--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)

local TOP_SCOREBOARD_LIMIT = 100

local MatchScoreboardUIController = {}
MatchScoreboardUIController.__index = MatchScoreboardUIController

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
	local value = root:FindFirstChild(name)
	if value and value:IsA("TextLabel") then
		return value
	end
	return nil
end

function MatchScoreboardUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, MatchScoreboardUIController)
	self.PlayerGui = playerGui
	self.ScreenGui = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchScoreboard.ScreenGui) :: ScreenGui?
	self.PlayerList = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchScoreboard.PlayerList) :: ScrollingFrame?
	self.RowTemplate = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchScoreboard.RowTemplate) :: Frame?
	self.CloseButton = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchScoreboard.CloseButton) :: GuiButton?
	self.Overlay = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchScoreboard.Overlay) :: GuiObject?
	self.RowsByKey = {} :: { [string]: Frame }
	self.LastRows = {} :: { any }
	self.Connections = {} :: { RBXScriptConnection }
	self.DataService = nil

	if self.RowTemplate then
		self.RowTemplate.Visible = false
	end
	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end

	return self
end

function MatchScoreboardUIController:_resolveUi()
	self.ScreenGui = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchScoreboard.ScreenGui, { shouldWarn = false }) :: ScreenGui?
	self.PlayerList = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchScoreboard.PlayerList, { shouldWarn = false }) :: ScrollingFrame?
	self.RowTemplate = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchScoreboard.RowTemplate, { shouldWarn = false }) :: Frame?
	self.CloseButton = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchScoreboard.CloseButton, { shouldWarn = false }) :: GuiButton?
	self.Overlay = PathResolver.resolvePath(self.PlayerGui, ProjectTreeSpec.UI.MatchScoreboard.Overlay, { shouldWarn = false }) :: GuiObject?
	if self.RowTemplate then self.RowTemplate.Visible = false end
end

function MatchScoreboardUIController:SetDataService(dataService)
	self.DataService = dataService
end

function MatchScoreboardUIController:SetVisible(visible: boolean)
	self:_resolveUi()
	if self.ScreenGui then
		self.ScreenGui.Enabled = visible
	end
end

function MatchScoreboardUIController:ToggleVisible()
	if self.ScreenGui then
		self:SetVisible(not self.ScreenGui.Enabled)
	end
end

function MatchScoreboardUIController:_setLabel(row: Frame, labelName: string, text: string)
	local label = findTextLabel(row, labelName)
	if label then
		label.Text = text
	end
end

function MatchScoreboardUIController:_getRowKey(rowData: any, index: number): string
	return asText(rowData.UserId or rowData.userId or rowData.Name or rowData.name, tostring(index))
end

function MatchScoreboardUIController:_getOrCreateRow(key: string): Frame?
	if self.RowsByKey[key] and self.RowsByKey[key].Parent then
		return self.RowsByKey[key]
	end
	if not (self.RowTemplate and self.PlayerList) then
		return nil
	end
	local row = self.RowTemplate:Clone()
	row.Name = "PlayerRow_" .. key
	row.Visible = true
	row.Parent = self.PlayerList
	self.RowsByKey[key] = row
	return row
end

function MatchScoreboardUIController:_applyRow(row: Frame, rowData: any, index: number)
	row.LayoutOrder = index
	self:_setLabel(row, "NameValue", asText(rowData.Name or rowData.name or "Player", "Player"))
	self:_setLabel(row, "LevelValue", tostring(math.floor(asNumber(rowData.Level or rowData.level, 0))))
	self:_setLabel(row, "PointValue", tostring(math.floor(asNumber(rowData.Points or rowData.points or rowData.Point or rowData.point, 0))))
	self:_setLabel(row, "KillValue", tostring(math.floor(asNumber(rowData.Kills or rowData.kills, 0))))
	self:_setLabel(row, "StateValue", asText(rowData.State or rowData.state, "Unknown"))
end

function MatchScoreboardUIController:Refresh(payload: any)
	self:_resolveUi()
	local rows = if type(payload) == "table" and type(payload.Rows) == "table" then payload.Rows else payload
	if type(rows) ~= "table" then
		rows = {}
	end
	self.LastRows = rows

	local liveKeys = {}
	local rendered = 0
	for index, rowData in ipairs(rows) do
		if rendered >= TOP_SCOREBOARD_LIMIT then
			break
		end
		if type(rowData) == "table" then
			rendered += 1
			local key = self:_getRowKey(rowData, rendered)
			liveKeys[key] = true
			local row = self:_getOrCreateRow(key)
			if row then
				self:_applyRow(row, rowData, rendered)
			end
		end
	end

	for key, row in pairs(self.RowsByKey) do
		if not liveKeys[key] then
			row:Destroy()
			self.RowsByKey[key] = nil
		end
	end
end

function MatchScoreboardUIController:Start()
	self:_resolveUi()
	if self.DataService then
		table.insert(self.Connections, self.DataService:BindChanged(function(snapshot) self:Refresh(snapshot) end))
		self:Refresh(self.DataService:GetSnapshot())
	end
	table.insert(self.Connections, self.PlayerGui.DescendantAdded:Connect(function() self:_resolveUi(); if self.DataService then self:Refresh(self.DataService:GetSnapshot()) end end))
end

function MatchScoreboardUIController:Destroy()
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	table.clear(self.Connections)
	for _, row in pairs(self.RowsByKey) do
		row:Destroy()
	end
	table.clear(self.RowsByKey)
end

return MatchScoreboardUIController
