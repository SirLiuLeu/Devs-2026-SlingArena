--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServicesFolder = script.Parent:WaitForChild("Services")

local EventBus = require(ServicesFolder.EventBus)
local PlayerStateService = require(ServicesFolder.PlayerStateService)
local PlayerService = require(ServicesFolder.PlayerService)
local SlingService = require(ServicesFolder.SlingService)
local MapService = require(ServicesFolder.MapService)
local FoodService = require(ServicesFolder.FoodService)
local CollisionService = require(ServicesFolder.CollisionService)
local ChargeService = require(ServicesFolder.ChargeService)
local MatchService = require(ServicesFolder.MatchService)
local DamagePipelineService = require(ServicesFolder.DamagePipelineService)
local TrapService = require(ServicesFolder.TrapService)

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local function ensureCollisionGroup(name)
	pcall(function()
		PhysicsService:CreateCollisionGroup(name)
	end)
end

ensureCollisionGroup("Players")
ensureCollisionGroup("Environment")
PhysicsService:CollisionGroupSetCollidable("Players", "Players", true)
PhysicsService:CollisionGroupSetCollidable("Players", "Environment", true)

local remotesFolder = ReplicatedStorage:FindFirstChild("SlingArenaRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "SlingArenaRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name)
	local remote = remotesFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

for _, remoteName in pairs(RemoteContracts.Names) do
	ensureRemote(remoteName)
end

local context = {
	Remotes = remotesFolder,
	Services = {},
	EventBus = EventBus.new(),
}

context.Services.PlayerStateService = PlayerStateService.new(context)
context.Services.PlayerService = PlayerService.new(context)
context.Services.SlingService = SlingService.new(context)
context.Services.MapService = MapService.new(context)
context.Services.FoodService = FoodService.new(context)
context.Services.CollisionService = CollisionService.new(context)
context.Services.ChargeService = ChargeService.new(context)
context.Services.DamagePipelineService = DamagePipelineService.new(context)
context.Services.TrapService = TrapService.new(context)
context.Services.MatchService = MatchService.new(context)

context.Services.PlayerStateService:Init()
context.Services.PlayerService:Init()
context.Services.SlingService:Init()
context.Services.MapService:Init()
context.Services.FoodService:Init()
context.Services.CollisionService:Init()
context.Services.ChargeService:Init()
context.Services.DamagePipelineService:Init()
context.Services.TrapService:Init()
context.Services.MatchService:Init()
