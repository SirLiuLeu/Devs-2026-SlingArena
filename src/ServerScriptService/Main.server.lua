--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServicesFolder = script.Parent:WaitForChild("Services")

local function requireSafe(moduleScript: Instance, moduleName: string)
	local ok, loaded = pcall(require, moduleScript)
	if not ok then
		warn(string.format("[Bootstrap] Failed to require %s: %s", moduleName, tostring(loaded)))
		return nil
	end
	return loaded
end

local EventBus = requireSafe(ServicesFolder:WaitForChild("EventBus"), "EventBus")
local ServiceRegistry = requireSafe(ServicesFolder:WaitForChild("ServiceRegistry"), "ServiceRegistry")
local PlayerStateService = requireSafe(ServicesFolder:WaitForChild("PlayerStateService"), "PlayerStateService")
local FlagService = requireSafe(ServicesFolder:WaitForChild("FlagService"), "FlagService")
local PlayerService = requireSafe(ServicesFolder:WaitForChild("PlayerService"), "PlayerService")
local TeamService = requireSafe(ServicesFolder:WaitForChild("TeamService"), "TeamService")
local SlingService = requireSafe(ServicesFolder:WaitForChild("SlingService"), "SlingService")
local MapService = requireSafe(ServicesFolder:WaitForChild("MapService"), "MapService")
local FoodService = requireSafe(ServicesFolder:WaitForChild("FoodService"), "FoodService")
local CollisionService = requireSafe(ServicesFolder:WaitForChild("CollisionService"), "CollisionService")
local DamagePipelineService = requireSafe(ServicesFolder:WaitForChild("DamagePipelineService"), "DamagePipelineService")
local GrowthService = requireSafe(ServicesFolder:WaitForChild("GrowthService"), "GrowthService")
local TrapService = requireSafe(ServicesFolder:WaitForChild("TrapService"), "TrapService")
local RoundService = requireSafe(ServicesFolder:WaitForChild("RoundService"), "RoundService")
local SafeZoneService = requireSafe(ServicesFolder:WaitForChild("SafeZoneService"), "SafeZoneService")
local MonetizationService = requireSafe(ServicesFolder:WaitForChild("MonetizationService"), "MonetizationService")
local LeaderboardService = requireSafe(ServicesFolder:WaitForChild("LeaderboardService"), "LeaderboardService")
local SlingAbilityFolder = ServicesFolder:FindFirstChild("SlingAbilityService")
local SlingAbilityService = nil
if SlingAbilityFolder and SlingAbilityFolder:IsA("Folder") then
	local moduleScript = SlingAbilityFolder:FindFirstChild("SlingAbilityService")
	if moduleScript then
		SlingAbilityService = requireSafe(moduleScript, "SlingAbilityService")
	else
		warn("[Bootstrap] Missing Services.SlingAbilityService.SlingAbilityService module.")
	end
else
	warn("[Bootstrap] Missing Services.SlingAbilityService folder.")
end

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
	local remote = remotesFolder:FindFirstChild(remoteName)
	if not remote then
		warn(string.format("[RemoteSetup] Missing ReplicatedStorage.SlingArenaRemotes.%s (RemoteEvent). Create it in Studio.", remoteName))
	end
end

local context = {
	Remotes = remotesFolder,
	Services = {},
	EventBus = EventBus and EventBus.new() or nil,
	ServiceRegistry = ServiceRegistry and ServiceRegistry.new() or nil,
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

local serviceConstructors = {
	PlayerStateService = PlayerStateService,
	FlagService = FlagService,
	TeamService = TeamService,
	PlayerService = PlayerService,
	SlingService = SlingService,
	MapService = MapService,
	FoodService = FoodService,
	CollisionService = CollisionService,
	DamagePipelineService = DamagePipelineService,
	GrowthService = GrowthService,
	TrapService = TrapService,
	RoundService = RoundService,
	SlingAbilityService = SlingAbilityService,
	SafeZoneService = SafeZoneService,
	MonetizationService = MonetizationService,
	LeaderboardService = LeaderboardService,
}

for serviceName, constructor in pairs(serviceConstructors) do
	if constructor and typeof(constructor.new) == "function" then
		local ok, service = xpcall(function()
			return constructor.new(context)
		end, debug.traceback)
		if ok and service then
			context.Services[serviceName] = service
			if context.ServiceRegistry then
				context.ServiceRegistry:Register(serviceName, service)
			end
		else
			warn(string.format("[Bootstrap] Failed to construct service %s: %s", serviceName, tostring(service)))
		end
	else
		warn(string.format("[Bootstrap] Missing constructor for service %s.", serviceName))
	end
end

local initializationOrder = {
	"PlayerStateService",
	"FlagService",
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
