--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local DailyLoginUIController = {}
DailyLoginUIController.__index = DailyLoginUIController

local GENERATED_PREFIX = "GeneratedDailySlot_"

local function resolveGuiObject(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	if value and value:IsA("GuiObject") then
		return value
	end
	return nil
end

local function resolveButton(root: Instance, path: string): GuiButton?
	local value = PathResolver.resolvePath(root, path, { shouldWarn = false })
	if value and value:IsA("GuiButton") then
		return value
	end
	return nil
end

function DailyLoginUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, DailyLoginUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._slotConnections = {}
	self._running = false
	return self
end

function DailyLoginUIController:SetLogicService(logicService)
	self._logicService = logicService
end

function DailyLoginUIController:Start()
	self._screenGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.DailyLogin.ScreenGui, { shouldWarn = false })
	self._leftGrid = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.DailyLogin.LeftGrid)
	if not self._leftGrid then
		self._leftGrid = resolveGuiObject(self._playerGui, "DailyLoginUI.MainPanel.Name_Button.Content.LeftGrid")
	end
	self._day7Big = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.DailyLogin.Day7Big)
	self._closeButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.DailyLogin.CloseButton)
	self._overlayButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.DailyLogin.OverlayButton)
	self._diamondIcon = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.MainHub.DiamondIcon)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._slotTemplate = uiFolder and uiFolder:FindFirstChild("SlotRewardTemplate_DailyLoginUI")

	if not self._slotTemplate then
		warn("[DAILY_LOGIN_UI] ReplicatedStorage.Assets.UI.SlotRewardTemplate_DailyLoginUI is missing; Day 1-6 slots cannot be cloned.")
	end
	if not self._leftGrid then
		warn("[DAILY_LOGIN_UI] DailyLoginUI.MainPanel.Content.LeftGrid is missing.")
	end
	if not self._day7Big then
		warn("[DAILY_LOGIN_UI] DailyLoginUI.MainPanel.Content.Day7Big is missing.")
	end

	if self._closeButton then
		table.insert(self._connections, self._closeButton.Activated:Connect(function()
			self:SetVisible(false)
		end))
	end
	if self._overlayButton then
		table.insert(self._connections, self._overlayButton.Activated:Connect(function()
			self:SetVisible(false)
		end))
	end

	if self._logicService then
		table.insert(self._connections, self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end))
		self:RenderSnapshot(self._logicService:GetSnapshot())
		self._logicService:RequestSnapshot()
	else
		warn("[DAILY_LOGIN_UI] DailyLoginLogicService was not assigned.")
	end

	self._running = true
	task.spawn(function()
		while self._running do
			self:_updateCountdownLabels()
			task.wait(1)
		end
	end)
end

function DailyLoginUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		self._screenGui.Enabled = isVisible
	end
	if isVisible and self._logicService then
		self._logicService:RequestSnapshot()
	end
end

function DailyLoginUIController:IsVisible(): boolean
	return self._screenGui ~= nil and self._screenGui:IsA("ScreenGui") and self._screenGui.Enabled
end

function DailyLoginUIController:_disconnectSlotConnections()
	for _, connection in ipairs(self._slotConnections) do
		connection:Disconnect()
	end
	table.clear(self._slotConnections)
end

function DailyLoginUIController:_clearGeneratedSlots()
	if not self._leftGrid then
		return
	end
	for _, child in ipairs(self._leftGrid:GetChildren()) do
		if string.sub(child.Name, 1, #GENERATED_PREFIX) == GENERATED_PREFIX then
			child:Destroy()
		end
	end
end

function DailyLoginUIController:_setSlotState(container: GuiObject, state: string, timerText: string?)
	local claimButton = container:FindFirstChild("ClaimButton", true)
	local claimedLabel = container:FindFirstChild("Claimed", true)
	local timerLabel = container:FindFirstChild("Timer", true)

	if claimButton and claimButton:IsA("GuiButton") then
		claimButton.Visible = state == "Claimable"
		claimButton.Active = state == "Claimable"
		claimButton.AutoButtonColor = state == "Claimable"
		if claimButton:IsA("TextButton") then
			claimButton.Text = "Claim"
		end
	end
	if claimedLabel and claimedLabel:IsA("TextLabel") then
		claimedLabel.Visible = state == "Claimed"
		claimedLabel.Text = "Claimed"
	end
	if timerLabel and timerLabel:IsA("TextLabel") then
		timerLabel.Visible = state == "Waiting" or state == "Locked"
		if state == "Waiting" then
			timerLabel.Text = timerText or "00:00:00"
		elseif state == "Locked" then
			timerLabel.Text = "Locked"
		else
			timerLabel.Text = ""
		end
	end
end

function DailyLoginUIController:_fillRewardFields(container: GuiObject, reward)
	local titleLabel = container:FindFirstChild("Title", true)
	local quantityLabel = container:FindFirstChild("Quantity", true)
	local iconLabel = container:FindFirstChild("Icon", true)

	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = string.format("Day %d - %s", reward.day, reward.rewardType or "Reward")
	end
	if quantityLabel and quantityLabel:IsA("TextLabel") then
		quantityLabel.Text = tostring(reward.rewardText or "")
	end
	if iconLabel and iconLabel:IsA("ImageLabel") then
		local icon = tostring(reward.icon or "")
		if reward.iconKind == "Diamonds" and self._diamondIcon and self._diamondIcon:IsA("ImageLabel") then
			icon = self._diamondIcon.Image
		end
		iconLabel.Image = icon
	end

	local timerText = if reward.state == "Waiting" and self._logicService
		then self._logicService:GetCountdownText()
		else reward.timerText
	self:_setSlotState(container, reward.state or "Locked", timerText)
end

function DailyLoginUIController:_connectClaimButton(container: GuiObject, day: number)
	local claimButton = container:FindFirstChild("ClaimButton", true)
	if not claimButton or not claimButton:IsA("GuiButton") then
		warn(string.format("[DAILY_LOGIN_UI] ClaimButton missing for Daily Login day %d.", day))
		return
	end
	table.insert(self._slotConnections, claimButton.Activated:Connect(function()
		if not self._logicService then
			return
		end
		if self._logicService:ClaimDay(day) then
			claimButton.Active = false
			claimButton.AutoButtonColor = false
			if claimButton:IsA("TextButton") then
				claimButton.Text = "Claiming..."
			end
		end
	end))
end

function DailyLoginUIController:RenderSnapshot(snapshot)
	self:_disconnectSlotConnections()
	self:_clearGeneratedSlots()

	if self._leftGrid and self._slotTemplate and self._slotTemplate:IsA("GuiObject") then
		for _, reward in ipairs(snapshot.entries or {}) do
			if reward.day >= 1 and reward.day <= 6 then
				local slot = self._slotTemplate:Clone()
				slot.Name = string.format("%s%d", GENERATED_PREFIX, reward.day)
				slot.Visible = true
				slot.LayoutOrder = reward.day
				slot.Parent = self._leftGrid
				self:_fillRewardFields(slot, reward)
				self:_connectClaimButton(slot, reward.day)
			end
		end
	end

	if self._day7Big then
		for _, reward in ipairs(snapshot.entries or {}) do
			if reward.day == 7 then
				local day7Label = self._day7Big:FindFirstChild("Day7Label", true)
				if day7Label and day7Label:IsA("TextLabel") then
					day7Label.Text = "DAY 7 - RANDOM PET"
				end
				self:_fillRewardFields(self._day7Big, reward)
				self:_connectClaimButton(self._day7Big, 7)
			end
		end
	end
end

function DailyLoginUIController:_updateCountdownLabels()
	if not self._running or not self._logicService then
		return
	end
	local snapshot = self._logicService:GetSnapshot()
	local countdownText = snapshot.CountdownText or self._logicService:GetCountdownText()
	local nextResetAt = tonumber(snapshot.NextResetAt)

	for _, reward in ipairs(snapshot.entries or {}) do
		if reward.state == "Waiting" then
			local container = if reward.day == 7
				then self._day7Big
				else (self._leftGrid and self._leftGrid:FindFirstChild(string.format("%s%d", GENERATED_PREFIX, reward.day)))
			if container and container:IsA("GuiObject") then
				local timerLabel = container:FindFirstChild("Timer", true)
				if timerLabel and timerLabel:IsA("TextLabel") then
					timerLabel.Text = countdownText
				end
			end
		end
	end

	local nowClock = os.clock()
	if snapshot.SecondsUntilReset <= 0 and nextResetAt
		and (self._lastResetRequestAt == nil or nowClock - self._lastResetRequestAt >= 1) then
		self._lastResetRequestAt = nowClock
		self._logicService:RequestSnapshot()
	end
end

function DailyLoginUIController:Destroy()
	self._running = false
	self:_disconnectSlotConnections()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return DailyLoginUIController
