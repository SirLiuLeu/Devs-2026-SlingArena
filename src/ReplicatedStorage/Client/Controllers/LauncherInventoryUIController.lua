--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local RarityConfig = require(ReplicatedStorage.Shared.Config.RarityConfig)
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
	return setmetatable({
		_playerGui = playerGui,
		_connections = {},
		_slotConnections = {},
		_slotMap = {},
		_selected = nil,
		_combineMode = false,
		_selectedCombineEntries = {},
		_pendingCombine = false,
		_combineRequestCounter = 0,
		_pendingCombineRequestId = nil,
	}, LauncherInventoryUIController)
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
	self._combineButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineButton)
	self._combineControls = resolveGui(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineControls)
	self._cancelCombineButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CancelCombineButton)
	self._confirmCombineButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.ConfirmCombineButton)
	self._combineConfirmFrame = resolveGui(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineConfirmFrame)
	self._combineBackButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineBackButton)
	self._combineModalConfirmButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineConfirmButton)
	self._combineDialog = resolveGui(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineDialog)
	self._combineOutputSlot = resolveGui(self._playerGui, ProjectTreeSpec.UI.LauncherInventory.CombineOutputSlot)
	self._combineInputSlots = {}
	for index, slotPath in ipairs(ProjectTreeSpec.UI.LauncherInventory.CombineInputSlots) do
		self._combineInputSlots[index] = resolveGui(self._playerGui, slotPath)
	end
	if not self._equip then
		warn("[LAUNCHER_INVENTORY_UI] Missing StarterGui.LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.EquiptButton; create/rename this GuiButton in Studio.")
	end
	if not self._sell then
		warn("[LAUNCHER_INVENTORY_UI] Missing StarterGui.LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.SellButton; create/rename this TextButton in Studio.")
	end
	if not self._combineButton then warn("[LAUNCHER_INVENTORY_UI] Missing LauncherInventoryUI.Root.BodyLauncher.RightPanel.ActionButtons.CombineButton.") end
	if not self._combineControls or not self._cancelCombineButton or not self._confirmCombineButton then
		warn("[LAUNCHER_INVENTORY_UI] CombineControls must contain CancelButton and ConfirmCombineButton.")
	end
	if not self._combineConfirmFrame or not self._combineBackButton or not self._combineModalConfirmButton or not self._combineDialog or not self._combineOutputSlot then
		warn("[LAUNCHER_INVENTORY_UI] CombineConfirmFrame tree is incomplete; check ProjectTreeSpec.UI.LauncherInventory.")
	end
	for index = 1, 3 do
		if not self._combineInputSlots[index] then
			warn(string.format("[LAUNCHER_INVENTORY_UI] Missing CombineConfirmFrame.Dialog.InputLaunchers.InputSlot%d.", index))
		end
	end

	if self._combineControls then self._combineControls.Visible = false end
	if self._combineConfirmFrame then self._combineConfirmFrame.Visible = false end

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
	self._combineRemote = remotes:FindFirstChild(RemoteContracts.Names.CombineLaunchers) :: RemoteEvent?
	self._feedbackRemote = remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent?
	if self._combineButton then
		table.insert(self._connections, self._combineButton.Activated:Connect(function()
			self:_enterCombineMode()
		end))
	end
	if self._cancelCombineButton then
		table.insert(self._connections, self._cancelCombineButton.Activated:Connect(function()
			self:_exitCombineMode()
		end))
	end
	if self._confirmCombineButton then
		table.insert(self._connections, self._confirmCombineButton.Activated:Connect(function()
			self:_openCombineConfirmation()
		end))
	end
	if self._combineBackButton then
		table.insert(self._connections, self._combineBackButton.Activated:Connect(function()
			if self._combineConfirmFrame then self._combineConfirmFrame.Visible = false end
		end))
	end
	if self._combineModalConfirmButton then
		table.insert(self._connections, self._combineModalConfirmButton.Activated:Connect(function()
			self:_requestCombine()
		end))
	end

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
			elseif message.EventType == "LauncherCombineResult" then
				if payload.RequestId ~= self._pendingCombineRequestId then
					return
				end
				if payload.Success == true and type(payload.ResultLauncher) == "table" then
					-- The server response invalidates the request timeout; keep the controls locked through animation.
					self._pendingCombineRequestId = nil
					self:_showToast("Combine successful!")
					self._combineServerResult = payload.ResultLauncher
					task.spawn(function()
						local animationOk, animationError = pcall(function()
							self:_playCombineAnimation(payload.ResultLauncher)
						end)
						if not animationOk then
							warn(string.format("[LAUNCHER_INVENTORY_UI] Combine animation failed: %s", tostring(animationError)))
							self._pendingCombine = false
							self._pendingCombineRequestId = nil
							if self._combineModalConfirmButton then self._combineModalConfirmButton.Text = "Confirm" end
							self:_exitCombineMode()
						end
					end)
				else
					self._pendingCombine = false
					self._pendingCombineRequestId = nil
					local reason = tostring(payload.Reason or "Unknown")
					warn(string.format("[LAUNCHER_INVENTORY_UI] Combine rejected: reason=%s", reason))
					self:_showToast("Could not combine Launchers: " .. reason)
					self:_refreshCombineButtons()
				end
			end
			self:_refreshRightPanel()
			self:_refreshCombineButtons()
		end))
	end

	if not (self._feedbackRemote and self._feedbackRemote:IsA("RemoteEvent")) then
		warn("[LAUNCHER_INVENTORY_UI] stage=startup_missing_feedback_remote path=ReplicatedStorage.LauncherArenaRemotes.GameplayFeedback")
	end
	if not (self._combineRemote and self._combineRemote:IsA("RemoteEvent")) then
		warn("[LAUNCHER_INVENTORY_UI] Missing ReplicatedStorage.LauncherArenaRemotes.CombineLaunchers.")
	end

	if self._provider then
		self._providerConnection = self._provider:BindChanged(function(snapshot) self:Render(snapshot) end)
		self._latestSnapshot = self._provider:GetSnapshot()
	end
	self:SetVisible(false)
end


function LauncherInventoryUIController:_findEntryByKey(entryKey: string)
	for _, entry in ipairs((self._latestSnapshot and self._latestSnapshot.ownedLaunchers) or {}) do
		if self:_entryKey(entry) == entryKey then
			return entry
		end
	end
	return nil
end

function LauncherInventoryUIController:_getRarity(entry)
	return RarityConfig.GetById(entry and entry.rarity) or RarityConfig.GetByStar(entry and entry.star)
end

function LauncherInventoryUIController:_isCombineCandidate(entry): boolean
	if not entry or type(entry.instanceId) ~= "string" or entry.instanceId == "" then return false end
	if entry.instanceId == "default_normal_launcher" or entry.equipped == true then return false end
	if self:_isTemporary(entry) then return false end
	local expiresAt = tonumber(entry.expiresAt)
	if expiresAt and expiresAt <= os.time() then return false end
	local rarity = self:_getRarity(entry)
	if not rarity or not RarityConfig.GetNext(rarity.id) then return false end
	return LauncherConfig.GetById(entry.id) ~= nil
end

function LauncherInventoryUIController:_combineGroupKey(entry): string
	local rarity = self:_getRarity(entry)
	return string.format("%s|%s|%d", tostring(entry.id), tostring(rarity and rarity.id or "Common"), math.max(1, math.floor(tonumber(entry.star) or 1)))
end

function LauncherInventoryUIController:_getEligibleCombineMap(entries)
	local groupCounts = {}
	for _, entry in ipairs(entries or {}) do
		if self:_isCombineCandidate(entry) then
			local groupKey = self:_combineGroupKey(entry)
			groupCounts[groupKey] = (groupCounts[groupKey] or 0) + 1
		end
	end

	local eligible = {}
	for _, entry in ipairs(entries or {}) do
		if self:_isCombineCandidate(entry) then
			local groupKey = self:_combineGroupKey(entry)
			if (groupCounts[groupKey] or 0) >= 3 then
				eligible[self:_entryKey(entry)] = true
			end
		end
	end
	return eligible
end

function LauncherInventoryUIController:_refreshCombineButtons()
	local selectedCount = #self._selectedCombineEntries
	local canConfirm = self._combineMode and selectedCount == 3 and not self._pendingCombine
	if self._confirmCombineButton then
		self._confirmCombineButton.Active = canConfirm
		self._confirmCombineButton.AutoButtonColor = canConfirm
		self._confirmCombineButton.TextTransparency = if canConfirm then 0 else 0.5
	end
	if self._combineModalConfirmButton then
		self._combineModalConfirmButton.Active = not self._pendingCombine
		self._combineModalConfirmButton.AutoButtonColor = not self._pendingCombine
	end
	if self._combineBackButton then
		self._combineBackButton.Active = not self._pendingCombine
		self._combineBackButton.AutoButtonColor = not self._pendingCombine
	end
end

function LauncherInventoryUIController:_enterCombineMode()
	if not self:_inLobby() then
		self:_showToast("Combine is only available in the Lobby.")
		return
	end
	if self._pendingCombine then return end
	self._combineMode = true
	self._selected = nil
	table.clear(self._selectedCombineEntries)
	if self._combineConfirmFrame then self._combineConfirmFrame.Visible = false end
	if self._combineControls then self._combineControls.Visible = true end
	if self._combineButton then self._combineButton.Visible = false end
	self:_refreshRightPanel()
	self:_refreshCombineButtons()
	if self._latestSnapshot then self:Render(self._latestSnapshot) end
end

function LauncherInventoryUIController:_exitCombineMode()
	if self._pendingCombine then return end
	self._combineMode = false
	table.clear(self._selectedCombineEntries)
	self._combineServerResult = nil
	if self._combineControls then self._combineControls.Visible = false end
	if self._combineConfirmFrame then self._combineConfirmFrame.Visible = false end
	if self._combineButton then self._combineButton.Visible = true end
	self:_refreshRightPanel()
	if self._latestSnapshot then self:Render(self._latestSnapshot) end
end

function LauncherInventoryUIController:_toggleCombineSelection(entry)
	if not self._combineMode or self._pendingCombine then return end
	if not self:_isCombineCandidate(entry) then
		self:_showToast("This Launcher cannot be combined.")
		return
	end

	local selectedIndex = nil
	for index, selected in ipairs(self._selectedCombineEntries) do
		if self:_entryKey(selected) == self:_entryKey(entry) then
			selectedIndex = index
			break
		end
	end

	if selectedIndex then
		table.remove(self._selectedCombineEntries, selectedIndex)
	else
		if #self._selectedCombineEntries >= 3 then
			self:_showToast("Select exactly 3 Launchers.")
			return
		end
		local firstSelected = self._selectedCombineEntries[1]
		if firstSelected and self:_combineGroupKey(firstSelected) ~= self:_combineGroupKey(entry) then
			self:_showToast("Select 3 Launchers with the same type and rarity.")
			return
		end
		table.insert(self._selectedCombineEntries, entry)
	end

	self:_refreshSlotVisuals()
	self:_refreshCombineButtons()
end

function LauncherInventoryUIController:_findLauncherDisplay(holder: GuiObject): GuiObject?
	local named = holder:FindFirstChild(LAUNCHER_SLOT_TEMPLATE_NAME)
	if named and named:IsA("GuiObject") and getSlotRoot(named) then return named end
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("GuiObject") and getSlotRoot(child) then return child end
	end
	return nil
end

function LauncherInventoryUIController:_populatePreviewHolder(holder: GuiObject?, entry)
	if not holder or not self._template then return nil end
	local display = self:_findLauncherDisplay(holder)
	if not display then
		display = self._template:Clone()
		display.Name = LAUNCHER_SLOT_TEMPLATE_NAME
		display.Parent = holder
	end
	display.Visible = true
	display.Position = UDim2.fromScale(0, 0)
	display.Size = UDim2.fromScale(1, 1)
	self:_updateSlot(display, entry)
	return display
end

function LauncherInventoryUIController:_makeCombineResultPreview()
	if #self._selectedCombineEntries ~= 3 then return nil end
	local first = self._selectedCombineEntries[1]
	local nextRarity = RarityConfig.GetNext(self:_getRarity(first).id)
	if not nextRarity then return nil end
	local highestLevel = 1
	for _, entry in ipairs(self._selectedCombineEntries) do
		highestLevel = math.max(highestLevel, math.max(1, math.floor(tonumber(entry.level) or 1)))
	end
	local definition = LauncherConfig.GetById(first.id)
	return {
		instanceId = "combine_preview",
		definitionId = first.id,
		id = first.id,
		name = (definition and definition.name) or first.name or first.id,
		star = nextRarity.star,
		rarity = nextRarity.id,
		level = highestLevel,
		equipped = false,
	}
end

function LauncherInventoryUIController:_openCombineConfirmation()
	if not self._combineMode or #self._selectedCombineEntries ~= 3 then
		self:_showToast("Select exactly 3 identical Launchers first.")
		return
	end
	for _, selected in ipairs(self._selectedCombineEntries) do
		local latest = self:_findEntryByKey(self:_entryKey(selected))
		if not latest or not self:_isCombineCandidate(latest) then
			self:_showToast("The selected Launchers are no longer available.")
			if self._latestSnapshot then self:Render(self._latestSnapshot) end
			return
		end
	end
	local resultPreview = self:_makeCombineResultPreview()
	if not resultPreview then
		self:_showToast("This Launcher has reached maximum rarity.")
		return
	end
	if not (self._combineConfirmFrame and self._combineOutputSlot) then
		warn("[LAUNCHER_INVENTORY_UI] Cannot open Combine confirmation: missing modal UI references.")
		return
	end

	self._combineResultPreview = resultPreview
	for index = 1, 3 do
		local holder = self._combineInputSlots[index]
		if holder then
			self:_populatePreviewHolder(holder, self._selectedCombineEntries[index])
		end
	end
	self:_populatePreviewHolder(self._combineOutputSlot, resultPreview)
	self._combineConfirmFrame.Visible = true
	self:_refreshCombineButtons()
end

function LauncherInventoryUIController:_requestCombine()
	if self._pendingCombine or #self._selectedCombineEntries ~= 3 then return end
	if not (self._combineRemote and self._combineRemote:IsA("RemoteEvent")) then
		warn("[LAUNCHER_INVENTORY_UI] CombineLaunchers RemoteEvent is missing.")
		self:_showToast("Combine is temporarily unavailable.")
		return
	end

	local instanceIds = {}
	for _, selected in ipairs(self._selectedCombineEntries) do
		local latest = self:_findEntryByKey(self:_entryKey(selected))
		if not latest or not self:_isCombineCandidate(latest) then
			self:_showToast("The selected Launchers are no longer eligible.")
			return
		end
		table.insert(instanceIds, latest.instanceId)
	end
	if #instanceIds ~= 3 then return end
	self._combineRequestCounter += 1
	local requestId = self._combineRequestCounter
	self._pendingCombineRequestId = requestId
	self._pendingCombine = true
	if self._combineModalConfirmButton then
		self._combineModalConfirmButton.Text = "Combining..."
		self._combineModalConfirmButton.Active = false
		self._combineModalConfirmButton.AutoButtonColor = false
	end
	self:_refreshCombineButtons()
	self._combineRemote:FireServer({ instanceIds = instanceIds, requestId = requestId })
	task.delay(8, function()
		if self._pendingCombine and self._pendingCombineRequestId == requestId then
			self._pendingCombine = false
			self._pendingCombineRequestId = nil
			warn("[LAUNCHER_INVENTORY_UI] Combine feedback timeout; server result was not received.")
			self:_showToast("Combine request timed out. Please check your inventory.")
			if self._combineModalConfirmButton then
				self._combineModalConfirmButton.Text = "Confirm"
			end
			self:_refreshCombineButtons()
		end
	end)
end

local function setGuiTreeZIndex(root: Instance, zIndex: number)
	if root:IsA("GuiObject") then root.ZIndex = zIndex end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = zIndex + 1
		end
	end
end

local function scaleUDim2(value: UDim2, multiplier: number): UDim2
	return UDim2.new(
		value.X.Scale * multiplier,
		value.X.Offset * multiplier,
		value.Y.Scale * multiplier,
		value.Y.Offset * multiplier
	)
end

function LauncherInventoryUIController:_playCombineAnimation(resultData)
	if self._gui and not self._gui.Enabled then
		self._pendingCombine = false
		self._pendingCombineRequestId = nil
		self:_exitCombineMode()
		return
	end
	if not (self._combineConfirmFrame and self._combineDialog and self._combineOutputSlot) then
		self._pendingCombine = false
		self._pendingCombineRequestId = nil
		self:_exitCombineMode()
		return
	end
	local definitionId = tostring(resultData.definitionId or resultData.id or "")
	local definition = LauncherConfig.GetById(definitionId)
	local rarity = RarityConfig.GetById(resultData.rarity) or RarityConfig.GetByStar(resultData.star)
	local resultEntry = {
		instanceId = tostring(resultData.instanceId or "combined_launcher"),
		definitionId = definitionId,
		id = definitionId,
		name = (definition and definition.name) or definitionId,
		star = rarity.star,
		rarity = rarity.id,
		level = math.max(1, math.floor(tonumber(resultData.level) or 1)),
		equipped = false,
	}
	local outputDisplay = self:_populatePreviewHolder(self._combineOutputSlot, resultEntry)
	if not outputDisplay then
		self:_exitCombineMode()
		return
	end

	local dialogPosition = self._combineDialog.AbsolutePosition
	local outputPosition = self._combineOutputSlot.AbsolutePosition
	local outputSize = self._combineOutputSlot.AbsoluteSize
	local targetCenter = outputPosition + outputSize / 2
	local flightTweens = {}

	for index = 1, 3 do
		local holder = self._combineInputSlots[index]
		local display = holder and self:_findLauncherDisplay(holder) or nil
		if holder and display then
			local holderPosition = holder.AbsolutePosition
			local holderSize = holder.AbsoluteSize
			local startCenter = holderPosition + holderSize / 2
			local flight = display:Clone()
			flight.Name = "CombineFlight_" .. tostring(index)
			flight.AnchorPoint = Vector2.new(0.5, 0.5)
			flight.Position = UDim2.fromOffset(startCenter.X - dialogPosition.X, startCenter.Y - dialogPosition.Y)
			flight.Size = UDim2.fromOffset(holderSize.X, holderSize.Y)
			flight.Parent = self._combineDialog
			setGuiTreeZIndex(flight, 50)
			display.Visible = false

			local targetLocal = targetCenter - dialogPosition
			local targetSmallSize = Vector2.new(math.max(24, outputSize.X * 0.28), math.max(24, outputSize.Y * 0.28))
			local tween = TweenService:Create(
				flight,
				TweenInfo.new(0.48, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.fromOffset(targetLocal.X, targetLocal.Y),
					Size = UDim2.fromOffset(targetSmallSize.X, targetSmallSize.Y),
				}
			)
			table.insert(flightTweens, { instance = flight, tween = tween })
		end
	end

	for _, flightInfo in ipairs(flightTweens) do
		flightInfo.tween:Play()
	end
	for _, flightInfo in ipairs(flightTweens) do
		flightInfo.tween.Completed:Wait()
		flightInfo.instance:Destroy()
	end

	for index = 1, 3 do
		local holder = self._combineInputSlots[index]
		local display = holder and self:_findLauncherDisplay(holder) or nil
		if display then display.Visible = true end
	end

	local originalSize = outputDisplay.Size
	local originalPosition = outputDisplay.Position
	outputDisplay.AnchorPoint = Vector2.new(0.5, 0.5)
	outputDisplay.Position = UDim2.fromScale(0.5, 0.5)
	local growTween = TweenService:Create(
		outputDisplay,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = scaleUDim2(originalSize, 1.18) }
	)
	local shrinkTween = TweenService:Create(
		outputDisplay,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Size = originalSize, Position = UDim2.fromScale(0.5, 0.5) }
	)
	growTween:Play()
	growTween.Completed:Wait()

	local outputRoot = getSlotRoot(outputDisplay)
	local viewport = outputRoot and outputRoot:FindFirstChild("LauncherPreview", true) or nil
	local previewModel = viewport and viewport:IsA("ViewportFrame") and viewport:FindFirstChild("PreviewModel") or nil
	if previewModel and previewModel:IsA("Model") then
		local initialPivot = previewModel:GetPivot()
		local spinDuration = 0.9
		local elapsed = 0
		local rotationConnection
		rotationConnection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed += deltaTime
			if previewModel.Parent == nil then
				if rotationConnection then rotationConnection:Disconnect() end
				return
			end
			local alpha = math.clamp(elapsed / spinDuration, 0, 1)
			previewModel:PivotTo(initialPivot * CFrame.Angles(0, math.rad(720) * alpha, 0))
			if alpha >= 1 and rotationConnection then
				rotationConnection:Disconnect()
			end
		end)
		task.wait(spinDuration)
	end
	shrinkTween:Play()
	shrinkTween.Completed:Wait()
	outputDisplay.AnchorPoint = self._template and self._template.AnchorPoint or Vector2.zero
	outputDisplay.Position = originalPosition
	outputDisplay.Size = originalSize

	if self._combineConfirmFrame then self._combineConfirmFrame.Visible = false end
	if self._combineModalConfirmButton then self._combineModalConfirmButton.Text = "Confirm" end
	self._pendingCombine = false
	self._pendingCombineRequestId = nil
	self:_exitCombineMode()
end

function LauncherInventoryUIController:_inLobby(): boolean
	return Players.LocalPlayer:GetAttribute("LocationState") == nil or Players.LocalPlayer:GetAttribute("LocationState") == "Lobby"
end

function LauncherInventoryUIController:SetVisible(value: boolean)
	if not value and self._combineMode and not self._pendingCombine then
		self:_exitCombineMode()
	end
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
	local entryKey = self:_entryKey(entry)
	local connection = slot.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local currentEntry = self:_findEntryByKey(entryKey)
			if not currentEntry then return end
			if self._combineMode then
				self:_toggleCombineSelection(currentEntry)
				return
			end
			self._selected = currentEntry
			if self._provider then self._provider:SelectLauncher(entryKey) end
			self:_refreshRightPanel()
			self:_refreshSlotVisuals()
		end
	end)
	self._slotConnections[slot] = connection
end

function LauncherInventoryUIController:_updateSlot(slot: GuiObject, entry)
	local root = getSlotRoot(slot)
	local definition = LauncherConfig.GetById(entry.id)
	if slot.Parent == self._grid then
		slot.Name = "GeneratedLauncher_" .. self:_entryKey(entry)
	end
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
		local rarity = self:_getRarity(entry)
		local rarityLabel = findText(root, "RarityLabel") or findText(root, "Rarity")
		if rarityLabel and rarity then rarityLabel.Text = rarity.displayName end
		local rarityBorder = root:FindFirstChild("RarityBorder", true)
		if rarityBorder and rarity then
			if rarityBorder:IsA("UIStroke") then
				rarityBorder.Color = rarity.borderColor
			elseif rarityBorder:IsA("GuiObject") then
				rarityBorder.BackgroundColor3 = rarity.borderColor
			end
		end
		local rarityStroke = root:FindFirstChildOfClass("UIStroke")
		if rarityStroke and rarity then rarityStroke.Color = rarity.borderColor end
		slot:SetAttribute("RarityBorderColor", if rarity then rarity.borderColor else nil)

		local stars = root:FindFirstChild("Stars")
		local starCount = math.clamp(math.floor(tonumber(entry.star) or 1), 1, RarityConfig.MaxStar)
		if stars then
			for index = 1, RarityConfig.MaxStar do
				local star = stars:FindFirstChild("Star" .. index)
				if star and star:IsA("GuiObject") then star.Visible = index <= starCount end
			end
		end

		local checkButton = root:FindFirstChild("CombineCheckButton", true)
		if checkButton and checkButton:IsA("GuiObject") then
			checkButton.Visible = self._combineMode
			local selected = false
			for _, selectedEntry in ipairs(self._selectedCombineEntries) do
				if self:_entryKey(selectedEntry) == self:_entryKey(entry) then selected = true break end
			end
			if checkButton:IsA("TextButton") then checkButton.Text = if selected then "✓" else "" end
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
			local selected = false
			if self._combineMode then
				for _, selectedEntry in ipairs(self._selectedCombineEntries) do
					if key == self:_entryKey(selectedEntry) then selected = true break end
				end
			else
				selected = self._selected ~= nil and key == self:_entryKey(self._selected)
			end
			slot.BackgroundTransparency = if selected then 0 else 0.2
			local root = getSlotRoot(slot)
			if root then
				local selectedOverlay = root:FindFirstChild("SelectedOverlay", true)
				if selectedOverlay and selectedOverlay:IsA("GuiObject") then
					selectedOverlay.Visible = self._combineMode and selected
				end
				local checkButton = root:FindFirstChild("CombineCheckButton", true)
				if checkButton and checkButton:IsA("GuiObject") then
					checkButton.Visible = self._combineMode
					if checkButton:IsA("TextButton") then checkButton.Text = if selected then "✓" else "" end
				end
				local stroke = root:FindFirstChildOfClass("UIStroke")
				local defaultColor = slot:GetAttribute("RarityBorderColor")
				if stroke and typeof(defaultColor) == "Color3" then
					stroke.Color = if selected then Color3.fromRGB(255, 235, 110) else defaultColor
				end
			end
		end
	end
	self:_refreshCombineButtons()
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
	if self._combineButton then self._combineButton.Visible = not self._combineMode end
	if self._combineControls then self._combineControls.Visible = self._combineMode end
	if self._equip then
		self._equip.Visible = not self._combineMode
		self._equip.Text = if entry and entry.equipped then "Equipped" elseif equipPending then "Equipping..." else "Equip"
		-- Keep the button clickable for selected entries so blocked actions can explain why.
		self._equip.Active = hasSelection and not equipPending
		self._equip.AutoButtonColor = canEquip
		self._equip.TextTransparency = if canEquip then 0 else 0.5
	end
	if self._sell then
		self._sell.Visible = not self._combineMode
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

	local entries = snapshot.ownedLaunchers or {}
	local eligibleMap = if self._combineMode then self:_getEligibleCombineMap(entries) else nil
	local seen = {}
	local latestByKey = {}

	for _, entry in ipairs(entries) do
		local key = self:_entryKey(entry)
		if key ~= "" then
			seen[key] = true
			latestByKey[key] = entry
			local slot = self._slotMap[key]
			if slot and slot.Parent then
				self:_updateSlot(slot, entry)
			else
				self:_spawnSlot(entry)
				slot = self._slotMap[key]
			end
			if slot then
				slot.Visible = not self._combineMode or (eligibleMap ~= nil and eligibleMap[key] == true)
			end
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

	if self._combineMode then
		local retained = {}
		for _, selected in ipairs(self._selectedCombineEntries) do
			local key = self:_entryKey(selected)
			local latest = latestByKey[key]
			if latest and eligibleMap and eligibleMap[key] then
				table.insert(retained, latest)
			end
		end
		self._selectedCombineEntries = retained
	end

	if self._capacity then self._capacity.Text = string.format("Capacity: %d/%d", #entries, snapshot.launcherCapacity or 0) end
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
