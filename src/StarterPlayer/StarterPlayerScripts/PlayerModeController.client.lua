--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local setPlayerModeRemote = remotes:WaitForChild(RemoteContracts.Names.SetPlayerMode) :: RemoteEvent

local HumanLauncherToggleController = {}
HumanLauncherToggleController.__index = HumanLauncherToggleController

local LauncherMode = GameStates.PlayerMode.Launcher
local HumanMode = GameStates.PlayerMode.Human
local SelectedPlayerMode = HumanMode
local ActivePlayerMode = HumanMode
player:SetAttribute("SelectedPlayerMode", SelectedPlayerMode)
player:SetAttribute("ActivePlayerMode", ActivePlayerMode)

local HUMAN_OFF = "Off"
local LAUNCHER_ON = "On"

local modeColors = {
	[LAUNCHER_ON] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 75, 78)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(178, 54, 56)),
	}),
	[HUMAN_OFF] = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(79, 255, 144)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 145, 82)),
	}),
}

local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local function findHumanLauncherToggle(): Frame?
	local mainHud = playerGui:FindFirstChild("MainHUD")
	local root = mainHud and mainHud:FindFirstChild("Root")
	local toggle = root and root:FindFirstChild("HumanLauncherToggle")
	return if toggle and toggle:IsA("Frame") then toggle else nil
end

function HumanLauncherToggleController.new()
	local self = setmetatable({}, HumanLauncherToggleController)
	self.ToggleFrame = nil :: Frame?
	self.Background = nil :: GuiObject?
	self.Gradient = nil :: UIGradient?
	self.Options = nil :: Instance?
	self.CurrentVisualState = nil :: string?
	self.Connections = {} :: { RBXScriptConnection }
	return self
end

function HumanLauncherToggleController:_disconnect()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

function HumanLauncherToggleController:_setVisibleForState()
	local toggleFrame = self.ToggleFrame
	if not toggleFrame then
		return
	end
	local locationState = player:GetAttribute("LocationState")
	local roundState = player:GetAttribute("RoundState")
	local inLobby = locationState == GameStates.SessionState.Lobby
	local roundIsLobby = roundState == GameStates.MapRoundState.Lobby
	toggleFrame.Visible = inLobby and roundIsLobby
end

function HumanLauncherToggleController:_applyVisual(optionName: string)
	local background = self.Background
	local gradient = self.Gradient
	local options = self.Options
	if not (background and gradient and options) then
		self.CurrentVisualState = nil
		return
	end
	if self.CurrentVisualState == optionName then
		self:_setVisibleForState()
		return
	end
	self.CurrentVisualState = optionName
	local targetOption = options:FindFirstChild(optionName)
	if targetOption and targetOption:IsA("GuiObject") then
		TweenService:Create(background, tweenInfo, {
			Position = targetOption.Position,
			AnchorPoint = targetOption.AnchorPoint,
		}):Play()
	end
	gradient.Color = modeColors[optionName]
	self:_setVisibleForState()
end

function HumanLauncherToggleController:RefreshFromActiveMode()
	local visualMode = if ActivePlayerMode == LauncherMode then LAUNCHER_ON else HUMAN_OFF
	self:_applyVisual(visualMode)
end

function HumanLauncherToggleController:SetSelectedPlayerMode(modeName: string, notifyServer: boolean)
	if modeName ~= LauncherMode and modeName ~= HumanMode then
		modeName = HumanMode
	end
	SelectedPlayerMode = modeName
	player:SetAttribute("SelectedPlayerMode", SelectedPlayerMode)
	self:RefreshFromActiveMode()
	if notifyServer then
		setPlayerModeRemote:FireServer(SelectedPlayerMode)
	end
end

function HumanLauncherToggleController:Bind()
	self:_disconnect()
	local toggleFrame = findHumanLauncherToggle()
	if not toggleFrame then
		return
	end
	self.ToggleFrame = toggleFrame
	self.Background = toggleFrame:WaitForChild("Background") :: GuiObject
	self.Gradient = (self.Background :: Instance):WaitForChild("Gradient") :: UIGradient
	self.Options = toggleFrame:WaitForChild("Options")
	self.CurrentVisualState = nil
	local offClick = self.Options:WaitForChild("Off"):WaitForChild("Click") :: GuiButton
	local onClick = self.Options:WaitForChild("On"):WaitForChild("Click") :: GuiButton
	table.insert(self.Connections, offClick.Activated:Connect(function()
		self:SetSelectedPlayerMode(HumanMode, true)
	end))
	table.insert(self.Connections, onClick.Activated:Connect(function()
		self:SetSelectedPlayerMode(LauncherMode, true)
	end))
	self:RefreshFromActiveMode()
	table.insert(self.Connections, player:GetAttributeChangedSignal("LocationState"):Connect(function()
		self:_setVisibleForState()
	end))
	table.insert(self.Connections, player:GetAttributeChangedSignal("RoundState"):Connect(function()
		self:_setVisibleForState()
	end))
	self:_setVisibleForState()
end

local controller = HumanLauncherToggleController.new()
controller:Bind()

playerGui.ChildAdded:Connect(function(child)
	if child.Name == "MainHUD" then
		task.defer(function()
			controller:Bind()
		end)
	end
end)

local function applyStatePayload(state: any)
	if type(state) ~= "table" then
		return
	end
	if typeof(state.SelectedPlayerMode) == "string" then
		SelectedPlayerMode = state.SelectedPlayerMode
		player:SetAttribute("SelectedPlayerMode", SelectedPlayerMode)
	end
	if typeof(state.ActivePlayerMode) == "string" then
		ActivePlayerMode = state.ActivePlayerMode
		player:SetAttribute("ActivePlayerMode", ActivePlayerMode)
	end
	if typeof(state.LocationState) == "string" then
		player:SetAttribute("LocationState", state.LocationState)
	end
	controller:RefreshFromActiveMode()
	controller:_setVisibleForState()
end

local stateUpdateRemote = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent
stateUpdateRemote.OnClientEvent:Connect(applyStatePayload)

local uiStateUpdateRemote = remotes:WaitForChild(RemoteContracts.Names.UIStateUpdate) :: RemoteEvent
uiStateUpdateRemote.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		player:SetAttribute("RoundState", payload.State)
		controller:_setVisibleForState()
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		controller:Bind()
	end)
end)
