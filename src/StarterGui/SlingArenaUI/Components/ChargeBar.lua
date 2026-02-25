--!strict

local TweenService = game:GetService("TweenService")

export type ChargeBar = {
	Root: Frame,
	Update: (self: ChargeBar, ratio: number, isAlive: boolean) -> (),
	Destroy: (self: ChargeBar) -> (),
}

local ChargeBar = {}
ChargeBar.__index = ChargeBar

function ChargeBar.new(parent: Instance): ChargeBar
	local root = Instance.new("Frame")
	root.Name = "ChargeBar"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.fromScale(0.5, 0.91)
	root.Size = UDim2.fromScale(0.25, 0.03)
	root.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = root

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(96, 180, 255)
	fill.BorderSizePixel = 0
	fill.Parent = root

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0.5, 0)
	fillCorner.Parent = fill

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 255, 255)),
	})
	gradient.Parent = fill

	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(120, 255, 255)
	glow.Thickness = 2
	glow.Transparency = 1
	glow.Parent = root

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "Charge"
	label.Font = Enum.Font.GothamMedium
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(230, 245, 255)
	label.TextStrokeTransparency = 0.75
	label.Parent = root

	return setmetatable({
		Root = root,
		Fill = fill,
		Glow = glow,
	}, ChargeBar) :: any
end

function ChargeBar:Update(ratio: number, isAlive: boolean)
	self.Root.Visible = isAlive
	local clamped = math.clamp(ratio, 0, 1)
	TweenService:Create(self.Fill, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(clamped, 1),
	}):Play()

	TweenService:Create(self.Glow, TweenInfo.new(0.16), {
		Transparency = if clamped >= 1 then 0 else 1,
	}):Play()
end

function ChargeBar:Destroy()
	self.Root:Destroy()
end

return ChargeBar
