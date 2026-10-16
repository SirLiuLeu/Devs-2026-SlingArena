--!strict

local RunService = game:GetService("RunService")
local EffectUtil = require(script.Parent.EffectUtil)
local ProjectileUtil = require(script.Parent.ProjectileUtil)

local PlasmaCannon = {}

local function removeProjectile(context: any, record: any)
	if record.cleaned then return end
	record.cleaned = true
	for _, connection in ipairs(record.connections) do connection:Disconnect() end
	if record.heartbeat then record.heartbeat:Disconnect(); record.heartbeat = nil end
	if record.model and record.model.Parent then record.model:Destroy() end
	if context._activeProjectiles then context._activeProjectiles[record] = nil end
end

function PlasmaCannon.OnInit(context: any)
	context._activeProjectiles = {}
end

function PlasmaCannon.OnAbilityTrigger(context: any, _payload: any): boolean
	local params = context.progression and context.progression.abilityParams or {}
	local maxRange = math.clamp(tonumber(params.maxRange) or 120, 10, 120)
	local target, targetRoot = ProjectileUtil.FindNearestEnemy(context, maxRange)
	local ownerRoot = ProjectileUtil.GetRoot(context, context.player)
	if not (target and targetRoot and ownerRoot) then return false end

	local direction = targetRoot.Position - ownerRoot.Position
	if direction.Magnitude <= 0.001 then direction = ownerRoot.CFrame.LookVector end
	direction = direction.Unit
	local spawnPosition = ownerRoot.Position + direction * 4
	local model, root = ProjectileUtil.ClonePrefab("PlasmaBall", spawnPosition, direction, {
		Anchored = false,
		CanCollide = true,
		CanTouch = true,
	})
	if not (model and root) then return false end

	local record = {
		model = model,
		root = root,
		connections = {},
		heartbeat = nil,
		cleaned = false,
		hit = false,
		startedAt = os.clock(),
		startPosition = spawnPosition,
	}
	context._activeProjectiles[record] = true
	root.AssemblyLinearVelocity = direction * math.clamp(tonumber(params.projectileSpeed) or 60, 20, 100)
	local damage = math.max(0, tonumber(params.damage) or 700)
	local maxLifetime = math.clamp(tonumber(params.lifetime) or 10, 1, 10)

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(record.connections, descendant.Touched:Connect(function(otherPart)
				if record.hit or not otherPart or not otherPart.Parent then return end
				local victim = ProjectileUtil.ResolvePlayerFromPart(context, otherPart)
				if not victim then return end
				if victim == context.player and os.clock() - record.startedAt < 0.35 then return end
				if not EffectUtil.CanAffectPlayers(context, context.player, victim) then return end
				record.hit = true
				if context.DamagePipelineService then
					context.DamagePipelineService:ApplyHitDamage(victim, damage, context.player, direction, {
						SourceType = "PetProjectile",
					})
				else
					warn("[PlasmaCannon] DamagePipelineService is missing; projectile hit could not apply damage.")
				end
				removeProjectile(context, record)
			end))
		end
	end

	record.heartbeat = RunService.Heartbeat:Connect(function()
		if not model.Parent or not root.Parent then
			removeProjectile(context, record)
			return
		end
		local travelDistance = (root.Position - record.startPosition).Magnitude
		if os.clock() - record.startedAt >= maxLifetime or travelDistance >= maxRange then
			removeProjectile(context, record)
		end
	end)
	return true
end

function PlasmaCannon.OnDestroy(context: any)
	local records = {}
	for record in pairs(context._activeProjectiles or {}) do table.insert(records, record) end
	for _, record in ipairs(records) do removeProjectile(context, record) end
end

return PlasmaCannon
