--!strict

local Players = game:GetService("Players")

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(context)
	local self = setmetatable({}, RoundService)
	self._context = context
	return self
end

function RoundService:Init()
	self._context.Services.MapService:Generate()
end

function RoundService:OnPlayerEliminated(player)
	task.delay(3, function()
		if player.Parent == Players then
			self._context.Services.PlayerService:SpawnPawn(player)
		end
	end)
end

return RoundService
