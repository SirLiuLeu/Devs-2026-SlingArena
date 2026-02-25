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
	self._context.Services.MapService:Generate(os.time())
end

function RoundService:OnPlayerEliminated(player)
	task.delay(3, function()
		if player.Parent == Players then
			self._context.Services.PlayerService:SpawnPawn(player)
		end
	end)

	task.delay(1, function()
		local alive = 0
		for _, p in Players:GetPlayers() do
			if self._context.Services.PlayerService:IsAlive(p) then
				alive += 1
			end
		end
		if alive <= 1 then
			self._context.Services.MapService:Generate(os.time())
		end
	end)
end

return RoundService
