--!strict

-- Replace each placeholder with the uploaded texture asset ID.
-- These five texture IDs are shared by every Launcher model.
local LauncherTextureConfig: { [string]: any } = {
	White = "rbxassetid://0",
	Yellow = "rbxassetid://0",
	Blue = "rbxassetid://0",
	Red = "rbxassetid://0",
	Rage = "rbxassetid://0",
}

function LauncherTextureConfig.GetTextureId(teamId: string?, rageActive: boolean): string?
	if rageActive then return LauncherTextureConfig.Rage end
	if teamId == nil then return nil end
	return LauncherTextureConfig[teamId]
end

return LauncherTextureConfig
