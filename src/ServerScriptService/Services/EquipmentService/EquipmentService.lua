--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local EquipmentUpgradeConfig = require(ReplicatedStorage.Shared.Config.EquipmentUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ServiceResolver = require(script.Parent.Parent.Infrastructure.ServiceResolver)

type Context = { Remotes: Folder?, EventBus: any?, Services: any?, ServiceRegistry: any? }

local EquipmentService = {}
EquipmentService.__index = EquipmentService


function EquipmentService.new(context: Context)
	local self = setmetatable({}, EquipmentService)
	self._context = context
	self._equipRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.EquipEquipment) :: RemoteEvent?
	self._unequipRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.UnequipEquipment) :: RemoteEvent?
	self._upgradeRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.UpgradeEquipment) :: RemoteEvent?
	return self
end

function EquipmentService:Init()
	-- [DEBUG_TRACE] print(string.format("[DIAG][EquipmentService] Init equipRemote=%s unequipRemote=%s upgradeRemote=%s t=%.3f", tostring(self._equipRemote ~= nil), tostring(self._unequipRemote ~= nil), tostring(self._upgradeRemote ~= nil), os.clock()))
	if self._equipRemote then
		self._equipRemote.OnServerEvent:Connect(function(player: Player, instanceId: string, slot: any)
			if RemoteContracts.Validate(RemoteContracts.Names.EquipEquipment, instanceId) then
				self:Equip(player, instanceId, slot)
			end
		end)
	end
	if self._unequipRemote then
		self._unequipRemote.OnServerEvent:Connect(function(player: Player, slot: any)
			if RemoteContracts.Validate(RemoteContracts.Names.UnequipEquipment, slot) then
				self:Unequip(player, slot)
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


function EquipmentService:_publishEquipResult(player: Player, result: { [string]: any })
	local feedbackRemote = self._context.Remotes and self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if feedbackRemote then
		feedbackRemote:FireClient(player, {
			EventType = "EquipmentEquipResult",
			Payload = result,
		})
	end
	if self._context.EventBus then
		self._context.EventBus:Fire("EquipmentEquipResult", player, result)
	end
end

function EquipmentService:_dataService()
	return ServiceResolver.Get(self._context, "PlayerDataService")
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

function EquipmentService:_normalizeSlot(slot: any): number?
	local legacySlotMap = { Core = 1, Module = 2, Charm = 3 }
	local slotNumber = tonumber(slot) or legacySlotMap[slot]
	if slotNumber and slotNumber % 1 == 0 and slotNumber >= 1 and slotNumber <= EquipmentConfig.EquippedSlotCount then
		return slotNumber
	end
	return nil
end

function EquipmentService:_findFirstOpenSlot(equipped: { [any]: string }): number?
	for slot = 1, EquipmentConfig.EquippedSlotCount do
		if equipped[slot] == nil then
			return slot
		end
	end
	return nil
end

function EquipmentService:Equip(player: Player, instanceId: string, preferredSlot: any?): (boolean, string?)
	-- [DEBUG_TRACE] print(string.format("[DIAG][EquipmentService] Equip requested player=%s instanceId=%s preferredSlot=%s t=%.3f", player.Name, tostring(instanceId), tostring(preferredSlot), os.clock()))
	if type(instanceId) ~= "string" or instanceId == "" then return false, "InvalidInstanceId" end
	local dataService = self:_dataService()
	if not dataService then return false, "MissingPlayerDataService" end
	local equippedInstance = nil
	local slotNumber = nil
	local replacedInstanceId = nil
	local ok = false
	local failure = "NotOwned"
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		local ownedInstance = data.OwnedEquipment[instanceId]
		if type(ownedInstance) ~= "table" then return data end
		local definition = EquipmentConfig.GetById(tostring(ownedInstance.definitionId or ""))
		if not definition then failure = "InvalidEquipment"; return data end
		for _, equippedInstanceId in pairs(data.EquippedEquipment) do
			if equippedInstanceId == instanceId then failure = "AlreadyEquipped"; return data end
		end
		slotNumber = self:_normalizeSlot(preferredSlot) or self:_findFirstOpenSlot(data.EquippedEquipment)
		if not slotNumber then failure = "NoOpenSlot"; return data end
		replacedInstanceId = data.EquippedEquipment[slotNumber]
		data.EquippedEquipment[slotNumber] = instanceId
		equippedInstance = ownedInstance
		ok = true
		return data
	end)
	if not ok then
		-- [DEBUG_TRACE] print(string.format("[DIAG][EquipmentService] Equip failed player=%s instanceId=%s failure=%s t=%.3f", player.Name, tostring(instanceId), tostring(failure), os.clock()))
		self:_publishEquipResult(player, { Status = "Rejected", Reason = failure, InstanceId = instanceId })
		return false, failure
	end
	-- [DEBUG_TRACE] print(string.format("[DIAG][EquipmentService] Equip committed player=%s instanceId=%s slot=%s definition=%s t=%.3f", player.Name, tostring(instanceId), tostring(slotNumber), tostring(equippedInstance and equippedInstance.definitionId), os.clock()))
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService and typeof(stateService.SyncEquipmentFromData) == "function" then stateService:SyncEquipmentFromData(player) end
	local isLauncherMode = stateService and typeof(stateService.IsLauncher) == "function" and stateService:IsLauncher(player)
	local equipResult = {
		Status = if isLauncherMode then "EquippedActive" else "EquippedVisualPending",
		Reason = if isLauncherMode then nil else "HumanModeNoHitbox",
		Message = if isLauncherMode then "Equipment equipped." else "Equipment saved. It will visually attach and activate when you switch to Launcher.",
		InstanceId = instanceId,
		DefinitionId = equippedInstance and equippedInstance.definitionId,
		ActivePlayerMode = if isLauncherMode then GameStates.PlayerMode.Launcher else GameStates.PlayerMode.Human,
	}
	self:_publishEquipResult(player, equipResult)
	if self._context.EventBus then
		if replacedInstanceId and replacedInstanceId ~= instanceId then
			self._context.EventBus:Fire("EquipmentUnequipped", player, slotNumber, replacedInstanceId)
		end
		self._context.EventBus:Fire("EquipmentEquipped", player, slotNumber, instanceId, equippedInstance)
	end
	if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
		stateService:RecalculateDerivedStats(player, false)
	end
	return true, nil
end

function EquipmentService:Unequip(player: Player, slot: any): (boolean, string?)
	-- [DEBUG_TRACE] print(string.format("[DIAG][EquipmentService] Unequip requested player=%s slot=%s t=%.3f", player.Name, tostring(slot), os.clock()))
	local slotNumber = self:_normalizeSlot(slot)
	if not slotNumber then return false, "InvalidSlot" end
	local dataService = self:_dataService()
	if not dataService then return false, "MissingPlayerDataService" end
	local removedInstanceId = nil
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		removedInstanceId = data.EquippedEquipment[slotNumber]
		data.EquippedEquipment[slotNumber] = nil
		return data
	end)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService and typeof(stateService.SyncEquipmentFromData) == "function" then stateService:SyncEquipmentFromData(player) end
	if removedInstanceId and self._context.EventBus then
		self._context.EventBus:Fire("EquipmentUnequipped", player, slotNumber, removedInstanceId)
	end
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
	local definition = EquipmentConfig.GetById(tostring(owned.definitionId or ""))
	local maxLevel = definition and EquipmentConfig.GetMaxLevelForRarity(definition.rarity) or EquipmentUpgradeConfig.MaxLevel
	local currentLevel = math.max(1, math.floor(tonumber(owned.level) or 1))
	if currentLevel >= maxLevel then return false, "MaxLevel" end
	local cost = EquipmentUpgradeConfig.GetUpgradeCost(currentLevel)
	if not dataService:SpendDiamonds(player, cost, "EquipmentUpgrade") then return false, "InsufficientDiamonds" end
	dataService:UpdateData(player, function(data)
		dataService:_ensureEquipmentData(data)
		data.OwnedEquipment[instanceId].level = math.min(maxLevel, currentLevel + 1)
		return data
	end)
	if self._context.EventBus then
		self._context.EventBus:Fire("EquipmentUpdated", player, instanceId, self:GetOwnedEquipment(player)[instanceId])
	end
	return true, nil
end

return EquipmentService
