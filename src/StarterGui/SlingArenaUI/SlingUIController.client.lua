--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingUiConstants = require(ReplicatedStorage.Shared.Constants.SlingUiConstants)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local SlingUiState = require(ReplicatedStorage.Shared.Utils.SlingUiState)
local WaitForUI = require(ReplicatedStorage.Shared.Utils.WaitForUI)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge) :: RemoteEvent
local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge) :: RemoteEvent
local stateUpdateRemote = remotes:FindFirstChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent?
local prefabsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Prefabs")

local MAX_CHARGE_TIME = SlingshotConfig.MAX_CHARGE_TIME or 2
local DEFAULT_COOLDOWN_DURATION = SlingshotConfig.RECOVER_TIME or 3
local DEFAULT_JOYSTICK_RADIUS = 60
local ARROW_FORWARD_OFFSET = 4
local DEBUG_LOG = false

local warnedMissingUi = false
local loggedUiResolved = false
local lastResolvedPath: string? = nil
local uiInputBound = false
local boundJoystickRoot: GuiObject? = nil
local boundInputRegion: GuiObject? = nil

local isHolding = false
local awaitingReleaseAck = false
local inputObject: InputObject? = nil
local currentDragVector = Vector2.zero
local currentDragDistance = 0
local currentDirection = Vector2.new(0, -1)
local currentChargeAimDirection = Vector3.new(0, 0, -1)
local chargeReferenceFrame: CFrame? = nil
local chargeStartTime = 0
local cooldownStartTime = 0
local cooldownEndTime = 0
local cooldownDuration = DEFAULT_COOLDOWN_DURATION
local lastKnownServerState: { [string]: any }? = nil
local uiUpdateConnection: RBXScriptConnection? = nil
local arrowPreview: Model? = nil

local joystickInputBeganConnection: RBXScriptConnection? = nil
local joystickInputChangedConnection: RBXScriptConnection? = nil
local joystickInputEndedConnection: RBXScriptConnection? = nil

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
	debugLog(string.format("[SlingUI] UI resolved: %s", lastResolvedPath))
end

local function warnMissingUiOnce(message: string)
	if warnedMissingUi then
		return
	end

	warnedMissingUi = true
	warn(message)
	warn("[UI_CREATION_GUIDE] Required path: StarterGui.SlingArenaUI.SlingUI.JoystickRoot(Base, Thumb), ChargeBar(Fill), CooldownBar(Fill), DirectionIndicator. Compatibility alias supported: DirectionArrow.")
end

local function setVisibleSafe(instance: GuiObject?, visible: boolean)
	if instance then
		instance.Visible = visible
	end
end

local function shouldShowJoystickByState(state: { [string]: any }?): boolean
	if state and state.IsAlive == false then
		return false
	end

	local movementState = if state then state.MovementState else nil
	if movementState == GameStates.Movement.Recovering or movementState == GameStates.Movement.Launched then
		return false
	end

	if awaitingReleaseAck then
		return false
	end

	return true
end

local function applyJoystickVisibilityFromState(state: { [string]: any }?)
	local showJoystick = shouldShowJoystickByState(state)
	setVisibleSafe(cachedJoystickRoot, showJoystick)
	setVisibleSafe(cachedDirectionIndicator, showJoystick)
end

local function ensureAnchors(joystickRoot: GuiObject?, base: GuiObject?, thumb: GuiObject?)
	if joystickRoot then
		joystickRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	if base then
		base.AnchorPoint = Vector2.new(0.5, 0.5)
		base.Position = UDim2.new(0.5, 0, 0.5, 0)
	end
	if thumb then
		thumb.AnchorPoint = Vector2.new(0.5, 0.5)
	end
end

local function resolveDirectionIndicator(screenGui: ScreenGui): Instance?
	local indicator = findChild(screenGui, SlingUiConstants.Elements.DirectionIndicator)
	if indicator then
		return indicator
	end

	return findChild(screenGui, SlingUiConstants.Elements.DirectionArrow)
end

local function disconnectUiInputConnections()
	if joystickInputBeganConnection then
		joystickInputBeganConnection:Disconnect()
		joystickInputBeganConnection = nil
	end
	if joystickInputChangedConnection then
		joystickInputChangedConnection:Disconnect()
		joystickInputChangedConnection = nil
	end
	if joystickInputEndedConnection then
		joystickInputEndedConnection:Disconnect()
		joystickInputEndedConnection = nil
	end
	uiInputBound = false
	boundJoystickRoot = nil
	boundInputRegion = nil
end

local function getJoystickRadius(): number
	if cachedBase then
		return math.max(8, math.min(cachedBase.AbsoluteSize.X, cachedBase.AbsoluteSize.Y) * 0.5)
	end
	return DEFAULT_JOYSTICK_RADIUS
end

local function getBaseCenter(): Vector2
	if not cachedBase then
		return Vector2.zero
	end
	return cachedBase.AbsolutePosition + (cachedBase.AbsoluteSize * 0.5)
end

local function resolveScreenGui(waitForUi: boolean): ScreenGui?
	if cachedScreenGui and cachedScreenGui.Parent then
		return cachedScreenGui
	end

	cachedScreenGui = WaitForUI.ResolveSlingUIWithRetry(player, {
		wait = waitForUi,
		timeout = if waitForUi then 5 else 0,
		onResolved = function(screenGui)
			cachedScreenGui = screenGui
			warnedMissingUi = false
			logUiResolvedOnce(screenGui)
		end,
	})

	if cachedScreenGui then
		warnedMissingUi = false
		logUiResolvedOnce(cachedScreenGui)
	end

	return cachedScreenGui
end

local function resolveUi(waitForUi: boolean?): (ScreenGui?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?)
	local screenGui = resolveScreenGui(if waitForUi == nil then false else waitForUi)
	if not screenGui then
		if WaitForUI.IsRetryPending(player) and waitForUi ~= true then
			return nil, nil, nil, nil, nil, nil, nil, nil, nil
		end
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
	cachedBase = if base and base:IsA("GuiObject") then base else nil
	cachedThumb = if thumb and thumb:IsA("GuiObject") then thumb else nil
	cachedChargeBar = if chargeBar and chargeBar:IsA("GuiObject") then chargeBar else nil
	cachedChargeFill = if chargeFill and chargeFill:IsA("GuiObject") then chargeFill else nil
	cachedDirectionIndicator = if directionIndicator and directionIndicator:IsA("GuiObject") then directionIndicator else nil
	cachedCooldownBar = if cooldownBar and cooldownBar:IsA("GuiObject") then cooldownBar else nil
	cachedCooldownFill = if cooldownFill and cooldownFill:IsA("GuiObject") then cooldownFill else nil

	ensureAnchors(cachedJoystickRoot, cachedBase, cachedThumb)

	if cachedJoystickRoot then
		cachedJoystickRoot.Active = true
	end
	if cachedBase then
		cachedBase.Active = true
	end
	if cachedThumb then
		cachedThumb.Active = false
	end

	return cachedScreenGui, cachedJoystickRoot, cachedBase, cachedThumb, cachedChargeBar, cachedChargeFill, cachedDirectionIndicator, cachedCooldownBar, cachedCooldownFill
end

local function getBoundInputRegion(): GuiObject?
	if cachedBase and cachedBase.Active then
		return cachedBase
	end
	return cachedJoystickRoot
end

local function updateChargeBar(percent: number)
	local _, _, _, _, chargeBar, chargeFill = resolveUi(false)
	local normalized = SlingUiState.ClampRatio(percent)
	setVisibleSafe(chargeBar, isHolding or normalized > 0)
	if chargeFill then
		chargeFill.Size = UDim2.new(normalized, 0, 1, 0)
	end
end

local function updateCooldownBar(percent: number)
	local _, _, _, _, _, _, _, cooldownBar, cooldownFill = resolveUi(false)
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

local function updateDirectionIndicator(rotation: number?)
	local _, _, _, _, _, _, directionIndicator = resolveUi(false)
	if directionIndicator then
		directionIndicator.Position = UDim2.new(0, getBaseCenter().X, 0, getBaseCenter().Y)
		if rotation ~= nil then
			directionIndicator.Rotation = rotation
		end
	end
end

local function clampDragToRadius(rawVector: Vector2): (Vector2, number, Vector2)
	local radius = getJoystickRadius()
	local distance = rawVector.Magnitude
	if distance <= 0.001 then
		return Vector2.zero, 0, currentDirection
	end

	local direction = rawVector.Unit
	local clampedDistance = math.min(distance, radius)
	return direction * clampedDistance, clampedDistance, direction
end

local function getCharacterRoot(): BasePart?
	return PawnLocator.GetRootPart(PawnLocator.GetLocalPawn())
end

local function getLaunchDirectionFromRoot(root: BasePart): Vector3
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return forward.Unit
end

local function resolveChargeAimDirection(root: BasePart): Vector3
	local reference = chargeReferenceFrame
	if not reference then
		return getLaunchDirectionFromRoot(root)
	end

	local right = Vector3.new(reference.RightVector.X, 0, reference.RightVector.Z)
	local forward = Vector3.new(reference.LookVector.X, 0, reference.LookVector.Z)
	if right.Magnitude < 0.001 or forward.Magnitude < 0.001 then
		return getLaunchDirectionFromRoot(root)
	end

	if currentDragDistance <= 0.001 then
		return getLaunchDirectionFromRoot(root)
	end

	local worldDirection = (right.Unit * currentDirection.X) + (forward.Unit * -currentDirection.Y)
	local planarDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)
	if planarDirection.Magnitude < 0.001 then
		return getLaunchDirectionFromRoot(root)
	end

	return planarDirection.Unit
end

local function destroyArrowPreview()
	if arrowPreview then
		arrowPreview:Destroy()
		arrowPreview = nil
	end
end

local function updateArrowPreview()
	if not isHolding then
		destroyArrowPreview()
		return
	end

	local root = getCharacterRoot()
	if not root then
		destroyArrowPreview()
		return
	end

	if not arrowPreview then
		local arrowTemplate = prefabsFolder:FindFirstChild("ArrowModel")
		if not arrowTemplate or not arrowTemplate:IsA("Model") then
			warn("[SlingUI] Missing ReplicatedStorage.Assets.Prefabs.ArrowModel for local charge preview.")
			return
		end

		arrowPreview = arrowTemplate:Clone()
		arrowPreview.Name = "LocalChargeArrowPreview"
		arrowPreview.Parent = workspace.CurrentCamera or workspace
	end

	local direction = currentChargeAimDirection
	local origin = root.Position + (direction * ARROW_FORWARD_OFFSET)
	arrowPreview:PivotTo(CFrame.lookAt(origin, origin + direction, Vector3.yAxis))
end

local function updateJoystickFromInput(input: InputObject)
	if not cachedBase or not cachedThumb then
		resolveUi(false)
	end
	if not cachedBase or not cachedThumb then
		return
	end

	local rawVector = Vector2.new(input.Position.X, input.Position.Y) - getBaseCenter()
	local clampedVector, distance, direction = clampDragToRadius(rawVector)
	currentDragVector = clampedVector
	currentDragDistance = distance
	currentDirection = direction
	local root = getCharacterRoot()
	if root then
		currentChargeAimDirection = resolveChargeAimDirection(root)
		player:SetAttribute("SlingAimDirection", currentChargeAimDirection)
	end
	cachedThumb.Position = UDim2.new(0.5, clampedVector.X, 0.5, clampedVector.Y)
	updateDirectionIndicator(SlingUiState.ComputeDirectionRotation(clampedVector))
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
	else
		updateChargeBar(0)
	end
	updateArrowPreview()

	applyJoystickVisibilityFromState(lastKnownServerState)

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
	currentDragVector = Vector2.zero
	currentDragDistance = 0
	currentDirection = Vector2.new(0, -1)
	currentChargeAimDirection = Vector3.new(0, 0, -1)
	chargeReferenceFrame = nil
	chargeStartTime = 0
	setVisibleSafe(cachedChargeBar, false)
	resetThumbPosition()
	updateChargeBar(0)
	destroyArrowPreview()
	clearCooldown()
	player:SetAttribute("SlingAimDirection", nil)
	applyJoystickVisibilityFromState(lastKnownServerState)
end

local function syncCooldownFromServerState(state: { [string]: any })
	local serverCooldownEnd = state.CooldownEndTime
	if typeof(serverCooldownEnd) ~= "number" or serverCooldownEnd <= os.clock() then
		if not isHolding then
			clearCooldown()
		end
		return
	end

	local releaseDuration = state.LastReleaseDuration
	local resolvedDuration = if typeof(releaseDuration) == "number" and releaseDuration > 0 then releaseDuration else DEFAULT_COOLDOWN_DURATION
	beginCooldown(resolvedDuration, serverCooldownEnd)
end

local function startHold(input: InputObject)
	if isHolding then
		return
	end
	if os.clock() < cooldownEndTime then
		return
	end

	local _, joystickRoot, _, _, chargeBar = resolveUi(false)
	if not joystickRoot then
		return
	end

	isHolding = true
	awaitingReleaseAck = false
	inputObject = input
	currentDragVector = Vector2.zero
	currentDragDistance = 0
	currentChargeAimDirection = Vector3.new(0, 0, -1)
	chargeStartTime = os.clock()
	chargeReferenceFrame = nil

	setVisibleSafe(joystickRoot, true)
	setVisibleSafe(chargeBar, true)
	resetThumbPosition()
	updateDirectionIndicator(nil)
	applyJoystickVisibilityFromState(lastKnownServerState)
	local root = getCharacterRoot()
	if root then
		chargeReferenceFrame = root.CFrame
		currentChargeAimDirection = getLaunchDirectionFromRoot(root)
		player:SetAttribute("SlingAimDirection", currentChargeAimDirection)
	end
	updateArrowPreview()
	ensureUiLoopRunning()

	debugLog("[SlingUI] StartCharge remote fired")

	startChargeRemote:FireServer(currentChargeAimDirection)
end

local function updateHold(input: InputObject)
	if not isHolding then
		return
	end
	if inputObject and input ~= inputObject and input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	updateJoystickFromInput(input)
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
	player:SetAttribute("SlingAimDirection", nil)
	releaseChargeRemote:FireServer(currentChargeAimDirection)

	setVisibleSafe(cachedChargeBar, false)
	resetThumbPosition()
	updateChargeBar(0)
	destroyArrowPreview()
	applyJoystickVisibilityFromState(lastKnownServerState)

	debugLog("[SlingUI] ReleaseCharge remote fired")
end

local function bindJoystickInput()
	local _, joystickRoot = resolveUi(false)
	if not joystickRoot then
		return
	end
	local inputRegion = getBoundInputRegion()
	if not inputRegion then
		return
	end
	if uiInputBound and boundJoystickRoot == joystickRoot and boundInputRegion == inputRegion then
		return
	end

	disconnectUiInputConnections()

	joystickInputBeganConnection = inputRegion.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		startHold(input)
		updateHold(input)
	end)

	joystickInputChangedConnection = inputRegion.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		updateHold(input)
	end)

	joystickInputEndedConnection = inputRegion.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		releaseHold(input)
	end)

	uiInputBound = true
	boundJoystickRoot = joystickRoot
	boundInputRegion = inputRegion
end

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

		if state.MovementState == GameStates.Movement.Recovering then
			awaitingReleaseAck = false
			syncCooldownFromServerState(state)
		elseif state.MovementState == GameStates.Movement.Idle and awaitingReleaseAck == false and state.IsCharging ~= true then
			clearCooldown()
		end

		applyJoystickVisibilityFromState(state)
	end)
end

workspace:WaitForChild("SlingPawns").ChildAdded:Connect(function(child)
	if child.Name ~= player.Name and child.Name ~= (player.Name .. "_Pawn") then
		return
	end
	resolveUi(false)
	bindJoystickInput()
	resetVisualState()
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name ~= "SlingArenaUI" and child.Name ~= SlingUiConstants.ScreenGuiName then
		return
	end

	resolveUi(false)
	bindJoystickInput()
	if lastKnownServerState and lastKnownServerState.IsAlive == false then
		resetVisualState()
	elseif lastKnownServerState and lastKnownServerState.MovementState == GameStates.Movement.Recovering then
		syncCooldownFromServerState(lastKnownServerState)
	end
	applyJoystickVisibilityFromState(lastKnownServerState)
end)

resolveUi(false)
bindJoystickInput()
resetVisualState()
