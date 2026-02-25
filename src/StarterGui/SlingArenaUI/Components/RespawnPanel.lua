--!strict

local TweenService = game:GetService("TweenService")

export type RespawnPanel = {
	Root: Frame,
	SetVisible: (self: RespawnPanel, isVisible: boolean) -> (),
	UpdateCost: (self: RespawnPanel, cost: number) -> (),
	Destroy: (self: RespawnPanel) -> (),
}

local RespawnPanel = {}
RespawnPanel.__index = RespawnPanel

function RespawnPanel.new(parent: Instance, onRespawn: (respawnType: string) -> ()): RespawnPanel
	local root = Instance.new("Frame")
	root.Name = "RespawnPanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 1.3)
	root.Size = UDim2.fromScale(0.34, 0.26)
	root.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
	root.BackgroundTransparency = 0.08
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.05, 0.08)
	title.Size = UDim2.fromScale(0.9, 0.2)
	title.Text = "Respawn"
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(235, 240, 255)
	title.Parent = root

	local costButton = Instance.new("TextButton")
	costButton.Name = "DiamondRespawn"
	costButton.AnchorPoint = Vector2.new(0.5, 0)
	costButton.Position = UDim2.fromScale(0.5, 0.38)
	costButton.Size = UDim2.fromScale(0.85, 0.24)
	costButton.BackgroundColor3 = Color3.fromRGB(20, 85, 185)
	costButton.BorderSizePixel = 0
	costButton.TextColor3 = Color3.fromRGB(230, 240, 255)
	costButton.Font = Enum.Font.GothamBold
	costButton.TextScaled = true
	costButton.Text = "Respawn with Diamonds (0)"
	costButton.Parent = root

	local freeButton = Instance.new("TextButton")
	freeButton.Name = "FreeRespawn"
	freeButton.AnchorPoint = Vector2.new(0.5, 0)
	freeButton.Position = UDim2.fromScale(0.5, 0.68)
	freeButton.Size = UDim2.fromScale(0.85, 0.2)
	freeButton.BackgroundColor3 = Color3.fromRGB(55, 65, 85)
	freeButton.BorderSizePixel = 0
	freeButton.TextColor3 = Color3.fromRGB(230, 240, 255)
	freeButton.Font = Enum.Font.GothamBold
	freeButton.TextScaled = true
	freeButton.Text = "Free Reset"
	freeButton.Parent = root

	for _, button in ipairs({costButton, freeButton}) do
		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0.14, 0)
		buttonCorner.Parent = button
	end

	costButton.Activated:Connect(function()
		onRespawn("Diamonds")
	end)

	freeButton.Activated:Connect(function()
		onRespawn("Free")
	end)

	return setmetatable({
		Root = root,
		CostButton = costButton,
		Visible = false,
	}, RespawnPanel) :: any
end

function RespawnPanel:UpdateCost(cost: number)
	self.CostButton.Text = string.format("Respawn with Diamonds (%d)", cost)
end

function RespawnPanel:SetVisible(isVisible: boolean)
	if self.Visible == isVisible then
		return
	end
	self.Visible = isVisible
	self.Root.Visible = true
	TweenService:Create(self.Root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = if isVisible then UDim2.fromScale(0.5, 0.6) else UDim2.fromScale(0.5, 1.3),
	}):Play()
	if not isVisible then
		task.delay(0.24, function()
			if not self.Visible then
				self.Root.Visible = false
			end
		end)
	end
end

function RespawnPanel:Destroy()
	self.Root:Destroy()
end

return RespawnPanel
