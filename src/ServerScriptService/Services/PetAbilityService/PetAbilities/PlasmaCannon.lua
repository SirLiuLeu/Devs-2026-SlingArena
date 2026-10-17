--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

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

local function prepareServerProxy(projectile: Instance)
	for _, descendant in ipairs(projectile:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam")
			or descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") then
			descendant.Enabled = false
		elseif descendant:IsA("BillboardGui") or descendant:IsA("SurfaceGui") then
			descendant.Enabled = false
		end
	end
	if projectile:IsA("BasePart") then
		projectile.Anchored = true
		projectile.CanCollide = false
		projectile.CanTouch = false
		projectile.CanQuery = false
		projectile.Transparency = 1
	end
end

local function candidatePawns(context): { Instance }
	local result = {}
	local stateService = context.PlayerStateService
	local playerService = context.PlayerService
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= context.player and stateService
			and not stateService:IsHuman(candidate)
			and not stateService:HasFlag(candidate, "Ghost")
			and not (context.TeamService and context.TeamService:IsFriendly(context.player, candidate)) then
			local pawn = playerService and playerService:GetPawn(candidate)
			if pawn and pawn.Parent then table.insert(result, pawn) end
		end
	end
	return result
end

local function resolvePlayerFromHit(hit: BasePart, context): Player?
	local cursor: Instance? = hit
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") then
			local player = context.PlayerService and context.PlayerService:GetPlayerFromPawn(cursor)
			if not player then player = Players:GetPlayerFromCharacter(cursor) end
			if player then return player end
		end
		cursor = cursor.Parent
	end
	return nil
end

local function moveProxy(projectile: Instance, part: BasePart, position: Vector3, velocity: Vector3)
	local facing = if velocity.Magnitude > 0.01 then velocity.Unit else Vector3.zAxis
	local cf = CFrame.lookAt(position, position + facing)
	if projectile:IsA("Model") then projectile:PivotTo(cf) else part.CFrame = cf end
end

local function endProjectile(context, projectile: Instance, data: any)
	local remote = context.Remotes and context.Remotes:FindFirstChild("PetProjectileVisual")
	if remote and remote:IsA("RemoteEvent") then remote:FireAllClients("End", data.id) end
	if context._projectiles then context._projectiles[projectile] = nil end
	if projectile.Parent then projectile:Destroy() end
end

local function spawnVisual(context, data: any)
	local remote = context.Remotes and context.Remotes:FindFirstChild("PetProjectileVisual")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients("Spawn", {
			id = data.id,
			projectileType = "PlasmaCannon",
			origin = data.position,
			velocity = data.velocity,
			speed = data.speed,
			targetUserId = data.targetUserId,
			spawnServerTime = data.spawnServerTime,
			lifetime = CONFIG.Lifetime,
		})
	else
		warn("[PET_PROJECTILE] LauncherArenaRemotes.PetProjectileVisual missing; create the RemoteEvent through Rojo.")
	end
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
	local direction = targetRoot.Position - attackerRoot.Position
	if direction.Magnitude < 0.01 then direction = attackerRoot.CFrame.LookVector else direction = direction.Unit end
	local spawnCFrame = CFrame.lookAt(attackerRoot.Position + direction * 5 + Vector3.new(0, 1.5, 0), attackerRoot.Position + direction * 6)
	if projectile:IsA("Model") then projectile:PivotTo(spawnCFrame) else part.CFrame = spawnCFrame end
	local radius = math.clamp(math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5, 0.5, 3)
	prepareServerProxy(projectile)
	projectile.Parent = ServerStorage

	local speed = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.projectileSpeed) or CONFIG.ProjectileSpeed
	local initialVelocity = direction * speed + Vector3.new(0, 4, 0)
	local data = {
		id = HttpService:GenerateGUID(false),
		part = part,
		position = spawnCFrame.Position,
		velocity = initialVelocity,
		speed = speed,
		radius = radius,
		expiresAt = now + CONFIG.Lifetime,
		spawnServerTime = Workspace:GetServerTimeNow(),
		targetUserId = target.UserId,
	}
	context._projectiles = context._projectiles or {}
	context._projectiles[projectile] = data
	local cooldown = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.cooldown) or CONFIG.Cooldown
	context._nextAbilityAt = now + cooldown
	print(string.format("[PET_ABILITY_ACTIVATED] player=%s pet=%s ability=PlasmaCannon target=%s cooldown=%.1fs", context.player.Name, tostring(context.definition and context.definition.PetId or "PlasmaCannon"), target.Name, cooldown))
	spawnVisual(context, data)
end

function PlasmaCannon.OnTick(context, dt: number)
	local now = os.clock()
	if now >= (context._nextTargetScanAt or 0) then
		context._nextTargetScanAt = now + CONFIG.TargetScanInterval
		if now >= (context._nextAbilityAt or 0) then PlasmaCannon.OnAbilityTrigger(context) end
	end

	for projectile, data in pairs(context._projectiles or {}) do
		if not (projectile and projectile.Parent and data.part and data.part.Parent) then
			context._projectiles[projectile] = nil
			continue
		end
		if now >= data.expiresAt then endProjectile(context, projectile, data); continue end
		local gravity = Vector3.new(0, -Workspace.Gravity, 0)
		local nextPosition = data.position + data.velocity * dt + gravity * (0.5 * dt * dt)
		local displacement = nextPosition - data.position
		if displacement.Magnitude > 0.001 then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = candidatePawns(context)
			params.IgnoreWater = true
			local ok, result = pcall(function() return Workspace:Spherecast(data.position, data.radius, displacement, params) end)
			local victim = if ok and result then resolvePlayerFromHit(result.Instance, context) else nil
			if victim and victim ~= context.player and not (context.TeamService and context.TeamService:IsFriendly(context.player, victim)) then
				local damage = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.damage) or 700
				local damageService = context.DamagePipelineService
				if damageService then damageService:ApplyDamage(victim, damage, context.player, nil, { SourceType = "PetProjectile", SuppressKnockback = true }) end
				endProjectile(context, projectile, data)
				continue
			end
		end
		data.position = nextPosition
		data.velocity += gravity * dt
		moveProxy(projectile, data.part, data.position, data.velocity)
	end
end

function PlasmaCannon.OnDestroy(context)
	for projectile, data in pairs(context._projectiles or {}) do
		if projectile and projectile.Parent then endProjectile(context, projectile, data) end
	end
	table.clear(context._projectiles or {})
end

return PlasmaCannon
