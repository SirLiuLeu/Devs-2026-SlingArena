--!strict

local TweenService = game:GetService("TweenService")

export type AttributeState = {
	AttributePoints: number,
	Attributes: {[string]: number},
}

type AttributeRow = {
	ValueLabel: TextLabel,
	AddButton: TextButton,
}

export type AttributePanel = {
	Root: Frame,
	Visible: boolean,
	Update: (self: AttributePanel, state: AttributeState) -> (),
	Toggle: (self: AttributePanel) -> (),
	Destroy: (self: AttributePanel) -> (),
}

local STAT_ORDER = {"Speed", "HPBonus", "LaunchPower", "ChargeSpeed", "ReflectDamage"}
local STAT_CAPS = {
	Speed = 25,
	HPBonus = 25,
	LaunchPower = 25,
	ChargeSpeed = 25,
	ReflectDamage = 25,
}

local AttributePanel = {}
AttributePanel.__index = AttributePanel

function AttributePanel.new(parent: Instance, onUpgrade: (attributeName: string) -> ()): AttributePanel
	local root = Instance.new("Frame")
	root.Name = "AttributePanel"
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.fromScale(-0.4, 0.52)
	root.Size = UDim2.fromScale(0.3, 0.55)
	root.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.Visible = true
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.06, 0)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 150, 255)
	stroke.Transparency = 0.2
	stroke.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.06, 0.03)
	title.Size = UDim2.fromScale(0.88, 0.1)
	title.Text = "Attributes [P]"
	title.TextScaled = true
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(230, 240, 255)
	title.Parent = root

	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "PointsLabel"
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Position = UDim2.fromScale(0.06, 0.12)
	pointsLabel.Size = UDim2.fromScale(0.88, 0.08)
	pointsLabel.Text = "Points: 0"
	pointsLabel.TextScaled = true
	pointsLabel.Font = Enum.Font.GothamMedium
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	pointsLabel.TextColor3 = Color3.fromRGB(150, 210, 255)
	pointsLabel.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.02, 0)

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromScale(0.04, 0.23)
	container.Size = UDim2.fromScale(0.92, 0.72)
	container.Parent = root
	list.Parent = container

	local rows: {[string]: AttributeRow} = {}

	for index, statName in ipairs(STAT_ORDER) do
		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.fromScale(1, 0.17)
		row.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.Parent = container

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0.2, 0)
		rowCorner.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromScale(0.04, 0)
		name.Size = UDim2.fromScale(0.52, 1)
		name.Text = statName
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Font = Enum.Font.GothamMedium
		name.TextScaled = true
		name.TextColor3 = Color3.fromRGB(220, 230, 255)
		name.Parent = row

		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.Position = UDim2.fromScale(0.58, 0)
		value.Size = UDim2.fromScale(0.18, 1)
		value.Text = "0"
		value.Font = Enum.Font.GothamBold
		value.TextScaled = true
		value.TextColor3 = Color3.fromRGB(120, 220, 255)
		value.Parent = row

		local add = Instance.new("TextButton")
		add.Name = statName .. "Add"
		add.AnchorPoint = Vector2.new(1, 0.5)
		add.Position = UDim2.fromScale(0.96, 0.5)
		add.Size = UDim2.fromScale(0.18, 0.7)
		add.Text = "+"
		add.Font = Enum.Font.GothamBlack
		add.TextScaled = true
		add.TextColor3 = Color3.fromRGB(230, 245, 255)
		add.BackgroundColor3 = Color3.fromRGB(40, 100, 220)
		add.BorderSizePixel = 0
		add.Parent = row

		local addCorner = Instance.new("UICorner")
		addCorner.CornerRadius = UDim.new(0.28, 0)
		addCorner.Parent = add

		add.Activated:Connect(function()
			onUpgrade(statName)
		end)

		rows[statName] = { ValueLabel = value, AddButton = add }
	end

	return setmetatable({
		Root = root,
		Rows = rows,
		PointsLabel = pointsLabel,
		Visible = false,
	}, AttributePanel) :: any
end

function AttributePanel:Toggle()
	self.Visible = not self.Visible
	local targetX = if self.Visible then 0.015 else -0.4
	TweenService:Create(self.Root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(targetX, 0.52),
	}):Play()
end

function AttributePanel:Update(state: AttributeState)
	self.PointsLabel.Text = string.format("Points: %d", state.AttributePoints)
	for statName, row in pairs(self.Rows) do
		local statValue = state.Attributes[statName] or 0
		row.ValueLabel.Text = tostring(statValue)
		local canUpgrade = state.AttributePoints > 0 and statValue < (STAT_CAPS[statName] or math.huge)
		row.AddButton.Active = canUpgrade
		row.AddButton.AutoButtonColor = canUpgrade
		row.AddButton.BackgroundColor3 = if canUpgrade then Color3.fromRGB(40, 100, 220) else Color3.fromRGB(60, 60, 70)
		row.AddButton.TextColor3 = if canUpgrade then Color3.fromRGB(230, 245, 255) else Color3.fromRGB(140, 150, 170)
	end
end

function AttributePanel:Destroy()
	self.Root:Destroy()
end

return AttributePanel
