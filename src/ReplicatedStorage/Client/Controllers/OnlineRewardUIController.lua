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

function OnlineRewardUIController:Start()
	self._screenGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.OnlineReward.ScreenGui)
	self._content = resolveGui(self._playerGui, ProjectTreeSpec.UI.OnlineReward.Content)
	self._claimAllButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.OnlineReward.ClaimAll)
	self._skipAllButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.OnlineReward.SkipAll)
	self._closeButton = resolveTextButton(self._playerGui, ProjectTreeSpec.UI.OnlineReward.CloseButton)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._template = uiFolder and uiFolder:FindFirstChild("RewardSlotTemplate")

	if not self._content then
		warn("[ONLINE_REWARD_UI] OnlineRewardUI/Root/Content missing")
	end
	if not self._template then
		warn("[ONLINE_REWARD_UI] ReplicatedStorage/Assets/UI/RewardSlotTemplate missing")
	end

	if self._claimAllButton then
		table.insert(self._connections, self._claimAllButton.MouseButton1Click:Connect(function()
			if self._logicService then
				self._logicService:ClaimAllReady()
			end
		end))
	else
		warn("[ONLINE_REWARD_UI] ClaimAll button missing")
	end

	if self._skipAllButton then
		table.insert(self._connections, self._skipAllButton.MouseButton1Click:Connect(function()
			if self._logicService then
				self._logicService:SkipAll()
			end
		end))
	else
		warn("[ONLINE_REWARD_UI] SkipAll button missing")
	end

	if self._closeButton then
		table.insert(self._connections, self._closeButton.MouseButton1Click:Connect(function()
			self:SetVisible(false)
		end))
	end

	if self._logicService then
		table.insert(self._connections, self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end))
		self:RenderSnapshot(self._logicService:GetSnapshot())
	end
end

function OnlineRewardUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		self._screenGui.Enabled = isVisible
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

function OnlineRewardUIController:_setSlotState(slot: GuiObject, data)
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
	end
	if claimedLabel and claimedLabel:IsA("TextLabel") then
		claimedLabel.Visible = data.state == "Claimed"
		claimedLabel.Text = "Claimed"
	end
end

function OnlineRewardUIController:_bindSlotData(slot: GuiObject, data)
	local iconLabel = slot:FindFirstChild("Icon", true)
	if iconLabel and iconLabel:IsA("ImageLabel") then
		iconLabel.Image = data.icon
	end

	local quantityLabel = slot:FindFirstChild("Quantity", true)
	if quantityLabel and quantityLabel:IsA("TextLabel") then
		quantityLabel.Text = string.format("%s x%d", data.rewardType, math.max(0, data.amount))
	end

	local claimButton = slot:FindFirstChild("ClaimButton", true)
	if claimButton and claimButton:IsA("TextButton") then
		claimButton.Text = "Claim"
	end

	self:_setSlotState(slot, data)
end

function OnlineRewardUIController:_ensureSlot(data, layoutOrder: number): GuiObject?
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
		local connection = claimButton.MouseButton1Click:Connect(function()
			if self._logicService then
				self._logicService:ClaimReward(data.id)
			end
		end)
		self._claimConnectionById[data.id] = connection
		table.insert(self._slotConnections, connection)
	end
	return slot
end

function OnlineRewardUIController:RenderSnapshot(snapshot)
	if not self._content or not self._template or not self._template:IsA("GuiObject") then
		return
	end

	local activeIds = {}
	for index, data in ipairs(snapshot.slots or {}) do
		activeIds[data.id] = true
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
end

function OnlineRewardUIController:Destroy()
	self:_clearSlots()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return OnlineRewardUIController
