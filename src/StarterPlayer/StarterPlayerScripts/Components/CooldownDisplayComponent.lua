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

-- Đổi từ getFill sang getClip vì Clip mới là object thực hiện Rotation
local function getClip(overlay: Instance?, halfName: string): GuiObject?
    local half = getGuiObject(overlay, halfName)
    return getGuiObject(half, "Clip")
end

local function getTextObject(parent: Instance?): GuiObject?
	local child = if parent then parent:FindFirstChild("CooldownText") else nil
	if not child then
		warnMissing("CooldownText")
		return nil
	end
	if not child:IsA("GuiObject") then
		warn(string.format("[UI_MISSING] %s exists but is not a GuiObject.", child:GetFullName()))
		return nil
	end
	child.Visible = false
	return child
end

function Component.new(joystickRoot: Instance)
    local root = getGuiObject(joystickRoot, "CooldownOverlay")
    local leftClip = getClip(root, "LeftHalf")
    local rightClip = getClip(root, "RightHalf")
    local text = getTextObject(joystickRoot)

    if root then
        root.Visible = false
    end

    return setmetatable({
        Root = root,
        LeftClip = leftClip,
        RightClip = rightClip,
        Text = text,
    }, Component)
end

function Component:Update(visible: boolean, progress: number?, text: string?)
    if not self.Root then
        return
    end

    self.Root.Visible = visible

    local normalized = math.clamp(progress or 0, 0, 1)
    local sweepDegrees = normalized * FULL_SWEEP_DEGREES
    local rightDegrees = math.clamp(sweepDegrees, 0, HALF_SWEEP_DEGREES)
    local leftDegrees = math.clamp(sweepDegrees - HALF_SWEEP_DEGREES, 0, HALF_SWEEP_DEGREES)

    -- Đổi Rotation trên Clip
    if self.RightClip then
        self.RightClip.Rotation = rightDegrees
    end
    if self.LeftClip then
        self.LeftClip.Rotation = leftDegrees
    end

    if self.Text and self.Text:IsA("GuiObject") then
        self.Text.Visible = visible
        if text ~= nil and (self.Text:IsA("TextLabel") or self.Text:IsA("TextButton") or self.Text:IsA("TextBox")) then
            (self.Text :: any).Text = text
        end
    end
end

function Component:Destroy()
    if self.Root and self.Root.Parent then
        self.Root.Visible = false
    end
    if self.Text and self.Text.Parent and self.Text:IsA("GuiObject") then
        self.Text.Visible = false
    end
end

return Component