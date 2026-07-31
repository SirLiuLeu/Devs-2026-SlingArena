--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local CombatCollision = require(ReplicatedStorage.Shared.Utils.CombatCollision)

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

local function getService(context: Context, name: string): any
	if context.ServiceRegistry then
		return context.ServiceRegistry:GetOptional(name)
	end
	return context.Services and context.Services[name]
end

local function fail(reason: string, details: { [string]: any }?): ValidationResult
	return { Ok = false, Reason = reason, Details = details, Root = nil, TargetPart = nil, TargetPlayer = nil, Normal = Vector3.new(1, 0, 0), ReportVelocity = Vector3.zero, Speed = 0 }
end

function CollisionValidation.ValidateAttackerTarget(context: Context, attacker: Player, target: ValidationTarget, payload: any): ValidationResult
	if type(payload) ~= "table" then
		return fail("invalid_payload", nil)
	end
	local playerService = getService(context, "PlayerService")
	local stateService = getService(context, "PlayerStateService")
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
		if stateService.HasFlag and (stateService:HasFlag(attacker, "Ghost") or stateService:HasFlag(target.Player, "Ghost")) then
			return fail("ghost_participant", nil)
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

return CollisionValidation
