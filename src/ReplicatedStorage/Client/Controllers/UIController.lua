--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local MainStatsPopupController = require(ReplicatedStorage.Client.Controllers.MainStatsPopupController)
local InventoryUIController = require(ReplicatedStorage.Client.Controllers.InventoryUIController)
local InventoryDataProvider = require(ReplicatedStorage.Client.Services.InventoryDataProvider)

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
	self.MainStatsPopupController = MainStatsPopupController.new(playerGui, dependencies)
	self.InventoryUIController = InventoryUIController.new(playerGui)
	self.InventoryDataProvider = InventoryDataProvider.GetDefault()

	self.JoinButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.JoinButton)
	self.LeaveButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.LeaveButton)
	self.MatchStatusLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.StatusLabel)
	self.TimerLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.TimerLabel)
	self.AlivePlayersLabel = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.AlivePlayersLabel)
	self.WinnerPopup = resolveTextLabel(playerGui, ProjectTreeSpec.UI.Match.WinnerPopup)
	self.DebugFoodButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugFoodButton)
	self.DebugResetButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.Lobby.DebugResetButton)
	self.SlingStatsButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SlingStatsButton)
	self.DailyButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.DailyButton)
	self.InventoryButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.InventoryButton)
	self.OnlineRewardButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.OnlineRewardButton)
	self.SettingButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SettingButton)
	self.SpinButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.SpinButton)
	self.QuickHpButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.QuickHP)
	self.HomeButton = resolveTextButton(playerGui, ProjectTreeSpec.UI.MainHub.HomeButton)

	self.PanelMap = {
		SlingStats = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.SlingStats),
		DailyLogin = resolveScreenGui(playerGui, ProjectTreeSpec.UI.MainHub.Panels.DailyLogin),
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
	if not self.SlingStatsButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SlingStatsButton, "TextButton") end
	if not self.DailyButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.DailyButton, "TextButton") end
	if not self.InventoryButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.InventoryButton, "TextButton") end
	if not self.OnlineRewardButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.OnlineRewardButton, "TextButton") end
	if not self.SettingButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SettingButton, "TextButton") end
	if not self.SpinButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.SpinButton, "TextButton") end
	if not self.QuickHpButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.QuickHP, "TextButton") end
	if not self.HomeButton then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.HomeButton, "TextButton") end
	if not self.PanelMap.SlingStats then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.SlingStats, "ScreenGui") end
	if not self.PanelMap.DailyLogin then warnMissingUiPath(ProjectTreeSpec.UI.MainHub.Panels.DailyLogin, "ScreenGui") end
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
	if self.InventoryDataProvider then
		table.insert(self.Connections, self.InventoryDataProvider:BindChanged(function(snapshot)
			if self.InventoryUIController then
				self.InventoryUIController:RefreshWithData(snapshot)
			end
		end))
		self.InventoryDataProvider:GiveTestSling()
		self.InventoryDataProvider:GiveTestItem()
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
	if self.SlingStatsButton then
		table.insert(self.Connections, self.SlingStatsButton.MouseButton1Click:Connect(function()
			self:ToggleMainHubPanel("SlingStats")
		end))
	end
	if self.DailyButton then
		table.insert(self.Connections, self.DailyButton.MouseButton1Click:Connect(function()
			self:ShowMainHubPanel("DailyLogin")
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
		if self.QuickHpButton then
			self.QuickHpButton.Text = string.format("HP x%d", math.max(0, math.floor(state.HpPotions or 0)))
		end
		if self.InventoryDataProvider then
			self.InventoryDataProvider:SetFromState(state)
		end
		if self.MainStatsPopupController then
			self.MainStatsPopupController:ApplyState(state)
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
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	if self.MainStatsPopupController then
		self.MainStatsPopupController:Destroy()
	end
end

return UIController
