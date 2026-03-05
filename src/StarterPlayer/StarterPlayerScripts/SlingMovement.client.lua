--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local moveRequestRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest) :: RemoteEvent
local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge) :: RemoteEvent
local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge) :: RemoteEvent
local stateUpdateRemote = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent
local gameplayFeedbackRemote = remotes:WaitForChild(RemoteContracts.Names.GameplayFeedback) :: RemoteEvent

local keyStates = {
	[Enum.KeyCode.W] = false,
	[Enum.KeyCode.A] = false,
	[Enum.KeyCode.S] = false,
	[Enum.KeyCode.D] = false,
}

local charging = false
local chargeStartTime = 0
local maxChargeTime = 2

local function getMouseWorld(): Vector3
	local mouse = player:GetMouse()
	if mouse.Hit then
		return mouse.Hit.Position
	end
	return Vector3.new(0, 0, -1)
end

local function ensureChargeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	local dynamic = playerGui:FindFirstChild("SlingArenaDynamicUI")
	if not dynamic then
		return nil, nil, nil, nil
	end
	local root = dynamic:FindFirstChild("Root")
	if not root or not root:IsA("Frame") then
		return nil, nil, nil, nil
	end

	local barBg = root:FindFirstChild("ChargeBarBg") :: Frame?
	if not barBg then
		barBg = Instance.new("Frame")
		barBg.Name = "ChargeBarBg"
		barBg.Size = UDim2.fromOffset(320, 14)
		barBg.Position = UDim2.fromOffset(10, 244)
		barBg.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		barBg.Parent = root
	end

	local bar = barBg:FindFirstChild("Fill") :: Frame?
	if not bar then
		bar = Instance.new("Frame")
		bar.Name = "Fill"
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = Color3.fromRGB(255, 178, 44)
		bar.BorderSizePixel = 0
		bar.Parent = barBg
	end

	local aimLabel = root:FindFirstChild("AimDirection") :: TextLabel?
	if not aimLabel then
		aimLabel = Instance.new("TextLabel")
		aimLabel.Name = "AimDirection"
		aimLabel.Size = UDim2.fromOffset(340, 24)
		aimLabel.Position = UDim2.fromOffset(10, 264)
		aimLabel.TextXAlignment = Enum.TextXAlignment.Left
		aimLabel.BackgroundTransparency = 1
		aimLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
		aimLabel.Parent = root
	end

	local feedback = root:FindFirstChild("ImpactFeedback") :: TextLabel?
	if not feedback then
		feedback = Instance.new("TextLabel")
		feedback.Name = "ImpactFeedback"
		feedback.Size = UDim2.fromOffset(340, 24)
		feedback.Position = UDim2.fromOffset(10, 284)
		feedback.TextXAlignment = Enum.TextXAlignment.Left
		feedback.BackgroundTransparency = 1
		feedback.TextColor3 = Color3.fromRGB(255, 120, 120)
		feedback.Parent = root
	end

	return bar, aimLabel, feedback, barBg
end

local function computeInputVector(): Vector3
	local x = 0
	local z = 0
	if keyStates[Enum.KeyCode.D] then x += 1 end
	if keyStates[Enum.KeyCode.A] then x -= 1 end
	if keyStates[Enum.KeyCode.W] then z += 1 end
	if keyStates[Enum.KeyCode.S] then z -= 1 end
	return Vector3.new(x, 0, z)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if keyStates[input.KeyCode] ~= nil then
		keyStates[input.KeyCode] = true
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not charging then
		charging = true
		chargeStartTime = os.clock()
		startChargeRemote:FireServer(getMouseWorld())
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if keyStates[input.KeyCode] ~= nil then
		keyStates[input.KeyCode] = false
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and charging then
		charging = false
		releaseChargeRemote:FireServer(getMouseWorld())
	end
end)

stateUpdateRemote.OnClientEvent:Connect(function(state)
	if typeof(state) == "table" and typeof(state.ChargeValue) == "number" then
		maxChargeTime = 2
	end
end)

gameplayFeedbackRemote.OnClientEvent:Connect(function(payload)
	local _, _, feedbackLabel = ensureChargeUI()
	if not feedbackLabel or typeof(payload) ~= "table" then
		return
	end
	if payload.EventType == "Impact" then
		feedbackLabel.Text = "Impact!"
	elseif payload.EventType == "LevelUp" then
		feedbackLabel.Text = "Level Up!"
	elseif payload.EventType == "DamageTaken" then
		feedbackLabel.Text = string.format("Damage: -%d", math.floor(payload.Payload.Amount or 0))
	elseif payload.EventType == "SelfDamage" then
		feedbackLabel.Text = string.format("Recoil: -%d", math.floor(payload.Payload.Amount or 0))
	end
end)

player.CharacterAdded:Connect(function()
	for keyCode in pairs(keyStates) do
		keyStates[keyCode] = false
	end
	charging = false
end)

RunService.RenderStepped:Connect(function()
	local inputVector = computeInputVector()
	if inputVector.Magnitude > 1 then
		inputVector = inputVector.Unit
	end
	moveRequestRemote:FireServer(inputVector)

	local bar, aimLabel, _, bg = ensureChargeUI()
	if bar and aimLabel and bg then
		bg.Visible = true
		local chargeRatio = 0
		if charging then
			chargeRatio = math.clamp((os.clock() - chargeStartTime) / maxChargeTime, 0, 1)
		end
		bar.Size = UDim2.fromScale(chargeRatio, 1)
		local origin = workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position or Vector3.zero
		local dir = (getMouseWorld() - origin)
		if dir.Magnitude > 0.001 then
			dir = dir.Unit
		end
		aimLabel.Text = string.format("Aim: (%.2f, %.2f)", dir.X, dir.Z)
	end
end)
