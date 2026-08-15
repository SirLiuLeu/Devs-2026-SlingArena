--!strict

local PathResolver = require(script.Parent.PathResolver)
local ProjectTreeSpec = require(script.Parent.Parent.ProjectTreeSpec)

local WaitForUI = {}
export type ResolveOptions = { wait: boolean?, timeout: number?, onResolved: ((ScreenGui) -> ())? }

function WaitForUI.ResolveLauncherUI(player: Player, _options: ResolveOptions?): ScreenGui?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return nil end
	local resolved = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.LauncherTouch.ScreenGui, { shouldWarn = false })
	if resolved and resolved:IsA("ScreenGui") then return resolved end
	return nil
end

function WaitForUI.ResolveLauncherUIWithRetry(player: Player, options: ResolveOptions?): ScreenGui?
	local resolved = WaitForUI.ResolveLauncherUI(player, options)
	if resolved and options and options.onResolved then options.onResolved(resolved) end
	return resolved
end
function WaitForUI.IsRetryPending(_player: Player): boolean return false end
function WaitForUI.ClearRetry(_player: Player) end
return WaitForUI
