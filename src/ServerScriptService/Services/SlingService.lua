--!strict

-- Pipeline A projectile SlingService has been retired.
-- Canonical launch flow now uses ChargeService + SlingshotService.

local SlingService = {}
SlingService.__index = SlingService

function SlingService.new(_context)
	return setmetatable({}, SlingService)
end

function SlingService:Init() end

return SlingService
