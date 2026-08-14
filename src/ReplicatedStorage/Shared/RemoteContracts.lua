--!strict

local RemoteContracts = {}

RemoteContracts.Names = {
	MoveRequest = "MoveRequest",
	StartCharge = "StartCharge",
	ReleaseCharge = "ReleaseCharge",
	CancelCharge = "CancelCharge",
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
	Plus1Minute = "Plus1Minute",
	EndRound = "EndRound",
	MatchSummaryUpdate = "MatchSummaryUpdate",
	TeleportRequest = "TeleportRequest",
	DebugSpawnFood = "DebugSpawnFood",
	DebugResetLauncher = "DebugResetLauncher",
	ConsumeHpPotion = "ConsumeHpPotion",
	ReportFoodHit = "ReportFoodHit",
	ReportCollision = "ReportCollision",
	ApplySelfBounce = "ApplySelfBounce",
	ApplyKnockback = "ApplyKnockback",
	ClientDoLaunch = "ClientDoLaunch",
	ReportLaunchStopped = "ReportLaunchStopped",
	KnockbackReplication = "KnockbackReplication",
	MatchScoreboardUpdate = "MatchScoreboardUpdate",
	GlobalTop100Update = "GlobalTop100Update",
	SetPlayerMode = "SetPlayerMode",
	ClockSyncRequest = "ClockSyncRequest",
	ClockSyncResponse = "ClockSyncResponse",
	QuestUpdate = "QuestUpdate",
	QuestClaim = "QuestClaim",
	Notification = "Notification",
	EquipEquipment = "EquipEquipment",
	UnequipEquipment = "UnequipEquipment",
	UpgradeEquipment = "UpgradeEquipment",
	RequestEquipmentGrant = "RequestEquipmentGrant",
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
	[RemoteContracts.Names.CancelCharge] = function(): boolean
		return true
	end,
	[RemoteContracts.Names.RequestLaunch] = function(payload: any): boolean
		return type(payload) == "table" and typeof(payload.aimTarget) == "Vector3"
			and (payload.launchSpeed == nil or typeof(payload.launchSpeed) == "number")
			and (payload.launchDirection == nil or typeof(payload.launchDirection) == "Vector3")
			and (payload.clientTimestamp == nil or typeof(payload.clientTimestamp) == "number")
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
	[RemoteContracts.Names.Plus1Minute] = function(): boolean
		return true
	end,
	[RemoteContracts.Names.EndRound] = function(): boolean
		return true
	end,
	[RemoteContracts.Names.ReportFoodHit] = function(payload: any): boolean
		if type(payload) ~= "table" then
			return false
		end
		if typeof(payload.foodId) ~= "string" or #payload.foodId == 0 then
			return false
		end
		if payload.launchId ~= nil and typeof(payload.launchId) ~= "string" then
			return false
		end
		if payload.hitType ~= nil and typeof(payload.hitType) ~= "string" then
			return false
		end
		if payload.currPos ~= nil and typeof(payload.currPos) ~= "Vector3" then
			return false
		end
		if payload.velocity ~= nil and typeof(payload.velocity) ~= "Vector3" then
			return false
		end
		if payload.observedSpeed ~= nil and typeof(payload.observedSpeed) ~= "number" then
			return false
		end
		return true
	end,
	[RemoteContracts.Names.ReportCollision] = function(payload: any): boolean
		if type(payload) ~= "table" then
			return false
		end
		if typeof(payload.targetUserId) ~= "number" then
			return false
		end
		if typeof(payload.timestamp) ~= "number" then
			return false
		end
		if typeof(payload.launchId) ~= "string" or #payload.launchId == 0 then
			return false
		end
		if typeof(payload.sweepStart) ~= "Vector3" or typeof(payload.sweepEnd) ~= "Vector3" then
			return false
		end
		if typeof(payload.hitPosition) ~= "Vector3" then
			return false
		end
		if payload.surfaceNormal ~= nil and typeof(payload.surfaceNormal) ~= "Vector3" then
			return false
		end
		if payload.velocity ~= nil and typeof(payload.velocity) ~= "Vector3" then
			return false
		end
		if payload.observedSpeed ~= nil and typeof(payload.observedSpeed) ~= "number" then
			return false
		end
		return true
	end,
	[RemoteContracts.Names.SetPlayerMode] = function(modeName: any): boolean
		return modeName == "Launcher" or modeName == "Human"
	end,
	[RemoteContracts.Names.ClockSyncRequest] = function(clientSendTime: any): boolean
		return typeof(clientSendTime) == "number"
	end,
	[RemoteContracts.Names.QuestClaim] = function(questId: any): boolean
		return typeof(questId) == "string" and #questId > 0 and #questId <= 80
	end,
	[RemoteContracts.Names.EquipEquipment] = function(instanceId: any): boolean
		return typeof(instanceId) == "string" and #instanceId > 0 and #instanceId <= 128
	end,
	[RemoteContracts.Names.UnequipEquipment] = function(slotType: any): boolean
		return (typeof(slotType) == "number" and slotType >= 1 and slotType <= 3) or (typeof(slotType) == "string" and #slotType > 0 and #slotType <= 64)
	end,
	[RemoteContracts.Names.UpgradeEquipment] = function(instanceId: any): boolean
		return typeof(instanceId) == "string" and #instanceId > 0 and #instanceId <= 128
	end,
	[RemoteContracts.Names.RequestEquipmentGrant] = function(definitionId: any): boolean
		return typeof(definitionId) == "string" and #definitionId > 0 and #definitionId <= 128
	end,
	[RemoteContracts.Names.ReportLaunchStopped] = function(payload: any): boolean
		if type(payload) ~= "table" then
			return false
		end
		if typeof(payload.launchId) ~= "string" or #payload.launchId == 0 then
			return false
		end
		if payload.observedSpeed ~= nil and typeof(payload.observedSpeed) ~= "number" then
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
