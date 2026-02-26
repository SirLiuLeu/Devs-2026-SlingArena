--!strict

local RemoteContracts = {}

RemoteContracts.Names = {
	SlingAim = "SlingAimRemote",
	SlingRelease = "SlingReleaseRemote",
	StateUpdate = "StateUpdate",
	AttributeUpgrade = "AttributeUpgrade",
	ActivateSkill = "ActivateSkill",
	RequestRespawn = "RequestRespawn",
	RequestMatchBuff = "RequestMatchBuff",
}

RemoteContracts.Validators = {
	[RemoteContracts.Names.SlingAim] = function(direction: any): boolean
		return typeof(direction) == "Vector3"
	end,
	[RemoteContracts.Names.SlingRelease] = function(direction: any, chargeRatio: any): boolean
		return typeof(direction) == "Vector3" and typeof(chargeRatio) == "number"
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
