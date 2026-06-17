--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MockData = require(ReplicatedStorage.Client.Services.MockData)
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)

local OnlineRewardLogicService = {}
OnlineRewardLogicService.__index = OnlineRewardLogicService

export type RewardState = "Locked" | "Ready" | "Claimed"

export type RewardSlot = {
	id: string,
	rewardType: string,
	amount: number,
	icon: string,
	duration: number,
	remaining: number,
	state: RewardState,
	itemId: string?,
}

local function cloneSlot(slot: RewardSlot): RewardSlot
	return {
		id = slot.id,
		rewardType = slot.rewardType,
		amount = slot.amount,
		icon = slot.icon,
		duration = slot.duration,
		remaining = slot.remaining,
		state = slot.state,
		itemId = slot.itemId,
	}
end

function OnlineRewardLogicService.new()
	local self = setmetatable({}, OnlineRewardLogicService)
	self._changed = Instance.new("BindableEvent")
	self._slots = {}
	self._indexById = {}
	self._running = false
	self._tickThread = nil
	self._batchYieldSize = 4
	self._config = {
		columns = 4,
		rows = 3,
	}
	return self
end

function OnlineRewardLogicService:Destroy()
	self._running = false
	if self._changed then
		self._changed:Destroy()
	end
end

function OnlineRewardLogicService:BindChanged(callback)
	return self._changed.Event:Connect(callback)
end

function OnlineRewardLogicService:GetSnapshot()
	local slots = {}
	for i, slot in ipairs(self._slots) do
		slots[i] = cloneSlot(slot)
	end
	return {
		slots = slots,
		columns = self._config.columns,
		rows = self._config.rows,
	}
end

function OnlineRewardLogicService:_emitChanged()
	self._changed:Fire(self:GetSnapshot())
end

function OnlineRewardLogicService:LoadMockData()
	local mock = MockData.GetOnlineRewardState()
	self._slots = {}
	table.clear(self._indexById)
	self._config.columns = math.max(1, math.floor(mock.columns or 4))
	self._config.rows = math.max(1, math.floor(mock.rows or 3))

	for index, slot in ipairs(mock.rewards or {}) do
		local startState = slot.state == "Claimed" and "Claimed" or (slot.duration <= 0 and "Ready" or "Locked")
		local normalized = {
			id = tostring(slot.id),
			rewardType = tostring(slot.rewardType),
			amount = math.max(0, math.floor(slot.amount or 0)),
			icon = tostring(slot.icon or ""),
			duration = math.max(0, math.floor(slot.duration or 0)),
			remaining = math.max(0, math.floor(slot.duration or 0)),
			state = startState,
			itemId = slot.itemId,
		}
		self._slots[index] = normalized
		self._indexById[normalized.id] = index
	end

	self:_emitChanged()
	self:StartTimerLoop()
end

function OnlineRewardLogicService:_setSlotReady(slot: RewardSlot)
	if slot.state == "Claimed" then
		return
	end
	slot.remaining = 0
	slot.state = "Ready"
end

function OnlineRewardLogicService:StartTimerLoop()
	if self._running then
		return
	end
	self._running = true

	task.spawn(function()
		while self._running do
			local changed = false
			local processed = 0
			for _, slot in ipairs(self._slots) do
				if slot.state == "Locked" then
					slot.remaining = math.max(0, slot.remaining - 1)
					if slot.remaining <= 0 then
						self:_setSlotReady(slot)
					end
					changed = true
				end

				processed += 1
				if processed % self._batchYieldSize == 0 then
					task.wait()
				end
			end
			if changed then
				self:_emitChanged()
			end
			task.wait(1)
		end
	end)
end

function OnlineRewardLogicService:ClaimReward(rewardId: string): boolean
	local index = self._indexById[rewardId]
	if not index then
		return false
	end
	local slot = self._slots[index]
	if slot.state ~= "Ready" then
		return false
	end
	slot.state = "Claimed"
	slot.remaining = 0
	MockPlayerData.GrantReward(slot.rewardType, slot.amount, slot.itemId, "OnlineRewardClaim")
	self:_emitChanged()
	return true
end

function OnlineRewardLogicService:ClaimAllReady(): number
	local claimed = 0
	for _, slot in ipairs(self._slots) do
		if slot.state == "Ready" then
			slot.state = "Claimed"
			slot.remaining = 0
			MockPlayerData.GrantReward(slot.rewardType, slot.amount, slot.itemId, "OnlineRewardClaimAll")
			claimed += 1
		end
	end
	if claimed > 0 then
		self:_emitChanged()
	end
	return claimed
end

function OnlineRewardLogicService:SkipAll()
	local changed = false
	for _, slot in ipairs(self._slots) do
		if slot.state == "Locked" then
			self:_setSlotReady(slot)
			changed = true
		end
	end
	if changed then
		self:_emitChanged()
	end
end

local defaultInstance = nil

function OnlineRewardLogicService.GetDefault()
	if not defaultInstance then
		defaultInstance = OnlineRewardLogicService.new()
	end
	return defaultInstance
end

return OnlineRewardLogicService
