--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataService = require(ServerScriptService.Services.PlayerDataService)
local MockProvider = require(ServerScriptService.Services.DataProviders.MockProvider)
local EventBus = require(ServerScriptService.Services.Infrastructure.EventBus)
local EquipmentService = require(ServerScriptService.Services.EquipmentService.EquipmentService)
local EquipmentEffectService = require(ServerScriptService.Services.EquipmentEffectService.EquipmentEffectService)
local EquipmentStatResolver = require(ReplicatedStorage.Shared.Utils.EquipmentStatResolver)
local EquipmentUpgradeConfig = require(ReplicatedStorage.Shared.Config.EquipmentUpgradeConfig)

local function runTest(name: string, testFn: () -> ())
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[EquipmentFoundationTests] PASS %s", name))
	else
		warn(string.format("[EquipmentFoundationTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function assertTrue(condition: boolean, message: string)
	if not condition then error(message) end
end

local function assertEqual(actual: any, expected: any, message: string)
	if actual ~= expected then error(string.format("%s | expected=%s actual=%s", message, tostring(expected), tostring(actual))) end
end

local function assertNear(actual: number, expected: number, epsilon: number, message: string)
	if math.abs(actual - expected) > epsilon then
		error(string.format("%s | expected=%s actual=%s", message, tostring(expected), tostring(actual)))
	end
end

local function player(id: number, name: string)
	return { UserId = id, Name = name, DisplayName = name } :: any
end

local function buildContext()
	local context = { EventBus = EventBus.new(), Services = {}, ServiceRegistry = nil }
	local data = PlayerDataService.new(context, MockProvider.new())
	context.Services.PlayerDataService = data
	context.Services.PlayerStateService = { RecalculateCount = 0, RecalculateDerivedStats = function(self) self.RecalculateCount += 1 end }
	return context, data
end

runTest("default and normalized equipment data", function()
	local context, dataService = buildContext()
	local p = player(7101, "EquipData")
	local data = dataService:LoadPlayer(p)
	assertTrue(type(data.OwnedEquipment) == "table", "OwnedEquipment defaults to a table")
	assertTrue(type(data.EquippedEquipment) == "table", "EquippedEquipment defaults to a table")
	data.OwnedEquipment.keep = { definitionId = "training_core", level = "3", rarity = "Rare", pity = { spins = 2 } }
	data.OwnedEquipment.drop = { level = 1 }
	data.EquippedEquipment.Core = "keep"
	data.EquippedEquipment.Module = "missing"
	dataService:_ensureEquipmentData(data)
	assertEqual(data.OwnedEquipment.keep.level, 3, "valid instance level is normalized and preserved")
	assertEqual(data.OwnedEquipment.drop, nil, "invalid owned equipment is removed")
	assertEqual(data.EquippedEquipment.Core, "keep", "valid equipped instance survives normalization")
	assertEqual(data.EquippedEquipment.Module, nil, "equipped references to unowned instances are removed")
	context.EventBus:Destroy()
end)

runTest("fail-closed ownership equip", function()
	local context, dataService = buildContext()
	local service = EquipmentService.new(context)
	local p = player(7102, "EquipOwner")
	dataService:LoadPlayer(p)
	local ok, instanceId = service:Grant(p, "training_core", { instanceId = "owned-core" })
	assertTrue(ok and instanceId == "owned-core", "grant creates owned instance")
	local equipOk = service:Equip(p, "owned-core")
	assertTrue(equipOk, "owned instance equips")
	local unownedOk = service:Equip(p, "unowned-core")
	assertTrue(not unownedOk, "unowned instance fails")
	local invalidOk = service:Equip(p, "")
	assertTrue(not invalidOk, "invalid instance ID fails")
	local definitionOk = service:Equip(p, "training_core")
	assertTrue(not definitionOk, "definition ID cannot bypass ownership")
	context.EventBus:Destroy()
end)

runTest("stat resolver applies equipped additive and multiplicative modifiers only", function()
	local owned = {
		core1 = { definitionId = "training_core" },
		module1 = { definitionId = "damage_module" },
		charm1 = { definitionId = "swift_charm" },
	}
	local equipped = { Core = "core1", Module = "module1" }
	local result = EquipmentStatResolver.Resolve({ maxHP = 1000, baseDamage = 100, damageMultiplier = 2, moveSpeed = 10 }, owned, equipped)
	assertEqual(result.maxHP, 1100, "equipped additive HP applies")
	assertEqual(result.baseDamage, 150, "equipped additive damage applies")
	assertNear(result.damageMultiplier, 2.1, 0.0001, "equipped multiplicative damage applies")
	assertEqual(result.moveSpeed, 10, "owned but unequipped move speed modifier is ignored")
	equipped.Charm = "charm1"
	local withCharm = EquipmentStatResolver.Resolve({ maxHP = 1000, baseDamage = 100, damageMultiplier = 2, moveSpeed = 10 }, owned, equipped)
	assertEqual(withCharm.moveSpeed, 11, "multiple equipped slots aggregate")
end)

runTest("effects activate, isolate players, and share heartbeat", function()
	local context, dataService = buildContext()
	local effectService = EquipmentEffectService.new(context)
	local callbacks = {}
	local signal = { Connect = function(_, callback) table.insert(callbacks, callback); return { Disconnect = function() end } end }
	effectService._heartbeatSignal = signal
	effectService:Init()
	local equipmentService = EquipmentService.new(context)
	local p1 = player(7103, "EffectOne")
	local p2 = player(7104, "EffectTwo")
	dataService:LoadPlayer(p1); dataService:LoadPlayer(p2)
	equipmentService:Grant(p1, "training_core", { instanceId = "p1-core" })
	equipmentService:Grant(p1, "damage_module", { instanceId = "p1-module" })
	equipmentService:Grant(p2, "training_core", { instanceId = "p2-core" })
	equipmentService:Equip(p1, "p1-core"); equipmentService:Equip(p1, "p1-module"); equipmentService:Equip(p2, "p2-core")
	assertEqual(effectService:GetActiveEffectCount(p1), 2, "one player can have multiple active equipment effects")
	assertEqual(effectService:GetActiveEffectCount(p2), 1, "other player's effects are isolated")
	assertEqual(effectService:GetHeartbeatConnectionCount(), 1, "one shared heartbeat connection is used")
	assertEqual(#callbacks, 1, "heartbeat is connected once")
	callbacks[1](0.016)
	equipmentService:Unequip(p1, "Core")
	assertEqual(effectService:GetActiveEffectCount(p1), 1, "unequip deactivates only matching effect")
	assertEqual(effectService:GetActiveEffectCount(p2), 1, "unequip does not affect other player")
	context.EventBus:Destroy()
end)

runTest("equipment upgrade spends canonical PlayerData diamonds", function()
	local context, dataService = buildContext()
	local service = EquipmentService.new(context)
	local p = player(7105, "Economy")
	dataService:LoadPlayer(p)
	dataService:GrantReward(p, { Diamonds = 1000 }, "Test")
	service:Grant(p, "training_core", { instanceId = "upgrade-core" })
	local cost = EquipmentUpgradeConfig.GetUpgradeCost(1)
	local ok = service:Upgrade(p, "upgrade-core")
	assertTrue(ok, "upgrade succeeds when PlayerData diamonds can pay")
	assertEqual(dataService:GetDiamonds(p), 1000 - cost, "upgrade debits PlayerDataService diamonds")
	context.Services.PlayerStateService.RuntimeDiamonds = 999999
	local poor = player(7106, "PoorEconomy")
	dataService:LoadPlayer(poor)
	service:Grant(poor, "training_core", { instanceId = "poor-core" })
	local poorOk = service:Upgrade(poor, "poor-core")
	assertTrue(not poorOk, "runtime-only diamond fields cannot bypass PlayerData ledger")
	context.EventBus:Destroy()
end)
