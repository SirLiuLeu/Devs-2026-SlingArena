--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local MapLoader = {}
MapLoader.__index = MapLoader

function MapLoader.new()
	local self = setmetatable({}, MapLoader)
	self._definitions = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapDefinitions")
	return self
end

local function arrayToVector3(values)
	if typeof(values) ~= "table" or #values < 3 then
		return Vector3.new(0, 0, 0)
	end
	return Vector3.new(values[1], values[2], values[3])
end

local function arrayToColor3(values)
	if typeof(values) ~= "table" or #values < 3 then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(values[1], values[2], values[3])
end

function MapLoader:_decodeJson(name: string)
	local jsonValue = self._definitions:FindFirstChild(name)
	if not jsonValue or not jsonValue:IsA("StringValue") then
		return nil
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(jsonValue.Value)
	end)
	if not ok then
		warn("Invalid map definition json", name)
		return nil
	end
	return decoded
end

function MapLoader:LoadMap(parent: Instance)
	parent:ClearAllChildren()
	local meta = self:_decodeJson("meta.json")
	if typeof(meta) ~= "table" then
		return {}
	end

	local map = meta.map
	if typeof(map) ~= "table" then
		return {}
	end

	local mapFolder = Instance.new("Folder")
	mapFolder.Name = map.name or "Map"
	mapFolder.Parent = parent

	local parts = {}
	for index, partDef in ipairs(map.parts or {}) do
		if typeof(partDef) == "table" then
			local part = Instance.new("Part")
			part.Name = partDef.type or ("Part" .. index)
			part.Anchored = true
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.CollisionGroup = "Environment"
			part.Size = arrayToVector3(partDef.size or { 4, 4, 4 })
			part.Position = arrayToVector3(partDef.position or { 0, 0, 0 })
			part.Color = arrayToColor3(partDef.color)
			if typeof(partDef.material) == "string" and Enum.Material[partDef.material] then
				part.Material = Enum.Material[partDef.material]
			end
			part.Parent = mapFolder
			table.insert(parts, part)
		end
	end

	return parts
end

function MapLoader:LoadUi()
	local model = self:_decodeJson("model.json")
	if typeof(model) ~= "table" then
		return
	end

	local rootGui = Instance.new("ScreenGui")
	rootGui.Name = "MapHud"
	rootGui.ResetOnSpawn = false

	for _, uiDef in ipairs(model.ui or {}) do
		if typeof(uiDef) == "table" and uiDef.type == "TextLabel" then
			local label = Instance.new("TextLabel")
			label.Name = uiDef.name or "Label"
			label.Text = uiDef.text or ""
			if typeof(uiDef.size) == "table" and #uiDef.size == 4 then
				label.Size = UDim2.new(uiDef.size[1], uiDef.size[2], uiDef.size[3], uiDef.size[4])
			end
			if typeof(uiDef.position) == "table" and #uiDef.position == 4 then
				label.Position = UDim2.new(uiDef.position[1], uiDef.position[2], uiDef.position[3], uiDef.position[4])
			end
			label.Parent = rootGui
		end
	end

	rootGui.Parent = StarterGui
end

function MapLoader.EnsureWorkspaceMapFolder()
	local mapFolder = Workspace:FindFirstChild("Map")
	if mapFolder and mapFolder:IsA("Folder") then
		return mapFolder
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Map"
	newFolder.Parent = Workspace
	return newFolder
end

return MapLoader
