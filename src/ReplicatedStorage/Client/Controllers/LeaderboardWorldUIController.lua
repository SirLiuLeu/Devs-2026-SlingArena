--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LeaderboardWorldUIController = {}
LeaderboardWorldUIController.__index = LeaderboardWorldUIController

local MAX_RENDERED_ROWS = 100
local MOCK_STARTING_POINTS = 1000000
local MOCK_POINT_STEP = 8750

local LIST_PATH = {
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

-- [DEBUG ENHANCED] Tìm path và in rõ nút nào bị thiếu nếu lỗi
local function findPath(root: Instance, path: { string }): Instance?
	local current: Instance? = root
	for index, childName in ipairs(path) do
		if not current then
			print(string.format("[DEBUG Leaderboard] ❌ Path trace broken BEFORE reaching index %d ('%sub')", index, childName))
			return nil
		end
		local nextChild = current:FindFirstChild(childName)
		if not nextChild then
			print(string.format("[DEBUG Leaderboard] ❌ Failed to find child '%s' inside '%s' (Path step %d/%d)", childName, current:GetFullName(), index, #path))
			return nil
		end
		current = nextChild
	end
	return current
end

local function getTargetList(): GuiObject?
	print("[DEBUG Leaderboard] Searching for Target List...")
	
	-- Dùng WaitForChild từng cấp để chờ Roblox Streaming tải Part 3D về Client
	local maps = Workspace:WaitForChild("Maps")
	local lobbyMap = maps:WaitForChild("LobbyMap")
	local rank = lobbyMap:WaitForChild("Rank")
	local tablePart = rank:WaitForChild("Table")
	local surfaceGui = tablePart:WaitForChild("SurfaceGui")
	local root = surfaceGui:WaitForChild("Root")
	local list = root:WaitForChild("List")

	if list and list:IsA("GuiObject") then
		print("[DEBUG Leaderboard] ✅ Target List loaded & found:", list:GetFullName())
		return list :: GuiObject
	end

	warn("[DEBUG Leaderboard] ❌ Target List is not a GuiObject!")
	return nil
end

local function getRowTemplate(): Frame?
	print("[DEBUG Leaderboard] Searching for Row Template...")
	
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local ui = assets:WaitForChild("UI")
	local template = ui:WaitForChild("PlayerRowTemplate_TopRank100")

	if template and template:IsA("Frame") then
		print("[DEBUG Leaderboard] ✅ Row Template found successfully:", template:GetFullName())
		return template :: Frame
	end

	warn("[DEBUG Leaderboard] ❌ Could not find PlayerRowTemplate_TopRank100")
	return nil
end

local function setText(rowFrame: Instance, labelName: string, text: string)
	local label = rowFrame:FindFirstChild(labelName)
	if label and label:IsA("TextLabel") then
		label.Text = text
	else
		warn(string.format("[DEBUG Leaderboard] ❌ Failed to set text: Child '%s' not found or not a TextLabel in %s", labelName, rowFrame.Name))
	end
end

local function makeMockRows(): { LeaderboardRow }
	print("[DEBUG Leaderboard] Generating mock data for Top 100...")
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
	print("[DEBUG Leaderboard] Controller.new() instantiated")
	local self = setmetatable({}, LeaderboardWorldUIController)
	self.ClientService = clientService
	self.Connections = {} :: { RBXScriptConnection }
	self.RowsFrame = nil :: GuiObject?
	self.RowTemplate = nil :: Frame?
	return self
end

function LeaderboardWorldUIController:_ensureReferences(): boolean
	print("[DEBUG Leaderboard] Executing _ensureReferences()...")
	if not self.RowsFrame then
		self.RowsFrame = getTargetList()
	end
	if not self.RowTemplate then
		self.RowTemplate = getRowTemplate()
	end
	
	local success = self.RowsFrame ~= nil and self.RowTemplate ~= nil
	print("[DEBUG Leaderboard] _ensureReferences() Result:", success)
	return success
end

function LeaderboardWorldUIController:_clearRows()
	if not self.RowsFrame then
		return
	end
	local deletedCount = 0
	for _, child in ipairs(self.RowsFrame:GetChildren()) do
		if child:IsA("UIGridLayout") or child:IsA("UIListLayout") or child:IsA("UIAspectRatioConstraint") then
			continue
		end
		child:Destroy()
		deletedCount += 1
	end
	print(string.format("[DEBUG Leaderboard] _clearRows() cleaned up %d old items.", deletedCount))
end

function LeaderboardWorldUIController:Render(payload: any?)
	print("[DEBUG Leaderboard] >>> Starting Render() process <<<")
	if payload then
		print("[DEBUG Leaderboard] Payload received type:", type(payload))
	else
		print("[DEBUG Leaderboard] Payload is nil -> Will use Mock Data")
	end

	if not self:_ensureReferences() then
		warn("[DEBUG Leaderboard] ❌ Render aborted: References check failed! Check path logs above.")
		return
	end

	self:_clearRows()

	local rows = if type(payload) == "table" and type(payload.Rows) == "table" then payload.Rows else makeMockRows()
	print("[DEBUG Leaderboard] Total rows to process:", #rows)

	local rowsFrame = self.RowsFrame :: GuiObject
	local rowTemplate = self.RowTemplate :: Frame

	local renderedCount = 0
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
			renderedCount += 1
		end
	end

	print(string.format("[DEBUG Leaderboard] ✅ Render complete! Successfully created and parented %d rows into '%s'. Current children count in List: %d", 
		renderedCount, 
		rowsFrame:GetFullName(), 
		#rowsFrame:GetChildren()
	))
end

function LeaderboardWorldUIController:Start()
	print("[DEBUG Leaderboard] === LeaderboardWorldUIController:Start() called ===")
	self:Render()
	
	if self.ClientService and self.ClientService.BindGlobalTop100Update then
		print("[DEBUG Leaderboard] Binding to ClientService.BindGlobalTop100Update...")
		local connection = self.ClientService:BindGlobalTop100Update(function(payload)
			print("[DEBUG Leaderboard] Received event update from ClientService!")
			self:Render(payload)
		end)
		if connection then
			table.insert(self.Connections, connection)
		end
	else
		print("[DEBUG Leaderboard] No ClientService / BindGlobalTop100Update found (Running in standalone mode).")
	end
end

function LeaderboardWorldUIController:Destroy()
	print("[DEBUG Leaderboard] Destroying controller and connections...")
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return LeaderboardWorldUIController