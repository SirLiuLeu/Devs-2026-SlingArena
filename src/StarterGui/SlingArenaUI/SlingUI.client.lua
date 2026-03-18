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

local function debugLog(message: string)
	if DEBUG_LOG then
		print(message)
	end
end

local function waitForChildIfNeeded(parent: Instance?, childName: string, timeout: number): Instance?
	if not parent then
		return nil
	end

	local existing = parent:FindFirstChild(childName)
	if existing then
		return existing
	end

	return parent:WaitForChild(childName, timeout)
end

local function findChild(parent: Instance?, childName: string): Instance?
	if not parent then
		return nil
	end
	return parent:FindFirstChild(childName)
end

local function getMouseWorld(): Vector3
	local mouse = player:GetMouse()
	if mouse.Hit then
		return mouse.Hit.Position
	end
	return Vector3.new(0, 0, -1)
end

local function getInputPosition(input: InputObject?): Vector2
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return Vector2.zero
end

local function warnMissingUiOnce(message: string)
	if warnedMissingUi then
		return
	end
	warnedMissingUi = true
	warn(message)
	warn("[UI_CREATION_GUIDE] Create StarterGui > SlingUI (ScreenGui) > JoystickRoot(Base, Thumb), ChargeBar(Fill), DirectionArrow. Optional: CooldownBar(Fill).")
end

local function primeUiCache()
	local directScreen = waitForChildIfNeeded(playerGui, "SlingUI", UI_WAIT_TIMEOUT)
	if directScreen and directScreen:IsA("ScreenGui") then
		cachedScreenGui = directScreen
	end

	if not cachedScreenGui then
		local legacyContainer = waitForChildIfNeeded(playerGui, "SlingArenaUI", UI_WAIT_TIMEOUT)
		local nestedScreen = waitForChildIfNeeded(legacyContainer, "SlingUI", UI_WAIT_TIMEOUT)
		if nestedScreen and nestedScreen:IsA("ScreenGui") then
			cachedScreenGui = nestedScreen
		end
	end

	if not cachedScreenGui then
		local scriptParent = script.Parent
		if scriptParent and scriptParent:IsA("ScreenGui") and scriptParent.Name == "SlingUI" then
			cachedScreenGui = scriptParent
		else
			local childOfScriptParent = waitForChildIfNeeded(scriptParent, "SlingUI", UI_WAIT_TIMEOUT)
			if childOfScriptParent and childOfScriptParent:IsA("ScreenGui") then
				cachedScreenGui = childOfScriptParent
			end
		end
	end
end

local function resolveScreenGui(): ScreenGui?
	if cachedScreenGui and cachedScreenGui.Parent then
		return cachedScreenGui
	end

	local directScreen = findChild(playerGui, "SlingUI")
	if directScreen and directScreen:IsA("ScreenGui") then
		cachedScreenGui = directScreen
		return cachedScreenGui
	end

	local legacyContainer = findChild(playerGui, "SlingArenaUI")
	local nestedScreen = findChild(legacyContainer, "SlingUI")
	if nestedScreen and nestedScreen:IsA("ScreenGui") then
		cachedScreenGui = nestedScreen
		return cachedScreenGui
	end

	local scriptParent = script.Parent
	if scriptParent and scriptParent:IsA("ScreenGui") and scriptParent.Name == "SlingUI" then
		cachedScreenGui = scriptParent
		return cachedScreenGui
	end

	local childOfScriptParent = findChild(scriptParent, "SlingUI")
	if childOfScriptParent and childOfScriptParent:IsA("ScreenGui") then
		cachedScreenGui = childOfScriptParent
		return cachedScreenGui
	end

	return nil
end

local function resolveUi()
	local screenGui = resolveScreenGui()
	if not screenGui then
		warnMissingUiOnce("[SlingUI] Missing SlingUI ScreenGui in PlayerGui.")
		return nil, nil, nil, nil, nil, nil, nil, nil, nil
	end

	screenGui.Enabled = true
	cachedScreenGui = screenGui

	local joystickRoot = findChild(screenGui, "JoystickRoot")
	local chargeBar = findChild(screenGui, "ChargeBar")
	local directionArrow = findChild(screenGui, "DirectionArrow")
	local cooldownBar = findChild(screenGui, "CooldownBar")

	local base = joystickRoot and findChild(joystickRoot, "Base") or nil
	local thumb = joystickRoot and findChild(joystickRoot, "Thumb") or nil
	local chargeFill = chargeBar and findChild(chargeBar, "Fill") or nil
	local cooldownFill = cooldownBar and findChild(cooldownBar, "Fill") or nil

	if not joystickRoot or not base or not thumb or not chargeBar or not chargeFill or not directionArrow then
		warnMissingUiOnce("[SlingUI] SlingUI hierarchy is incomplete. Expected SlingUI > JoystickRoot(Base, Thumb), ChargeBar(Fill), DirectionArrow.")
	end

	cachedJoystickRoot = if joystickRoot and joystickRoot:IsA("GuiObject") then joystickRoot else nil
	cachedBase = if base and base:IsA("GuiObject") then base else nil
	cachedThumb = if thumb and thumb:IsA("GuiObject") then thumb else nil
	cachedChargeBar = if chargeBar and chargeBar:IsA("GuiObject") then chargeBar else nil
	cachedChargeFill = if chargeFill and chargeFill:IsA("Frame") then chargeFill else nil
	cachedDirectionArrow = if directionArrow and directionArrow:IsA("GuiObject") then directionArrow else nil
	cachedCooldownBar = if cooldownBar and cooldownBar:IsA("GuiObject") then cooldownBar else nil
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
end

local function updateCooldownBar(percent: number)
	local _, _, _, _, _, _, _, cooldownBar, cooldownFill = resolveUi()
	if cooldownFill then
		cooldownFill.Size = UDim2.new(percent, 0, 1, 0)
	end
	setVisibleSafe(cooldownBar, percent > 0)
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
	startChargeRemote:FireServer(getMouseWorld())
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

	debugLog(string.format("[SlingUI] Delta movement: (%.1f, %.1f)", delta.X, delta.Y))
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

	releaseChargeRemote:FireServer(getMouseWorld())
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
	primeUiCache()
	isHolding = false
	inputObject = nil
	startPos = Vector2.zero
	currentPos = Vector2.zero
	currentDelta = Vector2.zero
	charge = 0
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
