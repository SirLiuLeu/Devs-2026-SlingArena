--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local MovementService = {}
MovementService.__index = MovementService

function MovementService.new(context)
	local self = setmetatable({}, MovementService)
	self._context = context
	self._input = {}
	return self
end

function MovementService:Init()
	local moveRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.MoveRequest)

	moveRemote.OnServerEvent:Connect(function(player, directionInput)
		self:HandleMoveRequest(player, directionInput)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._input[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		self:_stepMovement()
	end)
end

function MovementService:HandleMoveRequest(player: Player, directionInput: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.MoveRequest, directionInput) then
		return
	end
	if not self._context.Services.RoundService:IsRoundActive() then
		self._input[player] = Vector3.zero
		return
	end
	if not self._context.Services.PlayerService:IsAlive(player) then
		self._input[player] = Vector3.zero
		return
	end

	local planar = Vector3.new(directionInput.X, 0, directionInput.Z)
	self._input[player] = if planar.Magnitude > 1 then planar.Unit else planar
end

function MovementService:_stepMovement()
	for _, player in Players:GetPlayers() do
		local root = self._context.Services.PlayerService:GetRoot(player)
		local input = self._input[player] or Vector3.zero
		if root then
			self:_applyRootVelocity(root, input)
		end
	end
end

function MovementService:_applyRootVelocity(root: BasePart, input: Vector3)
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if not linearVelocity or not linearVelocity:IsA("LinearVelocity") then
		return
	end

	if input.Magnitude < 0.001 then
		linearVelocity.VectorVelocity = Vector3.zero
		linearVelocity.Enabled = false
		local current = root.AssemblyLinearVelocity
		local horizontal = Vector3.new(current.X, 0, current.Z)
		if horizontal.Magnitude < 0.1 then
			root.AssemblyLinearVelocity = Vector3.new(0, current.Y, 0)
		end
		return
	end

	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z)
	if forward.Magnitude < 0.001 or right.Magnitude < 0.001 then
		return
	end

	local direction = (forward.Unit * input.Z) + (right.Unit * input.X)
	if direction.Magnitude < 0.001 then
		linearVelocity.VectorVelocity = Vector3.zero
		linearVelocity.Enabled = false
		return
	end

	local velocity = direction.Unit * Config.MoveSpeed
	if velocity.Magnitude < 0.1 then
		velocity = Vector3.zero
	end
	if velocity.Magnitude > Config.MoveSpeed then
		velocity = velocity.Unit * Config.MoveSpeed
	end

	linearVelocity.VectorVelocity = velocity
	linearVelocity.Enabled = velocity.Magnitude >= 0.1
end

return MovementService
