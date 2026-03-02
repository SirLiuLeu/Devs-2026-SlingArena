--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local ChargeService = {}
ChargeService.__index = ChargeService

function ChargeService.new(context)
	local self = setmetatable({}, ChargeService)
	self._context = context
	self._lastShotAt = {}
	self._states = {}
	return self
end

function ChargeService:Init()
	local startRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.ChargeStart)
	local releaseRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.ChargeRelease)

	startRemote.OnServerEvent:Connect(function(player, direction)
		self:HandleChargeStart(player, direction)
	end)

	releaseRemote.OnServerEvent:Connect(function(player, pullVector)
		self:HandleChargeRelease(player, pullVector)
	end)
end

function ChargeService:HandleChargeStart(player, direction)
	if not RemoteContracts.Validate(RemoteContracts.Names.ChargeStart, direction) then return end
	if not self._context.Services.RoundService:IsRoundActive() then return end
	if not self._context.Services.PlayerService:IsAlive(player) then return end
	if not self._context.Services.PlayerService:IsGrounded(player) then return end

	local state = self._states[player]
	if state == "Cooldown" then return end

	local planar = Vector3.new(direction.X, 0, direction.Z)
	if planar.Magnitude < 0.001 then return end

	self._states[player] = "Charging"
	self._context.Services.PlayerService:SetAim(player, planar.Unit)
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
end

function ChargeService:HandleChargeRelease(player, pullVector)
	if not RemoteContracts.Validate(RemoteContracts.Names.ChargeRelease, pullVector) then return end
	if not self._context.Services.RoundService:IsRoundActive() then return end
	if not self._context.Services.PlayerService:IsAlive(player) then return end
	if self._states[player] ~= "Charging" then return end

	local now = os.clock()
	if now - (self._lastShotAt[player] or 0) < 0.3 then return end
	self._lastShotAt[player] = now

	local planar = Vector3.new(pullVector.X, 0, pullVector.Z)
	local maxPull = SlingshotConfig.SlingConfig.MaxPullDistance
	local pullDistance = math.clamp(planar.Magnitude, 0, maxPull)
	if pullDistance <= 0.01 then
		self._states[player] = "Idle"
		self._context.Services.PlayerStateService:SetCharging(player, false, 0)
		return
	end

	local direction = planar.Unit
	local chargeRatio = pullDistance / maxPull
	self._states[player] = "Launched"
	local didLaunch = self._context.Services.SlingshotService:Launch(player, direction, chargeRatio)
	if didLaunch then
		self._context.Services.PlayerService:SetAim(player, direction)
	end
	self._context.Services.PlayerStateService:SetCharging(player, false, chargeRatio)

	task.delay(0.25, function()
		if self._states[player] == "Launched" then
			self._states[player] = "Cooldown"
			task.delay(0.2, function()
				if self._states[player] == "Cooldown" then
					self._states[player] = "Idle"
				end
			end)
		end
	end)
end

return ChargeService
