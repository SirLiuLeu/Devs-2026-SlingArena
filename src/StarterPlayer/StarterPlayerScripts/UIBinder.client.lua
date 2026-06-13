--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local LobbyClientService = require(ReplicatedStorage.Client.Services.LobbyClientService)
local UIController = require(ReplicatedStorage.Client.Controllers.UIController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

PathResolver.reportMissing(game, PathResolver.collectPaths(ProjectTreeSpec.Services.Client))
PathResolver.reportMissing(ReplicatedStorage, PathResolver.collectPaths(ProjectTreeSpec.Remotes))

local clientService = LobbyClientService.new()
local controller: any = nil
local rebuildScheduled = false
local watchedGuiNames = {
	["MainHUD"] = true,
	["UnitTestUI"] = true,
	["MatchUI"] = true,
	["InventoryUI"] = true,
	["OnlineRewardUI"] = true,
	["SpinUI"] = true,
	["DailyLoginUI"] = true,
	["ShopUI"] = true
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

workspace:WaitForChild("SlingPawns").ChildAdded:Connect(function(child)
	if child.Name ~= player.Name then
		return
	end
	task.wait()
	scheduleRebuild()
end)

RunService.Heartbeat:Connect(function()
	if controller == nil then
		scheduleRebuild()
	end
end)

player.AncestryChanged:Connect(function(_, parent)
	if parent == nil and controller then
		controller:Destroy()
		controller = nil
	end
end)
