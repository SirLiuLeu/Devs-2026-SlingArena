--!strict

local HealthBar = require(script.Parent.HealthBar)
local ChargeBar = require(script.Parent.ChargeBar)
local DiamondDisplay = require(script.Parent.DiamondDisplay)
local SkillButton = require(script.Parent.SkillButton)

export type HUDCallbacks = {
	OnOpenBuffPanel: () -> (),
	OnActivateSkill: () -> (),
}

export type HUDState = {
	CurrentHP: number,
	MaxHP: number,
	ChargeRatio: number,
	Diamonds: number,
	SkillCooldownRemaining: number,
	IsAlive: boolean,
}

export type HUD = {
	Root: Frame,
	Update: (self: HUD, state: HUDState) -> (),
	Destroy: (self: HUD) -> (),
}

local HUD = {}
HUD.__index = HUD

function HUD.new(parent: Instance, callbacks: HUDCallbacks): HUD
	local root = Instance.new("Frame")
	root.Name = "HUD"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = parent

	local keyHints = Instance.new("TextLabel")
	keyHints.BackgroundTransparency = 1
	keyHints.AnchorPoint = Vector2.new(0, 1)
	keyHints.Position = UDim2.fromScale(0.015, 0.985)
	keyHints.Size = UDim2.fromScale(0.28, 0.05)
	keyHints.Text = "[P] Attributes  [Tab] Leaderboard  [E] Skill"
	keyHints.Font = Enum.Font.GothamMedium
	keyHints.TextScaled = true
	keyHints.TextXAlignment = Enum.TextXAlignment.Left
	keyHints.TextColor3 = Color3.fromRGB(155, 185, 230)
	keyHints.Parent = root

	local self = setmetatable({
		Root = root,
		HealthBar = HealthBar.new(root),
		ChargeBar = ChargeBar.new(root),
		DiamondDisplay = DiamondDisplay.new(root, callbacks.OnOpenBuffPanel),
		SkillButton = SkillButton.new(root, callbacks.OnActivateSkill),
	}, HUD)

	return self :: any
end

function HUD:Update(state: HUDState)
	self.HealthBar:Update({
		CurrentHP = state.CurrentHP,
		MaxHP = state.MaxHP,
		IsAlive = state.IsAlive,
	})
	self.ChargeBar:Update(state.ChargeRatio, state.IsAlive)
	self.DiamondDisplay:Update(state.Diamonds)
	self.SkillButton:Update(state.SkillCooldownRemaining)
end

function HUD:Destroy()
	self.Root:Destroy()
end

return HUD
