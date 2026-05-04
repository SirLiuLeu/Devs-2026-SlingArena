--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

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
	self._context.EventBus:On("CollisionPlayerHit", function(victim: Player, attacker: Player?, rawDamage: number, knockbackDirection: Vector3, _collisionMeta: any)
		self:ApplyDamage(victim, rawDamage, attacker, knockbackDirection, {
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

function DamagePipelineService:ComputeCollisionDamage(attackerState: any, velocityMagnitude: number, launchSession: any): number
	local baseDamage = math.max(attackerState.BaseDamage or 0, 0)
	local speed = math.max(0, velocityMagnitude)
	local speedMultiplier = speed / math.max(BalanceConfig.MinVelocityToCollide, 1)
	local sessionMultiplier = 1
	if launchSession then
		local hitFalloff = math.max(0.35, 1 - (launchSession.HitCount * 0.2))
		sessionMultiplier = (launchSession.CurrentDamageMultiplier or 1) * hitFalloff * math.max(0.2, launchSession.EnergyLeft or 0)
	end
	local damage = baseDamage * speedMultiplier * sessionMultiplier
	return math.clamp(damage, 0, BalanceConfig.MaxDamagePerHit)
end

function DamagePipelineService:ComputeCollisionKnockback(attackerState: any, defenderState: any, direction: Vector3, velocityMagnitude: number, launchSession: any): Vector3
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(1, 0, 0)
	end
	local attackerSize = math.max(attackerState.Size or 1, 0.1)
	local defenderSize = math.max(defenderState.Size or 1, 0.1)
	local sizeRatio = attackerSize / defenderSize
	local baseForce = math.max(BalanceConfig.BaseImpactForce, velocityMagnitude * BalanceConfig.KnockbackFactor)
	local sessionBoost = launchSession and (0.8 + ((launchSession.ChargeRatio or 0) * 0.35) + ((launchSession.EnergyLeft or 0) * 0.25)) or 1
	local resistance = math.clamp(defenderState.KnockbackResistance or 0, 0, 0.8)
	local knockbackForce = math.clamp((baseForce * sizeRatio * sessionBoost) * (1 - resistance), 0, BalanceConfig.MaxKnockback)
	return direction.Unit * knockbackForce
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
	if playerStateService:IsInvulnerable(victim) then
		return false
	end

	local amount = math.clamp(rawDamage, 0, BalanceConfig.MaxDamagePerHit)
	local teamService = getService(self._context, "TeamService")
	if attacker and teamService and teamService:IsFriendly(attacker, victim) then
		amount = 0
	end
	if attacker then
		playerStateService:SetLastAttacker(victim, attacker)
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
			playerStateService:AddDamageDealt(attacker, amount)
			if not suppressFeedback then
				self:_sendFeedback(attacker, "DamageDealt", { Amount = amount })
			end
			local victimStats = playerStateService:GetFinalStats(victim)
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
