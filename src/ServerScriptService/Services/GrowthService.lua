--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

type Context = {
	EventBus: any,
	Services: any,
}

local GrowthService = {}
GrowthService.__index = GrowthService

function GrowthService.new(context: Context)
	local self = setmetatable({}, GrowthService)
	self._context = context
	self._foodFolder = Workspace:FindFirstChild("FoodEntities") :: Folder
	if not self._foodFolder then
		self._foodFolder = Instance.new("Folder")
		self._foodFolder.Name = "FoodEntities"
		self._foodFolder.Parent = Workspace
	end
	return self
end

function GrowthService:Init()
	self._context.EventBus:On("DamageDealt", function(attacker: Player, _defender: Player, damage: number)
		local playerStateService = self._context.Services.PlayerStateService
		playerStateService:GrantExp(attacker, damage * BalanceConfig.DamageToExpRatio)
	end)

	self._context.EventBus:On("PlayerKilled", function(killer: Player)
		self._context.Services.PlayerStateService:GrantExp(killer, BalanceConfig.KillExp)
	end)

	self:SpawnFoodEntities(20)
end

function GrowthService:SpawnFoodEntities(count: number)
	for i = 1, count do
		local food = Instance.new("Part")
		food.Name = "Food_" .. i
		food.Shape = Enum.PartType.Ball
		food.Color = Color3.fromRGB(87, 255, 87)
		food.Material = Enum.Material.Neon
		food.Size = Vector3.new(1.2, 1.2, 1.2)
		food.Anchored = true
		food.CanCollide = false
		food.Position = Vector3.new(math.random(-120, 120), 3, math.random(-120, 120))
		food.Parent = self._foodFolder
		food.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			self._context.Services.PlayerStateService:GrantExp(player, BalanceConfig.FoodExp)
			self._context.Services.PlayerStateService:Heal(player, BalanceConfig.FoodHealth)
			food.Position = Vector3.new(math.random(-120, 120), 3, math.random(-120, 120))
		end)
	end
end

return GrowthService
