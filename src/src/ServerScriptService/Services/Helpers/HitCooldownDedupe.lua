--!strict

local HitCooldownDedupe = {}
HitCooldownDedupe.__index = HitCooldownDedupe

function HitCooldownDedupe.new(_context: any)
	local self = setmetatable({}, HitCooldownDedupe)
	self._expiresAt = {} :: { [string]: number }
	return self
end

function HitCooldownDedupe:Init() end
function HitCooldownDedupe:Start() end

function HitCooldownDedupe:TryAcquire(scope: string, key: string, cooldownSeconds: number, now: number?): boolean
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

function HitCooldownDedupe:ClearScope(scopePrefix: string)
	local prefix = `{scopePrefix}:`
	for key in pairs(self._expiresAt) do
		if string.sub(key, 1, #prefix) == prefix then
			self._expiresAt[key] = nil
		end
	end
end

return HitCooldownDedupe
