--!strict

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type BucketConfig = { Capacity: number, RefillPerSecond: number }

type Bucket = { tokens: number, updatedAt: number }

local DEFAULTS: { [string]: BucketConfig } = {
	RemoteDefault = { Capacity = 30, RefillPerSecond = 15 },
	ReportCollision = { Capacity = 8, RefillPerSecond = 6 },
	ReportFoodHit = { Capacity = 12, RefillPerSecond = 8 },
	MoveRequest = { Capacity = 20, RefillPerSecond = 20 },
}

function RateLimiter.new(_context: any)
	local self = setmetatable({}, RateLimiter)
	self._buckets = {} :: { [string]: Bucket }
	return self
end

function RateLimiter:Init() end
function RateLimiter:Start() end

local function configFor(scope: string): BucketConfig
	return DEFAULTS[scope] or DEFAULTS.RemoteDefault
end

function RateLimiter:Allow(scope: string, key: string, cost: number?, now: number?): boolean
	if type(scope) ~= "string" or scope == "" or type(key) ~= "string" or key == "" then
		return false
	end
	local cfg = configFor(scope)
	local tokenCost = math.max(cost or 1, 0)
	local t = now or os.clock()
	local bucketKey = `{scope}:{key}`
	local bucket = self._buckets[bucketKey]
	if not bucket then
		bucket = { tokens = cfg.Capacity, updatedAt = t }
		self._buckets[bucketKey] = bucket
	end
	local elapsed = math.max(0, t - bucket.updatedAt)
	bucket.tokens = math.min(cfg.Capacity, bucket.tokens + elapsed * cfg.RefillPerSecond)
	bucket.updatedAt = t
	if bucket.tokens < tokenCost then
		return false
	end
	bucket.tokens -= tokenCost
	return true
end

function RateLimiter:Clear(scopePrefix: string)
	local prefix = `{scopePrefix}:`
	for key in pairs(self._buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
