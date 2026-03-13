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
local warnedMissingChargeUI = false

local function getMouseWorld(): Vector3
	local mouse = player:GetMouse()
	if mouse.Hit then
		return mouse.Hit.Position
	end
	return Vector3.new(0, 0, -1)
end

local function ensureChargeUI()
	-- [UI_CREATION_GUIDE]
	-- Correct hierarchy:
	--
	-- StarterGui
	--   SlingArenaDynamicUI (Folder)
	--     SlingArenaDynamicUI (ScreenGui)
	--       RootFrame (Frame)
	--         ChargeBarBg (Frame)
	--           Fill (Frame)
	--         AimDirection (TextLabel)
	--         ImpactFeedback (TextLabel)

	local playerGui = player:WaitForChild("PlayerGui")

	local uiFolder = playerGui:FindFirstChild("SlingArenaDynamicUI")
	if not uiFolder then
		if not warnedMissingChargeUI then
			warn("[UI_MISSING] PlayerGui.SlingArenaDynamicUI (Folder) missing.")
			warnedMissingChargeUI = true
		end
		return nil, nil, nil, nil
	end

	local screenGui = uiFolder:FindFirstChild("SlingArenaDynamicUI")
	if not screenGui or not screenGui:IsA("ScreenGui") then
		if not warnedMissingChargeUI then
			warn("[UI_MISSING] PlayerGui.SlingArenaDynamicUI (ScreenGui) missing.")
			warnedMissingChargeUI = true
		end
		return nil, nil, nil, nil
	end

	local root = screenGui:FindFirstChild("RootFrame")
	if not root or not root:IsA("Frame") then
		if not warnedMissingChargeUI then
			warn("[UI_MISSING] PlayerGui.SlingArenaDynamicUI.RootFrame missing.")
			warnedMissingChargeUI = true
		end
		return nil, nil, nil, nil
	end

	local barBg = root:FindFirstChild("ChargeBarBg") :: Frame?
	local bar = barBg and (barBg:FindFirstChild("Fill") :: Frame?) or nil
	local aimLabel = root:FindFirstChild("AimDirection") :: TextLabel?
	local feedback = root:FindFirstChild("ImpactFeedback") :: TextLabel?

	if (not barBg) or (not bar) or (not aimLabel) or (not feedback) then
		if not warnedMissingChargeUI then
			warn("[UI_MISSING] Charge UI children incomplete under SlingArenaDynamicUI.RootFrame.")
			warnedMissingChargeUI = true
		end
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