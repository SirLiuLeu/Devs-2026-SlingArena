--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ServiceResolver = require(script.Parent.Parent.Infrastructure.ServiceResolver)

type Context = { Remotes: Folder?, EventBus: any?, Services: any?, ServiceRegistry: any? }

local PetService = {}
PetService.__index = PetService


function PetService.new(context: Context)
	local self = setmetatable({}, PetService)
	self._context = context
	self._equipRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.EquipPet) :: RemoteEvent?
	self._unequipRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.UnequipPet) :: RemoteEvent?
	self._upgradeRemote = context.Remotes and context.Remotes:FindFirstChild(RemoteContracts.Names.UpgradePet) :: RemoteEvent?
	return self
end

function PetService:Init()
	-- [DEBUG_TRACE] print(string.format("[DIAG][PetService] Init equipRemote=%s unequipRemote=%s upgradeRemote=%s t=%.3f", tostring(self._equipRemote ~= nil), tostring(self._unequipRemote ~= nil), tostring(self._upgradeRemote ~= nil), os.clock()))
	if self._equipRemote then
		self._equipRemote.OnServerEvent:Connect(function(player: Player, instanceId: string, slot: any)
			if RemoteContracts.Validate(RemoteContracts.Names.EquipPet, instanceId) then
				self:Equip(player, instanceId, slot)
			end
		end)
	end
	if self._unequipRemote then
		self._unequipRemote.OnServerEvent:Connect(function(player: Player, slot: any)
			if RemoteContracts.Validate(RemoteContracts.Names.UnequipPet, slot) then
				self:Unequip(player, slot)
			end
		end)
	end
	if self._upgradeRemote then
		self._upgradeRemote.OnServerEvent:Connect(function(player: Player, instanceId: string)
			if RemoteContracts.Validate(RemoteContracts.Names.UpgradePet, instanceId) then
				self:Upgrade(player, instanceId)
			end
		end)
	end
end


function PetService:_publishEquipResult(player: Player, result: { [string]: any })
	local feedbackRemote = self._context.Remotes and self._context.Remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if feedbackRemote then
		feedbackRemote:FireClient(player, {
			EventType = "PetEquipResult",
			Payload = result,
		})
	end
	if self._context.EventBus then
		self._context.EventBus:Fire("PetEquipResult", player, result)
	end
end

function PetService:_dataService()
	return ServiceResolver.Get(self._context, "PlayerDataService")
end

function PetService:GetOwnedPets(player: Player): { [string]: any }
	local dataService = self:_dataService()
	if not dataService then return {} end
	return dataService:GetOwnedPets(player)
end

function PetService:GetEquippedPets(player: Player): { [string]: any }
	local dataService = self:_dataService()
	if not dataService then return {} end
	return dataService:GetEquippedPets(player)
end

function PetService:OwnsInstance(player: Player, instanceId: string): boolean
	return self:GetOwnedPets(player)[instanceId] ~= nil
end

local STARTER_PET = PetsConfig.GetAllIds()

function PetService:GrantStarterPet(player: Player): boolean
	local dataService = self:_dataService()
	if not dataService then return false end
	local owned = self:GetOwnedPets(player)
	if next(owned) ~= nil then return false end
	for index, definitionId in ipairs(STARTER_PET) do
		self:Grant(player, definitionId, { instanceId = "starter_pet_" .. definitionId })
	end
	return true
end

function PetService:Grant(player: Player, definitionId: string, fields: { [string]: any }?): (boolean, string?)
	local definition = PetsConfig.GetById(definitionId)
	if not definition then return false, nil end
	local dataService = self:_dataService()
	if not dataService then return false, nil end
	local instanceId = (fields and fields.instanceId) or HttpService:GenerateGUID(false)
	dataService:UpdateData(player, function(data)
		dataService:_ensurePetData(data)
		data.OwnedPets[instanceId] = {
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

function PetService:_normalizeSlot(slot: any): number?
	local legacySlotMap = { Core = 1, Module = 2, Charm = 3 }
	local slotNumber = tonumber(slot) or legacySlotMap[slot]
	if slotNumber and slotNumber % 1 == 0 and slotNumber >= 1 and slotNumber <= PetsConfig.EquippedSlotCount then
		return slotNumber
	end
	return nil
end

function PetService:_findFirstOpenSlot(equipped: { [any]: string }): number?
	for slot = 1, PetsConfig.EquippedSlotCount do
		if equipped[slot] == nil then
			return slot
		end
	end
	return nil
end

function PetService:Equip(player: Player, instanceId: string, preferredSlot: any?): (boolean, string?)
	-- [DEBUG_TRACE] print(string.format("[DIAG][PetService] Equip requested player=%s instanceId=%s preferredSlot=%s t=%.3f", player.Name, tostring(instanceId), tostring(preferredSlot), os.clock()))
	if type(instanceId) ~= "string" or instanceId == "" then return false, "InvalidInstanceId" end
	local dataService = self:_dataService()
	if not dataService then return false, "MissingPlayerDataService" end
	local equippedInstance = nil
	local slotNumber = nil
	local replacedInstanceId = nil
	local ok = false
	local failure = "NotOwned"
	dataService:UpdateData(player, function(data)
		dataService:_ensurePetData(data)
		local ownedInstance = data.OwnedPets[instanceId]
		if type(ownedInstance) ~= "table" then return data end
		local definition = PetsConfig.GetById(tostring(ownedInstance.definitionId or ""))
		if not definition then failure = "InvalidPet"; return data end
		for _, equippedInstanceId in pairs(data.EquippedPets) do
			if equippedInstanceId == instanceId then failure = "AlreadyEquipped"; return data end
		end
		slotNumber = self:_normalizeSlot(preferredSlot) or self:_findFirstOpenSlot(data.EquippedPets)
		if not slotNumber then failure = "NoOpenSlot"; return data end
		replacedInstanceId = data.EquippedPets[slotNumber]
		data.EquippedPets[slotNumber] = instanceId
		equippedInstance = ownedInstance
		ok = true
		return data
	end)
	if not ok then
		-- [DEBUG_TRACE] print(string.format("[DIAG][PetService] Equip failed player=%s instanceId=%s failure=%s t=%.3f", player.Name, tostring(instanceId), tostring(failure), os.clock()))
		self:_publishEquipResult(player, { Status = "Rejected", Reason = failure, InstanceId = instanceId })
		return false, failure
	end
	-- [DEBUG_TRACE] print(string.format("[DIAG][PetService] Equip committed player=%s instanceId=%s slot=%s definition=%s t=%.3f", player.Name, tostring(instanceId), tostring(slotNumber), tostring(equippedInstance and equippedInstance.definitionId), os.clock()))
	print(string.format("[Pet] Equipping item: %s", tostring(equippedInstance and equippedInstance.definitionId or instanceId)))
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService and typeof(stateService.SyncPetFromData) == "function" then stateService:SyncPetFromData(player) end
	local isLauncherMode = stateService and typeof(stateService.IsLauncher) == "function" and stateService:IsLauncher(player)
	local equipResult = {
		Status = if isLauncherMode then "EquippedActive" else "EquippedVisualPending",
		Reason = if isLauncherMode then nil else "HumanModeNoHitbox",
		Message = if isLauncherMode then "Pet equipped." else "Pet saved. It will visually attach and activate when you switch to Launcher.",
		InstanceId = instanceId,
		DefinitionId = equippedInstance and equippedInstance.definitionId,
		ActivePlayerMode = if isLauncherMode then GameStates.PlayerMode.Launcher else GameStates.PlayerMode.Human,
	}
	self:_publishEquipResult(player, equipResult)
	if self._context.EventBus then
		if replacedInstanceId and replacedInstanceId ~= instanceId then
			self._context.EventBus:Fire("PetUnequipped", player, slotNumber, replacedInstanceId)
		end
		self._context.EventBus:Fire("PetEquipped", player, slotNumber, instanceId, equippedInstance)
	end
	if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
		stateService:RecalculateDerivedStats(player, false)
	end
	return true, nil
end

function PetService:Unequip(player: Player, slot: any): (boolean, string?)
	-- [DEBUG_TRACE] print(string.format("[DIAG][PetService] Unequip requested player=%s slot=%s t=%.3f", player.Name, tostring(slot), os.clock()))
	local slotNumber = self:_normalizeSlot(slot)
	if not slotNumber then return false, "InvalidSlot" end
	local dataService = self:_dataService()
	if not dataService then return false, "MissingPlayerDataService" end
	local removedInstanceId = nil
	dataService:UpdateData(player, function(data)
		dataService:_ensurePetData(data)
		removedInstanceId = data.EquippedPets[slotNumber]
		data.EquippedPets[slotNumber] = nil
		return data
	end)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService and typeof(stateService.SyncPetFromData) == "function" then stateService:SyncPetFromData(player) end
	if removedInstanceId and self._context.EventBus then
		self._context.EventBus:Fire("PetUnequipped", player, slotNumber, removedInstanceId)
	end
	if stateService and typeof(stateService.RecalculateDerivedStats) == "function" then
		stateService:RecalculateDerivedStats(player, false)
	end
	return removedInstanceId ~= nil, if removedInstanceId then nil else "NothingEquipped"
end

function PetService:GetPityState(player: Player, instanceId: string): any?
	local owned = self:GetOwnedPets(player)[instanceId]
	return type(owned) == "table" and owned.pity or nil
end

function PetService:Upgrade(player: Player, instanceId: string): (boolean, string?)
	local dataService = self:_dataService()
	if not dataService or not self:OwnsInstance(player, instanceId) then return false, "NotOwned" end
	local owned = self:GetOwnedPets(player)[instanceId]
	local definition = PetsConfig.GetById(tostring(owned.definitionId or ""))
	local maxLevel = definition and PetsConfig.GetMaxLevelForRarity(definition.rarity) or PetsUpgradeConfig.MaxLevel
	local currentLevel = math.max(1, math.floor(tonumber(owned.level) or 1))
	if currentLevel >= maxLevel then return false, "MaxLevel" end
	local cost = PetsUpgradeConfig.GetUpgradeCost(currentLevel)
	if not dataService:SpendDiamonds(player, cost, "PetUpgrade") then return false, "InsufficientDiamonds" end
	dataService:UpdateData(player, function(data)
		dataService:_ensurePetData(data)
		data.OwnedPets[instanceId].level = math.min(maxLevel, currentLevel + 1)
		return data
	end)
	if self._context.EventBus then
		self._context.EventBus:Fire("PetUpdated", player, instanceId, self:GetOwnedPets(player)[instanceId])
	end
	return true, nil
end

return PetService
