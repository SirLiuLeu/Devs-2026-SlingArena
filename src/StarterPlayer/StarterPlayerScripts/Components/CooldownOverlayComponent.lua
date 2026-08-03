--!strict

local Component = {}
Component.__index = Component

local function warnMissing(name: string)
	warn(string.format("[UI_MISSING] %s is missing. Create it manually in Studio. See ProjectTreeSpec.lua and UI guide comments.", name))
end

function Component.new(parent: Instance)
	local root = parent:FindFirstChild("CooldownOverlay")
	if not root then
		warnMissing("CooldownOverlay")
	elseif root:IsA("GuiObject") then
		root.Visible = false
	end
	return setmetatable({ Root = root }, Component)
end

function Component:Update(visible: boolean, ratio: number?)
	if not self.Root or not self.Root:IsA("GuiObject") then
		return
	end
	self.Root.Visible = visible
	if ratio ~= nil then
		local normalized = math.clamp(ratio, 0, 1)
		self.Root.BackgroundTransparency = 0.65 + (0.35 * normalized)
	end
end

function Component:Destroy()
	if self.Root and self.Root.Parent then
		self.Root:Destroy()
	end
end

return Component
