--!strict

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServicesFolder = script.Parent:WaitForChild("Services")

local function requireSafe(moduleScript: Instance, moduleName: string)
	local ok, loaded = pcall(require, moduleScript)
	if not ok then
		error(string.format("[Bootstrap CRITICAL] Failed to require %s: %s", moduleName, tostring(loaded)), 0)
	end
	return loaded
end

local EventBus = requireSafe(ServicesFolder:WaitForChild("Infrastructure"):WaitForChild("EventBus"), "EventBus")
local ServiceRegistry = requireSafe(ServicesFolder:WaitForChild("Infrastructure"):WaitForChild("ServiceRegistry"), "ServiceRegistry")
local ServiceResolver = requireSafe(ServicesFolder:WaitForChild("Infrastructure"):WaitForChild("ServiceResolver"), "ServiceResolver")
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
local ItemService = requireSafe(ServicesFolder:WaitForChild("ItemService"), "ItemService")
local ShopService = requireSafe(ServicesFolder:WaitForChild("ShopService"), "ShopService")
local PetService = requireSafe(ServicesFolder:WaitForChild("PetService"):WaitForChild("PetService"), "PetService")
local LauncherInventoryService = requireSafe(ServicesFolder:WaitForChild("LauncherInventoryService"), "LauncherInventoryService")
local PetAbilityService = requireSafe(ServicesFolder:WaitForChild("PetAbilityService"):WaitForChild("PetAbilityService"), "PetAbilityService")
local ProgressPointService = requireSafe(ServicesFolder:WaitForChild("ProgressPointService"), "ProgressPointService")
local QuestService = requireSafe(ServicesFolder:WaitForChild("QuestService"), "QuestService")
local NotificationService = requireSafe(ServicesFolder:WaitForChild("NotificationService"), "NotificationService")
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

local phaseRuns: { [string]: boolean } = {}

local function runServicePhase(serviceName: string, phase: "Init" | "Start")
	local phaseKey = serviceName .. ":" .. phase
	if phaseRuns[phaseKey] then
		error(string.format("[Bootstrap CRITICAL] Duplicate %s phase call for %s.", phase, serviceName), 0)
	end

	local service = ServiceResolver.Get(context, serviceName)
	if not service then
		error(string.format("[Bootstrap CRITICAL] Missing service %s during %s phase.", serviceName, phase), 0)
	end

	local phaseMethod = service[phase]
	if typeof(phaseMethod) ~= "function" then
		phaseRuns[phaseKey] = true
		return
	end

	local ok, err = xpcall(function()
		phaseMethod(service)
	end, debug.traceback)
	if not ok then
		error(string.format("[Bootstrap CRITICAL] %s:%s failed; startup aborted: %s", serviceName, phase, tostring(err)), 0)
	end
	phaseRuns[phaseKey] = true
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
	ItemService = ItemService,
	ShopService = ShopService,
	PetService = PetService,
	LauncherInventoryService = LauncherInventoryService,
	PetAbilityService = PetAbilityService,
	ProgressPointService = ProgressPointService,
	QuestService = QuestService,
	NotificationService = NotificationService,
}

for serviceName, constructor in pairs(serviceConstructors) do
	if not constructor or typeof(constructor.new) ~= "function" then
		error(string.format("[Bootstrap CRITICAL] Missing constructor for service %s.", serviceName), 0)
	end

	local ok, service = xpcall(function()
		return constructor.new(context)
	end, debug.traceback)
	if not ok or not service then
		error(string.format("[Bootstrap CRITICAL] Failed to construct service %s; startup aborted: %s", serviceName, tostring(service)), 0)
	end

	context.Services[serviceName] = service
	if context.ServiceRegistry then
		context.ServiceRegistry:Register(serviceName, service)
	end
end

local initializationOrder = {
	"RateLimiter",
	"PlayerDataService",
	"PlayerStateService",
	"ItemService",
	"ShopService",
	"PetService",
	"PetAbilityService",
	"FlagService",
	"TeamService",
	"MapService",
	"PlayerService",
	"FoodService",
	"LauncherService",
	"LauncherInventoryService",
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
	"QuestService",
	"NotificationService",
	"RoundService",
}

for _, serviceName in ipairs(initializationOrder) do
	runServicePhase(serviceName, "Init")
end

for _, serviceName in ipairs(initializationOrder) do
	runServicePhase(serviceName, "Start")
end
