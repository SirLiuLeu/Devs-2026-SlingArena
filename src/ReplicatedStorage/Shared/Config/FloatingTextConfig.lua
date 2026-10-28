--!strict

type FloatingTextDefinition = {
	Color: Color3,
	Prefix: string,
	Suffix: string,
	Scale: number,
}

local FloatingTextConfig = {
	Types = {
		Damage = {
			Color = Color3.fromRGB(255, 50, 50),
			Prefix = "-",
			Suffix = "",
			Scale = 1.0,
		},
		Heal = {
			Color = Color3.fromRGB(50, 255, 50),
			Prefix = "+",
			Suffix = "",
			Scale = 1.1,
		},
		Exp = {
			Color = Color3.fromRGB(0, 229, 255),
			Prefix = "+",
			Suffix = " EXP",
			Scale = 0.9,
		},
	} :: { [string]: FloatingTextDefinition },
}

return FloatingTextConfig
