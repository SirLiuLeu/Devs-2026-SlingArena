--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentConfig = require(ReplicatedStorage.Shared.Config.EquipmentConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local Component = {}
Component.__index = Component

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
local abilityTrigger = remotes:WaitForChild(RemoteContracts.Names.AbilityTrigger) :: RemoteEvent
local stateUpdate = remotes:WaitForChild(RemoteContracts.Names.StateUpdate) :: RemoteEvent

local function warnMissing(name: string)
	warn(string.format("[UI_MISSING] %s is missing. Create it manually in Studio. See ProjectTreeSpec.lua and UI guide comments.", name))
end

function Component.new(parent: Instance)
	-- [UI_CREATION_GUIDE]
	-- Create StarterGui.MainHUD.SkillButton as a GuiButton, or add an Activate/Click GuiButton beneath it.
	local root = parent:FindFirstChild(script.Name)
	if not root then warnMissing(script.Name) end
	local self = setmetatable({ Root = root, _connections = {}, _currentAbilityId = nil :: string? }, Component)
	if root then
		local button = if root:IsA("GuiButton") then root else root:FindFirstChild("Activate", true) or root:FindFirstChild("Click", true)
		if button and button:IsA("GuiButton") then
			table.insert(self._connections, button.Activated:Connect(function()
				if self._currentAbilityId then abilityTrigger:FireServer({ abilityId = self._currentAbilityId }) end
			end))
		else
			warnMissing("StarterGui.MainHUD.SkillButton.Activate (GuiButton)")
		end
	end
	table.insert(self._connections, player:GetAttributeChangedSignal("CurrentEquipmentAbilityId"):Connect(function()
		self._currentAbilityId = player:GetAttribute("CurrentEquipmentAbilityId")
	end))
	table.insert(self._connections, stateUpdate.OnClientEvent:Connect(function(state)
		self:Update(state)
	end))
	self._currentAbilityId = player:GetAttribute("CurrentEquipmentAbilityId")
	return self
end

function Component:SetEquipmentState(ownedEquipment: any, equippedEquipment: any)
	self._currentAbilityId = nil
	if type(ownedEquipment) ~= "table" or type(equippedEquipment) ~= "table" then return end
	for slot = 1, 3 do
		local instanceId = equippedEquipment[slot]
		local instance = instanceId and ownedEquipment[instanceId]
		local definition = type(instance) == "table" and EquipmentConfig.GetById(tostring(instance.definitionId or "")) or nil
		if definition and definition.abilityId then
			self._currentAbilityId = definition.abilityId
			player:SetAttribute("CurrentEquipmentAbilityId", self._currentAbilityId)
			return
		end
	end
	player:SetAttribute("CurrentEquipmentAbilityId", nil)
end

function Component:Update(state: any)
	if type(state) == "table" then self:SetEquipmentState(state.OwnedEquipment, state.EquippedEquipment) end
end

function Component:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
end

return Component
