--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)

local SFXController = {}
SFXController.__index = SFXController

function SFXController.new(player: Player, playerGui: PlayerGui)
	local self = setmetatable({}, SFXController)
	self._player = player
	self._playerGui = playerGui
	self._connections = {}
	self._buttonConnections = {}
	self._lastRoundStartId = nil
	self._lastVictoryRoundId = nil
	self._lastKnownHP = nil
	return self
end

function SFXController:_bindButton(instance: Instance)
	if not instance:IsA("GuiButton") or self._buttonConnections[instance] then return end
	self._buttonConnections[instance] = instance.Activated:Connect(function()
		SoundManager.Play("SFX_UI_Click")
	end)
end

function SFXController:_unbindButton(instance: Instance)
	local connection = self._buttonConnections[instance]
	if connection then
		connection:Disconnect()
		self._buttonConnections[instance] = nil
	end
end

function SFXController:_handleFeedback(message: any)
	if type(message) ~= "table" or type(message.EventType) ~= "string" then return end
	local eventType = message.EventType
	local payload = if type(message.Payload) == "table" then message.Payload else {}

	if eventType == "Death" then
		SoundManager.Play("SFX_Death")
	elseif eventType == "PlayerKill" then
		SoundManager.Play("SFX_Kill")
	elseif eventType == "LevelUp" then
		SoundManager.Play("SFX_LevelUp")
	elseif eventType == "RoundStart" then
		local roundId = payload.RoundId
		if roundId == nil or roundId ~= self._lastRoundStartId then
			self._lastRoundStartId = roundId
			SoundManager.Play("SFX_RoundStart")
		end
	elseif eventType == "TeamChangeResult"
		or eventType == "LauncherEquipResult"
		or eventType == "LauncherSellResult"
		or eventType == "ShopPurchaseResult" then
		if payload.Success == true then SoundManager.Play("SFX_Success") end
	elseif eventType == "PetEquipResult" then
		local status = tostring(payload.Status or "")
		if status == "EquippedActive" or status == "EquippedVisualPending" then SoundManager.Play("SFX_Success") end
	elseif eventType == "PetUpgradeResult" then
		if payload.Status == "Upgraded" then SoundManager.Play("SFX_LevelUp") end
	elseif eventType == "ItemUseResult" or eventType == "HpPotionUseResult" then
		if payload.Result == "Consumed" then SoundManager.Play("SFX_Success") end
	elseif string.match(eventType, "Result$") and payload.Success == true then
		SoundManager.Play("SFX_Success")
	end
end

function SFXController:Start()
	for _, descendant in ipairs(self._playerGui:GetDescendants()) do self:_bindButton(descendant) end
	table.insert(self._connections, self._playerGui.DescendantAdded:Connect(function(instance)
		self:_bindButton(instance)
	end))
	table.insert(self._connections, self._playerGui.DescendantRemoving:Connect(function(instance)
		self:_unbindButton(instance)
	end))

	local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	local stateUpdateRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.StateUpdate)
	if stateUpdateRemote and stateUpdateRemote:IsA("RemoteEvent") then
		table.insert(self._connections, stateUpdateRemote.OnClientEvent:Connect(function(state)
			if type(state) ~= "table" then return end
			local currentHP = tonumber(state.CurrentHP)
			if not currentHP then return end
			if self._lastKnownHP ~= nil and currentHP < self._lastKnownHP then
				SoundManager.Play("SFX_Hurt")
			end
			self._lastKnownHP = currentHP
		end))
	end

	local feedbackRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.GameplayFeedback)
	if feedbackRemote and feedbackRemote:IsA("RemoteEvent") then
		table.insert(self._connections, feedbackRemote.OnClientEvent:Connect(function(message)
			self:_handleFeedback(message)
		end))
	end
	local roundResultRemote = remotes and remotes:FindFirstChild(RemoteContracts.Names.RoundResult)
	if roundResultRemote and roundResultRemote:IsA("RemoteEvent") then
		table.insert(self._connections, roundResultRemote.OnClientEvent:Connect(function(result)
			if type(result) ~= "table" or result.Winner ~= self._player.Name then return end
			local roundId = result.RoundId
			if roundId ~= nil and roundId == self._lastVictoryRoundId then return end
			self._lastVictoryRoundId = roundId
			SoundManager.Play("SFX_Victory")
		end))
	end
end

function SFXController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
	for button in pairs(self._buttonConnections) do self:_unbindButton(button) end
end

return SFXController
