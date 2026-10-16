--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local EffectUtil = require(script.Parent.EffectUtil)

local CONFIG = {
	Cooldown = 8,
	ProjectileSpeed = 15,
	TargetRange = 120,
	Lifetime = 10,
	SlowDuration = 3,
}

local SlowBlaster = {}

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

local function findTarget(context): (Player?, BasePart?)
	local playerService = context.PlayerService
	local stateService = context.PlayerStateService
	local attackerRoot = playerService and playerService:GetRoot(context.player)
	if not attackerRoot then return nil, nil end
	local bestPlayer, bestRoot, bestDistance = nil, nil, CONFIG.TargetRange
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= context.player and stateService and not stateService:IsHuman(candidate)
			and not stateService:HasFlag(candidate, "Ghost")
			and not (context.TeamService and context.TeamService:IsFriendly(context.player, candidate)) then
			local candidateRoot = playerService:GetRoot(candidate)
			if candidateRoot then
				local distance = (candidateRoot.Position - attackerRoot.Position).Magnitude
				if distance < bestDistance then bestPlayer, bestRoot, bestDistance = candidate, candidateRoot, distance end
			end
		end
	end
	return bestPlayer, bestRoot
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

function SlowBlaster.OnAbilityTrigger(context)
	local now = os.clock()
	if now < (context._nextAbilityAt or 0) then return end
	local stateService = context.PlayerStateService
	if not stateService or not stateService:IsLauncher(context.player) or stateService:HasFlag(context.player, "Ghost") then return end
	local target, targetRoot = findTarget(context)
	if not (target and targetRoot) then return end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local prefabs = assets and assets:FindFirstChild("Prefabs")
	local template = prefabs and prefabs:FindFirstChild("SlowBall")
	if not template then
		warn("[PET_EFFECT][SlowBlaster] ReplicatedStorage.Assets.Prefabs.SlowBall is missing; create the projectile model in Studio.")
		return
	end
	local attackerRoot = context.PlayerService and context.PlayerService:GetRoot(context.player)
	if not attackerRoot then return end
	local projectile = template:Clone()
	local part = getProjectilePart(projectile)
	if not part then
		warn("[PET_EFFECT][SlowBlaster] SlowBall must be a BasePart or Model containing a BasePart.")
		projectile:Destroy()
		return
	end
	for _, descendant in ipairs(if projectile:IsA("Model") then projectile:GetDescendants() else { projectile }) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanTouch = true
			descendant.CanQuery = true
			descendant.CanCollide = false
		end
	end
	local direction = targetRoot.Position - attackerRoot.Position
	if direction.Magnitude < 0.01 then direction = attackerRoot.CFrame.LookVector else direction = direction.Unit end
	local spawnCFrame = CFrame.lookAt(attackerRoot.Position + direction * 5 + Vector3.new(0, 1.5, 0), attackerRoot.Position + direction * 6)
	if projectile:IsA("Model") then projectile:PivotTo(spawnCFrame) else part.CFrame = spawnCFrame end
	projectile.Parent = Workspace
	pcall(function() part:SetNetworkOwner(nil) end)
	part.AssemblyLinearVelocity = direction * CONFIG.ProjectileSpeed
	context._projectiles = context._projectiles or {}
	context._projectiles[projectile] = { target = target, part = part }
	context._nextAbilityAt = now + CONFIG.Cooldown
	local finished = false
	local hitConnection
	local function finish(victim: Player?)
		if finished then return end
		finished = true
		if hitConnection then hitConnection:Disconnect() end
		if victim and victim ~= context.player and not (context.TeamService and context.TeamService:IsFriendly(context.player, victim))
			and EffectUtil.CanAffectPlayers(context, context.player, victim) then
			local duration = tonumber(context.progression and context.progression.abilityParams and context.progression.abilityParams.slowDuration) or CONFIG.SlowDuration
			stateService:ApplyFlag(victim, "Slow", duration, context.player, { SlowAmount = 0.25, Stackable = false, MaxStack = 1 })
			EffectUtil.BurnCCFeedback(context, victim, "Slow", duration)
		end
		if context._projectiles then context._projectiles[projectile] = nil end
		if projectile.Parent then projectile:Destroy() end
	end
	hitConnection = part.Touched:Connect(function(hit)
		if not hit or not hit.Parent or hit:IsDescendantOf(projectile) then return end
		local victim = resolvePlayerFromHit(hit, context)
		if victim and victim ~= context.player then finish(victim) end
	end)
	Debris:AddItem(projectile, CONFIG.Lifetime)
	context._projectiles[projectile].expiresAt = now + CONFIG.Lifetime
end

function SlowBlaster.OnTick(context, _dt: number)
	for projectile, data in pairs(context._projectiles or {}) do
		if not (projectile and projectile.Parent and data.part and data.part.Parent) then
			context._projectiles[projectile] = nil
			continue
		end
		if os.clock() >= (data.expiresAt or 0) then
			context._projectiles[projectile] = nil
			projectile:Destroy()
			continue
		end
		local target = data.target
		local targetRoot = target and context.PlayerService and context.PlayerService:GetRoot(target)
		if not targetRoot or not target.Parent or (context.TeamService and context.TeamService:IsFriendly(context.player, target)) then
			context._projectiles[projectile] = nil
			projectile:Destroy()
			continue
		end
		local direction = targetRoot.Position - data.part.Position
		if direction.Magnitude > 0.01 then data.part.AssemblyLinearVelocity = direction.Unit * CONFIG.ProjectileSpeed end
	end
end

function SlowBlaster.OnDestroy(context)
	for projectile in pairs(context._projectiles or {}) do
		if projectile and projectile.Parent then projectile:Destroy() end
	end
	table.clear(context._projectiles or {})
end

return SlowBlaster
