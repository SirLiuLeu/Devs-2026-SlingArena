--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

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
	local consumeHpPotion = self._context.Remotes:FindFirstChild(RemoteContracts.Names.ConsumeHpPotion) :: RemoteEvent?
	if consumeHpPotion then
		consumeHpPotion.OnServerEvent:Connect(function(player: Player)
			self._context.Services.PlayerStateService:TryConsumeHpPotion(player)
		end)
	end

end

function SkillService:IsSpecialUpgradeActive(player: Player): boolean
	return false
end

return SkillService
