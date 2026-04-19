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
	self.MatchStatusLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.StatusLabel)
	self.TimerLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.TimerLabel)
	self.AlivePlayersLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.AlivePlayersLabel)
	self.WinnerPopup = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.WinnerPopup)
	self.DebugFoodButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugFoodButton)
	self.DebugResetButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugResetButton)
	self.DailyButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.DailyButton)
	self.InventoryButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.InventoryButton)
	self.OnlineRewardButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.OnlineRewardButton)
	self.SettingButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SettingButton)
	self.SpinButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SpinButton)
	self.ShopButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.ShopButton)
	self.QuickHpButton = resolveGuiButton(playerGui, ProjectTreeSpec.UI.MainHub.QuickHP)
	self.QuickHpCountLabel = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MainHub.QuickHPCountLabel)
	self.HomeButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.HomeButton)
	self.TeamIndicator = resolveTextLabel(playerGui, ProjectTreeSpec.UI.MainHub.TeamIndicator)
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

	if not self.JoinButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.JoinButton, "TextButton") end
	if not self.LeaveButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.LeaveButton, "TextButton") end
	if not self.MatchStatusLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.StatusLabel, "TextLabel") end
	if not self.TimerLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.TimerLabel, "TextLabel") end
	if not self.AlivePlayersLabel then warnMissingUiPath(ProjectTreeSpec.UI.Match.AlivePlayersLabel, "TextLabel") end
	if not self.WinnerPopup then warnMissingUiPath(ProjectTreeSpec.UI.Match.WinnerPopup, "TextLabel") end
	if not self.DebugFoodButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugFoodButton, "TextButton") end
	if not self.DebugResetButton then warnMissingUiPath(ProjectTreeSpec.UI.Lobby.DebugResetButton, "TextButton") end
	if not self.DailyButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.DailyButton, "TextButton") end
	if not self.InventoryButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.InventoryButton, "TextButton") end
	if not self.OnlineRewardButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.OnlineRewardButton, "TextButton") end
	if not self.SettingButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SettingButton, "TextButton") end
	if not self.SpinButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SpinButton, "TextButton") end
	if not self.ShopButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.ShopButton, "TextButton") end
	if not self.QuickHpButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHP, "GuiButton") end
	if not self.HomeButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.HomeButton, "TextButton") end
	if not (self.QuickHpCountLabel and self.QuickHpCountLabel:IsA("TextLabel")) then
		warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHPCountLabel, "TextLabel")
	end
	if not self.TeamIndicator then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.TeamIndicator, "TextLabel") end
	if not self.PanelMap.DailyLogin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.DailyLogin, "ScreenGui") end
	if not self.PanelMap.Shop then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Shop, "ScreenGui") end
	if not self.PanelMap.Inventory then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Inventory, "ScreenGui") end
	if not self.PanelMap.OnlineReward then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.OnlineReward, "ScreenGui") end
	if not self.PanelMap.Settings then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Settings, "ScreenGui") end
	if not self.PanelMap.Spin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.Spin, "ScreenGui") end

	return self
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
			self.ClientService:RequestConsumeHpPotion()
		end))
	end

	local stateConnection = self.ClientService:BindStateUpdate(function(state)
		if self.QuickHpCountLabel and self.QuickHpCountLabel:IsA("TextLabel") then
			self.QuickHpCountLabel.Text = string.format("x%d", math.max(0, math.floor(state.HpPotions or 0)))
		end
		if self.InventoryDataProvider then
			self.InventoryDataProvider:SetFromState(state)
		end
		local currentExp = math.max(0, math.floor(state.Exp or 0))
		local level = math.max(1, math.floor(state.Level or 1))
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
		if self.TeamIndicator then
			local teamId = tostring(state.TeamId or "Solo")
			self.TeamIndicator.Text = string.format("Team: %s", teamId)
		end
	end)
	if stateConnection then
		table.insert(self.Connections, stateConnection)
	end

	local uiStateConnection = self.ClientService:BindUIStateUpdate(function(payload)
		if self.MatchStatusLabel then self.MatchStatusLabel.Text = string.format("Match: %s", tostring(payload.State or GameStates.Round.Lobby)) end
		if self.TimerLabel then self.TimerLabel.Text = string.format("CountdownTimer: %d", math.floor(payload.CountdownTimer or payload.TimeLeft or 0)) end
		if self.AlivePlayersLabel then self.AlivePlayersLabel.Text = string.format("PlayerCount: %d (alive %d)", payload.PlayerCount or 0, payload.AlivePlayers or 0) end
		if self.WinnerPopup and (payload.State or "") ~= GameStates.Round.RoundEnd then
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
