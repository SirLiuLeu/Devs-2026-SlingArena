--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local SAFE_ZONE_MODEL_NAME = "SimulatorCircle"
local LIGHT_CORE_NAME = "LightCore"
local RADIUS_ATTRIBUTE_NAME = "CurrentRadius"

local BASE_GAMEPLAY_RADIUS = 70
local SMOOTH_SPEED = 10

local currentVisualRadius = BASE_GAMEPLAY_RADIUS
local targetRadius = BASE_GAMEPLAY_RADIUS

local trackedMap: Model? = nil
local trackedCircle: Model? = nil
local basePartStates = {} :: {[BasePart]: {baseSize: Vector3, localOffset: CFrame}}
local lightCorePart: BasePart? = nil

local function resetTracking()
	basePartStates = {}
	lightCorePart = nil
	trackedCircle = nil
end

local function cacheBaseStates(circle: Model)
	resetTracking()
	trackedCircle = circle

	local lightCore = circle:FindFirstChild("LightCore", true)
	if not (lightCore and lightCore:IsA("BasePart")) then
		return
	end

	if circle.PrimaryPart ~= lightCore then
		circle.PrimaryPart = lightCore
	end
	lightCorePart = lightCore

	for _, descendant in ipairs(circle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			basePartStates[descendant] = {
				baseSize = descendant.Size,
				localOffset = lightCore.CFrame:ToObjectSpace(descendant.CFrame),
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

	targetRadius = trackedMap:GetAttribute(RADIUS_ATTRIBUTE_NAME) or BASE_GAMEPLAY_RADIUS
	currentVisualRadius = targetRadius

	local circle = trackedMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
	if circle and circle:IsA("Model") then
		cacheBaseStates(circle)
	end
end

local function applyVisualScale(dt: number)
	updateMapTracking()
	if not trackedMap then
		return
	end

	local replicatedRadius = trackedMap:GetAttribute(RADIUS_ATTRIBUTE_NAME)
	if type(replicatedRadius) == "number" then
		targetRadius = math.max(replicatedRadius, 0.1)
	end

	if math.abs(currentVisualRadius - targetRadius) > 0.001 then
		local alpha = 1 - math.exp(-SMOOTH_SPEED * dt)
		currentVisualRadius = currentVisualRadius + ((targetRadius - currentVisualRadius) * alpha)
	else
		currentVisualRadius = targetRadius
	end

	if not trackedCircle or not lightCorePart or not trackedCircle.Parent then
		local circle = trackedMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
		if circle and circle:IsA("Model") then
			cacheBaseStates(circle)
		else
			return
		end
	end

	local centerPosition = lightCorePart and lightCorePart.Position or nil
	if not centerPosition and trackedMap then
		local circle = trackedMap:FindFirstChild(SAFE_ZONE_MODEL_NAME)
		local lightCore = circle and circle:FindFirstChild(LIGHT_CORE_NAME, true)
		if lightCore and lightCore:IsA("BasePart") then
			centerPosition = lightCore.Position
		end
	end
	if not centerPosition or not lightCorePart then
		return
	end

	local scaleXZ = currentVisualRadius / BASE_GAMEPLAY_RADIUS
	local lightCoreRotation = lightCorePart.CFrame.Rotation
	local lightCoreCFrame = CFrame.new(centerPosition) * lightCoreRotation

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
			part.CFrame = lightCoreCFrame * CFrame.new(scaledLocalPosition) * rotationOnly
		end
	end
end

RunService.RenderStepped:Connect(applyVisualScale)
