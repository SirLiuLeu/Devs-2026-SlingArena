--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

type Context = {
	Services: any,
	ServiceRegistry: any?,
	EventBus: any,
	Remotes: Folder,
}

type DamageOptions = {
	SuppressFeedback: boolean?,
	SuppressDeathHandling: boolean?,
	SuppressKnockback: boolean?,
	KnockbackDuration: number?,
	AttackerAbsoluteSpeed: number?,
	InitialImpactSpeed: number?,
	SourceType: string?,
}

type EffectConfig = {
	Flag: string,
	Duration: number?,
	TickInterval: number?,
	DamagePerTick: any?,
	SlowAmount: number?,
	SlowDuration: number?,
	KnockbackTailDuration: number?,
}

local DamagePipelineService = {}
DamagePipelineService.__index = DamagePipelineService

local LAUNCHER_DOT_EFFECTS: { [string]: EffectConfig } = {
	FireLauncher = { Flag = "Burn" },
	PoisonLauncher = { Flag = "Poison" },
}

local function getKnockbackSpeedCap(collisionMeta: any?): number
	local attackerAbsoluteSpeed = collisionMeta and collisionMeta.AttackerAbsoluteSpeed
	if type(attackerAbsoluteSpeed) == "number" then
		return math.max(0, attackerAbsoluteSpeed)
	end

	local initialImpactSpeed = collisionMeta and collisionMeta.InitialImpactSpeed
	if type(initialImpactSpeed) == "number" then
		return math.max(0, initialImpactSpeed)
	end

	return BalanceConfig.MaxVelocity
end

local function resolveKnockbackDirectionAndSpeed(knockbackVelocity: Vector3, collisionMeta: any?): (Vector3?, number)
	local planar = Vector3.new(knockbackVelocity.X, 0, knockbackVelocity.Z)
	local planarMagnitude = planar.Magnitude
	if planarMagnitude <= 0 then
		return nil, 0
	end

	local speedCap = math.min(BalanceConfig.MaxVelocity, getKnockbackSpeedCap(collisionMeta))
	local speed = math.min(planarMagnitude, speedCap)
	if speed <= 0 then
		return nil, 0
	end

	return planar.Unit, speed
end


local function playerName(player: Player?): string
	return player and player.Name or "nil"
end

local function damageLog(message: string)
	print("[EQUIPMENT_ATTACK_TRACE][DamagePipeline] " .. message)
end

-- Combat damage is allowed in active round phases; safe-zone and trap damage bypass this check.

local function getDamageBoostMultiplier(playerStateService: any, attacker: Player?): number
	if not attacker or not playerStateService or typeof(playerStateService.GetFlag) ~= "function" then
		return 1
	end
	local damageFlag = playerStateService:GetFlag(attacker, "DamageBoosted")
	local percent = damageFlag and damageFlag.Data and tonumber(damageFlag.Data.DamageBonusPercent) or 0
	return 1 + (math.max(0, percent) / 100)
end

local function isHumanDamageAllowed(sourceType: string?): boolean
	return sourceType == "Environment" or sourceType == "PhysicalLauncherCollision" or sourceType == "Trap" or sourceType == "SafeZone"
end

local function isCombatDamageAllowed(context: Context): boolean
	local roundService = ServiceResolver.Get(context, "RoundService")
	if not roundService then
		return false
	end
	local roundState = roundService:GetState()
	return roundState == GameStates.MapRoundState.EarlyGame
		or roundState == GameStates.MapRoundState.FinalPhase
end

function DamagePipelineService.new(context: Context)
	local self = setmetatable({}, DamagePipelineService)
	self._context = context
	self._feedbackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent
	self._knockbackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.KnockbackReplication) :: RemoteEvent
	self._pendingSlowTokens = {} :: { [Player]: { [string]: number } }
	return self
end

function DamagePipelineService:Init()
	self._context.EventBus:On("CollisionPlayerKnockback", function(
		victim: Player,
		_attacker: Player?,
		knockbackVelocity: Vector3,
		collisionMeta: any
	)
		if not (self._knockbackRemote and typeof(knockbackVelocity) == "Vector3") then
			return
		end
		local knockbackDirection, knockbackSpeed = resolveKnockbackDirectionAndSpeed(knockbackVelocity, collisionMeta)
		if not knockbackDirection then
			return
		end

		self._knockbackRemote:FireClient(victim, knockbackDirection, knockbackSpeed)
	end)

	self._context.EventBus:On("CollisionPlayerHit", function(
		victim: Player,
		attacker: Player?,
		impactSpeed: number,
		_knockbackDirection: Vector3,
		collisionMeta: any
	)
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		local attackerState = attacker and stateService and stateService:GetState(attacker) or nil

		local damage = self:ComputeCollisionDamage(attackerState or {}, impactSpeed, collisionMeta)
		damage *= getDamageBoostMultiplier(stateService, attacker)
		damageLog(`CollisionPlayerHit hook fired attacker={playerName(attacker)} victim={playerName(victim)} impactSpeed={impactSpeed} baseDamage={tostring(attackerState and attackerState.BaseDamage)} calculatedDamage={damage}`)

		if damage <= 0 then
			damageLog("CollisionPlayerHit aborted: calculated damage is zero")
			return
		end

		-- Player-vs-player collision knockback is emitted once by the
		-- CollisionPlayerKnockback event after CollisionService resolves the hit.
		-- Keep this ApplyDamage call damage-only so it does not produce a second impulse.
		local didApply = self:ApplyHitDamage(victim, damage, attacker, nil, {
			SuppressKnockback = true,
			SourceType = "PhysicalLauncherCollision",
		})
		damageLog(`collision hit attacker={playerName(attacker)} defender={playerName(victim)} impactSpeed={impactSpeed} damage={damage} applied={didApply}`)
		if didApply then
			self:_applyLauncherDotFromHit(victim, attacker, attackerState, collisionMeta)
		end
	end)


	self._context.EventBus:On("LevelUp", function(player: Player)
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
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
	local launcherMaxSpeed = math.max(
		PhysicsConfig.Launch.SpeedMin,
		collisionMeta and tonumber(collisionMeta.LauncherMaxSpeed) or 0,
		attackerState.LaunchSpeed or PhysicsConfig.Launch.SpeedMin
	)
	local speedRange = math.max(launcherMaxSpeed - PhysicsConfig.Launch.SpeedMin, 1)
	local speedRatio = math.clamp((speed - PhysicsConfig.Launch.SpeedMin) / speedRange, 0, 1)
	local intensity = 1 + (speedRatio * PhysicsConfig.Damage.CollisionIntensityMultiplier)
	local collisions = collisionMeta and math.max(0, collisionMeta.CollisionCount or 0) or 0
	local chainPenalty = math.max(0.2, 1 - (collisions * PhysicsConfig.Damage.ChainDecayPerHit))
	local initialImpactSpeed = collisionMeta and math.max(0, collisionMeta.InitialImpactSpeed or speed) or speed
	local speedDecayRatio = if initialImpactSpeed > 0 then math.clamp(speed / initialImpactSpeed, 0.3, 1) else 0.3
	local energy = collisionMeta and math.max(0, collisionMeta.LaunchEnergy or 0) or 0
	local energyScalar = energy / math.max(PhysicsConfig.Launch.EnergyMax, 1)
	local angleFactor = collisionMeta and math.clamp(collisionMeta.AngleFactor or 1, 0, 1) or 1
	local angleExponent = math.max(0, PhysicsConfig.Collision.CollisionAngleReductionExponent or 1)
	local angleScalar = angleFactor ^ angleExponent
	local damage = baseDamage
		* (1 + energyScalar)
		* chainPenalty
		* intensity
		* speedDecayRatio
		* angleScalar
		* PhysicsConfig.Damage.BaseMultiplier
	return math.max(0, damage)
end
local function getSourceId(source: any?): string
	if typeof(source) == "Instance" then
		if source:IsA("Player") then
			return `Player:{source.UserId}`
		end
		return `{source.ClassName}:{source:GetDebugId(0)}`
	end
	return tostring(source or "World")
end

local function mergeEffectDefaults(effectConfig: EffectConfig): any
	local defaults = GameConfig.FlagConfig[effectConfig.Flag] or {}
	local merged = {}
	for key, value in pairs(defaults) do
		merged[key] = value
	end
	for key, value in pairs(effectConfig) do
		if key ~= "Flag" and value ~= nil then
			merged[key] = value
		end
	end
	return merged
end

function DamagePipelineService:_sendFeedback(player: Player, eventType: string, payload: any)
	if self._feedbackRemote then
		self._feedbackRemote:FireClient(player, {
			EventType = eventType,
			Payload = payload,
		})
	end
end

function DamagePipelineService:ApplyHitDamage(victim: Player, rawDamage: number, attacker: Player?, knockbackDirection: Vector3?, options: DamageOptions?): boolean
	local playerStateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not playerStateService then
		warn("[DamagePipelineService] PlayerStateService unavailable; damage skipped.")
		return false
	end
	local sourceType = options and options.SourceType or (if attacker then "LauncherCombat" else "Environment")
	damageLog(`ApplyHitDamage entered attacker={playerName(attacker)} victim={playerName(victim)} rawDamage={rawDamage} sourceType={sourceType}`)
	if attacker and (not isCombatDamageAllowed(self._context) or (playerStateService.IsHuman and playerStateService:IsHuman(attacker))) then
		damageLog("ApplyHitDamage aborted: combat phase disallows damage or attacker is Human")
		return false
	end
	if playerStateService.IsHuman and playerStateService:IsHuman(victim) and not isHumanDamageAllowed(sourceType) then
		damageLog("ApplyHitDamage aborted: victim is Human for this source type")
		return false
	end
	if playerStateService:IsInvulnerable(victim) or (typeof(playerStateService.HasFlag) == "function" and playerStateService:HasFlag(victim, "Ghost")) then
		damageLog("ApplyHitDamage aborted: victim is invulnerable or Ghost")
		return false
	end

	local victimStats = playerStateService:GetFinalStats(victim)
	local armor = victimStats and math.clamp(victimStats.Armor or 0, 0, 0.8) or 0
	local equipmentDamageMultiplier = tonumber(victim:GetAttribute("EquipmentShieldDamageMultiplier")) or 1
	local amount = math.clamp(rawDamage * equipmentDamageMultiplier * (1 - armor), 0, BalanceConfig.MaxDamagePerHit)
	local teamService = ServiceResolver.Get(self._context, "TeamService")
	local friendly = attacker and teamService and teamService:IsFriendly(attacker, victim) or false
	if friendly then
		amount = 0
	end
	local didDamage = true
	if amount > 0 then
		didDamage = playerStateService:ApplyDamage(victim, amount)
	end
	if not didDamage then
		damageLog(`ApplyHitDamage aborted: PlayerStateService rejected amount={amount}`)
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
		local playerService = ServiceResolver.Get(self._context, "PlayerService")
		local root = playerService and playerService:GetRoot(victim)
		if root and knockbackDirection.Magnitude > 0 then
			local planarKnockback = Vector3.new(knockbackDirection.X, 0, knockbackDirection.Z)
			local resolvedDirection, resolvedSpeed = resolveKnockbackDirectionAndSpeed(planarKnockback, options)
			if resolvedDirection then
				if self._knockbackRemote then
					self._knockbackRemote:FireClient(victim, resolvedDirection, resolvedSpeed)
				end
			end
			if not suppressFeedback then
				self:_sendFeedback(victim, "Impact", { Direction = planarKnockback })
			end
		end
	end

	local state = playerStateService:GetState(victim)
	if not suppressDeathHandling and state and state.CurrentHP <= 0 then
		self:HandlePlayerDeath(victim)
	end
	return true
end

function DamagePipelineService:ApplyDamage(victim: Player, rawDamage: number, attacker: Player?, knockbackDirection: Vector3?, options: DamageOptions?): boolean
	local didApply = self:ApplyHitDamage(victim, rawDamage, attacker, knockbackDirection, options)
	return didApply
end

function DamagePipelineService:ApplyDoTDamage(victim: Player, rawDamage: number, source: any?, flagName: string?): boolean
	damageLog(`ApplyDoTDamage entered victim={playerName(victim)} source={playerName(if typeof(source) == "Instance" and source:IsA("Player") then source else nil)} flag={tostring(flagName)} rawDamage={rawDamage}`)
	local playerStateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not playerStateService then
		warn("[DamagePipelineService] PlayerStateService unavailable; DOT damage skipped.")
		return false
	end
	local sourceIsPlayer = typeof(source) == "Instance" and source:IsA("Player")
	if playerStateService.IsHuman and playerStateService:IsHuman(victim) and sourceIsPlayer then
		damageLog("ApplyDoTDamage aborted: player-sourced DoT cannot damage a Human victim")
		return false
	end
	if playerStateService:IsInvulnerable(victim) or (typeof(playerStateService.HasFlag) == "function" and playerStateService:HasFlag(victim, "Ghost")) then
		damageLog("ApplyDoTDamage aborted: victim is invulnerable or Ghost")
		return false
	end
	local amount = math.max(0, rawDamage)
	if amount <= 0 then
		damageLog("ApplyDoTDamage aborted: amount is zero")
		return false
	end
	local didDamage = playerStateService:ApplyDamage(victim, amount)
	if not didDamage then
		damageLog("ApplyDoTDamage aborted: PlayerStateService rejected damage")
		return false
	end
	self:_sendFeedback(victim, "DamageTaken", { Amount = amount, DamageType = "DoT", Flag = flagName })
	if typeof(source) == "Instance" and source:IsA("Player") then
		playerStateService:SetLastAttacker(victim, source)
		playerStateService:AddDamageDealt(source, amount)
		self:_sendFeedback(source, "DamageDealt", { Amount = amount, DamageType = "DoT", Flag = flagName })
		self._context.EventBus:Fire("DoTDamageDealt", source, victim, amount, flagName)
	end
	local state = playerStateService:GetState(victim)
	if state and state.CurrentHP <= 0 then
		self:HandlePlayerDeath(victim)
	end
	damageLog(`ApplyDoTDamage success victim={playerName(victim)} flag={tostring(flagName)} amount={amount}`)
	return true
end

function DamagePipelineService:_scheduleSlowAfterKnockback(victim: Player, source: Player, amount: number, duration: number)
	local sourceId = getSourceId(source)
	self._pendingSlowTokens[victim] = self._pendingSlowTokens[victim] or {}
	local nextToken = (self._pendingSlowTokens[victim][sourceId] or 0) + 1
	self._pendingSlowTokens[victim][sourceId] = nextToken
	task.spawn(function()
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		while stateService do
			local state = stateService:GetState(victim)
			if not state or not state.IsAlive then
				return
			end
			if state.MovementState ~= GameStates.PlayerState.Knockback then
				break
			end
			task.wait(0.05)
		end
		if not self._pendingSlowTokens[victim] or self._pendingSlowTokens[victim][sourceId] ~= nextToken then
			return
		end
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		if stateService then
			stateService:ApplyFlag(victim, "Slow", duration, source, {
				SlowAmount = amount,
				SourceId = sourceId,
			})
		end
	end)
end

function DamagePipelineService:_applyLauncherDotFromHit(victim: Player, attacker: Player?, attackerState: any?, _collisionMeta: any?)
	if not (attacker and attackerState) then
		return
	end
	local effectConfig = LAUNCHER_DOT_EFFECTS[attackerState.LaunchershotType or ""]
	if not effectConfig then
		return
	end
	local flagName = effectConfig.Flag
	local merged = mergeEffectDefaults(effectConfig)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not stateService then
		return
	end
	local duration = math.max(0, tonumber(merged.Duration) or 0)
	if duration <= 0 then
		return
	end
	local sourceId = getSourceId(attacker)
	stateService:ApplyFlag(victim, flagName, duration, attacker, {
		SourceId = sourceId,
		TickInterval = merged.TickInterval,
		DamagePerTick = merged.DamagePerTick,
		KnockbackTailDuration = merged.KnockbackTailDuration,
		Stackable = false,
		MaxStack = 1,
	})
	if flagName == "Poison" then
		local slowAmount = math.max(0, tonumber(merged.SlowAmount) or 0)
		local slowDuration = math.max(0, tonumber(merged.SlowDuration) or 0)
		if slowAmount > 0 and slowDuration > 0 then
			self:_scheduleSlowAfterKnockback(victim, attacker, slowAmount, slowDuration)
		end
	end
end

function DamagePipelineService:ApplySelfDamage(player: Player, amount: number)
	local clamped = math.clamp(amount, 0, BalanceConfig.MaxChargeSelfDamage)
	if clamped <= 0 then
		return
	end
	self:ApplyDamage(player, clamped, nil, nil, { SourceType = "LauncherAbility" })
	self:_sendFeedback(player, "SelfDamage", { Amount = clamped })
end

function DamagePipelineService:ApplyExpPenalty(player: Player, amount: number)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
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
	local playerStateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = playerStateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end
	local roundService = ServiceResolver.Get(self._context, "RoundService")
	local roundState = roundService and roundService:GetState() or nil
	local convertToHuman = playerStateService:RecordDeath(player, roundState)
	playerStateService:SetAlive(player, false)
	self._context.EventBus:Fire("PlayerDied", player)

	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local mapName = state.CurrentMap or ServiceResolver.Get(self._context, "MapService"):GetActiveMap() or "ArenaMap"
	if convertToHuman then
		playerStateService:SetActivePlayerMode(player, GameStates.PlayerMode.Human)
	end
	if playerService and typeof(playerService.RespawnAfterDelay) == "function" then
		playerService:RespawnAfterDelay(player, 3, nil, mapName)
	end

	local killer = playerStateService:GetLastAttacker(player)
	if killer then
		self._context.EventBus:Fire("PlayerKilled", killer, player)
		playerStateService:ClearLastAttacker(player)
	end
end

return DamagePipelineService
