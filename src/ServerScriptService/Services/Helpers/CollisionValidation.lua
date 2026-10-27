--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)
local ServiceResolver = require(script.Parent.Parent.Infrastructure.ServiceResolver)

export type Context = { Services: any, ServiceRegistry: any? }
export type ValidationTarget = { Kind: "Player" | "Food", Player: Player?, Part: BasePart, RadiusPadding: number?, RequiresLaunching: boolean?, AllowTouchStates: boolean? }
export type ValidationResult = { Ok: boolean, Reason: string?, Details: { [string]: any }?, Root: BasePart?, TargetPart: BasePart?, TargetPlayer: Player?, Normal: Vector3, ReportVelocity: Vector3, Speed: number }

local CollisionValidation = {}

local COMMON_ALLOWED_STATES = {
	[GameStates.PlayerState.Launching] = true,
	[GameStates.PlayerState.Moving] = true,
	[GameStates.PlayerState.Idle] = true,
	[GameStates.PlayerState.Human] = true,
}


local function fail(reason: string, details: { [string]: any }?): ValidationResult
	return { Ok = false, Reason = reason, Details = details, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
end

function CollisionValidation.ValidateAttackerTarget(context: Context, attacker: Player, target: ValidationTarget, payload: any): ValidationResult
	if type(payload) ~= "table" then
		return fail("invalid_payload", nil)
	end
	local playerService = ServiceResolver.Get(context, "PlayerService")
	local stateService = ServiceResolver.Get(context, "PlayerStateService")
	local root = playerService and playerService:GetRoot(attacker)
	if not (root and stateService) then
		return fail("missing_player_root_or_state_service", nil)
	end
	local attackerState = stateService:GetState(attacker)
	local movementState = attackerState and attackerState.MovementState
	if not (attackerState and movementState and attackerState.IsAlive == true) then
		return fail("invalid_launch_state", { movementState = movementState or "nil", alive = attackerState and attackerState.IsAlive or false })
	end
	if stateService.IsHuman and stateService:IsHuman(attacker) and target.RequiresLaunching then
		return fail("human_blocked_combat", { movementState = movementState })
	end
	if target.RequiresLaunching and movementState ~= GameStates.PlayerState.Launching then
		return fail("invalid_launch_state", { movementState = movementState })
	end
	if (not target.RequiresLaunching) and target.AllowTouchStates and not COMMON_ALLOWED_STATES[movementState] then
		return fail("invalid_launch_state", { movementState = movementState })
	end
	if target.Player then
		local defenderState = stateService:GetState(target.Player)
		if target.Player == attacker or not defenderState or defenderState.IsAlive ~= true then
			return fail("invalid_participants", nil)
		end
	end
	local reportVelocity = if typeof(payload.velocity) == "Vector3" then CombatCollision.FlattenXZ(payload.velocity) else CombatCollision.FlattenXZ(root.AssemblyLinearVelocity)
	local serverVelocity = CombatCollision.FlattenXZ(root.AssemblyLinearVelocity)
	if serverVelocity.Magnitude > reportVelocity.Magnitude then
		reportVelocity = serverVelocity
	end
	local observedSpeed = if typeof(payload.observedSpeed) == "number" then math.max(0, payload.observedSpeed) else 0
	local speed = math.max(reportVelocity.Magnitude, observedSpeed)
	if speed > PhysicsConfig.Collision.MaxAllowedSpeed then
		return fail("speed_above_max", { speed = speed, maxAllowed = PhysicsConfig.Collision.MaxAllowedSpeed })
	end
	if target.RequiresLaunching and speed < PhysicsConfig.Collision.FoodHitMinHorizontalSpeed then
		return fail("speed_below_threshold", { horizontalSpeed = speed })
	end
	local targetPart = target.Part
	local playerRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local targetRadius = math.max(targetPart.Size.X, targetPart.Size.Z) * 0.5 + (target.RadiusPadding or 0)
	local currPos = root.Position
	local sweepStart = if typeof(payload.sweepStart) == "Vector3" then payload.sweepStart else (if typeof(payload.currPos) == "Vector3" then payload.currPos else currPos)
	local sweepEnd = if typeof(payload.sweepEnd) == "Vector3" then payload.sweepEnd else currPos
	local segment = CombatCollision.FlattenXZ(sweepEnd) - CombatCollision.FlattenXZ(sweepStart)
	local targetOffset = CombatCollision.FlattenXZ(targetPart.Position) - CombatCollision.FlattenXZ(sweepStart)
	local alpha = if segment.Magnitude > 0.001 then math.clamp(targetOffset:Dot(segment) / segment:Dot(segment), 0, 1) else 0
	local closest = CombatCollision.FlattenXZ(sweepStart) + segment * alpha
	local sweepDistance = (closest - CombatCollision.FlattenXZ(targetPart.Position)).Magnitude
	local allowedSweepDistance = playerRadius + targetRadius + PhysicsConfig.Collision.ValidationTolerance
	if sweepDistance > allowedSweepDistance then
		return fail("sweep_misses_hitbox", { sweepDistance = sweepDistance, allowedSweepDistance = allowedSweepDistance })
	end
	local minSweepY = math.min(sweepStart.Y, sweepEnd.Y) - PhysicsConfig.Collision.YTolerance
	local maxSweepY = math.max(sweepStart.Y, sweepEnd.Y) + PhysicsConfig.Collision.YTolerance
	if targetPart.Position.Y < minSweepY or targetPart.Position.Y > maxSweepY then
		return fail("sweep_y_tolerance_failure", { targetY = targetPart.Position.Y, minSweepY = minSweepY, maxSweepY = maxSweepY })
	end
	local normal = if typeof(payload.surfaceNormal) == "Vector3" then CombatCollision.SafeUnit(payload.surfaceNormal, root.Position - targetPart.Position) else CombatCollision.ResolvePlanarNormal(root.Position, targetPart.Position, reportVelocity)
	if reportVelocity.Magnitude > PhysicsConfig.Movement.InputDeadzone and reportVelocity:Dot(normal) < 0 then
		normal = -normal
	end
	return { Ok = true, Reason = nil, Details = nil, Root = root, TargetPart = targetPart, TargetPlayer = target.Player, Normal = normal, ReportVelocity = reportVelocity, Speed = speed }
end

local function isFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

local function isFiniteVector3(value: any): boolean
	return typeof(value) == "Vector3"
		and isFiniteNumber(value.X)
		and isFiniteNumber(value.Y)
		and isFiniteNumber(value.Z)
end

local function isPlayerOrLauncherPart(part: BasePart): boolean
	local launcherPawns = Workspace:FindFirstChild("LauncherPawns")
	if launcherPawns and part:IsDescendantOf(launcherPawns) then
		return true
	end
	for _, targetPlayer in ipairs(Players:GetPlayers()) do
		local character = targetPlayer.Character
		if character and part:IsDescendantOf(character) then
			return true
		end
	end
	return false
end

local function isFoodPart(part: BasePart): boolean
	local cursor: Instance? = part
	while cursor and cursor ~= Workspace do
		if cursor:IsA("Model") and typeof(cursor:GetAttribute("FoodId")) == "string" then
			return true
		end
		cursor = cursor.Parent
	end
	return false
end

local function isTrapPart(part: BasePart): boolean
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not mapsRoot then return false end
	for _, mapModel in ipairs(mapsRoot:GetChildren()) do
		local traps = mapModel:FindFirstChild("Traps")
		if traps and part:IsDescendantOf(traps) then
			return true
		end
	end
	return false
end

local function distanceFromPointToSegment(point: Vector3, startPosition: Vector3, endPosition: Vector3): number
	local segment = endPosition - startPosition
	local segmentLengthSquared = segment:Dot(segment)
	local alpha = if segmentLengthSquared > 0.0001
		then math.clamp((point - startPosition):Dot(segment) / segmentLengthSquared, 0, 1)
		else 0
	return (point - (startPosition + segment * alpha)).Magnitude
end

-- World-hit reports are cosmetic only. Launch state, timestamp and speed are also
-- checked by LauncherService:ValidateLaunchReport before this geometry validation runs.
function CollisionValidation.ValidateWallTarget(
	context: Context,
	attacker: Player,
	targetPart: BasePart,
	payload: any
): (boolean, string?, number?)
	if type(payload) ~= "table" or not (targetPart and targetPart:IsA("BasePart")) then
		return false, "invalid_wall_payload", nil
	end
	if not targetPart.Parent or not targetPart:IsDescendantOf(Workspace) or targetPart.CanCollide ~= true then
		return false, "invalid_or_noncollidable_wall", nil
	end
	if not (isFiniteVector3(payload.sweepStart) and isFiniteVector3(payload.sweepEnd) and isFiniteVector3(payload.hitPosition)) then
		return false, "invalid_wall_geometry", nil
	end
	if not isFiniteNumber(payload.timestamp) then
		return false, "invalid_wall_timestamp", nil
	end
	if payload.velocity ~= nil and not isFiniteVector3(payload.velocity) then
		return false, "invalid_wall_velocity", nil
	end
	if payload.observedSpeed ~= nil and (typeof(payload.observedSpeed) ~= "number" or not isFiniteNumber(payload.observedSpeed)) then
		return false, "invalid_wall_speed", nil
	end

	local now = os.clock()
	local reportAge = now - payload.timestamp
	if reportAge < -PhysicsConfig.LagCompensation.FutureToleranceSeconds
		or reportAge > PhysicsConfig.LagCompensation.MaxAcceptedLatencySeconds then
		return false, "wall_timestamp_out_of_window", nil
	end

	local playerService = ServiceResolver.Get(context, "PlayerService")
	local stateService = ServiceResolver.Get(context, "PlayerStateService")
	local root = playerService and playerService:GetRoot(attacker)
	local state = stateService and stateService:GetState(attacker)
	if not (root and state and state.IsAlive == true and state.MovementState == GameStates.PlayerState.Launching) then
		return false, "wall_attacker_not_launching", nil
	end
	if stateService.IsHuman and stateService:IsHuman(attacker) then
		return false, "wall_human_mode_blocked", nil
	end
	if isPlayerOrLauncherPart(targetPart) then
		return false, "player_or_launcher_target", nil
	end
	if isFoodPart(targetPart) then
		return false, "food_target", nil
	end
	if isTrapPart(targetPart) then
		return false, "trap_target", nil
	end

	local velocity = if isFiniteVector3(payload.velocity)
		then CombatCollision.FlattenXZ(payload.velocity)
		else CombatCollision.FlattenXZ(root.AssemblyLinearVelocity)
	local serverVelocity = CombatCollision.FlattenXZ(root.AssemblyLinearVelocity)
	local observedSpeed = if typeof(payload.observedSpeed) == "number" then math.max(0, payload.observedSpeed) else 0
	local speed = math.max(velocity.Magnitude, serverVelocity.Magnitude, observedSpeed)
	if speed > PhysicsConfig.Collision.MaxAllowedSpeed then
		return false, "wall_speed_above_max", nil
	end
	if speed < (tonumber(PhysicsConfig.Collision.MinReportSpeed) or 0) then
		return false, "wall_speed_below_threshold", nil
	end

	local localHit = targetPart.CFrame:PointToObjectSpace(payload.hitPosition)
	local halfSize = targetPart.Size * 0.5
	local validationTolerance = math.max(0, tonumber(PhysicsConfig.Collision.ValidationTolerance) or 0)
	local hitTolerance = validationTolerance + math.max(0.5, tonumber(PhysicsConfig.Collision.SphereCastRadiusPadding) or 0)
	if math.abs(localHit.X) > halfSize.X + hitTolerance
		or math.abs(localHit.Y) > halfSize.Y + hitTolerance
		or math.abs(localHit.Z) > halfSize.Z + hitTolerance then
		return false, "wall_hit_position_outside_part", nil
	end

	local rootRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local contactTolerance = math.max(0.5, (tonumber(PhysicsConfig.Collision.SphereCastRadiusPadding) or 0) + 0.25)
	local allowedDistance = rootRadius + contactTolerance
	local sweepLength = (payload.sweepEnd - payload.sweepStart).Magnitude
	local maxSweepLength = math.min(32, math.max(8, speed * 0.15 + rootRadius + contactTolerance))
	if sweepLength > maxSweepLength then
		return false, "wall_sweep_too_long", nil
	end
	if distanceFromPointToSegment(payload.hitPosition, payload.sweepStart, payload.sweepEnd) > allowedDistance then
		return false, "wall_hit_misses_sweep", nil
	end

	local maxRootDrift = math.max(8, speed * math.max(0, reportAge) + rootRadius + contactTolerance)
	if (root.Position - payload.sweepEnd).Magnitude > maxRootDrift then
		return false, "wall_sweep_too_far_from_root", nil
	end

	return true, nil, speed
end

return CollisionValidation
