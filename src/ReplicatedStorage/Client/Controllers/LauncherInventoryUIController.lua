--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ConfirmationTextConfig = require(ReplicatedStorage.Shared.Config.ConfirmationTextConfig)
local LauncherPreviewConfig = require(ReplicatedStorage.Shared.Config.LauncherPreviewConfig)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PreviewRenderer = require(ReplicatedStorage.Shared.Utils.PreviewRenderer)

local LauncherInventoryUIController = {}
LauncherInventoryUIController.__index = LauncherInventoryUIController

local LAUNCHER_SLOT_TEMPLATE_NAME = "LauncherSlotTemplate_LauncherInventoryUI"

local function resolveGui(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path)
	return if value and value:IsA("GuiObject") then value else nil
end

local function resolveText(root: Instance, path: string): TextLabel?
	local value = PathResolver.resolvePath(root, path)
	return if value and value:IsA("TextLabel") then value else nil
end

local function resolveButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	return if value and value:IsA("TextButton") then value else nil
end

local function getSlotRoot(slot: Instance): GuiObject?
	local root = slot:FindFirstChild("Root")
	return if root and root:IsA("GuiObject") then root else nil
end

local function findText(root: Instance, name: string): TextLabel?
	local value = root:FindFirstChild(name, true)
	return if value and value:IsA("TextLabel") then value else nil
end

function LauncherInventoryUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {}, _slotConnections = {}, _slotMap = {}, _selected = nil }, LauncherInventoryUIController)
end

function LauncherInventoryUIController:SetDataProvider(provider)
	self._provider = provider
end

function LauncherInventoryUIController:SetConfirmationController(controller)
	self._confirmation = controller
end

function LauncherInventoryUIController:SetToastController(controller)
	self._toast = controller
end

function LauncherInventoryUIController:_showToast(message: string)
	if self._toast and typeof(self._toast.Enqueue) == "function" then
		self._toast:Enqueue({ Type = "Generic", Text = message })
	else
		warn("[LAUNCHER_INVENTORY_UI] " .. message)
	end
end

function LauncherInventoryUIController:Start(uiReadySignal: BindableEvent?)
	if uiReadySignal and uiReadySignal:GetAttribute("IsReady") ~= true then
		uiReadySignal.Event:Wait()
	end

	self._gui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ScreenGui) :: ScreenGui?
	self._grid = resolveGui(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.GridContainer)
	self._capacity = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CapacityLabel)
	self._name = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.SelectedName)
	self._damage = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.Damage)
	self._hp = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.HP)
	self._range = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.Range)
	self._regen = resolveText(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.Stats.Regeneration)
	self._equip = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.EquipButton)
	self._sell = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.SellButton)
	if not self._equip then
		warn("[LAUNCHER_INVENTORY_UI] Missing StarterGui.LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.EquiptButton; create/rename this GuiButton in Studio.")
	end
	if not self._sell then
		warn("[LAUNCHER_INVENTORY_UI] Missing StarterGui.LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.SellButton; create/rename this TextButton in Studio.")
	end

	local assets = ReplicatedStorage:WaitForChild("Assets")
	self._launcherAssets = assets:FindFirstChild("Launchers")
	local uiFolder = assets:FindFirstChild("UI")
	local template = uiFolder and uiFolder:FindFirstChild(LAUNCHER_SLOT_TEMPLATE_NAME)
	self._template = if template and template:IsA("GuiObject") then template else nil
	if not self._template then
		warn("[LAUNCHER_INVENTORY_UI] " .. LAUNCHER_SLOT_TEMPLATE_NAME .. " missing in ReplicatedStorage.Assets.UI")
		self._template = nil
	end
	if not self._launcherAssets then
		warn("[LAUNCHER_INVENTORY_UI] ReplicatedStorage.Assets.Launchers missing")
	end

	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	self._equipRemote = remotes:FindFirstChild(RemoteContracts.Names.EquipLauncher) :: RemoteEvent?
	self._sellRemote = remotes:FindFirstChild(RemoteContracts.Names.SellLauncher) :: RemoteEvent?
	self._feedbackRemote = remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if self._equip then
		table.insert(self._connections, self._equip.Activated:Connect(function()
			local entry = self._selected
			print(string.format(
				"[LAUNCHER_INVENTORY_UI] stage=equip_clicked player=%s locationState=%s playerMode=%s instanceId=%s launcherId=%s equipped=%s",
				Players.LocalPlayer.Name,
				tostring(Players.LocalPlayer:GetAttribute("LocationState")),
				tostring(Players.LocalPlayer:GetAttribute("ActivePlayerMode")),
				tostring(entry and entry.instanceId),
				tostring(entry and entry.id),
				tostring(entry and entry.equipped)
			))
			if not self:_inLobby() then
				warn("[LAUNCHER_INVENTORY_UI] stage=equip_blocked reason=NotInLobby")
				return
			end
			if not entry then
				warn("[LAUNCHER_INVENTORY_UI] stage=equip_blocked reason=NoSelection")
				return
			end
			if entry.equipped == true then
				warn(string.format("[LAUNCHER_INVENTORY_UI] stage=equip_blocked reason=AlreadyEquipped instanceId=%s launcherId=%s", tostring(entry.instanceId), tostring(entry.id)))
				return
			end
			if type(entry.instanceId) ~= "string" or entry.instanceId == "" then
				warn("[LAUNCHER_INVENTORY_UI] Equip ignored: selected Launcher has no owned instanceId.")
				return
			end
			if not (self._equipRemote and self._equipRemote:IsA("RemoteEvent")) then
				warn("[LAUNCHER_INVENTORY_UI] Missing ReplicatedStorage.LauncherArenaRemotes.EquipLauncher (RemoteEvent).")
				return
			end
			print(string.format("[LAUNCHER_INVENTORY_UI] Equip request sent: player=%s instanceId=%s definitionId=%s", Players.LocalPlayer.Name, entry.instanceId, tostring(entry.id)))
			local requestedInstanceId = entry.instanceId
			self._pendingEquipInstanceId = requestedInstanceId
			self:_refreshRightPanel()
			self._equipRemote:FireServer(requestedInstanceId)
			task.delay(8, function()
				if self._pendingEquipInstanceId == requestedInstanceId then
					self._pendingEquipInstanceId = nil
					warn(string.format(
						"[LAUNCHER_INVENTORY_UI] stage=equip_feedback_timeout instanceId=%s timeoutSeconds=8; check GameplayFeedback remote and server logs",
						requestedInstanceId
					))
					self:_refreshRightPanel()
				end
			end)
		end))
	end
	if self._sell then
		self._sell.Text = "Sell"
		table.insert(self._connections, self._sell.Activated:Connect(function()
			local entry = self._selected
			print(string.format(
				"[LAUNCHER_INVENTORY_UI] stage=sell_clicked player=%s locationState=%s playerMode=%s instanceId=%s launcherId=%s equipped=%s",
				Players.LocalPlayer.Name,
				tostring(Players.LocalPlayer:GetAttribute("LocationState")),
				tostring(Players.LocalPlayer:GetAttribute("ActivePlayerMode")),
				tostring(entry and entry.instanceId),
				tostring(entry and entry.id),
				tostring(entry and entry.equipped)
			))
			if not self:_inLobby() then
				warn("[LAUNCHER_INVENTORY_UI] stage=sell_blocked reason=NotInLobby")
				return
			end
			if not entry then
				warn("[LAUNCHER_INVENTORY_UI] stage=sell_blocked reason=NoSelection")
				return
			end
			local blockReason = self:_getSellBlockReason(entry)
			if blockReason then
				warn(string.format(
					"[LAUNCHER_INVENTORY_UI] stage=sell_blocked reason=%s instanceId=%s launcherId=%s equipped=%s temporary=%s expiresAt=%s sellPrice=%d",
					blockReason,
					tostring(entry.instanceId),
					tostring(entry.id),
					tostring(entry.equipped),
					tostring(self:_isTemporary(entry)),
					tostring(entry.expiresAt),
					self:_getSellPrice(entry)
				))
				self:_showToast(ConfirmationTextConfig.Get("LauncherSellFailed", { reason = blockReason }))
				return
			end
			if type(entry.instanceId) ~= "string" or entry.instanceId == "" then
				warn("[LAUNCHER_INVENTORY_UI] stage=sell_blocked reason=MissingInstanceId")
				return
			end
			if not self._confirmation then
				warn("[LAUNCHER_INVENTORY_UI] stage=sell_blocked reason=ConfirmationControllerMissing")
				return
			end

			local instanceId = entry.instanceId
			local price = self:_getSellPrice(entry)
			local confirmationShown = self._confirmation:RequestConfirm(
				ConfirmationTextConfig.Get("SellLauncher", { price = price }),
				function()
					print(string.format(
						"[LAUNCHER_INVENTORY_UI] stage=sell_confirm_action confirmed=true instanceId=%s",
						instanceId
					))
					if not (self._sellRemote and self._sellRemote:IsA("RemoteEvent")) then
						warn("[LAUNCHER_INVENTORY_UI] stage=sell_request_blocked reason=SellLauncherRemoteMissing")
						return
					end
					self._pendingSellInstanceId = instanceId
					self:_refreshRightPanel()
					print(string.format(
						"[LAUNCHER_INVENTORY_UI] stage=sell_request_sent player=%s instanceId=%s pricePreview=%d",
						Players.LocalPlayer.Name,
						instanceId,
						price
					))
					self._sellRemote:FireServer(instanceId)
					task.delay(8, function()
						if self._pendingSellInstanceId == instanceId then
							self._pendingSellInstanceId = nil
						warn(string.format(
							"[LAUNCHER_INVENTORY_UI] stage=sell_feedback_timeout instanceId=%s timeoutSeconds=8; check GameplayFeedback remote and server logs",
							instanceId
						))
							self:_refreshRightPanel()
						end
					end)
				end,
				function()
					print(string.format("[LAUNCHER_INVENTORY_UI] stage=sell_confirm_action confirmed=false instanceId=%s", instanceId))
				end
			)
			if not confirmationShown then
				warn(string.format("[LAUNCHER_INVENTORY_UI] stage=sell_confirmation_blocked instanceId=%s reason=ConfirmationNotShown", instanceId))
			end
		end))
	end
	if self._feedbackRemote and self._feedbackRemote:IsA("RemoteEvent") then
		table.insert(self._connections, self._feedbackRemote.OnClientEvent:Connect(function(message)
			if type(message) ~= "table" or type(message.Payload) ~= "table" then return end
			if message.EventType == "LauncherEquipResult" or message.EventType == "LauncherSellResult" then
				print(string.format("[LAUNCHER_INVENTORY_UI] stage=feedback_received event=%s success=%s reason=%s", tostring(message.EventType), tostring(message.Payload.Success), tostring(message.Payload.Reason)))
			end
			local payload = message.Payload
			if message.EventType == "LauncherEquipResult" then
				self._pendingEquipInstanceId = nil
				if payload.Success == true then
					local visualStatus = tostring(payload.VisualStatus or "Updated")
					if visualStatus == "Failed" or visualStatus == "PawnUnavailable" then
						warn(string.format("[LAUNCHER_INVENTORY_UI] Equip persisted, but live Launcher visual status is %s. launcherId=%s", visualStatus, tostring(payload.LauncherId)))
						self:_showToast(ConfirmationTextConfig.Get("LauncherEquipVisualFailed"))
					else
						print(string.format("[LAUNCHER_INVENTORY_UI] Equip succeeded: launcherId=%s visualStatus=%s", tostring(payload.LauncherId), visualStatus))
						self:_showToast(ConfirmationTextConfig.Get("LauncherEquipSuccess"))
					end
				else
					local reason = tostring(payload.Reason or "Unknown")
					warn(string.format("[LAUNCHER_INVENTORY_UI] Equip rejected: reason=%s", reason))
					self:_showToast(ConfirmationTextConfig.Get("LauncherEquipFailed", { reason = reason }))
				end
			elseif message.EventType == "LauncherSellResult" then
				self._pendingSellInstanceId = nil
				if payload.Success == true then
					local salePrice = math.max(0, math.floor(tonumber(payload.SalePrice) or 0))
					print(string.format("[LAUNCHER_INVENTORY_UI] Sell succeeded: price=%d", salePrice))
					self:_showToast(ConfirmationTextConfig.Get("LauncherSellSuccess", { price = salePrice }))
				else
					local reason = tostring(payload.Reason or "Unknown")
					warn(string.format("[LAUNCHER_INVENTORY_UI] Launcher sale rejected: reason=%s", reason))
					self:_showToast(ConfirmationTextConfig.Get("LauncherSellFailed", { reason = reason }))
				end
			end
			self:_refreshRightPanel()
		end))
	end

	if not (self._feedbackRemote and self._feedbackRemote:IsA("RemoteEvent")) then
		warn("[LAUNCHER_INVENTORY_UI] stage=startup_missing_feedback_remote path=ReplicatedStorage.LauncherArenaRemotes.GameplayFeedback")
	end

	if self._provider then
		self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end)
		self._latestSnapshot = self._provider:GetSnapshot()
	end
	self:SetVisible(false)
end

function LauncherInventoryUIController:_inLobby(): boolean
	return Players.LocalPlayer:GetAttribute("LocationState") == nil or Players.LocalPlayer:GetAttribute("LocationState") == "Lobby"
end

function LauncherInventoryUIController:SetVisible(value: boolean)
	if self._gui then
		self._gui.Enabled = value
		if value and self._latestSnapshot then
			self:Render(self._latestSnapshot)
		end
	end
end

function LauncherInventoryUIController:_entryKey(entry): string
	return tostring(entry.instanceId or entry.id or "")
end

function LauncherInventoryUIController:_isTemporary(entry): boolean
	return entry ~= nil and (entry.isTemporary == true or tonumber(entry.expiresAt) ~= nil)
end

function LauncherInventoryUIController:_getSellPrice(entry): number
	if self:_isTemporary(entry) then return LauncherConfig.TemporarySellPrice end
	local definition = entry and LauncherConfig.GetById(entry.id)
	return math.max(0, math.floor(tonumber(definition and definition.sellPrice) or 0))
end

function LauncherInventoryUIController:_getSellBlockReason(entry): string?
	if not entry then return "NoSelection" end
	if self:_entryKey(entry) == "default_normal_launcher" then return "ProtectedLauncher" end
	if entry.equipped == true then return "Equipped" end
	local expiresAt = tonumber(entry.expiresAt)
	if expiresAt and expiresAt <= os.time() then return "Expired" end
	if self:_getSellPrice(entry) <= 0 then return "NoSellPrice" end
	return nil
end

function LauncherInventoryUIController:_canSell(entry): boolean
	-- Any owned Launcher may be sold regardless of duplicate status. The server
	-- remains authoritative for ownership, protection rules, expiry, and payout.
	return self:_getSellBlockReason(entry) == nil
end

function LauncherInventoryUIController:_bindSlot(slot: GuiObject, entry)
	local connection = slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._selected = entry
			if self._provider then self._provider:SelectLauncher(self:_entryKey(entry)) end
			self:_refreshRightPanel()
			self:_refreshSlotVisuals()
		end
	end)
	self._slotConnections[slot] = connection
end

function LauncherInventoryUIController:_updateSlot(slot: GuiObject, entry)
	local root = getSlotRoot(slot)
	local definition = LauncherConfig.GetById(entry.id)
	slot.Name = "GeneratedLauncher_" .. self:_entryKey(entry)
	if not root then
		warn("[LAUNCHER_INVENTORY_UI] Launcher slot is missing Root GuiObject")
	else
		if not definition then
			warn(string.format("[LAUNCHER_INVENTORY_UI] Launcher definition missing for %q", tostring(entry.id)))
		end

		local name = findText(root, "Name")
		if name then name.Text = entry.name or (definition and definition.name) or "Unknown launcher" end
		local level = math.max(1, math.floor(tonumber(entry.level) or 1))
		local levelText = findText(root, "Level")
		if levelText then levelText.Text = string.format("Lv.%d", level) end
		local equipped = findText(root, "EquippedTag")
		if equipped then equipped.Visible = entry.equipped == true end
		local stars = root:FindFirstChild("Stars")
		if stars then
			for index = 1, 5 do
				local star = stars:FindFirstChild("Star" .. index)
				if star and star:IsA("GuiObject") then star.Visible = index <= math.clamp(level, 1, 5) end
			end
		end

		local launcherPreviewViewport = root:FindFirstChild("LauncherPreview")
		if launcherPreviewViewport and launcherPreviewViewport:IsA("ViewportFrame") then
			if slot:GetAttribute("CurrentRenderedId") ~= entry.id then
				PreviewRenderer.Populate(launcherPreviewViewport, self._launcherAssets, entry.id, LauncherPreviewConfig.Get(entry.id))
				slot:SetAttribute("CurrentRenderedId", entry.id)
			end
		else
			warn("[LAUNCHER_INVENTORY_UI] LauncherSlotTemplate_LauncherInventoryUI.Root.LauncherPreview ViewportFrame missing; create it in Studio")
		end
	end
end

function LauncherInventoryUIController:_spawnSlot(entry)
	if not self._grid or not self._template then return end
	local slot = self._template:Clone()
	slot.Visible = true
	slot.Parent = self._grid
	self:_updateSlot(slot, entry)
	self:_bindSlot(slot, entry)
	self._slotMap[self:_entryKey(entry)] = slot
end

function LauncherInventoryUIController:_refreshSlotVisuals()
	for key, slot in pairs(self._slotMap) do
		if slot.Parent then
			slot.BackgroundTransparency = if self._selected and key == self:_entryKey(self._selected) then 0 else 0.2
		end
	end
end

function LauncherInventoryUIController:_refreshRightPanel()
	local entry = self._selected
	local definition = entry and LauncherConfig.GetById(entry.id) or nil
	local stats = entry and entry.stats or nil
	if self._name then self._name.Text = (entry and (entry.name or (definition and definition.name))) or "No launcher selected" end
	if self._damage then self._damage.Text = string.format("Damage: %.2f", (stats and stats.damage) or (definition and definition.stats.launchPower) or 0) end
	if self._hp then self._hp.Text = string.format("HP: %.0f", (stats and stats.hp) or 0) end
	if self._range then self._range.Text = string.format("Weight: %.2f", (stats and stats.weight) or (definition and definition.stats.weight) or 0) end
	if self._regen then self._regen.Text = string.format("Regeneration: %.2f", (stats and stats.regen) or (definition and definition.stats.regen) or 0) end
	local hasSelection = entry ~= nil
	local entryKey = if entry then self:_entryKey(entry) else ""
	local equipPending = self._pendingEquipInstanceId ~= nil and self._pendingEquipInstanceId == entryKey
	local sellPending = self._pendingSellInstanceId ~= nil and self._pendingSellInstanceId == entryKey
	local canEquip = self:_inLobby() and hasSelection and entry.equipped ~= true and not equipPending
	local canSell = self:_inLobby() and self:_canSell(entry) and not sellPending
	if self._equip then
		self._equip.Text = if entry and entry.equipped then "Equipped" elseif equipPending then "Equipping..." else "Equip"
		-- Keep the button clickable for selected entries so blocked actions can explain why.
		self._equip.Active = hasSelection and not equipPending
		self._equip.AutoButtonColor = canEquip
		self._equip.TextTransparency = if canEquip then 0 else 0.5
	end
	if self._sell then
		self._sell.Text = if sellPending then "Selling..." else "Sell"
		-- Do not silently disable Sell for an equipped/protected Launcher; the click handler logs the exact reason.
		self._sell.Active = hasSelection and not sellPending
		self._sell.AutoButtonColor = canSell
		self._sell.TextTransparency = if canSell then 0 else 0.5
	end
end

function LauncherInventoryUIController:Render(snapshot)
	self._latestSnapshot = snapshot
	if self._gui and self._gui.Enabled == false then return end
	if not self._grid then return end
	local seen = {}
	for _, entry in ipairs(snapshot.ownedLaunchers or {}) do
		local key = self:_entryKey(entry)
		if key ~= "" then
			seen[key] = true
			local slot = self._slotMap[key]
			if slot and slot.Parent then self:_updateSlot(slot, entry) else self:_spawnSlot(entry) end
			if self._selected and self:_entryKey(self._selected) == key then self._selected = entry end
		end
	end
	for key, slot in pairs(self._slotMap) do
		if not seen[key] then
			local connection = self._slotConnections[slot]
			if connection then connection:Disconnect(); self._slotConnections[slot] = nil end
			if slot.Parent then slot:Destroy() end
			self._slotMap[key] = nil
			if self._selected and self:_entryKey(self._selected) == key then self._selected = nil end
		end
	end
	if self._capacity then self._capacity.Text = string.format("Capacity: %d/%d", #(snapshot.ownedLaunchers or {}), snapshot.launcherCapacity or 0) end
	self:_refreshRightPanel()
	self:_refreshSlotVisuals()
end

function LauncherInventoryUIController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	for _, connection in pairs(self._slotConnections) do connection:Disconnect() end
	if self._providerConnection then self._providerConnection:Disconnect() end
	for key, slot in pairs(self._slotMap) do
		if slot then slot:Destroy() end
		self._slotMap[key] = nil
	end
	table.clear(self._slotConnections)
end

return LauncherInventoryUIController
