--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local ChargeService = {}
ChargeService.__index = ChargeService

function ChargeService.new(context)
	local self = setmetatable({}, ChargeService)
	self._context = context
	self._lastShotAt = {}
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
	local releaseRemote = self._context.Remotes:WaitForChild(RemoteContracts.Names.SlingRelease)
	releaseRemote.OnServerEvent:Connect(function(player, direction, chargeRatio)
		self:HandleRelease(player, direction, chargeRatio)
	end)
end

function ChargeService:HandleRelease(player, direction, chargeRatio)
	if not RemoteContracts.Validate(RemoteContracts.Names.SlingRelease, direction, chargeRatio) then
		return
	end
	if not self._context.Services.PlayerService:IsAlive(player) then
		return
	end

	local now = os.clock()
	local lastShot = self._lastShotAt[player] or 0
	if now - lastShot < Config.ShotCooldown then
		return
	end

	local planarDirection = Vector3.new(direction.X, 0, direction.Z)
	if planarDirection.Magnitude < 0.001 then
		return
	end

	local trustedDirection = clampDirection(planarDirection.Unit, self._context.Services.PlayerService:GetAim(player))

	local trustedCharge = math.clamp(chargeRatio, 0, 1)
	local didLaunch = self._context.Services.SlingService:Launch(player, trustedDirection, trustedCharge)
	if didLaunch then
		self._lastShotAt[player] = now
		self._context.Services.PlayerService:SetAim(player, trustedDirection)
	end
end

return ChargeService
