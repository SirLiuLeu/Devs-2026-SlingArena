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
		vi = "Tăng trọng lượng Launcher lên {weight}x và hitbox lên {hitbox}x. Khi được trang bị, Launcher tăng 4% kích thước mỗi lần người chơi lên cấp, tối đa 2x.",
		en = "Increases Launcher weight to {weight}x and hitbox to {hitbox}x. While equipped, Launcher size grows by 4% per player level-up, up to 2x.",
	},
	ThunderHammer = {
		vi = "Va chạm với người chơi đối thủ gây choáng. Đồng thời tăng 5% sát thương cơ bản của Launcher.",
		en = "Collisions with enemy players apply Stun. Also increases the Launcher's base damage by 5%.",
	},
	Medusa = {
		vi = "Va chạm với người chơi đối thủ gây hóa đá. Người chơi đang trang bị Phoenix miễn nhiễm hiệu ứng hóa đá này.",
		en = "Collisions with enemy players apply Petrify. Players with Phoenix equipped are immune to this Petrify effect.",
	},
	IceCrystal = {
		vi = "Va chạm kích hoạt Slow, làm giảm 25% tốc độ mục tiêu. Thời lượng hiệu ứng được scale theo tốc độ va chạm.",
		en = "Collisions apply Slow, reducing the target's speed by 25%. Effect duration scales with collision speed.",
	},
	GhostFlame = {
		vi = "Va chạm áp dụng Burn lên người chơi hoặc thức ăn. Tăng {baseDamage} sát thương cơ bản.",
		en = "Collisions apply Burn to players or food. Adds {baseDamage} base damage.",
	},
	Poison = {
		vi = "Va chạm áp dụng Poison lên người chơi hoặc thức ăn. Tăng {baseDamage} sát thương cơ bản.",
		en = "Collisions apply Poison to players or food. Adds {baseDamage} base damage.",
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
		vi = "Tăng tốc độ phóng của Launcher lên {launchSpeed} lần.",
		en = "Increases Launcher launch speed to {launchSpeed}x.",
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
		vi = "Phản lại {reflectDamage} sát thương nhận vào.",
		en = "Reflects {reflectDamage} of incoming damage.",
	},
	RegenBooster = {
		vi = "Hồi {healAmount} HP mỗi {tickInterval}s.",
		en = "Restores {healAmount} HP every {tickInterval}s.",
	},
	ShadowCloak = {
		vi = "Tàng hình sau khi không hoạt động trong 3 giây. Tự hiện hình khi phóng, va chạm hoặc tấn công.",
		en = "Enters stealth after 3 seconds of inactivity. Reveals on launch, collision, or attack.",
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
