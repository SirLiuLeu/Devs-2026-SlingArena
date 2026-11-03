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

local function formatRemainingLifetime(entry): string
	local expiresAt = tonumber(entry.expiresAt or entry.ExpiresAt or entry.remainingLifetimeEndsAt or entry.RemainingLifetimeEndsAt)
	if expiresAt then
		local remaining = math.max(0, math.ceil(expiresAt - os.time()))
		if remaining > 0 then
			return string.format("%ds", remaining)
		end
		return "Expired"
	end
	local remainingSeconds = tonumber(entry.remainingLifetimeSeconds or entry.RemainingLifetimeSeconds or entry.remainingTime or entry.RemainingTime)
	if remainingSeconds and remainingSeconds > 0 then
		return string.format("%ds", math.ceil(remainingSeconds))
	end
	return "Permanent"
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
		_selectedPetId = nil,
		_upgradePreviewPetId = nil,
		_upgradePendingPetId = nil,
		_upgradePendingLevel = nil,
		_deletePendingPetId = nil,
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
				self._upgradePreviewPetId = nil
				self._upgradePendingPetId = nil
				self._upgradePendingLevel = nil
				if self._cachedSnapshot then self:RefreshWithData(self._cachedSnapshot) end
			elseif message.EventType == "PetDeleteResult" then
				local payload = message.Payload
				local deletedId = tostring(payload.InstanceId or "")
				self._deletePendingPetId = nil
				if payload.Status == "Deleted" and deletedId ~= "" and deletedId == self._selectedPetId and self._dataProvider then
					self._selectedPetId = nil
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
		self._upgradePreviewPetId = nil
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
	if preview:GetAttribute("RenderedPetId") == definition.PetId then
		return
	end
	local previewConfig = PetPreviewConfig.Get(definition.PetId)
	PreviewRenderer.Populate(preview, self._petAssets, definition.Name, previewConfig)
	preview:SetAttribute("RenderedPetId", definition.PetId)
end

function PetInventoryUIController:_bindSlotContent(slot: GuiObject, petEntry)
	local instanceId = tostring(petEntry.instanceId or "")
	local definitionId = tostring(petEntry.definitionId or petEntry.id or "")
	local definition = PetsConfig.GetById(definitionId)
	local root = getTemplateRoot(slot)
	if not (root and definition) then
		if not definition then warn(string.format("[PET_INVENTORY_UI] Unknown Pet definition id %q.", definitionId)) end
		return
	end

	local nameLabel = findDirectText(root, "Name")
	local levelLabel = findDirectText(root, "Level")
	local remainingTimeLabel = findDirectText(root, "RemainingTimeText")
	local equippedTag = findDirectText(root, "EquippedTag")

	if nameLabel then nameLabel.Text = definition.DisplayName end
	if levelLabel then levelLabel.Text = string.format("Lv.%d", PetsUpgradeConfig.NormalizeLevel(tonumber(petEntry.level) or 1)) end
	if remainingTimeLabel then remainingTimeLabel.Text = formatRemainingLifetime(petEntry) end
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
	self:_applySlotVisual(slot, false, self._selectedPetId == instanceId)

	local clickTarget: GuiObject = slot
	local childButton = slot:FindFirstChildWhichIsA("GuiButton", true)
	if childButton then
		clickTarget = childButton
	end

	local connections = {}
	table.insert(connections, clickTarget.MouseEnter:Connect(function()
		self:_applySlotVisual(slot, true, self._selectedPetId == instanceId)
	end))
	table.insert(connections, clickTarget.MouseLeave:Connect(function()
		self:_applySlotVisual(slot, false, self._selectedPetId == instanceId)
	end))
	table.insert(connections, clickTarget.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self._selectedPetId ~= instanceId then
			self._upgradePreviewPetId = nil
		end
		self._selectedPetId = instanceId
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
	local definitionId = tostring(petEntry.definitionId or petEntry.id or "")
	if instanceId == "" or not PetsConfig.GetById(definitionId) then
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

function PetInventoryUIController:_findPetEntry(ownedPets, petId: string?)
	if not petId then return nil end
	for _, entry in ipairs(ownedPets or {}) do
		if tostring(entry.instanceId or "") == petId or tostring(entry.id or "") == petId then
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
	self._selectedPetId = data.selectedPetId or self._selectedPetId
	local petId = self._selectedPetId
	local entry = self:_findPetEntry(data.ownedPets, petId)
	local definition = entry and PetsConfig.GetById(tostring(entry.definitionId or entry.id or "")) or nil
	local level = PetsUpgradeConfig.NormalizeLevel(tonumber(entry and entry.level) or 1)

	if self._selectedName then
		self._selectedName.Text = definition and definition.DisplayName or "No pet selected"
	end

	local isPreviewing = entry ~= nil and self._upgradePreviewPetId == petId
	if entry and self._upgradePendingPetId == petId and self._upgradePendingLevel and level > self._upgradePendingLevel then
		self._upgradePreviewPetId = nil
		self._upgradePendingPetId = nil
		self._upgradePendingLevel = nil
		isPreviewing = false
	end
	local displayText = PetDisplayFormatter.Format(definition, level, isPreviewing, LocalizationService.RobloxLocaleId)

	if self._statLevel then self._statLevel.Text = displayText.LevelText; self._statLevel.RichText = true end
	if self._statDamage then self._statDamage.Text = displayText.DamageText; self._statDamage.RichText = true end
	if self._statHP then self._statHP.Text = displayText.HPText; self._statHP.RichText = true end
	if self._statScript then self._statScript.Text = displayText.ScriptText; self._statScript.RichText = true end

	local equipped = entry and entry.equipped == true
	if self._toggleEquipButton then
		self._toggleEquipButton.Text = if equipped then "Unequip" else "Equip"
		self:_setButtonEnabled(self._toggleEquipButton, entry ~= nil)
	end

	local deleting = entry ~= nil and self._deletePendingPetId == petId
	if self._deleteButton then
		self._deleteButton.Text = if deleting then "Deleting..." else "Delete"
		self:_setButtonEnabled(self._deleteButton, entry ~= nil and not deleting)
	end

	local upgrading = entry ~= nil and self._upgradePendingPetId == petId
	local cost = PetsUpgradeConfig.GetUpgradeCost(level, (definition and definition.rarity) or "Common")
	if self._upgradeButton then
		self._upgradeButton.Text = if level >= PetsUpgradeConfig.MaxLevel and entry ~= nil
			then "MAX"
			elseif upgrading then "Upgrading..."
			elseif isPreviewing then string.format("Confirm Upgrade (%d Diamonds)", cost)
			else string.format("Upgrade %d Diamonds", cost)
		self:_setButtonEnabled(self._upgradeButton, entry ~= nil and level < PetsUpgradeConfig.MaxLevel and not upgrading)
	end
end

function PetInventoryUIController:_refreshSlotVisuals()
	for instanceId, slot in pairs(self._petSlotMap) do
		if slot and slot.Parent then
			self:_applySlotVisual(slot, false, self._selectedPetId == instanceId)
		end
	end
end

function PetInventoryUIController:_handleUpgradePressed()
	local petId = self._selectedPetId
	local entry = self._cachedSnapshot and self:_findPetEntry(self._cachedSnapshot.ownedPets, petId) or nil
	if not (entry and petId and self._upgradePetRemote) then
		return
	end
	if self._upgradePendingPetId then
		return
	end
	local level = PetsUpgradeConfig.NormalizeLevel(tonumber(entry.level) or 1)
	if level >= PetsUpgradeConfig.MaxLevel then
		return
	end

	if self._upgradePreviewPetId ~= petId then
		self._upgradePreviewPetId = petId
		self:_refreshPetPanel(self._cachedSnapshot)
		return
	end

	self._upgradePendingPetId = petId
	self._upgradePendingLevel = level
	self:_refreshPetPanel(self._cachedSnapshot)
	self._upgradePetRemote:FireServer(petId, level)
end

function PetInventoryUIController:_requestDeleteSelectedPet()
	local petId = self._selectedPetId
	local entry = self._cachedSnapshot and self:_findPetEntry(self._cachedSnapshot.ownedPets, petId) or nil
	local definition = entry and PetsConfig.GetById(tostring(entry.definitionId or entry.id or "")) or nil
	if not (petId and entry and definition and self._dataProvider) then
		return
	end
	if self._deletePendingPetId then
		return
	end
	if not self._confirmationController then
		warn("[PET_INVENTORY_UI] Delete confirmation controller is unavailable; Pet was not deleted.")
		return
	end

	local text = ConfirmationTextConfig.Get(
		"DeletePet",
		{ petName = definition.DisplayName },
		LocalizationService.RobloxLocaleId
	)
	self._confirmationController:RequestConfirm(text, function()
		if self._selectedPetId ~= petId then
			return
		end
		self._deletePendingPetId = petId
		local requested = self._dataProvider:DeleteSelectedPet()
		if not requested then
			self._deletePendingPetId = nil
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
