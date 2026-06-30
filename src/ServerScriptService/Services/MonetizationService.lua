--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local MonetizationService = {}
MonetizationService.__index = MonetizationService

type Context = {
	Services: any,
	Remotes: Folder,
	EventBus: any,
}

function MonetizationService.new(context: Context)
	local self = setmetatable({}, MonetizationService)
	self._context = context
	return self
end

function MonetizationService:Init()
	local purchaseRespawn = self._context.Remotes:FindFirstChild(RemoteContracts.Names.PurchaseRespawn) :: RemoteEvent?
	local requestRespawn = self._context.Remotes:FindFirstChild(RemoteContracts.Names.RequestRespawn) :: RemoteEvent?

	if purchaseRespawn then
		purchaseRespawn.OnServerEvent:Connect(function(player)
			self:HandleRespawnRequest(player)
		end)
	end
	if requestRespawn then
		requestRespawn.OnServerEvent:Connect(function(player)
			self:HandleRespawnRequest(player)
		end)
	end
end

function MonetizationService:HandleRespawnRequest(player: Player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	local mapName = state and state.CurrentMap or self._context.Services.MapService:GetActiveMap() or "LobbyMap"
	self._context.Services.PlayerService:RespawnCurrentMode(player, nil, mapName)
end

return MonetizationService
