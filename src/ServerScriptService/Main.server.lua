--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServicesFolder = script.Parent:WaitForChild("Services")

local PlayerService = require(ServicesFolder.PlayerService)
local SlingService = require(ServicesFolder.SlingService)
local MapService = require(ServicesFolder.MapService)
local FoodService = require(ServicesFolder.FoodService)
local CollisionService = require(ServicesFolder.CollisionService)
local ChargeService = require(ServicesFolder.ChargeService)
local RoundService = require(ServicesFolder.RoundService)

local function ensureCollisionGroup(name)
	local ok = pcall(function()
		PhysicsService:CreateCollisionGroup(name)
	end)
	if not ok then
		-- already exists
	end
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

ensureRemote("SlingAimRemote")
ensureRemote("SlingReleaseRemote")

local context = {
	Remotes = remotesFolder,
	Services = {},
}

context.Services.PlayerService = PlayerService.new(context)
context.Services.SlingService = SlingService.new(context)
context.Services.MapService = MapService.new(context)
context.Services.FoodService = FoodService.new(context)
context.Services.CollisionService = CollisionService.new(context)
context.Services.ChargeService = ChargeService.new(context)
context.Services.RoundService = RoundService.new(context)

context.Services.PlayerService:Init()
context.Services.SlingService:Init()
context.Services.MapService:Init()
context.Services.FoodService:Init()
context.Services.CollisionService:Init()
context.Services.ChargeService:Init()
context.Services.RoundService:Init()
