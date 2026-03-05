--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local SlingService = {}
SlingService.__index = SlingService

local MOVEMENT_STATE = {
	Idle = "Idle",
	Moving = "Moving",
	Charging = "Charging",
	Launched = "Launched",
	Recovering = "Recovering",
}

function SlingService.new(context)
	local self = setmetatable({}, SlingService)
	self._context = context
	self._input = {}
	self._chargeState = {}
	self._releaseCooldown = {}
	return self
end

function SlingService:Init()
	local remotes = self._context.Remotes
	local moveRemote = remotes:WaitForChild(RemoteContracts.Names.MoveRequest)
	local startChargeRemote = remotes:WaitForChild(RemoteContracts.Names.StartCharge)
	local releaseChargeRemote = remotes:WaitForChild(RemoteContracts.Names.ReleaseCharge)

	moveRemote.OnServerEvent:Connect(function(player, directionInput)
		self:HandleMoveRequest(player, directionInput)
	end)

	startChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
		self:StartCharge(player, aimTarget)
	end)

	releaseChargeRemote.OnServerEvent:Connect(function(player, aimTarget)
		self:ReleaseCharge(player, aimTarget)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._input[player] = nil
		self._chargeState[player] = nil
		self._releaseCooldown[player] = nil
	end)

	RunService.Heartbeat:Connect(function()
		self:_stepMovement()
		self:_stepMovementStates()
	end)
end

function SlingService:_isRoundPlaying(): boolean
	return self._context.Services.RoundService:GetState() == "ActiveRound"
end

function SlingService:_canControl(player: Player): boolean
	if not self:_isRoundPlaying() then
		return false
	end
	if not self._context.Services.RoundService:IsPlayerQueued(player) then
		return false
	end
	if not self._context.Services.PlayerService:IsAlive(player) then
		return false
	end
	return true
end

function SlingService:HandleMoveRequest(player: Player, directionInput: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.MoveRequest, directionInput) then
		return
	end
	if not self:_canControl(player) then
		self._input[player] = Vector3.zero
		return
	end

	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state or state.IsTeleporting then
		self._input[player] = Vector3.zero
		return
	end
	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Recovering then
		self._input[player] = Vector3.zero
		return
	end

	local planar = Vector3.new(directionInput.X, 0, directionInput.Z)
	self._input[player] = if planar.Magnitude > 1 then planar.Unit else planar
end

function SlingService:StartCharge(player: Player, aimTarget: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.StartCharge, aimTarget) then
		return
	end
	if not self:_canControl(player) then
		return
	end

	local now = os.clock()
	local cooldownUntil = self._releaseCooldown[player] or 0
	if now < cooldownUntil then
		return
	end

	local root = self._context.Services.PlayerService:GetRoot(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not root or not state then
		return
	end
	if self._chargeState[player] then
		return
	end

	local direction = aimTarget - root.Position
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(0, 0, -1)
	end

	self._chargeState[player] = {
		chargeStartTime = now,
		aimDirection = direction.Unit,
	}
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
	self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Charging)
	self._context.EventBus:Fire("ChargeStarted", player)
end

function SlingService:ReleaseCharge(player: Player, aimTarget: Vector3)
	if not RemoteContracts.Validate(RemoteContracts.Names.ReleaseCharge, aimTarget) then
		return
	end
	if not self:_canControl(player) then
		return
	end

	local chargeState = self._chargeState[player]
	if not chargeState then
		return
	end
	local root = self._context.Services.PlayerService:GetRoot(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not root or not state then
		self._chargeState[player] = nil
		return
	end

	local maxChargeTime = SlingshotConfig.MAX_CHARGE_TIME or SlingshotConfig.MaxChargeTime
	local chargeTime = math.clamp(os.clock() - chargeState.chargeStartTime, 0, maxChargeTime)
	local chargeRatio = math.clamp(chargeTime / maxChargeTime, 0, 1)

	local updatedDirection = aimTarget - root.Position
	if updatedDirection.Magnitude > 0.01 then
		chargeState.aimDirection = updatedDirection.Unit
	end

	local minForce = SlingshotConfig.MIN_LAUNCH_FORCE or SlingshotConfig.BaseLaunchForce
	local maxForce = SlingshotConfig.MAX_LAUNCH_FORCE or (SlingshotConfig.BaseLaunchForce + Config.MaxExtraForce)
	local launchForce = minForce + ((maxForce - minForce) * chargeRatio)
	local launchVector = chargeState.aimDirection * launchForce

	root.AssemblyLinearVelocity = Vector3.new(
		math.clamp(launchVector.X, -BalanceConfig.MaxVelocity, BalanceConfig.MaxVelocity),
		root.AssemblyLinearVelocity.Y,
		math.clamp(launchVector.Z, -BalanceConfig.MaxVelocity, BalanceConfig.MaxVelocity)
	)

	state.CurrentVelocity = root.AssemblyLinearVelocity
	self._context.Services.PlayerStateService:SetCharging(player, false, chargeRatio)
	self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Launched)
	self._context.EventBus:Fire("SlingLaunched", player, chargeRatio, launchVector)

	if chargeRatio >= 0.999 then
		self._context.EventBus:Fire("MaxChargeReleased", player, BalanceConfig.MaxChargeSelfDamage)
	end

	self._chargeState[player] = nil
	self._releaseCooldown[player] = os.clock() + (SlingshotConfig.RECOVER_TIME or 0.35)
end

function SlingService:_stepMovement()
	for _, player in Players:GetPlayers() do
		local root = self._context.Services.PlayerService:GetRoot(player)
		local input = self._input[player] or Vector3.zero
		if root then
			self:_applyRootVelocity(player, root, input)
		end
	end
end

function SlingService:_applyRootVelocity(player: Player, root: BasePart, input: Vector3)
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	if not linearVelocity or not linearVelocity:IsA("LinearVelocity") then
		return
	end
	local state = self._context.Services.PlayerStateService:GetState(player)
	if not state then
		return
	end

	if state.MovementState == MOVEMENT_STATE.Charging or state.MovementState == MOVEMENT_STATE.Launched or state.MovementState == MOVEMENT_STATE.Recovering then
		linearVelocity.VectorVelocity = Vector3.zero
		linearVelocity.Enabled = false
		return
	end

	if input.Magnitude < 0.001 then
		linearVelocity.VectorVelocity = Vector3.zero
		linearVelocity.Enabled = false
		root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		if state.MovementState ~= MOVEMENT_STATE.Idle then
			self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
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
	linearVelocity.VectorVelocity = velocity
	linearVelocity.Enabled = true
	if state.MovementState ~= MOVEMENT_STATE.Moving then
		self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Moving)
	end
end

function SlingService:_stepMovementStates()
	for _, player in Players:GetPlayers() do
		local state = self._context.Services.PlayerStateService:GetState(player)
		local root = self._context.Services.PlayerService:GetRoot(player)
		if state and root then
			local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			if state.MovementState == MOVEMENT_STATE.Launched and horizontal <= BalanceConfig.VelocityStopThreshold then
				self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Recovering)
				self._releaseCooldown[player] = math.max(self._releaseCooldown[player] or 0, os.clock() + (SlingshotConfig.RECOVER_TIME or 0.35))
			elseif state.MovementState == MOVEMENT_STATE.Recovering and os.clock() >= (self._releaseCooldown[player] or 0) then
				self._context.Services.PlayerStateService:SetMovementState(player, MOVEMENT_STATE.Idle)
			end
		end
	end
end

return SlingService
