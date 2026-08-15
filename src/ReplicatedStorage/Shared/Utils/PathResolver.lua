--!strict

local PathResolver = {}

export type ResolveOptions = {
	waitTimeout: number?,
	shouldWarn: boolean?,
	allowMissingReason: string?, -- Explicit TODO/uncertain marker for paths that are intentionally not enforced yet.
}

local DEFAULT_REPORT_MISSING_TIMEOUT_SECONDS = 1

local warnedMissingPaths: { [string]: boolean } = {}
local warnedAllowedMissingPaths: { [string]: boolean } = {}

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

local function warnMissingOnce(root: Instance, path: string, missingSegment: string?, parentPath: string?)
	local key = getPathKey(root, path) .. "::" .. tostring(missingSegment)
	if warnedMissingPaths[key] then
		return
	end

	warnedMissingPaths[key] = true
	if missingSegment and parentPath then
		warn(string.format("[PathResolver] Missing child '%s' under '%s' while resolving '%s'", missingSegment, parentPath, path))
	else
		warn("[ProjectTreeSpec] Missing:", path)
	end
end

local function warnAllowedMissingOnce(root: Instance, path: string, reason: string)
	local key = getPathKey(root, path)
	if warnedAllowedMissingPaths[key] then
		return
	end
	warnedAllowedMissingPaths[key] = true
	warn(string.format("[PathResolver][TODO_ALLOWED_MISSING] %s (%s)", path, reason))
end

local function splitPath(path: string?): { string }
	local segments = {}
	if type(path) ~= "string" or path == "" then
		warn("[PathResolver] Invalid path provided to splitPath:", path)
		return segments
	end
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	return segments
end

function PathResolver.waitForPath(root: Instance, path: string?, timeout: number): Instance?
	if type(path) ~= "string" or path == "" then
		return nil
	end

	local current: Instance? = root
	local deadline = os.clock() + math.max(timeout, 0)

	for index, segment in ipairs(splitPath(path)) do
		if index == 1 and current ~= nil and segment == current.Name then
			continue
		end

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

function PathResolver.resolvePath(root: Instance, path: string?, options: ResolveOptions?): Instance?
	if type(path) ~= "string" or path == "" then
		if options == nil or options.shouldWarn ~= false then
			warn("[PathResolver] resolvePath called with invalid path:", path)
		end
		return nil
	end

	local shouldWarn = if options and options.shouldWarn ~= nil then options.shouldWarn else true
	local allowMissingReason = if options then options.allowMissingReason else nil
	local resolved = if options and options.waitTimeout ~= nil
		then PathResolver.waitForPath(root, path, options.waitTimeout)
		else nil

	if resolved then
		return resolved
	end

	local current: Instance? = root
	local resolvedPath = root:GetFullName()
	for index, segment in ipairs(splitPath(path)) do
		if index == 1 and current ~= nil and segment == current.Name then
			continue
		end

		if current == nil then
			if allowMissingReason then
				warnAllowedMissingOnce(root, path, allowMissingReason)
			elseif shouldWarn then
				warnMissingOnce(root, path, segment, resolvedPath)
			end
			return nil
		end

		local parent = current
		local child = parent:FindFirstChild(segment)
		if child == nil then
			if allowMissingReason then
				warnAllowedMissingOnce(root, path, allowMissingReason)
			elseif shouldWarn then
				warnMissingOnce(root, path, segment, resolvedPath)
			end
			return nil
		end

		current = child
		resolvedPath = current:GetFullName()
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
	local waitTimeout = if options and options.waitTimeout ~= nil then options.waitTimeout else DEFAULT_REPORT_MISSING_TIMEOUT_SECONDS
	local missing = {}
	for _, path in ipairs(paths) do
		if PathResolver.resolvePath(root, path, {
			waitTimeout = waitTimeout,
			shouldWarn = false,
			allowMissingReason = options and options.allowMissingReason or nil,
		}) == nil then
			table.insert(missing, path)
			if options == nil or options.shouldWarn ~= false then
				PathResolver.resolvePath(root, path, {
					shouldWarn = true,
					allowMissingReason = options and options.allowMissingReason or nil,
				})
			end
		end
	end

	if #missing == 0 then
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
