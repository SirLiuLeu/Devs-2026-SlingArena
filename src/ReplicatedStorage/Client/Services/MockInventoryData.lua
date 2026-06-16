--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)
local SlingStatResolver = require(ReplicatedStorage.Shared.Utils.SlingStatResolver)

local MockInventoryData = {}

local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, nested in pairs(value) do
		result[key] = clone(nested)
	end
	return result
end

local function buildSlingInstanceId(definitionId: string, index: number): string
	return string.format("mock_%s_%02d", definitionId, index)
end

function MockInventoryData.GetInventoryState()
	local ownedSlings = {}
	local equippedSlingInstanceId = nil
	local initialSlingIds = { "NormalSling", "FireSling", "HealSling", "PoisonSling" }
	for index, definitionId in ipairs(initialSlingIds) do
		local slingDef = SlingConfig.GetById(definitionId)
		if slingDef then
			local instanceId = buildSlingInstanceId(definitionId, index)
			local level = if definitionId == SlingConfig.DefaultSlingId then 3 else 1
			local star = if definitionId == SlingConfig.DefaultSlingId then 2 else 1
			ownedSlings[instanceId] = {
				definitionId = definitionId,
				star = star,
				level = level,
				acquiredAt = 1_700_000_000 + index,
				name = slingDef.name,
				icon = slingDef.iconId or slingDef.icon,
				stats = SlingStatResolver.Resolve(definitionId, star, level),
			}
			if definitionId == SlingConfig.DefaultSlingId then
				equippedSlingInstanceId = instanceId
			end
		else
			warn(string.format("[MOCK_INVENTORY_DATA] Sling id missing in SlingConfig: %s", definitionId))
		end
	end

	return {
		OwnedSlings = clone(ownedSlings),
		EquippedSlingInstanceId = equippedSlingInstanceId,
		SlingCapacity = 40,
	}
end

return MockInventoryData
