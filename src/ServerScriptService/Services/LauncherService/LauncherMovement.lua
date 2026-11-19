--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

local LauncherMovement = {}
LauncherMovement.__index = LauncherMovement

local function getOrCreateAttachment(root: BasePart): Attachment
	local attachment = root:FindFirstChild("LauncherMovementAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	attachment = Instance.new("Attachment")
	attachment.Name = "LauncherMovementAttachment"
	attachment.Parent = root
	return attachment
end

local function createWallCastParams(root: BasePart): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { root.Parent or root }
	params.IgnoreWater = true
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup
	return params
end

local function configureLinearVelocity(linearVelocity: LinearVelocity, attachment: Attachment)
	local maxAxisForce = math.max(0, PhysicsConfig.Movement.MaxPlanarAxisForce)

	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.xAxis
	linearVelocity.SecondaryTangentAxis = Vector3.zAxis
	linearVelocity.ForceLimitsEnabled = true
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	linearVelocity.MaxPlanarAxesForce = Vector2.new(maxAxisForce, maxAxisForce)
end

local function getOrCreateLinearVelocity(root: BasePart, attachment: Attachment): LinearVelocity
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if linearVelocity and linearVelocity:IsA("LinearVelocity") then
		configureLinearVelocity(linearVelocity, attachment)
		return linearVelocity
	end

	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "LinearVelocity"
	configureLinearVelocity(linearVelocity, attachment)
	linearVelocity.PlaneVelocity = Vector2.zero
	linearVelocity.Enabled = false
	linearVelocity.Parent = root
	return linearVelocity
end

local function resolveWallSlideVelocity(
	root: BasePart,
	desiredVelocity: Vector3,
	dt: number,
	params: RaycastParams
): Vector3
	local planarVelocity = Vector3.new(desiredVelocity.X, 0, desiredVelocity.Z)
	local deadzone = PhysicsConfig.Movement.InputDeadzone
	if planarVelocity.Magnitude <= deadzone then
		return Vector3.zero
	end

	local safeDt = math.max(0, dt)
	local probePadding = math.max(0, PhysicsConfig.Movement.WallSlideProbePadding)
	local normalThreshold = math.clamp(PhysicsConfig.Movement.WallSlideNormalThreshold, 0, 1)
	local maxIterations = math.max(1, math.floor(PhysicsConfig.Movement.WallSlideMaxIterations))
	local castCFrame = root.CFrame

	-- Each pass removes only velocity directed into a wall. A second pass can
	-- resolve a second wall at a corner without changing the character's position.
	for _ = 1, maxIterations do
		local speed = planarVelocity.Magnitude
		if speed <= deadzone then
			return Vector3.zero
		end

		local sweepDistance = speed * safeDt + probePadding
		if sweepDistance <= 0 then
			break
		end

		local hit = Workspace:Shapecast(root, planarVelocity.Unit * sweepDistance, params, castCFrame)
		if not hit then
			break
		end

		local planarNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
		if planarNormal.Magnitude < normalThreshold then
			-- Ground and shallow ramp contacts must not be treated as vertical walls.
			break
		end

		local wallNormal = planarNormal.Unit
		local velocityIntoWall = planarVelocity:Dot(wallNormal)
		if velocityIntoWall >= -deadzone then
			break
		end

		planarVelocity -= wallNormal * velocityIntoWall
		if planarVelocity.Magnitude <= deadzone then
			return Vector3.zero
		end

		-- Offset the next sweep slightly away from the wall just resolved so a
		-- perpendicular corner wall can still be detected on the second pass.
		castCFrame += wallNormal * probePadding
	end

	return planarVelocity
end

function LauncherMovement.new(root: BasePart)
	local self = setmetatable({}, LauncherMovement)
	self._root = root
	self._speed = math.max(0, PhysicsConfig.Movement.MoveSpeed)
	self._wallCastParams = createWallCastParams(root)

	local attachment = getOrCreateAttachment(root)
	self._linearVelocity = getOrCreateLinearVelocity(root, attachment)
	return self
end

function LauncherMovement:SetSpeed(speed: number)
	self._speed = math.max(0, speed)
end

function LauncherMovement:Move(direction: Vector3, dt: number?)
	local planarInput = Vector3.new(direction.X, 0, direction.Z)
	local desiredVelocity = Vector3.zero
	if planarInput.Magnitude > PhysicsConfig.Movement.InputDeadzone then
		desiredVelocity = planarInput.Unit * self._speed
	end

	local resolvedVelocity = resolveWallSlideVelocity(
		self._root,
		desiredVelocity,
		dt or 0,
		self._wallCastParams
	)

	self._linearVelocity.PlaneVelocity = Vector2.new(resolvedVelocity.X, resolvedVelocity.Z)
	self._linearVelocity.Enabled = resolvedVelocity.Magnitude > PhysicsConfig.Movement.InputDeadzone
end

function LauncherMovement:Stop()
	self._linearVelocity.PlaneVelocity = Vector2.zero
	self._linearVelocity.Enabled = false
end

function LauncherMovement:DisableLocomotion(preserveMomentum: boolean?)
	self._linearVelocity.PlaneVelocity = Vector2.zero
	self._linearVelocity.Enabled = false

	if preserveMomentum then
		return
	end

	local rootVelocity = self._root.AssemblyLinearVelocity
	local planar = Vector3.new(rootVelocity.X, 0, rootVelocity.Z)
	self._root.AssemblyLinearVelocity = Vector3.new(
		planar.X * PhysicsConfig.Movement.PreservedMomentumScale,
		rootVelocity.Y,
		planar.Z * PhysicsConfig.Movement.PreservedMomentumScale
	)
end

function LauncherMovement:Destroy()
	self:Stop()
end

return LauncherMovement
