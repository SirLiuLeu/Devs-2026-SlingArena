--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local LauncherUiConstants = require(ReplicatedStorage.Shared.Constants.LauncherUiConstants)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local LauncherUiState = require(ReplicatedStorage.Shared.Utils.LauncherUiState)
local LauncherCooldownService = require(ReplicatedStorage.Shared.Utils.LauncherCooldownService)
local CooldownOverlayComponent = require(script.Parent.Components.CooldownOverlayComponent)
local CooldownTextComponent = require(script.Parent.Components.CooldownTextComponent)
local WaitForUI = require(ReplicatedStorage.Shared.Utils.WaitForUI)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge) :: RemoteEvent
local requestLaunchRemote = remotes:WaitForChild(RemoteContracts.Names.RequestLaunch) :: RemoteEvent
local stateUpdateRemote = remotes:FindFirstChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent?
local prefabsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Prefabs")

local MAX_CHARGE_TIME = PhysicsConfig.Charge.MaxSeconds
local DEFAULT_COOLDOWN_DURATION = PhysicsConfig.Launch.RecoveryDuration
local DEFAULT_JOYSTICK_RADIUS = 60
local ARROW_FORWARD_OFFSET = 1
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
local chargeStartTime = 0
local cooldownService = LauncherCooldownService.new(DEFAULT_COOLDOWN_DURATION)
local cooldownStartTime = 0
local cooldownEndTime = 0
local cooldownDuration = DEFAULT_COOLDOWN_DURATION
local lastCooldownTextBucket: number? = nil
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
local cooldownOverlayComponent: any = nil
local cooldownTextComponent: any = nil

-- [UI_CREATION_GUIDE]
-- Create in Studio:
-- StarterGui
--   LauncherUI (ScreenGui)
--       ChargeBar (Frame)
--         Fill (Frame)
--       JoystickRoot (Frame)
--         Base (Frame)
--         Thumb (Frame)
--         CooldownOverlay (Frame)
--           LeftHalf/Clip/Fill and RightHalf/Clip/Fill
--         DirectionIndicator (ImageLabel)
--         CooldownText (TextLabel)

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
	debugLog(string.format("[LauncherUI] UI resolved: %s", lastResolvedPath))
end

local function warnMissingUiOnce(message: string)
	if warnedMissingUi then
		return
	end

	warnedMissingUi = true
	warn(message)
	warn("[UI_CREATION_GUIDE] Required path: StarterGui.LauncherUI.ChargeBar(Fill), JoystickRoot(Base, Thumb, CooldownOverlay, DirectionIndicator, CooldownText).")
end

local function setVisibleSafe(instance: GuiObject?, visible: boolean)
	if instance then
		instance.Visible = visible
	end
end

local function isLauncherMode(state: { [string]: any }?): boolean
	local mode = if state and typeof(state.ActivePlayerMode) == "string" then state.ActivePlayerMode else player:GetAttribute("ActivePlayerMode")
	return mode ~= GameStates.PlayerMode.Human
end

local function destroyArrowPreview()
	if arrowPreview then
		arrowPreview:Destroy()
		arrowPreview = nil
	end
end

local function shouldShowJoystickByState(state: { [string]: any }?): boolean
	if not isLauncherMode(state) then
		return false
	end

	if state and state.IsAlive == false then
		return false
	end

	local movementState = if state then state.MovementState else nil
	if movementState == GameStates.PlayerState.Launching or movementState == GameStates.PlayerState.Knockback then
		return false
	end

	if awaitingReleaseAck then
		return false
	end

	return true
end

local function applyJoystickVisibilityFromState(state: { [string]: any }?)
	local launcherMode = isLauncherMode(state)
	local showJoystick = shouldShowJoystickByState(state)
	setVisibleSafe(cachedJoystickRoot, true)
	setVisibleSafe(cachedBase, showJoystick)
	setVisibleSafe(cachedThumb, showJoystick)
	setVisibleSafe(cachedDirectionIndicator, showJoystick)
	if cachedBase then
		cachedBase.Active = showJoystick
	end
	if not showJoystick then
		inputObject = nil
		currentDragVector = Vector2.zero
		currentDragDistance = 0
		if cachedThumb then
			cachedThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
		end
	end
	if not launcherMode then
		setVisibleSafe(cachedChargeBar, false)
		if cooldownOverlayComponent then
			cooldownOverlayComponent:Update(false)
		end
		if cooldownTextComponent then
			cooldownTextComponent:Update(false)
		end
		destroyArrowPreview()
	end
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

local function resolveDirectionIndicator(joystickRoot: Instance?): Instance?
	return findChild(joystickRoot, LauncherUiConstants.Elements.DirectionIndicator)
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

	cachedScreenGui = WaitForUI.ResolveLauncherUIWithRetry(player, {
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

local function resolveUi(waitForUi: boolean?): (ScreenGui?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?, GuiObject?)
	local screenGui = resolveScreenGui(if waitForUi == nil then false else waitForUi)
	if not screenGui then
		if WaitForUI.IsRetryPending(player) and waitForUi ~= true then
			return nil, nil, nil, nil, nil, nil, nil
		end
		warnMissingUiOnce("[LauncherUI] Missing LauncherUI ScreenGui at PlayerGui.LauncherUI.")
		return nil, nil, nil, nil, nil, nil, nil
	end

	screenGui.Enabled = true
	cachedScreenGui = screenGui

	local joystickRoot = findChild(screenGui, "JoystickRoot")
	local chargeBar = findChild(screenGui, "ChargeBar")
	local base = if joystickRoot then findChild(joystickRoot, "Base") else nil
	local thumb = if joystickRoot then findChild(joystickRoot, "Thumb") else nil
	local directionIndicator = resolveDirectionIndicator(joystickRoot)
	local cooldownOverlay = if joystickRoot then findChild(joystickRoot, LauncherUiConstants.Elements.CooldownOverlay) else nil
	local cooldownText = if joystickRoot then findChild(joystickRoot, LauncherUiConstants.Elements.CooldownText) else nil
	local chargeFill = if chargeBar then findChild(chargeBar, "Fill") else nil

	if joystickRoot and (not cooldownOverlayComponent or not cooldownOverlayComponent.Root or cooldownOverlayComponent.Root.Parent ~= joystickRoot) then
		cooldownOverlayComponent = CooldownOverlayComponent.new(joystickRoot)
	end
	if joystickRoot and (not cooldownTextComponent or not cooldownTextComponent.Root or cooldownTextComponent.Root.Parent ~= joystickRoot) then
		cooldownTextComponent = CooldownTextComponent.new(joystickRoot)
	end

	if not joystickRoot or not base or not thumb or not chargeBar or not chargeFill or not directionIndicator or not cooldownOverlay or not cooldownText then
		warnMissingUiOnce("[LauncherUI] LauncherUI hierarchy is incomplete. Expected LauncherUI > ChargeBar(Fill), JoystickRoot(Base, Thumb, CooldownOverlay, DirectionIndicator, CooldownText).")
	end

	cachedJoystickRoot = if joystickRoot and joystickRoot:IsA("GuiObject") then joystickRoot else nil
	cachedBase = if base and base:IsA("GuiObject") then base else nil
	cachedThumb = if thumb and thumb:IsA("GuiObject") then thumb else nil
	cachedChargeBar = if chargeBar and chargeBar:IsA("GuiObject") then chargeBar else nil
	cachedChargeFill = if chargeFill and chargeFill:IsA("GuiObject") then chargeFill else nil
	cachedDirectionIndicator = if directionIndicator and directionIndicator:IsA("GuiObject") then directionIndicator else nil

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

	return cachedScreenGui, cachedJoystickRoot, cachedBase, cachedThumb, cachedChargeBar, cachedChargeFill, cachedDirectionIndicator
end

local function getBoundInputRegion(): GuiObject?
	if cachedBase and cachedBase.Active then
		return cachedBase
	end
	return cachedJoystickRoot
end

local function updateChargeBar(percent: number)
	local _, _, _, _, chargeBar, chargeFill = resolveUi(false)
	local normalized = LauncherUiState.ClampRatio(percent)
	setVisibleSafe(chargeBar, isLauncherMode(lastKnownServerState) and (isHolding or normalized > 0))
	if chargeFill then
		chargeFill.Size = UDim2.new(normalized, 0, 1, 0)
	end
end

local function formatCooldownText(remainingTime: number): (string, number)
	if remainingTime > 1 then
		local rounded = math.max(1, math.round(remainingTime))
		return tostring(rounded), rounded
	end

	local rounded = math.max(0.1, math.round(remainingTime * 10) / 10)
	local bucket = math.round(rounded * 10)
	return string.format("%.1f", rounded), bucket
end

local function updateCooldownVisuals(percent: number, remainingTime: number?)
	resolveUi(false)
	local normalized = LauncherUiState.ClampRatio(percent)
	local launcherMode = isLauncherMode(lastKnownServerState)
	local showCooldown = launcherMode and normalized < 1 and remainingTime ~= nil and remainingTime > 0
	if cooldownOverlayComponent then
		cooldownOverlayComponent:Update(showCooldown, normalized)
	end
	if cooldownTextComponent then
		if showCooldown and remainingTime then
			local text, bucket = formatCooldownText(remainingTime)
			if lastCooldownTextBucket ~= bucket then
				lastCooldownTextBucket = bucket
				cooldownTextComponent:Update(true, text)
			else
				cooldownTextComponent:Update(true)
			end
		else
			lastCooldownTextBucket = nil
			cooldownTextComponent:Update(false)
		end
	end
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

local function getCameraPlanarBasis(): (Vector3?, Vector3?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end

	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if right.Magnitude < 0.001 or forward.Magnitude < 0.001 then
		return nil, nil
	end

	return right.Unit, forward.Unit
end

local function getCameraForwardDirection(): Vector3
	local _, forward = getCameraPlanarBasis()
	return forward or Vector3.new(0, 0, -1)
end

local function resolveChargeAimDirection(): Vector3
	local right, forward = getCameraPlanarBasis()
	if not right or not forward then
		return getCameraForwardDirection()
	end

	if currentDragDistance <= 0.001 then
		return forward
	end

	local worldDirection = (right * currentDirection.X) + (forward * -currentDirection.Y)
	local planarDirection = Vector3.new(worldDirection.X, 0, worldDirection.Z)
	if planarDirection.Magnitude < 0.001 then
		return forward
	end

	return planarDirection.Unit
end

local function updateLauncherFacingDirection(_root: BasePart, _direction: Vector3)
	-- Physical facing is server-owned. The client only updates UI previews.
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

	updateLauncherFacingDirection(root, currentChargeAimDirection)

	if not arrowPreview then
		local arrowTemplate = prefabsFolder:FindFirstChild("ArrowModel")
		if not arrowTemplate or not arrowTemplate:IsA("Model") then
			warn("[LauncherUI] Missing ReplicatedStorage.Assets.Prefabs.ArrowModel for local charge preview.")
			return
		end

		arrowPreview = arrowTemplate:Clone()
		arrowPreview.Name = "LocalChargeArrowPreview"
		arrowPreview.Parent = workspace.CurrentCamera or workspace
	end

	local direction = currentChargeAimDirection
	local origin = root.Position + (direction * ARROW_FORWARD_OFFSET)
	arrowPreview:PivotTo(CFrame.lookAt(origin, origin + direction, Vector3.yAxis)
					* CFrame.Angles(0, math.rad(-90), 0)) -- Rotate so that the arrow model faces forward along the X axis
			-- Note: The specific rotation may need to be adjusted based on the orientation of the arrow model in the asset. The above assumes the arrow points along the positive X axis in its default orientation.
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
		currentChargeAimDirection = resolveChargeAimDirection()
		player:SetAttribute("LauncherAimDirection", currentChargeAimDirection)
	end
	cachedThumb.Position = UDim2.new(0.5, clampedVector.X, 0.5, clampedVector.Y)
	updateDirectionIndicator(LauncherUiState.ComputeDirectionRotation(clampedVector))
end

local function stopUiLoopIfIdle()
	if isHolding then
		return
	end
	if cooldownService:IsActive() then
		return
	end
	if uiUpdateConnection then
		uiUpdateConnection:Disconnect()
		uiUpdateConnection = nil
	end
end

local function stepUi()
	if isHolding then
		local root = getCharacterRoot()
		if root then
			currentChargeAimDirection = resolveChargeAimDirection()
			player:SetAttribute("LauncherAimDirection", currentChargeAimDirection)
		end

		local chargeRatio = LauncherUiState.ComputeChargeRatio(os.clock() - chargeStartTime, MAX_CHARGE_TIME)
		updateChargeBar(chargeRatio)
	else
		updateChargeBar(0)
	end
	updateArrowPreview()

	applyJoystickVisibilityFromState(lastKnownServerState)

	local cooldownRatio = 0
	local remainingTime = 0
	local now = os.clock()
	if cooldownService:IsActive(now) then
		cooldownRatio = cooldownService:GetRatio(now)
		remainingTime = cooldownService:GetRemainingTime(now)
	end
	updateCooldownVisuals(cooldownRatio, remainingTime)
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
	local cooldownState = cooldownService:Begin(duration, endTime)
	cooldownStartTime = cooldownState.cooldownStartTime
	cooldownEndTime = cooldownState.cooldownEndTime
	cooldownDuration = cooldownState.cooldownDuration
	lastCooldownTextBucket = nil
	updateCooldownVisuals(0, cooldownDuration)
	ensureUiLoopRunning()
end

local function clearCooldown()
	local cooldownState = cooldownService:Clear()
	cooldownStartTime = cooldownState.cooldownStartTime
	cooldownEndTime = cooldownState.cooldownEndTime
	cooldownDuration = cooldownState.cooldownDuration
	lastCooldownTextBucket = nil
	updateCooldownVisuals(0, 0)
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
	chargeStartTime = 0
	setVisibleSafe(cachedChargeBar, false)
	resetThumbPosition()
	updateChargeBar(0)
	destroyArrowPreview()
	clearCooldown()
	player:SetAttribute("LauncherAimDirection", nil)
	player:SetAttribute("PredictedLaunchDirection", nil)
	player:SetAttribute("PredictedLaunchStartedAt", nil)
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
	if not isLauncherMode(lastKnownServerState) then
		return
	end
	if isHolding then
		return
	end
	if cooldownService:IsActive() then
		return
	end
	if lastKnownServerState and lastKnownServerState.MovementState == GameStates.PlayerState.Knockback then
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

	setVisibleSafe(joystickRoot, true)
	setVisibleSafe(chargeBar, true)
	resetThumbPosition()
	updateDirectionIndicator(nil)
	applyJoystickVisibilityFromState(lastKnownServerState)
	local root = getCharacterRoot()
	if root then
		currentChargeAimDirection = resolveChargeAimDirection()
		player:SetAttribute("LauncherAimDirection", currentChargeAimDirection)
	end
	updateArrowPreview()
	ensureUiLoopRunning()

	debugLog("[LauncherUI] StartCharge remote fired")

	startChargeRemote:FireServer(currentChargeAimDirection)
end

local function updateHold(input: InputObject)
    if not isHolding then
        return
    end

    -- CHỈ xử lý ngón tay/chuột đầu tiên đã bấm vào joystick.
    -- Bỏ qua nếu là input khác (nhưng vẫn cho phép MouseMovement vì chuột PC có object riêng)
    if inputObject and input ~= inputObject then
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
    end

    updateJoystickFromInput(input)
end

local function resolveClientLaunchSpeed(chargeRatio: number): number
	local launcherMaxSpeed = PhysicsConfig.Launch.SpeedMax
	if lastKnownServerState and typeof(lastKnownServerState.LaunchSpeed) == "number" then
		launcherMaxSpeed = lastKnownServerState.LaunchSpeed
	end
	local speed = PhysicsConfig.Launch.SpeedMin + ((math.max(PhysicsConfig.Launch.SpeedMin, launcherMaxSpeed) - PhysicsConfig.Launch.SpeedMin) * math.clamp(chargeRatio, 0, 1))
	return math.min(speed, PhysicsConfig.Launch.SpeedMax)
end

local function releaseHold(input: InputObject)
    if not isHolding then
        return
    end

    -- CHỈ kết thúc khi đúng ngón tay đã giữ joystick thả ra (chặn ngón khác chạm/thả làm huỷ touch)
    if inputObject and input ~= inputObject then
        return
    end

    isHolding = false
    awaitingReleaseAck = true
    inputObject = nil
    player:SetAttribute("PredictedLaunchDirection", currentChargeAimDirection)
    player:SetAttribute("PredictedLaunchStartedAt", os.clock())
    player:SetAttribute("LauncherAimDirection", nil)
    
    local chargeRatio = math.clamp((os.clock() - chargeStartTime) / math.max(PhysicsConfig.Charge.MinWindowSeconds, PhysicsConfig.Charge.MaxSeconds), 0, 1)
    local launchSpeed = resolveClientLaunchSpeed(chargeRatio)
    requestLaunchRemote:FireServer({
        aimTarget = currentChargeAimDirection,
        launchDirection = currentChargeAimDirection,
        launchSpeed = launchSpeed,
        chargeRatio = chargeRatio,
        clientTimestamp = os.clock(),
    })

    setVisibleSafe(cachedChargeBar, false)
    resetThumbPosition()
    updateChargeBar(0)
    destroyArrowPreview()
    applyJoystickVisibilityFromState(lastKnownServerState)

    debugLog("[LauncherUI] RequestLaunch remote fired")
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
		if typeof(state.ActivePlayerMode) == "string" then
			player:SetAttribute("ActivePlayerMode", state.ActivePlayerMode)
		end

		if state.IsAlive == false or not isLauncherMode(state) then
			resetVisualState()
			return
		end

		if state.IsCharging == false and isHolding == true then
            -- Chỉ huỷ bỏ charge từ server nếu Client đã bắt đầu charge hơn 0.5 giây.
            -- Điều này tránh lỗi nhận packet cũ (chưa kịp update IsCharging = true) từ server.
            if os.clock() - chargeStartTime > 0.5 then
                isHolding = false
                updateChargeBar(0)
            end
        end

		if state.MovementState == GameStates.PlayerState.Launching then
			awaitingReleaseAck = false
		end

		if typeof(state.CooldownEndTime) == "number" and state.CooldownEndTime > os.clock() then
			awaitingReleaseAck = false
			syncCooldownFromServerState(state)
		elseif awaitingReleaseAck == false and state.IsCharging ~= true then
			clearCooldown()
		end

		applyJoystickVisibilityFromState(state)
	end)
end

workspace:WaitForChild("LauncherPawns").ChildAdded:Connect(function(child)
	if child.Name ~= player.Name and child.Name ~= (player.Name .. "_Pawn") then
		return
	end
	resolveUi(false)
	bindJoystickInput()
	resetVisualState()
end)

playerGui.ChildAdded:Connect(function(child)
	if child.Name ~= LauncherUiConstants.ScreenGuiName then
		return
	end

	resolveUi(false)
	bindJoystickInput()
	if lastKnownServerState and lastKnownServerState.IsAlive == false then
		resetVisualState()
	elseif lastKnownServerState and typeof(lastKnownServerState.CooldownEndTime) == "number" and lastKnownServerState.CooldownEndTime > os.clock() then
		syncCooldownFromServerState(lastKnownServerState)
	end
	applyJoystickVisibilityFromState(lastKnownServerState)
end)

resolveUi(false)
bindJoystickInput()
resetVisualState()
