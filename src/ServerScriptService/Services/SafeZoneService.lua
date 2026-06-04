--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)

local SafeZoneService = {}
SafeZoneService.__index = SafeZoneService

local SAFE_ZONE_MODEL_NAME = "SimulatorCircle"
local LIGHT_CORE_NAME = "LightCore"
local RADIUS_ATTRIBUTE_NAME = "CurrentRadius"

local START_RADIUS = 420
local MIN_RADIUS = 0
local SHRINK_DURATION_SECONDS = 10 * 60
local DAMAGE_STEP_INTERVAL = 30
local DAMAGE_TICK_INTERVAL = 1
local DAMAGE_START_PERCENT = 0.5
local DAMAGE_PERCENT_STEP = 0.5
local DAMAGE_MAX_PERCENT = 5
local DAMAGE_FIXED_BASE = 15000

local function getPlanarPosition(position: Vector3): Vector2
	return Vector2.new(position.X, position.Z)
end

local function getCenterPosition(centerMarker: Instance?): Vector3?
	if not centerMarker then
		return nil
	end
	if centerMarker:IsA("BasePart") then
		return centerMarker.Position
	end
	if centerMarker:IsA("Model") then
		return centerMarker:GetPivot().Position
	end
	return nil
end

function SafeZoneService.new(context)
	local self = setmetatable({}, SafeZoneService)
	self._context = context
	self._startRadius = START_RADIUS
	self._minRadius = MIN_RADIUS
	self._radius = self._startRadius
	self._shrinkDuration = SHRINK_DURATION_SECONDS
	self._elapsed = 0
	self._center = Vector3.zero
	self._activeArenaMap = nil :: Model?
	self._visualCircle = nil :: Model?
	self._lightCore = nil :: BasePart?
	self._outsideDamageTimers = {} :: { [Player]: number }
	self._circleBaseTransparency = {} :: { [BasePart]: number }
	return self
end

function SafeZoneService:Init()
	RunService.Heartbeat:Connect(function(dt)
		self:_step(dt)
	end)
end

function SafeZoneService:GetRadius(): number
	return self._radius
end

function SafeZoneService:GetCenter(): Vector3
	return self._center
end

function SafeZoneService:_getArenaMap(): Model?
	local mapService = self._context.Services.MapService
	if not mapService then
		return nil
	end
	local arenaMap = mapService:GetArenaModel()
	if arenaMap and arenaMap:IsA("Model") then
		return arenaMap
	end
	return nil
end

function SafeZoneService:_ensureVisualCircle(arenaMap: Model, centerPosition: Vector3)
	if self._visualCircle and self._visualCircle.Parent ~= arenaMap then
		self._visualCircle = nil
	end

	local circle = self._visualCircle
	if not circle then
		local existingCircle = arenaMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
		if existingCircle and existingCircle:IsA("Model") then
			circle = existingCircle
		end
		self._visualCircle = circle
	end

	if not circle then
		return
	end

	for _, descendant in ipairs(circle:GetDescendants()) do
		if descendant:IsA("BasePart") and self._circleBaseTransparency[descendant] == nil then
			self._circleBaseTransparency[descendant] = descendant.Transparency
		end
	end

	local lightCore = circle:FindFirstChild("LightCore", true)
	if lightCore and lightCore:IsA("BasePart") then
		self._lightCore = lightCore
		if circle.PrimaryPart ~= lightCore then
			circle.PrimaryPart = lightCore
		end
		-- Do not re-pivot the model using LightCore's own position as the target center.
		-- Reapplying PivotTo each heartbeat with a non-zero model-pivot offset causes cumulative drift.
	end
end

function SafeZoneService:_resolveCenter(arenaMap: Model): Vector3?
	local circle = arenaMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
	if not (circle and circle:IsA("Model")) then
		return nil
	end
	local lightCore = circle:FindFirstChild(LIGHT_CORE_NAME, true)
	if not lightCore then
		return nil
	end
	return getCenterPosition(lightCore)
end

function SafeZoneService:_updateRadius(dt: number)
	self._elapsed += dt
	local progress = math.clamp(self._elapsed / self._shrinkDuration, 0, 1)
	local target = self._startRadius - ((self._startRadius - self._minRadius) * progress)
	self._radius = math.max(self._minRadius, target)
end

function SafeZoneService:_updateVisualTransparency()
	local circle = self._visualCircle
	if not circle then
		return
	end

	local isCollapsed = self._radius <= 0
	for _, descendant in ipairs(circle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if self._circleBaseTransparency[descendant] == nil then
				self._circleBaseTransparency[descendant] = descendant.Transparency
			end
			descendant.Transparency = if isCollapsed then 1 else self._circleBaseTransparency[descendant]
		end
	end
end

function SafeZoneService:_getCurrentDamagePercent(): number
	local rampSteps = math.floor(self._elapsed / DAMAGE_STEP_INTERVAL)
	return math.clamp(DAMAGE_START_PERCENT + (rampSteps * DAMAGE_PERCENT_STEP), DAMAGE_START_PERCENT, DAMAGE_MAX_PERCENT)
end

function SafeZoneService:_calculateOutsideDamage(state: any, damagePercent: number): number
	local currentPercent = damagePercent / 100
	local hp = if type(state.CurrentHP) == "number" then state.CurrentHP else state.MaxHP
	return (hp * currentPercent) + (DAMAGE_FIXED_BASE * currentPercent)
end

function SafeZoneService:_isOutsideCircle(rootPosition: Vector3): boolean
	if self._radius <= 0 then
		return true
	end

	local flattenedCenter: Vector2 = getPlanarPosition(self._center)
	local flattenedPlayerPos: Vector2 = getPlanarPosition(rootPosition)
	local planarDistance = (flattenedPlayerPos - flattenedCenter).Magnitude
	return planarDistance > self._radius
end

function SafeZoneService:_damagePlayersOutsideZone(dt: number)
	local playerService = self._context.Services.PlayerService
	local playerStateService = self._context.Services.PlayerStateService
	local damagePipelineService = self._context.Services.DamagePipelineService
	if not playerService or not playerStateService or not damagePipelineService then
		return
	end

	local damagePercent = self:_getCurrentDamagePercent()
	local activePlayers = {} :: { [Player]: boolean }

	for _, player in ipairs(Players:GetPlayers()) do
		activePlayers[player] = true
		local state = playerStateService:GetState(player)
		local root = playerService:GetRoot(player)
		if state and state.IsAlive and root and self:_isOutsideCircle(root.Position) then
			local accumulated = (self._outsideDamageTimers[player] or 0) + dt
			while accumulated >= DAMAGE_TICK_INTERVAL do
				local damage = self:_calculateOutsideDamage(state, damagePercent)
				-- Outside-zone damage is periodic DOT; do not emit per-tick RemoteEvent feedback.
				damagePipelineService:ApplyDamage(player, damage, nil, nil, { SuppressFeedback = true })
				accumulated -= DAMAGE_TICK_INTERVAL
			end
			self._outsideDamageTimers[player] = accumulated
		else
			self._outsideDamageTimers[player] = nil
		end
	end

	for player in pairs(self._outsideDamageTimers) do
		if not activePlayers[player] then
			self._outsideDamageTimers[player] = nil
		end
	end
end

function SafeZoneService:_replicateRadius(arenaMap: Model)
	arenaMap:SetAttribute(RADIUS_ATTRIBUTE_NAME, self._radius)
end

function SafeZoneService:IsAtMinimumRadius(): boolean
	return self._radius <= self._minRadius + 0.0001
end

function SafeZoneService:_isShrinkAllowed(): boolean
	local roundService = self._context.Services.RoundService
	if not roundService then
		return false
	end
	return roundService:IsRoundActive() and roundService:GetState() == GameStates.MapRoundState.EarlyGame
end

function SafeZoneService:_isDamageAllowed(): boolean
	local roundService = self._context.Services.RoundService
	if not roundService then
		return false
	end
	local roundState = roundService:GetState()
	local allowedState = roundState == GameStates.MapRoundState.EarlyGame or roundState == GameStates.MapRoundState.FinalPhase
	return roundService:IsRoundActive() and allowedState
end

function SafeZoneService:Reset()
	self._radius = self._startRadius
	self._elapsed = 0
	table.clear(self._outsideDamageTimers)
end

function SafeZoneService:_step(dt: number)
	local arenaMap = self:_getArenaMap()
	if not arenaMap then
		return
	end

	if self._activeArenaMap ~= arenaMap then
		self._activeArenaMap = arenaMap
		self._visualCircle = nil
	end

	local centerPosition = self:_resolveCenter(arenaMap)
	if not centerPosition then
		return
	end
	self._center = centerPosition

	self:_ensureVisualCircle(arenaMap, centerPosition)
	if self:_isShrinkAllowed() then
		self:_updateRadius(dt)
	else
		local roundService = self._context.Services.RoundService
		if roundService and roundService:GetState() == GameStates.MapRoundState.Lobby then
			self:Reset()
		end
	end
	self:_updateVisualTransparency()
	self:_replicateRadius(arenaMap)
	if self:_isDamageAllowed() then
		self:_damagePlayersOutsideZone(dt)
	end
end

return SafeZoneService
