--!strict

-- Deprecated: directional launch mechanics removed.
local SlingshotService = {}
SlingshotService.__index = SlingshotService

function SlingshotService.new(_context)
	return setmetatable({}, SlingshotService)
end

function SlingshotService:Init() end

return SlingshotService
