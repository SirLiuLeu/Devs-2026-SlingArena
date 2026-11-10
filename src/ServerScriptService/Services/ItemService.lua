--!strict

-- Server-authoritative consumable gateway. Clients only submit an item id; quantities,
-- cooldowns and effect parameters always come from server-owned profile/config data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local GiftBoxConfig = require(ReplicatedStorage.Shared.Config.GiftBoxConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local ItemService = {}
ItemService.__index = ItemService

function ItemService.new(context)
	local self = setmetatable({}, ItemService)
	self._context = context
	self._cooldownEnds = {} :: { [Player]: { [string]: number } }
	self._consumeRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.ConsumeItem) :: RemoteEvent?
	self._legacyPotionRemote = context.Remotes:FindFirstChild(RemoteContracts.Names.ConsumeHpPotion) :: RemoteEvent?
	return self
end

function ItemService:Init()
	if self._consumeRemote then
		self._consumeRemote.OnServerEvent:Connect(function(player: Player, payload: any)
			if RemoteContracts.Validate(RemoteContracts.Names.ConsumeItem, payload) then
				self:TryConsume(player, payload.itemId)
			end
		end)
	end
	-- Compatibility only: old clients take the exact same server-authoritative path.
	if self._legacyPotionRemote then
		self._legacyPotionRemote.OnServerEvent:Connect(function(player: Player)
			self:TryConsume(player, "hp_potion")
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player) self:ClearPlayer(player) end)
end

function ItemService:_publishInventory(player: Player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	local state = stateService and stateService:GetState(player)
	if state and dataService then
		local data = dataService:GetData(player)
		state.OwnedItems = data.OwnedItems or {}
		state.HpPotions = math.max(0, math.floor(tonumber(state.OwnedItems.hp_potion) or 0))
		state.ItemCooldownEnds = self._cooldownEnds[player] or {}
		state.NextHpPotionUseTime = state.ItemCooldownEnds.hp_potion or 0
		stateService:PublishState(player)
	end
end

function ItemService:_feedback(player: Player, itemId: string, result: string, cooldownEndTime: number?, extraPayload: { [string]: any }?)
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if remote then
		local payload = { ItemId = itemId, Result = result, CooldownEndTime = cooldownEndTime }
		for key, value in pairs(extraPayload or {}) do payload[key] = value end
		remote:FireClient(player, { EventType = "ItemUseResult", Payload = payload })
	end
end

function ItemService:PublishInventory(player: Player)
	self:_publishInventory(player)
end

function ItemService:TryConsume(player: Player, itemId: string): (boolean, string?)
	local item = ItemConfig.GetById(itemId)
	if not item or item.itemType ~= "Consumable" or item.consumeOnUse ~= true or not item.effect then
		self:_feedback(player, itemId, "InvalidItem")
		return false, "InvalidItem"
	end
	local now = os.clock()
	local cooldowns = self._cooldownEnds[player] or {}
	self._cooldownEnds[player] = cooldowns
	if now < (cooldowns[itemId] or 0) then
		self:_feedback(player, itemId, "Cooldown", cooldowns[itemId])
		return false, "Cooldown"
	end

	local effect = item.effect
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local requiresRoundProgression = effect.kind == "Experience"
		or (effect.kind == "Flag" and effect.flagName == "EXPBoosted")
	if requiresRoundProgression then
		if not stateService or typeof(stateService.CanGainRoundExp) ~= "function" or not stateService:CanGainRoundExp(player) then
			self:_feedback(player, itemId, "NotInRound")
			return false, "NotInRound"
		end
		-- The round-start reset clears temporary flags. Do not allow a timed EXP
		-- boost to be consumed in Awaits just before that reset discards it.
		if effect.kind == "Flag" and effect.flagName == "EXPBoosted" then
			local roundService = ServiceResolver.Get(self._context, "RoundService")
			if not roundService or typeof(roundService.IsPlayingState) ~= "function" or not roundService:IsPlayingState() then
				self:_feedback(player, itemId, "NotInRound")
				return false, "NotInRound"
			end
		end
	end

	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return false, "DataUnavailable" end

	local giftBoxReward: any = nil
	if effect.kind == "GiftBox" then
		giftBoxReward = GiftBoxConfig.Roll(Random.new())
		if not giftBoxReward then
			self:_feedback(player, itemId, "RewardUnavailable")
			return false, "RewardUnavailable"
		end
	end

	local bombService = nil
	if effect.kind == "Bomb" then
		bombService = ServiceResolver.Get(self._context, "BombService")
		if not (bombService and typeof(bombService.CanPlaceBomb) == "function") then
			self:_feedback(player, itemId, "BombServiceUnavailable")
			return false, "BombServiceUnavailable"
		end
		local canPlace, placeReason = bombService:CanPlaceBomb(player)
		if not canPlace then
			self:_feedback(player, itemId, placeReason or "CannotUse")
			return false, placeReason or "CannotUse"
		end
	end

	local consumed = false
	dataService:UpdateData(player, function(data)
		local owned = data.OwnedItems
		local quantity = type(owned) == "table" and math.max(0, math.floor(tonumber(owned[itemId]) or 0)) or 0
		if quantity > 0 then
			owned[itemId] = quantity - 1
			if owned[itemId] <= 0 then owned[itemId] = nil end
			consumed = true
		end
		return data
	end)
	if not consumed then
		self:_publishInventory(player)
		self:_feedback(player, itemId, "NotOwned")
		return false, "NotOwned"
	end

	if effect.kind == "Experience" then
		local growthService = ServiceResolver.Get(self._context, "GrowthService")
		if growthService and typeof(growthService.GrantExperience) == "function" then
			growthService:GrantExperience(player, effect.experienceAmount or 0, "Consumable:" .. itemId)
		elseif stateService then
			stateService:GrantExp(player, effect.experienceAmount or 0)
		end
	elseif effect.kind == "Flag" and stateService and effect.flagName then
		stateService:ApplyFlag(player, effect.flagName, effect.flagParams and effect.flagParams.Duration, "Consumable:" .. itemId, effect.flagParams)
	elseif effect.kind == "Bomb" then
		local placed, placeReason = bombService:TryPlaceBomb(player)
		if not placed then
			-- Refund if the world placement fails after the authoritative inventory decrement.
			dataService:UpdateData(player, function(data)
				data.OwnedItems = if type(data.OwnedItems) == "table" then data.OwnedItems else {}
				data.OwnedItems[itemId] = math.max(0, math.floor(tonumber(data.OwnedItems[itemId]) or 0)) + 1
				return data
			end)
			self:_publishInventory(player)
			self:_feedback(player, itemId, placeReason or "PlacementFailed")
			return false, placeReason or "PlacementFailed"
		end
	elseif effect.kind == "GiftBox" then
		if giftBoxReward.kind == "Diamonds" then
			dataService:GrantReward(player, { Diamonds = giftBoxReward.amount }, "GiftBoxOpened")
		elseif giftBoxReward.kind == "Item" and ItemConfig.GetById(giftBoxReward.itemId) then
			dataService:GrantReward(player, { Items = { { Id = giftBoxReward.itemId, Quantity = giftBoxReward.quantity } } }, "GiftBoxOpened")
		else
			-- A bad reward config must never consume this Gift Box.
			dataService:UpdateData(player, function(data)
				data.OwnedItems = if type(data.OwnedItems) == "table" then data.OwnedItems else {}
				data.OwnedItems[itemId] = math.max(0, math.floor(tonumber(data.OwnedItems[itemId]) or 0)) + 1
				return data
			end)
			self:_publishInventory(player)
			self:_feedback(player, itemId, "RewardUnavailable")
			return false, "RewardUnavailable"
		end
		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
		if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
			stateService:RecalculateDerivedStats(player, false)
		end
	end

	cooldowns[itemId] = now + math.max(0, item.useCooldown or 0)
	self:_publishInventory(player)
	self:_feedback(player, itemId, "Consumed", cooldowns[itemId], if giftBoxReward then { Reward = giftBoxReward } else nil)
	if itemId == "hp_potion" and self._context.EventBus then
		self._context.EventBus:Fire("DailyQuestHpPotionUsed", player)
	end
	return true, nil
end



function ItemService:ClearPlayer(player: Player) self._cooldownEnds[player] = nil end
return ItemService
