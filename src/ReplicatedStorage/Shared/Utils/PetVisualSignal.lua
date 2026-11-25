--!strict

-- Lightweight replicated signals for client-side Pet animations.
-- Player attributes replicate to nearby clients without adding RemoteEvents.
local PetVisualSignal = {}

PetVisualSignal.AttributeName = "PetCastSignal"
PetVisualSignal.DanceAttributeName = "PetDanceSignal"

local function incrementSequence(player: Player, attributeName: string): number
	local currentValue = player:GetAttribute(attributeName)
	local currentSequence = tonumber(currentValue) or 0
	local nextSequence = math.max(0, math.floor(currentSequence)) + 1
	player:SetAttribute(attributeName, nextSequence)
	return nextSequence
end

function PetVisualSignal.TriggerCast(player: Player, abilityId: string)
	if typeof(abilityId) ~= "string" or abilityId == "" then
		return
	end

	local currentValue = player:GetAttribute(PetVisualSignal.AttributeName)
	local sequence = 0
	if type(currentValue) == "string" then
		local _, currentSequence = string.match(currentValue, "^([^|]+)|(%d+)$")
		sequence = tonumber(currentSequence) or 0
	end

	player:SetAttribute(PetVisualSignal.AttributeName, string.format("%s|%d", abilityId, sequence + 1))
end

function PetVisualSignal.TriggerDance(player: Player)
	incrementSequence(player, PetVisualSignal.DanceAttributeName)
end

function PetVisualSignal.DecodeCast(value: any): string?
	if type(value) ~= "string" then
		return nil
	end

	local abilityId = string.match(value, "^([^|]+)|%d+$")
	if abilityId == nil or abilityId == "" then
		return nil
	end
	return abilityId
end

return PetVisualSignal
