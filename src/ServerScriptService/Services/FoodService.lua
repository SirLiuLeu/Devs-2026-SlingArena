--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config.Config)

local FoodService = {}
FoodService.__index = FoodService

function FoodService.new(context)
	local self = setmetatable({}, FoodService)
	self._context = context
	self._folder = Workspace:FindFirstChild("FoodBlocks")
	if not self._folder then
		self._folder = Instance.new("Folder")
		self._folder.Name = "FoodBlocks"
		self._folder.Parent = Workspace
	end
	self._spatialHash = {}
	return self
end

function FoodService:Init()
	for _ = 1, Config.FoodCount do
		self:SpawnFood()
	end
end

function FoodService:_randomPosition()
	local radius = Config.MaxArenaRadius - 16
	return Vector3.new(math.random(-radius, radius), 2, math.random(-radius, radius))
end

function FoodService:_cellKey(position)
	local size = 30
	local x = math.floor(position.X / size)
	local z = math.floor(position.Z / size)
	return `{x}:{z}`
end

function FoodService:SpawnFood()
	if #self._folder:GetChildren() >= Config.FoodCount then
		return
	end

	local food = Instance.new("Part")
	food.Name = "FoodBlock"
	food.Size = Vector3.new(2, 2, 2)
	food.Shape = Enum.PartType.Block
	food.Anchored = true
	food.Color = Color3.fromRGB(118, 232, 108)
	food.CollisionGroup = "Environment"
	food.Position = self:_randomPosition()
	food.Parent = self._folder

	local sizeScaleValue = Instance.new("NumberValue")
	sizeScaleValue.Name = "SizeScaleValue"
	sizeScaleValue.Value = math.random(10, 40) / 100
	sizeScaleValue.Parent = food

	local cellKey = self:_cellKey(food.Position)
	self._spatialHash[cellKey] = self._spatialHash[cellKey] or {}
	self._spatialHash[cellKey][food] = true

	food.Touched:Connect(function(hit)
		self:_onFoodTouched(food, hit)
	end)
end

function FoodService:_onFoodTouched(food, hit)
	if not food.Parent or food:GetAttribute("Consumed") then
		return
	end

	local model = hit:FindFirstAncestorOfClass("Model")
	if not model then
		return
	end

	local player = game:GetService("Players"):GetPlayerFromCharacter(model)
	if not player then
		return
	end
	if model ~= self._context.Services.PlayerService:GetPawn(player) then
		return
	end

	food:SetAttribute("Consumed", true)
	local growth = (food:FindFirstChild("SizeScaleValue") :: NumberValue).Value
	self._context.Services.PlayerStateService:GrantExp(player, math.floor(growth * 100))
	self._context.Services.PlayerStateService:Heal(player, Config.BasePlayerHP * 0.05)

	local key = self:_cellKey(food.Position)
	if self._spatialHash[key] then
		self._spatialHash[key][food] = nil
	end
	food:Destroy()
	task.delay(1.5, function()
		self:SpawnFood()
	end)
end

return FoodService
