--!strict

local RemoteContracts = {}

RemoteContracts.Names = {
	MoveRequest = "MoveRequest",
	StartCharge = "StartCharge",
	ReleaseCharge = "ReleaseCharge",
	GameplayFeedback = "GameplayFeedback",
	StateUpdate = "StateUpdate",
	UIStateUpdate = "UIStateUpdate",
	MatchStateUpdate = "MatchStateUpdate",
	RoundResult = "RoundResult",
	PopupMessage = "PopupMessage",
	JoinArena = "JoinArena",
	LeaveArena = "LeaveArena",
	TeleportRequest = "TeleportRequest",
	DebugSpawnFood = "DebugSpawnFood",
	DebugResetSling = "DebugResetSling",
	ConsumeHpPotion = "ConsumeHpPotion",
}

RemoteContracts.Validators = {
	[RemoteContracts.Names.MoveRequest] = function(inputState: any): boolean
		if typeof(inputState) ~= "table" then
			return false
		end
		local allowedKeys = {
			W = true,
			A = true,
			S = true,
			D = true,
		}
		for key, value in pairs(inputState) do
			if not allowedKeys[key] or typeof(value) ~= "boolean" then
				return false
			end
		end
		return typeof(inputState.W) == "boolean"
			and typeof(inputState.A) == "boolean"
			and typeof(inputState.S) == "boolean"
			and typeof(inputState.D) == "boolean"
	end,
	[RemoteContracts.Names.StartCharge] = function(aimTarget: any): boolean
		return typeof(aimTarget) == "Vector3"
	end,
	[RemoteContracts.Names.ReleaseCharge] = function(aimTarget: any): boolean
		return typeof(aimTarget) == "Vector3"
	end,
	[RemoteContracts.Names.TeleportRequest] = function(mapName: any, spawnName: any): boolean
		return typeof(mapName) == "string" and typeof(spawnName) == "string"
	end,
	[RemoteContracts.Names.ConsumeHpPotion] = function(): boolean
		return true
	end,
}

function RemoteContracts.Validate(remoteName: string, ...: any): boolean
	local validator = RemoteContracts.Validators[remoteName]
	if not validator then
		return true
	end
	return validator(...)
end

return RemoteContracts
