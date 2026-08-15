--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local InventoryUIController = require(ReplicatedStorage.Client.Controllers.InventoryUIController)
local InventoryDataProvider = require(ReplicatedStorage.Client.Services.InventoryDataProvider)
local OnlineRewardUIController = require(ReplicatedStorage.Client.Controllers.OnlineRewardUIController)
local OnlineRewardLogicService = require(ReplicatedStorage.Client.Services.OnlineRewardLogicService)
local SpinUIController = require(ReplicatedStorage.Client.Controllers.SpinUIController)
local ShopUIController = require(ReplicatedStorage.Client.Controllers.ShopUIController)
local ShopLogicService = require(ReplicatedStorage.Client.Services.ShopLogicService)
local DailyLoginUIController = require(ReplicatedStorage.Client.Controllers.DailyLoginUIController)
local DailyLoginLogicService = require(ReplicatedStorage.Client.Services.DailyLoginLogicService)
local MatchScoreboardUIController = require(ReplicatedStorage.Client.Controllers.MatchScoreboardUIController)
local MatchSummaryUIController = require(ReplicatedStorage.Client.Controllers.MatchSummaryUIController)
local ToastUIController = require(ReplicatedStorage.Client.Controllers.ToastUIController)
local QuestUIController = require(ReplicatedStorage.Client.Controllers.QuestUIController)
local QuestLogicService = require(ReplicatedStorage.Client.Services.QuestLogicService)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local QUICK_HP_COOLDOWN_SECONDS = 3
local QUICK_HP_DIM_TRANSPARENCY = 0.45

local UIController = {}
UIController.__index = UIController

export type Dependencies = {
	ClientService: any,
}

local function resolveTextButton(root: Instance, path: string, shouldWarn: boolean?): TextButton?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = shouldWarn })
	if value and value:IsA("TextButton") then
		return value
	end
	return nil
end

local function resolveGuiButton(root: Instance, path: string, shouldWarn: boolean?): GuiButton?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = shouldWarn })
	if value and value:IsA("GuiButton") then
		return value
	end
	return nil
end

local function resolveTextLabel(root: Instance, path: string, shouldWarn: boolean?): TextLabel?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = shouldWarn })
	if value and value:IsA("TextLabel") then
		return value
	end
	return nil
end

local function resolveScreenGui(root: Instance, path: string, shouldWarn: boolean?): ScreenGui?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = shouldWarn })
	if value and value:IsA("ScreenGui") then
		return value
	end
	return nil
end

local function warnMissingUiPath(path: string, className: string)
	warn(string.format("[UI_MISSING] %s (%s) is missing. Create it manually in Studio.", path, className))
end

local function getRemainingSeconds(flag: any, now: number): number
	if type(flag) ~= "table" or type(flag.ExpiresAt) ~= "number" then
		return 0
	end
	return math.max(0, flag.ExpiresAt - now)
end

local function setBuffVisible(buffObject: Instance?, visible: boolean)
	if buffObject and buffObject:IsA("GuiObject") then
		buffObject.Visible = visible
	end
end

local function setBuffText(label: Instance?, text: string)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end


local function formatQuickHpCooldown(remaining: number): string
	if remaining > 0.5 then
		return tostring(math.max(1, math.ceil(remaining - 0.001)))
	end
	local tenths = math.max(1, math.floor((remaining * 10) + 0.0001))
	return string.format("%.1f", tenths / 10)
end

local function formatSteppedCooldown(remaining: number, interval: number): string
	local safeInterval = math.max(0.1, interval)
	local stepped = math.ceil((remaining - 0.0001) / safeInterval) * safeInterval
	stepped = math.max(safeInterval, stepped)
	if math.abs(stepped - math.floor(stepped + 0.5)) < 0.001 then
		return tostring(math.floor(stepped + 0.5))
	end
	return string.format("%.1f", stepped)
end

local function getRequiredExp(level: number): number
	return math.max(1, LevelConfig.RequiredExp(math.max(1, math.floor(level))))
end

local function getActiveFlagData(activeFlags: any, flagName: string): any?
	if type(activeFlags) ~= "table" then
		return nil
	end
	local flag = activeFlags[flagName]
	if type(flag) == "table" and type(flag.Data) == "table" then
		return flag.Data
	end
	return flag
end

function UIController.new(playerGui: PlayerGui, dependencies: Dependencies)
	local self = setmetatable({}, UIController)
	self.ClientService = dependencies.ClientService
	self.PlayerGui = playerGui
	self.Connections = {}
	self._boundUiConnectionKeys = {}
	self._startedControllerKeys = {}
	self.InventoryUIController = InventoryUIController.new(playerGui)
	self.SpinUIController = SpinUIController.new(playerGui)
	self.OnlineRewardUIController = OnlineRewardUIController.new(playerGui)
	self.ShopUIController = ShopUIController.new(playerGui)
	self.DailyLoginUIController = DailyLoginUIController.new(playerGui)
	self.MatchScoreboardUIController = MatchScoreboardUIController.new(playerGui)
	self.MatchSummaryUIController = MatchSummaryUIController.new(playerGui, self.ClientService)
	self.ToastUIController = ToastUIController.new(playerGui)
	self.QuestUIController = QuestUIController.new(playerGui)
	self.InventoryDataProvider = InventoryDataProvider.GetDefault()
	self.OnlineRewardLogicService = OnlineRewardLogicService.GetDefault()
	self.ShopLogicService = ShopLogicService.GetDefault()
	self.DailyLoginLogicService = DailyLoginLogicService.GetDefault()
	self.QuestLogicService = QuestLogicService.GetDefault()
	self.InventoryUIController:SetDataProvider(self.InventoryDataProvider)
	self.OnlineRewardUIController:SetLogicService(self.OnlineRewardLogicService)
	self.ShopUIController:SetLogicService(self.ShopLogicService)
	self.DailyLoginUIController:SetLogicService(self.DailyLoginLogicService)
	self.QuestUIController:SetLogicService(self.QuestLogicService)
	self.QuestUIController:SetToastController(self.ToastUIController)

	self.PanelMap = {}

	self.LastQuickHpRequest = 0
	self.AuthoritativeHpPotions = 0
	self.NextHpPotionUseTime = 0
	self.LastAuthoritativeState = nil
	self.QuickHpCooldownEndTime = 0
	self:_resolveUiReferences()

	-- UI may be cloned into PlayerGui after this controller is constructed.
	-- Missing-path warnings for concrete UI hierarchies are emitted by startup checks
	-- and by individual controllers once their ScreenGui is actually present.


	return self
end

function UIController:_resolveUiReferences()
	local playerGui = self.PlayerGui
	self.JoinButton = self.JoinButton or resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.JoinButton, false)
	self.LeaveButton = self.LeaveButton or resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.LeaveButton, false)
	self.StartSafeZoneButton = self.StartSafeZoneButton or resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.StartSafeZoneButton, false)
	self.Plus1MinuteButton = self.Plus1MinuteButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.Lobby.Plus1MinuteButton, false)
	self.EndRoundButton = self.EndRoundButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.Lobby.EndRoundButton, false)
	self.MatchStatusLabel = self.MatchStatusLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.StatusLabel, false)
	self.TimerLabel = self.TimerLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.TimerLabel, false)
	self.AlivePlayersLabel = self.AlivePlayersLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.AlivePlayersLabel, false)
	self.WinnerPopup = self.WinnerPopup or resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.WinnerPopup, false)
	self.DebugResetButton = self.DebugResetButton or resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugResetButton, false)
	self.DailyButton = self.DailyButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.DailyButton, false)
	self.InventoryButton = self.InventoryButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.InventoryButton, false)
	self.OnlineRewardButton = self.OnlineRewardButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.OnlineRewardButton, false)
	self.SettingButton = self.SettingButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.SettingButton, false)
	self.ShopButton = self.ShopButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.ShopButton, false)
	self.TabScoreButton = self.TabScoreButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.TabScore, false)
	self.QuestButton = self.QuestButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.QuestButton, false)
	self.ProgressPoint = self.ProgressPoint or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.ProgressPoint, { shouldWarn = false })
	self.QuickHpButton = self.QuickHpButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.QuickHP, false)
	self.QuickHpQuantityLabel = self.QuickHpQuantityLabel or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.QuickHPQuantity, { shouldWarn = false })
	self.QuickHpTimeLabel = self.QuickHpTimeLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.QuickHPTime, false)
	self.QuickHpOverlay = self.QuickHpOverlay or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.QuickHPOverlay, { shouldWarn = false })
	self.DamageBuff = self.DamageBuff or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.DamageBuff, { shouldWarn = false })
	self.DamageBuffValueText = self.DamageBuffValueText or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.DamageValueText, { shouldWarn = false })
	self.ExpBuff = self.ExpBuff or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.ExpBuff, { shouldWarn = false })
	self.ExpBuffValueText = self.ExpBuffValueText or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.ExpValueText, { shouldWarn = false })
	self.HPRecoveryBuff = self.HPRecoveryBuff or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecovery, { shouldWarn = false })
	self.HPRecoveryTimeText = self.HPRecoveryTimeText or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecoveryTime, { shouldWarn = false })
	self.HomeButton = self.HomeButton or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.HomeButton, false)
	self.DiamondValueLabel = self.DiamondValueLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.DiamondValue, false)
	self.ExpBarFill = self.ExpBarFill or PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.Fill, { shouldWarn = false })
	self.ExpValueLabel = self.ExpValueLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.ValueLabel, false)
	self.ExpLevelLabel = self.ExpLevelLabel or resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.LevelLabel, false)

	self.PanelMap.DailyLogin = self.PanelMap.DailyLogin or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.DailyLogin, false)
	self.PanelMap.Shop = self.PanelMap.Shop or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Shop, false) or resolveScreenGui(playerGui, "ShopUI", false)
	self.PanelMap.Inventory = self.PanelMap.Inventory or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Inventory, false)
	self.PanelMap.OnlineReward = self.PanelMap.OnlineReward or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.OnlineReward, false)
	self.PanelMap.Settings = self.PanelMap.Settings or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Settings, false)
	self.PanelMap.Spin = self.PanelMap.Spin or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Spin, false)
	self.PanelMap.Quest = self.PanelMap.Quest or resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Quest, false) or resolveScreenGui(playerGui, "QuestUI", false)
end

function UIController:_connectOnce(key: string, signal: RBXScriptSignal, callback: (...any) -> ())
	if self._boundUiConnectionKeys[key] then
		return
	end
	self._boundUiConnectionKeys[key] = true
	table.insert(self.Connections, signal:Connect(callback))
end

function UIController:_clearReferenceIfRemoved(fieldName: string, removedRoot: Instance, connectionKey: string?)
	local current = self[fieldName]
	if current and current:IsDescendantOf(removedRoot) then
		self[fieldName] = nil
		if connectionKey then
			self._boundUiConnectionKeys[connectionKey] = nil
		end
	end
end

function UIController:_clearRemovedUiReferences(removedRoot: Instance)
	self:_clearReferenceIfRemoved("JoinButton", removedRoot, "JoinButton")
	self:_clearReferenceIfRemoved("LeaveButton", removedRoot, "LeaveButton")
	self:_clearReferenceIfRemoved("StartSafeZoneButton", removedRoot, "StartSafeZoneButton")
	self:_clearReferenceIfRemoved("Plus1MinuteButton", removedRoot, "Plus1MinuteButton")
	self:_clearReferenceIfRemoved("EndRoundButton", removedRoot, "EndRoundButton")
	self:_clearReferenceIfRemoved("DebugResetButton", removedRoot, "DebugResetButton")
	self:_clearReferenceIfRemoved("DailyButton", removedRoot, "DailyButton")
	self:_clearReferenceIfRemoved("InventoryButton", removedRoot, "InventoryButton")
	self:_clearReferenceIfRemoved("OnlineRewardButton", removedRoot, "OnlineRewardButton")
	self:_clearReferenceIfRemoved("SettingButton", removedRoot, "SettingButton")
	self:_clearReferenceIfRemoved("ShopButton", removedRoot, "ShopButton")
	self:_clearReferenceIfRemoved("TabScoreButton", removedRoot, "TabScoreButton")
	self:_clearReferenceIfRemoved("QuestButton", removedRoot, "QuestButton")
	self:_clearReferenceIfRemoved("HomeButton", removedRoot, "HomeButton")
	self:_clearReferenceIfRemoved("QuickHpButton", removedRoot, "QuickHpButton")
	self:_clearReferenceIfRemoved("MatchStatusLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("TimerLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("AlivePlayersLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("WinnerPopup", removedRoot, nil)
	self:_clearReferenceIfRemoved("ProgressPoint", removedRoot, nil)
	self:_clearReferenceIfRemoved("QuickHpQuantityLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("QuickHpTimeLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("QuickHpOverlay", removedRoot, nil)
	self:_clearReferenceIfRemoved("DamageBuff", removedRoot, nil)
	self:_clearReferenceIfRemoved("DamageBuffValueText", removedRoot, nil)
	self:_clearReferenceIfRemoved("ExpBuff", removedRoot, nil)
	self:_clearReferenceIfRemoved("ExpBuffValueText", removedRoot, nil)
	self:_clearReferenceIfRemoved("HPRecoveryBuff", removedRoot, nil)
	self:_clearReferenceIfRemoved("HPRecoveryTimeText", removedRoot, nil)
	self:_clearReferenceIfRemoved("DiamondValueLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("ExpBarFill", removedRoot, nil)
	self:_clearReferenceIfRemoved("ExpValueLabel", removedRoot, nil)
	self:_clearReferenceIfRemoved("ExpLevelLabel", removedRoot, nil)
end

function UIController:_bindResolvedUiReferences()
	if self.JoinButton then
		self:_connectOnce("JoinButton", self.JoinButton.MouseButton1Click, function()
			self.ClientService:RequestJoinArena()
		end)
	end
	if self.LeaveButton then
		self:_connectOnce("LeaveButton", self.LeaveButton.MouseButton1Click, function()
			self.ClientService:RequestLeaveArena()
		end)
	end
	if self.StartSafeZoneButton then
		self:_connectOnce("StartSafeZoneButton", self.StartSafeZoneButton.MouseButton1Click, function()
			self.ClientService:RequestStartSafeZone()
		end)
	end
	if self.Plus1MinuteButton then
		self:_connectOnce("Plus1MinuteButton", self.Plus1MinuteButton.MouseButton1Click, function()
			self.ClientService:RequestPlus1Minute()
		end)
	end
	if self.DebugResetButton then
		self:_connectOnce("DebugResetButton", self.DebugResetButton.MouseButton1Click, function()
			self.ClientService:RequestDebugResetLauncher()
		end)
	end
	if self.EndRoundButton then
		self:_connectOnce("EndRoundButton", self.EndRoundButton.MouseButton1Click, function()
			self.ClientService:RequestEndRound()
		end)
	end
	if self.DailyButton then
		self:_connectOnce("DailyButton", self.DailyButton.MouseButton1Click, function()
			self:ShowMainHubPanel("DailyLogin")
			if self.DailyLoginUIController then
				self.DailyLoginUIController:SetVisible(true)
			end
		end)
	end
	if self.ShopButton then
		self:_connectOnce("ShopButton", self.ShopButton.MouseButton1Click, function()
			self:ShowMainHubPanel("Shop")
			if self.ShopUIController then
				self.ShopUIController:SetVisible(true)
			end
		end)
	end
	if self.InventoryButton then
		self:_connectOnce("InventoryButton", self.InventoryButton.MouseButton1Click, function()
			self:ShowMainHubPanel("Inventory")
			if self.InventoryUIController then
				self.InventoryUIController:SetVisible(true)
			end
			if self.InventoryDataProvider and self.InventoryUIController then
				self.InventoryUIController:RefreshWithData(self.InventoryDataProvider:GetSnapshot())
			end
		end)
	end
	if self.OnlineRewardButton then
		self:_connectOnce("OnlineRewardButton", self.OnlineRewardButton.MouseButton1Click, function()
			self:ShowMainHubPanel("OnlineReward")
			if self.OnlineRewardUIController then
				self.OnlineRewardUIController:SetVisible(true)
			end
		end)
	end
	if self.QuestButton then
		self:_connectOnce("QuestButton", self.QuestButton.MouseButton1Click, function()
			self:ShowMainHubPanel("Quest")
			if self.QuestUIController then
				self.QuestUIController:SetVisible(true)
			end
		end)
	end
	if self.SettingButton then
		self:_connectOnce("SettingButton", self.SettingButton.MouseButton1Click, function()
			self:ShowMainHubPanel("Settings")
		end)
	end
	if self.TabScoreButton then
		self:_connectOnce("TabScoreButton", self.TabScoreButton.MouseButton1Click, function()
			if self.MatchScoreboardUIController then
				self.MatchScoreboardUIController:ToggleVisible()
			end
		end)
	end
	if self.MatchScoreboardUIController and self.MatchScoreboardUIController.CloseButton then
		self:_connectOnce("MatchScoreboardCloseButton", self.MatchScoreboardUIController.CloseButton.MouseButton1Click, function()
			self.MatchScoreboardUIController:SetVisible(false)
		end)
	end
	if self.MatchScoreboardUIController and self.MatchScoreboardUIController.Overlay and self.MatchScoreboardUIController.Overlay:IsA("GuiButton") then
		self:_connectOnce("MatchScoreboardOverlay", self.MatchScoreboardUIController.Overlay.MouseButton1Click, function()
			self.MatchScoreboardUIController:SetVisible(false)
		end)
	end
	if self.HomeButton then
		self.HomeButton.Active = true
		self:_connectOnce("HomeButton", self.HomeButton.MouseButton1Click, function()
			self.ClientService:RequestLeaveArena()
		end)
	end
	if self.QuickHpButton then
		self:_connectOnce("QuickHpButton", self.QuickHpButton.MouseButton1Click, function()
			local now = os.clock()
			if now - self.LastQuickHpRequest < 0.2 then
				return
			end
			self.LastQuickHpRequest = now
			if (self.AuthoritativeHpPotions or 0) <= 0 then
				self:_showHpPotionUseFeedback("NoPotion")
				return
			end
			if now < (self.NextHpPotionUseTime or 0) then
				self:_showHpPotionUseFeedback("Cooldown", self.NextHpPotionUseTime)
				return
			end
			self.QuickHpCooldownEndTime = now + QUICK_HP_COOLDOWN_SECONDS
			self:_refreshQuickHpCooldown()
			self.ClientService:RequestConsumeHpPotion()
		end)
	end
end

function UIController:_renderHudValues(diamonds: number?, hpPotions: number?, exp: number?, level: number?)
	local resolvedLevel = math.max(1, math.floor(level or 1))
	local currentExp = math.max(0, math.floor(exp or 0))
	local required = getRequiredExp(resolvedLevel)
	local ratio = math.clamp(currentExp / required, 0, 1)

	if self.DiamondValueLabel and diamonds ~= nil then
		self.DiamondValueLabel.Text = tostring(math.max(0, math.floor(diamonds)))
	end
	if self.QuickHpQuantityLabel and self.QuickHpQuantityLabel:IsA("TextLabel") and hpPotions ~= nil then
		self.QuickHpQuantityLabel.Text = string.format("x%d", math.max(0, math.floor(hpPotions)))
	end
	if self.ExpBarFill and self.ExpBarFill:IsA("GuiObject") then
		self.ExpBarFill.Size = UDim2.new(ratio, 0, self.ExpBarFill.Size.Y.Scale, self.ExpBarFill.Size.Y.Offset)
	end
	if self.ExpValueLabel then
		self.ExpValueLabel.Text = string.format("%d / %d", currentExp, required)
	end
	if self.ExpLevelLabel then
		self.ExpLevelLabel.Text = string.format("Lv.%d", resolvedLevel)
	end
end

function UIController:_refreshMockHud(playerData)
	local data = playerData or MockPlayerData.GetPlayerData()
	self:_renderHudValues(data.Diamonds or 0, self.AuthoritativeHpPotions or 0, data.Exp or 0, data.Level or 1)
end

function UIController:_showHpPotionUseFeedback(result: string, retryAt: number?)
	if not self.QuickHpQuantityLabel or not self.QuickHpQuantityLabel:IsA("TextLabel") then
		return
	end
	if result == "Cooldown" then
		local remaining = math.max(0, (retryAt or self.NextHpPotionUseTime or 0) - os.clock())
		self.QuickHpQuantityLabel.Text = string.format("%.1fs", remaining)
	elseif result == "NoPotion" then
		self.QuickHpQuantityLabel.Text = "Empty"
	elseif result == "Rejected" then
		self.QuickHpQuantityLabel.Text = "Wait"
	end
end


function UIController:_setQuickHpCooldownVisual(remaining: number)
	local inCooldown = remaining > 0
	if self.QuickHpButton then
		self.QuickHpButton.Active = not inCooldown
		self.QuickHpButton.AutoButtonColor = not inCooldown
		if self.QuickHpButton:IsA("ImageButton") then
			self.QuickHpButton.ImageTransparency = if inCooldown then QUICK_HP_DIM_TRANSPARENCY else 0
		end
	end
	if self.QuickHpOverlay and self.QuickHpOverlay:IsA("GuiObject") then
		self.QuickHpOverlay.Visible = inCooldown
	end
	if self.QuickHpTimeLabel then
		self.QuickHpTimeLabel.Visible = inCooldown
		self.QuickHpTimeLabel.Text = if inCooldown then formatQuickHpCooldown(remaining) else ""
	end
end

function UIController:_refreshQuickHpCooldown()
	local remaining = math.max(0, (self.QuickHpCooldownEndTime or 0) - os.clock())
	self:_setQuickHpCooldownVisual(remaining)
end

function UIController:ShowMainHubPanel(activeKey: string)
	for panelKey, panelGui in pairs(self.PanelMap) do
		if panelGui then
			panelGui.Enabled = (panelKey == activeKey)
		end
	end
end

function UIController:ToggleMainHubPanel(panelKey: string)
	local panelGui = self.PanelMap[panelKey]
	if panelGui then
		panelGui.Enabled = not panelGui.Enabled
	end
end

function UIController:_isUiAvailable(path: string): boolean
	return PathResolver.resolvePath(self.PlayerGui, path, { shouldWarn = false }) ~= nil
end

function UIController:_startFeatureController(key: string, screenPath: string, startCallback: () -> ())
	if self._startedControllerKeys[key] or not self:_isUiAvailable(screenPath) then
		return
	end
	self._startedControllerKeys[key] = true
	startCallback()
end

function UIController:_startAvailableFeatureControllers()
	self:_startFeatureController("Inventory", ProjectTreeSpec.UI.Inventory.ScreenGui, function()
		self.InventoryUIController = InventoryUIController.new(self.PlayerGui)
		self.InventoryUIController:SetDataProvider(self.InventoryDataProvider)
		self.InventoryUIController:Start()
		self.PanelMap.Inventory = resolveScreenGui(self.PlayerGui, ProjectTreeSpec.UI.Inventory.ScreenGui, false)
		if self.InventoryDataProvider then
			self.InventoryUIController:RefreshWithData(self.InventoryDataProvider:GetSnapshot())
		end
	end)
	self:_startFeatureController("Spin", ProjectTreeSpec.UI.Spin.ScreenGui, function()
		self.SpinUIController = SpinUIController.new(self.PlayerGui)
		self.SpinUIController:Start()
		self.PanelMap.Spin = resolveScreenGui(self.PlayerGui, ProjectTreeSpec.UI.Spin.ScreenGui, false)
	end)
	self:_startFeatureController("OnlineReward", ProjectTreeSpec.UI.OnlineReward.ScreenGui, function()
		self.OnlineRewardUIController = OnlineRewardUIController.new(self.PlayerGui)
		self.OnlineRewardUIController:SetLogicService(self.OnlineRewardLogicService)
		self.OnlineRewardUIController:Start()
		self.PanelMap.OnlineReward = resolveScreenGui(self.PlayerGui, ProjectTreeSpec.UI.OnlineReward.ScreenGui, false)
	end)
	self:_startFeatureController("Shop", ProjectTreeSpec.UI.Shop.ScreenGui, function()
		self.ShopUIController = ShopUIController.new(self.PlayerGui)
		self.ShopUIController:SetLogicService(self.ShopLogicService)
		self.ShopUIController:Start()
		self.PanelMap.Shop = resolveScreenGui(self.PlayerGui, ProjectTreeSpec.UI.Shop.ScreenGui, false)
	end)
	self:_startFeatureController("DailyLogin", ProjectTreeSpec.UI.DailyLogin.ScreenGui, function()
		self.DailyLoginUIController = DailyLoginUIController.new(self.PlayerGui)
		self.DailyLoginUIController:SetLogicService(self.DailyLoginLogicService)
		self.DailyLoginUIController:Start()
		self.PanelMap.DailyLogin = resolveScreenGui(self.PlayerGui, ProjectTreeSpec.UI.DailyLogin.ScreenGui, false)
	end)
	self:_startFeatureController("MatchScoreboard", ProjectTreeSpec.UI.MatchScoreboard.ScreenGui, function()
		self.MatchScoreboardUIController = MatchScoreboardUIController.new(self.PlayerGui)
		self.MatchScoreboardUIController:LoadMockData()
	end)
	self:_startFeatureController("MatchSummary", ProjectTreeSpec.UI.MatchSummary.ScreenGui, function()
		self.MatchSummaryUIController = MatchSummaryUIController.new(self.PlayerGui, self.ClientService)
		self.MatchSummaryUIController:Start()
	end)
	self:_startFeatureController("Quest", "QuestUI", function()
		self.QuestUIController = QuestUIController.new(self.PlayerGui)
		self.QuestUIController:SetLogicService(self.QuestLogicService)
		self.QuestUIController:SetToastController(self.ToastUIController)
		self.QuestUIController:Start()
		self.PanelMap.Quest = self.PanelMap.Quest or resolveScreenGui(self.PlayerGui, "QuestUI", false)
	end)
end

function UIController:_destroyFeatureController(key: string, fieldName: string)
	if not self._startedControllerKeys[key] then
		return
	end
	local controller = self[fieldName]
	if controller and controller.Destroy then
		controller:Destroy()
	end
	self[fieldName] = nil
	self._startedControllerKeys[key] = nil
	if key == "MatchScoreboard" then
		self._boundUiConnectionKeys.MatchScoreboardCloseButton = nil
		self._boundUiConnectionKeys.MatchScoreboardOverlay = nil
	end
end

function UIController:_handlePlayerGuiChildRemoved(child: Instance)
	self:_clearRemovedUiReferences(child)
	local name = child.Name
	if name == ProjectTreeSpec.UI.Inventory.ScreenGui then
		self:_destroyFeatureController("Inventory", "InventoryUIController")
	elseif name == ProjectTreeSpec.UI.Shop.ScreenGui then
		self:_destroyFeatureController("Shop", "ShopUIController")
	elseif name == ProjectTreeSpec.UI.MatchSummary.ScreenGui then
		self:_destroyFeatureController("MatchSummary", "MatchSummaryUIController")
	elseif name == ProjectTreeSpec.UI.MatchScoreboard.ScreenGui then
		self:_destroyFeatureController("MatchScoreboard", "MatchScoreboardUIController")
	elseif name == ProjectTreeSpec.UI.OnlineReward.ScreenGui then
		self:_destroyFeatureController("OnlineReward", "OnlineRewardUIController")
	elseif name == ProjectTreeSpec.UI.DailyLogin.ScreenGui then
		self:_destroyFeatureController("DailyLogin", "DailyLoginUIController")
	elseif name == ProjectTreeSpec.UI.Spin.ScreenGui then
		self:_destroyFeatureController("Spin", "SpinUIController")
	elseif name == "QuestUI" then
		self:_destroyFeatureController("Quest", "QuestUIController")
	end
	if self.PanelMap then
		for panelKey, panelGui in pairs(self.PanelMap) do
			if panelGui == child then
				self.PanelMap[panelKey] = nil
			end
		end
	end
end

function UIController:Start()
	self:_resolveUiReferences()
	self:_startAvailableFeatureControllers()
	self:_bindResolvedUiReferences()
	table.insert(self.Connections, self.PlayerGui.ChildAdded:Connect(function()
		self:_resolveUiReferences()
		self:_startAvailableFeatureControllers()
		self:_bindResolvedUiReferences()
		self:_refreshMockHud(MockPlayerData.GetPlayerData())
		self:_refreshQuickHpCooldown()
	end))
	table.insert(self.Connections, self.PlayerGui.DescendantAdded:Connect(function()
		self:_resolveUiReferences()
		self:_bindResolvedUiReferences()
	end))
	table.insert(self.Connections, self.PlayerGui.ChildRemoved:Connect(function(child)
		self:_handlePlayerGuiChildRemoved(child)
	end))

	setBuffVisible(self.DamageBuff, true)
	setBuffText(self.DamageBuffValueText, "100%")
	setBuffVisible(self.ExpBuff, true)
	setBuffText(self.ExpBuffValueText, "100%")
	setBuffVisible(self.HPRecoveryBuff, false)
	self:_refreshQuickHpCooldown()

	table.insert(self.Connections, MockPlayerData.BindChanged(function(playerData)
		self:_refreshMockHud(playerData)
	end))
	self:_refreshMockHud(MockPlayerData.GetPlayerData())

	if self.InventoryDataProvider then
		table.insert(self.Connections, self.InventoryDataProvider:BindChanged(function(snapshot)
			if self.InventoryUIController then
				self.InventoryUIController:RefreshWithData(snapshot)
			end
		end))
		self.InventoryDataProvider:LoadMockInventory()
	end
	if self.OnlineRewardLogicService then
		self.OnlineRewardLogicService:LoadMockData()
	end
	if self.ShopLogicService then
		self.ShopLogicService:LoadMockData()
	end
	if self.DailyLoginLogicService then
		self.DailyLoginLogicService:LoadMockData()
	end

	local stateConnection = self.ClientService:BindStateUpdate(function(state)
		local previousState = self.LastAuthoritativeState
		self.LastAuthoritativeState = state
		if not previousState or previousState.Level ~= state.Level or previousState.Exp ~= state.Exp then
			MockPlayerData.SetProgress(state.Level or 1, state.Exp or 0, "AuthoritativeProgress", false)
		end
		if typeof(state.HpPotions) == "number" then
			self.AuthoritativeHpPotions = math.max(0, math.floor(state.HpPotions))
			if self.InventoryDataProvider then
				self.InventoryDataProvider:SetFromState({ OwnedItems = { hp_potion = self.AuthoritativeHpPotions } })
			end
		end
		if typeof(state.NextHpPotionUseTime) == "number" then
			self.NextHpPotionUseTime = state.NextHpPotionUseTime
		end
		self:_renderHudValues(state.Diamonds or 0, self.AuthoritativeHpPotions or 0, state.Exp or 0, state.Level or 1)
		self:_refreshQuickHpCooldown()

		local activeFlags = state.ActiveFlags or {}
		local now = os.clock()
		local damageFlag = getActiveFlagData(activeFlags, "DamageBoosted")
		local damageTotalPercent = 100 * math.max(0, state.DamageMultiplier or 1)
		if damageFlag and type(damageFlag.DamageBonusPercent) == "number" then
			damageTotalPercent += math.max(0, damageFlag.DamageBonusPercent)
		end
		setBuffVisible(self.DamageBuff, true)
		setBuffText(self.DamageBuffValueText, string.format("%d%%", math.floor(damageTotalPercent + 0.5)))

		local expTotalPercent = 100 + math.max(0, state.ExpBonus or 0) * 100
		local expFlag = getActiveFlagData(activeFlags, "EXPBoosted")
		if expFlag and type(expFlag.ExpBonusPercent) == "number" then
			expTotalPercent += math.max(0, expFlag.ExpBonusPercent)
		end
		setBuffVisible(self.ExpBuff, true)
		setBuffText(self.ExpBuffValueText, string.format("%d%%", math.floor(expTotalPercent + 0.5)))

		local hpRecoveryFlag = activeFlags.HPRecovering
		setBuffVisible(self.HPRecoveryBuff, hpRecoveryFlag ~= nil)
		if hpRecoveryFlag then
			local tickInterval = if type(hpRecoveryFlag) == "table" and type(hpRecoveryFlag.TickInterval) == "number" then hpRecoveryFlag.TickInterval else 0.5
			setBuffText(self.HPRecoveryTimeText, formatSteppedCooldown(getRemainingSeconds(hpRecoveryFlag, now), tickInterval))
		else
			setBuffText(self.HPRecoveryTimeText, "0")
		end
	end)
	if stateConnection then
		table.insert(self.Connections, stateConnection)
	end

	local uiStateConnection = self.ClientService:BindUIStateUpdate(function(payload)
		if self.MatchStatusLabel then self.MatchStatusLabel.Text = string.format("Match: %s", tostring(payload.State or GameStates.MapRoundState.Lobby)) end
		if self.TimerLabel then
			local total = math.max(0, math.floor(payload.RoundElapsed or payload.CountdownTimer or payload.TimeLeft or 0))
			local minutes = math.floor(total / 60)
			local seconds = total % 60
			self.TimerLabel.Text = string.format("%02d:%02d", minutes, seconds)
		end
		if self.AlivePlayersLabel then self.AlivePlayersLabel.Text = string.format("PlayerCount: %d (alive %d)", payload.PlayerCount or 0, payload.AlivePlayers or 0) end
		if self.WinnerPopup and (payload.State or "") == GameStates.MapRoundState.RoundEnd then
			self.WinnerPopup.Visible = true
			self.WinnerPopup.Text = "Match result screen: pending"
		end
	end)
	if uiStateConnection then
		table.insert(self.Connections, uiStateConnection)
	end

	table.insert(self.Connections, game:GetService("RunService").Heartbeat:Connect(function()
		self:_refreshQuickHpCooldown()
	end))

	local scoreboardConnection = self.ClientService:BindMatchScoreboardUpdate(function(payload)
		if self.MatchScoreboardUIController then
			self.MatchScoreboardUIController:Refresh(payload)
		end
	end)
	if scoreboardConnection then
		table.insert(self.Connections, scoreboardConnection)
	end

	local notificationRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.Notification) :: RemoteEvent?
	if notificationRemote and self.ToastUIController then
		table.insert(self.Connections, notificationRemote.OnClientEvent:Connect(function(payload)
			self.ToastUIController:Enqueue(payload)
		end))
	end

	local feedbackRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if feedbackRemote then
		table.insert(self.Connections, feedbackRemote.OnClientEvent:Connect(function(message)
			if type(message) ~= "table" or message.EventType ~= "HpPotionUseResult" then
				return
			end
			local payload = message.Payload or {}
			local result = tostring(payload.Result or "Rejected")
			if result == "Consumed" then
				self.QuickHpCooldownEndTime = os.clock() + QUICK_HP_COOLDOWN_SECONDS
				self:_refreshQuickHpCooldown()
			else
				self:_showHpPotionUseFeedback(result, payload.RetryAt)
			end
		end))
	end

	local popupRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.PopupMessage) :: RemoteEvent?
	if popupRemote and self.ToastUIController then
		table.insert(self.Connections, popupRemote.OnClientEvent:Connect(function(message)
			self.ToastUIController:Enqueue(message)
		end))
	end

	local resultConnection = self.ClientService:BindRoundResult(function(payload)
		if self.WinnerPopup then
			self.WinnerPopup.Visible = true
			self.WinnerPopup.Text = "Match result screen: Winner: " .. tostring(payload.Winner)
		end
	end)
	if resultConnection then
		table.insert(self.Connections, resultConnection)
	end
end

function UIController:Destroy()
	if self.InventoryUIController then
		self.InventoryUIController:Destroy()
	end
	if self.SpinUIController then
		self.SpinUIController:Destroy()
	end
	if self.OnlineRewardUIController then
		self.OnlineRewardUIController:Destroy()
	end
	if self.ShopUIController then
		self.ShopUIController:Destroy()
	end
	if self.DailyLoginUIController then
		self.DailyLoginUIController:Destroy()
	end
	if self.MatchScoreboardUIController then
		self.MatchScoreboardUIController:Destroy()
	end
	if self.MatchSummaryUIController then
		self.MatchSummaryUIController:Destroy()
	end
	if self.ToastUIController then
		self.ToastUIController:Destroy()
	end
	if self.QuestUIController then
		self.QuestUIController:Destroy()
	end
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return UIController
