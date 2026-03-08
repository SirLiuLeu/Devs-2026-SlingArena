--!strict

local SlingService = require(script.Parent.SlingService)

local SlingshotService = {}
SlingshotService.__index = SlingshotService

function SlingshotService.new(context)
	local impl = SlingService.new(context)
	return setmetatable({ _impl = impl }, SlingshotService)
end

function SlingshotService:Init()
	self._impl:Init()
end

return SlingshotService
