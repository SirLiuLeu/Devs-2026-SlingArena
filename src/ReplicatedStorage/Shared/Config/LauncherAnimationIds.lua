--!strict

-- Fill each Launcher rig's animation asset IDs in Studio.
-- Values may be either "rbxassetid://123" or "123".
-- Keep an empty string until the matching rig animation has been uploaded.

local LauncherAnimationIds: { [string]: { [string]: string } } = {
	Normalduck = {
		Idle = "",
		Move = "",
		Launch = "",
		Knockback = "",
	},
	Kingduck = {
		Idle = "",
		Move = "",
		Launch = "",
		Knockback = "",
	},
	Witchduck = {
		Idle = "",
		Move = "",
		Launch = "",
		Knockback = "",
	},
	Drakeduck = {
		Idle = "",
		Move = "",
		Launch = "",
		Knockback = "",
	},
	Shielduck = {
		Idle = "",
		Move = "",
		Launch = "",
		Knockback = "",
	},
}

return LauncherAnimationIds
