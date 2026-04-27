--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SafeZoneService = {}
SafeZoneService.__index = SafeZoneService

local SAFE_ZONE_MODEL_NAME = "SimulatorCircle"
local CENTER_MARKER_NAME = "CenterCross"
local RADIUS_ATTRIBUTE_NAME = "CurrentRadius"

local START_RADIUS = 70
local MIN_RADIUS = 0.1
local SHRINK_DURATION_SECONDS = 10 * 60
local DAMAGE_STEP_INTERVAL = 30
local DAMAGE_START_PERCENT = 1
local DAMAGE_MAX_PERCENT = 10

local function getPlanarPosition(position: Vector3): Vector3
	return Vector3.new(position.X, 0, position.Z)
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
		else
			local template = ReplicatedStorage:FindFirstChild(SAFE_ZONE_MODEL_NAME)
			if template and template:IsA("Model") then
				circle = template:Clone()
				circle.Name = SAFE_ZONE_MODEL_NAME
				circle.Parent = arenaMap
			end
		end
		self._visualCircle = circle
	end

	if not circle then
		return
	end

	local lightCore = circle:FindFirstChild("LightCore", true)
	if lightCore and lightCore:IsA("BasePart") then
		if circle.PrimaryPart ~= lightCore then
			circle.PrimaryPart = lightCore
		end
		circle:PivotTo(CFrame.new(centerPosition) * lightCore.CFrame.Rotation)
	end
end

function SafeZoneService:_resolveCenter(arenaMap: Model): Vector3?
	local centerMarker = arenaMap:FindFirstChild(CENTER_MARKER_NAME, true)
	return getCenterPosition(centerMarker)
end

function SafeZoneService:_updateRadius(dt: number)
	self._elapsed += dt
	local progress = math.clamp(self._elapsed / self._shrinkDuration, 0, 1)
	local target = self._startRadius - ((self._startRadius - self._minRadius) * progress)
	self._radius = math.max(self._minRadius, target)
end

function SafeZoneService:_getCurrentDamagePercent(): number
	local rampSteps = math.floor(self._elapsed / DAMAGE_STEP_INTERVAL)
	return math.clamp(DAMAGE_START_PERCENT + rampSteps, DAMAGE_START_PERCENT, DAMAGE_MAX_PERCENT)
end

function SafeZoneService:_damagePlayersOutsideZone(dt: number)
	local playerService = self._context.Services.PlayerService
	local playerStateService = self._context.Services.PlayerStateService
	local damagePipelineService = self._context.Services.DamagePipelineService
	if not playerService or not playerStateService or not damagePipelineService then
		return
	end

	local flattenedCenter = getPlanarPosition(self._center)
	local damagePercent = self:_getCurrentDamagePercent()

	for _, player in ipairs(Players:GetPlayers()) do
		local state = playerStateService:GetState(player)
		if state and state.IsAlive then
			local root = playerService:GetRoot(player)
			if root then
				local flattenedPlayerPos = getPlanarPosition(root.Position)
				local planarDistance = (flattenedPlayerPos - flattenedCenter).Magnitude
				if planarDistance > self._radius then
					local damage = state.MaxHP * (damagePercent / 100) * dt
					damagePipelineService:ApplyDamage(player, damage, nil, nil)
				end
			end
		end
	end
end

function SafeZoneService:_replicateRadius(arenaMap: Model)
	arenaMap:SetAttribute(RADIUS_ATTRIBUTE_NAME, self._radius)
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
	self:_updateRadius(dt)
	self:_replicateRadius(arenaMap)
	self:_damagePlayersOutsideZone(dt)
end

return SafeZoneService
