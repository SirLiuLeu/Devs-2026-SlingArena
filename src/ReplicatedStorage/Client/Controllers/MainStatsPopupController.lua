--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

	self.AvailablePoints = 0
	self.AllocatedTotal = 0
	self.AllocatedByAttribute = {}
	self.BaseValues = {}
	self.LastState = nil

	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		self.AllocatedByAttribute[attributeKey] = 0
		self.BaseValues[attributeKey] = 0
	end

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
	self.BodyContainer = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.BodyContainer, "GuiObject")
	self.AttributeList = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.AttributeList, "GuiObject")
	self.ResetButton = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.ResetButton, "TextButton")
	self.AcceptButton = self:_resolveTyped(ProjectTreeSpec.UI.SlingStats.AcceptButton, "TextButton")

	self.RowBindings = {}
	self:_buildDynamicRows()
end

function MainStatsPopupController:_buildDynamicRows()
	if not self.AttributeList then
		warn("[STATS_UI] AttributeList missing for dynamic row generation")
		return
	end
	for _, child in ipairs(self.AttributeList:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "AttributeRowTemplate" and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	local template = ReplicatedStorage:FindFirstChild("Assets")
	template = template and template:FindFirstChild("UI")
	template = template and template:FindFirstChild("AttributeRowTemplate")
	if not (template and template:IsA("GuiObject")) then
		warn("[STATS_UI] ReplicatedStorage.Assets.UI.AttributeRowTemplate missing")
		return
	end
	for _, attributeKey in ipairs(ATTRIBUTE_ORDER) do
		local row = template:Clone()
		row.Name = string.format("%sRow", attributeKey)
		row.Visible = true
		row.Parent = self.AttributeList
		self.RowBindings[attributeKey] = {
			Row = row,
			NameLabel = row:FindFirstChild("AttributeNameLabel"),
			CurrentValueLabel = row:FindFirstChild("CurrentValueLabel"),
			AllocatedPointsLabel = row:FindFirstChild("AllocatedPointsLabel"),
			IncreaseButton = row:FindFirstChild("IncreaseButton"),
			DecreaseButton = row:FindFirstChild("DecreaseButton"),
		}
		local rowBinding = self.RowBindings[attributeKey]
		if rowBinding.IncreaseButton and rowBinding.IncreaseButton:IsA("TextButton") then
			table.insert(self.Connections, rowBinding.IncreaseButton.MouseButton1Click:Connect(function()
				self:_changeAllocation(attributeKey, 1)
			end))
		end
		if rowBinding.DecreaseButton and rowBinding.DecreaseButton:IsA("TextButton") then
			table.insert(self.Connections, rowBinding.DecreaseButton.MouseButton1Click:Connect(function()
				self:_changeAllocation(attributeKey, -1)
			end))
		end
	end
end

function MainStatsPopupController:_bindStaticControls()
	if self.TitleLabel then
		self.TitleLabel.Text = "Stats"
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

	self:_refreshAll()
end

function MainStatsPopupController:_changeAllocation(attributeKey: AttributeKey, delta: number)
	local current = self.AllocatedByAttribute[attributeKey] or 0
	local nextValue = math.max(0, current + delta)

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

function MainStatsPopupController:_refreshAll()
	self:_refreshHeader()
	self:_refreshRows()
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
