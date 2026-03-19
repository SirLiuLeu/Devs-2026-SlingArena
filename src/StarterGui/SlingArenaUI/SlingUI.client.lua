--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge) :: RemoteEvent
local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge) :: RemoteEvent

local MAX_CHARGE_TIME = SlingshotConfig.MAX_CHARGE_TIME or 2
local COOLDOWN_DURATION = SlingshotConfig.RECOVER_TIME or 3
local MAX_JOYSTICK_DRAG = 60
local UI_WAIT_TIMEOUT = 2
local DEBUG_LOG = true

local warnedMissingUi = false
local lastLoggedChargeBucket = -1
local loggedMaxCharge = false
local lastLoggedUiBucket = -1
local lastLoggedCooldownBucket = -1

local isHolding = false
local inputObject: InputObject? = nil
local startPos = Vector2.zero
local currentPos = Vector2.zero
local currentDelta = Vector2.zero
local charge = 0
local cooldownEndTime = 0

local cachedScreenGui: ScreenGui? = nil
local cachedJoystickRoot: GuiObject? = nil
local cachedBase: GuiObject? = nil
local cachedThumb: GuiObject? = nil
local cachedChargeBar: GuiObject? = nil
local cachedChargeFill: Frame? = nil
local cachedDirectionArrow: GuiObject? = nil
local cachedCooldownBar: GuiObject? = nil
local cachedCooldownFill: Frame? = nil
local hasWaitedForHierarchy = false

local function debugLog(message: string)
	if DEBUG_LOG then
		print(message)
	end
end

local function findChild(parent: Instance?, childName: string): Instance?
	if not parent then
		return nil
	end
	return parent:FindFirstChild(childName)
end

local function waitForChildIfNeeded(parent: Instance?, childName: string, timeout: number): Instance?
	if not parent then
		return nil
	end

	local existing = parent:FindFirstChild(childName)
	if existing then
		return existing
	end

	local ok, result = pcall(function()
		return parent:WaitForChild(childName, timeout)
	end)
	if ok then
		return result
	end

	return nil
end

local function getInputPosition(input: InputObject?): Vector2
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return Vector2.zero
end

local function getAimTargetFromScreenPosition(screenPosition: Vector2): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.new(0, 0, -1)
	end

	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1024, raycastParams)
	if result then
		return result.Position
	end

	return ray.Origin + (ray.Direction * 256)
end

local function getAimTarget(input: InputObject?): Vector3
	local inputPosition = getInputPosition(input)
	if inputPosition.Magnitude > 0 then
		return getAimTargetFromScreenPosition(inputPosition)
	end

	local mouse = player:GetMouse()
	if mouse.Hit then
		return mouse.Hit.Position
	end

	return Vector3.new(0, 0, -1)
end

local function warnMissingUiOnce(message: string)
	if warnedMissingUi then
		return
	end
	warnedMissingUi = true
	warn(message)
	warn("[UI_CREATION_GUIDE] Create StarterGui > SlingArenaUI (Folder) > SlingUI (ScreenGui) > JoystickRoot(Base, Thumb), ChargeBar(Fill), DirectionArrow. Optional: CooldownBar(Fill).")
end

local function findPreferredScreenGui(waitForUi: boolean): ScreenGui?
	debugLog(string.format("[SlingUI] Resolving UI path wait=%s", tostring(waitForUi)))

	local container = if waitForUi
		then waitForChildIfNeeded(playerGui, "SlingArenaUI", UI_WAIT_TIMEOUT)
		else findChild(playerGui, "SlingArenaUI")
	if container then
		debugLog("[SlingUI] Found PlayerGui.SlingArenaUI")
	else
		debugLog("[SlingUI] Waiting for PlayerGui.SlingArenaUI")
	end

	local nestedScreen = if waitForUi
		then waitForChildIfNeeded(container, "SlingUI", UI_WAIT_TIMEOUT)
		else findChild(container, "SlingUI")
	if nestedScreen and nestedScreen:IsA("ScreenGui") then
		debugLog("[SlingUI] Found PlayerGui.SlingArenaUI.SlingUI")
		return nestedScreen
	end

	debugLog("[SlingUI] PlayerGui.SlingArenaUI.SlingUI not ready")
	return nil
end

local function primeUiCache()
	cachedScreenGui = findPreferredScreenGui(true)
end

local function resolveScreenGui(): ScreenGui?
	if cachedScreenGui and cachedScreenGui.Parent then
		return cachedScreenGui
	end

	cachedScreenGui = findPreferredScreenGui(false)
	return cachedScreenGui
end

local function resolveUi()
	local screenGui = resolveScreenGui()
	if not screenGui then
		warnMissingUiOnce("[SlingUI] Missing SlingUI ScreenGui at PlayerGui.SlingArenaUI.SlingUI.")
		return nil, nil, nil, nil, nil, nil, nil, nil, nil
	end

	screenGui.Enabled = true
	debugLog("[SlingUI] Loaded successfully")
	cachedScreenGui = screenGui

	local joystickRoot = if hasWaitedForHierarchy
		then findChild(screenGui, "JoystickRoot")
		else waitForChildIfNeeded(screenGui, "JoystickRoot", UI_WAIT_TIMEOUT)
	local chargeBar = if hasWaitedForHierarchy
		then findChild(screenGui, "ChargeBar")
		else waitForChildIfNeeded(screenGui, "ChargeBar", UI_WAIT_TIMEOUT)
	local directionArrow = if hasWaitedForHierarchy
		then findChild(screenGui, "DirectionArrow")
		else waitForChildIfNeeded(screenGui, "DirectionArrow", UI_WAIT_TIMEOUT)
	local cooldownBar = if hasWaitedForHierarchy
		then findChild(screenGui, "CooldownBar")
		else waitForChildIfNeeded(screenGui, "CooldownBar", UI_WAIT_TIMEOUT)

	local base = if joystickRoot
		then (if hasWaitedForHierarchy then findChild(joystickRoot, "Base") else waitForChildIfNeeded(joystickRoot, "Base", UI_WAIT_TIMEOUT))
		else nil
	local thumb = if joystickRoot
		then (if hasWaitedForHierarchy then findChild(joystickRoot, "Thumb") else waitForChildIfNeeded(joystickRoot, "Thumb", UI_WAIT_TIMEOUT))
		else nil
	local chargeFill = if chargeBar
		then (if hasWaitedForHierarchy then findChild(chargeBar, "Fill") else waitForChildIfNeeded(chargeBar, "Fill", UI_WAIT_TIMEOUT))
		else nil
	local cooldownFill = if cooldownBar
		then (if hasWaitedForHierarchy then findChild(cooldownBar, "Fill") else waitForChildIfNeeded(cooldownBar, "Fill", UI_WAIT_TIMEOUT))
		else nil

	hasWaitedForHierarchy = true

	if not joystickRoot or not base or not thumb or not chargeBar or not chargeFill or not directionArrow then
		warnMissingUiOnce("[SlingUI] SlingUI hierarchy is incomplete. Expected SlingUI > JoystickRoot(Base, Thumb), ChargeBar(Fill), DirectionArrow.")
	end

	cachedJoystickRoot = if joystickRoot and joystickRoot:IsA("GuiObject") then joystickRoot else nil
	if cachedJoystickRoot then
		cachedJoystickRoot.Active = true
	end
	cachedBase = if base and base:IsA("GuiObject") then base else nil
	if cachedBase then
		cachedBase.Active = true
	end
	cachedThumb = if thumb and thumb:IsA("GuiObject") then thumb else nil
	if cachedThumb then
		cachedThumb.Active = true
	end
	cachedChargeBar = if chargeBar and chargeBar:IsA("GuiObject") then chargeBar else nil
	if cachedChargeBar then
		cachedChargeBar.Active = true
	end
	cachedChargeFill = if chargeFill and chargeFill:IsA("Frame") then chargeFill else nil
	cachedDirectionArrow = if directionArrow and directionArrow:IsA("GuiObject") then directionArrow else nil
	cachedCooldownBar = if cooldownBar and cooldownBar:IsA("GuiObject") then cooldownBar else nil
	if cachedCooldownBar then
		cachedCooldownBar.Active = true
	end
	cachedCooldownFill = if cooldownFill and cooldownFill:IsA("Frame") then cooldownFill else nil

	return cachedScreenGui, cachedJoystickRoot, cachedBase, cachedThumb, cachedChargeBar, cachedChargeFill, cachedDirectionArrow, cachedCooldownBar, cachedCooldownFill
end

local function getScreenRayHit(input: InputObject): Instance?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local position = input.Position
	local ray = camera:ViewportPointToRay(position.X, position.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {}

	local result = workspace:Raycast(ray.Origin, ray.Direction * 1024, raycastParams)
	return result and result.Instance or nil
end

local function isSlingInputStart(input: InputObject): boolean
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return false
	end

	local character = player.Character
	if not character then
		return false
	end

	local hitInstance = getScreenRayHit(input)
	if not hitInstance then
		return false
	end

	return hitInstance:IsDescendantOf(character)
end

local function setVisibleSafe(instance: GuiObject?, visible: boolean)
	if instance then
		instance.Visible = visible
	end
end

local function ensureAnchors(joystickRoot: GuiObject?, thumb: GuiObject?)
	if joystickRoot then
		joystickRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	if thumb then
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	end
end

local function updateChargeBar(percent: number)
	local _, _, _, _, chargeBar, chargeFill = resolveUi()
	setVisibleSafe(chargeBar, isHolding or percent > 0)
	if chargeFill then
		chargeFill.Size = UDim2.new(percent, 0, 1, 0)
	end
	local uiBucket = math.floor(percent * 10)
	if uiBucket ~= lastLoggedUiBucket then
		lastLoggedUiBucket = uiBucket
		debugLog(string.format("[Charge] Value = %.2f", percent))
	end
end

local function updateCooldownBar(percent: number)
	local _, _, _, _, _, _, _, cooldownBar, cooldownFill = resolveUi()
	if cooldownFill then
		cooldownFill.Size = UDim2.new(percent, 0, 1, 0)
	end
	setVisibleSafe(cooldownBar, percent > 0)
	local cooldownBucket = math.floor(percent * 10)
	if cooldownBucket ~= lastLoggedCooldownBucket then
		lastLoggedCooldownBucket = cooldownBucket
		debugLog(string.format("[Cooldown] Updating percent=%.2f", percent))
	end
end

local function positionJoystick(inputPosition: Vector2)
	local _, joystickRoot, _, thumb, _, _, directionArrow = resolveUi()
	ensureAnchors(joystickRoot, thumb)

	if joystickRoot then
		joystickRoot.Position = UDim2.new(0, inputPosition.X, 0, inputPosition.Y)
		joystickRoot.ZIndex = 20
	end

	if directionArrow then
		directionArrow.Position = UDim2.new(0, inputPosition.X, 0, inputPosition.Y)
		directionArrow.ZIndex = 21
	end

	if thumb then
		thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	end
end

local function startHold(input: InputObject)
	if isHolding or os.clock() < cooldownEndTime then
		return
	end

	isHolding = true
	inputObject = input
	startPos = getInputPosition(input)
	currentPos = startPos
	currentDelta = Vector2.zero
	charge = 0
	lastLoggedChargeBucket = -1
	loggedMaxCharge = false

	local _, joystickRoot, _, _, chargeBar, _, directionArrow = resolveUi()
	setVisibleSafe(joystickRoot, true)
	setVisibleSafe(chargeBar, true)
	setVisibleSafe(directionArrow, true)
	positionJoystick(startPos)

	debugLog(string.format("[SlingUI] Input start at (%.0f, %.0f)", startPos.X, startPos.Y))
	debugLog("[SlingUI] Holding started")
	debugLog("[Joystick] Input detected")
	debugLog("[SlingUI] StartCharge remote fired")
	startChargeRemote:FireServer(getAimTarget(input))
end

local function updateHold(input: InputObject)
	if not isHolding then
		return
	end
	if inputObject and input ~= inputObject and input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	currentPos = getInputPosition(input)
	local delta = currentPos - startPos
	if delta.Magnitude > MAX_JOYSTICK_DRAG then
		delta = delta.Unit * MAX_JOYSTICK_DRAG
	end
	currentDelta = delta

	local _, joystickRoot, _, thumb, _, _, directionArrow = resolveUi()
	ensureAnchors(joystickRoot, thumb)

	if thumb then
		thumb.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
	end

	if directionArrow then
		directionArrow.Position = joystickRoot and joystickRoot.Position or UDim2.new(0, startPos.X, 0, startPos.Y)
		if delta.Magnitude > 0.001 then
			directionArrow.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
	end

	debugLog(string.format("[Joystick] Delta movement: (%.1f, %.1f)", delta.X, delta.Y))
end

local function releaseHold(input: InputObject)
	if not isHolding then
		return
	end
	if inputObject and input ~= inputObject and input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	isHolding = false
	inputObject = nil

	releaseChargeRemote:FireServer(getAimTarget(input))
	cooldownEndTime = os.clock() + COOLDOWN_DURATION

	local _, joystickRoot, _, thumb, chargeBar, _, directionArrow = resolveUi()
	setVisibleSafe(joystickRoot, false)
	setVisibleSafe(directionArrow, false)
	setVisibleSafe(chargeBar, false)
	if thumb then
		thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	end
	updateChargeBar(0)

	debugLog(string.format("[SlingUI] Holding released after %.2fs", charge))
	debugLog("[SlingUI] ReleaseCharge remote fired")
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if isSlingInputStart(input) then
		startHold(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		updateHold(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		releaseHold(input)
	end
end)

player.CharacterAdded:Connect(function()
	hasWaitedForHierarchy = false
	primeUiCache()
	isHolding = false
	inputObject = nil
	startPos = Vector2.zero
	currentPos = Vector2.zero
	currentDelta = Vector2.zero
	charge = 0
	lastLoggedUiBucket = -1
	lastLoggedCooldownBucket = -1
	updateChargeBar(0)
	updateCooldownBar(0)
end)

RunService.RenderStepped:Connect(function(dt)
	local _, joystickRoot, _, _, _, _, directionArrow = resolveUi()

	if isHolding then
		charge += dt
		local chargeRatio = math.clamp(charge / MAX_CHARGE_TIME, 0, 1)
		updateChargeBar(chargeRatio)

		local bucket = math.floor(chargeRatio * 10)
		if bucket ~= lastLoggedChargeBucket then
			lastLoggedChargeBucket = bucket
			debugLog(string.format("[SlingUI] Charge percent: %.2f", chargeRatio))
		end

		if chargeRatio >= 1 and not loggedMaxCharge then
			loggedMaxCharge = true
			debugLog("[SlingUI] Charge reached max")
		end

		setVisibleSafe(joystickRoot, true)
		setVisibleSafe(directionArrow, true)
	end

	local remaining = math.max(0, cooldownEndTime - os.clock())
	updateCooldownBar(math.clamp(remaining / COOLDOWN_DURATION, 0, 1))
end)

primeUiCache()
local _, joystickRoot, _, thumb, chargeBar, _, directionArrow = resolveUi()
ensureAnchors(joystickRoot, thumb)
setVisibleSafe(joystickRoot, false)
setVisibleSafe(chargeBar, false)
setVisibleSafe(directionArrow, false)
updateChargeBar(0)
updateCooldownBar(0)
