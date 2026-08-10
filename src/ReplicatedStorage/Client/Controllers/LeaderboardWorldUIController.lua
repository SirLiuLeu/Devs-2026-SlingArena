--!strict

local Workspace = game:GetService("Workspace")

local LeaderboardWorldUIController = {}
LeaderboardWorldUIController.__index = LeaderboardWorldUIController

local BOARD_PART_NAME = "GlobalTop100Board"
local SURFACE_GUI_NAME = "GlobalTop100SurfaceGui"
local ROW_CONTAINER_NAME = "Rows"
local MAX_RENDERED_ROWS = 100

local function asNumber(value: any, fallback: number): number
	if type(value) == "number" and value == value then
		return value
	end
	return fallback
end

local function ensureBoardPart(): BasePart
	local existing = Workspace:FindFirstChild(BOARD_PART_NAME)
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = BOARD_PART_NAME
	part.Anchored = true
	part.Size = Vector3.new(18, 10, 1)
	part.CFrame = CFrame.new(0, 8, -35)
	part.Parent = Workspace
	return part
end

local function ensureText(parent: Instance, name: string, textSize: number): TextLabel
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("TextLabel") then
		return existing
	end
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextSize = textSize
	label.Parent = parent
	return label
end

function LeaderboardWorldUIController.new(clientService: any)
	local self = setmetatable({}, LeaderboardWorldUIController)
	self.ClientService = clientService
	self.Connections = {} :: { RBXScriptConnection }
	self.SurfaceGui = nil :: SurfaceGui?
	self.RowsFrame = nil :: ScrollingFrame?
	return self
end

function LeaderboardWorldUIController:_ensureGui()
	local part = ensureBoardPart()
	local gui = part:FindFirstChild(SURFACE_GUI_NAME)
	if not (gui and gui:IsA("SurfaceGui")) then
		gui = Instance.new("SurfaceGui")
		gui.Name = SURFACE_GUI_NAME
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = part
	end
	self.SurfaceGui = gui

	local title = ensureText(gui, "Title", 28)
	title.Size = UDim2.new(1, -24, 0, 42)
	title.Position = UDim2.fromOffset(12, 8)
	title.Text = "Global Top 100"

	local rows = gui:FindFirstChild(ROW_CONTAINER_NAME)
	if not (rows and rows:IsA("ScrollingFrame")) then
		rows = Instance.new("ScrollingFrame")
		rows.Name = ROW_CONTAINER_NAME
		rows.BackgroundTransparency = 0.25
		rows.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
		rows.BorderSizePixel = 0
		rows.ScrollBarThickness = 8
		rows.Parent = gui
		local layout = Instance.new("UIListLayout")
		layout.Name = "ListLayout"
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 2)
		layout.Parent = rows
	end
	rows.Size = UDim2.new(1, -24, 1, -62)
	rows.Position = UDim2.fromOffset(12, 54)
	self.RowsFrame = rows
end

function LeaderboardWorldUIController:_clearRows()
	if not self.RowsFrame then
		return
	end
	for _, child in ipairs(self.RowsFrame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

function LeaderboardWorldUIController:Render(payload: any)
	self:_ensureGui()
	self:_clearRows()
	local rows = if type(payload) == "table" and type(payload.Rows) == "table" then payload.Rows else {}
	if not self.RowsFrame then
		return
	end
	for index, row in ipairs(rows) do
		if index > MAX_RENDERED_ROWS then
			break
		end
		if type(row) == "table" then
			local label = Instance.new("TextLabel")
			label.Name = "GlobalRank_" .. tostring(index)
			label.LayoutOrder = index
			label.BackgroundColor3 = if index % 2 == 0 then Color3.fromRGB(31, 36, 52) else Color3.fromRGB(39, 45, 64)
			label.BorderSizePixel = 0
			label.Font = Enum.Font.GothamMedium
			label.TextColor3 = Color3.fromRGB(245, 245, 245)
			label.TextSize = 18
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Size = UDim2.new(1, -8, 0, 26)
			label.Text = string.format("#%d  %s  —  %d PP", math.floor(asNumber(row.Rank, index)), tostring(row.Name or "Player"), math.floor(asNumber(row.ProgressPoints, 0)))
			label.Parent = self.RowsFrame
		end
	end
	self.RowsFrame.CanvasSize = UDim2.fromOffset(0, math.max(#rows, 1) * 28)
end

function LeaderboardWorldUIController:Start()
	self:_ensureGui()
	local connection = self.ClientService:BindGlobalTop100Update(function(payload)
		self:Render(payload)
	end)
	if connection then
		table.insert(self.Connections, connection)
	end
end

function LeaderboardWorldUIController:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return LeaderboardWorldUIController
