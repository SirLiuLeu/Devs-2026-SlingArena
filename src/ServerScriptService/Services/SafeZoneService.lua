--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local SafeZoneService = {}
SafeZoneService.__index = SafeZoneService

function SafeZoneService.new(context)
	local self = setmetatable({}, SafeZoneService)
	self._context = context
	self._zoneRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.ZoneUpdate) :: RemoteEvent?
	self._center = Vector3.new(0, 0, 0)
	self._startRadius = Config.MaxArenaRadius
	self._minRadius = math.max(40, Config.MaxArenaRadius * 0.2)
	self._radius = self._startRadius
	self._shrinkDuration = 8 * 60
	self._tickAccumulator = 0
	self._elapsed = 0
	return self
end

function SafeZoneService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

function SafeZoneService:GetRadius(): number
	return self._radius
end

function SafeZoneService:GetCenter(): Vector3
	return self._center
end

function SafeZoneService:_step(dt: number)
	self._elapsed += dt
	local progress = math.clamp(self._elapsed / self._shrinkDuration, 0, 1)
	self._radius = self._startRadius - ((self._startRadius - self._minRadius) * progress)

	self._tickAccumulator += dt
	if self._tickAccumulator < 1 then
		return
	end
	local tickTime = self._tickAccumulator
	self._tickAccumulator = 0

	local dpsPercent = 1 + (9 * progress)
	for _, player in ipairs(Players:GetPlayers()) do
		local root = self._context.Services.PlayerService:GetRoot(player)
		local state = self._context.Services.PlayerStateService:GetState(player)
		if root and state and state.IsAlive then
			local planarDistance = (Vector3.new(root.Position.X, 0, root.Position.Z) - self._center).Magnitude
			if planarDistance > self._radius then
				local damage = (state.MaxHP * (dpsPercent / 100)) * tickTime
				self._context.Services.DamagePipelineService:ApplyDamage(player, damage, nil, nil)
			end
		end
	end

	if self._zoneRemote then
		self._zoneRemote:FireAllClients({
			Phase = "Active",
			Radius = self._radius,
			Center = self._center,
			DpsPercent = dpsPercent,
			NextShrinkAt = os.clock() + 1,
		})
	end
end

return SafeZoneService
