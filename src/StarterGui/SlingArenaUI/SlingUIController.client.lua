--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local SlingUiState = require(ReplicatedStorage.Shared.Utils.SlingUiState)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge) :: RemoteEvent
local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge) :: RemoteEvent
local stateUpdateRemote = remotes:FindFirstChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent?

local MAX_CHARGE_TIME = SlingshotConfig.MAX_CHARGE_TIME or 2
local DEFAULT_COOLDOWN_DURATION = SlingshotConfig.RECOVER_TIME or 3
local MAX_JOYSTICK_DRAG = 60
local DEBUG_LOG = false

local warnedMissingUi = false
local loggedUiResolved = false
local lastResolvedPath: string? = nil

local isHolding = false
local awaitingReleaseAck = false
local inputObject: InputObject? = nil
local startPos = Vector2.zero
local currentDelta = Vector2.zero
local chargeStartTime = 0
local cooldownStartTime = 0
local cooldownEndTime = 0
local cooldownDuration = DEFAULT_COOLDOWN_DURATION
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
		print(message)
	end
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

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart.Position + rootPart.CFrame.LookVector * 8
	end

	return Vector3.zero
end

local function getInputPosition(input: InputObject?): Vector2
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return Vector2.zero
end

local function getAimTarget(input: InputObject?): Vector3
	if input and input.UserInputType == Enum.UserInputType.Touch then
		local camera = workspace.CurrentCamera
		if camera then
			local position = input.Position
			local ray = camera:ViewportPointToRay(position.X, position.Y)
			return ray.Origin + ray.Direction * 256
		end
	end

	return getMouseWorld()
end

local function findPreferredScreenGui(): ScreenGui?
	debugLog("[SlingUI] Resolving UI path without timeout")

	local screenGui = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.SlingTouch.ScreenGui, {
		shouldWarn = false,
	})
	if screenGui and screenGui:IsA("ScreenGui") then
		return screenGui
	end

	debugLog("[SlingUI] PlayerGui.SlingArenaUI.SlingUI not ready")
	return nil
end

local function resolveScreenGui(): ScreenGui?
	if cachedScreenGui and cachedScreenGui.Parent then
		return cachedScreenGui
	end

	cachedScreenGui = findPreferredScreenGui()
	if cachedScreenGui then
		warnedMissingUi = false
		logUiResolvedOnce(cachedScreenGui)
	end
	return cachedScreenGui
end

local function resolveDirectionIndicator(screenGui: ScreenGui): Instance?
	local indicator = findChild(screenGui, "DirectionIndicator")
	if indicator then
		return indicator
	end

	return findChild(screenGui, "DirectionArrow")
end

local function resolveUi(): (ScreenGui?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?)
	local screenGui = resolveScreenGui()
	if not screenGui then
		warnMissingUiOnce("[SlingUI] Missing SlingUI ScreenGui at PlayerGui.SlingArenaUI.SlingUI.")
		return nil, nil, nil, nil, nil, nil, nil, nil, nil
	end

	screenGui.Enabled = true
	cachedScreenGui = screenGui

	local joystickRoot = findChild(screenGui, "JoystickRoot")
	local chargeBar = findChild(screenGui, "ChargeBar")
	local cooldownBar = findChild(screenGui, "CooldownBar")
	local directionIndicator = resolveDirectionIndicator(screenGui)

	local base = if joystickRoot then findChild(joystickRoot, "Base") else nil
	local thumb = if joystickRoot then findChild(joystickRoot, "Thumb") else nil
	local chargeFill = if chargeBar then findChild(chargeBar, "Fill") else nil
	local cooldownFill = if cooldownBar then findChild(cooldownBar, "Fill") else nil

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
	cachedChargeFill = if chargeFill and chargeFill:IsA("GuiObject") then chargeFill else nil
	cachedDirectionIndicator = if directionIndicator and directionIndicator:IsA("GuiObject") then directionIndicator else nil
	cachedCooldownBar = if cooldownBar and cooldownBar:IsA("GuiObject") then cooldownBar else nil
	if cachedCooldownBar then
		cachedCooldownBar.Active = true
	end
	cachedCooldownFill = if cooldownFill and cooldownFill:IsA("GuiObject") then cooldownFill else nil

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
		cooldownRatio = SlingUiState.ComputeCooldownRatio(os.clock() - cooldownStartTime, cooldownDuration)
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

local function beginCooldown(duration: number, endTime: number?)
	cooldownDuration = math.max(duration, 0)
	if endTime and endTime > 0 then
		cooldownEndTime = endTime
		cooldownStartTime = cooldownEndTime - cooldownDuration
	else
		cooldownStartTime = os.clock()
		cooldownEndTime = cooldownStartTime + cooldownDuration
	end
	updateCooldownBar(0)
	ensureUiLoopRunning()
end

local function clearCooldown()
	cooldownStartTime = 0
	cooldownEndTime = 0
	cooldownDuration = DEFAULT_COOLDOWN_DURATION
	updateCooldownBar(0)
	stopUiLoopIfIdle()
end

local function resetVisualState()
	isHolding = false
	awaitingReleaseAck = false
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

local function syncCooldownFromServerState(state: { [string]: any })
	local serverCooldownEnd = state.CooldownEndTime
	if typeof(serverCooldownEnd) ~= "number" or serverCooldownEnd <= os.clock() then
		if not isHolding then
			clearCooldown()
		end
		return
	end

	beginCooldown(DEFAULT_COOLDOWN_DURATION, serverCooldownEnd)
end

local function startHold(input: InputObject)
	if isHolding then
		return
	end
	if os.clock() < cooldownEndTime then
		return
	end

	isHolding = true
	awaitingReleaseAck = false
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
	awaitingReleaseAck = true
	inputObject = nil

	releaseChargeRemote:FireServer(getAimTarget(input))

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

		if state.IsCharging == false and isHolding == true then
			isHolding = false
			updateChargeBar(0)
		end

		if state.MovementState == "Launched" or state.MovementState == "Recovering" then
			awaitingReleaseAck = false
			syncCooldownFromServerState(state)
		elseif state.MovementState == "Idle" and awaitingReleaseAck == false and state.IsCharging ~= true then
			clearCooldown()
		end
	end)
end

playerGui.DescendantAdded:Connect(function(descendant)
	if descendant.Name ~= "SlingUI" and descendant.Name ~= "DirectionIndicator" and descendant.Name ~= "DirectionArrow" and descendant.Name ~= "ChargeBar" and descendant.Name ~= "CooldownBar" and descendant.Name ~= "Fill" and descendant.Name ~= "JoystickRoot" and descendant.Name ~= "Base" and descendant.Name ~= "Thumb" then
		return
	end

	resolveUi()
	if lastKnownServerState and lastKnownServerState.IsAlive == false then
		resetVisualState()
	elseif lastKnownServerState and (lastKnownServerState.MovementState == "Launched" or lastKnownServerState.MovementState == "Recovering") then
		syncCooldownFromServerState(lastKnownServerState)
	end
end)

player.CharacterAdded:Connect(function()
	resolveUi()
	resetVisualState()
end)

resolveUi()
resetVisualState()
