--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local LobbyClientService = require(ReplicatedStorage.Client.Services.LobbyClientService)
local UIController = require(ReplicatedStorage.Client.Controllers.UIController)
local LeaderboardWorldUIController = require(ReplicatedStorage.Client.Controllers.LeaderboardWorldUIController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

PathResolver.reportMissing(game, PathResolver.collectPaths(ProjectTreeSpec.Services.Client))
PathResolver.reportMissing(ReplicatedStorage, PathResolver.collectPaths(ProjectTreeSpec.Remotes))

local clientService = LobbyClientService.new()
local controller: any = nil
local leaderboardWorldController: any = nil
local rebuildScheduled = false
local watchedGuiNames = {
	["MainHUD"] = true,
	["UnitTestUI"] = true,
	["MatchUI"] = true,
	["MatchScoreboardUI"] = true,
	["InventoryUI"] = true,
	["OnlineRewardUI"] = true,
	["SpinUI"] = true,
	["DailyLoginUI"] = true,
	["ShopUI"] = true,
	["LauncherUI"] = true,
}

local function buildController()
	if controller then
		controller:Destroy()
	end

	PathResolver.reportMissing(playerGui, PathResolver.collectPaths(ProjectTreeSpec.UI))
	controller = UIController.new(playerGui, {
		ClientService = clientService,
	})
	controller:Start()

	if leaderboardWorldController == nil then
		leaderboardWorldController = LeaderboardWorldUIController.new(clientService)
		leaderboardWorldController:Start()
	end
end

local function scheduleRebuild()
	if rebuildScheduled then
		return
	end
	rebuildScheduled = true
	task.defer(function()
		rebuildScheduled = false
		buildController()
	end)
end

buildController()

playerGui.ChildAdded:Connect(function(child)
	if child:IsA("ScreenGui") and watchedGuiNames[child.Name] then
		scheduleRebuild()
	end
end)

playerGui.ChildRemoved:Connect(function(child)
	if child:IsA("ScreenGui") and watchedGuiNames[child.Name] then
		scheduleRebuild()
	end
end)

local function isLocalLauncherPawn(child: Instance): boolean
	return child.Name == player.Name or child.Name == (player.Name .. "_Pawn")
end

workspace:WaitForChild("LauncherPawns").ChildAdded:Connect(function(child)
	if not isLocalLauncherPawn(child) then
		return
	end
	task.wait()
	scheduleRebuild()
end)

workspace:WaitForChild("LauncherPawns").ChildRemoved:Connect(function(child)
	if isLocalLauncherPawn(child) then
		scheduleRebuild()
	end
end)

player.CharacterAdded:Connect(function()
	scheduleRebuild()
end)

player.CharacterRemoving:Connect(function()
	scheduleRebuild()
end)

player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(scheduleRebuild)

RunService.Heartbeat:Connect(function()
	if controller == nil then
		scheduleRebuild()
	end
end)

player.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		if controller then
			controller:Destroy()
			controller = nil
		end
		if leaderboardWorldController then
			leaderboardWorldController:Destroy()
			leaderboardWorldController = nil
		end
	end
end)
