--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local HUD = require(script.Components.HUD)
local AttributePanel = require(script.Components.AttributePanel)
local RespawnPanel = require(script.Components.RespawnPanel)
local BuffPanel = require(script.Components.BuffPanel)
local LeaderboardUI = require(script.Components.LeaderboardUI)

export type LeaderboardRow = {
	UserId: number,
	Name: string,
	Level: number,
	Size: number,
	Kills: number,
}

export type UIState = {
	Level: number,
	Exp: number,
	RequiredEXP: number,
	Size: number,
	CurrentHP: number,
	MaxHP: number,
	ChargeRatio: number,
	Diamonds: number,
	AttributePoints: number,
	Attributes: {[string]: number},
	SkillCooldownRemaining: number,
	IsAlive: boolean,
	LeaderboardData: {LeaderboardRow},
	RespawnCountThisMatch: number?,
	HasMatchBuff: boolean?,
}

local DEFAULT_UI_STATE: UIState = {
	Level = 1,
	Exp = 0,
	RequiredEXP = 100,
	Size = 1,
	CurrentHP = 100,
	MaxHP = 100,
	ChargeRatio = 0,
	Diamonds = 0,
	AttributePoints = 0,
	Attributes = {},
	SkillCooldownRemaining = 0,
	IsAlive = true,
	LeaderboardData = {},
	RespawnCountThisMatch = 0,
	HasMatchBuff = false,
}

local UIController = {}
UIController.__index = UIController

local function findRemote(remotes: Folder, preferredName: string, fallbackName: string): RemoteEvent
	return (remotes:FindFirstChild(preferredName) or remotes:FindFirstChild(fallbackName)) :: RemoteEvent
end

function UIController.new(screenGui: ScreenGui)
	local remotes = (ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("SlingArenaRemotes")) :: Folder

	local self = setmetatable({
		ScreenGui = screenGui,
		Remotes = {
			UIStateUpdate = findRemote(remotes, "UIStateUpdate", "StateUpdate"),
			AttributeUpgrade = findRemote(remotes, "AttributeUpgrade", "SpendAttribute"),
			ActivateSkill = findRemote(remotes, "ActivateSkill", "ToggleSpecialUpgrade"),
			RequestRespawn = findRemote(remotes, "RequestRespawn", "PurchaseRespawn"),
			RequestMatchBuff = findRemote(remotes, "RequestMatchBuff", "PurchaseMatchBuff"),
		},
		State = table.clone(DEFAULT_UI_STATE),
		Connections = {},
	}, UIController)

	self.HUD = HUD.new(screenGui, {
		OnOpenBuffPanel = function()
			self.BuffPanel:Toggle()
		end,
		OnActivateSkill = function()
			self:RequestSkillActivation()
		end,
	})
	self.AttributePanel = AttributePanel.new(screenGui, function(attributeName: string)
		self.Remotes.AttributeUpgrade:FireServer(attributeName)
	end)
	self.RespawnPanel = RespawnPanel.new(screenGui, function(respawnType: string)
		self.Remotes.RequestRespawn:FireServer(respawnType)
	end)
	self.BuffPanel = BuffPanel.new(screenGui, function()
		self.Remotes.RequestMatchBuff:FireServer()
	end)
	self.Leaderboard = LeaderboardUI.new(screenGui)

	return self
end

function UIController:RequestSkillActivation()
	if self.State.SkillCooldownRemaining <= 0 and self.State.IsAlive then
		self.Remotes.ActivateSkill:FireServer()
	end
end

function UIController:ApplyState(payload: UIState)
	self.State = payload
	self.HUD:Update(payload)
	self.AttributePanel:Update({
		AttributePoints = payload.AttributePoints,
		Attributes = payload.Attributes,
	})
	self.RespawnPanel:UpdateCost(20 * ((payload.RespawnCountThisMatch or 0) + 1))
	self.RespawnPanel:SetVisible(not payload.IsAlive)
	self.BuffPanel:Update({
		Diamonds = payload.Diamonds,
		HasMatchBuff = payload.HasMatchBuff or false,
	})
	self.Leaderboard:Update(payload.LeaderboardData)
end

function UIController:Start()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	self:ApplyState(self.State)

	table.insert(self.Connections, self.Remotes.UIStateUpdate.OnClientEvent:Connect(function(payload: UIState)
		self:ApplyState(payload)
	end))

	table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.P then
			self.AttributePanel:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Tab then
			self.Leaderboard:Toggle()
		elseif input.KeyCode == Enum.KeyCode.E then
			self:RequestSkillActivation()
		end
	end))
end

function UIController:Destroy()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	self.HUD:Destroy()
	self.AttributePanel:Destroy()
	self.RespawnPanel:Destroy()
	self.BuffPanel:Destroy()
	self.Leaderboard:Destroy()
end

return UIController
