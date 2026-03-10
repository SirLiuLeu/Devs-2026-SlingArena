--!strict

local Workspace = game:GetService("Workspace")

local MapLoader = {}
MapLoader.__index = MapLoader

function MapLoader.new()
	local self = setmetatable({}, MapLoader)
	return self
end

function MapLoader:GetMetaConfig()
	return {}
end

function MapLoader:GetMapDuration(defaultDuration: number): number
	return defaultDuration
end

function MapLoader:GetMapRoot()
	local mapRoot = Workspace:FindFirstChild("Maps")
	if mapRoot and mapRoot:IsA("Folder") then
		return mapRoot
	end
	return nil
end

return MapLoader
