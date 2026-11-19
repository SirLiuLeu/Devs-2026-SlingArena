--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local LauncherMovement = require(script.Parent.Parent.Services.LauncherService.LauncherMovement)

local function assertEqual(actual: any, expected: any, message: string)
	if actual ~= expected then
		error(string.format("%s | expected=%s actual=%s", message, tostring(expected), tostring(actual)))
	end
end

local function assertNear(actual: number, expected: number, message: string, tolerance: number?)
	if math.abs(actual - expected) > (tolerance or 0.001) then
		error(string.format("%s | expected=%.4f actual=%.4f", message, expected, actual))
	end
end

local function runTest(name: string, testFn: () -> ())
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[LauncherMovementTests] PASS %s", name))
	else
		warn(string.format("[LauncherMovementTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function createTestScene(includeWall: boolean): (Folder, BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "LauncherMovementTestScene"
	folder.Parent = Workspace

	local character = Instance.new("Model")
	character.Name = "TestLauncher"
	character.Parent = folder

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.CFrame = CFrame.new(0, 10, 0)
	root.Anchored = true
	root.CanCollide = true
	root.CanQuery = true
	root.Parent = character
	character.PrimaryPart = root

	if includeWall then
		local wall = Instance.new("Part")
		wall.Name = "TestWall"
		wall.Size = Vector3.new(0.5, 12, 20)
		wall.CFrame = CFrame.new(2, 10, 0)
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanQuery = true
		wall.Parent = folder
	end

	return folder, root
end

runTest("LinearVelocity_Uses_Finite_PerAxis_Plane_Force", function()
	local folder, root = createTestScene(false)
	local movement = LauncherMovement.new(root)
	local linearVelocity = root:FindFirstChildOfClass("LinearVelocity")

	assertEqual(linearVelocity ~= nil, true, "Launcher LinearVelocity exists")
	assertEqual(linearVelocity.VelocityConstraintMode, Enum.VelocityConstraintMode.Plane, "Plane constraint mode")
	assertEqual(linearVelocity.PrimaryTangentAxis, Vector3.xAxis, "Primary tangent uses world X")
	assertEqual(linearVelocity.SecondaryTangentAxis, Vector3.zAxis, "Secondary tangent uses world Z")
	assertEqual(linearVelocity.RelativeTo, Enum.ActuatorRelativeTo.World, "World-space plane")
	assertEqual(linearVelocity.ForceLimitsEnabled, true, "Force limits enabled")
	assertEqual(linearVelocity.ForceLimitMode, Enum.ForceLimitMode.PerAxis, "Per-axis force limiting")
	assertNear(linearVelocity.MaxPlanarAxesForce.X, PhysicsConfig.Movement.MaxPlanarAxisForce, "X force cap")
	assertNear(linearVelocity.MaxPlanarAxesForce.Y, PhysicsConfig.Movement.MaxPlanarAxisForce, "Z force cap")
	assertEqual(linearVelocity.MaxPlanarAxesForce.X < math.huge, true, "X force cap is finite")
	assertEqual(linearVelocity.MaxPlanarAxesForce.Y < math.huge, true, "Z force cap is finite")

	movement:Destroy()
	folder:Destroy()
end)

runTest("Movement_Preserves_Both_Planar_Axes_Without_Obstacles", function()
	local folder, root = createTestScene(false)
	local movement = LauncherMovement.new(root)

	movement:Move(Vector3.new(1, 0, 1), 0.1)
	local linearVelocity = root:FindFirstChildOfClass("LinearVelocity")
	assertNear(linearVelocity.PlaneVelocity.X, PhysicsConfig.Movement.MoveSpeed / math.sqrt(2), "Unblocked X velocity")
	assertNear(linearVelocity.PlaneVelocity.Y, PhysicsConfig.Movement.MoveSpeed / math.sqrt(2), "Unblocked Z velocity")
	assertEqual(linearVelocity.Enabled, true, "Unblocked movement remains enabled")

	movement:Destroy()
	folder:Destroy()
end)

runTest("Movement_Projects_Velocity_Along_Wall", function()
	local folder, root = createTestScene(true)
	local movement = LauncherMovement.new(root)

	movement:Move(Vector3.new(1, 0, 1), 0.1)
	local linearVelocity = root:FindFirstChildOfClass("LinearVelocity")
	assertNear(linearVelocity.PlaneVelocity.X, 0, "Velocity into wall is removed", 0.05)
	assertEqual(linearVelocity.PlaneVelocity.Y > 0, true, "Tangential Z velocity is preserved")
	assertEqual(linearVelocity.Enabled, true, "Wall-slide movement remains enabled")

	movement:Destroy()
	folder:Destroy()
end)

runTest("Movement_Stops_When_Directly_Facing_Wall", function()
	local folder, root = createTestScene(true)
	local movement = LauncherMovement.new(root)

	movement:Move(Vector3.xAxis, 0.1)
	local linearVelocity = root:FindFirstChildOfClass("LinearVelocity")
	assertNear(linearVelocity.PlaneVelocity.X, 0, "Blocked X velocity is removed")
	assertNear(linearVelocity.PlaneVelocity.Y, 0, "No tangential velocity remains")
	assertEqual(linearVelocity.Enabled, false, "Fully blocked input does not keep pushing into wall")

	movement:Destroy()
	folder:Destroy()
end)

print("[LauncherMovementTests] all checks passed")
