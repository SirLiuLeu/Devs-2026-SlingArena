--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local QuestUIController = {}
QuestUIController.__index = QuestUIController

local QUEST_UI_PATH = "QuestUI"
local QUEST_ROW_TEMPLATE_PATH = "Assets.UI.QuestRowTemplate_QuestUI"

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
	self:_resolveUi()
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

function QuestUIController:_resolveTemplate(): Frame?
	local template = PathResolver.resolvePath(ReplicatedStorage, QUEST_ROW_TEMPLATE_PATH)
	if template and template:IsA("Frame") then
		self._rowTemplate = template
		return template
	end
	warn("[QuestUI] ReplicatedStorage.Assets.UI.QuestRowTemplate_QuestUI is missing or is not a Frame")
	return nil
end

function QuestUIController:_resolveUi()
	local existing = PathResolver.resolvePath(self._playerGui, QUEST_UI_PATH)
	if existing and existing:IsA("ScreenGui") then
		self._screenGui = existing
	else
		warn("[QuestUI] QuestUI ScreenGui is missing; row rendering requires StarterGui.QuestUI to be cloned into PlayerGui")
		return
	end

	self:_resolveTemplate()
	self._root = PathResolver.resolvePath(self._screenGui, "Root")
	self._list = PathResolver.resolvePath(self._screenGui, "Root.Content_ScrollFrame")
	local dailyTab = PathResolver.resolvePath(self._screenGui, "Root.TabContainer.Tab_Daily")
	local mainTab = PathResolver.resolvePath(self._screenGui, "Root.TabContainer.Tab_Main")
	local close = PathResolver.resolvePath(self._screenGui, "Root.CloseButton")
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

local function setTextIfPresent(row: Instance, name: string, text: string)
	local child = row:FindFirstChild(name, true)
	if child and (child:IsA("TextLabel") or child:IsA("TextButton")) then
		child.Text = text
	end
end

function QuestUIController:_makeRow(data, order: number)
	if not self._list or not self._list:IsA("GuiObject") then return end
	local template = self._rowTemplate or self:_resolveTemplate()
	if not template then return end

	local row = template:Clone()
	row.Name = "Quest_" .. tostring(data.Id)
	row.LayoutOrder = order
	row.Visible = true
	row.Parent = self._list

	local progress = math.max(0, tonumber(data.Progress) or 0)
	local target = math.max(0, tonumber(data.Target) or 0)
	setTextIfPresent(row, "QuestDesc", tostring(data.Desc))
	setTextIfPresent(row, "ProgressText", string.format("%d / %d", progress, target))

	local progressBarBox = row:FindFirstChild("ProgressBarBox", true)
	local fill = progressBarBox and progressBarBox:FindFirstChild("Fill")
	if fill and fill:IsA("GuiObject") then
		local ratio = if target > 0 then math.clamp(progress / target, 0, 1) else 0
		fill.Size = UDim2.new(ratio, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)
	end

	local claim = row:FindFirstChild("ClaimButton", true)
	if claim and claim:IsA("TextButton") then
		claim.Text = if data.State == "Claimed" then "Claimed" elseif data.State == "Ready" then "Claim" else "Locked"
		claim.Active = data.State == "Ready"
		claim.AutoButtonColor = data.State == "Ready"
		if data.State == "Ready" then
			table.insert(self._connections, claim.MouseButton1Click:Connect(function()
				if self._logicService then self._logicService:ClaimQuest(data.Id) end
			end))
		end
	else
		warn("[QuestUI] QuestRowTemplate_QuestUI is missing ClaimButton TextButton")
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
