--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local MainStatsPopupController = {}
MainStatsPopupController.__index = MainStatsPopupController

type Dependencies = {
	ClientService: any,
}

type AttributeKey = "HP" | "BaseDamage" | "RegenRate" | "ReflectDamage" | "LaunchSpeed" | "LaunchRange" | "ChargeSpeed" | "MoveSpeed"

local ATTRIBUTE_ORDER: { AttributeKey } = {
	"HP",
	"BaseDamage",
	"RegenRate",
	"ReflectDamage",
	"LaunchSpeed",
	"LaunchRange",
	"ChargeSpeed",
	"MoveSpeed",
}

local ROW_TO_SERVER_ATTRIBUTE: { [AttributeKey]: string } = {
	HP = "MaxHP",
	BaseDamage = "Damage",
	RegenRate = "Regen",
	ReflectDamage = "Reflect",
	LaunchSpeed = "LaunchSpeed",
	LaunchRange = "Range",
	ChargeSpeed = "ChargeSpeed",
	MoveSpeed = "MoveSpeed",
}

local ROW_TO_STATE_FIELD: { [AttributeKey]: string } = {
	HP = "MaxHP",
	BaseDamage = "BaseDamage",
	RegenRate = "RegenRate",
	ReflectDamage = "ReflectDamage",
	LaunchSpeed = "LaunchSpeed",
	LaunchRange = "LaunchRange",
	ChargeSpeed = "ChargeSpeed",
	MoveSpeed = "MoveSpeed",
}

local function toNumber(value: any, fallback: number): number
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

local function formatValue(value: number): string
	if math.abs(value - math.floor(value)) < 0.001 then
		return tostring(math.floor(value))
	end
	return string.format("%.2f", value)
end

function MainStatsPopupController.new(playerGui: PlayerGui, dependencies: Dependencies)
	local self = setmetatable({}, MainStatsPopupController)
	self.PlayerGui = playerGui
	self.ClientService = dependencies.ClientService
	self.Connections = {}
	self.WarnedPaths = {}
	self.IsCollapsed = false

	self.AvailablePoints = 0
	self.AllocatedTotal = 0
	self.AllocatedByAttribute = {}
	self.BaseValues = {}
	self.LastState = nil

	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		self.AllocatedByAttribute[attributeKey] = 0
		self.BaseValues[attributeKey] = 0
	end

	-- [UI_CREATION_GUIDE]
	-- Create in Studio:
	-- StarterGui
	--   SlingStatsUI (ScreenGui)
	--     StatsRoot (Frame)
	--       HeaderBar (Frame)
	--         TitleLabel (TextLabel)
	--         AvailablePointsLabel (TextLabel)
	--         ToggleDropdownButton (TextButton)
	--       BodyContainer (Frame)
	--         AttributeList (Frame)
	--           HPRow | BaseDamageRow | RegenRateRow | ReflectDamageRow | LaunchSpeedRow | LaunchRangeRow | ChargeSpeedRow | MoveSpeedRow
	--             AttributeNameLabel (TextLabel)
	--             CurrentValueLabel (TextLabel)
	--             AllocatedPointsLabel (TextLabel)
	--             DecreaseButton (TextButton)
	--             IncreaseButton (TextButton)
	--         ActionButtonsRow (Frame)
	--           ResetButton (TextButton)
	--           AcceptButton (TextButton)
	--       FooterExpBar (Frame)
	--         ExpBarFill (Frame)
	--         ExpValueLabel (TextLabel)
	--         LevelOnBarLabel (TextLabel)

	self:_resolveUi()
	self:_bindStaticControls()

	return self
end

function MainStatsPopupController:_warnMissingPathOnce(path: string, className: string)
	local warningKey = string.format("%s::%s", path, className)
	if self.WarnedPaths[warningKey] then
		return
	end

	self.WarnedPaths[warningKey] = true
	warn(string.format("[UI_MISSING] %s (%s) is missing. Create it manually in Studio.", path, className))
end

function MainStatsPopupController:_resolve(path: string): Instance?
	return PathResolver.resolvePath(self.PlayerGui, path, {
		waitTimeout = 2,
		shouldWarn = false,
	})
end

function MainStatsPopupController:_resolveTyped(path: string, className: string): Instance?
	local value = self:_resolve(path)
	if value and value.ClassName == className then
		return value
	end
	if className == "GuiObject" and value and value:IsA("GuiObject") then
		return value
	end
	if className == "TextLabel" and value and value:IsA("TextLabel") then
		return value
	end
	if className == "TextButton" and value and value:IsA("TextButton") then
		return value
	end
	self:_warnMissingPathOnce(path, className)
	return nil
end

function MainStatsPopupController:_resolveUi()
	self.ScreenGui = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.ScreenGui, "ScreenGui")
	self.StatsRoot = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.StatsRoot, "GuiObject")
	self.HeaderBar = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.HeaderBar, "GuiObject")
	self.TitleLabel = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.TitleLabel, "TextLabel")
	self.AvailablePointsLabel = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.AvailablePointsLabel, "TextLabel")
	self.ToggleDropdownButton = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.ToggleDropdownButton, "TextButton")
	self.BodyContainer = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.BodyContainer, "GuiObject")
	self.AttributeList = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.AttributeList, "GuiObject")
	self.ResetButton = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.ResetButton, "TextButton")
	self.AcceptButton = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.AcceptButton, "TextButton")
	self.FooterExpBar = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.FooterExpBar, "GuiObject")
	self.ExpBarFill = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.ExpBarFill, "GuiObject")
	self.ExpValueLabel = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.ExpValueLabel, "TextLabel")
	self.LevelOnBarLabel = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.LevelOnBarLabel, "TextLabel")

	self.RowBindings = {}
	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		local rowPath = ProjectTreeSpec.UI.SlingStats.AttributeRows[attributeKey]
		local rowRoot = self:_resolveTyped(rowPath, "GuiObject")
		local binding = {
			Row = rowRoot,
			NameLabel = self:_resolveTyped(string.format("%s.AttributeNameLabel", rowPath), "TextLabel"),
			CurrentValueLabel = self:_resolveTyped(string.format("%s.CurrentValueLabel", rowPath), "TextLabel"),
			AllocatedPointsLabel = self:_resolveTyped(string.format("%s.AllocatedPointsLabel", rowPath), "TextLabel"),
			IncreaseButton = self:_resolveTyped(string.format("%s.IncreaseButton", rowPath), "TextButton"),
			DecreaseButton = self:_resolveTyped(string.format("%s.DecreaseButton", rowPath), "TextButton"),
		}
		self.RowBindings[attributeKey] = binding
	end
end

function MainStatsPopupController:_bindStaticControls()
	if self.TitleLabel then
		self.TitleLabel.Text = "Stats"
	end

	if self.ToggleDropdownButton then
		table.insert(self.Connections, self.ToggleDropdownButton.MouseButton1Click:Connect(function()
			self.IsCollapsed = not self.IsCollapsed
			self:_refreshVisibility()
		end))
	end

	if self.ResetButton then
		table.insert(self.Connections, self.ResetButton.MouseButton1Click:Connect(function()
			self:_resetAllocations()
		end))
	end

	if self.AcceptButton then
		table.insert(self.Connections, self.AcceptButton.MouseButton1Click:Connect(function()
			self:_acceptAllocations()
		end))
	end

	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		local rowBinding = self.RowBindings[attributeKey]
		if rowBinding.IncreaseButton then
			table.insert(self.Connections, rowBinding.IncreaseButton.MouseButton1Click:Connect(function()
				self:_changeAllocation(attributeKey, 1)
			end))
		end
		if rowBinding.DecreaseButton then
			table.insert(self.Connections, rowBinding.DecreaseButton.MouseButton1Click:Connect(function()
				self:_changeAllocation(attributeKey, -1)
			end))
		end
	end

	self:_refreshVisibility()
	self:_refreshAll()
end

function MainStatsPopupController:_refreshVisibility()
	if self.BodyContainer then
		self.BodyContainer.Visible = not self.IsCollapsed
	end
	if self.FooterExpBar then
		self.FooterExpBar.Visible = true
	end
end

function MainStatsPopupController:_changeAllocation(attributeKey: AttributeKey, delta: number)
	local current = self.AllocatedByAttribute[attributeKey] or 0
	local nextValue = current + delta
	if nextValue < 0 then
		nextValue = 0
	end

	if delta > 0 and self.AllocatedTotal >= self.AvailablePoints then
		return
	end

	if nextValue == current then
		return
	end

	self.AllocatedByAttribute[attributeKey] = nextValue
	self.AllocatedTotal += (nextValue - current)
	self:_refreshAll()
end

function MainStatsPopupController:_resetAllocations()
	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		self.AllocatedByAttribute[attributeKey] = 0
	end
	self.AllocatedTotal = 0
	self:_refreshAll()
end

function MainStatsPopupController:_acceptAllocations()
	local spentAny = false
	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		local points = self.AllocatedByAttribute[attributeKey] or 0
		local serverAttributeName = ROW_TO_SERVER_ATTRIBUTE[attributeKey]
		if points > 0 and serverAttributeName ~= nil then
			for _ = 1, points do
				self.ClientService:RequestAttributeUpgrade(serverAttributeName)
				spentAny = true
			end
		end
	end

	if spentAny then
		self:_resetAllocations()
	end
end

function MainStatsPopupController:_refreshHeader()
	if self.AvailablePointsLabel then
		self.AvailablePointsLabel.Text = string.format("Available Points: %d", math.max(self.AvailablePoints - self.AllocatedTotal, 0))
	end
end

function MainStatsPopupController:_refreshRows()
	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		local rowBinding = self.RowBindings[attributeKey]
		local baseValue = self.BaseValues[attributeKey] or 0
		local allocated = self.AllocatedByAttribute[attributeKey] or 0

		if rowBinding.NameLabel then
			rowBinding.NameLabel.Text = attributeKey
		end
		if rowBinding.CurrentValueLabel then
			rowBinding.CurrentValueLabel.Text = formatValue(baseValue + allocated)
		end
		if rowBinding.AllocatedPointsLabel then
			rowBinding.AllocatedPointsLabel.Text = string.format("+%d", allocated)
		end
	end
end

function MainStatsPopupController:_refreshExpBar()
	local state = self.LastState
	local level = toNumber(state and state.Level, 1)
	local currentExp = toNumber(state and state.Exp, 0)
	local requiredExp = math.max(LevelConfig.RequiredExp(level), 1)
	local fillRatio = math.clamp(currentExp / requiredExp, 0, 1)

	if self.ExpBarFill then
		self.ExpBarFill.Size = UDim2.new(fillRatio, 0, 1, 0)
	end
	if self.ExpValueLabel then
		self.ExpValueLabel.Text = string.format("%d / %d", math.floor(currentExp), math.floor(requiredExp))
	end
	if self.LevelOnBarLabel then
		self.LevelOnBarLabel.Text = string.format("LV %d", math.floor(level))
	end
end

function MainStatsPopupController:_refreshAll()
	self:_refreshHeader()
	self:_refreshRows()
	self:_refreshExpBar()
end

function MainStatsPopupController:ApplyState(state: { [string]: any })
	self.LastState = state
	self.AvailablePoints = math.max(0, math.floor(toNumber(state.AttributePoints, 0)))

	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		local stateField = ROW_TO_STATE_FIELD[attributeKey]
		local nextValue = toNumber(state[stateField], 0)
		self.BaseValues[attributeKey] = nextValue
	end

	self:_refreshAll()
end

function MainStatsPopupController:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
end

return MainStatsPopupController
