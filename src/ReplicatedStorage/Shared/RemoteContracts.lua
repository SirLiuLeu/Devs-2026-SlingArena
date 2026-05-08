--!strict

local RemoteContracts = {}

RemoteContracts.Names = {
	MoveRequest = "MoveRequest",
	StartCharge = "StartCharge",
	ReleaseCharge = "ReleaseCharge",
	RequestLaunch = "RequestLaunch",
	AbilityTrigger = "AbilityTrigger",
	GameplayFeedback = "GameplayFeedback",
	StateUpdate = "StateUpdate",
	UIStateUpdate = "UIStateUpdate",
	AttributeUpgrade = "AttributeUpgrade",
	RequestRespawn = "RequestRespawn",
	MatchStateUpdate = "MatchStateUpdate",
	RoundResult = "RoundResult",
	PopupMessage = "PopupMessage",
	ZoneUpdate = "ZoneUpdate",
	PurchaseRespawn = "PurchaseRespawn",
	PurchaseMatchBuff = "PurchaseMatchBuff",
	PrestigeReset = "PrestigeReset",
	JoinArena = "JoinArena",
	LeaveArena = "LeaveArena",
	StartSafeZone = "StartSafeZone",
	TeleportRequest = "TeleportRequest",
	DebugSpawnFood = "DebugSpawnFood",
	DebugResetSling = "DebugResetSling",
	ConsumeHpPotion = "ConsumeHpPotion",
	ReportFoodHit = "ReportFoodHit",
	ReportCollision = "ReportCollision",
}

RemoteContracts.Validators = {
	[RemoteContracts.Names.MoveRequest] = function(directionInput: any): boolean
		return typeof(directionInput) == "Vector3"
	end,
	[RemoteContracts.Names.StartCharge] = function(aimTarget: any): boolean
		return typeof(aimTarget) == "Vector3"
	end,
	[RemoteContracts.Names.ReleaseCharge] = function(aimTarget: any): boolean
		return typeof(aimTarget) == "Vector3"
	end,
	[RemoteContracts.Names.RequestLaunch] = function(payload: any): boolean
		return type(payload) == "table" and typeof(payload.aimTarget) == "Vector3"
	end,
	[RemoteContracts.Names.AbilityTrigger] = function(payload: any): boolean
		return type(payload) == "table"
	end,
	[RemoteContracts.Names.AttributeUpgrade] = function(attributeName: any): boolean
		return typeof(attributeName) == "string"
	end,
	[RemoteContracts.Names.RequestRespawn] = function(respawnType: any): boolean
		return typeof(respawnType) == "string"
	end,
	[RemoteContracts.Names.TeleportRequest] = function(mapName: any, spawnName: any): boolean
		return typeof(mapName) == "string" and typeof(spawnName) == "string"
	end,
	[RemoteContracts.Names.ConsumeHpPotion] = function(): boolean
		return true
	end,
	[RemoteContracts.Names.ReportFoodHit] = function(payload: any): boolean
		if type(payload) ~= "table" then
			return false
		end
		if typeof(payload.foodId) ~= "string" or #payload.foodId == 0 then
			return false
		end
		if payload.hitType ~= nil and typeof(payload.hitType) ~= "string" then
			return false
		end
		if payload.currPos ~= nil and typeof(payload.currPos) ~= "Vector3" then
			return false
		end
		return true
	end,
	[RemoteContracts.Names.ReportCollision] = function(payload: any): boolean
		if type(payload) ~= "table" or typeof(payload.targetType) ~= "string" then
			return false
		end
		if payload.targetType == "Player" then
			if typeof(payload.targetUserId) ~= "number" then
				return false
			end
		elseif payload.targetType == "Trap" then
			if typeof(payload.targetPosition) ~= "Vector3" then
				return false
			end
		else
			return false
		end
		if payload.currPos ~= nil and typeof(payload.currPos) ~= "Vector3" then
			return false
		end
		if payload.velocity ~= nil and typeof(payload.velocity) ~= "Vector3" then
			return false
		end
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
