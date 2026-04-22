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
local DamagePipelineService = require(ServicesFolder.DamagePipelineService)
local GrowthService = require(ServicesFolder.GrowthService)
local TrapService = require(ServicesFolder.TrapService)
local RoundService = require(ServicesFolder.RoundService)
local SlingAbilityService = require(ServicesFolder.SlingAbilityService.SlingAbilityService)
local SafeZoneService = require(ServicesFolder.SafeZoneService)
local MonetizationService = require(ServicesFolder.MonetizationService)
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

local function runServicePhase(serviceName: string, phase: "Init" | "Start")
	local service = context.Services[serviceName]
	if not service then
		warn(string.format("[Bootstrap] Missing service %s during %s phase.", serviceName, phase))
		return
	end

	local phaseMethod = service[phase]
	if typeof(phaseMethod) ~= "function" then
		return
	end

	local ok, err = xpcall(function()
		phaseMethod(service)
	end, debug.traceback)
	if not ok then
		warn(string.format("[Bootstrap] %s:%s failed: %s", serviceName, phase, tostring(err)))
	end
end

context.Services.PlayerStateService = PlayerStateService.new(context)
context.Services.TeamService = TeamService.new(context)
context.Services.PlayerService = PlayerService.new(context)
context.Services.SlingService = SlingService.new(context)
context.Services.MapService = MapService.new(context)
context.Services.FoodService = FoodService.new(context)
context.Services.CollisionService = CollisionService.new(context)
context.Services.DamagePipelineService = DamagePipelineService.new(context)
context.Services.GrowthService = GrowthService.new(context)
context.Services.TrapService = TrapService.new(context)
context.Services.RoundService = RoundService.new(context)
context.Services.SlingAbilityService = SlingAbilityService.new(context)
context.Services.SafeZoneService = SafeZoneService.new(context)
context.Services.MonetizationService = MonetizationService.new(context)
context.Services.LeaderboardService = LeaderboardService.new(context)

local initializationOrder = {
	"PlayerStateService",
	"TeamService",
	"MapService",
	"PlayerService",
	"FoodService",
	"SlingService",
	"CollisionService",
	"DamagePipelineService",
	"GrowthService",
	"TrapService",
	"SlingAbilityService",
	"SafeZoneService",
	"MonetizationService",
	"LeaderboardService",
	"RoundService",
}

for _, serviceName in ipairs(initializationOrder) do
	runServicePhase(serviceName, "Init")
end

for _, serviceName in ipairs(initializationOrder) do
	runServicePhase(serviceName, "Start")
end
