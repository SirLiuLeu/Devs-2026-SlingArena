--!strict

local TweenService = game:GetService("TweenService")

export type HealthBarState = {
	CurrentHP: number,
	MaxHP: number,
	IsAlive: boolean,
}

export type HealthBar = {
	Root: Frame,
	Update: (self: HealthBar, state: HealthBarState) -> (),
	Destroy: (self: HealthBar) -> (),
}

local BAR_TWEEN = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local HealthBar = {}
HealthBar.__index = HealthBar

function HealthBar.new(parent: Instance): HealthBar
	local root = Instance.new("Frame")
	root.Name = "HealthBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromScale(0.5, 0.965)
	root.Size = UDim2.fromScale(0.35, 0.05)
	root.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.4, 0)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 115, 150)
	stroke.Transparency = 0.4
	stroke.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(80, 240, 140)
	fill.BorderSizePixel = 0
	fill.Parent = root

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.4, 0)
	fillCorner.Parent = fill

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 255, 165)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 180, 255)),
	})
	gradient.Rotation = 20
	gradient.Parent = fill

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "ValueLabel"
	valueLabel.BackgroundTransparency = 1
	valueLabel.Size = UDim2.fromScale(1, 1)
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextColor3 = Color3.fromRGB(230, 240, 255)
	valueLabel.TextStrokeTransparency = 0.7
	valueLabel.Text = "0 / 0"
	valueLabel.Parent = root

	local self = setmetatable({
		Root = root,
		Fill = fill,
		ValueLabel = valueLabel,
		FillGradient = gradient,
	}, HealthBar)

	return self :: any
end

function HealthBar:Update(state: HealthBarState)
	if not state.IsAlive then
		self.Root.Visible = false
		return
	end

	self.Root.Visible = true
	local maxHP = math.max(state.MaxHP, 1)
	local ratio = math.clamp(state.CurrentHP / maxHP, 0, 1)
	self.ValueLabel.Text = string.format("%d / %d", math.floor(state.CurrentHP + 0.5), math.floor(maxHP + 0.5))

	local targetColor = if ratio < 0.3 then Color3.fromRGB(255, 60, 78) else Color3.fromRGB(80, 240, 140)
	TweenService:Create(self.Fill, BAR_TWEEN, {
		Size = UDim2.fromScale(ratio, 1),
		BackgroundColor3 = targetColor,
	}):Play()
end

function HealthBar:Destroy()
	self.Root:Destroy()
end

return HealthBar
