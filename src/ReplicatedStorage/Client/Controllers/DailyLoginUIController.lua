--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local DailyLoginUIController = {}
DailyLoginUIController.__index = DailyLoginUIController

local GENERATED_PREFIX = "GeneratedDailySlot_"

local function resolveGuiObject(root: Instance, path: string): GuiObject?
	local value = PathResolver.resolvePath(root, path)
	if value and value:IsA("GuiObject") then
		return value
	end
	return nil
end

local function resolveButton(root: Instance, path: string): GuiButton?
	local value = PathResolver.resolvePath(root, path)
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
	return self
end

function DailyLoginUIController:SetLogicService(logicService)
	self._logicService = logicService
end

function DailyLoginUIController:Start()
	self._screenGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.DailyLogin.ScreenGui)
	self._leftGrid = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.DailyLogin.LeftGrid)
	if not self._leftGrid then
		self._leftGrid = resolveGuiObject(self._playerGui, "DailyLoginUI.MainPanel.Name_Button.Content.LeftGrid")
	end
	self._day7Big = resolveGuiObject(self._playerGui, ProjectTreeSpec.UI.DailyLogin.Day7Big)
	self._closeButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.DailyLogin.CloseButton)
	self._overlayButton = resolveButton(self._playerGui, ProjectTreeSpec.UI.DailyLogin.OverlayButton)

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	self._slotTemplate = uiFolder and uiFolder:FindFirstChild("SlotRewardTemplate_DailyLoginUI")

	if not self._slotTemplate then
		warn("[DAILY_LOGIN_UI] ReplicatedStorage.Assets.UI.SlotRewardTemplate_DailyLoginUI missing")
	end
	if not self._leftGrid then
		warn("[DAILY_LOGIN_UI] DailyLoginUI.MainPanel.Content.LeftGrid missing")
	end

	if self._closeButton then
		table.insert(self._connections, self._closeButton.MouseButton1Click:Connect(function()
			self:SetVisible(false)
		end))
	end
	if self._overlayButton then
		table.insert(self._connections, self._overlayButton.MouseButton1Click:Connect(function()
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

function DailyLoginUIController:SetVisible(isVisible: boolean)
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		self._screenGui.Enabled = isVisible
	end
end

function DailyLoginUIController:IsVisible(): boolean
	if self._screenGui and self._screenGui:IsA("ScreenGui") then
		return self._screenGui.Enabled
	end
	return false
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

function DailyLoginUIController:_setSlotState(container: GuiObject, state: string)
	local claimButton = container:FindFirstChild("ClaimButton", true)
	local claimedLabel = container:FindFirstChild("Claimed", true)
	local timerLabel = container:FindFirstChild("Timer", true)

	if claimButton and claimButton:IsA("TextButton") then
		claimButton.Visible = state == "Claimable"
		claimButton.Active = state == "Claimable"
		claimButton.Text = "Claim"
	end
	if claimedLabel and claimedLabel:IsA("TextLabel") then
		claimedLabel.Visible = state == "Claimed"
		claimedLabel.Text = "Claimed"
	end
	if timerLabel and timerLabel:IsA("TextLabel") then
		timerLabel.Visible = state == "Locked"
		timerLabel.Text = if state == "Locked" then "Wait" else ""
	end
end

function DailyLoginUIController:_fillRewardFields(container: GuiObject, reward)
	local titleLabel = container:FindFirstChild("Title", true)
	local quantityLabel = container:FindFirstChild("Quantity", true)
	local iconLabel = container:FindFirstChild("Icon", true)

	if titleLabel and titleLabel:IsA("TextLabel") then
		titleLabel.Text = string.format("Day %d - %s", reward.day, reward.rewardType)
	end
	if quantityLabel and quantityLabel:IsA("TextLabel") then
		quantityLabel.Text = reward.rewardText
	end
	if iconLabel and iconLabel:IsA("ImageLabel") then
		iconLabel.Image = reward.icon or ""
	end

	self:_setSlotState(container, reward.state)
end

function DailyLoginUIController:RenderSnapshot(snapshot)
	self:_disconnectSlotConnections()
	self:_clearGeneratedSlots()

	if self._leftGrid and self._slotTemplate and self._slotTemplate:IsA("GuiObject") then
		for _, reward in ipairs(snapshot.entries or {}) do
			if reward.day <= 6 then
				local slot = self._slotTemplate:Clone()
				slot.Name = string.format("%s%d", GENERATED_PREFIX, reward.day)
				slot.Visible = true
				slot.LayoutOrder = reward.day
				slot.Parent = self._leftGrid
				self:_fillRewardFields(slot, reward)

				local claimButton = slot:FindFirstChild("ClaimButton", true)
				if claimButton and claimButton:IsA("GuiButton") then
					table.insert(self._slotConnections, claimButton.MouseButton1Click:Connect(function()
						local _, message = self._logicService:ClaimDay(reward.day)
						print("[DAILY_LOGIN_UI]", message)
					end))
				end
			end
		end
	end

	if self._day7Big then
		for _, reward in ipairs(snapshot.entries or {}) do
			if reward.day == 7 then
				self:_fillRewardFields(self._day7Big, reward)
				local claimButton = self._day7Big:FindFirstChild("ClaimButton", true)
				if claimButton and claimButton:IsA("GuiButton") then
					table.insert(self._slotConnections, claimButton.MouseButton1Click:Connect(function()
						local _, message = self._logicService:ClaimDay(7)
						print("[DAILY_LOGIN_UI]", message)
					end))
				end
			end
		end
	end
end

function DailyLoginUIController:Destroy()
	self:_disconnectSlotConnections()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

return DailyLoginUIController
