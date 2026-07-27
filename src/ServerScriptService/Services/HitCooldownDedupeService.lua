--!strict

local HitCooldownDedupeService = {}
HitCooldownDedupeService.__index = HitCooldownDedupeService

function HitCooldownDedupeService.new(_context: any)
	local self = setmetatable({}, HitCooldownDedupeService)
	self._expiresAt = {} :: { [string]: number }
	return self
end

function HitCooldownDedupeService:Init() end
function HitCooldownDedupeService:Start() end

function HitCooldownDedupeService:TryAcquire(scope: string, key: string, cooldownSeconds: number, now: number?): boolean
	if type(scope) ~= "string" or scope == "" or type(key) ~= "string" or key == "" then
		return false
	end
	local t = now or os.clock()
	local fullKey = `{scope}:{key}`
	local expiresAt = self._expiresAt[fullKey]
	if expiresAt and expiresAt > t then
		return false
	end
	self._expiresAt[fullKey] = t + math.max(0, cooldownSeconds)
	return true
end

function HitCooldownDedupeService:ClearScope(scopePrefix: string)
	local prefix = `{scopePrefix}:`
	for key in pairs(self._expiresAt) do
		if string.sub(key, 1, #prefix) == prefix then
			self._expiresAt[key] = nil
		end
	end
end

return HitCooldownDedupeService
