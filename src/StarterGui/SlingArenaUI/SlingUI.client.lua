local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)

local player = Players.LocalPlayer
local guiRoot = script.Parent
local slingGui = guiRoot
if not slingGui:FindFirstChild("JoystickRoot") then
	slingGui = guiRoot:FindFirstChild("SlingUI") or guiRoot
end

local joystick = slingGui:FindFirstChild("JoystickRoot")
local base = joystick and joystick:FindFirstChild("Base")
local thumb = joystick and joystick:FindFirstChild("Thumb")
local chargeBar = slingGui:FindFirstChild("ChargeBar")
local chargeFill = chargeBar and chargeBar:FindFirstChild("Fill")
local directionArrow = slingGui:FindFirstChild("DirectionArrow")
local cooldownBar = slingGui:FindFirstChild("CooldownBar")
local cooldownFill = cooldownBar and cooldownBar:FindFirstChild("Fill")

local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge)
local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge)

local MAX_CHARGE_TIME = SlingshotConfig.MAX_CHARGE_TIME or 2
local COOLDOWN_DURATION = SlingshotConfig.RECOVER_TIME or 3
local MAX_JOYSTICK_DRAG = 60
local DEBUG_LOG = true
local lastLoggedChargeBucket = -1

local isHolding = false
local inputObject = nil
local startPos = Vector2.zero
local currentPos = Vector2.zero
local charge = 0
local cooldownEndTime = 0

local function getMouseWorld(): Vector3
	local mouse = player:GetMouse()
	if mouse.Hit then
		return mouse.Hit.Position
	end
	return Vector3.new(0, 0, -1)
end

local function getInputPosition(input): Vector2
	if input and input.Position then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return Vector2.zero
end

local function isSlingInputStart(input): boolean
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return false
	end
	local mouse = player:GetMouse()
	local target = mouse and mouse.Target
	if not target then
		return false
	end
	local character = player.Character
	if not character then
		return false
	end
	return target:IsDescendantOf(character)
end

local function setVisibleSafe(instance, visible)
	if instance and instance:IsA("GuiObject") then
		instance.Visible = visible
	end
end

local function updateChargeBar(percent)
	if chargeFill and chargeFill:IsA("Frame") then
		chargeFill.Size = UDim2.new(percent, 0, 1, 0)
	end
end

local function updateCooldownBar(percent)
	if cooldownFill and cooldownFill:IsA("Frame") then
		cooldownFill.Size = UDim2.new(percent, 0, 1, 0)
	end
	if cooldownBar and cooldownBar:IsA("GuiObject") then
		cooldownBar.Visible = percent > 0
	end
end

local function startHold(input)
	if os.clock() < cooldownEndTime then
		return
	end
	isHolding = true
	inputObject = input
	startPos = getInputPosition(input)
	currentPos = startPos
	charge = 0

	setVisibleSafe(joystick, true)
	setVisibleSafe(directionArrow, true)

	if joystick and joystick:IsA("GuiObject") then
		joystick.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
		joystick.ZIndex = 20
	end
	if directionArrow and directionArrow:IsA("GuiObject") then
		directionArrow.ZIndex = 21
		directionArrow.Position = joystick and joystick.Position or UDim2.new(0, startPos.X, 0, startPos.Y)
	end
	if DEBUG_LOG then
		print("[SlingUI] Input start detected")
		print("[SlingUI] Charging started")
	end
	startChargeRemote:FireServer(getMouseWorld())
end

local function updateHold(input)
	if not isHolding then
		return
	end
	if input ~= inputObject and input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	currentPos = getInputPosition(input)
	local delta = currentPos - startPos
	if delta.Magnitude > MAX_JOYSTICK_DRAG then
		delta = delta.Unit * MAX_JOYSTICK_DRAG
	end
	if thumb and thumb:IsA("GuiObject") then
		thumb.Position = UDim2.new(0.5, delta.X, 0.5, delta.Y)
	end
	if directionArrow and directionArrow:IsA("GuiObject") then
		if delta.Magnitude > 0 then
			directionArrow.Rotation = math.deg(math.atan2(delta.Y, delta.X))
		end
		directionArrow.Position = joystick and joystick.Position or directionArrow.Position
	end
end

local function releaseHold(input)
	if not isHolding then
		return
	end
	if inputObject and input ~= inputObject and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	isHolding = false
	inputObject = nil

	releaseChargeRemote:FireServer(getMouseWorld())
	cooldownEndTime = os.clock() + COOLDOWN_DURATION

	setVisibleSafe(joystick, false)
	setVisibleSafe(directionArrow, false)
	if thumb and thumb:IsA("GuiObject") then
		thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	end
	updateChargeBar(0)
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

RunService.RenderStepped:Connect(function(dt)
	if isHolding then
		charge += dt
		local chargeRatio = math.clamp(charge / MAX_CHARGE_TIME, 0, 1)
		updateChargeBar(chargeRatio)
		if DEBUG_LOG then
			local bucket = math.floor(chargeRatio * 10)
			if bucket ~= lastLoggedChargeBucket then
				lastLoggedChargeBucket = bucket
				print(string.format("[SlingUI] Charging value: %.2f", chargeRatio))
			end
		end
	end
	local remaining = math.max(0, cooldownEndTime - os.clock())
	updateCooldownBar(math.clamp(remaining / COOLDOWN_DURATION, 0, 1))
end)

setVisibleSafe(joystick, false)
setVisibleSafe(directionArrow, false)
updateChargeBar(0)
updateCooldownBar(0)
