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
local ClientPetController = require(ReplicatedStorage.Client.Controllers.ClientPetController)
local TeamSelectionUIController = require(ReplicatedStorage.Client.Controllers.TeamSelectionUIController)
local SFXController = require(ReplicatedStorage.Client.Controllers.SFXController)

local PLAYER_GUI_TIMEOUT_SECONDS = 8
local ROOT_SCREEN_GUI_TIMEOUT_SECONDS = 8

local STARTER_GUI_ROOTS = {
	UnitTestUI = true,
	MainHUD = true,
	InventoryUI = true,
	LauncherInventoryUI = true,
	OnlineRewardUI = true,
	ShopUI = true,
	DailyLoginUI = true,
	MatchUI = true,
	MatchSummaryUI = true,
	MatchScoreboardUI = true,
	LauncherControlUI = true,
	TeamSelectionGui = true,
}

local function getRootSegment(path: string): string
	return string.match(path, "^[^%.]+") or path
end

local DAILY_QUEST_ROOT_PATH = "MainHUD.Root.QuestDaily"
local DAILY_QUEST_FALLBACK_NAMES: { [string]: boolean } = {
	ProgressLabel = true,
	TaskDescriptionLabel = true,
	ToggleDropdown = true,
	OpenIcon = true,
	ClosedIcon = true,
	NotificationIcon = true,
}

local function getRelativePath(root: Instance, descendant: Instance): string?
	local segments = {}
	local current: Instance? = descendant
	while current and current ~= root do
		table.insert(segments, current.Name)
		current = current.Parent
	end
	if current ~= root then
		return nil
	end

	for left = 1, math.floor(#segments / 2) do
		local right = #segments - left + 1
		segments[left], segments[right] = segments[right], segments[left]
	end
	return table.concat(segments, ".")
end

local function isDailyQuestFallbackPath(expectedPath: string): boolean
	local prefix = DAILY_QUEST_ROOT_PATH .. "."
	if string.sub(expectedPath, 1, #prefix) ~= prefix then
		return false
	end
	local targetName = string.match(expectedPath, "([^.]+)$")
	return targetName ~= nil and DAILY_QUEST_FALLBACK_NAMES[targetName] == true
end

local function resolveDailyQuestFallbackPath(playerGui: PlayerGui, expectedPath: string): string?
	local prefix = DAILY_QUEST_ROOT_PATH .. "."
	if string.sub(expectedPath, 1, #prefix) ~= prefix then
		return nil
	end

	local targetName = string.match(expectedPath, "([^.]+)$")
	if not targetName or not DAILY_QUEST_FALLBACK_NAMES[targetName] then
		return nil
	end

	local questRoot = PathResolver.resolvePath(playerGui, DAILY_QUEST_ROOT_PATH, { shouldWarn = false })
	if not questRoot then
		return nil
	end

	local match: Instance? = nil
	for _, descendant in ipairs(questRoot:GetDescendants()) do
		if descendant.Name == targetName then
			if match then
				-- A duplicate name is ambiguous; keep the canonical path unresolved.
				return nil
			end
			match = descendant
		end
	end

	return if match then getRelativePath(playerGui, match) else nil
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
	local sfxController = SFXController.new(player, playerGui)
	sfxController:Start()
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
		local bindingPath = path
		local isDynamicDailyQuestPath = isDailyQuestFallbackPath(path)
		if resolved == nil and resolvedRoot then
			bindingPath = resolveDailyQuestFallbackPath(playerGui, path) or path
		end
		if resolved == nil and bindingPath == path and not isDynamicDailyQuestPath then
			warn(string.format("[UIBinder] UI path '%s' was unavailable after bounded resolution; binding will remain retryable.", path))
		end

		uiBindManager:Bind(tostring(pathKey), bindingPath, function(_resolved)
			-- UiBindManager continues to refresh the exact path discovered at startup.
		end)
	end

	uiBindManager:Start()
	local controller = UIController.new(playerGui, {
		ClientService = clientService,
	})
	controller:Start()

	local leaderboardWorldController = LeaderboardWorldUIController.new(clientService)
	leaderboardWorldController:Start()
	local clientPetController = ClientPetController.new(player)
	clientPetController:Start()
	local teamSelectionController = TeamSelectionUIController.new(playerGui)
	teamSelectionController:SetConfirmationController(controller.ConfirmationUIController)
	teamSelectionController:SetToastController(controller.ToastUIController)
	teamSelectionController:Start()

	player.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			sfxController:Destroy()
			controller:Destroy()
			uiBindManager:Destroy()
			leaderboardWorldController:Destroy()
			clientPetController:Destroy()
			teamSelectionController:Destroy()
		end
	end)
end)
