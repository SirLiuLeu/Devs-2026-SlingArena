--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)

type Context = {
	EventBus: any,
	Services: any,
	Remotes: Folder,
}

local SlingshotService = {}
SlingshotService.__index = SlingshotService

function SlingshotService.new(context: Context)
	local self = setmetatable({}, SlingshotService)
	self._context = context
	self._chargeStartedAt = {} :: { [Player]: number }
	return self
end

function SlingshotService:Init()
	local startChargeRemote = self._context.Remotes:FindFirstChild("StartCharge") :: RemoteEvent
	local releaseChargeRemote = self._context.Remotes:FindFirstChild("ReleaseCharge") :: RemoteEvent

	startChargeRemote.OnServerEvent:Connect(function(player)
		self:StartCharge(player)
	end)

	releaseChargeRemote.OnServerEvent:Connect(function(player, direction: Vector3)
		self:ReleaseCharge(player, direction)
	end)
end

function SlingshotService:StartCharge(player: Player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end
	self._chargeStartedAt[player] = os.clock()
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
end

function SlingshotService:ReleaseCharge(player: Player, direction: Vector3)
	local playerStateService = self._context.Services.PlayerStateService
	local state = playerStateService:GetState(player)
	local startedAt = self._chargeStartedAt[player]
	if not state or not startedAt or not state.IsAlive then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not root then
		return
	end

	local buff = playerStateService:GetBuff(player)
	local chargeBuff = buff and buff.ChargeBoost or 0
	local chargeSpeedBonus = math.min(state.Attributes.ChargeSpeed * SlingshotConfig.ChargeSpeedPerPoint, 0.25)
	local elapsed = (os.clock() - startedAt) * (1 + chargeSpeedBonus + chargeBuff)
	local chargeRatio = math.clamp(elapsed / SlingshotConfig.MaxChargeTime, 0, 1)
	local launchPowerBonus = 1 + math.min(state.Attributes.LaunchPower * SlingshotConfig.LaunchPowerPerPoint, BalanceConfig.MaxDamageBonusFromAttributes)
	local sizeModifier = math.max(0.6, math.log(state.Size + 1))
	local launchForce = SlingshotConfig.BaseLaunchForce * chargeRatio * sizeModifier * launchPowerBonus

	local safeDirection = direction
	if safeDirection.Magnitude < 0.01 then
		safeDirection = root.CFrame.LookVector
	else
		safeDirection = safeDirection.Unit
	end

	local velocity = safeDirection * launchForce
	if velocity.Magnitude > BalanceConfig.MaxVelocity then
		velocity = velocity.Unit * BalanceConfig.MaxVelocity
	end

	root.AssemblyLinearVelocity = velocity
	playerStateService:UpdateVelocity(player, velocity)
	playerStateService:SetCharging(player, false, chargeRatio)
	self._chargeStartedAt[player] = nil
	self._context.EventBus:Fire("PlayerLaunched", player, chargeRatio, velocity)
end

return SlingshotService
