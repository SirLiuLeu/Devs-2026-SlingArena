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

function Component.new(joystickRoot: Instance)
    local root = getGuiObject(joystickRoot, "CooldownOverlay")
    local leftClip = getClip(root, "LeftHalf")
    local rightClip = getClip(root, "RightHalf")

    if root then
        root.Visible = false
    end

    return setmetatable({
        Root = root,
        LeftClip = leftClip,
        RightClip = rightClip,
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

    -- Đổi Rotation trên Clip
    if self.RightClip then
        self.RightClip.Rotation = rightDegrees
    end
    if self.LeftClip then
        self.LeftClip.Rotation = leftDegrees
    end
end

function Component:Destroy()
    if self.Root and self.Root.Parent then
        self.Root:Destroy()
    end
end

return Component