--!strict

local NotificationConfigData = {}

NotificationConfigData.Priority = {
	Low = 10,
	Normal = 50,
	High = 80,
	Critical = 100,
}

export type NotificationType = "DiamondReward" | "PlayerKill" | "RoundState" | "ArenaJoinCooldown" | "FoodConsumed" | "RoundEndReward" | "StartRoundCountdown" | "Generic"

export type NotificationStyle = {
	BackgroundColor: Color3,
	AccentColor: Color3,
	TextColor: Color3,
	Icon: string,
}

export type NotificationConfig = {
	Type: NotificationType,
	I18nKey: string,
	FallbackText: string,
	Priority: number,
	DisplaySeconds: number?,
	FadeOutSeconds: number?,
	ReplaceKey: string?,
	Style: NotificationStyle,
}

NotificationConfigData.Types = {
	DiamondReward = {
		Type = "DiamondReward",
		I18nKey = "notification.reward.diamonds",
		FallbackText = "+{amount} Diamonds received!",
		Priority = NotificationConfigData.Priority.High,
		DisplaySeconds = 3,
		Style = {
			BackgroundColor = Color3.fromRGB(20, 32, 48),
			AccentColor = Color3.fromRGB(80, 210, 255),
			TextColor = Color3.fromRGB(245, 252, 255),
			Icon = "rbxassetid://0",
		},
	},
	PlayerKill = {
		Type = "PlayerKill",
		I18nKey = "notification.combat.kill",
		FallbackText = "You eliminated {victimName}!",
		Priority = NotificationConfigData.Priority.Critical,
		DisplaySeconds = 3.25,
		Style = {
			BackgroundColor = Color3.fromRGB(54, 20, 24),
			AccentColor = Color3.fromRGB(255, 86, 86),
			TextColor = Color3.fromRGB(255, 245, 245),
			Icon = "rbxassetid://0",
		},
	},
	RoundState = {
		Type = "RoundState",
		I18nKey = "notification.round.state_changed",
		FallbackText = "Round state: {state}",
		Priority = NotificationConfigData.Priority.Normal,
		DisplaySeconds = 2.75,
		Style = {
			BackgroundColor = Color3.fromRGB(30, 28, 52),
			AccentColor = Color3.fromRGB(160, 125, 255),
			TextColor = Color3.fromRGB(248, 246, 255),
			Icon = "rbxassetid://0",
		},
	},
	ArenaJoinCooldown = {
		Type = "ArenaJoinCooldown",
		I18nKey = "notification.arena.join_cooldown",
		FallbackText = "Arena join available in {seconds}s.",
		Priority = NotificationConfigData.Priority.High,
		DisplaySeconds = 2.5,
		Style = {
			BackgroundColor = Color3.fromRGB(52, 36, 16),
			AccentColor = Color3.fromRGB(255, 190, 90),
			TextColor = Color3.fromRGB(255, 250, 235),
			Icon = "rbxassetid://0",
		},
	},
	FoodConsumed = {
		Type = "FoodConsumed",
		I18nKey = "notification.food.consumed",
		FallbackText = "+{exp} EXP",
		Priority = NotificationConfigData.Priority.Low,
		DisplaySeconds = 2,
		Style = {
			BackgroundColor = Color3.fromRGB(18, 44, 30),
			AccentColor = Color3.fromRGB(90, 230, 130),
			TextColor = Color3.fromRGB(240, 255, 245),
			Icon = "rbxassetid://0",
		},
	},
	RoundEndReward = {
		Type = "RoundEndReward",
		I18nKey = "notification.round.reward",
		FallbackText = "Round đã kết thúc, bạn nhận được reward rank {rank}",
		Priority = NotificationConfigData.Priority.High,
		DisplaySeconds = 3,
		FadeOutSeconds = 2,
		Style = {
			BackgroundColor = Color3.fromRGB(32, 48, 28),
			AccentColor = Color3.fromRGB(145, 220, 105),
			TextColor = Color3.fromRGB(245, 255, 240),
			Icon = "rbxassetid://73584476161715",
		},
	},
	StartRoundCountdown = {
		Type = "StartRoundCountdown",
		I18nKey = "notification.round.countdown",
		FallbackText = "Start Round còn {seconds}s",
		Priority = NotificationConfigData.Priority.High,
		DisplaySeconds = 3,
		FadeOutSeconds = 2,
		ReplaceKey = "RoundCountdown",
		Style = {
			BackgroundColor = Color3.fromRGB(30, 38, 58),
			AccentColor = Color3.fromRGB(115, 175, 255),
			TextColor = Color3.fromRGB(245, 250, 255),
			Icon = "",
		},
	},
	Generic = {
		Type = "Generic",
		I18nKey = "notification.generic",
		FallbackText = "{message}",
		Priority = NotificationConfigData.Priority.Normal,
		DisplaySeconds = 2.5,
		Style = {
			BackgroundColor = Color3.fromRGB(25, 25, 25),
			AccentColor = Color3.fromRGB(255, 255, 255),
			TextColor = Color3.fromRGB(255, 255, 255),
			Icon = "",
		},
	},
}

function NotificationConfigData.Get(notificationType: string?): NotificationConfig
	local key = tostring(notificationType or "")
	return (NotificationConfigData.Types[key] or NotificationConfigData.Types.Generic) :: NotificationConfig
end

return NotificationConfigData
