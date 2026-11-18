--!strict

-- Item definitions are shared presentation/balance data. ItemService remains the only
-- authority that mutates quantities or applies these effects.
local ItemConfig = {}

export type ItemEffect = {
	kind: "Flag" | "Experience" | "Bomb" | "GiftBox",
	flagName: string?,
	flagParams: { [string]: any }?,
	experienceAmount: number?,
}

export type BombItemConfig = {
	Damage: number,
	BlastRadius: number,
	FuseTime: number,
	SpawnForwardOffset: number,
	SpawnHeightOffset: number,
	MaxActivePerPlayer: number,
	ExplosionParticleEmitCount: number,
	RingScaleMultiplier: number,
	RingExpandMultiplier: number,
	RingTweenDuration: number,
	CleanupDelay: number,
	MaxDamageFalloffPercent: number,
	KnockbackSpeed: number,
	BeepInterval: number,
}

type ItemDefinition = {
	id: string,
	name: string,
	description: string,
	script: string,
	shopPriceX1: number,
	shopPriceX10: number,
	icon: string,
	itemType: "Consumable",
	stackable: boolean,
	consumeOnUse: boolean,
	useCooldown: number?,
	effect: ItemEffect?,
	bombConfig: BombItemConfig?,
}

ItemConfig.Items = {
	{
		id = "bomb", name = "Bomb", description = "Place a bomb that explodes after 3 seconds and damages nearby players and food.",
		script = "Đặt một quả bom có thời gian kích hoạt 3 giây, gây sát thương và lực đẩy lên các mục tiêu ở gần.", shopPriceX1 = 75, shopPriceX10 = 650,
		icon = "rbxassetid://70706019014966",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1.5,
		effect = { kind = "Bomb" },
		bombConfig = {
			Damage = 1500,
			BlastRadius = 22,
			FuseTime = 3,
			SpawnForwardOffset = 5,
			SpawnHeightOffset = 6,
			MaxActivePerPlayer = 2,
			ExplosionParticleEmitCount = 28,
			RingScaleMultiplier = 2.5,
			RingExpandMultiplier = 2,
			RingTweenDuration = 0.75,
			CleanupDelay = 2.25,
			MaxDamageFalloffPercent = 20,
			KnockbackSpeed = 45,
			BeepInterval = 0.75,
		},
	},
	{
		id = "gift_box", name = "Gift Box", description = "Open to receive Diamonds or a useful consumable item.",
		script = "Hộp quà ngẫu nhiên. Sử dụng để nhận Diamonds hoặc một vật phẩm tiêu hao hữu ích.", shopPriceX1 = 100, shopPriceX10 = 900,
		icon = "rbxassetid://73584476161715",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 0.35,
		effect = { kind = "GiftBox" },
	},
	{
		id = "hp_potion", name = "HP Potion", description = "Restore 500 HP every 0.5 seconds for 3 seconds.",
		script = "Hồi 500 HP mỗi 0,5 giây trong 3 giây, giúp phục hồi nhanh trong giao tranh.", shopPriceX1 = 35, shopPriceX10 = 300,
		 icon = "rbxassetid://138146402871393", 
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 3,
		effect = { kind = "Flag", flagName = "HPRecovering", flagParams = { Duration = 3, TickInterval = 0.5, HealPerTick = 500 } },
	},
	{
		id = "exp_buff_30", name = "30% EXP Buff", description = "Gain 30% more EXP for 5 minutes. Reuse refreshes duration.",
		script = "Tăng 30% EXP nhận được trong 5 phút. Sử dụng lại sẽ làm mới thời gian hiệu lực.", shopPriceX1 = 50, shopPriceX10 = 450, icon = "rbxassetid://16112286685",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "EXPBoosted", flagParams = { Duration = 300, ExpBonusPercent = 30 } },
	},
	{
		id = "damage_buff_20", name = "20% Damage Buff", description = "Deal 20% more damage for 60 seconds. Reuse refreshes duration.",
		script = "Tăng 20% sát thương gây ra trong 60 giây. Sử dụng lại sẽ làm mới hiệu lực.", shopPriceX1 = 70, shopPriceX10 = 630, icon = "rbxassetid://0",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "DamageBoosted", flagParams = { Duration = 60, DamageBonusPercent = 20 } },
	},
	{
		id = "hp_buff_30", name = "30% HP Buff", description = "Increase maximum HP by 30% for 5 minutes. Reuse refreshes duration.",
		script = "Tăng 30% HP tối đa trong 5 phút. Sử dụng lại sẽ làm mới thời gian hiệu lực.", shopPriceX1 = 70, shopPriceX10 = 630, icon = "rbxassetid://0",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "HPBoosted", flagParams = { Duration = 300, MaxHPBonusPercent = 30 } },
	},
	{
		id = "exp_card_500", name = "500 EXP Card", description = "Immediately grants 500 EXP.",
		script = "Sử dụng ngay để nhận 500 EXP.", shopPriceX1 = 40, shopPriceX10 = 360, 
		icon = "rbxassetid://121017572574132",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 0.25,
		effect = { kind = "Experience", experienceAmount = 500 },
	},
	{
		id = "luck_buff_clover", name = "3-Leaf Clover", description = "Increase server-side diamond-drop chance by 30% for 5 minutes. Reuse refreshes duration.",
		script = "Tăng 30% cơ hội rơi Diamonds trong 5 phút. Sử dụng lại sẽ làm mới thời gian hiệu lực.", shopPriceX1 = 60, shopPriceX10 = 540,
		icon = "rbxassetid://132864992072277",
		itemType = "Consumable", stackable = true, consumeOnUse = true, useCooldown = 1,
		effect = { kind = "Flag", flagName = "LuckBoosted", flagParams = { Duration = 300, DiamondDropChanceBonusPercent = 30 } },
	},
} :: { ItemDefinition }

local byId = {} :: { [string]: ItemDefinition }
for _, item in ipairs(ItemConfig.Items) do byId[item.id] = item end
function ItemConfig.GetById(id: string): ItemDefinition? return byId[id] end
function ItemConfig.GetAllIds(): { string }
	local result = {}
	for _, item in ipairs(ItemConfig.Items) do table.insert(result, item.id) end
	return result
end
return ItemConfig
