--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)
local CollisionValidation = require(script.Parent.Helpers.CollisionValidation)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)

local CollisionService = {}
CollisionService.__index = CollisionService


local MAX_REPORT_AGE_SECONDS = PhysicsConfig.LagCompensation.MaxAcceptedLatencySeconds
local MAX_REPORT_FUTURE_SECONDS = PhysicsConfig.LagCompensation.FutureToleranceSeconds

local function isLauncherMovementControlling(root: BasePart): boolean
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	return linearVelocity ~= nil and linearVelocity:IsA("LinearVelocity") and linearVelocity.Enabled
end

function CollisionService.new(context)
	local self = setmetatable({}, CollisionService)
	self._context = context
	self._lastWallCollision = {}
	return self
end

function CollisionService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_applyDragAndBounce(dt)
	end)
	self:_bindClockSync()
	self:_bindClientCollisionReports()
end

function CollisionService:_bindClockSync()
	local requestRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ClockSyncRequest)
	local responseRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ClockSyncResponse)
	if not (requestRemote and requestRemote:IsA("RemoteEvent") and responseRemote and responseRemote:IsA("RemoteEvent")) then
		warn("[Validation Result] failure reason=clock_sync_remotes_unavailable")
		return
	end
	requestRemote.OnServerEvent:Connect(function(player, clientSendTime)
		if not RemoteContracts.Validate(RemoteContracts.Names.ClockSyncRequest, clientSendTime) then
			return
		end
		responseRemote:FireClient(player, {
			ClientSendTime = clientSendTime,
			ServerCurrentTime = os.clock(),
		})
	end)
end

function CollisionService:_applyDragAndBounce(dt: number)
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	if not playerService then
		return
	end

	for _, player in Players:GetPlayers() do
		local root = playerService:GetRoot(player)
		if not (root and playerService:IsAlive(player)) then
			continue
		end

		local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
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

local function logValidation(ok: boolean, reason: string)
	print(`[Validation Result] {if ok then "success" else "failure"} reason={reason}`)
end

function CollisionService:_validatePlayerReport(
	player: Player, payload: any
): CollisionValidation.ValidationResult
	if typeof(payload.timestamp) ~= "number" or typeof(payload.hitPosition) ~= "Vector3" then
		return { Ok = false, Reason = "invalid timestamp or hitPosition", Details = nil, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
	end

	local now = os.clock()
	if payload.timestamp > now + MAX_REPORT_FUTURE_SECONDS or now - payload.timestamp > MAX_REPORT_AGE_SECONDS then
		return { Ok = false, Reason = `stale or future report: now={now} timestamp={payload.timestamp}`, Details = nil, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
	end

	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local defender = Players:GetPlayerByUserId(payload.targetUserId)
	local targetRoot = defender and playerService and playerService:GetRoot(defender)
	if not (defender and targetRoot) then
		return { Ok = false, Reason = "missing defender root", Details = nil, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
	end
	return CollisionValidation.ValidateAttackerTarget(self._context, player, {
		Kind = "Player",
		Player = defender,
		Part = targetRoot,
		RadiusPadding = 0,
		RequiresLaunching = true,
	}, payload)
end

function CollisionService:_resolveClientPlayerHit(player: Player, payload: any)
	print(`[Server Received] attacker={playerName(player)} targetUserId={tostring(payload and payload.targetUserId)}`)
	local launcherService = ServiceResolver.Get(self._context, "LauncherService")
	local launchOk = false
	local launchReason = "missing_launcher_service"
	if launcherService and typeof(launcherService.ValidateLaunchReport) == "function" then
		local ok, _launchState, reason = launcherService:ValidateLaunchReport(player, payload)
		launchOk = ok
		launchReason = reason
	end
	if not launchOk then
		logValidation(false, launchReason)
		return
	end
	local validation = self:_validatePlayerReport(player, payload)
	local defender = validation.TargetPlayer
	local root = validation.Root
	local targetRoot = validation.TargetPart
	local normal = validation.Normal
	local reportedVelocity = validation.ReportVelocity
	if not (validation.Ok and defender and root and targetRoot) then
		logValidation(false, validation.Reason or "validation_failed")
		return
	end
	logValidation(true, "sweep_intersects_hitbox")
	local now = os.clock()
	local dedupeService = ServiceResolver.Get(self._context, "HitCooldownDedupe")
	local hitKey = `{payload.launchId}:{defender.UserId}`
	if dedupeService and not dedupeService:TryAcquire("LaunchPlayerHit", hitKey, math.max(PhysicsConfig.Launch.MaxLaunchDuration, PhysicsConfig.Collision.Cooldown), now) then
		logValidation(false, "duplicate_launch_target")
		return
	end
	local launcherService2 = ServiceResolver.Get(self._context, "LauncherService")
	if launcherService2 and not launcherService2:RegisterLaunchDamageTarget(player, tostring(defender.UserId)) then
		logValidation(false, "launch_target_limit_or_duplicate")
		return
	end
	if launcherService2 and not launcherService2:RegisterLaunchKnockbackTarget(player, tostring(defender.UserId)) then
		logValidation(false, "launch_knockback_target_limit_or_duplicate")
		return
	end

	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not stateService then
		logValidation(false, "missing_state_service")
		return
	end
	if (stateService.IsHuman and stateService:IsHuman(player)) or stateService.HasFlag and (
		stateService:HasFlag(player, "Ghost") or stateService:HasFlag(defender, "Ghost")
	) then
		logValidation(false, "blocked_participant_state")
		return
	end

	local attackerVelocity = reportedVelocity.Magnitude > 0 and reportedVelocity or getHorizontalVelocity(root)
	local defenderVelocity = getHorizontalVelocity(targetRoot)
	local collisionResult = CombatCollision.ResolveAttackerBounce(attackerVelocity, defenderVelocity, normal)
	local impactSpeed = math.max(collisionResult.ClosingSpeed, math.max(attackerVelocity.Magnitude, payload.observedSpeed or 0))
	if impactSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
		logValidation(false, "impact_speed_below_threshold")
		return
	end

	local attackerAbsoluteSpeed = attackerVelocity.Magnitude
	local defenderOutRaw = collisionResult.DefenderVelocity
	local defenderOutRawSpeed = defenderOutRaw.Magnitude
	local maxDefenderOutSpeed = attackerAbsoluteSpeed * PhysicsConfig.Collision.DefenderVelocityTransferScale
	local defenderOut = if defenderOutRawSpeed <= maxDefenderOutSpeed
		then defenderOutRaw
		elseif maxDefenderOutSpeed <= 0
		then Vector3.zero
		else defenderOutRaw.Unit * maxDefenderOutSpeed
	local outgoingKnockbackMultiplier = tonumber(player:GetAttribute("EquipmentOutgoingKnockbackMultiplier")) or 1
	local incomingKnockbackMultiplier = tonumber(defender:GetAttribute("EquipmentIncomingKnockbackMultiplier")) or 1
	defenderOut *= math.max(0, outgoingKnockbackMultiplier) * math.max(0, incomingKnockbackMultiplier)
	local attackerOut = collisionResult.AttackerVelocity
	local transferEnergy = math.max(0, attackerAbsoluteSpeed)
	local shouldKnockback = defenderOut.Magnitude >= PhysicsConfig.Collision.KnockbackMinActivationSpeed


	if shouldKnockback then
		stateService:ForceSetMovementState(defender, "Knockback")
		if typeof(stateService.RecordKnockbackImpact) == "function" then
			stateService:RecordKnockbackImpact(defender, normal, now, defenderOut.Magnitude)
		end
	end

	local attackerState = stateService:GetState(player)
	local launcherMaxSpeed = attackerState and attackerState.LaunchSpeed or PhysicsConfig.Launch.SpeedMin
	print(`[EQUIPMENT_ATTACK_TRACE][CollisionService] collision accepted; firing hooks attacker={playerName(player)} victim={playerName(defender)} impactSpeed={impactSpeed} transferredVelocity={defenderOut.Magnitude} launchId={tostring(payload.launchId)}`)
	self._context.EventBus:Fire("CollisionDetected", "Launcher", player, defender, {
		Speed = impactSpeed,
		ImpactNormal = normal,
		AngleFactor = collisionResult.AngleFactor,
		NormalSpeed = collisionResult.NormalSpeed,
		TangentialSpeed = collisionResult.TangentialSpeed,
		AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
		LauncherMaxSpeed = launcherMaxSpeed,
	})
	self._context.EventBus:Fire("CollisionPlayerHit", defender, player, impactSpeed, normal, {
		SourceType = "PhysicalLauncherCollision",
		ImpactNormal = normal,
		ImpactSpeed = impactSpeed,
		AngleFactor = collisionResult.AngleFactor,
		NormalSpeed = collisionResult.NormalSpeed,
		TangentialSpeed = collisionResult.TangentialSpeed,
		InitialImpactSpeed = math.max(attackerAbsoluteSpeed, impactSpeed),
		AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
		CollisionCount = 0,
		LaunchEnergy = transferEnergy,
		LauncherMaxSpeed = launcherMaxSpeed,
		TransferredEnergy = transferEnergy,
		TransferredVelocity = defenderOut.Magnitude,
		TransferredVelocityVector = defenderOut,
	})
	if shouldKnockback then
		self._context.EventBus:Fire("CollisionPlayerKnockback", defender, player, defenderOut, {
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			InitialImpactSpeed = math.max(attackerAbsoluteSpeed, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			TransferredEnergy = transferEnergy,
		})
	end
	print(`[Knockback Status] attacker={playerName(player)} defender={playerName(defender)} applied={tostring(shouldKnockback)} impactSpeed={impactSpeed}`)
end

function CollisionService:_bindClientCollisionReports()
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ReportCollision)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		local rateLimiter = ServiceResolver.Get(self._context, "RateLimiter")
		if rateLimiter and not rateLimiter:Allow(RemoteContracts.Names.ReportCollision, tostring(player.UserId)) then
			logValidation(false, "rate_limited")
			return
		end
		if not RemoteContracts.Validate(RemoteContracts.Names.ReportCollision, payload) then
			logValidation(false, "contract_validation_failed")
			return
		end
		self:_resolveClientPlayerHit(player, payload)
	end)
end

return CollisionService
