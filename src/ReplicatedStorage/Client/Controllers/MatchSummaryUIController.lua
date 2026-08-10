--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RunService = game:GetService("RunService")

local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)

local TEMPLATE_PATH = "Assets.UI.PlayerRowTemplate_MatchSummaryUI"
local DEFAULT_DURATION_SECONDS = 15

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
	self.ScreenGui = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.ScreenGui) :: ScreenGui?
	self.PlayerList = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.PlayerList) :: ScrollingFrame?
	self.CountdownLabel = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.CountdownLabel) :: TextLabel?
	self.CloseButton = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.MatchSummary.CloseButton) :: GuiButton?
	self.RowTemplate = PathResolver.resolvePath(ReplicatedStorage, TEMPLATE_PATH) :: Frame?
	self.Rows = {} :: { Frame }
	self.Connections = {} :: { RBXScriptConnection }
	self.CountdownEndsAt = 0

	if self.ScreenGui then
		self.ScreenGui.Enabled = false
	end
	if self.RowTemplate then
		self.RowTemplate.Visible = false
	end

	return self
end

function MatchSummaryUIController:SetVisible(visible: boolean)
	if self.ScreenGui then
		self.ScreenGui.Enabled = visible
	end
end

function MatchSummaryUIController:_clearRows()
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
	local rows = if type(payload) == "table" and type(payload.Rows) == "table" then payload.Rows else {}
	self:_clearRows()
	for index, rowData in ipairs(rows) do
		if type(rowData) == "table" then
			self:_addRow(rowData, index)
		end
	end
	local duration = if type(payload) == "table" then asNumber(payload.DurationSeconds, DEFAULT_DURATION_SECONDS) else DEFAULT_DURATION_SECONDS
	self.CountdownEndsAt = os.clock() + math.max(0, duration)
	self:SetVisible(true)
	if self.CloseButton then
		self.CloseButton.Active = true
		self.CloseButton.Visible = true
	end
end

function MatchSummaryUIController:_updateCountdown()
	if not self.CountdownLabel then
		return
	end
	local remaining = math.max(0, math.ceil(self.CountdownEndsAt - os.clock()))
	self.CountdownLabel.Text = tostring(remaining)
	if remaining <= 0 and self.CountdownEndsAt > 0 then
		self.CountdownEndsAt = 0
		self:SetVisible(false)
		self:_clearRows()
	end
end

function MatchSummaryUIController:Start()
	local summaryConnection = self.ClientService:BindMatchSummaryUpdate(function(payload)
		self:Refresh(payload)
	end)
	if summaryConnection then
		table.insert(self.Connections, summaryConnection)
	end
	if self.CloseButton then
		table.insert(self.Connections, self.CloseButton.MouseButton1Click:Connect(function()
			self.CountdownEndsAt = 0
			self:SetVisible(false)
			self:_clearRows()
		end))
	end
	local uiStateConnection = self.ClientService:BindUIStateUpdate(function(payload)
		if type(payload) == "table" and payload.State == GameStates.MapRoundState.Lobby then
			self.CountdownEndsAt = 0
			self:SetVisible(false)
			self:_clearRows()
		end
	end)
	if uiStateConnection then
		table.insert(self.Connections, uiStateConnection)
	end
	table.insert(self.Connections, RunService.Heartbeat:Connect(function()
		self:_updateCountdown()
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
