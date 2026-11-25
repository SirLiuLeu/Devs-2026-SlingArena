--!strict

-- Lightweight replicated signal for client-side Pet cast animations.
-- A single changing Player attribute avoids adding another RemoteEvent.
local PetVisualSignal = {}

PetVisualSignal.AttributeName = "PetCastSignal"

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
