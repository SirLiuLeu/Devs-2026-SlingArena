--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local LobbyClientService = require(ReplicatedStorage.Client.Services.LobbyClientService)
local UIController = require(ReplicatedStorage.Client.Controllers.UIController)
local LeaderboardWorldUIController = require(ReplicatedStorage.Client.Controllers.LeaderboardWorldUIController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STARTUP_UI_WAIT_TIMEOUT_SECONDS = 3

local STARTER_GUI_ROOTS = {
	UnitTestUI = true,
	MainHUD = true,
	InventoryUI = true,
	OnlineRewardUI = true,
	ShopUI = true,
	DailyLoginUI = true,
	SpinUI = true,
	QuestUI = true,
	MatchUI = true,
	MatchSummaryUI = true,
	MatchScoreboardUI = true,
	LauncherUI = true,
}

local function getRootSegment(path: string): string
	return string.match(path, "^[^%.]+") or path
end

local function buildStartupUiPaths(): { string }
	local paths = PathResolver.collectPaths(ProjectTreeSpec.UI)
	local activeMode = player:GetAttribute("ActivePlayerMode")
	local isHuman = activeMode == nil or activeMode == GameStates.PlayerMode.Human or player:GetAttribute("State") == GameStates.PlayerMode.Human
	local filtered = {}
	for _, path in ipairs(paths) do
		local rootName = getRootSegment(path)
		if not STARTER_GUI_ROOTS[rootName] then
			continue
		end
		if isHuman and rootName == ProjectTreeSpec.UI.LauncherTouch.ScreenGui then
			continue
		end
		table.insert(filtered, path)
	end
	return filtered
end

PathResolver.reportMissing(game, PathResolver.collectPaths(ProjectTreeSpec.Services.Client))
PathResolver.reportMissing(ReplicatedStorage, PathResolver.collectPaths(ProjectTreeSpec.Remotes))
PathResolver.reportMissing(playerGui, buildStartupUiPaths(), { waitTimeout = STARTUP_UI_WAIT_TIMEOUT_SECONDS })

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
