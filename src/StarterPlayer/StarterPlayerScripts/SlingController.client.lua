--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes")
local chargeStartRemote = remotes:WaitForChild(RemoteContracts.Names.ChargeStart) :: RemoteEvent
local chargeReleaseRemote = remotes:WaitForChild(RemoteContracts.Names.ChargeRelease) :: RemoteEvent
local matchStateRemote = remotes:WaitForChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent

local STATE_IDLE = "Idle"
local STATE_CHARGING = "Charging"
local STATE_LAUNCHED = "Launched"
local STATE_COOLDOWN = "Cooldown"

local controlState = STATE_IDLE
local matchState = "Lobby"
local dragVector = Vector3.zero
local releaseAt = 0

local function getRoot(): BasePart?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

local function isGrounded(root: BasePart): boolean
	return Workspace:Raycast(root.Position, Vector3.new(0, -4, 0)) ~= nil
end

local function canControl(root: BasePart): boolean
	if matchState ~= "ActiveRound" then return false end
	if root.AssemblyLinearVelocity.Magnitude > 1 then return false end
	if not isGrounded(root) then return false end
	return true
end

local function updateCamera()
	local root = getRoot()
	if not root or not camera then return end
	camera.CameraType = Enum.CameraType.Scriptable
	local velocity = root.AssemblyLinearVelocity
	local facing = velocity.Magnitude > 0.5 and velocity.Unit or root.CFrame.LookVector
	local offset = -facing * 16 + Vector3.new(0, 10, 0)
	camera.CFrame = CFrame.lookAt(root.Position + offset, root.Position)
end

matchStateRemote.OnClientEvent:Connect(function(payload)
	matchState = payload.State or matchState
	if matchState ~= "ActiveRound" then
		controlState = STATE_IDLE
		dragVector = Vector3.zero
	end
end)

player.CharacterAdded:Connect(function()
	controlState = STATE_IDLE
	dragVector = Vector3.zero
end)

RunService.RenderStepped:Connect(function()
	updateCamera()
	local root = getRoot()
	if not root then return end

	if controlState == STATE_CHARGING then
		local pull = Vector3.new(root.Position.X - mouse.Hit.Position.X, 0, root.Position.Z - mouse.Hit.Position.Z)
		local maxPower = 120
		dragVector = if pull.Magnitude > maxPower then pull.Unit * maxPower else pull
	elseif controlState == STATE_LAUNCHED and root.AssemblyLinearVelocity.Magnitude < 1 then
		controlState = STATE_COOLDOWN
		releaseAt = os.clock()
	elseif controlState == STATE_COOLDOWN and os.clock() - releaseAt >= 0.2 then
		controlState = STATE_IDLE
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local root = getRoot()
	if not root or controlState ~= STATE_IDLE or not canControl(root) then return end
	controlState = STATE_CHARGING
	dragVector = Vector3.zero
	chargeStartRemote:FireServer(root.CFrame.LookVector)
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 or controlState ~= STATE_CHARGING then return end
	controlState = STATE_LAUNCHED
	chargeReleaseRemote:FireServer(dragVector)
	dragVector = Vector3.zero
end)
