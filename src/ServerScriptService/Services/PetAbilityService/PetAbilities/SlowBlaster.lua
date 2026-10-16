--!strict

local RunService = game:GetService("RunService")
local EffectUtil = require(script.Parent.EffectUtil)
local ProjectileUtil = require(script.Parent.ProjectileUtil)

local SlowBlaster = {}

local function removeProjectile(context: any, record: any)
	if record.cleaned then return end
	record.cleaned = true
	if record.heartbeat then record.heartbeat:Disconnect(); record.heartbeat = nil end
	if record.model and record.model.Parent then record.model:Destroy() end
	if context._activeProjectiles then context._activeProjectiles[record] = nil end
end

function SlowBlaster.OnInit(context: any)
	context._activeProjectiles = {}
end

function SlowBlaster.OnAbilityTrigger(context: any, _payload: any): boolean
	local params = context.progression and context.progression.abilityParams or {}
	local maxRange = math.clamp(tonumber(params.maxRange) or 120, 10, 120)
	local target, targetRoot = ProjectileUtil.FindNearestEnemy(context, maxRange)
	local ownerRoot = ProjectileUtil.GetRoot(context, context.player)
	if not (target and targetRoot and ownerRoot) then return false end

	local direction = targetRoot.Position - ownerRoot.Position
	if direction.Magnitude <= 0.001 then direction = ownerRoot.CFrame.LookVector end
	direction = direction.Unit
	local spawnPosition = ownerRoot.Position + direction * 4
	local model = ProjectileUtil.ClonePrefab("SlowBall", spawnPosition, direction, {
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
	})
	if not model then return false end

	local record = {
		model = model,
		connections = {},
		heartbeat = nil,
		cleaned = false,
		startedAt = os.clock(),
		startPosition = spawnPosition,
		target = target,
		speed = math.clamp(tonumber(params.projectileSpeed) or 15, 1, 60),
		lifetime = math.clamp(tonumber(params.lifetime) or 10, 1, 10),
		maxRange = maxRange,
		hitRadius = math.clamp(tonumber(params.hitRadius) or 4.5, 1, 10),
		slowDuration = math.clamp(tonumber(params.slowDuration) or 3, 0.1, 10),
	}
	context._activeProjectiles[record] = true

	record.heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent or os.clock() - record.startedAt >= record.lifetime then
			removeProjectile(context, record)
			return
		end
		if (model:GetPivot().Position - record.startPosition).Magnitude >= record.maxRange then
			removeProjectile(context, record)
			return
		end

		local targetRootNow = ProjectileUtil.GetRoot(context, record.target)
		if not targetRootNow or not EffectUtil.CanAffectPlayers(context, context.player, record.target) then
			removeProjectile(context, record)
			return
		end

		local currentPosition = model:GetPivot().Position
		local offset = targetRootNow.Position - currentPosition
		if offset.Magnitude <= record.hitRadius then
			local stateService = context.PlayerStateService
			if stateService then
				local flagConfig = EffectUtil.GetFlagConfig("Slow")
				stateService:ApplyFlag(record.target, "Slow", record.slowDuration, context.player, {
					Stackable = flagConfig.Stackable,
					MaxStack = flagConfig.MaxStack,
					SlowAmount = flagConfig.SlowAmount,
				})
				EffectUtil.BurnCCFeedback(context, record.target, "Slow", record.slowDuration)
			else
				warn("[SlowBlaster] PlayerStateService is missing; Slow could not be applied.")
			end
			removeProjectile(context, record)
			return
		end

		local step = math.min(record.speed * math.max(dt, 0), offset.Magnitude)
		local newPosition = currentPosition + offset.Unit * step
		model:PivotTo(CFrame.lookAt(newPosition, newPosition + offset.Unit))
	end)
	return true
end

function SlowBlaster.OnDestroy(context: any)
	local records = {}
	for record in pairs(context._activeProjectiles or {}) do table.insert(records, record) end
	for _, record in ipairs(records) do removeProjectile(context, record) end
end

return SlowBlaster
