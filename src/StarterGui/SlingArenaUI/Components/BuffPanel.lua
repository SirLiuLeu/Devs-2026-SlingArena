--!strict

local TweenService = game:GetService("TweenService")

export type BuffPanelState = {
	Diamonds: number,
	HasMatchBuff: boolean,
}

export type BuffPanel = {
	Root: Frame,
	Visible: boolean,
	Toggle: (self: BuffPanel) -> (),
	Update: (self: BuffPanel, state: BuffPanelState) -> (),
	Destroy: (self: BuffPanel) -> (),
}

local BUFF_COST = 20

local BuffPanel = {}
BuffPanel.__index = BuffPanel

function BuffPanel.new(parent: Instance, onPurchase: () -> ()): BuffPanel
	local root = Instance.new("Frame")
	root.Name = "BuffPanel"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.fromScale(1.35, 0.12)
	root.Size = UDim2.fromScale(0.26, 0.3)
	root.BackgroundColor3 = Color3.fromRGB(13, 15, 22)
	root.BackgroundTransparency = 0.08
	root.BorderSizePixel = 0
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.08, 0)
	corner.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.07, 0.06)
	title.Size = UDim2.fromScale(0.86, 0.13)
	title.Text = "Match Buff"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(220, 240, 255)
	title.Parent = root

	local details = Instance.new("TextLabel")
	details.BackgroundTransparency = 1
	details.Position = UDim2.fromScale(0.07, 0.2)
	details.Size = UDim2.fromScale(0.86, 0.45)
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.TextWrapped = true
	details.Text = "• EXP +10%\n• HP +10%\n• Damage +10%\n• Charge speed +10%"
	details.Font = Enum.Font.GothamMedium
	details.TextScaled = true
	details.TextColor3 = Color3.fromRGB(175, 205, 255)
	details.Parent = root

	local purchase = Instance.new("TextButton")
	purchase.Name = "Purchase"
	purchase.AnchorPoint = Vector2.new(0.5, 1)
	purchase.Position = UDim2.fromScale(0.5, 0.94)
	purchase.Size = UDim2.fromScale(0.88, 0.2)
	purchase.Text = "Purchase (20 💎)"
	purchase.TextScaled = true
	purchase.Font = Enum.Font.GothamBold
	purchase.TextColor3 = Color3.fromRGB(230, 245, 255)
	purchase.BackgroundColor3 = Color3.fromRGB(40, 90, 180)
	purchase.BorderSizePixel = 0
	purchase.Parent = root

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0.18, 0)
	buttonCorner.Parent = purchase

	purchase.Activated:Connect(onPurchase)

	return setmetatable({
		Root = root,
		Purchase = purchase,
		Visible = false,
	}, BuffPanel) :: any
end

function BuffPanel:Toggle()
	self.Visible = not self.Visible
	TweenService:Create(self.Root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = if self.Visible then UDim2.fromScale(0.985, 0.12) else UDim2.fromScale(1.35, 0.12),
	}):Play()
end

function BuffPanel:Update(state: BuffPanelState)
	local canBuy = state.Diamonds >= BUFF_COST and not state.HasMatchBuff
	self.Purchase.Active = canBuy
	self.Purchase.AutoButtonColor = canBuy
	if state.HasMatchBuff then
		self.Purchase.Text = "Active"
	elseif state.Diamonds < BUFF_COST then
		self.Purchase.Text = "Not enough diamonds"
	else
		self.Purchase.Text = "Purchase (20 💎)"
	end
	self.Purchase.BackgroundColor3 = if canBuy then Color3.fromRGB(40, 90, 180) else Color3.fromRGB(60, 60, 70)
end

function BuffPanel:Destroy()
	self.Root:Destroy()
end

return BuffPanel
