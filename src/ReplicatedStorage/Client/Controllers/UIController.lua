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
	self.DebugFoodButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugFoodButton)
	self.DebugResetButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugResetButton)
	self.SlingStatsButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SlingStatsButton)
	self.DailyButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.DailyButton)
	self.InventoryButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.InventoryButton)
	self.OnlineRewardButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.OnlineRewardButton)
	self.SettingButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.SettingButton)
	self.SpinButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SpinButton)
	self.ShopButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.ShopButton)
	self.QuickHpButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.QuickHP)
	self.QuickHpCountLabel = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.QuickHPCountLabel)
	self.DamageBuff = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.DamageBuff)
	self.DamageBuffValueText = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.DamageValueText)
	self.ExpBuff = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.ExpBuff)
	self.ExpBuffValueText = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.ExpValueText)
	self.HPRecoveryBuff = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecovery)
	self.HPRecoveryTimeText = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecoveryTime)
	self.HomeButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.HomeButton)
	self.TeamIndicator = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.TeamIndicator)
	self.DiamondQuantityLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.DiamondQuantity)
	self.ExpBarFill = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.Fill)
	self.ExpValueLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.ValueLabel)
	self.ExpLevelLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.ExpProgress.LevelLabel)

	self.PanelMap = {
		SlingStats = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.SlingStats),
		DailyLogin = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.DailyLogin),
		Shop = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Shop) or resolveScreenGui(playerGui, "ShopUI"),
		Inventory = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Inventory),
		OnlineReward = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.OnlineReward),
		Settings = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Settings),
		Spin = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.Spin),
	}

	self.LastQuickHpRequest = 0

	if not self.JoinButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.JoinButton, "TextButton") end
	if not self.LeaveButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.LeaveButton, "TextButton") end
	if not self.StartSafeZoneButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.StartSafeZoneButton, "TextButton") end
	if not self.MatchStatusLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.StatusLabel, "TextLabel") end
	if not self.TimerLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.TimerLabel, "TextLabel") end
	if not self.AlivePlayersLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.AlivePlayersLabel, "TextLabel") end
	if not self.WinnerPopup then warnMissingUiPath(ProjectTreeSpec.UI.Match.WinnerPopup, "TextLabel") end
	if not self.DebugFoodButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugFoodButton, "TextButton") end
	if not self.DebugResetButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugResetButton, "TextButton") end
	if not self.SlingStatsButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SlingStatsButton, "TextButton") end
	if not self.DailyButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.DailyButton, "GuiButton") end
	if not self.InventoryButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.InventoryButton, "GuiButton") end
	if not self.OnlineRewardButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.OnlineRewardButton, "GuiButton") end
	if not self.SettingButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SettingButton, "GuiButton") end
	if not self.SpinButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SpinButton, "TextButton") end
	if not self.ShopButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.ShopButton, "GuiButton") end
	if not self.QuickHpButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHP, "GuiButton") end
	if not self.HomeButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.HomeButton, "GuiButton") end
	if not (self.DamageBuff and self.DamageBuff:IsA("GuiObject")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.DamageBuff, "GuiObject") end
	if not (self.DamageBuffValueText and self.DamageBuffValueText:IsA("TextLabel")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.DamageValueText, "TextLabel") end
	if not (self.ExpBuff and self.ExpBuff:IsA("GuiObject")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.ExpBuff, "GuiObject") end
	if not (self.ExpBuffValueText and self.ExpBuffValueText:IsA("TextLabel")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.ExpValueText, "TextLabel") end
	if not (self.HPRecoveryBuff and self.HPRecoveryBuff:IsA("GuiObject")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecovery, "GuiObject") end
	if not (self.HPRecoveryTimeText and self.HPRecoveryTimeText:IsA("TextLabel")) then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.BuffContainer.HPRecoveryTime, "TextLabel") end
	if not (self.QuickHpCountLabel and self.QuickHpCountLabel:IsA("TextLabel")) then
		warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHPCountLabel, "TextLabel")
	end
	if not self.TeamIndicator then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.TeamIndicator, "TextLabel") end
	if not self.DiamondQuantityLabel then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.DiamondQuantity, "TextLabel") end
	if not self.PanelMap.SlingStats then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.SlingStats, "ScreenGui") end
	if not self.PanelMap.DailyLogin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.DailyLogin, "ScreenGui") end
	if not self.PanelMap.Shop then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Shop, "ScreenGui") end
	if not self.PanelMap.Inventory then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Inventory, "ScreenGui") end
	if not self.PanelMap.OnlineReward then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.OnlineReward, "ScreenGui") end
	if not self.PanelMap.Settings then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Settings, "ScreenGui") end
	if not self.PanelMap.Spin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Spin, "ScreenGui") end

	return self
end

function UIController:_refreshMockHud(playerData)
	local data = playerData or MockPlayerData.GetPlayerData()
	if self.DiamondQuantityLabel then
		self.DiamondQuantityLabel.Text = tostring(math.max(0, math.floor(data.Diamonds or 0)))
	end
	if self.QuickHpCountLabel and self.QuickHpCountLabel:IsA("TextLabel") then
		self.QuickHpCountLabel.Text = string.format("x%d", math.max(0, math.floor((data.OwnedItems and data.OwnedItems.hp_potion) or 0)))
	end
	local currentExp = math.max(0, math.floor(data.Exp or 0))
	local level = 1
	local required = math.max(1, LevelConfig.RequiredExp(level))
	local ratio = math.clamp(currentExp / required, 0, 1)
	if self.ExpBarFill and self.ExpBarFill:IsA("GuiObject") then
		self.ExpBarFill.Size = UDim2.new(ratio, 0, self.ExpBarFill.Size.Y.Scale, self.ExpBarFill.Size.Y.Offset)
	end
	if self.ExpValueLabel then
		self.ExpValueLabel.Text = string.format("%d / %d", currentExp, required)
	end
	if self.ExpLevelLabel then
		self.ExpLevelLabel.Text = string.format("Lv.%d", level)
	end
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
	setBuffVisible(self.DamageBuff, false)
	setBuffVisible(self.ExpBuff, false)
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
	if self.DebugFoodButton then
		table.insert(self.Connections, self.DebugFoodButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestDebugSpawnFood("ArenaMap")
		end))
	end
	if self.DebugResetButton then
		table.insert(self.Connections, self.DebugResetButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestDebugResetSling()
		end))
	end
	if self.SlingStatsButton then
		table.insert(self.Connections, self.SlingStatsButton.MouseButton1Click:Connect(function()
			self:ToggleMainHubPanel("SlingStats")
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
	if self.SpinButton then
		table.insert(self.Connections, self.SpinButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("Spin")
		end))
	end
	if self.HomeButton then
		table.insert(self.Connections, self.HomeButton.MouseButton1Click:Connect(function()
			self.ClientService:RequestTeleport(
				ProjectTreeSpec.UI.MainHub.LobbyTeleport.MapName,
				ProjectTreeSpec.UI.MainHub.LobbyTeleport.SpawnName
			)
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
		local currentExp = math.max(0, math.floor(MockPlayerData.GetPlayerData().Exp or 0))
		local level = math.max(1, math.floor(state.Level or 1))
		local required = math.max(1, LevelConfig.RequiredExp(level))
		local ratio = math.clamp(currentExp / required, 0, 1)
		if self.ExpBarFill and self.ExpBarFill:IsA("GuiObject") then
			self.ExpBarFill.Size = UDim2.new(ratio, 0, self.ExpBarFill.Size.Y.Scale, self.ExpBarFill.Size.Y.Offset)
		end
		if self.DiamondQuantityLabel then
			self.DiamondQuantityLabel.Text = tostring(math.max(0, math.floor(MockPlayerData.GetPlayerData().Diamonds or 0)))
		end
		if self.ExpValueLabel then
			self.ExpValueLabel.Text = string.format("%d / %d", currentExp, required)
		end
		if self.ExpLevelLabel then
			self.ExpLevelLabel.Text = string.format("Lv.%d", level)
		end
		local activeFlags = state.ActiveFlags or {}
		local now = os.clock()
		local damageFlag = activeFlags.DamageBoosted
		setBuffVisible(self.DamageBuff, damageFlag ~= nil)
		setBuffText(self.DamageBuffValueText, if damageFlag then string.format("+%d%%", math.floor((damageFlag.DamageBonusPercent or 100) + 0.5)) else "+0%")
		local expPercent = math.floor(math.max(0, state.ExpBonus or 0) * 100 + 0.5)
		local expFlag = activeFlags.EXPBoosted
		if expFlag then
			expPercent += math.floor((expFlag.ExpBonusPercent or 100) + 0.5)
		end
		setBuffVisible(self.ExpBuff, expPercent > 0)
		setBuffText(self.ExpBuffValueText, string.format("+%d%%", expPercent))
		local hpRecoveryFlag = activeFlags.HPRecovering
		setBuffVisible(self.HPRecoveryBuff, hpRecoveryFlag ~= nil)
		setBuffText(self.HPRecoveryTimeText, if hpRecoveryFlag then string.format("%.1fs", getRemainingSeconds(hpRecoveryFlag, now)) else "0.0s")
		if self.TeamIndicator then
			local teamId = tostring(state.TeamId or "NoTeam")
			self.TeamIndicator.Text = string.format("Team: %s", teamId)
			if teamId == "TeamRed" then
				self.TeamIndicator.TextColor3 = Color3.fromRGB(255, 80, 80)
			elseif teamId == "TeamBlue" then
				self.TeamIndicator.TextColor3 = Color3.fromRGB(80, 160, 255)
			end
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
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return UIController
