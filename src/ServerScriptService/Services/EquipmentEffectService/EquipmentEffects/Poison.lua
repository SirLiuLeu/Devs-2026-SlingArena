--!strict
local EffectUtil = require(script.Parent.EffectUtil)

local foodDotState: { [string]: any } = {}
local Dot = {}

local function applyFoodDot(context, food: Model)
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

function Dot.OnCollision(context, collisionType: string, target: any, _payload: any)
	if collisionType == "Player" and target then
		if not EffectUtil.CanAffectPlayers(context, context.player, target) then return end
		EffectUtil.ApplyDotFlag(context, target)
	elseif collisionType == "Food" and target and typeof(target) == "Instance" and target:IsA("Model") then
		local stateService = context.PlayerStateService
		if stateService and stateService:IsHuman(context.player) then return end
		applyFoodDot(context, target)
	end
end

function Dot.OnTick(context, _dt: number)
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

return Dot
