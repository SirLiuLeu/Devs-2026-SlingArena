--!strict

local PathResolver = require(script.Parent.PathResolver)

local UIReadiness = {}

-- Creates a one-shot readiness signal owned by the client UI builder. The signal
-- fires only after every declared startup path exists; no wall-clock timeout is
-- used, so slow StarterGui replication cannot race path resolution.
function UIReadiness.create(playerGui: PlayerGui, paths: { string }): BindableEvent
	local signal = Instance.new("BindableEvent")
	signal.Name = "UI_Ready"
	signal.Parent = playerGui

	task.spawn(function()
		for _, path in ipairs(paths) do
			PathResolver.waitForPath(playerGui, path, math.huge)
		end
		signal:SetAttribute("IsReady", true)
		signal:Fire()
	end)

	return signal
end

return UIReadiness
