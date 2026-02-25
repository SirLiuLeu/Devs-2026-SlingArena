--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillService = {}
SkillService.__index = SkillService

type Context = {
	Services: any,
	Remotes: Folder,
	EventBus: any,
}

function SkillService.new(context: Context)
	local self = setmetatable({}, SkillService)
	self._context = context
	self._specialUpgradePlayers = {} :: { [Player]: boolean }
	return self
end

function SkillService:Init()
	local spendAttribute = self._context.Remotes:FindFirstChild("SpendAttribute") :: RemoteEvent
	spendAttribute.OnServerEvent:Connect(function(player, attributeName: string)
		if type(attributeName) ~= "string" then
			return
		end
		self._context.Services.PlayerStateService:TrySpendAttribute(player, attributeName)
	end)

	local toggleSpecial = self._context.Remotes:FindFirstChild("ToggleSpecialUpgrade") :: RemoteEvent
	toggleSpecial.OnServerEvent:Connect(function(player, active: boolean)
		if type(active) ~= "boolean" then
			return
		end
		self._specialUpgradePlayers[player] = active
	end)

	self._context.EventBus:On("PlayerDied", function(player: Player)
		self._specialUpgradePlayers[player] = false
	end)
end

function SkillService:IsSpecialUpgradeActive(player: Player): boolean
	return self._specialUpgradePlayers[player] == true
end

return SkillService
