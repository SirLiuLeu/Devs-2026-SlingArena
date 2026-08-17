--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local EffectUtil = {}

function EffectUtil.GetFlagConfig(flagName: string): any
	return GameConfig.FlagConfig[flagName] or {}
end

function EffectUtil.GetCollisionTransferredVelocity(collisionMeta: any): number
	if collisionMeta and typeof(collisionMeta.TransferredVelocity) == "number" then
		return math.max(0, collisionMeta.TransferredVelocity)
	end
	if collisionMeta and typeof(collisionMeta.TransferredVelocityVector) == "Vector3" then
		return collisionMeta.TransferredVelocityVector.Magnitude
	end
	return 0
end

function EffectUtil.ResolveImpactScaledFlagDuration(flagName: string, collisionMeta: any, fallbackDuration: number?): number
	local flagConfig = EffectUtil.GetFlagConfig(flagName)
	local baseDuration = math.max(0, fallbackDuration or flagConfig.Duration or 0)
	local maxLaunchSpeed = math.max(PhysicsConfig.Launch.SpeedMax or 0, 0.001)
	return (EffectUtil.GetCollisionTransferredVelocity(collisionMeta) / maxLaunchSpeed) * baseDuration
end

function EffectUtil.CanAffectPlayers(context, attacker: Player, victim: Player): boolean
	local stateService = context.PlayerStateService
	if not stateService then return false end
	if stateService:IsHuman(attacker) or stateService:IsHuman(victim) then return false end
	if stateService:HasFlag(attacker, "Ghost") or stateService:HasFlag(victim, "Ghost") then return false end
	local teamService = context.TeamService
	if teamService and teamService:IsFriendly(attacker, victim) then return false end
	return true
end

function EffectUtil.FireCCFeedback(context, victim: Player, flagName: string, duration: number)
	local remotes = context.Remotes
	local feedbackRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
		feedbackRemote:FireClient(victim, { EventType = "CCApplied", Payload = { FlagName = flagName, Duration = duration } })
	end
end

function EffectUtil.ApplyCollisionFlag(context, victim: Player, collisionMeta: any)
	local effect = context.definition.combatEffect or {}
	local flagName = effect.collisionFlag
	if not flagName then return end
	local stateService = context.PlayerStateService
	if not stateService then return end
	local duration = EffectUtil.ResolveImpactScaledFlagDuration(flagName, collisionMeta, effect.collisionExtraDuration)
	stateService:ApplyFlag(victim, flagName, duration, context.player)
	EffectUtil.FireCCFeedback(context, victim, flagName, duration)
end

function EffectUtil.ApplyDotFlag(context, victim: Player)
	local effect = context.definition.combatEffect or {}
	local flagName = effect.dotFlag
	if not flagName then return end
	local stateService = context.PlayerStateService
	if not stateService then return end
	local flagConfig = EffectUtil.GetFlagConfig(flagName)
	stateService:ApplyFlag(victim, flagName, flagConfig.Duration, context.player, {
		Stackable = flagConfig.Stackable,
		MaxStack = flagConfig.MaxStack,
		TickInterval = flagConfig.TickInterval,
		DamagePerTick = flagConfig.DamagePerTick,
	})
	if flagConfig.SlowAmount then
		local slowConfig = EffectUtil.GetFlagConfig("Slow")
		stateService:ApplyFlag(victim, "Slow", flagConfig.SlowDuration or slowConfig.Duration, context.player, {
			Stackable = slowConfig.Stackable,
			MaxStack = slowConfig.MaxStack,
			SlowAmount = flagConfig.SlowAmount,
		})
	end
end

local foodDotState: { [string]: any } = {}
local playerRemovingConnection: RBXScriptConnection? = nil

local function ensurePlayerRemovingCleanup()
	if playerRemovingConnection then return end
	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		for stateKey, dotData in pairs(foodDotState) do
			if dotData.instigator == player or string.find(stateKey, ":" .. tostring(player.UserId), 1, true) then
				foodDotState[stateKey] = nil
			end
		end
	end)
end

function EffectUtil.ApplyFoodDot(context, food: Model)
	ensurePlayerRemovingCleanup()
	local effect = context.definition.combatEffect or {}
	local flagName = effect.dotFlag
	if not flagName then return end
	local foodId = food:GetAttribute("FoodId")
	if typeof(foodId) ~= "string" then return end
	local flagConfig = EffectUtil.GetFlagConfig(flagName)
	local stateKey = string.format("%s:%s:%d", foodId, flagName, context.player.UserId)
	local existing = foodDotState[stateKey]
	local maxStack = math.max(1, flagConfig.MaxStack or 1)
	local stacks = math.clamp((existing and (existing.stacks or 1) or 0) + 1, 1, maxStack)
	local now = os.clock()
	foodDotState[stateKey] = {
		food = food,
		flagName = flagName,
		stacks = stacks,
		damagePerTick = flagConfig.DamagePerTick or 0,
		tickInterval = flagConfig.TickInterval or 1,
		lastTickAt = existing and existing.lastTickAt or now,
		expiresAt = now + (flagConfig.Duration or 0),
		instigator = context.player,
	}
end

function EffectUtil.TickFoodDots(context)
	local now = os.clock()
	local toRemove = {}
	for stateKey, dotData in pairs(foodDotState) do
		local food = dotData.food
		if not (food and food.Parent) or now >= dotData.expiresAt then
			table.insert(toRemove, stateKey)
		elseif now - (dotData.lastTickAt or now) >= dotData.tickInterval then
			dotData.lastTickAt = now
			local totalDamage = math.max(0, dotData.damagePerTick or 0) * math.max(1, dotData.stacks or 1)
			local foodService = context.FoodService
			if totalDamage <= 0 or not (foodService and typeof(foodService.ApplyDamageToFood) == "function") then
				table.insert(toRemove, stateKey)
			elseif not foodService:ApplyDamageToFood(food, totalDamage, dotData.instigator) or not food.Parent then
				table.insert(toRemove, stateKey)
			end
		end
	end
	for _, stateKey in ipairs(toRemove) do foodDotState[stateKey] = nil end
end

return EffectUtil
