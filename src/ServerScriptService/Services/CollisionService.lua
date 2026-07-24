--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local VelocityDecay = require(ReplicatedStorage.Shared.Utils.VelocityDecay)

local CollisionService = {}
CollisionService.__index = CollisionService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local SAME_TARGET_DEDUPE_SECONDS = 0.28
local MAX_REPORT_AGE_SECONDS = 0.75
local MAX_REPORT_FUTURE_SECONDS = 0.15

local function isLauncherMovementControlling(root: BasePart): boolean
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	return linearVelocity ~= nil and linearVelocity:IsA("LinearVelocity") and linearVelocity.Enabled
end

function CollisionService.new(context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._lastCollision = {}
	self._lastCollisionByLaunchTarget = {}
	self._lastWallCollision = {}
	return self
end

function CollisionService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_applyDragAndBounce(dt)
	end)
	self:_bindClientCollisionReports()
end

function CollisionService:_applyDragAndBounce(dt: number)
	local playerService = getService(self._context, "PlayerService")
	if not playerService then
		return
	end

	for _, player in Players:GetPlayers() do
		local root = playerService:GetRoot(player)
		if not (root and playerService:IsAlive(player)) then
			continue
		end

		local stateService = getService(self._context, "PlayerStateService")
		if stateService and stateService.IsHuman and stateService:IsHuman(player) then
			continue
		end
		local playerState = stateService and stateService:GetState(player)
		local movementState = playerState and playerState.MovementState
		local isLaunching = movementState == "Launching"
		local isNormalLocomotion = movementState == "Moving" or movementState == "Idle"

		if isNormalLocomotion or isLauncherMovementControlling(root) then
			continue
		end

		local velocity = root.AssemblyLinearVelocity
		local pos = root.Position
		local arenaLimit = PhysicsConfig.World.MaxArenaRadius - PhysicsConfig.World.ArenaWallPadding
		local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

		-- Wall bounce only applies while locomotion is not actively controlling velocity.
		local hitWall = false
		if math.abs(pos.X) > arenaLimit then
			horizontal = Vector3.new(
				-horizontal.X * PhysicsConfig.World.WallRestitution,
				0,
				horizontal.Z * PhysicsConfig.World.WallTangentialDamping
			)
			hitWall = true
		end
		if math.abs(pos.Z) > arenaLimit then
			horizontal = Vector3.new(
				horizontal.X * PhysicsConfig.World.WallTangentialDamping,
				0,
				-horizontal.Z * PhysicsConfig.World.WallRestitution
			)
			hitWall = true
		end
		if hitWall then
			local now = os.clock()
			if not self._lastWallCollision[player]
				or now - self._lastWallCollision[player] >= PhysicsConfig.World.WallCollisionCooldown
			then
				self._lastWallCollision[player] = now
				root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
				self._context.EventBus:Fire("CollisionDetected", "Wall", player, nil,
					{ Speed = horizontal.Magnitude })
			end
			continue
		end

		-- Launching players remain client-owned; only uncontrolled movement gets server drag.
		if isLaunching then
			continue
		end

		-- Drag is reserved for physics-driven states after locomotion releases velocity control.
		local dragFactor = math.max(0, 1 - (PhysicsConfig.World.LinearDragPerSecond * dt))
		horizontal = horizontal * dragFactor
		if horizontal.Magnitude < PhysicsConfig.World.StopSpeed then
			horizontal = Vector3.zero
		end
		root.AssemblyLinearVelocity = Vector3.new(horizontal.X, velocity.Y, horizontal.Z)
	end
end

local function getCollisionKey(playerA: Player, playerB: Player): string
	return if playerA.UserId < playerB.UserId
		then `{playerA.UserId}:{playerB.UserId}`
		else `{playerB.UserId}:{playerA.UserId}`
end

local function getHorizontalVelocity(root: BasePart): Vector3
	local velocity = root.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z)
end

local function playerName(player: Player?): string
	return player and player.Name or "nil"
end

local function collisionLog(message: string)
	print(`[Collision] {message}`)
end


local function resolveImpactVelocity(_root: BasePart, launchState: any): Vector3
	local direction = if typeof(launchState.direction) == "Vector3" then Vector3.new(launchState.direction.X, 0, launchState.direction.Z) else Vector3.zero
	local launchSpeed = math.max(launchState.currentSpeed or 0, launchState.initialSpeed or 0)
	if direction.Magnitude < 0.001 or launchSpeed <= 0 then
		return Vector3.zero
	end
	return direction.Unit * math.min(launchSpeed, PhysicsConfig.Collision.MaxAllowedSpeed)
end

local function updateLaunchFromVelocity(launchState, velocity: Vector3, energy: number, now: number)
	local speed = velocity.Magnitude
	if speed <= PhysicsConfig.Collision.MinPostCollisionSpeed or energy <= 0 then
		launchState.direction = Vector3.zero
		launchState.initialSpeed = 0
		launchState.currentSpeed = 0
		launchState.energy = 0
		launchState.startTime = now
		launchState.lastSampleTime = now
		return
	end
	launchState.direction = velocity.Unit
	launchState.initialSpeed = speed
	launchState.currentSpeed = speed
	launchState.energy = energy
	launchState.startTime = now
	launchState.lastSampleTime = now
end


function CollisionService:_validatePlayerReport(
	player: Player, payload: any
): (boolean, Player?, BasePart?, BasePart?, Vector3, string)
	local playerService = getService(self._context, "PlayerService")
	local stateService = getService(self._context, "PlayerStateService")
	if not (playerService and stateService) then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), "missing PlayerService or PlayerStateService"
	end

	if typeof(payload.clientTimestamp) ~= "number" or typeof(payload.hitPosition) ~= "Vector3" then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), "invalid clientTimestamp or hitPosition"
	end
	local now = os.clock()
	if payload.clientTimestamp > now + MAX_REPORT_FUTURE_SECONDS or now - payload.clientTimestamp > MAX_REPORT_AGE_SECONDS then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), `stale or future report: now={now} clientTimestamp={payload.clientTimestamp}`
	end

	local defender = Players:GetPlayerByUserId(payload.targetUserId)
	local root = playerService:GetRoot(player)
	local targetRoot = defender and playerService:GetRoot(defender)
	local attackerState = stateService:GetState(player)
	local defenderState = defender and stateService:GetState(defender)

	if not (defender and defender ~= player and root and targetRoot and attackerState and defenderState
		and attackerState.MovementState == "Launching" and defenderState.MovementState == "Launching")
	then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), `invalid participants or states: defender={playerName(defender)} attackerState={attackerState and attackerState.MovementState or "nil"} defenderState={defenderState and defenderState.MovementState or "nil"}`
	end

	if not (playerService:IsAlive(player) and playerService:IsAlive(defender)) then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), `dead participant: attackerAlive={playerService:IsAlive(player)} defenderAlive={defender and playerService:IsAlive(defender) or false}`
	end

	local hitOffset = Vector3.new(payload.hitPosition.X, 0, payload.hitPosition.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)
	local targetHitOffset = Vector3.new(payload.hitPosition.X, 0, payload.hitPosition.Z) - Vector3.new(targetRoot.Position.X, 0, targetRoot.Position.Z)
	local maxHitDistance = PhysicsConfig.Collision.ValidationTolerance + (math.max(root.Size.X, root.Size.Z, targetRoot.Size.X, targetRoot.Size.Z) * 0.5)
	if hitOffset.Magnitude > maxHitDistance or targetHitOffset.Magnitude > maxHitDistance then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), `hitPosition outside tolerance: attackerOffset={hitOffset.Magnitude} defenderOffset={targetHitOffset.Magnitude} max={maxHitDistance}`
	end

	local offset = targetRoot.Position - root.Position
	local planar = Vector3.new(offset.X, 0, offset.Z)
	local combinedRadius = (math.max(root.Size.X, root.Size.Z) + math.max(targetRoot.Size.X, targetRoot.Size.Z)) * 0.5
	local maxDistance = combinedRadius + PhysicsConfig.Collision.ValidationTolerance
	if planar.Magnitude > maxDistance or math.abs(root.Position.Y - targetRoot.Position.Y) > PhysicsConfig.Collision.YTolerance then
		return false, nil, nil, nil, Vector3.new(1, 0, 0), `players outside collision tolerance: planarDistance={planar.Magnitude} maxDistance={maxDistance} yDelta={math.abs(root.Position.Y - targetRoot.Position.Y)}`
	end
	local normal = if planar.Magnitude > PhysicsConfig.Movement.InputDeadzone
		then planar.Unit
		else Vector3.new(1, 0, 0)

	return true, defender, root, targetRoot, normal, "ok"
end

function CollisionService:_resolveClientPlayerHit(player: Player, payload: any)
	collisionLog(`enter _resolveClientPlayerHit attacker={playerName(player)} targetUserId={payload.targetUserId} launchId={payload.launchId or "nil"}`)
	local ok, defender, root, targetRoot, normal, validationReason = self:_validatePlayerReport(player, payload)
	collisionLog(`_validatePlayerReport result ok={ok} attacker={playerName(player)} defender={playerName(defender)} reason={validationReason}`)
	if not (ok and defender and root and targetRoot) then
		collisionLog(`return: validation failed attacker={playerName(player)} targetUserId={payload.targetUserId} reason={validationReason}`)
		return
	end
	local key = getCollisionKey(player, defender)
	local now = os.clock()

	local launcherService = getService(self._context, "LauncherService")
	local stateService = getService(self._context, "PlayerStateService")
	if not (launcherService and stateService) then
		collisionLog(`return: missing service launcherService={launcherService ~= nil} stateService={stateService ~= nil} attacker={playerName(player)} defender={playerName(defender)}`)
		return
	end
	if (stateService.IsHuman and stateService:IsHuman(player)) or stateService.HasFlag and (
		stateService:HasFlag(player, "Ghost") or stateService:HasFlag(defender, "Ghost")
	) then
		collisionLog(`return: attacker human or ghost flag attacker={playerName(player)} defender={playerName(defender)} attackerIsHuman={stateService.IsHuman and stateService:IsHuman(player) or false} attackerGhost={stateService.HasFlag and stateService:HasFlag(player, "Ghost") or false} defenderGhost={stateService.HasFlag and stateService:HasFlag(defender, "Ghost") or false}`)
		return
	end
	local launchState = launcherService:GetLaunchState(player)
	collisionLog(`LaunchState lookup attacker={playerName(player)} defender={playerName(defender)} exists={launchState ~= nil}`)
	if not launchState then
		collisionLog(`return: missing LaunchState attacker={playerName(player)} defender={playerName(defender)}`)
		return
	end
	local launchId = launchState.launchId
	collisionLog(`LaunchId validation attacker={playerName(player)} defender={playerName(defender)} launchId={tostring(launchId)} valid={type(launchId) == "string" and launchId ~= ""}`)
	if type(launchId) ~= "string" or launchId == "" then
		collisionLog(`return: invalid launchId attacker={playerName(player)} defender={playerName(defender)} launchId={tostring(launchId)}`)
		return
	end
	self._lastCollisionByLaunchTarget[launchId] = self._lastCollisionByLaunchTarget[launchId] or {}
	local launchTargetKey = `Player:{defender.UserId}`
	local lastHitAt = self._lastCollisionByLaunchTarget[launchId][launchTargetKey]
	if lastHitAt and (now - lastHitAt) < SAME_TARGET_DEDUPE_SECONDS then
		collisionLog(`return: duplicate launch target attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} elapsed={now - lastHitAt} threshold={SAME_TARGET_DEDUPE_SECONDS}`)
		return
	end
	local attackerVelocity = resolveImpactVelocity(root, launchState)
	local defenderVelocity = getHorizontalVelocity(targetRoot)
	local collisionResult = VelocityDecay.ResolvePlayerCollision(attackerVelocity, defenderVelocity, normal)
	local impactSpeed = collisionResult.ClosingSpeed
	collisionLog(`Impact velocity resolved attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} attackerSpeed={attackerVelocity.Magnitude} defenderSpeed={defenderVelocity.Magnitude} closingSpeed={impactSpeed} normalSpeed={collisionResult.NormalSpeed} angleFactor={collisionResult.AngleFactor}`)
	if impactSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
		collisionLog(`return: closingSpeed below minimum attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} closingSpeed={impactSpeed} min={PhysicsConfig.Collision.RealHitMinClosingSpeed}`)
		return
	end
	if self._lastCollision[key] and now - self._lastCollision[key] < PhysicsConfig.Collision.Cooldown then
		collisionLog(`return: collision cooldown attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} elapsed={now - self._lastCollision[key]} cooldown={PhysicsConfig.Collision.Cooldown}`)
		return
	end
	self._lastCollision[key] = now
	self._lastCollisionByLaunchTarget[launchId][launchTargetKey] = now

	local attackerAbsoluteSpeed = attackerVelocity.Magnitude
	local defenderOutRaw = collisionResult.DefenderVelocity
	local defenderOutRawSpeed = defenderOutRaw.Magnitude
	local maxDefenderOutSpeed = attackerAbsoluteSpeed * PhysicsConfig.Collision.DefenderVelocityTransferScale
	local defenderOut = if defenderOutRawSpeed <= maxDefenderOutSpeed
		then defenderOutRaw
		elseif maxDefenderOutSpeed <= 0
		then Vector3.zero
		else defenderOutRaw.Unit * maxDefenderOutSpeed
	local attackerOut = collisionResult.AttackerVelocity

	local canDamage = launcherService:RegisterLaunchDamageTarget(player, launchTargetKey)
	collisionLog(`RegisterLaunchDamageTarget result attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} targetKey={launchTargetKey} canDamage={canDamage}`)
	local canKnockback = launcherService:RegisterLaunchKnockbackTarget(player, launchTargetKey)
	collisionLog(`RegisterLaunchKnockbackTarget result attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} targetKey={launchTargetKey} canKnockback={canKnockback}`)
	if not canDamage and not canKnockback then
		collisionLog(`return: launch target already processed for damage and knockback attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} targetKey={launchTargetKey}`)
		return
	end
	if canKnockback then
		updateLaunchFromVelocity(
			launchState,
			attackerOut,
			math.max(0, (launchState.energy or 0) * collisionResult.RemainingEnergyScale),
			now
		)
	end
	launchState.collisions = (launchState.collisions or 0) + 1

	local transferEnergy = math.max(0, (launchState.energy or 0) * collisionResult.TransferredEnergyScale)
	local shouldKnockback = canKnockback
		and transferEnergy >= PhysicsConfig.Collision.MinTransferEnergy
		and defenderOut.Magnitude > PhysicsConfig.Collision.MinPostCollisionSpeed
	local damagePreview = 0
	local damageService = getService(self._context, "DamagePipelineService")
	local attackerState = stateService:GetState(player)
	if damageService and typeof(damageService.ComputeCollisionDamage) == "function" and attackerState then
		damagePreview = damageService:ComputeCollisionDamage(attackerState, impactSpeed, {
			SourceType = "PhysicalLauncherCollision",
			InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			CollisionCount = launchState.collisions,
			LaunchEnergy = launchState.energy,
			ChargeRatio = launchState.chargeRatio or 0,
			ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
		})
	end
	collisionLog(`Damage preview attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} damagePreview={damagePreview} canDamage={canDamage} canKnockback={canKnockback} collisionCount={launchState.collisions} transferredEnergy={transferEnergy} shouldKnockback={shouldKnockback}`)
	local selfBounceRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ApplySelfBounce)
	if selfBounceRemote and selfBounceRemote:IsA("RemoteEvent") then
		selfBounceRemote:FireClient(player, attackerOut)
	end
	local knockbackRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ApplyKnockback)
	if shouldKnockback and knockbackRemote and knockbackRemote:IsA("RemoteEvent") then
		knockbackRemote:FireClient(defender, defenderOut, damagePreview)
	end
	if shouldKnockback then
		stateService:SetMovementState(defender, "Knockback")
		task.delay(PhysicsConfig.Collision.KnockbackImpulseDuration, function()
			local defenderState = stateService:GetState(defender)
			if defenderState and defenderState.MovementState == "Knockback" then
				stateService:SetMovementState(defender, "Idle")
			end
		end)
	end

	collisionLog(`firing CollisionDetected attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} impactSpeed={impactSpeed} collisionCount={launchState.collisions}`)
	self._context.EventBus:Fire("CollisionDetected", "Launcher", player, defender, {
		Speed = impactSpeed,
		ImpactNormal = normal,
		AngleFactor = collisionResult.AngleFactor,
		NormalSpeed = collisionResult.NormalSpeed,
		TangentialSpeed = collisionResult.TangentialSpeed,
		LaunchEnergy = launchState.energy,
		AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
		CollisionCount = launchState.collisions,
		ChargeRatio = launchState.chargeRatio or 0,
		ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
	})
	if canDamage then
		collisionLog(`firing CollisionPlayerHit attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} impactSpeed={impactSpeed} damagePreview={damagePreview}`)
		self._context.EventBus:Fire("CollisionPlayerHit", defender, player, impactSpeed, normal, {
			SourceType = "PhysicalLauncherCollision",
			Duration = PhysicsConfig.Collision.KnockbackImpulseDuration,
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			AngleFactor = collisionResult.AngleFactor,
			NormalSpeed = collisionResult.NormalSpeed,
			TangentialSpeed = collisionResult.TangentialSpeed,
			InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			CollisionCount = launchState.collisions,
			LaunchEnergy = launchState.energy,
			ChargeRatio = launchState.chargeRatio or 0,
			ElapsedLaunchTime = math.max(0, now - (launchState.startTime or now)),
			TransferredEnergy = transferEnergy,
			TransferredVelocity = defenderOut.Magnitude,
			TransferredVelocityVector = defenderOut,
		})
	end
	if shouldKnockback then
		collisionLog(`firing CollisionPlayerKnockback attacker={playerName(player)} defender={playerName(defender)} launchId={launchId} transferredEnergy={transferEnergy} defenderOutSpeed={defenderOut.Magnitude}`)
		self._context.EventBus:Fire("CollisionPlayerKnockback", defender, player, defenderOut, {
			Duration = PhysicsConfig.Collision.KnockbackImpulseDuration,
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			AngleFactor = collisionResult.AngleFactor,
			NormalSpeed = collisionResult.NormalSpeed,
			TangentialSpeed = collisionResult.TangentialSpeed,
			InitialImpactSpeed = math.max(launchState.initialSpeed or 0, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			CollisionCount = launchState.collisions,
			TransferredEnergy = transferEnergy,
		})
	end
end


function CollisionService:_bindClientCollisionReports()
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ReportCollision)
	if not (remote and remote:IsA("RemoteEvent")) then
		collisionLog(`return: ReportCollision remote unavailable remoteExists={remote ~= nil}`)
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		collisionLog(`received ReportCollision remote attacker={playerName(player)} targetUserId={payload and payload.targetUserId or "nil"}`)
		if not RemoteContracts.Validate(RemoteContracts.Names.ReportCollision, payload) then
			collisionLog(`return: ReportCollision contract validation failed attacker={playerName(player)} targetUserId={payload and payload.targetUserId or "nil"}`)
			return
		end
		self:_resolveClientPlayerHit(player, payload)
	end)
end

return CollisionService
