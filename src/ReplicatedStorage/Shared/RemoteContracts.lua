--!strict

local RemoteContracts = {}

RemoteContracts.Names = {
	ChargeStart = "ChargeStartRemote",
	ChargeRelease = "ChargeReleaseRemote",
	StateUpdate = "StateUpdate",
	UIStateUpdate = "UIStateUpdate",
	AttributeUpgrade = "AttributeUpgrade",
	ActivateSkill = "ActivateSkill",
	RequestRespawn = "RequestRespawn",
	RequestMatchBuff = "RequestMatchBuff",
	MatchStateUpdate = "MatchStateUpdate",
	RoundResult = "RoundResult",
	PopupMessage = "PopupMessage",
	PurchaseRespawn = "PurchaseRespawn",
	PurchaseMatchBuff = "PurchaseMatchBuff",
	PrestigeReset = "PrestigeReset",
	ToggleSpecialUpgrade = "ToggleSpecialUpgrade",
	JoinArena = "JoinArena",
	LeaveArena = "LeaveArena",
}

RemoteContracts.Validators = {
	[RemoteContracts.Names.ChargeStart] = function(direction: any): boolean
		return typeof(direction) == "Vector3"
	end,
	[RemoteContracts.Names.ChargeRelease] = function(pullVector: any): boolean
		return typeof(pullVector) == "Vector3"
	end,
	[RemoteContracts.Names.AttributeUpgrade] = function(attributeName: any): boolean
		return typeof(attributeName) == "string"
	end,
	[RemoteContracts.Names.RequestRespawn] = function(respawnType: any): boolean
		return typeof(respawnType) == "string"
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
