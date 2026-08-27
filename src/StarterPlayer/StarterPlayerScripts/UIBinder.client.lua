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
local UIReadiness = require(ReplicatedStorage.Shared.Utils.UIReadiness)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui


print("[ROUND_END_TRACE][UIBinder] script start; waiting for PlayerGui complete")

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
	print("[ROUND_END_TRACE][UIBinder] buildStartupUiPaths start")
	local paths = PathResolver.collectPaths(ProjectTreeSpec.UI)
	local activeMode = player:GetAttribute("ActivePlayerMode")
	local isHuman = activeMode == nil or activeMode == GameStates.PlayerMode.Human or player:GetAttribute("State") == GameStates.PlayerMode.Human
	local filtered = {}
	print(string.format("[ROUND_END_TRACE][UIBinder] buildStartupUiPaths collected %d paths; ActivePlayerMode=%s State=%s isHuman=%s", #paths, tostring(activeMode), tostring(player:GetAttribute("State")), tostring(isHuman)))
	for index, path in ipairs(paths) do
		if index == 1 or index % 25 == 0 or string.find(path, "EndRound", 1, true) then
			print(string.format("[ROUND_END_TRACE][UIBinder] filtering path %d/%d: %s", index, #paths, path))
		end
		local rootName = getRootSegment(path)
		if not STARTER_GUI_ROOTS[rootName] then
			continue
		end
		if isHuman and rootName == ProjectTreeSpec.UI.LauncherTouch.ScreenGui then
			continue
		end
		table.insert(filtered, path)
	end
	print(string.format("[ROUND_END_TRACE][UIBinder] buildStartupUiPaths finished with %d allowed startup paths", #filtered))
	return filtered
end

print("[ROUND_END_TRACE][UIBinder] before client service PathResolver.reportMissing")
PathResolver.reportMissing(game, PathResolver.collectPaths(ProjectTreeSpec.Services.Client))
print("[ROUND_END_TRACE][UIBinder] before remotes PathResolver.reportMissing")
PathResolver.reportMissing(ReplicatedStorage, PathResolver.collectPaths(ProjectTreeSpec.Remotes))
local startupUiPaths = buildStartupUiPaths()
-- UIReadiness is the UI builder boundary. Controllers only resolve paths after
-- this event, rather than racing StarterGui replication with a fixed timeout.
local uiReadySignal = UIReadiness.create(playerGui, startupUiPaths)
print("[ROUND_END_TRACE][UIBinder] waiting for UI_Ready")
uiReadySignal.Event:Wait()
print("[ROUND_END_TRACE][UIBinder] UI_Ready received; validating startup UI")
PathResolver.reportMissing(playerGui, startupUiPaths)

print("[ROUND_END_TRACE][UIBinder] constructing LobbyClientService")
local clientService = LobbyClientService.new()
local controller = UIController.new(playerGui, {
	ClientService = clientService,
	UIReadySignal = uiReadySignal,
})
print("[ROUND_END_TRACE][UIBinder] before UIController:Start")
controller:Start()
print("[ROUND_END_TRACE][UIBinder] after UIController:Start")

local leaderboardWorldController = LeaderboardWorldUIController.new(clientService)
print("[ROUND_END_TRACE][UIBinder] before LeaderboardWorldUIController:Start")
leaderboardWorldController:Start()
print("[ROUND_END_TRACE][UIBinder] after LeaderboardWorldUIController:Start")

local uiBindManager = UiBindManager.new(playerGui)
print(string.format("[ROUND_END_TRACE][UIBinder] binding %d startup UI paths into UiBindManager", #startupUiPaths))
for pathKey, path in ipairs(startupUiPaths) do
	if pathKey == 1 or pathKey % 25 == 0 or string.find(path, "EndRound", 1, true) then
		print(string.format("[ROUND_END_TRACE][UIBinder] UiBindManager:Bind path %d/%d: %s", pathKey, #startupUiPaths, path))
	end
	uiBindManager:Bind(tostring(pathKey), path, function(resolved)
		if string.find(path, "EndRound", 1, true) then
			print(string.format("[ROUND_END_TRACE][UIBinder] UiBindManager callback for EndRound path; resolved=%s", resolved and resolved:GetFullName() or "nil"))
		end
	end)
end
print("[ROUND_END_TRACE][UIBinder] before UiBindManager:Start")
uiBindManager:Start()
print("[ROUND_END_TRACE][UIBinder] after UiBindManager:Start")

player.AncestryChanged:Connect(function(_, parent)
	if parent == nil then
		controller:Destroy()
		uiBindManager:Destroy()
		leaderboardWorldController:Destroy()
	end
end)
