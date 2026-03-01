--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local ChargeService = {}
ChargeService.__index = ChargeService

function ChargeService.new(context)
	local self = setmetatable({}, ChargeService)
	self._context = context
	self._chargeStartedAt = {}
	self._lastShotAt = {}
	self._lastDirection = {}
	return self
end

local function clampDirection(current, previous)
	local dot = math.clamp(previous:Dot(current), -1, 1)
	local angle = math.acos(dot)
	if angle <= Config.MaxAimAngleDelta then
		return current
	end
	local blend = Config.MaxAimAngleDelta / angle
	return (previous:Lerp(current, blend)).Unit
end

function ChargeService:Init()
	local startRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.ChargeStart)
	local releaseRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.ChargeRelease)

	startRemote.OnServerEvent:Connect(function(player, direction)
		self:HandleChargeStart(player, direction)
	end)

	releaseRemote.OnServerEvent:Connect(function(player, direction)
		self:HandleChargeRelease(player, direction)
	end)
end

function ChargeService:HandleChargeStart(player, direction)
	if not RemoteContracts.Validate(RemoteContracts.Names.ChargeStart, direction) then
		return
	end
	if not self._context.Services.PlayerService:IsAlive(player) then
		return
	end

	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end

	local trustedDirection = clampDirection(planarDirection.Unit, self._context.Services.PlayerService:GetAim(player))
	self._chargeStartedAt[player] = os.clock()
	self._lastDirection[player] = trustedDirection
	self._context.Services.PlayerService:SetAim(player, trustedDirection)
	self._context.Services.PlayerStateService:SetCharging(player, true, 0)
end

function ChargeService:HandleChargeRelease(player, direction)
	if not RemoteContracts.Validate(RemoteContracts.Names.ChargeRelease, direction) then
		return
	end
	if not self._context.Services.PlayerService:IsAlive(player) then
		return
	end

	local startedAt = self._chargeStartedAt[player]
	if not startedAt then
		return
	end

	local now = os.clock()
	local lastShot = self._lastShotAt[player] or 0
	if now - lastShot < Config.ShotCooldown then
		return
	end

	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	local fallback = self._lastDirection[player] or self._context.Services.PlayerService:GetAim(player)
	local trustedDirection = fallback
	if planarDirection.Magnitude >= 0.001 then
		trustedDirection = clampDirection(planarDirection.Unit, fallback)
	end

	local elapsed = math.max(0, now - startedAt)
	local chargeRatio = math.clamp(elapsed / SlingshotConfig.MaxChargeTime, 0, 1)
	local didLaunch = self._context.Services.SlingshotService:Launch(player, trustedDirection, chargeRatio)
	if didLaunch then
		self._lastShotAt[player] = now
		self._context.Services.PlayerService:SetAim(player, trustedDirection)
	end

	self._chargeStartedAt[player] = nil
end

return ChargeService
