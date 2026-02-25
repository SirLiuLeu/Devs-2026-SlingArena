--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServicesFolder = script.Parent:WaitForChild("Services")

local EventBus = require(ServicesFolder.EventBus)
local PlayerStateService = require(ServicesFolder.PlayerStateService)
local GrowthService = require(ServicesFolder.GrowthService)
local SlingshotService = require(ServicesFolder.SlingshotService)
local CollisionService = require(ServicesFolder.CollisionService)
local CombatService = require(ServicesFolder.CombatService)
local SkillService = require(ServicesFolder.SkillService)
local MonetizationService = require(ServicesFolder.MonetizationService)
local MapService = require(ServicesFolder.MapService)

local remotesFolder = ReplicatedStorage:FindFirstChild("SlingArenaRemotes") :: Folder
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "SlingArenaRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name: string): RemoteEvent
	local remote = remotesFolder:FindFirstChild(name) :: RemoteEvent
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end
	return remote
end

ensureRemote("StartCharge")
ensureRemote("ReleaseCharge")
ensureRemote("SpendAttribute")
ensureRemote("PurchaseRespawn")
ensureRemote("PurchaseMatchBuff")
ensureRemote("PrestigeReset")
ensureRemote("ToggleSpecialUpgrade")
ensureRemote("StateUpdate")

local eventBus = EventBus.new()

local context = {
	EventBus = eventBus,
	Remotes = remotesFolder,
	Services = {},
}

context.Services.PlayerStateService = PlayerStateService.new(context)
context.Services.GrowthService = GrowthService.new(context)
context.Services.SlingshotService = SlingshotService.new(context)
context.Services.CollisionService = CollisionService.new(context)
context.Services.CombatService = CombatService.new(context)
context.Services.SkillService = SkillService.new(context)
context.Services.MonetizationService = MonetizationService.new(context)
context.Services.MapService = MapService.new(context)

context.Services.PlayerStateService:Init()
context.Services.GrowthService:Init()
context.Services.SlingshotService:Init()
context.Services.CollisionService:Init()
context.Services.CombatService:Init()
context.Services.SkillService:Init()
context.Services.MonetizationService:Init()
context.Services.MapService:Init()

eventBus:On("PlayerDied", function(player: Player)
	task.delay(3, function()
		context.Services.MonetizationService:HandleFreeRespawn(player)
	end)
end)
