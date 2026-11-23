--!strict

-- Player-facing ability descriptions for PetInventoryUI. Keep this separate from
-- PetAbilityProgressionConfig: this module describes behavior; progression config
-- remains the source of level-scaled numeric parameters.
local PetAbilityDisplayConfig = {}

PetAbilityDisplayConfig.Descriptions = {
	PlasmaCannon = {
		vi = "Titan: tăng trọng lượng Launcher lên {weight}, hitbox lên {hitbox}, knockback gây ra {outgoingKnockbackBonus} và giảm knockback nhận vào {incomingKnockbackReduction}. Launcher tăng kích thước 4% mỗi cấp người chơi, tối đa 2x.",
		en = "Titan: increases Launcher weight to {weight}, hitbox to {hitbox}, outgoing knockback by {outgoingKnockbackBonus}, and reduces incoming knockback by {incomingKnockbackReduction}. Launcher size grows 4% per player level, up to 2x.",
	},
	Hydra = {
		vi = "Last Stand: tăng tối đa {lastStandDamageBonus} sát thương khi HP giảm xuống 20% hoặc thấp hơn. Hiệu ứng bắt đầu tăng khi HP dưới 80%.",
		en = "Last Stand: grants up to {lastStandDamageBonus} bonus damage at 20% HP or lower. The bonus ramps up below 80% HP.",
	},
	ThunderHammer = {
		vi = "Tăng {launcherStatBonus} các chỉ số cốt lõi của Launcher, không nhân chỉ số cơ bản từ Pet.",
		en = "Increases core Launcher stats by {launcherStatBonus}; Pet base stats are not included in this multiplier.",
	},
	Medusa = {
		vi = "Va chạm áp dụng Poison, gây {damagePerTick} sát thương mỗi giây. Không kèm hiệu ứng làm chậm.",
		en = "Collisions apply Poison, dealing {damagePerTick} damage per second. It does not apply Slow.",
	},
	IceCrystal = {
		vi = "Nhân {petBaseStatsMultiplier} phần HP và sát thương cơ bản đến từ rarity và level của toàn bộ Pet đang trang bị.",
		en = "Multiplies the rarity-and-level base HP and damage from all equipped Pets by {petBaseStatsMultiplier}.",
	},
	GhostFlame = {
		vi = "Va chạm áp dụng Burn lên người chơi hoặc thức ăn, gây {damagePerTick} sát thương mỗi giây; đồng thời tăng {baseDamage} sát thương cơ bản.",
		en = "Collisions apply Burn to players or Food, dealing {damagePerTick} damage per second; also adds {baseDamage} base damage.",
	},
	Poison = {
		vi = "Lifesteal: hồi {playerLifestealPercent} sát thương thực tế gây lên người chơi và {foodLifestealPercent} sát thương gây lên thức ăn; đồng thời tăng {baseDamage} sát thương cơ bản.",
		en = "Lifesteal: restores {playerLifestealPercent} of actual damage dealt to players and {foodLifestealPercent} of damage dealt to Food; also adds {baseDamage} base damage.",
	},
	HealthCore = {
		vi = "Tăng {maxHPBonusPercent} HP tối đa sau khi cộng chỉ số Launcher và Pet.",
		en = "Increases final maximum HP by {maxHPBonusPercent} after Launcher and Pet base stats are combined.",
	},
	PowerCore = {
		vi = "Tăng {damageBonusPercent} sát thương cơ bản sau khi cộng chỉ số Launcher và Pet.",
		en = "Increases final base damage by {damageBonusPercent} after Launcher and Pet base stats are combined.",
	},
	Shield = {
		vi = "Hấp thụ tối đa {absorbCapacity} sát thương mỗi {refreshInterval}s. Sát thương Lava và SafeZone không bị hấp thụ.",
		en = "Absorbs up to {absorbCapacity} damage every {refreshInterval}s. Lava and SafeZone damage bypass the shield.",
	},
	BrainBoost = {
		vi = "Tăng {expBonus} EXP nhận được.",
		en = "Increases EXP gained by {expBonus}.",
	},
	TurboModule = {
		vi = "Tăng {moveSpeedBonusPercent} tốc độ di chuyển.",
		en = "Increases movement speed by {moveSpeedBonusPercent}.",
	},
	LaunchBooster = {
		vi = "Nhân tốc độ phóng tối đa của Launcher lên {launchSpeed}.",
		en = "Multiplies the Launcher's maximum launch speed by {launchSpeed}.",
	},
	Dragon = {
		vi = "Full Force: tăng tối đa {fullForceDamageBonus} sát thương khi HP đầy; bonus giảm tỷ lệ thuận khi HP giảm.",
		en = "Full Force: grants up to {fullForceDamageBonus} bonus damage at full HP; the bonus scales down with current HP.",
	},
	QuickReload = {
		vi = "Giảm {launchCooldown}s thời gian hồi chiêu phóng.",
		en = "Reduces launch cooldown by {launchCooldown}s.",
	},
	ThornArmor = {
		vi = "Phản lại {reflectDamage} sát thương nhận vào cho kẻ tấn công.",
		en = "Reflects {reflectDamage} of incoming damage back to the attacker.",
	},
	RegenBooster = {
		vi = "Hồi cố định {healAmount} HP mỗi {tickInterval}s. Tăng thêm {healingReceivedBonus} lượng hồi phục từ các nguồn khác.",
		en = "Restores a fixed {healAmount} HP every {tickInterval}s and increases healing received from other sources by {healingReceivedBonus}.",
	},
	ShadowCloak = {
		vi = "Tàng hình sau {idleSeconds}s đứng yên. Tự hiện hình khi phóng, di chuyển hoặc bị đánh bật.",
		en = "Enters stealth after {idleSeconds}s without movement. Reveals on launch, movement or knockback.",
	},
}

function PetAbilityDisplayConfig.GetTemplate(petId: string?, languageCode: string?): string?
	if type(petId) ~= "string" then
		return nil
	end
	local entry = PetAbilityDisplayConfig.Descriptions[petId]
	if not entry then
		return nil
	end
	local locale = string.lower(languageCode or "en")
	local language = if string.sub(locale, 1, 2) == "vi" then "vi" else "en"
	return entry[language] or entry.en
end

return PetAbilityDisplayConfig
