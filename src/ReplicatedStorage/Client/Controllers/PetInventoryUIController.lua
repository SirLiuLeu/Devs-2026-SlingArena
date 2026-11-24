--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalizationService = game:GetService("LocalizationService")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetsUpgradeConfig = require(ReplicatedStorage.Shared.Config.PetsUpgradeConfig)
local PetPreviewConfig = require(ReplicatedStorage.Shared.Config.PetPreviewConfig)
local PetDisplayFormatter = require(ReplicatedStorage.Shared.Utils.PetDisplayFormatter)
local ConfirmationTextConfig = require(ReplicatedStorage.Shared.Config.ConfirmationTextConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)

local PetInventoryUIController = {}
PetInventoryUIController.__index = PetInventoryUIController

local NORMAL_COLOR = Color3.fromRGB(41, 43, 53)
local HOVER_COLOR = Color3.fromRGB(62, 66, 82)
local SELECTED_COLOR = Color3.fromRGB(88, 102, 132)
local PET_SLOT_TEMPLATE_NAME = "PetSlotTemplate_PetInventoryUI"

local function resolveGui(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return if value and value:IsA("GuiObject") then value else nil
end

local function resolveTextLabel(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return if value and value:IsA("TextLabel") then value else nil
end

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	return if value and value:IsA("TextButton") then value else nil
end

local function findDirectText(root: Instance, name: string): TextLabel?
	local child = root:FindFirstChild(name)
	return if child and child:IsA("TextLabel") then child else nil
end

local function getTemplateRoot(slot: Instance): GuiObject?
	local root = slot:FindFirstChild("Root")
	if root and root:IsA("GuiObject") then
		return root
	end
	warn(string.format("[PET_INVENTORY_UI] %s clone is missing its Root GuiObject.", PET_SLOT_TEMPLATE_NAME))
	return nil
end

local function countEntries(values): number
	local count = 0
	for _, value in pairs(values or {}) do
		if value ~= nil then count += 1 end
	end
	return count
end

function PetInventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({
		_playerGui = playerGui,
		_connections = {},
		_slotConnections = {},
		_petSlotMap = {},
		_selectedPetInstanceId = nil,
		_upgradePreviewPetInstanceId = nil,
		_upgradePendingPetInstanceId = nil,
		_upgradePendingLevel = nil,
		_deletePendingPetInstanceId = nil,
		_cachedSnapshot = nil,
	}, PetInventoryUIController)
end

function PetInventoryUIController:SetDataProvider(provider)
	self._dataProvider = provider
end

function PetInventoryUIController:SetConfirmationController(controller)
	self._confirmationController = controller
end

function PetInventoryUIController:Start(uiReadySignal: BindableEvent?)
	if self._started then
		return
	end
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then
		uiReadySignal.Event:Wait()
	end
	self._started = true

	local ui = ProjectTreeSpec.UI.PetInventory
	self._screenGui = PathResolver.resolvePath(self._playerGui, ui.ScreenGui) :: ScreenGui?
	self._grid = resolveGui(self._playerGui, ui.GridContainer)
	self._capacityLabel = resolveTextLabel(self._playerGui, ui.CapacityLabel)
	self._selectedName = resolveTextLabel(self._playerGui, ui.SelectedName)
	self._statLevel = resolveTextLabel(self._playerGui, ui.Stats.Level)
	self._statDamage = resolveTextLabel(self._playerGui, ui.Stats.Damage)
	self._statHP = resolveTextLabel(self._playerGui, ui.Stats.HP)
	self._statScript = resolveTextLabel(self._playerGui, ui.Stats.Script)
	self._deleteButton = resolveTextButton(self._playerGui, ui.DeleteButton)
	self._toggleEquipButton = resolveTextButton(self._playerGui, ui.ToggleEquipButton)
	self._upgradeButton = resolveTextButton(self._playerGui, ui.UpgradeButton)
	self._upgradePetRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.UpgradePet) :: RemoteEvent?

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._petTemplate = uiFolder and uiFolder:FindFirstChild(PET_SLOT_TEMPLATE_NAME)
	self._petAssets = assets and assets:FindFirstChild("Pets")

	if not self._screenGui then warn("[PET_INVENTORY_UI] PlayerGui.PetInventoryUI ScreenGui is missing.") end
	if not self._grid then warn("[PET_INVENTORY_UI] PetInventoryUI.Root.BodyPets.GridContainer is missing.") end
	if not self._capacityLabel then warn("[PET_INVENTORY_UI] PetInventoryUI.Root.BodyPets.Footer.CapacityLabel is missing.") end
	if not self._selectedName then warn("[PET_INVENTORY_UI] PetInventoryUI.Root.BodyPets.RightPanel.SelectedName is missing.") end
	if not self._statLevel then warn("[PET_INVENTORY_UI] PetInventoryUI Stats.Level is missing.") end
	if not self._statDamage then warn("[PET_INVENTORY_UI] PetInventoryUI Stats.Damage is missing.") end
	if not self._statHP then warn("[PET_INVENTORY_UI] PetInventoryUI Stats.HP is missing.") end
	if not self._statScript then warn("[PET_INVENTORY_UI] PetInventoryUI Stats.Script is missing.") end
	if not self._upgradePetRemote then warn("[PET_INVENTORY_UI] LauncherArenaRemotes.UpgradePet is missing.") end
	if not self._deleteButton then warn("[PET_INVENTORY_UI] PetInventoryUI DeleteButton is missing.") end
	if not self._toggleEquipButton then warn("[PET_INVENTORY_UI] PetInventoryUI ToggleEquipButton is missing.") end
	if not self._upgradeButton then warn("[PET_INVENTORY_UI] PetInventoryUI UpgradeButton is missing.") end
	if not (self._petTemplate and self._petTemplate:IsA("GuiObject")) then
		warn("[PET_INVENTORY_UI] ReplicatedStorage.Assets.UI.PetSlotTemplate_PetInventoryUI is missing.")
		self._petTemplate = nil
	end
	if not self._petAssets then warn("[PET_INVENTORY_UI] ReplicatedStorage.Assets.Pets is missing.") end

	if self._screenGui then
		self._screenGui.Enabled = false
	end
	-- Slot1..Slot4 are Studio layout placeholders; real Pet entries are cloned from
	-- PetSlotTemplate_PetInventoryUI so the grid always reflects the owned Pet data.
	if self._grid then
		for _, child in ipairs(self._grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	if self._toggleEquipButton then
		table.insert(self._connections, self._toggleEquipButton.Activated:Connect(function()
			if self._dataProvider then
				self._dataProvider:EquipSelectedPet()
			end
		end))
	end
	if self._deleteButton then
		table.insert(self._connections, self._deleteButton.Activated:Connect(function()
			self:_requestDeleteSelectedPet()
		end))
	end
	if self._upgradeButton then
		table.insert(self._connections, self._upgradeButton.Activated:Connect(function()
			self:_handleUpgradePressed()
		end))
	end

	local feedbackRemote = ReplicatedStorage:WaitForChild("LauncherArenaRemotes"):FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
		table.insert(self._connections, feedbackRemote.OnClientEvent:Connect(function(message)
			if type(message) ~= "table" or type(message.Payload) ~= "table" then
				return
			end
			if message.EventType == "PetUpgradeResult" then
				self._upgradePreviewPetInstanceId = nil
				self._upgradePendingPetInstanceId = nil
				self._upgradePendingLevel = nil
				if self._cachedSnapshot then self:RefreshWithData(self._cachedSnapshot) end
			elseif message.EventType == "PetDeleteResult" then
				local payload = message.Payload
				local deletedId = tostring(payload.InstanceId or "")
				self._deletePendingPetInstanceId = nil
				if payload.Status == "Deleted" and deletedId ~= "" and deletedId == self._selectedPetInstanceId and self._dataProvider then
					self._selectedPetInstanceId = nil
					self._dataProvider:SelectPet(nil)
				end
				if self._cachedSnapshot then self:RefreshWithData(self._cachedSnapshot) end
			end
		end))
	end

	if DebugConfig.VerboseTrace then
		print("[PET_INVENTORY_UI] Pet-only controller started.")
	end
end

function PetInventoryUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui.Parent then
		self._screenGui.Enabled = isVisible
	end
	if not isVisible then
		self._upgradePreviewPetInstanceId = nil
	elseif self._cachedSnapshot then
		self:RefreshWithData(self._cachedSnapshot)
	end
end

function PetInventoryUIController:_disconnectSlot(slot: Instance)
	local connections = self._slotConnections[slot]
	if not connections then return end
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	self._slotConnections[slot] = nil
end

function PetInventoryUIController:_applySlotVisual(slot: GuiObject, hovered: boolean, selected: boolean)
	slot.BackgroundColor3 = if selected then SELECTED_COLOR elseif hovered then HOVER_COLOR else NORMAL_COLOR
	local stroke = slot:FindFirstChildWhichIsA("UIStroke", true)
	if stroke then
		stroke.Thickness = if selected then 2 else 1
		stroke.Color = if selected then Color3.fromRGB(255, 230, 130) else Color3.fromRGB(120, 120, 120)
	end
end

function PetInventoryUIController:_populatePreview(slotRoot: Instance, definition: PetsConfig.PetDefinition)
	local preview = slotRoot:FindFirstChild("PetPreview")
	if not (preview and preview:IsA("ViewportFrame")) then
		warn("[PET_INVENTORY_UI] PetSlotTemplate_PetInventoryUI.Root.PetPreview ViewportFrame is missing.")
		return
	end
	if preview:GetAttribute("RenderedPetAbilityId") == definition.abilityId then
		return
	end
	local previewConfig = PetPreviewConfig.Get(definition.abilityId)
	PreviewRenderer.Populate(preview, self._petAssets, definition.modelName, previewConfig)
	preview:SetAttribute("RenderedPetAbilityId", definition.abilityId)
end

function PetInventoryUIController:_bindSlotContent(slot: GuiObject, petEntry)
	local instanceId = tostring(petEntry.instanceId or "")
	local abilityId = tostring(petEntry.abilityId or "")
	local definition = PetsConfig.GetByAbilityId(abilityId)
	local root = getTemplateRoot(slot)
	if not (root and definition) then
		if not definition then warn(string.format("[PET_INVENTORY_UI] Unknown Pet definition id %q.", abilityId)) end
		return
	end

	local nameLabel = findDirectText(root, "Name")
	local levelLabel = findDirectText(root, "Level")
	local equippedTag = findDirectText(root, "EquippedTag")

	if nameLabel then nameLabel.Text = definition.modelName end
	if levelLabel then levelLabel.Text = string.format("Lv.%d", PetsUpgradeConfig.NormalizeLevel(tonumber(petEntry.level) or 1)) end
	if equippedTag then
		equippedTag.Visible = petEntry.equipped == true
		equippedTag.Text = petEntry.equippedSlot and ("Slot " .. tostring(petEntry.equippedSlot)) or "Equipped"
	end
	self:_populatePreview(root, definition)
	slot:SetAttribute("PetInstanceId", instanceId)
end

function PetInventoryUIController:_bindSlotState(slot: GuiObject, instanceId: string)
	slot.Active = true
	slot.Selectable = true
	self:_applySlotVisual(slot, false, self._selectedPetInstanceId == instanceId)

	local clickTarget: GuiObject = slot
	local childButton = slot:FindFirstChildWhichIsA("GuiButton", true)
	if childButton then
		clickTarget = childButton
	end

	local connections = {}
	table.insert(connections, clickTarget.MouseEnter:Connect(function()
		self:_applySlotVisual(slot, true, self._selectedPetInstanceId == instanceId)
	end))
	table.insert(connections, clickTarget.MouseLeave:Connect(function()
		self:_applySlotVisual(slot, false, self._selectedPetInstanceId == instanceId)
	end))
	table.insert(connections, clickTarget.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self._selectedPetInstanceId ~= instanceId then
			self._upgradePreviewPetInstanceId = nil
		end
		self._selectedPetInstanceId = instanceId
		if self._dataProvider then
			self._dataProvider:SelectPet(instanceId)
		end
		if self._cachedSnapshot then
			self:RefreshWithData(self._cachedSnapshot)
		end
	end))
	self._slotConnections[slot] = connections
end

function PetInventoryUIController:_spawnPetSlot(petEntry)
	if not (self._grid and self._petTemplate and self._petTemplate:IsA("GuiObject")) then
		return
	end
	local instanceId = tostring(petEntry.instanceId or "")
	local abilityId = tostring(petEntry.abilityId or "")
	if instanceId == "" or not PetsConfig.GetByAbilityId(abilityId) then
		return
	end

	local slot = self._petTemplate:Clone()
	if not getTemplateRoot(slot) then
		slot:Destroy()
		return
	end
	slot.Name = "GeneratedPet_" .. instanceId
	slot.Visible = true
	slot.Parent = self._grid
	self:_bindSlotContent(slot, petEntry)
	self._petSlotMap[instanceId] = slot
	self:_bindSlotState(slot, instanceId)
end

function PetInventoryUIController:_reconcileSlots(data)
	local seen = {}
	for _, petEntry in ipairs(data.ownedPets or {}) do
		local instanceId = tostring(petEntry.instanceId or "")
		if instanceId ~= "" then
			seen[instanceId] = true
			local slot = self._petSlotMap[instanceId]
			if slot and slot.Parent then
				self:_bindSlotContent(slot, petEntry)
			else
				self:_spawnPetSlot(petEntry)
			end
		end
	end
	for instanceId, slot in pairs(self._petSlotMap) do
		if not seen[instanceId] then
			self._petSlotMap[instanceId] = nil
			self:_disconnectSlot(slot)
			if slot.Parent then slot:Destroy() end
		end
	end
end

function PetInventoryUIController:_findPetEntry(ownedPets, petInstanceId: string?)
	if not petInstanceId then return nil end
	for _, entry in ipairs(ownedPets or {}) do
		if tostring(entry.instanceId or "") == petInstanceId then
			return entry
		end
	end
	return nil
end

function PetInventoryUIController:_setButtonEnabled(button: TextButton?, enabled: boolean)
	if not button then return end
	button.Active = enabled
	button.AutoButtonColor = enabled
end

function PetInventoryUIController:_refreshPetPanel(data)
	self._selectedPetInstanceId = data.selectedPetInstanceId
	local petInstanceId = self._selectedPetInstanceId
	local entry = self:_findPetEntry(data.ownedPets, petInstanceId)
	local definition = entry and PetsConfig.GetByAbilityId(tostring(entry.abilityId or "")) or nil
	local level = PetsUpgradeConfig.NormalizeLevel(tonumber(entry and entry.level) or 1)

	if self._selectedName then
		self._selectedName.Text = definition and definition.modelName or "No pet selected"
	end

	local isPreviewing = entry ~= nil and self._upgradePreviewPetInstanceId == petInstanceId
	if entry and self._upgradePendingPetInstanceId == petInstanceId and self._upgradePendingLevel and level > self._upgradePendingLevel then
		self._upgradePreviewPetInstanceId = nil
		self._upgradePendingPetInstanceId = nil
		self._upgradePendingLevel = nil
		isPreviewing = false
	end
	local displayText = PetDisplayFormatter.Format(definition, level, isPreviewing, LocalizationService.RobloxLocaleId)

	if self._statLevel then self._statLevel.Text = displayText.LevelText; self._statLevel.RichText = true end
	if self._statDamage then self._statDamage.Text = displayText.DamageText; self._statDamage.RichText = true end
	if self._statHP then self._statHP.Text = displayText.HPText; self._statHP.RichText = true end
	if self._statScript then self._statScript.Text = displayText.ScriptText; self._statScript.RichText = true end

	local equipped = entry and entry.equipped == true
	local deleting = self._deletePendingPetInstanceId ~= nil
	if self._toggleEquipButton then
		self._toggleEquipButton.Text = if equipped then "Unequip" else "Equip"
		self:_setButtonEnabled(self._toggleEquipButton, entry ~= nil and not deleting and self._upgradePendingPetInstanceId == nil)
	end

	if self._deleteButton then
		self._deleteButton.Text = if self._deletePendingPetInstanceId == petInstanceId then "Deleting..." else "Delete"
		self:_setButtonEnabled(self._deleteButton, entry ~= nil and not deleting)
	end

	local upgrading = entry ~= nil and self._upgradePendingPetInstanceId == petInstanceId
	local cost = PetsUpgradeConfig.GetUpgradeCost(level, (definition and definition.rarity) or "Common")
	if self._upgradeButton then
		self._upgradeButton.Text = if level >= PetsUpgradeConfig.MaxLevel and entry ~= nil
			then "MAX"
			elseif upgrading then "Upgrading..."
			elseif isPreviewing then string.format("Confirm Upgrade (%d Diamonds)", cost)
			else string.format("Upgrade %d Diamonds", cost)
		self:_setButtonEnabled(self._upgradeButton, entry ~= nil and level < PetsUpgradeConfig.MaxLevel and self._upgradePendingPetInstanceId == nil and not deleting)
	end
end

function PetInventoryUIController:_refreshSlotVisuals()
	for instanceId, slot in pairs(self._petSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedPetInstanceId == instanceId)
		end
	end
end

function PetInventoryUIController:_handleUpgradePressed()
	local petInstanceId = self._selectedPetInstanceId
	local entry = self._cachedSnapshot and self:_findPetEntry(self._cachedSnapshot.ownedPets, petInstanceId) or nil
	if not (entry and petInstanceId and self._upgradePetRemote) then
		return
	end
	if self._upgradePendingPetInstanceId or self._deletePendingPetInstanceId then
		return
	end
	local level = PetsUpgradeConfig.NormalizeLevel(tonumber(entry.level) or 1)
	if level >= PetsUpgradeConfig.MaxLevel then
		return
	end

	if self._upgradePreviewPetInstanceId ~= petInstanceId then
		self._upgradePreviewPetInstanceId = petInstanceId
		self:_refreshPetPanel(self._cachedSnapshot)
		return
	end

	self._upgradePendingPetInstanceId = petInstanceId
	self._upgradePendingLevel = level
	self:_refreshPetPanel(self._cachedSnapshot)
	self._upgradePetRemote:FireServer(petInstanceId, level)
end

function PetInventoryUIController:_requestDeleteSelectedPet()
	local petInstanceId = self._selectedPetInstanceId
	local entry = self._cachedSnapshot and self:_findPetEntry(self._cachedSnapshot.ownedPets, petInstanceId) or nil
	local definition = entry and PetsConfig.GetByAbilityId(tostring(entry.abilityId or "")) or nil
	if not (petInstanceId and entry and definition and self._dataProvider) then
		return
	end
	if self._deletePendingPetInstanceId or self._upgradePendingPetInstanceId then
		return
	end
	if not self._confirmationController then
		warn("[PET_INVENTORY_UI] Delete confirmation controller is unavailable; Pet was not deleted.")
		return
	end

	local text = ConfirmationTextConfig.Get(
		"DeletePet",
		{ petName = definition.modelName },
		LocalizationService.RobloxLocaleId
	)
	self._confirmationController:RequestConfirm(text, function()
		if self._selectedPetInstanceId ~= petInstanceId then
			return
		end
		self._deletePendingPetInstanceId = petInstanceId
		local requested = self._dataProvider:DeleteSelectedPet()
		if not requested then
			self._deletePendingPetInstanceId = nil
		end
		if self._cachedSnapshot then self:_refreshPetPanel(self._cachedSnapshot) end
	end)
end

function PetInventoryUIController:RefreshWithData(data)
	self._cachedSnapshot = data
	if not (self._screenGui and self._screenGui.Enabled) then
		return
	end
	self:_reconcileSlots(data)
	if self._capacityLabel then
		local ownedCount = #(data.ownedPets or {})
		local capacity = math.max(0, math.floor(tonumber(data.petCapacity) or 0))
		self._capacityLabel.Text = string.format(
			"Capacity: %d/%d | Equipped: %d/%d",
			ownedCount,
			capacity,
			countEntries(data.equippedPets),
			PetsConfig.EquippedSlotCount
		)
	end
	self:_refreshPetPanel(data)
	self:_refreshSlotVisuals()
end

function PetInventoryUIController:Destroy()
	for slot in pairs(self._slotConnections) do
		self:_disconnectSlot(slot)
	end
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._petSlotMap)
end

return PetInventoryUIController
