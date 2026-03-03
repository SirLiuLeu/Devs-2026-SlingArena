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
PathResolver.reportMissing(playerGui, PathResolver.collectPaths(ProjectTreeSpec.UI))

local clientService = LobbyClientService.new()
local controller = UIController.new(playerGui, {
	ClientService = clientService,
})
controller:Start()

player.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		controller:Destroy()
	end
end)
