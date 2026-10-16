--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local EffectUtil = require(script.Parent.EffectUtil)

local ProjectileUtil = {}

function ProjectileUtil.GetRoot(context: any, player: Player): BasePart?
	local playerService = context.PlayerService
	if playerService and typeof(playerService.GetRoot) == "function" then
		local root = playerService:GetRoot(player)
		if root and root:IsA("BasePart") then return root end
	end
	local character = player.Character
	local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
	return if root and root:IsA("BasePart") then root else nil
end

function ProjectileUtil.FindNearestEnemy(context: any, maxRange: number): (Player?, BasePart?)
	local ownerRoot = ProjectileUtil.GetRoot(context, context.player)
	if not ownerRoot then return nil, nil end

	local nearestPlayer: Player? = nil
	local nearestRoot: BasePart? = nil
	local nearestDistance = math.max(0, maxRange)
	local stateService = context.PlayerStateService
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= context.player and EffectUtil.CanAffectPlayers(context, context.player, candidate) then
			local state = stateService and stateService:GetState(candidate)
			if state and state.IsAlive ~= false and (tonumber(state.CurrentHP) == nil or state.CurrentHP > 0) then
				local candidateRoot = ProjectileUtil.GetRoot(context, candidate)
				if candidateRoot then
					local distance = (candidateRoot.Position - ownerRoot.Position).Magnitude
					if distance <= nearestDistance then
						nearestPlayer = candidate
						nearestRoot = candidateRoot
						nearestDistance = distance
					end
				end
			end
		end
	end
	return nearestPlayer, nearestRoot
end

function ProjectileUtil.ResolvePlayerFromPart(context: any, part: Instance): Player?
	local current: Instance? = part
	local playerService = context.PlayerService
	while current do
		if current:IsA("Model") then
			if playerService and typeof(playerService.GetPlayerFromPawn) == "function" then
				local player = playerService:GetPlayerFromPawn(current)
				if player then return player end
			end
			local characterPlayer = Players:GetPlayerFromCharacter(current)
			if characterPlayer then return characterPlayer end
		end
		current = current.Parent
	end
	return nil
end

function ProjectileUtil.ClonePrefab(prefabName: string, position: Vector3, direction: Vector3, options: any): (Model?, BasePart?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local prefabs = assets and assets:FindFirstChild("Prefabs")
	local source = prefabs and prefabs:FindFirstChild(prefabName)
	if not (source and source:IsA("Model")) then
		warn(string.format("[PET_PROJECTILE] Missing ReplicatedStorage.Assets.Prefabs.%s (Model). Add it manually in Studio/Rojo.", prefabName))
		return nil, nil
	end

	local projectile = source:Clone()
	local root = projectile.PrimaryPart or projectile:FindFirstChildWhichIsA("BasePart", true)
	if not (root and root:IsA("BasePart")) then
		warn(string.format("[PET_PROJECTILE] Prefab %s contains no BasePart; projectile was discarded.", prefabName))
		projectile:Destroy()
		return nil, nil
	end
	projectile.PrimaryPart = root
	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = options.Anchored == true
			descendant.CanCollide = options.CanCollide == true
			descendant.CanTouch = options.CanTouch == true
			descendant.CanQuery = true
			descendant.Massless = options.Anchored == true
		end
	end

	local lookDirection = if direction.Magnitude > 0.001 then direction.Unit else Vector3.zAxis
	projectile:PivotTo(CFrame.lookAt(position, position + lookDirection))
	projectile.Parent = Workspace
	if options.Anchored ~= true then
		pcall(function() root:SetNetworkOwner(nil) end)
	end
	return projectile, root
end

return ProjectileUtil
