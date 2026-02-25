--!strict

local TweenService = game:GetService("TweenService")

export type SkillButton = {
	Root: Frame,
	Update: (self: SkillButton, cooldownRemaining: number) -> (),
	Destroy: (self: SkillButton) -> (),
}

local COOLDOWN_WINDOW = 10

local SkillButton = {}
SkillButton.__index = SkillButton

function SkillButton.new(parent: Instance, onActivate: () -> ()): SkillButton
	local root = Instance.new("Frame")
	root.Name = "SkillButton"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromScale(0.5, 0.84)
	root.Size = UDim2.fromScale(0.1, 0.1)
	root.BackgroundTransparency = 1
	root.Parent = parent

	local button = Instance.new("TextButton")
	button.Name = "Activate"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Color3.fromRGB(65, 110, 255)
	button.Text = "SKILL"
	button.TextScaled = true
	button.Font = Enum.Font.GothamBlack
	button.TextColor3 = Color3.fromRGB(230, 245, 255)
	button.BorderSizePixel = 0
	button.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	local cooldownRing = Instance.new("ImageLabel")
	cooldownRing.Name = "CooldownRing"
	cooldownRing.BackgroundTransparency = 1
	cooldownRing.Size = UDim2.fromScale(1.35, 1.35)
	cooldownRing.AnchorPoint = Vector2.new(0.5, 0.5)
	cooldownRing.Position = UDim2.fromScale(0.5, 0.5)
	cooldownRing.Image = "rbxassetid://4894687986"
	cooldownRing.ImageColor3 = Color3.fromRGB(85, 210, 255)
	cooldownRing.ImageTransparency = 1
	cooldownRing.Parent = root

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 1.08)
	hint.Size = UDim2.fromScale(2.4, 0.36)
	hint.Text = "Skill [E]"
	hint.Font = Enum.Font.GothamMedium
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(180, 210, 255)
	hint.Parent = root

	button.Activated:Connect(onActivate)

	return setmetatable({
		Root = root,
		Button = button,
		CooldownRing = cooldownRing,
	}, SkillButton) :: any
end

function SkillButton:Update(cooldownRemaining: number)
	local ratio = math.clamp(cooldownRemaining / COOLDOWN_WINDOW, 0, 1)
	local isReady = cooldownRemaining <= 0

	self.Button.Active = isReady
	self.Button.AutoButtonColor = isReady
	self.Button.BackgroundColor3 = if isReady then Color3.fromRGB(65, 110, 255) else Color3.fromRGB(65, 65, 85)
	self.Button.Text = if isReady then "SKILL" else string.format("%.1f", cooldownRemaining)

	self.CooldownRing.ImageTransparency = if isReady then 1 else 0.08
	TweenService:Create(self.CooldownRing, TweenInfo.new(0.12), {
		Rotation = 360 * ratio,
		ImageColor3 = if ratio > 0.65 then Color3.fromRGB(255, 110, 110) else Color3.fromRGB(85, 210, 255),
	}):Play()
end

function SkillButton:Destroy()
	self.Root:Destroy()
end

return SkillButton
