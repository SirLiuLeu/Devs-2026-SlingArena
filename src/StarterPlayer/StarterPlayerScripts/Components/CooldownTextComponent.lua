--!strict

local Component = {}
Component.__index = Component

local function warnMissing(name: string)
	warn(string.format("[UI_MISSING] %s is missing. Create it manually in Studio. See ProjectTreeSpec.lua and UI guide comments.", name))
end

function Component.new(joystickRoot: Instance)
	local root = joystickRoot:FindFirstChild("CooldownText")
	if not root then
		warnMissing("CooldownText")
	elseif root:IsA("GuiObject") then
		root.Visible = false
	elseif root then
		warn(string.format("[UI_MISSING] %s exists but is not a GuiObject.", root:GetFullName()))
	end
	return setmetatable({ Root = root }, Component)
end

function Component:Update(visible: boolean, text: string?)
	if not self.Root or not self.Root:IsA("GuiObject") then
		return
	end
	self.Root.Visible = visible
	if text ~= nil and (self.Root:IsA("TextLabel") or self.Root:IsA("TextButton") or self.Root:IsA("TextBox")) then
		local textObject = self.Root :: any
		textObject.Text = text
	end
end

function Component:Destroy()
	if self.Root and self.Root.Parent then
		self.Root:Destroy()
	end
end

return Component
