--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServicesFolder = script.Parent:WaitForChild("Services")

local EventBus = require(ServicesFolder.EventBus)
local PlayerStateService = require(ServicesFolder.PlayerStateService)
local PlayerService = require(ServicesFolder.PlayerService)
local TeamService = require(ServicesFolder.TeamService)
local SlingService = require(ServicesFolder.SlingService)
local MapService = require(ServicesFolder.MapService)
local FoodService = require(ServicesFolder.FoodService)
local CollisionService = require(ServicesFolder.CollisionService)
local CombatService = require(ServicesFolder.CombatService)
local DamagePipelineService = require(ServicesFolder.DamagePipelineService)
local GrowthService = require(ServicesFolder.GrowthService)
local TrapService = require(ServicesFolder.TrapService)
local RoundService = require(ServicesFolder.RoundService)
local SkillService = require(ServicesFolder.SkillService)
local LeaderboardService = require(ServicesFolder.LeaderboardService)

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local function ensureCollisionGroup(name)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

ensureCollisionGroup("Players")
ensureCollisionGroup("Environment")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", true)
PhysicsService:CollisionGroupSetCollidable("Players", "Environment", true)

local remotesFolder = ReplicatedStorage:WaitForChild("SlingArenaRemotes") :: Folder
for _, remoteName in pairs(RemoteContracts.Names) do
	local remote = remotesFolder:WaitForChild(remoteName, 5)
	if not remote then
		warn(string.format("[RemoteSetup] Missing ReplicatedStorage.SlingArenaRemotes.%s (RemoteEvent). Create it in Studio.", remoteName))
	end
end

local context = {
	Remotes = remotesFolder,
	Services = {},
	EventBus = EventBus.new(),
}

context.Services.PlayerStateService = PlayerStateService.new(context)
context.Services.TeamService = TeamService.new(context)
context.Services.PlayerService = PlayerService.new(context)
context.Services.SlingService = SlingService.new(context)
context.Services.MapService = MapService.new(context)
context.Services.FoodService = FoodService.new(context)
context.Services.CollisionService = CollisionService.new(context)
context.Services.CombatService = CombatService.new(context)
context.Services.DamagePipelineService = DamagePipelineService.new(context)
context.Services.GrowthService = GrowthService.new(context)
context.Services.TrapService = TrapService.new(context)
context.Services.RoundService = RoundService.new(context)
context.Services.SkillService = SkillService.new(context)
context.Services.LeaderboardService = LeaderboardService.new(context)

context.Services.PlayerStateService:Init()
context.Services.TeamService:Init()
context.Services.MapService:Init()
context.Services.PlayerService:Init()
context.Services.FoodService:Init()
context.Services.SlingService:Init()
context.Services.CombatService:Init()
context.Services.CollisionService:Init()
context.Services.DamagePipelineService:Init()
context.Services.GrowthService:Init()
context.Services.TrapService:Init()
context.Services.SkillService:Init()
context.Services.LeaderboardService:Init()
context.Services.RoundService:Init()
