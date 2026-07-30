--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function getOrCreateLinearVelocity(root: BasePart, attachment: Attachment): LinearVelocity
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if linearVelocity and linearVelocity:IsA("LinearVelocity") then
		linearVelocity.Attachment0 = attachment
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		linearVelocity.PrimaryTangentAxis = Vector3.xAxis
		linearVelocity.SecondaryTangentAxis = Vector3.zAxis
		linearVelocity.ForceLimitsEnabled = true
		linearVelocity.MaxForce = if PhysicsConfig.Stability.UseInfiniteForce then math.huge else PhysicsConfig.Movement.MaxForce
		return linearVelocity
	end

	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "LinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.xAxis
	linearVelocity.SecondaryTangentAxis = Vector3.zAxis
	linearVelocity.ForceLimitsEnabled = true
	linearVelocity.MaxForce = if PhysicsConfig.Stability.UseInfiniteForce then math.huge else PhysicsConfig.Movement.MaxForce
	linearVelocity.PlaneVelocity = Vector2.zero
	linearVelocity.Enabled = false
	linearVelocity.Parent = root
	return linearVelocity
end

function LauncherMovement.new(root: BasePart)
	local self = setmetatable({}, LauncherMovement)
	self._root = root
	self._speed = math.max(0, PhysicsConfig.Movement.MoveSpeed)

	local attachment = getOrCreateAttachment(root)
	self._linearVelocity = getOrCreateLinearVelocity(root, attachment)
	return self
end

function LauncherMovement:SetSpeed(speed: number)
	self._speed = math.max(0, speed)
end

function LauncherMovement:Move(direction: Vector3, _dt: number?)
	local planarInput = Vector3.new(direction.X, 0, direction.Z)
	local desiredVelocity = Vector3.zero
	if planarInput.Magnitude > PhysicsConfig.Movement.InputDeadzone then
		desiredVelocity = planarInput.Unit * self._speed
	end

	self._linearVelocity.PlaneVelocity = Vector2.new(desiredVelocity.X, desiredVelocity.Z)
	self._linearVelocity.Enabled = desiredVelocity.Magnitude > PhysicsConfig.Movement.InputDeadzone
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

function LauncherMovement:BrakeKnockback(inputDirection: Vector3, dt: number)
	self._linearVelocity.PlaneVelocity = Vector2.zero
	self._linearVelocity.Enabled = false

	local velocity = self._root.AssemblyLinearVelocity
	local planarVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	if planarVelocity.Magnitude <= PhysicsConfig.Movement.InputDeadzone then
		return
	end

	local planarInput = Vector3.new(inputDirection.X, 0, inputDirection.Z)
	local inputUnit = if planarInput.Magnitude > PhysicsConfig.Movement.InputDeadzone then planarInput.Unit else Vector3.zero
	local velocityUnit = planarVelocity.Unit
	local dot = if inputUnit.Magnitude > 0 then inputUnit:Dot(velocityUnit) else 0
	local decayPerSecond = if dot < 0 then PhysicsConfig.Collision.KnockbackRecoveryBrakePerSecond else PhysicsConfig.Collision.KnockbackRecoveryCoastPerSecond
	local decay = math.exp(-math.max(decayPerSecond, 0) * math.max(dt, 0))
	local adjustedPlanar = planarVelocity * decay

	if dot > 0 then
		adjustedPlanar += inputUnit * PhysicsConfig.Collision.KnockbackRecoveryAssistAcceleration * dot * math.max(dt, 0)
	end

	self._root.AssemblyLinearVelocity = Vector3.new(adjustedPlanar.X, velocity.Y, adjustedPlanar.Z)
end

function LauncherMovement:Destroy()
	self:Stop()
end

return LauncherMovement
