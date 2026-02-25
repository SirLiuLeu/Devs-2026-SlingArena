--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local SlingService = {}
SlingService.__index = SlingService

function SlingService.new(context)
	local self = setmetatable({}, SlingService)
	self._context = context
	return self
end

function SlingService:Init()
	local aimRemote = self._context.Remotes:WaitForChild("SlingAimRemote")
	aimRemote.OnServerEvent:Connect(function(player, direction)
		self:UpdateAim(player, direction)
	end)
end

function SlingService:UpdateAim(player, direction)
	if typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.001 then
		return
	end
	local planar = Vector3.new(direction.X, 0, direction.Z)
	if planar.Magnitude < 0.001 then
		return
	end
	self._context.Services.PlayerService:SetAim(player, planar.Unit)
end

function SlingService:Launch(player, direction, chargeRatio)
	local playerService = self._context.Services.PlayerService
	if not playerService:IsAlive(player) then
		return false
	end

	local root = playerService:GetRoot(player)
	if not root then
		return false
	end

	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		local state = playerService:GetState(player)
		planarDirection = state and state.LastAim or Vector3.new(0, 0, -1)
	end

	local force = planarDirection.Unit * (Config.BaseForce + chargeRatio * Config.MaxBonusForce)
	root.AssemblyLinearVelocity = Vector3.zero

	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if not linearVelocity or not linearVelocity:IsA("LinearVelocity") then
		return false
	end

	linearVelocity.VectorVelocity = force
	linearVelocity.Enabled = true
	task.delay(0.25, function()
		if linearVelocity.Parent then
			linearVelocity.Enabled = false
		end
	end)

	local align = root:FindFirstChild("AlignOrientation")
	if align and align:IsA("AlignOrientation") then
		align.CFrame = CFrame.lookAt(Vector3.zero, planarDirection.Unit)
	end

	return true
end

return SlingService
