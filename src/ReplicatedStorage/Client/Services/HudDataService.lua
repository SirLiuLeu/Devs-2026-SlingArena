--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MockPlayerData = require(ReplicatedStorage.Client.Services.MockPlayerData)

local HudDataService = {}
HudDataService.__index = HudDataService

local function deepCopy(v: any): any
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in pairs(v) do c[deepCopy(k)] = deepCopy(x) end
	return c
end

local function defaultState()
	return { Diamonds = 0, HpPotions = 0, Exp = 0, Level = 1, NextHpPotionUseTime = 0, ActiveFlags = {}, DamageMultiplier = 1, ExpBonus = 0 }
end

function HudDataService.new()
	local self = setmetatable({}, HudDataService)
	self._changed = Instance.new("BindableEvent")
	self._snapshot = defaultState()
	self._hasAuthoritativeState = false
	return self
end

function HudDataService:Destroy()
	if self._mockDataConnection then
		self._mockDataConnection:Disconnect()
		self._mockDataConnection = nil
	end
	self._changed:Destroy()
end

function HudDataService:GetSnapshot() return deepCopy(self._snapshot) end
function HudDataService:BindChanged(cb) return self._changed.Event:Connect(cb) end
function HudDataService:_emitChanged() self._changed:Fire(self:GetSnapshot()) end

function HudDataService:SetFromState(state: any)
	-- Server StateUpdate is authoritative. Mock updates remain subscribed for
	-- offline mode but cannot overwrite this snapshot after server data arrives.
	self._hasAuthoritativeState = true
	if type(state) ~= "table" then
		self._snapshot = defaultState()
		self:_emitChanged()
		return
	end
	self._snapshot = {
		Diamonds = state.Diamonds or 0,
		HpPotions = state.HpPotions or self._snapshot.HpPotions or 0,
		Exp = state.Exp or 0,
		Level = state.Level or 1,
		NextHpPotionUseTime = state.NextHpPotionUseTime or 0,
		ActiveFlags = deepCopy(state.ActiveFlags or {}),
		DamageMultiplier = state.DamageMultiplier or 1,
		ExpBonus = state.ExpBonus or 0,
	}
	self:_emitChanged()
end
function HudDataService:LoadMockData()
	if not self._mockDataConnection then
		self._mockDataConnection = MockPlayerData.BindChanged(function(data)
			if not self._hasAuthoritativeState then self:_setFromMockData(data) end
		end)
	end
	if not self._hasAuthoritativeState then self:_setFromMockData(MockPlayerData.GetPlayerData()) end
end
function HudDataService:_setFromMockData(data: any)
	if type(data) ~= "table" then return end
	self._snapshot = {
		Diamonds = data.Diamonds or 0,
		HpPotions = self._snapshot.HpPotions or 0,
		Exp = data.Exp or 0,
		Level = data.Level or 1,
		NextHpPotionUseTime = self._snapshot.NextHpPotionUseTime or 0,
		ActiveFlags = deepCopy(self._snapshot.ActiveFlags or {}),
		DamageMultiplier = self._snapshot.DamageMultiplier or 1,
		ExpBonus = self._snapshot.ExpBonus or 0,
	}
	self:_emitChanged()
end

local default = nil
function HudDataService.GetDefault()
	if not default then default = HudDataService.new() end
	return default
end
return HudDataService
