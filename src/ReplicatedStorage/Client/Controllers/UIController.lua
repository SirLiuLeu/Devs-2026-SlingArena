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
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)

local UIController = {}
UIController.__index = UIController

export type Dependencies = {
	ClientService: any,
}

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextButton") then
		return value
	end
	return nil
end

local function resolveGuiButton(root: Instance, path: string): GuiButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("GuiButton") then
		return value
	end
	return nil
end

local function resolveTextLabel(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextLabel") then
		return value
	end
	return nil
end

local function resolveScreenGui(root: Instance, path: string): ScreenGui?
	local value = PathResolver.resolvePath(root, path)
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

local function getRequiredExp(level: number): number
	return math.max(1, LevelConfig.RequiredExp(math.max(1, math.floor(level))))
end

local function getHpPotionCountFromMock(data): number
	local ownedItems = data and data.OwnedItems
	if type(ownedItems) ~= "table" then
		return 0
	end
	return math.max(0, math.floor(ownedItems.hp_potion or 0))
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
	self.InventoryUIController = InventoryUIController.new(playerGui)
	self.SpinUIController = SpinUIController.new(playerGui)
	self.OnlineRewardUIController = OnlineRewardUIController.new(playerGui)
	self.ShopUIController = ShopUIController.new(playerGui)
	self.DailyLoginUIController = DailyLoginUIController.new(playerGui)
	self.MatchScoreboardUIController = MatchScoreboardUIController.new(playerGui)
	self.InventoryDataProvider = InventoryDataProvider.GetDefault()
	self.OnlineRewardLogicService = OnlineRewardLogicService.GetDefault()
	self.ShopLogicService = ShopLogicService.GetDefault()
	self.DailyLoginLogicService = DailyLoginLogicService.GetDefault()
	self.InventoryUIController:SetDataProvider(self.InventoryDataProvider)
	self.OnlineRewardUIController:SetLogicService(self.OnlineRewardLogicService)
	self.ShopUIController:SetLogicService(self.ShopLogicService)
	self.DailyLoginUIController:SetLogicService(self.DailyLoginLogicService)

	self.JoinButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.JoinButton)
	self.LeaveButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.LeaveButton)
	self.StartSafeZoneButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.StartSafeZoneButton)
	self.MatchStatusLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.StatusLabel)
	self.TimerLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.TimerLabel)
	self.AlivePlayersLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.AlivePlayersLabel)
	self.WinnerPopup = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.WinnerPopup)
	self.DebugResetButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugResetButton)
	self.DailyButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.DailyButton)
	self.InventoryButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.InventoryButton)
	self.OnlineRewardButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.OnlineRewardButton)
	self.SettingButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.SettingButton)
	self.ShopButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.ShopButton)
	self.TabCoreButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.TabCore) or resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.TabScore)
	self.QuickHpButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.QuickHP)
	self.QuickHpQuantityLabel = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.QuickHPQuantity)
	self.DamageBuff = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.DamageBuff)
	self.DamageBuffValueText = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.DamageValueText)
	self.ExpBuff = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.ExpBuff)
	self.ExpBuffValueText = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.ExpValueText)
	self.HPRecoveryBuff = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecovery)
	self.HPRecoveryTimeText = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecoveryTime)
	self.HomeButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.HomeButton)
	self.DiamondValueLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.DiamondValue)
	self.ExpBarFill = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.Fill)
	self.ExpValueLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.ValueLabel)
	self.ExpLevelLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.LevelLabel)

	self.PanelMap = {
		DailyLogin = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.DailyLogin),
		Shop = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Shop) or resolveScreenGui(playerGui, "ShopUI"),
		Inventory = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Inventory),
		OnlineReward = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.OnlineReward),
		Settings = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Settings),
		Spin = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Spin),
	}

	self.LastQuickHpRequest = 0
	self.LastAuthoritativeState = nil

	if not self.JoinButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.JoinButton, "TextButton") end
	if not self.LeaveButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.LeaveButton, "TextButton") end
	if not self.StartSafeZoneButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.StartSafeZoneButton, "TextButton") end
	if not self.MatchStatusLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.StatusLabel, "TextLabel") end
	if not self.TimerLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.TimerLabel, "TextLabel") end
	if not self.AlivePlayersLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.AlivePlayersLabel, "TextLabel") end
	if not self.WinnerPopup then warnMissingUiPath(ProjectTreeSpec.UI.Match.WinnerPopup, "TextLabel") end
	if not self.DebugResetButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugResetButton, "TextButton") end
	if not self.DailyButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.DailyButton, "GuiButton") end
	if not self.InventoryButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.InventoryButton, "GuiButton") end
	if not self.OnlineRewardButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.OnlineRewardButton, "GuiButton") end
	if not self.SettingButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SettingButton, "GuiButton") end
	if not self.ShopButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.ShopButton, "GuiButton") end
	if not self.TabCoreButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.TabCore, "GuiButton") end
	if not self.QuickHpButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHP, "GuiButton") end
	if not self.HomeButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.HomeButton, "GuiButton") end
	if not (self.DamageBuff and self.DamageBuff:IsA("GuiObject")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.DamageBuff, "GuiObject") end
	if not (self.DamageBuffValueText and self.DamageBuffValueText:IsA("TextLabel")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.DamageValueText, "TextLabel") end
	if not (self.ExpBuff and self.ExpBuff:IsA("GuiObject")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.ExpBuff, "GuiObject") end
	if not (self.ExpBuffValueText and self.ExpBuffValueText:IsA("TextLabel")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.ExpValueText, "TextLabel") end
	if not (self.HPRecoveryBuff and self.HPRecoveryBuff:IsA("GuiObject")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecovery, "GuiObject") end
	if not (self.HPRecoveryTimeText and self.HPRecoveryTimeText:IsA("TextLabel")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecoveryTime, "TextLabel") end
	if not (self.QuickHpQuantityLabel and self.QuickHpQuantityLabel:IsA("TextLabel")) then
		warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHPQuantity, "TextLabel")
	end
	if not self.DiamondValueLabel then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.DiamondValue, "TextLabel") end
	if not self.PanelMap.DailyLogin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.DailyLogin, "ScreenGui") end
	if not self.PanelMap.Shop then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Shop, "ScreenGui") end
	if not self.PanelMap.Inventory then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Inventory, "ScreenGui") end
	if not self.PanelMap.OnlineReward then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.OnlineReward, "ScreenGui") end
	if not self.PanelMap.Settings then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Settings, "ScreenGui") end
	if not self.PanelMap.Spin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Spin, "ScreenGui") end

	return self
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
	self:_renderHudValues(data.Diamonds or 0, getHpPotionCountFromMock(data), data.Exp or 0, data.Level or 1)
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

function UIController:Start()
	if self.InventoryUIController then
		self.InventoryUIController:Start()
	end
	if self.SpinUIController then
		self.SpinUIController:Start()
	end
	if self.OnlineRewardUIController then
		self.OnlineRewardUIController:Start()
	end
	if self.ShopUIController then
		self.ShopUIController:Start()
	end
	if self.DailyLoginUIController then
		self.DailyLoginUIController:Start()
	end
	if self.MatchScoreboardUIController then
		self.MatchScoreboardUIController:LoadMockData()
	end
	setBuffVisible(self.DamageBuff, true)
	setBuffText(self.DamageBuffValueText, "100%")
	setBuffVisible(self.ExpBuff, true)
	setBuffText(self.ExpBuffValueText, "100%")
	setBuffVisible(self.HPRecoveryBuff, false)

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
	if self.JoinButton then
		table.insert(self.Connections, self.JoinButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestJoinArena()
		end))
	end
	if self.LeaveButton then
		table.insert(self.Connections, self.LeaveButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestLeaveArena()
		end))
	end
	if self.StartSafeZoneButton then
		table.insert(self.Connections, self.StartSafeZoneButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestStartSafeZone()
		end))
	end
	if self.DebugResetButton then
		table.insert(self.Connections, self.DebugResetButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestDebugResetLauncher()
		end))
	end
	if self.DailyButton then
		table.insert(self.Connections, self.DailyButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("DailyLogin")
			if self.DailyLoginUIController then
				self.DailyLoginUIController:SetVisible(true)
			end
		end))
	end
	if self.ShopButton then
		table.insert(self.Connections, self.ShopButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("Shop")
			if self.ShopUIController then
				self.ShopUIController:SetVisible(true)
			end
		end))
	end
	if self.InventoryButton then
		table.insert(self.Connections, self.InventoryButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("Inventory")
			if self.InventoryUIController then
				self.InventoryUIController:SetVisible(true)
			end
			if self.InventoryDataProvider and self.InventoryUIController then
				self.InventoryUIController:RefreshWithData(self.InventoryDataProvider:GetSnapshot())
			end
		end))
	end
	if self.OnlineRewardButton then
		table.insert(self.Connections, self.OnlineRewardButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("OnlineReward")
			if self.OnlineRewardUIController then
				self.OnlineRewardUIController:SetVisible(true)
			end
		end))
	end
	if self.SettingButton then
		table.insert(self.Connections, self.SettingButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("Settings")
		end))
	end
	if self.TabCoreButton then
		table.insert(self.Connections, self.TabCoreButton.MouseButton1Click:Connect(function()
			if self.MatchScoreboardUIController then
				self.MatchScoreboardUIController:ToggleVisible()
			end
		end))
	end
	if self.MatchScoreboardUIController and self.MatchScoreboardUIController.CloseButton then
		table.insert(self.Connections, self.MatchScoreboardUIController.CloseButton.MouseButton1Click:Connect(function()
			self.MatchScoreboardUIController:SetVisible(false)
		end))
	end
	if self.MatchScoreboardUIController and self.MatchScoreboardUIController.Overlay and self.MatchScoreboardUIController.Overlay:IsA("GuiButton") then
		table.insert(self.Connections, self.MatchScoreboardUIController.Overlay.MouseButton1Click:Connect(function()
			self.MatchScoreboardUIController:SetVisible(false)
		end))
	end
	if self.HomeButton then
		self.HomeButton.Active = true
		table.insert(self.Connections, self.HomeButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestLeaveArena()
		end))
	end
	if self.QuickHpButton then
		table.insert(self.Connections, self.QuickHpButton.MouseButton1Click:Connect(function()
			local now = os.clock()
			if now - self.LastQuickHpRequest < 0.2 then
				return
			end
			self.LastQuickHpRequest = now
			if self.InventoryDataProvider then
				self.InventoryDataProvider:SelectItem("hp_potion")
				self.InventoryDataProvider:UseSelectedItem()
			else
				self.ClientService:RequestConsumeHpPotion()
			end
		end))
	end

	local stateConnection = self.ClientService:BindStateUpdate(function(state)
		local previousState = self.LastAuthoritativeState
		self.LastAuthoritativeState = state
		if not previousState or previousState.Level ~= state.Level or previousState.Exp ~= state.Exp then
			MockPlayerData.SetProgress(state.Level or 1, state.Exp or 0, "AuthoritativeProgress", false)
		end
		local playerData = MockPlayerData.GetPlayerData()
		self:_renderHudValues(playerData.Diamonds or 0, getHpPotionCountFromMock(playerData), playerData.Exp or 0, playerData.Level or 1)

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
		setBuffText(self.HPRecoveryTimeText, if hpRecoveryFlag then string.format("%.1fs", getRemainingSeconds(hpRecoveryFlag, now)) else "0.0s")
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

	local scoreboardConnection = self.ClientService:BindMatchScoreboardUpdate(function(payload)
		if self.MatchScoreboardUIController then
			self.MatchScoreboardUIController:Refresh(payload)
		end
	end)
	if scoreboardConnection then
		table.insert(self.Connections, scoreboardConnection)
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
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return UIController
