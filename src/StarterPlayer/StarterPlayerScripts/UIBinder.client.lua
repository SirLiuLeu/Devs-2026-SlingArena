--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local LobbyClientService = require(ReplicatedStorage.Client.Services.LobbyClientService)
local UIController = require(ReplicatedStorage.Client.Controllers.UIController)
local LeaderboardWorldUIController = require(ReplicatedStorage.Client.Controllers.LeaderboardWorldUIController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STARTUP_UI_WAIT_TIMEOUT_SECONDS = 8

local STARTUP_UI_PATHS = {
	ProjectTreeSpec.UI.MainHub.ScreenGui,
	ProjectTreeSpec.UI.MainHub.Root,
	ProjectTreeSpec.UI.Match.ScreenGui,
	ProjectTreeSpec.UI.Match.Root,
	ProjectTreeSpec.UI.MatchScoreboard.ScreenGui,
	ProjectTreeSpec.UI.MatchScoreboard.Root,
	ProjectTreeSpec.UI.MatchSummary.ScreenGui,
	ProjectTreeSpec.UI.MatchSummary.Root,
}

PathResolver.reportMissing(game, PathResolver.collectPaths(ProjectTreeSpec.Services.Client))
PathResolver.reportMissing(ReplicatedStorage, PathResolver.collectPaths(ProjectTreeSpec.Remotes))
PathResolver.reportMissing(playerGui, STARTUP_UI_PATHS, { waitTimeout = STARTUP_UI_WAIT_TIMEOUT_SECONDS })

local clientService = LobbyClientService.new()
local controller = UIController.new(playerGui, {
	ClientService = clientService,
})
controller:Start()

local leaderboardWorldController = LeaderboardWorldUIController.new(clientService)
leaderboardWorldController:Start()

player.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		controller:Destroy()
		leaderboardWorldController:Destroy()
	end
end)
