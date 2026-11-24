--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	table.insert(self._connections, player:GetAttributeChangedSignal("CurrentPetAbilityId"):Connect(function()
		self._currentAbilityId = player:GetAttribute("CurrentPetAbilityId")
	end))
	table.insert(self._connections, stateUpdate.OnClientEvent:Connect(function(state)
		self:Update(state)
	end))
	self._currentAbilityId = player:GetAttribute("CurrentPetAbilityId")
	return self
end

function Component:SetPetState(_ownedPets: any, _equippedPets: any)
	-- Current Pet abilities are passive or automatic; none has a click-triggered skill.
	self._currentAbilityId = nil
	player:SetAttribute("CurrentPetAbilityId", nil)
end

function Component:Update(state: any)
	if type(state) == "table" then self:SetPetState(state.OwnedPets, state.EquippedPets) end
end

function Component:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
end

return Component
