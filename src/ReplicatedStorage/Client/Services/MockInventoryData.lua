--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local LauncherStatResolver = require(ReplicatedStorage.Shared.Utils.LauncherStatResolver)

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

local function buildLauncherInstanceId(definitionId: string, index: number): string
	return string.format("mock_%s_%02d", definitionId, index)
end

function MockInventoryData.GetInventoryState()
	local ownedLaunchers = {}
	local equippedLauncherInstanceId = nil
	local initialLauncherIds = { "NormalLauncher", "FireLauncher", "HealLauncher", "PoisonLauncher" }
	for index, definitionId in ipairs(initialLauncherIds) do
		local launcherDef = LauncherConfig.GetById(definitionId)
		if launcherDef then
			local instanceId = buildLauncherInstanceId(definitionId, index)
			local level = if definitionId == LauncherConfig.DefaultLauncherId then 3 else 1
			local star = if definitionId == LauncherConfig.DefaultLauncherId then 2 else 1
			ownedLaunchers[instanceId] = {
				definitionId = definitionId,
				star = star,
				level = level,
				acquiredAt = 1_700_000_000 + index,
				name = launcherDef.name,
				icon = launcherDef.iconId or launcherDef.icon,
				stats = LauncherStatResolver.Resolve(definitionId, star, level),
			}
			if definitionId == LauncherConfig.DefaultLauncherId then
				equippedLauncherInstanceId = instanceId
			end
		else
			warn(string.format("[MOCK_INVENTORY_DATA] Launcher id missing in LauncherConfig: %s", definitionId))
		end
	end

	return {
		OwnedLaunchers = clone(ownedLaunchers),
		EquippedLauncherInstanceId = equippedLauncherInstanceId,
		LauncherCapacity = 40,
	}
end

return MockInventoryData
