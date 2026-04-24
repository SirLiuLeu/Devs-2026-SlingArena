--!strict

local PhysicsConfig = require(script.Parent.Parent.Config.PhysicsConfig)

local SlingMovement = {}
SlingMovement.__index = SlingMovement

local function getOrCreateAttachment(root: BasePart): Attachment
	local attachment = root:FindFirstChild("SlingMovementAttachment")
	if attachment and attachment:IsA("Attachment") then
		return attachment
	end

	attachment = Instance.new("Attachment")
	attachment.Name = "SlingMovementAttachment"
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

function SlingMovement.new(root: BasePart)
	local self = setmetatable({}, SlingMovement)
	self._root = root
	self._speed = math.max(0, PhysicsConfig.Movement.MoveSpeed)

	local attachment = getOrCreateAttachment(root)
	self._linearVelocity = getOrCreateLinearVelocity(root, attachment)
	return self
end

function SlingMovement:SetSpeed(speed: number)
	self._speed = math.max(0, speed)
end

function SlingMovement:Move(direction: Vector3, _dt: number?)
	local planarInput = Vector3.new(direction.X, 0, direction.Z)
	local desiredVelocity = Vector3.zero
	if planarInput.Magnitude > 0.001 then
		desiredVelocity = planarInput.Unit * self._speed
	end

	self._linearVelocity.PlaneVelocity = Vector2.new(desiredVelocity.X, desiredVelocity.Z)
	self._linearVelocity.Enabled = desiredVelocity.Magnitude > 0.001
end

function SlingMovement:Stop()
	self._linearVelocity.PlaneVelocity = Vector2.zero
	self._linearVelocity.Enabled = false

	local rootVelocity = self._root.AssemblyLinearVelocity
	self._root.AssemblyLinearVelocity = Vector3.new(0, rootVelocity.Y, 0)
end

function SlingMovement:DisableLocomotion(preserveMomentum: boolean?)
	self._linearVelocity.PlaneVelocity = Vector2.zero
	self._linearVelocity.Enabled = false

	if preserveMomentum then
		return
	end

	local rootVelocity = self._root.AssemblyLinearVelocity
	self._root.AssemblyLinearVelocity = Vector3.new(0, rootVelocity.Y, 0)
end

function SlingMovement:Destroy()
	self:Stop()
end

return SlingMovement
