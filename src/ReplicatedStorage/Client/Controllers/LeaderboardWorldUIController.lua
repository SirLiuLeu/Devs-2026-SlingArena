--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LeaderboardWorldUIController = {}
LeaderboardWorldUIController.__index = LeaderboardWorldUIController

local MAX_RENDERED_ROWS = 100
local MOCK_STARTING_POINTS = 1000000
local MOCK_POINT_STEP = 8750

local LIST_PATH = {
	"src",
	"Workspace",
	"Maps",
	"LobbyMap",
	"Rank",
	"Table",
	"SurfaceGui",
	"Root",
	"List",
}

local TEMPLATE_PATH = {
	"Assets",
	"UI",
	"PlayerRowTemplate_TopRank100",
}

type LeaderboardRow = {
	Rank: number?,
	Name: string?,
	ProgressPoints: number?,
	Points: number?,
}

local function asNumber(value: any, fallback: number): number
	if type(value) == "number" and value == value then
		return value
	end
	return fallback
end

local function findPath(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, childName in ipairs(path) do
		if not current then
			return nil
		end
		current = current:FindFirstChild(childName)
	end
	return current
end

local function getTargetList(): GuiObject?
	local list = findPath(Workspace, LIST_PATH)
	if list and list:IsA("GuiObject") then
		return list
	end
	warn("LeaderboardWorldUIController could not find Workspace.src.Workspace.Maps.LobbyMap.Rank.Table.SurfaceGui.Root.List")
	return nil
end

local function getRowTemplate(): Frame?
	local template = findPath(ReplicatedStorage, TEMPLATE_PATH)
	if template and template:IsA("Frame") then
		return template
	end
	warn("LeaderboardWorldUIController could not find ReplicatedStorage.Assets.UI.PlayerRowTemplate_TopRank100")
	return nil
end

local function setText(rowFrame: Instance, labelName: string, text: string)
	local label = rowFrame:FindFirstChild(labelName)
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function makeMockRows(): { LeaderboardRow }
	local rows = table.create(MAX_RENDERED_ROWS)
	for rank = 1, MAX_RENDERED_ROWS do
		rows[rank] = {
			Rank = rank,
			Name = "Player_" .. tostring(rank),
			Points = MOCK_STARTING_POINTS - ((rank - 1) * MOCK_POINT_STEP),
		}
	end
	return rows
end

function LeaderboardWorldUIController.new(clientService: any)
	local self = setmetatable({}, LeaderboardWorldUIController)
	self.ClientService = clientService
	self.Connections = {} :: { RBXScriptConnection }
	self.RowsFrame = nil :: GuiObject?
	self.RowTemplate = nil :: Frame?
	return self
end

function LeaderboardWorldUIController:_ensureReferences(): boolean
	self.RowsFrame = getTargetList()
	self.RowTemplate = getRowTemplate()
	return self.RowsFrame ~= nil and self.RowTemplate ~= nil
end

function LeaderboardWorldUIController:_clearRows()
	if not self.RowsFrame then
		return
	end
	for _, child in ipairs(self.RowsFrame:GetChildren()) do
		if child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			continue
		end
		child:Destroy()
	end
end

function LeaderboardWorldUIController:Render(payload: any?)
	if not self:_ensureReferences() then
		return
	end

	self:_clearRows()

	local rows = if type(payload) == "table" and type(payload.Rows) == "table" then payload.Rows else makeMockRows()
	local rowsFrame = self.RowsFrame :: GuiObject
	local rowTemplate = self.RowTemplate :: Frame

	for index, row in ipairs(rows) do
		if index > MAX_RENDERED_ROWS then
			break
		end
		if type(row) == "table" then
			local rank = math.floor(asNumber(row.Rank, index))
			local points = math.floor(asNumber(row.Points or row.ProgressPoints, 0))
			local rowFrame = rowTemplate:Clone()
			rowFrame.Name = "TopRank100Row_" .. tostring(rank)
			rowFrame.LayoutOrder = rank
			rowFrame.Visible = true
			setText(rowFrame, "RankValue", "#" .. tostring(rank))
			setText(rowFrame, "NameValue", tostring(row.Name or "Player_" .. tostring(rank)))
			setText(rowFrame, "PointValue", tostring(points))
			rowFrame.Parent = rowsFrame
		end
	end
end

function LeaderboardWorldUIController:Start()
	self:Render()
	if self.ClientService and self.ClientService.BindGlobalTop100Update then
		local connection = self.ClientService:BindGlobalTop100Update(function(payload)
			self:Render(payload)
		end)
		if connection then
			table.insert(self.Connections, connection)
		end
	end
end

function LeaderboardWorldUIController:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return LeaderboardWorldUIController
