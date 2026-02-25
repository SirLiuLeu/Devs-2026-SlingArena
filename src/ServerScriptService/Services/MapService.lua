--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)

local MapService = {}
MapService.__index = MapService

type Context = {
	Services: any,
	EventBus: any,
}

function MapService.new(context: Context)
	local self = setmetatable({}, MapService)
	self._context = context
	self._zonesFolder = Workspace:FindFirstChild("ArenaZones") :: Folder
	if not self._zonesFolder then
		self._zonesFolder = Instance.new("Folder")
		self._zonesFolder.Name = "ArenaZones"
		self._zonesFolder.Parent = Workspace
	end
	return self
end

local function ensureZone(folder: Folder, name: string, position: Vector3, size: Vector3, color: Color3): BasePart
	local zone = folder:FindFirstChild(name) :: BasePart
	if not zone then
		zone = Instance.new("Part")
		zone.Name = name
		zone.Anchored = true
		zone.Transparency = 0.7
		zone.Color = color
		zone.CanCollide = false
		zone.Parent = folder
	end
	zone.Position = position
	zone.Size = size
	return zone
end

function MapService:Init()
	local safeZone = ensureZone(self._zonesFolder, "SafeZone", Vector3.new(0, 4, 0), Vector3.new(30, 8, 30), Color3.fromRGB(64, 196, 255))
	local antiGiantZone = ensureZone(self._zonesFolder, "AntiGiantZone", Vector3.new(60, 4, 0), Vector3.new(24, 8, 24), Color3.fromRGB(255, 163, 64))
	local corridor = ensureZone(self._zonesFolder, "SizeRestrictedCorridor", Vector3.new(-60, 4, 0), Vector3.new(20, 8, 80), Color3.fromRGB(218, 64, 255))

	safeZone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			self._context.Services.PlayerStateService:MarkInvulnerable(player, 0.2)
		end
	end)

	antiGiantZone.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local state = self._context.Services.PlayerStateService:GetState(player)
		if state and state.Size > BalanceConfig.AntiGiantSizeLimit then
			self._context.Services.PlayerStateService:ApplyDamage(player, 4)
		end
	end)

	corridor.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local state = self._context.Services.PlayerStateService:GetState(player)
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart
		if state and root and state.Size > BalanceConfig.CorridorSizeLimit then
			root.AssemblyLinearVelocity = -root.CFrame.LookVector * 35
		end
	end)
end

return MapService
