--!strict

local PathResolver = {}

local function flattenSpec(prefix: string, node: any, output: { string })
	if type(node) == "string" then
		table.insert(output, node)
		return
	end

	if type(node) ~= "table" then
		return
	end

	for key, value in pairs(node) do
		local childPrefix = if prefix == "" then tostring(key) else string.format("%s.%s", prefix, tostring(key))
		flattenSpec(childPrefix, value, output)
	end
end

function PathResolver.resolvePath(root: Instance, path: string): Instance?
	local current: Instance? = root
	for segment in string.gmatch(path, "[^%.]+") do
		if current == nil then
			warn("[ProjectTreeSpec] Missing:", path)
			return nil
		end

		current = current:FindFirstChild(segment)
		if current == nil then
			warn("[ProjectTreeSpec] Missing:", path)
			return nil
		end
	end
	return current
end

function PathResolver.collectPaths(specNode: any): { string }
	local paths = {}
	flattenSpec("", specNode, paths)
	table.sort(paths)
	return paths
end

function PathResolver.reportMissing(root: Instance, paths: { string }): { string }
	local missing = {}
	for _, path in ipairs(paths) do
		if PathResolver.resolvePath(root, path) == nil then
			table.insert(missing, path)
		end
	end

	if #missing == 0 then
		print("[ProjectTreeSpec] Startup check complete. Missing instances: 0")
	else
		warn(string.format("[ProjectTreeSpec] Startup check complete. Missing instances: %d", #missing))
		for _, path in ipairs(missing) do
			warn("[ProjectTreeSpec] MissingSummary:", path)
		end
	end

	return missing
end

return PathResolver
