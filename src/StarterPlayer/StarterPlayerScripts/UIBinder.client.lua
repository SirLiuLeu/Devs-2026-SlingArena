--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local refreshScheduled = false

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

local function scheduleControllerRefresh()
	if refreshScheduled then
		return
	end

	refreshScheduled = true
	task.defer(function()
		refreshScheduled = false
		buildController()
	end)
end

buildController()

playerGui.ChildAdded:Connect(function()
	scheduleControllerRefresh()
end)

playerGui.DescendantAdded:Connect(function()
	scheduleControllerRefresh()
end)

playerGui.ChildRemoved:Connect(function()
	scheduleControllerRefresh()
end)

player.AncestryChanged:Connect(function(_, parent)
	if parent == nil and controller then
		controller:Destroy()
		controller = nil
	end
end)
