--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)

type Context = {
	EventBus: any,
	Services: any,
}

local SlingshotService = {}
SlingshotService.__index = SlingshotService

function SlingshotService.new(context: Context)
	local self = setmetatable({}, SlingshotService)
	self._context = context
	self._origin = {}
	return self
end

function SlingshotService:Init() end

function SlingshotService:Launch(player: Player, direction: Vector3, chargeRatio: number): boolean
	local playerStateService = self._context.Services.PlayerStateService
	local state = playerStateService:GetState(player)
	if not state or not state.IsAlive then return false end
	local root = self._context.Services.PlayerService:GetRoot(player)
	if not root then return false end

	local safeDirection = if direction.Magnitude < 0.01 then root.CFrame.LookVector else direction.Unit
	local pullDistance = math.clamp(chargeRatio, 0, 1) * SlingshotConfig.SlingConfig.MaxPullDistance
	local force = pullDistance * SlingshotConfig.SlingConfig.ForceMultiplier
	local velocity = safeDirection * force
	if velocity.Magnitude > BalanceConfig.MaxVelocity then
		velocity = velocity.Unit * BalanceConfig.MaxVelocity
	end

	if not self._origin[player] then
		self._origin[player] = root.Position
	end
	local range = SlingshotConfig.SlingConfig.MaxShootRange + (state.Attributes.Range * 10)
	if (root.Position - self._origin[player]).Magnitude >= range then
		velocity *= 0.4
	end

	root:ApplyImpulse(velocity * root.AssemblyMass)
	playerStateService:UpdateVelocity(player, velocity)
	self._context.EventBus:Fire("PlayerLaunched", player, chargeRatio, velocity)
	return true
end

return SlingshotService
