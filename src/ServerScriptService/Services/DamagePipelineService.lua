--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)

type Context = {
	Services: any,
	EventBus: any,
	Remotes: Folder,
}

type DamageOptions = {
	SuppressFeedback: boolean?,
	SuppressDeathHandling: boolean?,
	SuppressKnockback: boolean?,
}

local DamagePipelineService = {}
DamagePipelineService.__index = DamagePipelineService

local function getService(context: Context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function isCombatDamageAllowed(context: Context): boolean
	local roundService = getService(context, "RoundService")
	if not roundService then
		return false
	end
	local roundState = roundService:GetState()
	return roundState == GameStates.MapRoundState.EarlyGame or roundState == GameStates.MapRoundState.FinalPhase
end

function DamagePipelineService.new(context: Context)
	local self = setmetatable({}, DamagePipelineService)
	self._context = context
	self._feedbackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent
	return self
end

function DamagePipelineService:Init()
	self._context.EventBus:On("CollisionPlayerHit", function(victim: Player, attacker: Player?, impactSpeed: number, knockbackDirection: Vector3, collisionMeta: any)
		local attackerState = attacker and getService(self._context, "PlayerStateService") and getService(self._context, "PlayerStateService"):GetState(attacker)
		local damage = self:ComputeCollisionDamage(attackerState or {}, impactSpeed, collisionMeta)
		self:ApplyDamage(victim, damage, attacker, knockbackDirection * impactSpeed * 0.35, {
			SuppressKnockback = true,
		})
	end)
	self._context.EventBus:On("TrapCollision", function(player: Player, penalty: number)
		self:ApplyExpPenalty(player, penalty)
	end)
	self._context.EventBus:On("LevelUp", function(player: Player)
		local stateService = getService(self._context, "PlayerStateService")
		if not stateService then
			warn("[DamagePipelineService] PlayerStateService unavailable; level-up growth skipped.")
			return
		end
		stateService:ApplyLevelGrowth(player)
		self:_sendFeedback(player, "LevelUp", {})
	end)
end

function DamagePipelineService:ComputeCollisionDamage(attackerState: any, velocityMagnitude: number, collisionMeta: any?): number
	local baseDamage = math.max(attackerState.BaseDamage or BalanceConfig.BaseDamage or 0, 0)
	local speed = math.max(0, velocityMagnitude)
	local energy = collisionMeta and math.max(0, collisionMeta.LaunchEnergy or 0) or 0
	local elapsed = collisionMeta and math.max(0, collisionMeta.ElapsedLaunchTime or 0) or 0
	local collisions = collisionMeta and math.max(0, collisionMeta.CollisionCount or 0) or 0
	local earlyBonus = 1 / (1 + (elapsed * PhysicsConfig.Damage.LaunchTimeBias))
	local chainPenalty = math.max(0.2, 1 - (collisions * PhysicsConfig.Damage.ChainDecayPerHit))
	local intensity = speed / math.max(PhysicsConfig.Collision.RealHitMinClosingSpeed, 1)
	local energyScalar = energy / math.max(PhysicsConfig.Launch.EnergyMax, 1)
	local damage = baseDamage
		* (1 + energyScalar)
		* earlyBonus
		* chainPenalty
		* (intensity * PhysicsConfig.Damage.CollisionIntensityMultiplier)
		* PhysicsConfig.Damage.BaseMultiplier
	return math.clamp(damage, 0, PhysicsConfig.Damage.Max)
end

function DamagePipelineService:_sendFeedback(player: Player, eventType: string, payload: any)
	if self._feedbackRemote then
		self._feedbackRemote:FireClient(player, {
			EventType = eventType,
			Payload = payload,
		})
	end
end

function DamagePipelineService:ApplyDamage(victim: Player, rawDamage: number, attacker: Player?, knockbackDirection: Vector3?, options: DamageOptions?): boolean
	if attacker and not isCombatDamageAllowed(self._context) then
		return false
	end
	local playerStateService = getService(self._context, "PlayerStateService")
	if not playerStateService then
		warn("[DamagePipelineService] PlayerStateService unavailable; damage skipped.")
		return false
	end
	if playerStateService:IsInvulnerable(victim) or (typeof(playerStateService.HasFlag) == "function" and playerStateService:HasFlag(victim, "Ghost")) then
		return false
	end

	local victimStats = playerStateService:GetFinalStats(victim)
	local armor = victimStats and math.clamp(victimStats.Armor or 0, 0, 0.8) or 0
	local amount = math.clamp(rawDamage * (1 - armor), 0, BalanceConfig.MaxDamagePerHit)
	local teamService = getService(self._context, "TeamService")
	if attacker and teamService and teamService:IsFriendly(attacker, victim) then
		amount = 0
	end
	local didDamage = true
	if amount > 0 then
		didDamage = playerStateService:ApplyDamage(victim, amount)
	end
	if not didDamage then
		return false
	end

	local suppressFeedback = options and options.SuppressFeedback == true
	local suppressDeathHandling = options and options.SuppressDeathHandling == true

	if amount > 0 and not suppressFeedback then
		self:_sendFeedback(victim, "DamageTaken", { Amount = amount })
	end

	if attacker then
		if amount > 0 then
			playerStateService:SetLastAttacker(victim, attacker)
			playerStateService:AddDamageDealt(attacker, amount)
			if not suppressFeedback then
				self:_sendFeedback(attacker, "DamageDealt", { Amount = amount })
			end
			if victimStats then
				local reflectPct = math.clamp(victimStats.Reflect, 0, 0.5)
				if reflectPct > 0 then
					local reflected = amount * reflectPct
					playerStateService:ApplyDamage(attacker, reflected)
				end
			end
			self._context.EventBus:Fire("DamageDealt", attacker, victim, amount)
		end
	end

	local suppressKnockback = options and options.SuppressKnockback == true
	if knockbackDirection and not suppressKnockback then
		local playerService = getService(self._context, "PlayerService")
		local root = playerService and playerService:GetRoot(victim)
		if root and knockbackDirection.Magnitude > 0 then
			local nextVelocity = root.AssemblyLinearVelocity + knockbackDirection
			root.AssemblyLinearVelocity = Vector3.new(
				math.clamp(nextVelocity.X, -BalanceConfig.MaxVelocity, BalanceConfig.MaxVelocity),
				nextVelocity.Y,
				math.clamp(nextVelocity.Z, -BalanceConfig.MaxVelocity, BalanceConfig.MaxVelocity)
			)
			if not suppressFeedback then
				self:_sendFeedback(victim, "Impact", { Direction = knockbackDirection })
			end
		end
	end

	local state = playerStateService:GetState(victim)
	if not suppressDeathHandling and state and state.CurrentHP <= 0 then
		self:HandlePlayerDeath(victim)
	end
	return true
end

function DamagePipelineService:ApplySelfDamage(player: Player, amount: number)
	local clamped = math.clamp(amount, 0, BalanceConfig.MaxChargeSelfDamage)
	if clamped <= 0 then
		return
	end
	self:ApplyDamage(player, clamped, nil, nil)
	self:_sendFeedback(player, "SelfDamage", { Amount = clamped })
end

function DamagePipelineService:ApplyExpPenalty(player: Player, amount: number)
	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return
	end
	local state = stateService:GetState(player)
	if not state then
		return
	end
	stateService:TryApplyExpPenalty(player, amount)
end

function DamagePipelineService:HandlePlayerDeath(player: Player)
	local playerStateService = self._context.Services.PlayerStateService
	local state = playerStateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end
	playerStateService:SetAlive(player, false)
	self._context.EventBus:Fire("PlayerDied", player)

	local killer = playerStateService:GetLastAttacker(player)
	if killer then
		self._context.EventBus:Fire("PlayerKilled", killer, player)
		playerStateService:ClearLastAttacker(player)
	end
end

return DamagePipelineService
