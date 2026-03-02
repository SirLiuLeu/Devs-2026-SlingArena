--!strict

-- Deprecated: charge input and launch mechanics removed in favor of WASD movement.
local ChargeService = {}
ChargeService.__index = ChargeService

function ChargeService.new(_context)
	return setmetatable({}, ChargeService)
end

function ChargeService:Init() end

return ChargeService
