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
	return self
end

function SlingshotService:Init() end

function SlingshotService:Launch(player: Player, direction: Vector3, chargeRatio: number): boolean
	local playerStateService = self._context.Services.PlayerStateService
	local state = playerStateService:GetState(player)
	if not state or not state.IsAlive then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not root then
		return false
	end

	local safeDirection = direction
	if safeDirection.Magnitude < 0.01 then
		safeDirection = root.CFrame.LookVector
	else
		safeDirection = safeDirection.Unit
	end

	local clampedCharge = math.clamp(chargeRatio, 0, 1)
	local buff = playerStateService:GetBuff(player)
	local launchPowerBonus = 1 + math.min(state.Attributes.LaunchPower * SlingshotConfig.LaunchPowerPerPoint, BalanceConfig.MaxDamageBonusFromAttributes)
	local chargeBoost = 1 + (buff and buff.ChargeBoost or 0)
	local sizeModifier = math.max(0.6, math.log(state.Size + 1))
	local launchForce = SlingshotConfig.BaseLaunchForce * clampedCharge * chargeBoost * sizeModifier * launchPowerBonus

	local velocity = safeDirection * launchForce
	if velocity.Magnitude > BalanceConfig.MaxVelocity then
		velocity = velocity.Unit * BalanceConfig.MaxVelocity
	end

	root.AssemblyLinearVelocity = velocity
	playerStateService:UpdateVelocity(player, velocity)
	playerStateService:SetCharging(player, false, clampedCharge)
	self._context.EventBus:Fire("PlayerLaunched", player, clampedCharge, velocity)
	return true
end

return SlingshotService
