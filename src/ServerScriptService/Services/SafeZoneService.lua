--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)

local SafeZoneService = {}
SafeZoneService.__index = SafeZoneService

local SAFE_ZONE_MODEL_NAME = "SimulatorCircle"
local CORE_NAME = "Core"
local LEGACY_CORE_NAME = "Light" .. "Core"
local RADIUS_ATTRIBUTE_NAME = "CurrentRadius"
local SCALE_ATTRIBUTE_NAME = "CurrentScale"
local CENTER_ATTRIBUTE_NAME = "CurrentCenter"
local IS_RELOCATING_ATTRIBUTE_NAME = "IsRelocating"

local START_RADIUS = 420
local MIN_RADIUS = 0
local RELOCATION_SCALE_THRESHOLD = 0.7
local RELOCATION_DURATION_SECONDS = 10
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
	self._core = nil :: BasePart?
	self._initialCenter = nil :: Vector3?
	self._initialPivot = nil :: CFrame?
	self._relocationTriggered = false
	self._relocating = false
	self._relocationElapsed = 0
	self._relocationStart = nil :: Vector3?
	self._relocationTarget = nil :: Vector3?
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

local function findCore(circle: Model): BasePart?
	local core = circle:FindFirstChild(CORE_NAME, true)
	if core and core:IsA("BasePart") then
		return core
	end

	local legacyCore = circle:FindFirstChild(LEGACY_CORE_NAME, true)
	if legacyCore and legacyCore:IsA("BasePart") then
		legacyCore.Name = CORE_NAME
		return legacyCore
	end

	return nil
end

function SafeZoneService:_ensureVisualCircle(arenaMap: Model)
	if self._visualCircle and self._visualCircle.Parent ~= arenaMap then
		self._visualCircle = nil
		self._core = nil
		self._initialCenter = nil
		self._initialPivot = nil
		table.clear(self._circleBaseTransparency)
	end

	local circle = self._visualCircle
	if not circle then
		for _, child in ipairs(arenaMap:GetChildren()) do
			if child.Name == SAFE_ZONE_MODEL_NAME and child:IsA("Model") then
				if not circle then
					circle = child
				else
					child:Destroy()
				end
			end
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

	local core = findCore(circle)
	if core then
		self._core = core
		if circle.PrimaryPart ~= core then
			circle.PrimaryPart = core
		end
		if not self._initialCenter then
			self._initialCenter = core.Position
		end
		if not self._initialPivot then
			self._initialPivot = circle:GetPivot()
		end
	end
end

function SafeZoneService:_resolveCenter(arenaMap: Model): Vector3?
	self:_ensureVisualCircle(arenaMap)
	return getCenterPosition(self._core)
end

function SafeZoneService:_getLavaPart(arenaMap: Model): BasePart?
	local traps = arenaMap:FindFirstChild("Traps")
	local lavaTrap = traps and traps:FindFirstChild("LavaTrap")
	local lava = lavaTrap and lavaTrap:FindFirstChild("Lava")
	if lava and lava:IsA("BasePart") then
		return lava
	end
	return nil
end

function SafeZoneService:_getRandomPointInLavaBounds(arenaMap: Model, y: number): Vector3?
	local lava = self:_getLavaPart(arenaMap)
	if not lava then
		return nil
	end
	local halfX = lava.Size.X * 0.5
	local halfZ = lava.Size.Z * 0.5
	local localPoint = Vector3.new((math.random() * 2 - 1) * halfX, 0, (math.random() * 2 - 1) * halfZ)
	local worldPoint = lava.CFrame:PointToWorldSpace(localPoint)
	return Vector3.new(worldPoint.X, y, worldPoint.Z)
end

function SafeZoneService:_currentScale(): number
	if self._startRadius <= 0 then
		return 0
	end
	return math.clamp(self._radius / self._startRadius, 0, 1)
end

function SafeZoneService:_beginRelocation(arenaMap: Model)
	if self._relocationTriggered then
		return
	end
	local startCenter = self._center
	local targetCenter = self:_getRandomPointInLavaBounds(arenaMap, startCenter.Y)
	if not targetCenter then
		return
	end
	self._relocationTriggered = true
	self._relocating = true
	self._relocationElapsed = 0
	self._relocationStart = startCenter
	self._relocationTarget = targetCenter
end

function SafeZoneService:_updateRelocation(dt: number)
	if not self._relocating then
		return
	end
	local startCenter = self._relocationStart
	local targetCenter = self._relocationTarget
	if not startCenter or not targetCenter then
		self._relocating = false
		return
	end

	self._relocationElapsed += dt
	local alpha = math.clamp(self._relocationElapsed / RELOCATION_DURATION_SECONDS, 0, 1)
	self._center = startCenter:Lerp(targetCenter, alpha)
	if alpha >= 1 then
		self._relocating = false
	end
end

function SafeZoneService:_moveCircleToCenter()
	local circle = self._visualCircle
	local core = self._core
	if not circle or not core then
		return
	end
	local delta = self._center - core.Position
	if delta.Magnitude > 0.0001 then
		circle:PivotTo(circle:GetPivot() + delta)
	end
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

function SafeZoneService:_replicateState(arenaMap: Model)
	arenaMap:SetAttribute(RADIUS_ATTRIBUTE_NAME, self._radius)
	arenaMap:SetAttribute(SCALE_ATTRIBUTE_NAME, self:_currentScale())
	arenaMap:SetAttribute(CENTER_ATTRIBUTE_NAME, self._center)
	arenaMap:SetAttribute(IS_RELOCATING_ATTRIBUTE_NAME, self._relocating)
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
	self._relocationTriggered = false
	self._relocating = false
	self._relocationElapsed = 0
	self._relocationStart = nil
	self._relocationTarget = nil
	if self._visualCircle and self._initialPivot then
		self._visualCircle:PivotTo(self._initialPivot)
	end
	if self._initialCenter then
		self._center = self._initialCenter
	elseif self._core then
		self._center = self._core.Position
	end
	table.clear(self._outsideDamageTimers)
	local arenaMap = self:_getArenaMap()
	if arenaMap then
		self:_replicateState(arenaMap)
	end
end

function SafeZoneService:_step(dt: number)
	local arenaMap = self:_getArenaMap()
	if not arenaMap then
		return
	end

	if self._activeArenaMap ~= arenaMap then
		self._activeArenaMap = arenaMap
		self._visualCircle = nil
		self._core = nil
		self._initialCenter = nil
		self._initialPivot = nil
		table.clear(self._circleBaseTransparency)
	end

	local centerPosition = self:_resolveCenter(arenaMap)
	if not centerPosition then
		return
	end
	if not self._relocating then
		self._center = centerPosition
	end

	self:_ensureVisualCircle(arenaMap)
	if self:_isShrinkAllowed() then
		self:_updateRadius(dt)
		if not self._relocationTriggered and self:_currentScale() <= RELOCATION_SCALE_THRESHOLD then
			self:_beginRelocation(arenaMap)
		end
		self:_updateRelocation(dt)
		self:_moveCircleToCenter()
	else
		local roundService = self._context.Services.RoundService
		if roundService and roundService:GetState() == GameStates.MapRoundState.Lobby then
			self:Reset()
		end
	end
	self:_updateVisualTransparency()
	self:_replicateState(arenaMap)
	if self:_isDamageAllowed() then
		self:_damagePlayersOutsideZone(dt)
	end
end

return SafeZoneService
