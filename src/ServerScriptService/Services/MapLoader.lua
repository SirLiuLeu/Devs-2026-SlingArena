--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapLoader = {}
MapLoader.__index = MapLoader

function MapLoader.new()
	local self = setmetatable({}, MapLoader)
	self._shared = ReplicatedStorage:WaitForChild("Shared")
	self._metaConfig = nil
	return self
end

function MapLoader:_loadMetaConfig()
	if self._metaConfig ~= nil then
		return self._metaConfig
	end

	local definitionsFolder = self._shared:FindFirstChild("MapDefinitions")
	local jsonValue = definitionsFolder and definitionsFolder:FindFirstChild("meta.json")
	if not jsonValue or not jsonValue:IsA("StringValue") then
		self._metaConfig = {}
		return self._metaConfig
	end

	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(jsonValue.Value)
	end)
	if not ok or typeof(decoded) ~= "table" then
		warn("Invalid MapDefinitions meta.json")
		self._metaConfig = {}
		return self._metaConfig
	end

	self._metaConfig = decoded
	return self._metaConfig
end

function MapLoader:GetMetaConfig()
	return self:_loadMetaConfig()
end

function MapLoader:GetMapDuration(defaultDuration: number): number
	local config = self:_loadMetaConfig()
	local duration = config.duration
	if typeof(duration) == "number" and duration > 0 then
		return duration
	end
	return defaultDuration
end

function MapLoader:GetMapRoot()
	local mapRoot = Workspace:FindFirstChild("MapDefinitions")
	if mapRoot and mapRoot:IsA("Folder") then
		return mapRoot
	end
	return nil
end

return MapLoader
