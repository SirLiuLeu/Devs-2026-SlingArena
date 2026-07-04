--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SafeZoneConfig = require(ReplicatedStorage.Shared.Config.SafeZoneConfig)

local SAFE_ZONE_MODEL_NAME = "SimulatorCircle"
local CORE_NAME = "Core"
local LEGACY_CORE_NAME = "Light" .. "Core"
local RADIUS_ATTRIBUTE_NAME = SafeZoneConfig.Attributes.CurrentRadius
local SCALE_ATTRIBUTE_NAME = SafeZoneConfig.Attributes.CurrentScale
local CENTER_ATTRIBUTE_NAME = SafeZoneConfig.Attributes.CurrentCenter
local IS_RELOCATING_ATTRIBUTE_NAME = SafeZoneConfig.Attributes.IsRelocating
local GRADIENT_CYLINDER_NAME = "GradientCylinder"
local GRADIENT_CYLINDER_BASE_SIZE = SafeZoneConfig.GradientCylinderBaseSize

local targetScale = 1

local trackedMap: Model? = nil
local trackedCircle: Model? = nil
local basePartStates = {} :: {[BasePart]: {baseSize: Vector3, localOffset: CFrame, baseTransparency: number}}
local corePart: BasePart? = nil
local baseCoreCFrame: CFrame? = nil

local function configureGradientCylinder(circle: Model)
	local gradientCylinder = circle:FindFirstChild(GRADIENT_CYLINDER_NAME, true)
	if gradientCylinder and gradientCylinder:IsA("BasePart") then
		gradientCylinder.Size = GRADIENT_CYLINDER_BASE_SIZE
	end
end

local function resetTracking()
	basePartStates = {}
	corePart = nil
	baseCoreCFrame = nil
	trackedCircle = nil
end

local function cacheBaseStates(circle: Model)
	resetTracking()
	trackedCircle = circle
	configureGradientCylinder(circle)

	local core = circle:FindFirstChild(CORE_NAME, true)
	if not (core and core:IsA("BasePart")) then
		local legacyCore = circle:FindFirstChild(LEGACY_CORE_NAME, true)
		if legacyCore and legacyCore:IsA("BasePart") then
			legacyCore.Name = CORE_NAME
			core = legacyCore
		else
			return
		end
	end

	if circle.PrimaryPart ~= core then
		circle.PrimaryPart = core
	end
	corePart = core
	baseCoreCFrame = core.CFrame

	for _, descendant in ipairs(circle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			basePartStates[descendant] = {
				baseSize = descendant.Size,
				localOffset = core.CFrame:ToObjectSpace(descendant.CFrame),
				baseTransparency = descendant.Transparency,
			}
		end
	end
end

local function findArenaMap(): Model?
	local maps = Workspace:FindFirstChild("Maps")
	if maps and maps:IsA("Folder") then
		local arenaMap = maps:FindFirstChild("ArenaMap")
		if arenaMap and arenaMap:IsA("Model") then
			return arenaMap
		end

		for _, child in ipairs(maps:GetChildren()) do
			if child:IsA("Model") and string.find(child.Name, "Arena", 1, true) then
				return child
			end
		end
	end

	local directArenaMap = Workspace:FindFirstChild("ArenaMap")
	if directArenaMap and directArenaMap:IsA("Model") then
		return directArenaMap
	end

	return nil
end

local function updateMapTracking()
	local arenaMap = findArenaMap()
	if trackedMap == arenaMap and trackedCircle and trackedCircle.Parent then
		return
	end

	trackedMap = arenaMap
	resetTracking()

	if not trackedMap then
		return
	end

	local initialScale = trackedMap:GetAttribute(SCALE_ATTRIBUTE_NAME)
	targetScale = if type(initialScale) == "number" then math.clamp(initialScale, 0, 1) else 1

	local circle = trackedMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
	if circle and circle:IsA("Model") then
		cacheBaseStates(circle)
	end
end

local function applyVisualScale(_dt: number)
	updateMapTracking()
	if not trackedMap then
		return
	end

	local replicatedScale = trackedMap:GetAttribute(SCALE_ATTRIBUTE_NAME)
	if type(replicatedScale) == "number" then
		targetScale = math.clamp(replicatedScale, 0, 1)
	elseif type(trackedMap:GetAttribute(RADIUS_ATTRIBUTE_NAME)) == "number" then
		-- Backward-compatible fallback for maps that have not received CurrentScale yet.
		targetScale = 1
	end

	local _isRelocating = trackedMap:GetAttribute(IS_RELOCATING_ATTRIBUTE_NAME) == true

	if not trackedCircle or not corePart or not trackedCircle.Parent then
		local circle = trackedMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
		if circle and circle:IsA("Model") then
			cacheBaseStates(circle)
		else
			return
		end
	end

	local centerCFrame = baseCoreCFrame
	local replicatedCenter = trackedMap:GetAttribute(CENTER_ATTRIBUTE_NAME)
	if typeof(replicatedCenter) == "Vector3" then
		local rotationSource = centerCFrame or (corePart and corePart.CFrame) or CFrame.identity
		centerCFrame = CFrame.new(replicatedCenter) * (rotationSource - rotationSource.Position)
	elseif not centerCFrame and corePart then
		centerCFrame = corePart.CFrame
	end
	if not centerCFrame and trackedMap then
		local circle = trackedMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
		local core = circle and circle:FindFirstChild(CORE_NAME, true)
		if core and core:IsA("BasePart") then
			centerCFrame = core.CFrame
		end
	end
	if not centerCFrame then
		return
	end

	local scaleXZ = targetScale
	local isCollapsed = targetScale <= 0.001
	local coreCFrame = centerCFrame

	for part, state in pairs(basePartStates) do
		if part.Parent then
			local localOffset = state.localOffset
			local localPosition = localOffset.Position
			local rotationOnly = localOffset - localPosition
			local scaledLocalPosition = Vector3.new(localPosition.X * scaleXZ, localPosition.Y, localPosition.Z * scaleXZ)

			part.Size = Vector3.new(
				state.baseSize.X * scaleXZ,
				state.baseSize.Y,
				state.baseSize.Z * scaleXZ
			)
			part.CFrame = coreCFrame * CFrame.new(scaledLocalPosition) * rotationOnly
			part.Transparency = if isCollapsed then 1 else state.baseTransparency
		end
	end
end

RunService.RenderStepped:Connect(applyVisualScale)
