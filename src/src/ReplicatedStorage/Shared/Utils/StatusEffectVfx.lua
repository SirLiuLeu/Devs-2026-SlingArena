--!strict

local StatusEffectVfx = {}

export type StatusEffectInstance = ParticleEmitter | Fire | Smoke

type EffectSpec = {
	Attachment: string,
	ClassName: string,
}

local EFFECT_SPECS: { [string]: EffectSpec } = {
	Stun = { Attachment = "EffectHead", ClassName = "ParticleEmitter" },
	Burn = { Attachment = "EffectOrigin", ClassName = "Fire" },
	Frost = { Attachment = "EffectOrigin", ClassName = "ParticleEmitter" },
	Poison = { Attachment = "EffectOrigin", ClassName = "Smoke" },
}

StatusEffectVfx.EffectSpecs = EFFECT_SPECS

local function getSpec(effectName: string): EffectSpec?
	return EFFECT_SPECS[effectName]
end

function StatusEffectVfx.IsStatusEffectName(effectName: any?): boolean
	return typeof(effectName) == "string" and getSpec(effectName) ~= nil
end

function StatusEffectVfx.GetDefaultAttachmentName(effectName: string): string?
	local spec = getSpec(effectName)
	return if spec then spec.Attachment else nil
end

function StatusEffectVfx.GetExpectedClassName(effectName: string): string?
	local spec = getSpec(effectName)
	return if spec then spec.ClassName else nil
end

function StatusEffectVfx.GetStatusEffect(root: BasePart, effectName: string, attachmentName: string?): StatusEffectInstance?
	local spec = getSpec(effectName)
	if not spec then
		warn(string.format(
			"[StatusEffectVfx] Unknown status effect '%s' requested on %s.",
			effectName,
			root:GetFullName()
		))
		return nil
	end

	local resolvedAttachmentName = attachmentName or spec.Attachment
	local attachment = root:FindFirstChild(resolvedAttachmentName)
	if not (attachment and attachment:IsA("Attachment")) then
		warn(string.format(
			"[StatusEffectVfx] Attachment '%s' missing on %s for pre-placed %s (%s) effect.",
			resolvedAttachmentName,
			root:GetFullName(),
			effectName,
			spec.ClassName
		))
		return nil
	end

	local effect = attachment:FindFirstChild(effectName)
	if effect and effect:IsA(spec.ClassName) then
		return effect :: any
	end

	local actualClassName = if effect then effect.ClassName else "nil"
	warn(string.format(
		"[StatusEffectVfx] Pre-placed effect '%s' under %s.%s must be a %s, got %s.",
		effectName,
		root:GetFullName(),
		resolvedAttachmentName,
		spec.ClassName,
		actualClassName
	))
	return nil
end

function StatusEffectVfx.SetStatusEffectEnabled(root: BasePart, effectName: string, enabled: boolean, attachmentName: string?): boolean
	local effect = StatusEffectVfx.GetStatusEffect(root, effectName, attachmentName)
	if not effect then
		return false
	end
	(effect :: any).Enabled = enabled
	return true
end

function StatusEffectVfx.SetAllStatusEffectsEnabled(root: BasePart, enabled: boolean)
	for effectName, spec in pairs(EFFECT_SPECS) do
		StatusEffectVfx.SetStatusEffectEnabled(root, effectName, enabled, spec.Attachment)
	end
end

return StatusEffectVfx
