--!strict

local Component = {}
Component.__index = Component

local FULL_SWEEP_DEGREES = 360
local HALF_SWEEP_DEGREES = 180

local function warnMissing(name: string)
	warn(string.format("[UI_MISSING] %s is missing. Create it manually in Studio. See ProjectTreeSpec.lua and UI guide comments.", name))
end

local function getGuiObject(parent: Instance?, name: string): GuiObject?
	local child = if parent then parent:FindFirstChild(name) else nil
	if not child then
		warnMissing(name)
		return nil
	end
	if not child:IsA("GuiObject") then
		warn(string.format("[UI_MISSING] %s exists but is not a GuiObject.", child:GetFullName()))
		return nil
	end
	return child
end

local function getFill(overlay: Instance?, halfName: string): GuiObject?
	local half = getGuiObject(overlay, halfName)
	local clip = getGuiObject(half, "Clip")
	return getGuiObject(clip, "Fill")
end

function Component.new(joystickRoot: Instance)
	local root = getGuiObject(joystickRoot, "CooldownOverlay")
	local leftFill = getFill(root, "LeftHalf")
	local rightFill = getFill(root, "RightHalf")

	if root then
		root.Visible = false
	end

	return setmetatable({
		Root = root,
		LeftFill = leftFill,
		RightFill = rightFill,
	}, Component)
end

function Component:Update(visible: boolean, progress: number?)
	if not self.Root then
		return
	end

	self.Root.Visible = visible

	local normalized = math.clamp(progress or 0, 0, 1)
	local sweepDegrees = normalized * FULL_SWEEP_DEGREES
	local rightDegrees = math.clamp(sweepDegrees, 0, HALF_SWEEP_DEGREES)
	local leftDegrees = math.clamp(sweepDegrees - HALF_SWEEP_DEGREES, 0, HALF_SWEEP_DEGREES)

	if self.RightFill then
		self.RightFill.Rotation = rightDegrees
	end
	if self.LeftFill then
		self.LeftFill.Rotation = leftDegrees
	end
end

function Component:Destroy()
	if self.Root and self.Root.Parent then
		self.Root:Destroy()
	end
end

return Component
