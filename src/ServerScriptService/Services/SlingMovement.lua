--!strict

local SlingMovement = {}
SlingMovement.__index = SlingMovement

export type Options = {
	moveSpeed: number?,
	acceleration: number?,
	deceleration: number?,
	forceMultiplier: number?,
}

local DEFAULT_SPEED = 16
local DEFAULT_ACCELERATION = 18
local DEFAULT_DECELERATION = 24
local DEFAULT_FORCE_MULTIPLIER = 3500

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

local function getOrCreateLinearVelocity(root: BasePart, attachment: Attachment, forceMultiplier: number): LinearVelocity
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if linearVelocity and linearVelocity:IsA("LinearVelocity") then
		linearVelocity.Attachment0 = attachment
		linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
		linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		linearVelocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		linearVelocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		linearVelocity.MaxForce = math.max(root.AssemblyMass * forceMultiplier, 1000)
		return linearVelocity
	end

	linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "LinearVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	linearVelocity.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	linearVelocity.MaxForce = math.max(root.AssemblyMass * forceMultiplier, 1000)
	linearVelocity.PlaneVelocity = Vector2.zero
	linearVelocity.Enabled = false
	linearVelocity.Parent = root
	return linearVelocity
end

function SlingMovement.new(root: BasePart, options: Options?)
	local opts = options or {}
	local self = setmetatable({}, SlingMovement)
	self._root = root
	self._speed = math.max(0, opts.moveSpeed or DEFAULT_SPEED)
	self._acceleration = math.max(0.01, opts.acceleration or DEFAULT_ACCELERATION)
	self._deceleration = math.max(0.01, opts.deceleration or DEFAULT_DECELERATION)
	self._planarVelocity = Vector3.zero

	local attachment = getOrCreateAttachment(root)
	self._linearVelocity = getOrCreateLinearVelocity(root, attachment, opts.forceMultiplier or DEFAULT_FORCE_MULTIPLIER)
	return self
end

function SlingMovement:SetSpeed(speed: number)
	self._speed = math.max(0, speed)
end

function SlingMovement:Move(direction: Vector3, dt: number?)
	local stepDt = math.max(dt or (1 / 60), 1 / 240)
	local planarInput = Vector3.new(direction.X, 0, direction.Z)
	local desiredVelocity = Vector3.zero

	if planarInput.Magnitude > 0.001 then
		desiredVelocity = planarInput.Unit * self._speed
	end

	local current = self._planarVelocity
	local accel = if desiredVelocity.Magnitude > current.Magnitude then self._acceleration else self._deceleration
	local alpha = 1 - math.exp(-accel * stepDt)
	local nextVelocity = current:Lerp(desiredVelocity, alpha)

	if nextVelocity.Magnitude < 0.05 then
		nextVelocity = Vector3.zero
	end

	self._planarVelocity = nextVelocity
	self._linearVelocity.PlaneVelocity = Vector2.new(nextVelocity.X, nextVelocity.Z)
	self._linearVelocity.Enabled = nextVelocity.Magnitude > 0.001
end

function SlingMovement:Stop()
	self._planarVelocity = Vector3.zero
	self._linearVelocity.PlaneVelocity = Vector2.zero
	self._linearVelocity.Enabled = false

	local rootVelocity = self._root.AssemblyLinearVelocity
	self._root.AssemblyLinearVelocity = Vector3.new(0, rootVelocity.Y, 0)
end

function SlingMovement:DisableLocomotion(preserveMomentum: boolean?)
	self._planarVelocity = Vector3.zero
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
