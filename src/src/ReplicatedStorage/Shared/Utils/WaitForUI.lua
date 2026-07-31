--!strict

local Players = game:GetService("Players")

local PathResolver = require(script.Parent.PathResolver)
local LauncherUiConstants = require(script.Parent.Parent.Constants.LauncherUiConstants)
local ProjectTreeSpec = require(script.Parent.Parent.ProjectTreeSpec)

local WaitForUI = {}

export type ResolveOptions = {
	wait: boolean?,
	timeout: number?,
	onResolved: ((ScreenGui) -> ())?,
}

local pendingRetries: { [Player]: RBXScriptConnection } = {}

local function resolveContainer(playerGui: PlayerGui, shouldWait: boolean, timeout: number): Instance?
	if shouldWait then
		return PathResolver.waitForPath(playerGui, ProjectTreeSpec.UI.LauncherTouch.Container, timeout)
	end

	return PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.LauncherTouch.Container, {
		shouldWarn = false,
	})
end

local function resolveScreenGui(container: Instance?, shouldWait: boolean, timeout: number): ScreenGui?
	if not container then
		return nil
	end

	local screenGuiPath = LauncherUiConstants.ScreenGuiName
	local screenGui = if shouldWait then PathResolver.waitForPath(container, screenGuiPath, timeout) else PathResolver.resolvePath(container, screenGuiPath, {
		shouldWarn = false,
	})
	if screenGui and screenGui:IsA("ScreenGui") then
		return screenGui
	end
	return nil
end

local function getPlayerGui(player: Player, shouldWait: boolean, timeout: number): PlayerGui?
	if shouldWait then
		local instance = player:WaitForChild("PlayerGui", timeout)
		if instance and instance:IsA("PlayerGui") then
			return instance
		end
		return nil
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui
	end
	return nil
end

function WaitForUI.ResolveLauncherUI(player: Player, options: ResolveOptions?): ScreenGui?
	local shouldWait = if options and options.wait ~= nil then options.wait else true
	local timeout = if options and options.timeout ~= nil then math.max(options.timeout, 0) else 5
	local playerGui = getPlayerGui(player, shouldWait, timeout)
	if not playerGui then
		return nil
	end

	local container = resolveContainer(playerGui, shouldWait, timeout)
	return resolveScreenGui(container, shouldWait, timeout)
end

function WaitForUI.ResolveLauncherUIWithRetry(player: Player, options: ResolveOptions?): ScreenGui?
	local resolved = WaitForUI.ResolveLauncherUI(player, options)
	if resolved then
		local existing = pendingRetries[player]
		if existing then
			existing:Disconnect()
			pendingRetries[player] = nil
		end
		if options and options.onResolved then
			options.onResolved(resolved)
		end
		return resolved
	end

	if options and options.wait == false and options.onResolved and not pendingRetries[player] then
		local connection: RBXScriptConnection? = nil
		local function tryResolve()
			local screenGui = WaitForUI.ResolveLauncherUI(player, {
				wait = false,
				timeout = if options and options.timeout ~= nil then options.timeout else nil,
			})
			if screenGui then
				if connection then
					connection:Disconnect()
				end
				pendingRetries[player] = nil
				options.onResolved(screenGui)
			end
		end

		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if playerGui then
			connection = playerGui.DescendantAdded:Connect(function()
				tryResolve()
			end)
			pendingRetries[player] = connection
		end
	end

	return nil
end

function WaitForUI.IsRetryPending(player: Player): boolean
	return pendingRetries[player] ~= nil
end

function WaitForUI.ClearRetry(player: Player)
	local connection = pendingRetries[player]
	if connection then
		connection:Disconnect()
		pendingRetries[player] = nil
	end
end

Players.PlayerRemoving:Connect(function(player)
	WaitForUI.ClearRetry(player)
end)

return WaitForUI
