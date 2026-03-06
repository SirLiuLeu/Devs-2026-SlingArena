--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

type Context = {
	Services: any,
	EventBus: any,
	Remotes: Folder,
}

local DamagePipelineService = {}
DamagePipelineService.__index = DamagePipelineService

function DamagePipelineService.new(context: Context)
	local self = setmetatable({}, DamagePipelineService)
	self._context = context
	self._feedbackRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent
	return self
end

function DamagePipelineService:Init()
	self._context.EventBus:On("CollisionPlayerHit", function(victim: Player, attacker: Player?, rawDamage: number, knockbackDirection: Vector3, collisionMeta: any)
		self:ApplyDamage(victim, rawDamage, attacker, knockbackDirection)
		self:_applyCollisionSelfDamage(attacker, rawDamage, collisionMeta)
	end)
	self._context.EventBus:On("TrapCollision", function(player: Player, penalty: number)
		self:ApplyExpPenalty(player, penalty)
	end)
	self._context.EventBus:On("MaxChargeReleased", function(player: Player, selfDamage: number)
		local skillService = self._context.Services.SkillService
		local specialActive = skillService and skillService.IsSpecialUpgradeActive and skillService:IsSpecialUpgradeActive(player)
		if specialActive then
			self:ApplySelfDamage(player, selfDamage)
		end
	end)
	self._context.EventBus:On("LevelUp", function(player: Player)
		self._context.Services.PlayerStateService:ApplyLevelGrowth(player)
		self:_sendFeedback(player, "LevelUp", {})
	end)
	task.spawn(function()
		while true do
			self:_runRegenTick()
			task.wait(1)
		end
	end)
end

function DamagePipelineService:_sendFeedback(player: Player, eventType: string, payload: any)
	if self._feedbackRemote then
		self._feedbackRemote:FireClient(player, {
			EventType = eventType,
			Payload = payload,
		})
	end
end

function DamagePipelineService:_runRegenTick()
	for player, state in pairs(self._context.Services.PlayerStateService:GetAllStates()) do
		if state.IsAlive and state.CurrentHP > 0 then
			local regen = SlingshotConfig.SlingConfig.RegenPerSecond + state.Attributes.Regen
			if regen > 0 then
				self._context.Services.PlayerStateService:Heal(player, regen)
			end
		end
	end
end


function DamagePipelineService:_applyCollisionSelfDamage(attacker: Player?, rawDamage: number, collisionMeta: any)
	if not attacker then
		return
	end
	local state = self._context.Services.PlayerStateService:GetState(attacker)
	if not state then
		return
	end
	local skillService = self._context.Services.SkillService
	local specialActive = skillService and skillService.IsSpecialUpgradeActive and skillService:IsSpecialUpgradeActive(attacker)
	local chargeRatio = 0
	if typeof(collisionMeta) == "table" and typeof(collisionMeta.ChargeRatio) == "number" then
		chargeRatio = collisionMeta.ChargeRatio
	else
		chargeRatio = state.ChargeValue or 0
	end
	if chargeRatio < 0.999 or not specialActive then
		return
	end
	local cappedImpact = math.min(rawDamage, (state.CurrentHP or 0) * BalanceConfig.MaxSelfDamageToCurrentHpRatio)
	local selfDamage = math.clamp(cappedImpact * BalanceConfig.SelfDamageRatio, 0, BalanceConfig.MaxDamagePerHit)
	if selfDamage > 0 then
		self:ApplyDamage(attacker, selfDamage, nil, nil)
		self:_sendFeedback(attacker, "SelfDamage", { Amount = selfDamage })
	end
end
function DamagePipelineService:ApplyDamage(victim: Player, rawDamage: number, attacker: Player?, knockbackDirection: Vector3?): boolean
	local playerStateService = self._context.Services.PlayerStateService
	if playerStateService:IsInvulnerable(victim) then
		return false
	end

	local amount = math.clamp(rawDamage, 0, BalanceConfig.MaxDamagePerHit)
	if attacker then
		playerStateService:SetLastAttacker(victim, attacker)
	end
	local didDamage = playerStateService:ApplyDamage(victim, amount)
	if not didDamage then
		return false
	end

	self:_sendFeedback(victim, "DamageTaken", { Amount = amount })

	if attacker then
		playerStateService:AddDamageDealt(attacker, amount)
		self:_sendFeedback(attacker, "DamageDealt", { Amount = amount })
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

	if knockbackDirection then
		local root = self._context.Services.PlayerService:GetRoot(victim)
		if root and knockbackDirection.Magnitude > 0 then
			local nextVelocity = root.AssemblyLinearVelocity + knockbackDirection
			root.AssemblyLinearVelocity = Vector3.new(
				math.clamp(nextVelocity.X, -BalanceConfig.MaxVelocity, BalanceConfig.MaxVelocity),
				nextVelocity.Y,
				math.clamp(nextVelocity.Z, -BalanceConfig.MaxVelocity, BalanceConfig.MaxVelocity)
			)
			self:_sendFeedback(victim, "Impact", { Direction = knockbackDirection })
		end
	end

	local state = playerStateService:GetState(victim)
	if state and state.CurrentHP <= 0 then
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
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end
	self._context.Services.PlayerStateService:TryApplyExpPenalty(player, amount)
end

function DamagePipelineService:HandlePlayerDeath(player: Player)
	local playerStateService = self._context.Services.PlayerStateService
	local state = playerStateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end
	playerStateService:SetAlive(player, false)
	self._context.EventBus:Fire("PlayerDied", player)
	task.delay(2, function()
		if player.Parent then
			local mapName = self._context.Services.MapService:GetActiveMap() or "LobbyMap"
			self._context.Services.PlayerService:SpawnPawn(player, nil, mapName)
			playerStateService:SetMapName(player, mapName)
			playerStateService:SetArenaStatus(player, "Respawned")
		end
	end)

	local killer = playerStateService:GetLastAttacker(player)
	if killer then
		self._context.EventBus:Fire("PlayerKilled", killer, player)
		playerStateService:ClearLastAttacker(player)
	end
end

return DamagePipelineService
