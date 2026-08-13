--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local EquipmentUpgradeConfig = require(ReplicatedStorage.Shared.Config.EquipmentUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

type Context = { Remotes: Folder?, EventBus: any?, Services: any?, ServiceRegistry: any? }

local EquipmentService = {}
EquipmentService.__index = EquipmentService

local function getService(context: Context, name: string)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

function EquipmentService.new(context: Context)
	local self = setmetatable({}, EquipmentService)
	self._context = context
	self._equipRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.EquipEquipment) :: RemoteEvent?
	self._unequipRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.UnequipEquipment) :: RemoteEvent?
	self._upgradeRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.UpgradeEquipment) :: RemoteEvent?
	return self
end

function EquipmentService:Init()
	if self._equipRemote then
		self._equipRemote.OnServerEvent:Connect(function(player: Player, instanceId: string)
			if RemoteContracts.Validate(RemoteContracts.Names.EquipEquipment, instanceId) then
				self:Equip(player, instanceId)
			end
		end)
	end
	if self._unequipRemote then
		self._unequipRemote.OnServerEvent:Connect(function(player: Player, slotType: string)
			if RemoteContracts.Validate(RemoteContracts.Names.UnequipEquipment, slotType) then
				self:Unequip(player, slotType)
			end
		end)
	end
	if self._upgradeRemote then
		self._upgradeRemote.OnServerEvent:Connect(function(player: Player, instanceId: string)
			if RemoteContracts.Validate(RemoteContracts.Names.UpgradeEquipment, instanceId) then
				self:Upgrade(player, instanceId)
			end
		end)
	end
end

function EquipmentService:_dataService()
	return getService(self._context, "PlayerDataService")
end

function EquipmentService:GetOwnedEquipment(player: Player): { [string]: any }
	local dataService = self:_dataService()
	if not dataService then return {} end
	return dataService:GetOwnedEquipment(player)
end

function EquipmentService:GetEquippedEquipment(player: Player): { [string]: any }
	local dataService = self:_dataService()
	if not dataService then return {} end
	return dataService:GetEquippedEquipment(player)
end

function EquipmentService:OwnsInstance(player: Player, instanceId: string): boolean
	return self:GetOwnedEquipment(player)[instanceId] ~= nil
end

function EquipmentService:Grant(player: Player, definitionId: string, fields: { [string]: any }?): (boolean, string?)
	local definition = EquipmentConfig.GetById(definitionId)
	if not definition then return false, nil end
	local dataService = self:_dataService()
	if not dataService then return false, nil end
	local instanceId = (fields and fields.instanceId) or HttpService:GenerateGUID(false)
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		data.OwnedEquipment[instanceId] = {
			definitionId = definitionId,
			level = math.max(1, math.floor(tonumber(fields and fields.level) or 1)),
			rarity = tostring((fields and fields.rarity) or definition.rarity),
			isTemporary = (fields and fields.isTemporary) == true,
			expiresAt = tonumber(fields and fields.expiresAt),
			acquiredAt = tonumber(fields and fields.acquiredAt) or os.time(),
			pity = if type(fields and fields.pity) == "table" then fields.pity else {},
		}
		return data
	end)
	return true, instanceId
end

function EquipmentService:Equip(player: Player, instanceId: string): (boolean, string?)
	if type(instanceId) ~= "string" or instanceId == "" then return false, "InvalidInstanceId" end
	local dataService = self:_dataService()
	if not dataService then return false, "MissingPlayerDataService" end
	local equippedInstance = nil
	local slotType = nil
	local ok = false
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		local ownedInstance = data.OwnedEquipment[instanceId]
		if type(ownedInstance) ~= "table" then return data end
		local definition = EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
		if not definition then return data end
		slotType = definition.slotType
		data.EquippedEquipment[slotType] = instanceId
		equippedInstance = ownedInstance
		ok = true
		return data
	end)
	if not ok then return false, "NotOwned" end
	if self._context.EventBus then
		self._context.EventBus:Fire("EquipmentEquipped", player, slotType, instanceId, equippedInstance)
	end
	local stateService = getService(self._context, "PlayerStateService")
	if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
		stateService:RecalculateDerivedStats(player, false)
	end
	return true, nil
end

function EquipmentService:Unequip(player: Player, slotType: string): (boolean, string?)
	if type(slotType) ~= "string" or not EquipmentConfig.IsValidSlot(slotType) then return false, "InvalidSlot" end
	local dataService = self:_dataService()
	if not dataService then return false, "MissingPlayerDataService" end
	local removedInstanceId = nil
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		removedInstanceId = data.EquippedEquipment[slotType]
		data.EquippedEquipment[slotType] = nil
		return data
	end)
	if removedInstanceId and self._context.EventBus then
		self._context.EventBus:Fire("EquipmentUnequipped", player, slotType, removedInstanceId)
	end
	local stateService = getService(self._context, "PlayerStateService")
	if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
		stateService:RecalculateDerivedStats(player, false)
	end
	return removedInstanceId ~= nil, if removedInstanceId then nil else "NothingEquipped"
end

function EquipmentService:GetPityState(player: Player, instanceId: string): any?
	local owned = self:GetOwnedEquipment(player)[instanceId]
	return type(owned) == "table" and owned.pity or nil
end

function EquipmentService:Upgrade(player: Player, instanceId: string): (boolean, string?)
	local dataService = self:_dataService()
	if not dataService or not self:OwnsInstance(player, instanceId) then return false, "NotOwned" end
	local owned = self:GetOwnedEquipment(player)[instanceId]
	local cost = EquipmentUpgradeConfig.GetUpgradeCost(tonumber(owned.level) or 1)
	if not dataService:SpendDiamonds(player, cost, "EquipmentUpgrade") then return false, "InsufficientDiamonds" end
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		data.OwnedEquipment[instanceId].level = math.max(1, math.floor(tonumber(data.OwnedEquipment[instanceId].level) or 1)) + 1
		return data
	end)
	if self._context.EventBus then
		self._context.EventBus:Fire("EquipmentUpdated", player, instanceId, self:GetOwnedEquipment(player)[instanceId])
	end
	return true, nil
end

return EquipmentService
