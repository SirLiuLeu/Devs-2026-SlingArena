--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

type Context = {
	EventBus: any,
	Services: any,
}

local CollisionService = {}
CollisionService.__index = CollisionService

function CollisionService.new(context: Context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._pairDebounce = {} :: { [string]: number }
	return self
end

local function pairKey(attacker: Player, defender: Player): string
	return (`{attacker.UserId}:{defender.UserId}`)
end

function CollisionService:Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:_hookCharacter(player, character)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			self:_hookCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			self:_hookCharacter(player, character)
		end)
	end
end

function CollisionService:_hookCharacter(player: Player, character: Model)
	self._context.EventBus:Fire("CharacterSpawned", player, character)
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	root.Touched:Connect(function(hit)
		local otherCharacter = hit:FindFirstAncestorOfClass("Model")
		if not otherCharacter or otherCharacter == character then
			return
		end
		local defender = Players:GetPlayerFromCharacter(otherCharacter)
		if not defender then
			return
		end
		self:ResolveCollision(player, defender)
	end)
end

function CollisionService:ResolveCollision(attacker: Player, defender: Player)
	local now = os.clock()
	local attackState = self._context.Services.PlayerStateService:GetState(attacker)
	local defendState = self._context.Services.PlayerStateService:GetState(defender)
	if not attackState or not defendState then
		return
	end
	if not attackState.IsAlive or not defendState.IsAlive then
		return
	end
	if self._context.Services.PlayerStateService:IsInvulnerable(defender) then
		return
	end

	local key = pairKey(attacker, defender)
	if (self._pairDebounce[key] or 0) + BalanceConfig.CollisionCooldown > now then
		return
	end
	self._pairDebounce[key] = now

	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	local defenderRoot = defender.Character and defender.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not attackerRoot or not defenderRoot then
		return
	end

	local velocity = attackerRoot.AssemblyLinearVelocity
	local velocityMag = velocity.Magnitude
	if velocityMag < BalanceConfig.MinVelocityToCollide then
		return
	end

	local combatService = self._context.Services.CombatService
	local damage = combatService:ComputeImpactDamage(attackState, velocityMag)
	local chargeRatio = attackState.ChargeValue
	local skillService = self._context.Services.SkillService
	local specialUpgrade = skillService:IsSpecialUpgradeActive(attacker)

	if chargeRatio >= 1 and specialUpgrade then
		damage = math.min(damage, attackState.CurrentHP * BalanceConfig.MaxSelfDamageToCurrentHpRatio)
		local selfDamage = damage * BalanceConfig.SelfDamageRatio
		self._context.Services.PlayerStateService:ApplyDamage(attacker, selfDamage)
	end

	self._context.Services.PlayerStateService:ApplyDamage(defender, damage)
	self._context.Services.PlayerStateService:MarkInvulnerable(defender, BalanceConfig.HitInvulSeconds)
	self._context.EventBus:Fire("DamageDealt", attacker, defender, damage)

	if defendState.CurrentHP <= 0 then
		self._context.EventBus:Fire("PlayerKilled", attacker, defender)
	end

	local knockDirection = defenderRoot.Position - attackerRoot.Position
	local knockback = combatService:ComputeKnockback(attackState, defendState, knockDirection)
	defenderRoot.AssemblyLinearVelocity = knockback

	local remain = attackerRoot.AssemblyLinearVelocity * BalanceConfig.VelocityDecayFactor
	if remain.Magnitude < BalanceConfig.VelocityStopThreshold then
		remain = Vector3.zero
	end
	attackerRoot.AssemblyLinearVelocity = remain
	self._context.Services.PlayerStateService:UpdateVelocity(attacker, remain)
end

return CollisionService
