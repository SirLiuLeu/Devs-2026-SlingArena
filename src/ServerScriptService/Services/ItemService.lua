--!strict

-- Server-authoritative consumable gateway. Clients only submit an item id; quantities,
-- cooldowns and effect parameters always come from server-owned profile/config data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
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

function ItemService:_feedback(player: Player, itemId: string, result: string, cooldownEndTime: number?)
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if remote then remote:FireClient(player, { EventType = "ItemUseResult", Payload = { ItemId = itemId, Result = result, CooldownEndTime = cooldownEndTime } }) end
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
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return false, "DataUnavailable" end
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
	if not consumed then self:_publishInventory(player); self:_feedback(player, itemId, "NotOwned"); return false, "NotOwned" end

	local effect = item.effect
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if effect.kind == "Experience" then
		local growthService = ServiceResolver.Get(self._context, "GrowthService")
		if growthService and typeof(growthService.GrantExperience) == "function" then
			growthService:GrantExperience(player, effect.experienceAmount or 0, "Consumable:" .. itemId)
		elseif stateService then stateService:GrantExp(player, effect.experienceAmount or 0) end
	elseif effect.kind == "Flag" and stateService and effect.flagName then
		stateService:ApplyFlag(player, effect.flagName, effect.flagParams and effect.flagParams.Duration, "Consumable:" .. itemId, effect.flagParams)
	end
	cooldowns[itemId] = now + math.max(0, item.useCooldown or 0)
	self:_publishInventory(player)
	self:_feedback(player, itemId, "Consumed", cooldowns[itemId])
	return true, nil
end

function ItemService:ClearPlayer(player: Player) self._cooldownEnds[player] = nil end
return ItemService
