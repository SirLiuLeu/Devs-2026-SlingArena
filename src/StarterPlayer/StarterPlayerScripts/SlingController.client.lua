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

local dragging = false
local matchState = "Lobby"
local activePull = Vector3.zero

local function getRoot(): BasePart?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

local function isGrounded(root: BasePart): boolean
	return workspace:Raycast(root.Position, Vector3.new(0, -4, 0)) ~= nil
end

local function canControl(root: BasePart): boolean
	if matchState ~= "ActiveRound" then return false end
	if root.AssemblyLinearVelocity.Magnitude > 1 then return false end
	if not isGrounded(root) then return false end
	return true
end

local function updateCamera()
	local root = getRoot()
	if not root then return end
	if not camera then return end
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = root
end

matchStateRemote.OnClientEvent:Connect(function(payload)
	matchState = payload.State or matchState
end)

player.CharacterAdded:Connect(function()
	task.defer(updateCamera)
end)

RunService.RenderStepped:Connect(function()
	updateCamera()
	if not dragging then
		activePull = Vector3.zero
		return
	end
	local root = getRoot()
	if not root then
		activePull = Vector3.zero
		return
	end
	activePull = Vector3.new(root.Position.X - mouse.Hit.Position.X, 0, root.Position.Z - mouse.Hit.Position.Z)
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local root = getRoot()
	if not root or not canControl(root) then return end
	dragging = true
	activePull = Vector3.zero
	chargeStartRemote:FireServer(root.CFrame.LookVector)
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 or not dragging then return end
	dragging = false
	chargeReleaseRemote:FireServer(activePull)
	activePull = Vector3.zero
end)
