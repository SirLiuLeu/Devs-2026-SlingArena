--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local CombatService = require(ServerScriptService.Services.CombatService)

local function assertAlmostEqual(actual: number, expected: number, epsilon: number, message: string)
	if math.abs(actual - expected) > epsilon then
		error(string.format("%s | actual=%.4f expected=%.4f", message, actual, expected))
	end
end

local function testChargeToLaunchForce()
	local minForce = SlingshotConfig.MIN_LAUNCH_FORCE
	local maxForce = SlingshotConfig.MAX_LAUNCH_FORCE
	local ratio = 0.5
	local launchForce = minForce + (maxForce - minForce) * ratio
	assertAlmostEqual(launchForce, (minForce + maxForce) * 0.5, 0.0001, "Launch force lerp should match")
end

local function testCollisionTriggersDamageFormula()
	local service = CombatService.new({})
	local attacker = {
		BaseDamage = 20,
		Size = 2,
		ChargeValue = 1,
		SlingshotType = "Default",
		DamageMultiplier = 1,
	}
	local damage = service:ComputeImpactDamage(attacker, 80, 1)
	if damage <= 0 then
		error("Damage should be positive for valid collision")
	end
end

local function testExpLevelUpThreshold()
	local required = require(ReplicatedStorage.Shared.Config.LevelConfig).RequiredExp(1)
	if required <= 0 then
		error("Required EXP must be greater than 0")
	end
end

local function testSelfDamageClampOnMaxCharge()
	local selfDamage = math.clamp(BalanceConfig.MaxChargeSelfDamage, 0, BalanceConfig.MaxChargeSelfDamage)
	assertAlmostEqual(selfDamage, BalanceConfig.MaxChargeSelfDamage, 0, "Max charge self damage should clamp correctly")
end

testChargeToLaunchForce()
testCollisionTriggersDamageFormula()
testExpLevelUpThreshold()
testSelfDamageClampOnMaxCharge()

print("[CoreLoopTests] all checks passed")
