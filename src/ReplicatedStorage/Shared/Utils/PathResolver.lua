--!strict

local PathResolver = {}

export type ResolveOptions = {
	waitTimeout: number?,
	shouldWarn: boolean?,
	debugMissingTree: boolean?,
}

local warnedMissingPaths: { [string]: boolean } = {}

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

local function getPathKey(root: Instance, path: string): string
	return string.format("%s::%s", root:GetFullName(), path)
end

local function describeChildren(instance: Instance?): string
	if instance == nil then
		return "<nil>"
	end

	local names = {}
	for _, child in ipairs(instance:GetChildren()) do
		table.insert(names, child.Name)
	end
	table.sort(names)

	if #names == 0 then
		return "<no-children>"
	end

	return table.concat(names, ", ")
end

local function splitPath(path: string): { string }
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	return segments
end

local function tracePathFailure(root: Instance, path: string): (Instance?, string?)
	local current: Instance? = root
	for _, segment in ipairs(splitPath(path)) do
		if current == nil then
			return nil, segment
		end

		local nextChild = current:FindFirstChild(segment)
		if nextChild == nil then
			return current, segment
		end

		current = nextChild
	end

	return nil, nil
end

local function warnMissingOnce(root: Instance, path: string, debugMissingTree: boolean?)
	local key = getPathKey(root, path)
	if warnedMissingPaths[key] then
		return
	end

	warnedMissingPaths[key] = true
	warn("[ProjectTreeSpec] Missing:", path)

	if not debugMissingTree then
		return
	end

	local parent, missingSegment = tracePathFailure(root, path)
	if parent and missingSegment then
		warn(string.format(
			"[ProjectTreeSpec] MissingDetail root=%s parent=%s missingSegment=%s children=[%s]",
			root:GetFullName(),
			parent:GetFullName(),
			missingSegment,
			describeChildren(parent)
		))
	end
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

			local ok, result = pcall(function()
				return current:WaitForChild(segment, remaining)
			end)
			child = if ok then result else nil
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
				warnMissingOnce(root, path, options and options.debugMissingTree)
			end
			return nil
		end

		current = current:FindFirstChild(segment)
		if current == nil then
			if shouldWarn then
				warnMissingOnce(root, path, options and options.debugMissingTree)
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

local function normalizePathForRoot(root: Instance, path: string): string
	local rootName = root.Name
	if string.sub(path, 1, #rootName + 1) == rootName .. "." then
		return string.sub(path, #rootName + 2)
	end
	return path
end

function PathResolver.reportMissing(root: Instance, paths: { string }, options: ResolveOptions?): { string }
	local missing = {}
	for _, path in ipairs(paths) do
		local normalizedPath = normalizePathForRoot(root, path)
		if PathResolver.resolvePath(root, normalizedPath, {
			waitTimeout = if options then options.waitTimeout else nil,
			shouldWarn = false,
		}) == nil then
			table.insert(missing, normalizedPath)
		end
	end

	if #missing == 0 then
		print("[ProjectTreeSpec] Startup check complete. Missing instances: 0")
	else
		warn(string.format("[ProjectTreeSpec] Startup check complete. Missing instances: %d", #missing))
		for _, path in ipairs(missing) do
			warnMissingOnce(root, path, options and options.debugMissingTree)
			warn("[ProjectTreeSpec] MissingSummary:", path)
		end
	end

	return missing
end

return PathResolver
