--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local UIController = {}
UIController.__index = UIController

function UIController.new(screenGui: ScreenGui)
	local remotes = ReplicatedStorage:WaitForChild("SlingArenaRemotes") :: Folder
	local self = setmetatable({
		ScreenGui = screenGui,
		Connections = {},
		State = {
			Level = 1,
			Exp = 0,
			CurrentHP = 100,
			MaxHP = 100,
			MatchState = "Boot",
			ChargeValue = 0,
			IsCharging = false,
			Size = 1,
		},
		Remotes = {
			StateUpdate = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent,
			MatchStateUpdate = remotes:WaitForChild(RemoteContracts.Names.MatchStateUpdate) :: RemoteEvent,
			RoundResult = remotes:WaitForChild(RemoteContracts.Names.RoundResult) :: RemoteEvent,
			PopupMessage = remotes:WaitForChild(RemoteContracts.Names.PopupMessage) :: RemoteEvent,
		},
	}, UIController)

	self:_buildUI()
	return self
end

function UIController:_buildUI()
	local hud = Instance.new("Frame")
	hud.Name = "HUD"
	hud.Size = UDim2.fromScale(0.32, 0.18)
	hud.Position = UDim2.fromScale(0.02, 0.02)
	hud.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	hud.BackgroundTransparency = 0.2
	hud.Parent = self.ScreenGui
	self.HUD = hud

	local hpBack = Instance.new("Frame")
	hpBack.Size = UDim2.fromScale(1, 0.2)
	hpBack.Position = UDim2.fromScale(0, 0)
	hpBack.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
	hpBack.Parent = hud
	self.HPFill = Instance.new("Frame")
	self.HPFill.BackgroundColor3 = Color3.fromRGB(225, 70, 70)
	self.HPFill.Size = UDim2.fromScale(1, 1)
	self.HPFill.Parent = hpBack

	local expBack = Instance.new("Frame")
	expBack.Size = UDim2.fromScale(1, 0.2)
	expBack.Position = UDim2.fromScale(0, 0.28)
	expBack.BackgroundColor3 = Color3.fromRGB(58, 58, 58)
	expBack.Parent = hud
	self.EXPFill = Instance.new("Frame")
	self.EXPFill.BackgroundColor3 = Color3.fromRGB(70, 160, 255)
	self.EXPFill.Size = UDim2.fromScale(0, 1)
	self.EXPFill.Parent = expBack

	self.LevelText = Instance.new("TextLabel")
	self.LevelText.BackgroundTransparency = 1
	self.LevelText.Size = UDim2.fromScale(1, 0.2)
	self.LevelText.Position = UDim2.fromScale(0, 0.56)
	self.LevelText.Font = Enum.Font.GothamBold
	self.LevelText.TextColor3 = Color3.new(1, 1, 1)
	self.LevelText.TextScaled = true
	self.LevelText.Parent = hud

	self.MatchStateText = Instance.new("TextLabel")
	self.MatchStateText.BackgroundTransparency = 1
	self.MatchStateText.Size = UDim2.fromScale(1, 0.2)
	self.MatchStateText.Position = UDim2.fromScale(0, 0.78)
	self.MatchStateText.Font = Enum.Font.Gotham
	self.MatchStateText.TextColor3 = Color3.fromRGB(252, 232, 111)
	self.MatchStateText.TextScaled = true
	self.MatchStateText.Parent = hud

	self.ChargeText = Instance.new("TextLabel")
	self.ChargeText.BackgroundTransparency = 1
	self.ChargeText.Size = UDim2.fromScale(1, 0.2)
	self.ChargeText.Position = UDim2.fromScale(0, 0.98)
	self.ChargeText.Font = Enum.Font.Gotham
	self.ChargeText.TextColor3 = Color3.fromRGB(155, 235, 255)
	self.ChargeText.TextScaled = true
	self.ChargeText.Parent = hud

	self.Popup = Instance.new("TextLabel")
	self.Popup.Visible = false
	self.Popup.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Popup.Position = UDim2.fromScale(0.5, 0.35)
	self.Popup.Size = UDim2.fromScale(0.35, 0.1)
	self.Popup.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	self.Popup.BackgroundTransparency = 0.3
	self.Popup.Font = Enum.Font.GothamBlack
	self.Popup.TextScaled = true
	self.Popup.TextColor3 = Color3.new(1, 1, 1)
	self.Popup.Parent = self.ScreenGui

	self.Winner = Instance.new("TextLabel")
	self.Winner.Visible = false
	self.Winner.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Winner.Position = UDim2.fromScale(0.5, 0.5)
	self.Winner.Size = UDim2.fromScale(0.5, 0.16)
	self.Winner.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
	self.Winner.BackgroundTransparency = 0.25
	self.Winner.Font = Enum.Font.GothamBlack
	self.Winner.TextScaled = true
	self.Winner.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.Winner.Parent = self.ScreenGui
end

function UIController:_renderState()
	local hpRatio = 0
	if self.State.MaxHP > 0 then
		hpRatio = math.clamp(self.State.CurrentHP / self.State.MaxHP, 0, 1)
	end
	self.HPFill.Size = UDim2.fromScale(hpRatio, 1)

	local requiredExp = LevelConfig.RequiredExp(self.State.Level)
	local expRatio = 0
	if requiredExp > 0 then
		expRatio = math.clamp(self.State.Exp / requiredExp, 0, 1)
	end
	self.EXPFill.Size = UDim2.fromScale(expRatio, 1)

	self.LevelText.Text = `Level: {self.State.Level}`
	self.MatchStateText.Text = `Match: {self.State.MatchState}`
	local chargePct = math.floor(math.clamp(self.State.ChargeValue, 0, 1) * 100)
	self.ChargeText.Text = `Charge: {chargePct}% | Size: {string.format("%.2f", self.State.Size)}`
end

function UIController:_showPopup(message: string, duration: number)
	self.Popup.Text = message
	self.Popup.Visible = true
	task.delay(duration, function()
		if self.Popup then
			self.Popup.Visible = false
		end
	end)
end

function UIController:Start()
	self:_renderState()
	table.insert(self.Connections, self.Remotes.StateUpdate.OnClientEvent:Connect(function(state)
		self.State.Level = state.Level or self.State.Level
		self.State.Exp = state.Exp or self.State.Exp
		self.State.CurrentHP = state.CurrentHP or self.State.CurrentHP
		self.State.MaxHP = state.MaxHP or self.State.MaxHP
		self.State.ChargeValue = state.ChargeValue or self.State.ChargeValue
		self.State.IsCharging = state.IsCharging or false
		self.State.Size = state.Size or self.State.Size
		self:_renderState()
	end))

	table.insert(self.Connections, self.Remotes.MatchStateUpdate.OnClientEvent:Connect(function(payload)
		self.State.MatchState = payload.State or self.State.MatchState
		if payload.State ~= "RoundEnd" then
			self.Winner.Visible = false
		end
		self:_renderState()
	end))

	table.insert(self.Connections, self.Remotes.PopupMessage.OnClientEvent:Connect(function(payload)
		self:_showPopup(payload.Text or "", 1.2)
	end))

	table.insert(self.Connections, self.Remotes.RoundResult.OnClientEvent:Connect(function(payload)
		self.Winner.Text = `Winner: {payload.Winner}`
		self.Winner.Visible = true
	end))
end

function UIController:Destroy()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	self.Connections = {}
	if self.ScreenGui then
		self.ScreenGui:Destroy()
	end
end

return UIController
