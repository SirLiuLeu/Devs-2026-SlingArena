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

local EventBus = requireSafe(ServicesFolder:WaitForChild("Infrastructure"):WaitForChild("EventBus"), "EventBus")
local ServiceRegistry = requireSafe(ServicesFolder:WaitForChild("Infrastructure"):WaitForChild("ServiceRegistry"), "ServiceRegistry")
local RateLimiter = requireSafe(ServicesFolder:WaitForChild("Infrastructure"):WaitForChild("RateLimiter"), "RateLimiter")
local PlayerStateService = requireSafe(ServicesFolder:WaitForChild("PlayerStateService"), "PlayerStateService")
local FlagService = requireSafe(ServicesFolder:WaitForChild("FlagService"), "FlagService")
local PlayerService = requireSafe(ServicesFolder:WaitForChild("PlayerService"):WaitForChild("PlayerService"), "PlayerService")
local TeamService = requireSafe(ServicesFolder:WaitForChild("TeamService"), "TeamService")
local LauncherService = requireSafe(ServicesFolder:WaitForChild("LauncherService"):WaitForChild("LauncherService"), "LauncherService")
local MapService = requireSafe(ServicesFolder:WaitForChild("MapService"), "MapService")
local FoodService = requireSafe(ServicesFolder:WaitForChild("FoodService"), "FoodService")
local CollisionService = requireSafe(ServicesFolder:WaitForChild("CollisionService"), "CollisionService")
local HitCooldownDedupe = requireSafe(ServicesFolder:WaitForChild("Helpers"):WaitForChild("HitCooldownDedupe"), "HitCooldownDedupe")
local DamagePipelineService = requireSafe(ServicesFolder:WaitForChild("DamagePipelineService"), "DamagePipelineService")
local GrowthService = requireSafe(ServicesFolder:WaitForChild("GrowthService"), "GrowthService")
local TrapService = requireSafe(ServicesFolder:WaitForChild("TrapService"), "TrapService")
local RoundService = requireSafe(ServicesFolder:WaitForChild("RoundService"), "RoundService")
local SafeZoneService = requireSafe(ServicesFolder:WaitForChild("SafeZoneService"), "SafeZoneService")
local MonetizationService = requireSafe(ServicesFolder:WaitForChild("MonetizationService"), "MonetizationService")
local LeaderboardService = requireSafe(ServicesFolder:WaitForChild("LeaderboardService"), "LeaderboardService")
local PlayerDataService = requireSafe(ServicesFolder:WaitForChild("PlayerDataService"), "PlayerDataService")
local ProgressPointService = requireSafe(ServicesFolder:WaitForChild("ProgressPointService"), "ProgressPointService")
local LauncherAbilityFolder = ServicesFolder:FindFirstChild("LauncherAbilityService")
local LauncherAbilityService = nil
if LauncherAbilityFolder and LauncherAbilityFolder:IsA("Folder") then
	local moduleScript = LauncherAbilityFolder:FindFirstChild("LauncherAbilityService")
	if moduleScript then
		LauncherAbilityService = requireSafe(moduleScript, "LauncherAbilityService")
	else
		warn("[Bootstrap] Missing Services.LauncherAbilityService.LauncherAbilityService module.")
	end
else
	warn("[Bootstrap] Missing Services.LauncherAbilityService folder.")
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

local remotesFolder = ReplicatedStorage:WaitForChild("LauncherArenaRemotes") :: Folder
for _, remoteName in pairs(RemoteContracts.Names) do
	local remote = remotesFolder:FindFirstChild(remoteName)
	if not remote then
		warn(string.format("[RemoteSetup] Missing ReplicatedStorage.LauncherArenaRemotes.%s (RemoteEvent). Create it in Studio.", remoteName))
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
	RateLimiter = RateLimiter,
	PlayerStateService = PlayerStateService,
	FlagService = FlagService,
	TeamService = TeamService,
	PlayerService = PlayerService,
	LauncherService = LauncherService,
	MapService = MapService,
	FoodService = FoodService,
	CollisionService = CollisionService,
	HitCooldownDedupe = HitCooldownDedupe,
	DamagePipelineService = DamagePipelineService,
	GrowthService = GrowthService,
	TrapService = TrapService,
	RoundService = RoundService,
	LauncherAbilityService = LauncherAbilityService,
	SafeZoneService = SafeZoneService,
	MonetizationService = MonetizationService,
	LeaderboardService = LeaderboardService,
	PlayerDataService = PlayerDataService,
	ProgressPointService = ProgressPointService,
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
	"RateLimiter",
	"PlayerDataService",
	"PlayerStateService",
	"FlagService",
	"TeamService",
	"MapService",
	"PlayerService",
	"FoodService",
	"LauncherService",
	"HitCooldownDedupe",
	"CollisionService",
	"DamagePipelineService",
	"GrowthService",
	"TrapService",
	"LauncherAbilityService",
	"SafeZoneService",
	"MonetizationService",
	"LeaderboardService",
	"ProgressPointService",
	"RoundService",
}

for _, serviceName in ipairs(initializationOrder) do
	runServicePhase(serviceName, "Init")
end

for _, serviceName in ipairs(initializationOrder) do
	runServicePhase(serviceName, "Start")
end
