--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local SlingService = {}
SlingService.__index = SlingService

function SlingService.new(context)
	local self = setmetatable({}, SlingService)
	self._context = context
	self._lastShotAt = {}
	self._projectilesFolder = Workspace:FindFirstChild("Projectiles")
	if not self._projectilesFolder then
		self._projectilesFolder = Instance.new("Folder")
		self._projectilesFolder.Name = "Projectiles"
		self._projectilesFolder.Parent = Workspace
	end
	return self
end

local function clampPlanarDirection(direction: Vector3, fallback: Vector3): Vector3
	local planar = Vector3.new(direction.X, 0, direction.Z)
	if planar.Magnitude < 0.001 then
		return fallback.Unit
	end
	return planar.Unit
end

function SlingService:Init()
	local aimRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.SlingAim)
	aimRemote.OnServerEvent:Connect(function(player, direction)
		self:UpdateAim(player, direction)
	end)

	local releaseRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.SlingRelease)
	releaseRemote.OnServerEvent:Connect(function(player, direction, finalCharge)
		self:HandleRelease(player, direction, finalCharge)
	end)
end

function SlingService:UpdateAim(player, direction)
	if not RemoteContracts.Validate(RemoteContracts.Names.SlingAim, direction) then
		return
	end
	if direction.Magnitude < 0.001 then
		return
	end
	self._context.Services.PlayerService:SetAim(player, Vector3.new(direction.X, 0, direction.Z).Unit)
end

function SlingService:HandleRelease(player, direction, finalCharge)
	if not RemoteContracts.Validate(RemoteContracts.Names.SlingRelease, direction, finalCharge) then
		return
	end

	local playerService = self._context.Services.PlayerService
	if not playerService:IsAlive(player) then
		return
	end

	local now = os.clock()
	local lastShot = self._lastShotAt[player] or 0
	if now - lastShot < Config.ShotCooldown then
		return
	end

	local aimDirection = clampPlanarDirection(direction, playerService:GetAim(player))
	local charge = math.clamp(finalCharge, 0, Config.MaxCharge)
	local chargeRatio = if Config.MaxCharge > 0 then (charge / Config.MaxCharge) else 0
	local force = Config.BaseForce + chargeRatio * Config.MaxExtraForce

	local root = playerService:GetRoot(player)
	if not root then
		return
	end

	local projectile = Instance.new("Part")
	projectile.Name = "SlingProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Size = Vector3.new(1.5, 1.5, 1.5)
	projectile.Material = Enum.Material.Neon
	projectile.Color = Color3.fromRGB(255, 226, 120)
	projectile.TopSurface = Enum.SurfaceType.Smooth
	projectile.BottomSurface = Enum.SurfaceType.Smooth
	projectile.CollisionGroup = "Players"
	projectile.Position = root.Position + (aimDirection * 4) + Vector3.new(0, 2, 0)
	projectile.Parent = self._projectilesFolder

	projectile:ApplyImpulse(aimDirection * force * projectile.AssemblyMass)
	self._lastShotAt[player] = now
	playerService:SetAim(player, aimDirection)

	task.delay(8, function()
		if projectile.Parent then
			projectile:Destroy()
		end
	end)
end

return SlingService
