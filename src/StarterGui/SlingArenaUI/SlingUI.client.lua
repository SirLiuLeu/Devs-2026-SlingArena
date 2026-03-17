local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = game.Players.LocalPlayer
local gui = script.Parent

local joystick = gui:WaitForChild("JoystickRoot")
local base = joystick:WaitForChild("Base")
local thumb = joystick:WaitForChild("Thumb")

local chargeBar = gui:WaitForChild("ChargeBar")
local fill = chargeBar:WaitForChild("Fill")

local arrow = gui:WaitForChild("DirectionArrow")

-- state
local isHolding = false
local startPos = nil
local currentPos = nil

local charge = 0
local maxChargeTime = 2 -- giây

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		isHolding = true
		startPos = input.Position
		currentPos = startPos
		charge = 0

		-- show UI
		joystick.Visible = true
		arrow.Visible = true

		-- đặt joystick tại vị trí click
		joystick.Position = UDim2.new(0, startPos.X, 0, startPos.Y)
	end
end)

UIS.InputChanged:Connect(function(input)
	if not isHolding then return end

	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then

		currentPos = input.Position

		local delta = currentPos - startPos

		-- giới hạn joystick
		local maxDistance = 60
		if delta.Magnitude > maxDistance then
			delta = delta.Unit * maxDistance
		end

		-- di chuyển thumb
		thumb.Position = UDim2.new(
			0.5, delta.X,
			0.5, delta.Y
		)

		-- rotate arrow
		local angle = math.atan2(delta.Y, delta.X)
		arrow.Rotation = math.deg(angle)

		-- đặt arrow tại joystick
		arrow.Position = joystick.Position
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if isHolding then
		charge += dt

		local percent = math.clamp(charge / maxChargeTime, 0, 1)

		-- update UI
		fill.Size = UDim2.new(percent, 0, 1, 0)
	end
end)

UIS.InputEnded:Connect(function(input)
	if not isHolding then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		isHolding = false

		local delta = currentPos - startPos
		local direction = delta.Magnitude > 0 and delta.Unit or Vector2.new(0,0)

		local power = math.clamp(charge / maxChargeTime, 0, 1)

		print("Direction:", direction)
		print("Power:", power)

		-- TODO: gửi lên server
		-- RemoteEvent:FireServer(direction, power)

		-- reset UI
		joystick.Visible = false
		arrow.Visible = false

		thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
		fill.Size = UDim2.new(0, 0, 1, 0)
	end
end)