--!strict

-- Replace each placeholder with its uploaded texture asset ID.
-- The same five textures are applied to every Launcher model.
local LauncherTextureConfig = {}

LauncherTextureConfig.Textures = {
	White = "rbxassetid://0",
	Yellow = "rbxassetid://0",
	Blue = "rbxassetid://0",
	Red = "rbxassetid://0",
	Rage = "rbxassetid://0",
}

function LauncherTextureConfig.GetKey(teamId: string?, rageActive: boolean): string?
	if rageActive then return "Rage" end
	if typeof(teamId) == "string" and LauncherTextureConfig.Textures[teamId] ~= nil then return teamId end
	return nil
end

return LauncherTextureConfig
