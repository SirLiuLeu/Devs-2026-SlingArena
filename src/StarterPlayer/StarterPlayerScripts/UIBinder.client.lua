--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local LobbyClientService = require(ReplicatedStorage.Client.Services.LobbyClientService)
local UiBindManager = require(ReplicatedStorage.Shared.Utils.UiBindManager)
local UIController = require(ReplicatedStorage.Client.Controllers.UIController)
local LeaderboardWorldUIController = require(ReplicatedStorage.Client.Controllers.LeaderboardWorldUIController)

local PLAYER_GUI_TIMEOUT_SECONDS = 8
local ROOT_SCREEN_GUI_TIMEOUT_SECONDS = 8

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

local function buildStartupUiPaths(player: Player): { string }
	local paths = PathResolver.collectPaths(ProjectTreeSpec.UI)
	local activeMode = player:GetAttribute("ActivePlayerMode")
	local isHuman = activeMode == nil
		or activeMode == GameStates.PlayerMode.Human
		or player:GetAttribute("State") == GameStates.PlayerMode.Human
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

task.spawn(function()
	local player = Players.LocalPlayer
	local playerGuiInstance = player:WaitForChild("PlayerGui", PLAYER_GUI_TIMEOUT_SECONDS)
	if playerGuiInstance == nil or not playerGuiInstance:IsA("PlayerGui") then
		warn("[UIBinder] PlayerGui was not available before the startup timeout; UI bindings were not started.")
		return
	end

	local playerGui = playerGuiInstance
	PathResolver.reportMissing(game, PathResolver.collectPaths(ProjectTreeSpec.Services.Client))
	PathResolver.reportMissing(ReplicatedStorage, PathResolver.collectPaths(ProjectTreeSpec.Remotes))

	local startupUiPaths = buildStartupUiPaths(player)
	local clientService = LobbyClientService.new()
	local uiBindManager = UiBindManager.new(playerGui)
	local resolvedRoots: { [string]: ScreenGui? } = {}
	local attemptedRoots: { [string]: boolean } = {}

	for pathKey, path in ipairs(startupUiPaths) do
		local rootName = getRootSegment(path)
		if not attemptedRoots[rootName] then
			attemptedRoots[rootName] = true
			resolvedRoots[rootName] = PathResolver.resolveRootScreenGui(playerGui, path, ROOT_SCREEN_GUI_TIMEOUT_SECONDS)
		end

		local resolvedRoot = resolvedRoots[rootName]
		local resolved = if resolvedRoot then PathResolver.resolvePath(playerGui, path, { shouldWarn = false }) else nil
		if resolved == nil then
			warn(string.format("[UIBinder] UI path '%s' was unavailable after bounded resolution; binding will remain retryable.", path))
		end

		uiBindManager:Bind(tostring(pathKey), path, function(_resolved)
			-- UiBindManager continues to refresh this binding if the UI appears later.
		end)
	end

	uiBindManager:Start()
	local controller = UIController.new(playerGui, {
		ClientService = clientService,
	})
	controller:Start()

	local leaderboardWorldController = LeaderboardWorldUIController.new(clientService)
	leaderboardWorldController:Start()

	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			controller:Destroy()
			uiBindManager:Destroy()
			leaderboardWorldController:Destroy()
		end
	end)
end)
