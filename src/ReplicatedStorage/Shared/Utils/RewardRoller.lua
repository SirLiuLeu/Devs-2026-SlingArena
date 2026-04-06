--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlingConfig = require(ReplicatedStorage.Shared.Config.SlingConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)

local RewardRoller = {}

local function randomFrom(list)
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

function RewardRoller.RollRandomSlingId(): string?
	return randomFrom(SlingConfig.GetAllIds())
end

function RewardRoller.RollRandomItemId(): string?
	return randomFrom(ItemConfig.GetAllIds())
end

return RewardRoller
