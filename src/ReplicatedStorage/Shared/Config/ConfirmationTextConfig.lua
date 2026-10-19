--!strict

local LocalizationService = game:GetService("LocalizationService")

local ConfirmationTextConfig = {}

local TEXTS = {
	ChangeTeam = {
		vi = "Bạn có chắc chắn muốn chuyển đội từ {currentTeam} sang {team} không?",
		en = "Are you sure you want to switch teams from {currentTeam} to {team}?",
	},
	TeamFull = {
		vi = "Đội này đã đủ người.",
		en = "This team is full.",
	},
	Cooldown = {
		vi = "Bạn cần chờ thêm {seconds} giây trước khi đổi đội.",
		en = "Wait {seconds} more seconds before switching teams.",
	},
	RageActive = {
		vi = "Không thể đổi đội khi Rage đang hoạt động.",
		en = "You cannot switch teams while Rage is active.",
	},
	TeamChangeUnavailable = {
		vi = "Hiện tại không thể đổi đội.",
		en = "Team switching is unavailable right now.",
	},
	UnequipLauncher = {
		vi = "Bạn có chắc chắn muốn bỏ trang bị Launcher này không?",
		en = "Are you sure you want to unequip this launcher?",
	},
	SellLauncher = {
		vi = "Bạn có chắc chắn muốn bán Launcher này để nhận {price} kim cương không?",
		en = "Are you sure you want to sell this launcher for {price} Diamonds?",
	},
	LauncherEquipSuccess = {
		vi = "Đã trang bị Launcher thành công.",
		en = "Launcher equipped successfully.",
	},
	LauncherEquipFailed = {
		vi = "Không thể trang bị Launcher này. Lý do: {reason}",
		en = "Could not equip this Launcher. Reason: {reason}",
	},
	LauncherEquipVisualFailed = {
		vi = "Dữ liệu trang bị đã cập nhật nhưng visual Launcher chưa thể làm mới.",
		en = "The equip data was updated, but the Launcher visual could not be refreshed.",
	},
	LauncherSellSuccess = {
		vi = "Đã bán Launcher và nhận {price} kim cương.",
		en = "Launcher sold for {price} Diamonds.",
	},
	LauncherSellFailed = {
		vi = "Không thể bán Launcher này. Lý do: {reason}",
		en = "Could not sell this Launcher. Reason: {reason}",
	},
	LeaveArena = {
		vi = "Rời đấu trường lúc này sẽ bị phạt 30 giây. Bạn có chắc chắn không?",
		en = "Leaving now will apply a 30-second penalty. Are you sure?",
	},
}

function ConfirmationTextConfig.Get(key: string, replacements: { [string]: any }?, locale: string?): string
	local entry = TEXTS[key]
	if not entry then
		warn(string.format("[CONFIRMATION_TEXT] Missing text config key %q.", key))
		return key
	end
	local activeLocale = string.lower(locale or LocalizationService.RobloxLocaleId or "en")
	local language = if string.sub(activeLocale, 1, 2) == "vi" then "vi" else "en"
	local template = entry[language] or entry.en or key
	return (template:gsub("{([%w_]+)}", function(name)
		local value = replacements and replacements[name]
		return if value == nil then "{" .. name .. "}" else tostring(value)
	end))
end

return ConfirmationTextConfig
