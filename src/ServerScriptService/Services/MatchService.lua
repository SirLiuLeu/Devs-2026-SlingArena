--!strict

-- Legacy compatibility shim.
-- Active round flow is implemented in RoundService.lua with single-player auto-win removed.

local MatchService = {}
MatchService.__index = MatchService

function MatchService.new(_context)
	return setmetatable({}, MatchService)
end

function MatchService:Init() end

return MatchService
