--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local SkillService = {}
SkillService.__index = SkillService

type Context = {
	Services: any,
	Remotes: Folder,
	EventBus: any,
}

function SkillService.new(context: Context)
	local self = setmetatable({}, SkillService)
	self._context = context
	self._specialUpgradePlayers = {} :: { [Player]: boolean }
	return self
end

function SkillService:Init()
			self._specialUpgradePlayers[player] = active
		end)
	end

	local consumeHpPotion = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ConsumeHpPotion) :: RemoteEvent?
	if consumeHpPotion then
		consumeHpPotion.OnServerEvent:Connect(function(player: Player)
			self._context.Services.PlayerStateService:TryConsumeHpPotion(player)
		end)
	end

	self._context.EventBus:On("PlayerDied", function(player: Player)
		self._specialUpgradePlayers[player] = false
	end)
	RunService.Heartbeat:Connect(function(dt)
		self:_stepPassiveHeal(dt)
	end)
end

function SkillService:_stepPassiveHeal(dt: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local state = self._context.Services.PlayerStateService:GetState(player)
		local root = self._context.Services.PlayerService:GetRoot(player)
		if state and root and state.IsAlive and state.CurrentHP > 0 and state.CurrentHP < state.MaxHP then
			local horizontalSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			local stillEnough = horizontalSpeed <= BalanceConfig.PassiveHealMovementThreshold
			local safeDelay = (os.clock() - (state.LastDamageTime or 0)) >= BalanceConfig.PassiveHealDelay
			local canHeal = stillEnough and safeDelay and not state.IsCharging and state.MovementState ~= "Launched"
			if canHeal then
				local healPerSecond = state.MaxHP * BalanceConfig.PassiveHealPercent
				self._context.Services.PlayerStateService:Heal(player, healPerSecond * dt)
			end
		end
	end
end

function SkillService:IsSpecialUpgradeActive(player: Player): boolean
	return self._specialUpgradePlayers[player] == true
end

return SkillService
