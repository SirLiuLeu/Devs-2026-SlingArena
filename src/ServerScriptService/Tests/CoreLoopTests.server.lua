--!strict

local function runTest(name: string, testFn: () -> ())
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[CoreLoopTests] PASS %s", name))
	else
		warn(string.format("[CoreLoopTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function assertEqual(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(string.format("%s | expected=%s actual=%s", message, tostring(expected), tostring(actual)))
	end
end

local function assertTrue(condition: boolean, message: string)
	if not condition then
		error(message)
	end
end

local function buildMockPlayer()
	return {
		UserId = 4001,
		Name = "CoreLoopTester",
		Level = 1,
		Exp = 0,
		Position = Vector3.new(0, 0, 0),
		Velocity = Vector3.zero,
		CollisionCount = 0,
	}
end

local function buildMockSling()
	return {
		MaxCharge = 1,
		MinLaunchSpeed = 12,
		MaxLaunchSpeed = 72,
	}
end

local function buildMockFood(expValue: number)
	return {
		Exp = expValue,
		Consumed = false,
	}
end

local function spawnPlayer(player)
	player.Position = Vector3.new(0, 5, 0)
	player.Velocity = Vector3.zero
end

local function simulateMovement(player, inputDirection: Vector3, deltaTime: number)
	player.Position = player.Position + (inputDirection * deltaTime)
end

local function chargeAndLaunch(player, sling, chargeRatio: number, aimDirection: Vector3)
	local clampedRatio = math.clamp(chargeRatio, 0, sling.MaxCharge)
	local launchSpeed = sling.MinLaunchSpeed + (sling.MaxLaunchSpeed - sling.MinLaunchSpeed) * clampedRatio
	local direction = if aimDirection.Magnitude > 0 then aimDirection.Unit else Vector3.new(1, 0, 0)
	player.Velocity = direction * launchSpeed
	return launchSpeed
end

local function simulateCollision(player, surfaceNormal: Vector3)
	local reflected = player.Velocity - (2 * player.Velocity:Dot(surfaceNormal) * surfaceNormal)
	player.Velocity = reflected
	player.CollisionCount += 1
end

local function consumeFoodAndApplyProgress(player, food)
	if food.Consumed then
		return
	end

	food.Consumed = true
	player.Exp += food.Exp
	local requiredExp = 100
	while player.Exp >= requiredExp do
		player.Exp -= requiredExp
		player.Level += 1
	end
end

local function testPlayerSpawnAndBasicMovement()
	-- Setup
	local player = buildMockPlayer()

	-- Action
	spawnPlayer(player)
	simulateMovement(player, Vector3.new(10, 0, 0), 0.5)

	-- Assertion
	assertEqual(player.Position, Vector3.new(5, 5, 0), "Player should spawn then move on input")
	assertEqual(player.Velocity, Vector3.zero, "Movement simulation should not force launch velocity")
end

local function testChargeLaunchFlowChangesVelocity()
	-- Setup
	local player = buildMockPlayer()
	local sling = buildMockSling()

	-- Action
	local launchSpeed = chargeAndLaunch(player, sling, 0.5, Vector3.new(0, 0, -1))

	-- Assertion
	assertTrue(launchSpeed > sling.MinLaunchSpeed, "Charge should scale launch speed")
	assertTrue(player.Velocity.Magnitude > 0, "Launch must assign non-zero velocity")
	assertEqual(player.Velocity.Unit, Vector3.new(0, 0, -1), "Launch direction should follow aim")
end

local function testCollisionProducesExpectedEffect()
	-- Setup
	local player = buildMockPlayer()
	player.Velocity = Vector3.new(30, 0, 0)

	-- Action
	simulateCollision(player, Vector3.new(-1, 0, 0))

	-- Assertion
	assertEqual(player.CollisionCount, 1, "Collision should be tracked")
	assertTrue(player.Velocity.X < 0, "Velocity should reflect after collision")
end

local function testFoodConsumptionLevelsPlayerUp()
	-- Setup
	local player = buildMockPlayer()
	local food = buildMockFood(120)

	-- Action
	consumeFoodAndApplyProgress(player, food)

	-- Assertion
	assertTrue(food.Consumed, "Food should be marked consumed")
	assertEqual(player.Level, 2, "Player should level up after enough food exp")
	assertEqual(player.Exp, 20, "Excess exp should carry over after level up")
end

runTest("Spawn_And_Movement", testPlayerSpawnAndBasicMovement)
runTest("Charge_Launch_ChangesVelocity", testChargeLaunchFlowChangesVelocity)
runTest("Collision_Reflection", testCollisionProducesExpectedEffect)
runTest("Food_Consumption_LevelUp", testFoodConsumptionLevelsPlayerUp)

print("[CoreLoopTests] all checks passed")
