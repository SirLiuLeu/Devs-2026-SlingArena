--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)

local RewardRoller = {}

local function randomFrom(list)
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

function RewardRoller.RollRandomLauncherId(): string?
	return randomFrom(LauncherConfig.GetAllIds())
end

function RewardRoller.RollRandomItemId(): string?
	return randomFrom(ItemConfig.GetAllIds())
end

return RewardRoller
