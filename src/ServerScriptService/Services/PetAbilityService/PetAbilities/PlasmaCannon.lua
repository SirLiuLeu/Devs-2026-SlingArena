--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local CONFIG = {
	Cooldown = 10,
	ProjectileSpeed = 60,
	TargetRange = 120,
	Lifetime = 10,
	TargetScanInterval = 0.5,
}

local PlasmaCannon = {}

local function findTarget(context): (Player?, BasePart?)
	local playerService = context.PlayerService
	local stateService = context.PlayerStateService
	local attackerRoot = playerService and playerService:GetRoot(context.player)
	if not attackerRoot then return nil, nil end
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = CONFIG.TargetRange
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= context.player and not (context.TeamService and context.TeamService:IsFriendly(context.player, candidate))
			and stateService and not stateService:IsHuman(candidate) and not stateService:HasFlag(candidate, "Ghost") then
			local candidateRoot = playerService:GetRoot(candidate)
			if candidateRoot then
				local distance = (candidateRoot.Position - attackerRoot.Position).Magnitude
				if distance < bestDistance then bestPlayer, bestRoot, bestDistance = candidate, candidateRoot, distance end
			end
		end
	end
	return bestPlayer, bestRoot
end

local function getProjectilePart(projectile: Instance): BasePart?
	if projectile:IsA("BasePart") then return projectile end
	if projectile:IsA("Model") then
		if not projectile.PrimaryPart then
			local part = projectile:FindFirstChildWhichIsA("BasePart", true)
			if part then projectile.PrimaryPart = part end
		end
		return projectile.PrimaryPart
	end
	return nil
end

local function resolvePlayerFromHit(hit: BasePart, context): Player?
	local cursor: Instance? = hit
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") then
			local playerService = context.PlayerService
			local player = playerService and playerService:GetPlayerFromPawn(cursor)
			if not player then player = Players:GetPlayerFromCharacter(cursor) end
			if player then return player end
		end
		cursor = cursor.Parent
	end
	return nil
end

function PlasmaCannon.OnAbilityTrigger(context)
	local now = os.clock()
	if now < (context._nextAbilityAt or 0) then return end
	local stateService = context.PlayerStateService
	if not stateService or not stateService:IsLauncher(context.player) or stateService:HasFlag(context.player, "Ghost") then return end
	local target, targetRoot = findTarget(context)
	if not (target and targetRoot) then return end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local prefabs = assets and assets:FindFirstChild("Prefabs")
	local template = prefabs and prefabs:FindFirstChild("PlasmaBall")
	if not template then
		if not context._warnedMissingProjectile then
			warn("[PET_EFFECT][PlasmaCannon] ReplicatedStorage.Assets.Prefabs.PlasmaBall is missing; create the projectile model in Studio.")
			context._warnedMissingProjectile = true
		end
		return
	end
	local attackerRoot = context.PlayerService and context.PlayerService:GetRoot(context.player)
	if not attackerRoot then return end
	local projectile = template:Clone()
	local part = getProjectilePart(projectile)
	if not part then
		if not context._warnedInvalidProjectile then
			warn("[PET_EFFECT][PlasmaCannon] PlasmaBall must be a BasePart or Model containing a BasePart.")
			context._warnedInvalidProjectile = true
		end
		projectile:Destroy()
		return
	end
	for _, descendant in ipairs(if projectile:IsA("Model") then projectile:GetDescendants() else { projectile }) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanTouch = true
			descendant.CanQuery = true
			descendant.CanCollide = true
		end
	end
	local direction = (targetRoot.Position - attackerRoot.Position)
	if direction.Magnitude < 0.01 then direction = attackerRoot.CFrame.LookVector else direction = direction.Unit end
	local spawnCFrame = CFrame.lookAt(attackerRoot.Position + direction * 5 + Vector3.new(0, 1.5, 0), attackerRoot.Position + direction * 6)
	if projectile:IsA("Model") then projectile:PivotTo(spawnCFrame) else part.CFrame = spawnCFrame end
	projectile.Parent = Workspace
	pcall(function() part:SetNetworkOwner(nil) end)
	local projectileSpeed = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.projectileSpeed) or CONFIG.ProjectileSpeed
	part.AssemblyLinearVelocity = direction * projectileSpeed + Vector3.new(0, 4, 0)
	context._projectiles = context._projectiles or {}
	context._projectiles[projectile] = true
	local cooldown = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.cooldown) or CONFIG.Cooldown
	context._nextAbilityAt = now + cooldown
	print(string.format("[PET_ABILITY_ACTIVATED] player=%s pet=%s ability=PlasmaCannon target=%s cooldown=%.1fs", context.player.Name, tostring(context.definition and context.definition.PetId or "PlasmaCannon"), target.Name, cooldown))
	local hitConnection
	hitConnection = part.Touched:Connect(function(hit)
		if not hit or not hit.Parent or hit:IsDescendantOf(projectile) then return end
		local victim = resolvePlayerFromHit(hit, context)
		if not victim or victim == context.player then return end
		if context.TeamService and context.TeamService:IsFriendly(context.player, victim) then return end
		local damageService = context.DamagePipelineService
		local damage = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.damage) or 700
		if damageService then damageService:ApplyDamage(victim, damage, context.player, nil, { SourceType = "PetProjectile", SuppressKnockback = true }) end
		if hitConnection then hitConnection:Disconnect() end
		context._projectiles[projectile] = nil
		projectile:Destroy()
	end)
	Debris:AddItem(projectile, CONFIG.Lifetime)
	task.delay(CONFIG.Lifetime, function()
		if hitConnection then hitConnection:Disconnect() end
		if context._projectiles then context._projectiles[projectile] = nil end
	end)
end

function PlasmaCannon.OnTick(context, _dt: number)
	local now = os.clock()
	if now < (context._nextTargetScanAt or 0) then return end
	context._nextTargetScanAt = now + CONFIG.TargetScanInterval
	if now >= (context._nextAbilityAt or 0) then
		PlasmaCannon.OnAbilityTrigger(context)
	end
end

function PlasmaCannon.OnDestroy(context)
	for projectile in pairs(context._projectiles or {}) do
		if projectile and projectile.Parent then projectile:Destroy() end
	end
	table.clear(context._projectiles or {})
end

return PlasmaCannon
