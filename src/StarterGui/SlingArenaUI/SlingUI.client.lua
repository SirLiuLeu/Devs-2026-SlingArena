--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local SlingUiState = require(ReplicatedStorage.Shared.Utils.SlingUiState)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge) :: RemoteEvent
local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge) :: RemoteEvent
local stateUpdateRemote = remotes:FindFirstChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent?

local MAX_CHARGE_TIME = SlingshotConfig.MAX_CHARGE_TIME or 2
local COOLDOWN_DURATION = SlingshotConfig.RECOVER_TIME or 3
local MAX_JOYSTICK_DRAG = 60
local UI_WAIT_TIMEOUT = 2
local DEBUG_LOG = true

local warnedMissingUi = false
local loggedUiResolved = false
local lastResolvedPath: string? = nil
local hasWaitedForHierarchy = false

local isHolding = false
local inputObject: InputObject? = nil
local startPos = Vector2.zero
local currentDelta = Vector2.zero
local chargeStartTime = 0
local cooldownStartTime = 0
local cooldownEndTime = 0
local lastKnownServerState: { [string]: any }? = nil
local uiUpdateConnection: RBXScriptConnection? = nil

local cachedScreenGui: ScreenGui? = nil
local cachedJoystickRoot: GuiObject? = nil
local cachedBase: GuiObject? = nil
local cachedThumb: GuiObject? = nil
local cachedChargeBar: GuiObject? = nil
local cachedChargeFill: GuiObject? = nil
local cachedDirectionIndicator: GuiObject? = nil
local cachedCooldownBar: GuiObject? = nil
local cachedCooldownFill: GuiObject? = nil

-- [UI_CREATION_GUIDE]
-- Create in Studio:
-- StarterGui
--   SlingArenaUI (Folder)
--     SlingUI (ScreenGui)
--       JoystickRoot (Frame)
--         Base (Frame)
--         Thumb (Frame)
--       ChargeBar (Frame)
--         Fill (Frame)
--       CooldownBar (Frame)
--         Fill (Frame)
--       DirectionIndicator (ImageLabel)
-- Optional compatibility alias:
-- StarterGui.SlingArenaUI.SlingUI.DirectionArrow (ImageLabel)

local function debugLog(message: string)
	if DEBUG_LOG then
		-- print(message)
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

	local ok, result = pcall(function()
		return parent:WaitForChild(childName, timeout)
	end)
	if ok then
		return result
	end

	return nil
end

local function findChild(parent: Instance?, childName: string): Instance?
	if not parent then
		return nil
	end
	return parent:FindFirstChild(childName)
end

local function logUiResolvedOnce(screenGui: ScreenGui)
	if loggedUiResolved and lastResolvedPath == screenGui:GetFullName() then
		return
	end

	loggedUiResolved = true
	lastResolvedPath = screenGui:GetFullName()
	print(string.format("[SlingUI] UI resolved: %s", lastResolvedPath))
end

local function warnMissingUiOnce(message: string)
	if warnedMissingUi then
		return
	end

	warnedMissingUi = true
	warn(message)
	warn("[UI_CREATION_GUIDE] Required path: StarterGui.SlingArenaUI.SlingUI.JoystickRoot(Base, Thumb), ChargeBar(Fill), CooldownBar(Fill), DirectionIndicator. Compatibility alias supported: DirectionArrow.")
end

local function getMouseWorld(): Vector3
	local mouse = player:GetMouse()
	if mouse.Hit then
		return mouse.Hit.Position
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
	if cachedScreenGui then
		warnedMissingUi = false
		logUiResolvedOnce(cachedScreenGui)
	end
end

local function resolveScreenGui(): ScreenGui?
	if cachedScreenGui and cachedScreenGui.Parent then
		return cachedScreenGui
	end

	cachedScreenGui = findPreferredScreenGui(false)
	if cachedScreenGui then
		warnedMissingUi = false
		logUiResolvedOnce(cachedScreenGui)
	end
	return cachedScreenGui
end

local function resolveDirectionIndicator(screenGui: ScreenGui, waitForUi: boolean): Instance?
	local indicator = if waitForUi
		then waitForChildIfNeeded(screenGui, "DirectionIndicator", UI_WAIT_TIMEOUT)
		else findChild(screenGui, "DirectionIndicator")
	if indicator then
		return indicator
	end

	return if waitForUi
		then waitForChildIfNeeded(screenGui, "DirectionArrow", UI_WAIT_TIMEOUT)
		else findChild(screenGui, "DirectionArrow")
end

local function resolveUi(): (ScreenGui?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?)
	local screenGui = resolveScreenGui()
	if not screenGui then
		warnMissingUiOnce("[SlingUI] Missing SlingUI ScreenGui at PlayerGui.SlingArenaUI.SlingUI.")
		return nil, nil, nil, nil, nil, nil, nil, nil, nil
	end

	screenGui.Enabled = true
	debugLog("[SlingUI] Loaded successfully")
	cachedScreenGui = screenGui

	local shouldWait = not hasWaitedForHierarchy
	local joystickRoot = if shouldWait
		then waitForChildIfNeeded(screenGui, "JoystickRoot", UI_WAIT_TIMEOUT)
		else findChild(screenGui, "JoystickRoot")
	local chargeBar = if shouldWait
		then waitForChildIfNeeded(screenGui, "ChargeBar", UI_WAIT_TIMEOUT)
		else findChild(screenGui, "ChargeBar")
	local cooldownBar = if shouldWait
		then waitForChildIfNeeded(screenGui, "CooldownBar", UI_WAIT_TIMEOUT)
		else findChild(screenGui, "CooldownBar")
	local directionIndicator = resolveDirectionIndicator(screenGui, shouldWait)

	local base = if joystickRoot
		then (if shouldWait then waitForChildIfNeeded(joystickRoot, "Base", UI_WAIT_TIMEOUT) else findChild(joystickRoot, "Base"))
		else nil
	local thumb = if joystickRoot
		then (if shouldWait then waitForChildIfNeeded(joystickRoot, "Thumb", UI_WAIT_TIMEOUT) else findChild(joystickRoot, "Thumb"))
		else nil
	local chargeFill = if chargeBar
		then (if shouldWait then waitForChildIfNeeded(chargeBar, "Fill", UI_WAIT_TIMEOUT) else findChild(chargeBar, "Fill"))
		else nil
	local cooldownFill = if cooldownBar
		then (if shouldWait then waitForChildIfNeeded(cooldownBar, "Fill", UI_WAIT_TIMEOUT) else findChild(cooldownBar, "Fill"))
		else nil

	hasWaitedForHierarchy = true

	if not joystickRoot or not base or not thumb or not chargeBar or not chargeFill or not cooldownBar or not cooldownFill or not directionIndicator then
		warnMissingUiOnce("[SlingUI] SlingUI hierarchy is incomplete. Expected SlingUI > JoystickRoot(Base, Thumb), ChargeBar(Fill), CooldownBar(Fill), DirectionIndicator or DirectionArrow.")
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

	return cachedScreenGui, cachedJoystickRoot, cachedBase, cachedThumb, cachedChargeBar, cachedChargeFill, cachedDirectionIndicator, cachedCooldownBar, cachedCooldownFill
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
	local normalized = SlingUiState.ClampRatio(percent)
	setVisibleSafe(chargeBar, isHolding or normalized > 0)
	if chargeFill then
		chargeFill.Size = UDim2.new(normalized, 0, 1, 0)
	end
end

local function updateCooldownBar(percent: number)
	local _, _, _, _, _, _, _, cooldownBar, cooldownFill = resolveUi()
	local normalized = SlingUiState.ClampRatio(percent)
	if cooldownFill then
		cooldownFill.Size = UDim2.new(normalized, 0, 1, 0)
	end
	setVisibleSafe(cooldownBar, normalized > 0 and normalized < 1)
end

local function resetThumbPosition()
	if cachedThumb then
		cachedThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	end
end

local function updateDirectionIndicator(position: UDim2, rotation: number?)
	local _, _, _, _, _, _, directionIndicator = resolveUi()
	if directionIndicator then
		directionIndicator.Position = position
		if rotation ~= nil then
			directionIndicator.Rotation = rotation
		end
	end
end

local function positionJoystick(inputPosition: Vector2)
	local _, joystickRoot, _, thumb = resolveUi()
	ensureAnchors(joystickRoot, thumb)

	if joystickRoot then
		joystickRoot.Position = UDim2.new(0, inputPosition.X, 0, inputPosition.Y)
		joystickRoot.ZIndex = 20
	end

	updateDirectionIndicator(UDim2.new(0, inputPosition.X, 0, inputPosition.Y), nil)
	resetThumbPosition()
end

local function stopUiLoopIfIdle()
	if isHolding then
		return
	end
	if os.clock() < cooldownEndTime then
		return
	end
	if uiUpdateConnection then
		uiUpdateConnection:Disconnect()
		uiUpdateConnection = nil
	end
end

local function stepUi()
	if isHolding then
		local chargeRatio = SlingUiState.ComputeChargeRatio(os.clock() - chargeStartTime, MAX_CHARGE_TIME)
		updateChargeBar(chargeRatio)
		setVisibleSafe(cachedJoystickRoot, true)
		setVisibleSafe(cachedDirectionIndicator, true)
	else
		updateChargeBar(0)
	end

	local cooldownRatio = 0
	if cooldownEndTime > cooldownStartTime and os.clock() < cooldownEndTime then
		cooldownRatio = SlingUiState.ComputeCooldownRatio(os.clock() - cooldownStartTime, cooldownEndTime - cooldownStartTime)
	end
	updateCooldownBar(cooldownRatio)
	stopUiLoopIfIdle()
end

local function ensureUiLoopRunning()
	if uiUpdateConnection then
		return
	end

	uiUpdateConnection = RunService.RenderStepped:Connect(function()
		stepUi()
	end)
end

local function beginCooldown(duration: number)
	cooldownStartTime = os.clock()
	cooldownEndTime = cooldownStartTime + math.max(duration, 0)
	updateCooldownBar(0)
	ensureUiLoopRunning()
end

local function clearCooldown()
	cooldownStartTime = 0
	cooldownEndTime = 0
	updateCooldownBar(0)
	stopUiLoopIfIdle()
end

local function resetVisualState()
	isHolding = false
	inputObject = nil
	startPos = Vector2.zero
	currentDelta = Vector2.zero
	chargeStartTime = 0
	setVisibleSafe(cachedJoystickRoot, false)
	setVisibleSafe(cachedChargeBar, false)
	setVisibleSafe(cachedDirectionIndicator, false)
	resetThumbPosition()
	updateChargeBar(0)
	clearCooldown()
end

local function startHold(input: InputObject)
	if isHolding then
		return
	end
	if os.clock() < cooldownEndTime then
		return
	end

	isHolding = true
	inputObject = input
	startPos = getInputPosition(input)
	currentDelta = Vector2.zero
	chargeStartTime = os.clock()

	resolveUi()
	setVisibleSafe(cachedJoystickRoot, true)
	setVisibleSafe(cachedChargeBar, true)
	setVisibleSafe(cachedDirectionIndicator, true)
	positionJoystick(startPos)
	updateChargeBar(0)
	ensureUiLoopRunning()

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

	local currentPos = getInputPosition(input)
	local delta = currentPos - startPos
	if delta.Magnitude > MAX_JOYSTICK_DRAG then
		delta = delta.Unit * MAX_JOYSTICK_DRAG
	end
	currentDelta = delta

	local _, joystickRoot, _, thumb = resolveUi()
	ensureAnchors(joystickRoot, thumb)

	if thumb then
		thumb.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
	end

	local rotation = SlingUiState.ComputeDirectionRotation(delta)
	local indicatorPosition = if joystickRoot then joystickRoot.Position else UDim2.new(0, startPos.X, 0, startPos.Y)
	updateDirectionIndicator(indicatorPosition, rotation)
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
	beginCooldown(COOLDOWN_DURATION)

	setVisibleSafe(cachedJoystickRoot, false)
	setVisibleSafe(cachedDirectionIndicator, false)
	setVisibleSafe(cachedChargeBar, false)
	resetThumbPosition()
	updateChargeBar(0)

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

if stateUpdateRemote then
	stateUpdateRemote.OnClientEvent:Connect(function(state)
		lastKnownServerState = state
		if not state then
			return
		end

		if state.IsAlive == false then
			resetVisualState()
			return
		end

		if state.IsCharging == false and isHolding == false and (state.MovementState == "Launched" or state.MovementState == "Recovering") then
			if cooldownEndTime <= os.clock() then
				beginCooldown(COOLDOWN_DURATION)
			end
		end
	end)
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name ~= "SlingUI" and descendant.Name ~= "DirectionIndicator" and descendant.Name ~= "DirectionArrow" and descendant.Name ~= "ChargeBar" and descendant.Name ~= "CooldownBar" then
		return
	end

	resolveUi()
	if lastKnownServerState and lastKnownServerState.IsAlive == false then
		resetVisualState()
	end
end)

player.CharacterAdded:Connect(function()
	hasWaitedForHierarchy = false
	primeUiCache()
	resolveUi()
	resetVisualState()
end)

primeUiCache()
resolveUi()
resetVisualState()
