--!strict

local Component = {}
Component.__index = Component

local function warnMissing(name: string)
	warn(string.format("[UI_MISSING] %s is missing. Create it manually in Studio. See ProjectTreeSpec.lua and UI guide comments.", name))
end

function Component.new(parent: Instance)
	-- [UI_CREATION_GUIDE]
	-- Create this component manually as descendants under StarterGui.LauncherArenaUI (ScreenGui)
	-- with matching names and instance types expected by your UI prefab.
	local root = parent:FindFirstChild(script.Name)
	if not root then
		warnMissing(script.Name)
	end
	return setmetatable({ Root = root }, Component)
end

function Component:Update(...)
	if not self.Root then
		return
	end
	local _ = { ... }
end

function Component:Destroy()
	if self.Root and self.Root.Parent then
		self.Root:Destroy()
	end
end

return Component
