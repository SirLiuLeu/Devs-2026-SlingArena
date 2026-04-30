--!strict

local PathResolver = {}

export type ResolveOptions = {
	waitTimeout: number?,
	shouldWarn: boolean?,
}

local warnedMissingPaths: { [string]: boolean } = {}

local function flattenSpec(prefix: string, node: any, output: { string })
	if type(node) == "string" then
		if node ~= nil then
			table.insert(output, node)
		else
			warn("flattenSpec: nil string node detected", debug.traceback())
		end
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

local function getPathKey(root: Instance, path: string): string
	return string.format("%s::%s", root:GetFullName(), path)
end

local function warnMissingOnce(root: Instance, path: string)
	local key = getPathKey(root, path)
	if warnedMissingPaths[key] then
		return
	end

	warnedMissingPaths[key] = true
	warn("[ProjectTreeSpec] Missing:", path)
end

local function splitPath(path: string): { string }
	local segments = {}
	print("SPLIT PATH", path)
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	return segments
end

function PathResolver.waitForPath(root: Instance, path: string, timeout: number): Instance?
	local current: Instance? = root
	local deadline = os.clock() + math.max(timeout, 0)

	for _, segment in ipairs(splitPath(path)) do
		if current == nil then
			return nil
		end

		local child = current:FindFirstChild(segment)
		if not child then
			local remaining = deadline - os.clock()
			if remaining <= 0 then
				return nil
			end

			child = current:WaitForChild(segment, remaining)
		end

		current = child
	end

	return current
end

function PathResolver.resolvePath(root: Instance, path: string, options: ResolveOptions?): Instance?
	local shouldWarn = if options and options.shouldWarn ~= nil then options.shouldWarn else true
	local resolved = if options and options.waitTimeout ~= nil
		then PathResolver.waitForPath(root, path, options.waitTimeout)
		else nil

	if resolved then
		return resolved
	end

	local current: Instance? = root
	for _, segment in ipairs(splitPath(path)) do
		if current == nil then
			if shouldWarn then
				warnMissingOnce(root, path)
			end
			return nil
		end

		current = current:FindFirstChild(segment)
		if current == nil then
			if shouldWarn then
				warnMissingOnce(root, path)
			end
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

function PathResolver.reportMissing(root: Instance, paths: { string }, options: ResolveOptions?): { string }
	local missing = {}
	for _, path in ipairs(paths) do
		if PathResolver.resolvePath(root, path, {
			waitTimeout = if options then options.waitTimeout else nil,
			shouldWarn = false,
		}) == nil then
			table.insert(missing, path)
		end
	end

	if #missing == 0 then
		print("[ProjectTreeSpec] Startup check complete. Missing instances: 0")
	else
		warn(string.format("[ProjectTreeSpec] Startup check complete. Missing instances: %d", #missing))
		for _, path in ipairs(missing) do
			warnMissingOnce(root, path)
			warn("[ProjectTreeSpec] MissingSummary:", path)
		end
	end

	return missing
end

return PathResolver
