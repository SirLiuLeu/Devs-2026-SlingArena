--!strict

local UiBindManager = {}
UiBindManager.__index = UiBindManager

export type UiBindManager = typeof(setmetatable({} :: {
	PlayerGui: PlayerGui,
	Connections: { RBXScriptConnection },
	Bindings: { [string]: { Path: string, Callback: (Instance?) -> (), Last: Instance? } },
}, UiBindManager))

local function resolvePath(root: Instance, path: string): Instance?
	local current: Instance? = root
	for segment in string.gmatch(path, "[^%.]+") do
		current = if current then current:FindFirstChild(segment) else nil
		if not current then return nil end
	end
	return current
end

function UiBindManager.new(playerGui: PlayerGui): UiBindManager
	local self = setmetatable({}, UiBindManager)
	self.PlayerGui = playerGui
	self.Connections = {}
	self.Bindings = {}
	return self
end

function UiBindManager:Bind(key: string, path: string, callback: (Instance?) -> ())
	self.Bindings[key] = { Path = path, Callback = callback, Last = nil }
	self:_refreshKey(key)
end

function UiBindManager:_refreshKey(key: string)
	local binding = self.Bindings[key]
	if not binding then return end
	local resolved = resolvePath(self.PlayerGui, binding.Path)
	if resolved ~= binding.Last then
		binding.Last = resolved
		binding.Callback(resolved)
	end
end

function UiBindManager:RefreshAll()
	for key in pairs(self.Bindings) do
		self:_refreshKey(key)
	end
end

function UiBindManager:Start()
	table.insert(self.Connections, self.PlayerGui.ChildAdded:Connect(function() self:RefreshAll() end))
	table.insert(self.Connections, self.PlayerGui.DescendantAdded:Connect(function() self:RefreshAll() end))
	table.insert(self.Connections, self.PlayerGui.ChildRemoved:Connect(function() self:RefreshAll() end))
	table.insert(self.Connections, self.PlayerGui.DescendantRemoving:Connect(function() task.defer(function() self:RefreshAll() end) end))
	self:RefreshAll()
end

function UiBindManager:Destroy()
	for _, connection in ipairs(self.Connections) do connection:Disconnect() end
	table.clear(self.Connections)
	table.clear(self.Bindings)
end

return UiBindManager
