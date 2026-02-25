--!strict

local TweenService = game:GetService("TweenService")

export type DiamondDisplay = {
	Root: Frame,
	Update: (self: DiamondDisplay, diamonds: number) -> (),
	Destroy: (self: DiamondDisplay) -> (),
}

local DiamondDisplay = {}
DiamondDisplay.__index = DiamondDisplay

function DiamondDisplay.new(parent: Instance, onBuffOpen: () -> ()): DiamondDisplay
	local root = Instance.new("Frame")
	root.Name = "DiamondDisplay"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.fromScale(0.985, 0.03)
	root.Size = UDim2.fromScale(0.2, 0.075)
	root.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
	root.BackgroundTransparency = 0.2
	root.BorderSizePixel = 0
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 180, 255)
	stroke.Transparency = 0.2
	stroke.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "DiamondLabel"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.08, 0)
	label.Size = UDim2.fromScale(0.64, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(140, 235, 255)
	label.Text = "💎 0"
	label.Parent = root

	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenBuffPanel"
	openButton.AnchorPoint = Vector2.new(1, 0.5)
	openButton.Position = UDim2.fromScale(0.95, 0.5)
	openButton.Size = UDim2.fromScale(0.24, 0.74)
	openButton.Text = "BUFF"
	openButton.TextScaled = true
	openButton.Font = Enum.Font.GothamBold
	openButton.TextColor3 = Color3.fromRGB(230, 245, 255)
	openButton.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
	openButton.BorderSizePixel = 0
	openButton.Parent = root

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.22, 0)
	buttonCorner.Parent = openButton

	openButton.Activated:Connect(onBuffOpen)

	return setmetatable({
		Root = root,
		Label = label,
		LastDiamonds = 0,
	}, DiamondDisplay) :: any
end

function DiamondDisplay:Update(diamonds: number)
	self.Label.Text = string.format("💎 %d", diamonds)
	if diamonds > self.LastDiamonds then
		local popIn = TweenService:Create(self.Root, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.22, 0.083),
		})
		local popOut = TweenService:Create(self.Root, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.2, 0.075),
		})
		popIn:Play()
		popIn.Completed:Once(function()
			popOut:Play()
		end)
	end
	self.LastDiamonds = diamonds
end

function DiamondDisplay:Destroy()
	self.Root:Destroy()
end

return DiamondDisplay
