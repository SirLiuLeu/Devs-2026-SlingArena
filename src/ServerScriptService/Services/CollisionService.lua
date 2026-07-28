--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)
local CollisionValidation = require(script.Parent.CollisionValidation)

local CollisionService = {}
CollisionService.__index = CollisionService

local function getService(context, name)
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

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
		print("[Collision] return: clock sync remotes unavailable")
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

function CollisionService:_validatePlayerReport(
	player: Player, payload: any
): CollisionValidation.ValidationResult
	if typeof(payload.clientTimestamp) ~= "number" or typeof(payload.hitPosition) ~= "Vector3" then
		return { Ok = false, Reason = "invalid clientTimestamp or hitPosition", Details = nil, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
	end

	local now = os.clock()
	if payload.clientTimestamp > now + MAX_REPORT_FUTURE_SECONDS or now - payload.clientTimestamp > MAX_REPORT_AGE_SECONDS then
		return { Ok = false, Reason = `stale or future report: now={now} clientTimestamp={payload.clientTimestamp}`, Details = nil, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
	end

	local playerService = getService(self._context, "PlayerService")
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
	local validation = self:_validatePlayerReport(player, payload)
	local defender = validation.TargetPlayer
	local root = validation.Root
	local targetRoot = validation.TargetPart
	local normal = validation.Normal
	local reportedVelocity = validation.ReportVelocity
	if not (validation.Ok and defender and root and targetRoot) then
		return
	end
	local now = os.clock()
	local dedupeService = getService(self._context, "HitCooldownDedupeService")
	local hitKey = getCollisionKey(player, defender)
	if dedupeService and not dedupeService:TryAcquire("PlayerCollisionPair", hitKey, PhysicsConfig.Collision.Cooldown, now) then
		return
	end

	local stateService = getService(self._context, "PlayerStateService")
	if not stateService then
		return
	end
	if (stateService.IsHuman and stateService:IsHuman(player)) or stateService.HasFlag and (
		stateService:HasFlag(player, "Ghost") or stateService:HasFlag(defender, "Ghost")
	) then
		return
	end

	local attackerVelocity = reportedVelocity.Magnitude > 0 and reportedVelocity or getHorizontalVelocity(root)
	local defenderVelocity = getHorizontalVelocity(targetRoot)
	local collisionResult = CombatCollision.ResolveAttackerBounce(attackerVelocity, defenderVelocity, normal)
	local impactSpeed = math.max(collisionResult.ClosingSpeed, math.max(attackerVelocity.Magnitude, payload.observedSpeed or 0))
	if impactSpeed < PhysicsConfig.Collision.RealHitMinClosingSpeed then
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
	local attackerOut = collisionResult.AttackerVelocity
	local transferEnergy = math.max(0, attackerAbsoluteSpeed)
	local shouldKnockback = defenderOut.Magnitude > PhysicsConfig.Collision.MinPostCollisionSpeed

	local selfBounceRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ApplySelfBounce)
	if selfBounceRemote and selfBounceRemote:IsA("RemoteEvent") then
		selfBounceRemote:FireClient(player, attackerOut, CombatCollision.ComputeDepenetratedPosition(root, targetRoot, normal, PhysicsConfig.Collision.Range))
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

	local attackerState = stateService:GetState(player)
	local launcherMaxSpeed = attackerState and attackerState.LaunchSpeed or PhysicsConfig.Launch.SpeedMin
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
		Duration = PhysicsConfig.Collision.KnockbackImpulseDuration,
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
			Duration = PhysicsConfig.Collision.KnockbackImpulseDuration,
			ImpactNormal = normal,
			ImpactSpeed = impactSpeed,
			InitialImpactSpeed = math.max(attackerAbsoluteSpeed, impactSpeed),
			AttackerAbsoluteSpeed = attackerAbsoluteSpeed,
			TransferredEnergy = transferEnergy,
		})
	end
	collisionLog(`resolved client-authoritative player hit attacker={playerName(player)} defender={playerName(defender)} impactSpeed={impactSpeed}`)
end

function CollisionService:_bindClientCollisionReports()
	local remote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ReportCollision)
	if not (remote and remote:IsA("RemoteEvent")) then
		return
	end
	remote.OnServerEvent:Connect(function(player, payload)
		if not RemoteContracts.Validate(RemoteContracts.Names.ReportCollision, payload) then
			collisionLog(`return: ReportCollision contract validation failed attacker={playerName(player)} targetUserId={payload and payload.targetUserId or "nil"}`)
			return
		end
		self:_resolveClientPlayerHit(player, payload)
	end)
end

return CollisionService
