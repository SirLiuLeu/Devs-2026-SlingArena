--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local QuestUIController = {}
QuestUIController.__index = QuestUIController

local QUEST_UI_PATH = "QuestUI"

local function makeLabel(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name; label.Text = text; label.Size = size; label.Position = pos
	label.BackgroundTransparency = 1; label.TextColor3 = Color3.fromRGB(255, 255, 255); label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function QuestUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, QuestUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._rows = {}
	self._activeTab = "Daily"
	return self
end

function QuestUIController:SetLogicService(logicService)
	self._logicService = logicService
end

function QuestUIController:SetToastController(toastController)
	self._toastController = toastController
end

function QuestUIController:Start()
	self:_resolveOrCreateUi()
	if self._logicService then
		table.insert(self._connections, self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end))
		table.insert(self._connections, self._logicService:BindClaimCompleted(function(result)
			self:_handleClaimResult(result)
		end))
		self:RenderSnapshot(self._logicService:GetSnapshot())
	end
end

function QuestUIController:_resolveOrCreateUi()
	local existing = PathResolver.resolvePath(self._playerGui, QUEST_UI_PATH)
	if existing and existing:IsA("ScreenGui") then
		self._screenGui = existing
	else
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "QuestUI"; screenGui.Enabled = false; screenGui.ResetOnSpawn = false; screenGui.Parent = self._playerGui
		self._screenGui = screenGui
		local root = Instance.new("Frame")
		root.Name = "Root"; root.Size = UDim2.fromScale(0.5, 0.7); root.Position = UDim2.fromScale(0.25, 0.15); root.BackgroundColor3 = Color3.fromRGB(28, 30, 42); root.Parent = screenGui
		local daily = Instance.new("TextButton")
		daily.Name = "DailyTab"; daily.Text = "Daily"; daily.Size = UDim2.fromScale(0.25, 0.1); daily.Parent = root
		local main = daily:Clone(); main.Name = "MainTab"; main.Text = "Main"; main.Position = UDim2.fromScale(0.25, 0); main.Parent = root
		local close = daily:Clone(); close.Name = "CloseButton"; close.Text = "X"; close.Position = UDim2.fromScale(0.9, 0); close.Size = UDim2.fromScale(0.1, 0.1); close.Parent = root
		local list = Instance.new("ScrollingFrame")
		list.Name = "QuestList"; list.Size = UDim2.fromScale(1, 0.82); list.Position = UDim2.fromScale(0, 0.14); list.BackgroundTransparency = 1; list.Parent = root
		local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 6); layout.Parent = list
	end
	self._root = self._screenGui:FindFirstChild("Root")
	self._list = self._root and self._root:FindFirstChild("QuestList", true)
	local dailyTab = self._root and self._root:FindFirstChild("DailyTab", true)
	local mainTab = self._root and self._root:FindFirstChild("MainTab", true)
	local close = self._root and self._root:FindFirstChild("CloseButton", true)
	if dailyTab and dailyTab:IsA("GuiButton") then table.insert(self._connections, dailyTab.MouseButton1Click:Connect(function() self._activeTab = "Daily"; self:RenderSnapshot(self._logicService:GetSnapshot()) end)) end
	if mainTab and mainTab:IsA("GuiButton") then table.insert(self._connections, mainTab.MouseButton1Click:Connect(function() self._activeTab = "Main"; self:RenderSnapshot(self._logicService:GetSnapshot()) end)) end
	if close and close:IsA("GuiButton") then table.insert(self._connections, close.MouseButton1Click:Connect(function() self:SetVisible(false) end)) end
end

function QuestUIController:SetVisible(visible: boolean)
	if self._screenGui then self._screenGui.Enabled = visible end
end

function QuestUIController:_clearRows()
	for _, row in ipairs(self._rows) do if row.Parent then row:Destroy() end end
	table.clear(self._rows)
end

function QuestUIController:_makeRow(data, order: number)
	if not self._list or not self._list:IsA("GuiObject") then return end
	local row = Instance.new("Frame")
	row.Name = "Quest_" .. tostring(data.Id); row.Size = UDim2.new(1, -8, 0, 72); row.LayoutOrder = order; row.BackgroundColor3 = Color3.fromRGB(42, 45, 62); row.Parent = self._list
	makeLabel(row, "Desc", tostring(data.Desc), UDim2.fromScale(0.62, 0.45), UDim2.fromScale(0.02, 0.05))
	makeLabel(row, "Progress", string.format("%d / %d", data.Progress or 0, data.Target or 0), UDim2.fromScale(0.35, 0.35), UDim2.fromScale(0.02, 0.55))
	local rewardText = "Reward"
	if data.Reward and data.Reward.Diamonds then rewardText = "+" .. tostring(data.Reward.Diamonds) .. " Diamonds" end
	makeLabel(row, "Reward", rewardText, UDim2.fromScale(0.2, 0.4), UDim2.fromScale(0.62, 0.1))
	local claim = Instance.new("TextButton")
	claim.Name = "ClaimButton"; claim.Size = UDim2.fromScale(0.16, 0.55); claim.Position = UDim2.fromScale(0.82, 0.22); claim.Text = if data.State == "Claimed" then "Claimed" elseif data.State == "Ready" then "Claim" else "Locked"; claim.Active = data.State == "Ready"; claim.Parent = row
	if data.State == "Ready" then
		table.insert(self._connections, claim.MouseButton1Click:Connect(function()
			if self._logicService then self._logicService:ClaimQuest(data.Id) end
		end))
	end
	table.insert(self._rows, row)
end

function QuestUIController:RenderSnapshot(snapshot)
	self:_clearRows()
	local quests = snapshot[self._activeTab] or {}
	for index, quest in ipairs(quests) do self:_makeRow(quest, index) end
end

function QuestUIController:_handleClaimResult(result)
	if not self._toastController then return end
	if result.Success then
		self._toastController:Enqueue({ Text = "Quest reward claimed!", Toast = true })
	else
		self._toastController:Enqueue({ Text = "Quest is not ready yet.", Toast = true })
	end
end

function QuestUIController:Destroy()
	self:_clearRows()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
end

return QuestUIController
