--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)

local PlayerModeState = {}

PlayerModeState.HumanMode = GameStates.PlayerMode.Human
PlayerModeState.LauncherMode = GameStates.PlayerMode.Launcher
PlayerModeState.SettledAttribute = "ModeSettledToken"
PlayerModeState.SETTLE_DELAY_SECONDS = 0.08

function PlayerModeState.GetActiveMode(player: Player, state: { [string]: any }?): string
	local mode = if state and typeof(state.ActivePlayerMode) == "string" then state.ActivePlayerMode else player:GetAttribute("ActivePlayerMode")
	return if mode == PlayerModeState.LauncherMode then PlayerModeState.LauncherMode else PlayerModeState.HumanMode
end

function PlayerModeState.IsLauncherMode(player: Player, state: { [string]: any }?): boolean
	return PlayerModeState.GetActiveMode(player, state) == PlayerModeState.LauncherMode
end

function PlayerModeState.ApplyPayload(player: Player, state: any)
	if type(state) ~= "table" then
		return
	end
	if typeof(state.SelectedPlayerMode) == "string" then
		player:SetAttribute("SelectedPlayerMode", state.SelectedPlayerMode)
	end
	if typeof(state.ActivePlayerMode) == "string" then
		player:SetAttribute("ActivePlayerMode", state.ActivePlayerMode)
	end
	if typeof(state.LocationState) == "string" then
		player:SetAttribute("LocationState", state.LocationState)
	end
end

function PlayerModeState.BindSettled(player: Player, callback: (string) -> ()): RBXScriptConnection
	local token = 0
	local function schedule()
		token += 1
		local current = token
		task.delay(PlayerModeState.SETTLE_DELAY_SECONDS, function()
			if current ~= token then return end
			player:SetAttribute(PlayerModeState.SettledAttribute, current)
			callback(PlayerModeState.GetActiveMode(player, nil))
		end)
	end
	local connection = player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(schedule)
	schedule()
	return connection
end

return PlayerModeState
