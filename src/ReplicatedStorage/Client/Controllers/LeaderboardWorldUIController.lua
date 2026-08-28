--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local DebugConfig = require(ReplicatedStorage.Shared.Config.DebugConfig)
local LeaderboardWorldUIController = {}
LeaderboardWorldUIController.__index = LeaderboardWorldUIController
local MAX_RENDERED_ROWS = 100
local LIST_PATH = { "Maps", "LobbyMap", "Rank", "Table", "SurfaceGui", "Root", "List" }
local TEMPLATE_PATH = { "Assets", "UI", "PlayerRowTemplate_TopRank100" }
local function findPath(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for _, name in ipairs(path) do current = current and current:FindFirstChild(name) or nil end
	return current
end
local function setText(row: Instance, name: string, value: string, cache: { [string]: string })
	if cache[name] == value then return end
	local label = row:FindFirstChild(name)
	if label and label:IsA("TextLabel") then label.Text = value; cache[name] = value end
end
function LeaderboardWorldUIController.new(clientService: any)
	local self = setmetatable({}, LeaderboardWorldUIController)
	self.ClientService = clientService; self.Connections = {}; self.RowsFrame = nil; self.RowTemplate = nil; self._rowPool = {}; self._rowState = {}
	return self
end
function LeaderboardWorldUIController:_ensureReferences(): boolean
	self.RowsFrame = self.RowsFrame or (findPath(Workspace, LIST_PATH) :: GuiObject?)
	self.RowTemplate = self.RowTemplate or (findPath(ReplicatedStorage, TEMPLATE_PATH) :: Frame?)
	if not self.RowsFrame or not self.RowTemplate then if DebugConfig.VerboseTrace then warn("[LeaderboardWorldUI] Missing list or row template") end; return false end
	if #self._rowPool == 0 then
		for index = 1, MAX_RENDERED_ROWS do local row = self.RowTemplate:Clone(); row.Name = "TopRank100Row_" .. index; row.Visible = false; row.Parent = self.RowsFrame; self._rowPool[index] = row; self._rowState[index] = {} end
	end
	return true
end
function LeaderboardWorldUIController:Render(payload: any?)
	if not self:_ensureReferences() then return end
	local rows = type(payload) == "table" and type(payload.Rows) == "table" and payload.Rows or {}
	for index, rowFrame in ipairs(self._rowPool) do
		local row = rows[index]
		if type(row) == "table" then
			local rank = math.floor(tonumber(row.Rank) or index); local points = math.floor(tonumber(row.Points or row.ProgressPoints) or 0); local cache = self._rowState[index]
			rowFrame.LayoutOrder = rank; rowFrame.Name = "TopRank100Row_" .. rank; rowFrame.Visible = true
			setText(rowFrame, "RankValue", "#" .. rank, cache); setText(rowFrame, "NameValue", tostring(row.Name or "Player_" .. rank), cache); setText(rowFrame, "PointValue", tostring(points), cache)
		else rowFrame.Visible = false end
	end
end
function LeaderboardWorldUIController:Start()
	self:_ensureReferences()
	if self.ClientService and self.ClientService.BindGlobalTop100Update then local connection = self.ClientService:BindGlobalTop100Update(function(payload) self:Render(payload) end); if connection then table.insert(self.Connections, connection) end end
end
function LeaderboardWorldUIController:Destroy() for _, connection in ipairs(self.Connections) do connection:Disconnect() end; table.clear(self.Connections) end
return LeaderboardWorldUIController
