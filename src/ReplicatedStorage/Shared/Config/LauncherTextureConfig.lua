--!strict

-- Replace each placeholder with the uploaded texture asset ID.
-- These five texture IDs are shared by every Launcher model.
local LauncherTextureConfig: { [string]: any } = {
	White = "rbxassetid://79301206944125",
	Yellow = "rbxassetid://86896388737286",
	Blue = "rbxassetid://124209684920568",
	Red = "rbxassetid://129948366892221",
	Rage = "rbxassetid://92390752724859",
	Green = "rbxassetid://100651321131616",
	Purple = "rbxassetid://97582647099987",
}

function LauncherTextureConfig.GetTextureId(teamId: string?, rageActive: boolean): string?
	if rageActive then return LauncherTextureConfig.Rage end
	if teamId == nil then return nil end
	return LauncherTextureConfig[teamId]
end

return LauncherTextureConfig
