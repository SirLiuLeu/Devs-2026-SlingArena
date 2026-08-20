--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)

local TEMPLATE_PATH = "Assets.UI.PlayerRowTemplate_MatchSummaryUI"

local MatchSummaryUIController = {}
MatchSummaryUIController.__index = MatchSummaryUIController

local function asText(value: any, fallback: string): string
	if value == nil then
		return fallback
	end
	return tostring(value)
end

local function asNumber(value: any, fallback: number): number
	if type(value) == "number" and value == value then
		return value
	end
	return fallback
end

local function findTextLabel(root: Instance, name: string): TextLabel?
	local value = root:FindFirstChild(name, true)
	if value and value:IsA("TextLabel") then
		return value
	end
	return nil
end

function MatchSummaryUIController.new(playerGui: PlayerGui, clientService: any)
	local self = setmetatable({}, MatchSummaryUIController)
	self.PlayerGui = playerGui
	self.ClientService = clientService
	self.DataService = nil
	self.ScreenGui = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.ScreenGui) :: ScreenGui?
	self.PlayerList = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.PlayerList) :: ScrollingFrame?
	self.CloseButton = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.CloseButton) :: GuiButton?
	self.RowTemplate = PathResolver.resolvePath(ReplicatedStorage, TEMPLATE_PATH) :: Frame?
	self.Rows = {} :: { Frame }
	self.Connections = {} :: { RBXScriptConnection }

	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end
	if self.RowTemplate then
		self.RowTemplate.Visible = false
	end

	return self
end

function MatchSummaryUIController:_resolveUi()
	self.ScreenGui = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchSummary.ScreenGui, { shouldWarn = false }) :: ScreenGui?
	self.PlayerList = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchSummary.PlayerList, { shouldWarn = false }) :: ScrollingFrame?
	self.CloseButton = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchSummary.CloseButton, { shouldWarn = false }) :: GuiButton?
	if self.RowTemplate then self.RowTemplate.Visible = false end
end

function MatchSummaryUIController:SetDataService(dataService) self.DataService = dataService end

function MatchSummaryUIController:SetVisible(visible: boolean)
	self:_resolveUi()
	if self.ScreenGui then
		self.ScreenGui.Enabled = visible
	end
end

function MatchSummaryUIController:_clearRows()
	if #self.Rows == 0 then
		return
	end
	for _, row in ipairs(self.Rows) do
		row:Destroy()
	end
	table.clear(self.Rows)
end

function MatchSummaryUIController:_setLabel(row: Frame, labelName: string, text: string)
	local label = findTextLabel(row, labelName)
	if label then
		label.Text = text
	end
end

function MatchSummaryUIController:_addRow(rowData: any, index: number)
	if not (self.RowTemplate and self.PlayerList) then
		return
	end
	local row = self.RowTemplate:Clone()
	row.Name = "PlayerRow_" .. asText(rowData.UserId or index, tostring(index))
	row.LayoutOrder = index
	row.Visible = true
	row.Parent = self.PlayerList

	self:_setLabel(row, "Rank", tostring(math.floor(asNumber(rowData.Rank, index))))
	self:_setLabel(row, "PlayerName", asText(rowData.Name or rowData.PlayerName or rowData.name, "Player"))
	self:_setLabel(row, "Level", tostring(math.floor(asNumber(rowData.Level or rowData.level, 0))))
	self:_setLabel(row, "Kills", tostring(math.floor(asNumber(rowData.Kills or rowData.kills, 0))))
	self:_setLabel(row, "Deaths", tostring(math.floor(asNumber(rowData.Deaths or rowData.deaths, 0))))
	self:_setLabel(row, "Points", tostring(math.floor(asNumber(rowData.Points or rowData.points, 0))))
	self:_setLabel(row, "Reward", "+" .. tostring(math.floor(asNumber(rowData.Reward or rowData.ProgressPointReward, 0))))

	table.insert(self.Rows, row)
end

function MatchSummaryUIController:Refresh(payload: any)
	self:_resolveUi()
	local rows = if type(payload) == "table" and type(payload.Rows) == "table" then payload.Rows else {}
	self:_clearRows()
	for index, rowData in ipairs(rows) do
		if type(rowData) == "table" then
			self:_addRow(rowData, index)
		end
	end
	self:SetVisible(true)
	if self.CloseButton then
		self.CloseButton.Active = true
		self.CloseButton.Visible = true
	end
end

function MatchSummaryUIController:Start()
	self:_resolveUi()
	if self.DataService then
		table.insert(self.Connections, self.DataService:BindChanged(function(snapshot)
			if snapshot.Visible == false then self:SetVisible(false); self:_clearRows() else self:Refresh(snapshot) end
		end))
		local snapshot = self.DataService:GetSnapshot()
		if snapshot.Visible then self:Refresh(snapshot) end
	end
	local function bindClose()
		self:_resolveUi()
		if self.CloseButton and not self._closeBound then
			self._closeBound = true
			table.insert(self.Connections, self.CloseButton.MouseButton1Click:Connect(function() self:SetVisible(false); self:_clearRows() end))
		end
	end
	bindClose()
	table.insert(self.Connections, self.PlayerGui.DescendantAdded:Connect(function()
		-- Only bind late-cloned controls here. Refresh is driven by DataService updates;
		-- rebuilding rows from DescendantAdded would re-enter when rows are parented.
		bindClose()
	end))
end

function MatchSummaryUIController:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	self:_clearRows()
end

return MatchSummaryUIController
