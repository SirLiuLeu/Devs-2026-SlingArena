--!strict

local DeepCopy = {}

export type Options = {
	MaxDepth: number?,
	MaxNodes: number?,
	PreserveCycles: boolean?,
}

local DEFAULT_MAX_DEPTH = 32
local DEFAULT_MAX_NODES = 10000

function DeepCopy.Copy(value: any, options: Options?): any
	local maxDepth = if options and options.MaxDepth then options.MaxDepth else DEFAULT_MAX_DEPTH
	local maxNodes = if options and options.MaxNodes then options.MaxNodes else DEFAULT_MAX_NODES
	local preserveCycles = if options and options.PreserveCycles ~= nil then options.PreserveCycles else true
	local seen = {}
	local nodes = 0

	local function copyRecursive(input: any, depth: number): any
		if type(input) ~= "table" then
			return input
		end
		if depth > maxDepth then
			return nil
		end
		nodes += 1
		if nodes > maxNodes then
			return nil
		end
		local existing = seen[input]
		if existing ~= nil then
			return if preserveCycles then existing else nil
		end
		local output = {}
		seen[input] = output
		for key, child in pairs(input) do
			local copiedKey = copyRecursive(key, depth + 1)
			if copiedKey ~= nil then
				output[copiedKey] = copyRecursive(child, depth + 1)
			end
		end
		return output
	end

	return copyRecursive(value, 0)
end

return DeepCopy
