--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local OnlineRewardUIController = {}
OnlineRewardUIController.__index = OnlineRewardUIController

local function resolveGui(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("GuiObject") then
		return value
	end
	return nil
end

local function resolveTextButton(root: Instance, path: string): TextButton?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("TextButton") then
		return value
	end
	return nil
end

local function formatTime(seconds: number): string
	local clamped = math.max(0, math.floor(seconds))
	local minutes = math.floor(clamped / 60)
	local remain = clamped % 60
	return string.format("%02d:%02d", minutes, remain)
end

function OnlineRewardUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, OnlineRewardUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._slotConnections = {}
	self._spawnedSlots = {}
	self._slotById = {}
	self._claimConnectionById = {}
	return self
end

function OnlineRewardUIController:SetLogicService(logicService)
	self._logicService = logicService
end

function OnlineRewardUIController:_resolveNotificationIcon()
	if self._notificationIcon and self._notificationIcon.Parent then
		return self._notificationIcon
	end
	local icon = PathResolver.resolvePath(
		self._playerGui,
		ProjectTreeSpec.OptionalUI.MainHub.OnlineRewardNotificationIcon,
		{ shouldWarn = false }
	)
	if icon and icon:IsA("GuiObject") then
		self._notificationIcon = icon
	end
	return self._notificationIcon
end

function OnlineRewardUIController:_setNotificationVisible(isVisible: boolean)
	local icon = self:_resolveNotificationIcon()
	if icon then
		icon.Visible = isVisible
	end
end

function OnlineRewardUIController:_updateCanvasSize()
	if not self._content or not self._content:IsA("ScrollingFrame") then
		return
	end
	if self._grid and self._grid:IsA("UIGridLayout") then
		local height = math.max(0, math.ceil(self._grid.AbsoluteContentSize.Y + 12))
		self._content.CanvasSize = UDim2.new(0, 0, 0, height)
	end
end

function OnlineRewardUIController:Start()
	self._screenGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.OnlineReward.ScreenGui)
	self._content = resolveGui(self._playerGui, ProjectTreeSpec.UI.OnlineReward.Content)
	self._closeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.OnlineReward.CloseButton)
	self._grid = self._content and self._content:FindFirstChild("Grid")

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._template = uiFolder and uiFolder:FindFirstChild("SlotRewardTemplate_OnlineRewardUI")

	if not self._content then
		warn("[ONLINE_REWARD_UI] OnlineRewardUI/Root/Content missing")
	end
	if not self._template or not self._template:IsA("GuiObject") then
		warn("[ONLINE_REWARD_UI] ReplicatedStorage/Assets/UI/SlotRewardTemplate_OnlineRewardUI missing")
	end
	if not self:_resolveNotificationIcon() then
		warn("[ONLINE_REWARD_UI] MainHUD.Root.LeftMenu.OnlineRewardButton.InfoIcon missing; add an ImageLabel there to show ready-reward notifications.")
	end

	if self._closeButton then
		table.insert(self._connections, self._closeButton.Activated:Connect(function()
			self:SetVisible(false)
		end))
	end

	if self._grid and self._grid:IsA("UIGridLayout") then
		table.insert(self._connections, self._grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			self:_updateCanvasSize()
		end))
	end

	if self._logicService then
		table.insert(self._connections, self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end))
		self:RenderSnapshot(self._logicService:GetSnapshot())
		self._logicService:RequestSnapshot()
	end
end

function OnlineRewardUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		self._screenGui.Enabled = isVisible
	end
	if isVisible and self._logicService then
		self._logicService:RequestSnapshot()
	end
end

function OnlineRewardUIController:_disconnectSlotConnections()
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
end

function OnlineRewardUIController:_clearSlots()
	self:_disconnectSlotConnections()
	for _, slot in ipairs(self._spawnedSlots) do
		if slot and slot.Parent then
			slot:Destroy()
		end
	end
	table.clear(self._spawnedSlots)
	table.clear(self._slotById)
	table.clear(self._claimConnectionById)
end

function OnlineRewardUIController:_setSlotState(slot: GuiObject, data: any)
	local timerLabel = slot:FindFirstChild("Timer", true)
	local claimButton = slot:FindFirstChild("ClaimButton", true)
	local claimedLabel = slot:FindFirstChild("Claimed", true)

	if timerLabel and timerLabel:IsA("TextLabel") then
		timerLabel.Visible = data.state == "Locked"
		timerLabel.Text = formatTime(data.remaining)
	end
	if claimButton and claimButton:IsA("TextButton") then
		claimButton.Visible = data.state == "Ready"
		claimButton.Active = data.state == "Ready"
		claimButton.AutoButtonColor = data.state == "Ready"
	end
	if claimedLabel and claimedLabel:IsA("TextLabel") then
		claimedLabel.Visible = data.state == "Claimed"
		claimedLabel.Text = "Claimed"
	end
end

function OnlineRewardUIController:_bindSlotData(slot: GuiObject, data: any)
	local iconLabel = slot:FindFirstChild("Icon", true)
	if iconLabel and iconLabel:IsA("ImageLabel") then
		local icon = tostring(data.icon or "")
		if data.rewardType == "Diamonds" and (icon == "" or icon == "rbxassetid://0") then
			local hudDiamondIcon = PathResolver.resolvePath(
				self._playerGui,
				ProjectTreeSpec.UI.MainHub.DiamondIcon,
				{ shouldWarn = false }
			)
			if hudDiamondIcon and hudDiamondIcon:IsA("ImageLabel") then
				icon = hudDiamondIcon.Image
			end
		end
		iconLabel.Image = icon
	end

	local rarityText = string.upper(tostring(data.rarity or ""))
	local rarityLabel = slot:FindFirstChild("RarityLabel", true) or slot:FindFirstChild("Rarity", true)
	local hasRarityLabel = false
	if rarityLabel and rarityLabel:IsA("TextLabel") then
		rarityLabel.Text = rarityText
		rarityLabel.Visible = data.rarity ~= nil
		hasRarityLabel = true
	end

	local quantityLabel = slot:FindFirstChild("Quantity", true)
	if quantityLabel and quantityLabel:IsA("TextLabel") then
		local rewardText
		if data.rewardType == "Diamonds" then
			rewardText = string.format("+%d Diamonds", math.max(0, data.amount))
		else
			rewardText = string.format("%s x%d", tostring(data.rewardType), math.max(0, data.amount))
		end
		quantityLabel.Text = if hasRarityLabel or rarityText == "" then rewardText else string.format("%s • %s", rewardText, rarityText)
	end

	local claimButton = slot:FindFirstChild("ClaimButton", true)
	if claimButton and claimButton:IsA("TextButton") then
		claimButton.Text = "Claim"
	end

	self:_setSlotState(slot, data)
end

function OnlineRewardUIController:_ensureSlot(data: any, layoutOrder: number): GuiObject?
	local existing = self._slotById[data.id]
	if existing and existing.Parent then
		existing.LayoutOrder = layoutOrder
		return existing
	end
	if not self._template or not self._template:IsA("GuiObject") or not self._content then
		return nil
	end

	local slot = self._template:Clone()
	slot.Name = string.format("GeneratedReward_%s", tostring(data.id))
	slot.Visible = true
	slot.LayoutOrder = layoutOrder
	slot.Parent = self._content
	self._slotById[data.id] = slot
	table.insert(self._spawnedSlots, slot)

	local claimButton = slot:FindFirstChild("ClaimButton", true)
	if claimButton and claimButton:IsA("TextButton") and not self._claimConnectionById[data.id] then
		local connection = claimButton.Activated:Connect(function()
			if self._logicService then
				self._logicService:ClaimReward(data.id)
			end
		end)
		self._claimConnectionById[data.id] = connection
		table.insert(self._slotConnections, connection)
	end
	return slot
end

function OnlineRewardUIController:RenderSnapshot(snapshot: any)
	if not self._content or not self._template or not self._template:IsA("GuiObject") then
		return
	end

	if self._grid and self._grid:IsA("UIGridLayout") then
		self._grid.FillDirectionMaxCells = math.max(1, math.floor(tonumber(snapshot.columns) or 3))
	end

	local activeIds = {}
	local readyCount = math.max(0, math.floor(tonumber(snapshot.ReadyCount) or 0))
	for index, data in ipairs(snapshot.slots or {}) do
		activeIds[data.id] = true
		if data.state == "Ready" and tonumber(snapshot.ReadyCount) == nil then
			readyCount += 1
		end
		local slot = self:_ensureSlot(data, index)
		if slot then
			self:_bindSlotData(slot, data)
		end
	end

	for rewardId, slot in pairs(self._slotById) do
		if not activeIds[rewardId] then
			if slot and slot.Parent then
				slot:Destroy()
			end
			local connection = self._claimConnectionById[rewardId]
			if connection then
				connection:Disconnect()
				self._claimConnectionById[rewardId] = nil
			end
			self._slotById[rewardId] = nil
		end
	end

	self:_setNotificationVisible(readyCount > 0)
	self:_updateCanvasSize()
end

function OnlineRewardUIController:Destroy()
	self:_clearSlots()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	self:_setNotificationVisible(false)
end

return OnlineRewardUIController
