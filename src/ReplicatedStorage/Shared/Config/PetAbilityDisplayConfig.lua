--!strict

-- Player-facing ability descriptions for PetInventoryUI. Keep this separate from
-- PetAbilityProgressionConfig: this module describes behavior; progression config
-- remains the source of level-scaled numeric parameters.
local PetAbilityDisplayConfig = {}

PetAbilityDisplayConfig.Descriptions = {
	PlasmaCannon = {
		vi = "Tự động bắn cầu Plasma vào kẻ địch gần nhất trong phạm vi 120 studs, gây {damage} sát thương. Hồi chiêu: {cooldown}s.",
		en = "Automatically fires a Plasma projectile at the nearest enemy within 120 studs, dealing {damage} damage. Cooldown: {cooldown}s.",
	},
	Hydra = {
		vi = "Tăng trọng lượng Launcher lên {weight} và hitbox lên {hitbox}. Khi được trang bị, Launcher tăng 4% kích thước mỗi lần người chơi lên cấp, tối đa 2x.",
		en = "Increases Launcher weight to {weight} and hitbox to {hitbox}. While equipped, Launcher size grows by 4% per player level-up, up to 2x.",
	},
	ThunderHammer = {
		vi = "Va chạm với người chơi đối thủ gây choáng trong thời lượng cơ bản {duration}s (còn scale theo lực va chạm). Đồng thời tăng 5% sát thương cơ bản của Launcher.",
		en = "Collisions with enemy players apply Stun for a base duration of {duration}s (also scaled by impact speed). Also increases base damage by 5%.",
	},
	Medusa = {
		vi = "Va chạm với người chơi đối thủ gây hóa đá trong thời lượng cơ bản {duration}s (còn scale theo lực va chạm). Người chơi trang bị Phoenix miễn nhiễm hiệu ứng này.",
		en = "Collisions with enemy players apply Petrify for a base duration of {duration}s (also scaled by impact speed). Players with Phoenix equipped are immune.",
	},
	IceCrystal = {
		vi = "Va chạm kích hoạt Slow, làm giảm 25% tốc độ mục tiêu. Thời lượng cơ bản: {duration}s; thời lượng thực tế được scale theo tốc độ va chạm.",
		en = "Collisions apply Slow, reducing the target's speed by 25%. Base duration: {duration}s; actual duration scales with collision speed.",
	},
	GhostFlame = {
		vi = "Va chạm áp dụng Burn lên người chơi hoặc thức ăn, gây {damagePerTick} sát thương mỗi giây. Đồng thời tăng {baseDamage} sát thương cơ bản.",
		en = "Collisions apply Burn to players or food, dealing {damagePerTick} damage per second. Also adds {baseDamage} base damage.",
	},
	Poison = {
		vi = "Va chạm áp dụng Poison lên người chơi hoặc thức ăn, gây {damagePerTick} sát thương mỗi giây. Đồng thời tăng {baseDamage} sát thương cơ bản.",
		en = "Collisions apply Poison to players or food, dealing {damagePerTick} damage per second. Also adds {baseDamage} base damage.",
	},
	HealthCore = {
		vi = "Tăng {maxHP} HP tối đa.",
		en = "Increases maximum HP by {maxHP}.",
	},
	PowerCore = {
		vi = "Tăng {baseDamage} sát thương cơ bản.",
		en = "Increases base damage by {baseDamage}.",
	},
	Shield = {
		vi = "Giảm {damageReduction} sát thương nhận vào.",
		en = "Reduces incoming damage by {damageReduction}.",
	},
	BrainBoost = {
		vi = "Tăng {expBonus} EXP nhận được.",
		en = "Increases EXP gained by {expBonus}.",
	},
	TurboModule = {
		vi = "Tăng {moveSpeed} tốc độ di chuyển.",
		en = "Increases movement speed by {moveSpeed}.",
	},
	LaunchBooster = {
		vi = "Nhân tốc độ phóng tối đa của Launcher lên {launchSpeed}.",
		en = "Multiplies the Launcher's maximum launch speed by {launchSpeed}.",
	},
	Dragon = {
		vi = "Tự động bắn SlowBlaster vào kẻ địch gần nhất, làm chậm trong {slowDuration}s. Hồi chiêu: {cooldown}s.",
		en = "Automatically fires SlowBlaster at the nearest enemy, slowing them for {slowDuration}s. Cooldown: {cooldown}s.",
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
		vi = "Hồi {healAmount} HP mỗi {tickInterval}s.",
		en = "Restores {healAmount} HP every {tickInterval}s.",
	},
	ShadowCloak = {
		vi = "Tàng hình sau {idleSeconds}s đứng yên. Tự hiện hình khi phóng, va chạm hoặc tấn công.",
		en = "Enters stealth after {idleSeconds}s without movement. Reveals on launch, collision, or attack.",
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
