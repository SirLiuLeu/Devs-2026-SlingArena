--!strict

-- Owns only the world lifecycle of placed Bombs.
-- Item quantities are owned by ItemService; player and Food damage are delegated
-- to DamagePipelineService and FoodService respectively.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)

local BombService = {}
BombService.__index = BombService

function BombService.new(context)
	local self = setmetatable({}, BombService)
	self._context = context
	self._bombTemplate = nil :: Model?
	self._explosionPartTemplate = nil :: BasePart?
	self._ringTemplate = nil :: Model?
	self._activeBombs = {} :: { [Player]: { [Model]: boolean } }
	return self
end

function BombService:Init()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local prefabs = assets and assets:FindFirstChild("Prefabs")
	local effects = assets and assets:FindFirstChild("EffectVfx")

	local bomb = prefabs and prefabs:FindFirstChild("Bomb")
	if bomb and bomb:IsA("Model") then
		self._bombTemplate = bomb
	else
		warn("[BombService] Missing required Model: ReplicatedStorage.Assets.Prefabs.Bomb")
	end

	local explosionPart = effects and effects:FindFirstChild("ExplosionPart")
	local explosionAttachment = explosionPart and explosionPart:FindFirstChild("Explosion")
	if explosionPart and explosionPart:IsA("BasePart")
		and explosionAttachment and explosionAttachment:IsA("Attachment") then
		self._explosionPartTemplate = explosionPart
	else
		warn("[BombService] Missing required VFX Part/Attachment: ReplicatedStorage.Assets.EffectVfx.ExplosionPart.Explosion")
	end

	local ring = prefabs and prefabs:FindFirstChild("VFX_ExplosionRing")
	if ring and ring:IsA("Model") then
		self._ringTemplate = ring
	else
		warn("[BombService] Missing optional VFX Model: ReplicatedStorage.Assets.Prefabs.VFX_ExplosionRing")
	end

	Players.PlayerRemoving:Connect(function(player: Player)
		self:ClearPlayer(player)
	end)
end

function BombService:_getDefinition()
	return ItemConfig.GetById("bomb")
end

function BombService:_getActiveCount(player: Player): number
	local bombs = self._activeBombs[player]
	if not bombs then
		return 0
	end

	local count = 0
	for bomb in pairs(bombs) do
		if bomb and bomb.Parent then
			count += 1
		else
			bombs[bomb] = nil
		end
	end
	return count
end

function BombService:CanPlaceBomb(player: Player): (boolean, string?)
	local definition = self:_getDefinition()
	local config = definition and definition.bombConfig
	if not (self._bombTemplate and config) then
		return false, "BombAssetUnavailable"
	end

	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local roundService = ServiceResolver.Get(self._context, "RoundService")
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local state = stateService and stateService:GetState(player)
	local validMode = state and (state.ActivePlayerMode == GameStates.PlayerMode.Launcher or state.ActivePlayerMode == GameStates.PlayerMode.Human)
	if not (state and state.IsAlive == true and validMode) then
		return false, "InvalidPlayerState"
	end
	if state.LocationState == GameStates.SessionState.Lobby then
		return false, "NotInRound"
	end

	local roundState = roundService and roundService:GetState()
	if roundState ~= GameStates.MapRoundState.EarlyGame and roundState ~= GameStates.MapRoundState.FinalPhase then
		return false, "NotInCombatPhase"
	end
	if not (playerService and playerService:GetRoot(player)) then
		return false, "PlayerRootUnavailable"
	end
	if self:_getActiveCount(player) >= math.max(1, math.floor(config.MaxActivePerPlayer or 1)) then
		return false, "ActiveBombLimit"
	end

	return true, nil
end

function BombService:_resolveBombRoot(bomb: Model): BasePart?
	local root = bomb:FindFirstChild("RootPart", true)
	if not (root and root:IsA("BasePart")) then
		root = bomb.PrimaryPart
	end
	if not (root and root:IsA("BasePart")) then
		local hitbox = bomb:FindFirstChild("Hitbox", true)
		root = if hitbox and hitbox:IsA("BasePart") then hitbox else nil
	end
	if root and root:IsA("BasePart") and bomb.PrimaryPart == nil then
		bomb.PrimaryPart = root
	end
	return if root and root:IsA("BasePart") then root else nil
end

function BombService:TryPlaceBomb(player: Player): (boolean, string?)
	local canPlace, reason = self:CanPlaceBomb(player)
	if not canPlace then
		return false, reason
	end

	local definition = self:_getDefinition()
	local config = definition and definition.bombConfig
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local playerRoot = playerService and playerService:GetRoot(player)
	if not (config and playerRoot and self._bombTemplate) then
		return false, "BombPlacementUnavailable"
	end

	local bomb = self._bombTemplate:Clone()
	local bombRoot = self:_resolveBombRoot(bomb)
	if not bombRoot then
		warn("[BombService] Bomb prefab must contain a BasePart named RootPart, PrimaryPart, or Hitbox.")
		bomb:Destroy()
		return false, "InvalidBombPrefab"
	end

	for _, descendant in ipairs(bomb:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	bombRoot.Anchored = false
	bombRoot.CanCollide = true
	local bombHitbox = bombRoot:FindFirstChild("Hitbox", true)
	if bombHitbox and bombHitbox:IsA("BasePart") then
		bombHitbox.Anchored = false
		bombHitbox.CanCollide = true
	end
	bomb:SetAttribute("BombOwnerUserId", player.UserId)
	bomb:SetAttribute("BombDetonated", false)

	local forward = Vector3.new(playerRoot.CFrame.LookVector.X, 0, playerRoot.CFrame.LookVector.Z)
	if forward.Magnitude <= 0.001 then
		forward = Vector3.new(0, 0, -1)
	else
		forward = forward.Unit
	end
	local spawnHeightAboveRootTop = math.max(1, config.SpawnHeightOffset or 6)
	local spawnPosition = playerRoot.Position
		+ forward * math.max(0, config.SpawnForwardOffset or 5)
		+ Vector3.new(0, playerRoot.Size.Y * 0.5 + spawnHeightAboveRootTop, 0)
	bomb:PivotTo(CFrame.lookAt(spawnPosition, spawnPosition + forward))
	bomb.Parent = Workspace
	SoundManager.Play("SFX_Beep", bombRoot.Position)
	task.delay(math.max(0.05, tonumber(config.BeepInterval) or 0.75), function()
		if bomb.Parent and bomb:GetAttribute("BombDetonated") ~= true and bombRoot.Parent then
			SoundManager.Play("SFX_Beep", bombRoot.Position)
		end
	end)

	pcall(function()
		bombRoot:SetNetworkOwner(nil)
	end)

	self._activeBombs[player] = self._activeBombs[player] or {}
	self._activeBombs[player][bomb] = true

	task.delay(math.max(0.1, config.FuseTime or 3), function()
		self:_detonate(player, bomb, bombRoot, config)
	end)
	return true, nil
end

function BombService:_activateExplosionVfx(blastPosition: Vector3, emitCount: number)
	if not self._explosionPartTemplate then
		return
	end

	-- Clone the Studio-authored carrier Part so its Attachment keeps the
	-- configured local offset/orientation while remaining independent of the
	-- physical Bomb's roll and rotation.
	local vfxPart = self._explosionPartTemplate:Clone()
	vfxPart.Name = "BombExplosionVfx"
	vfxPart.CFrame = CFrame.new(blastPosition)
	vfxPart.Anchored = true
	vfxPart.Transparency = 1
	vfxPart.CastShadow = false
	vfxPart.CanCollide = false
	vfxPart.CanTouch = false
	vfxPart.CanQuery = false
	vfxPart.Parent = Workspace

	local attachment = vfxPart:FindFirstChild("Explosion")
	if not (attachment and attachment:IsA("Attachment")) then
		warn("[BombService] Cloned ExplosionPart is missing its Explosion Attachment.")
		vfxPart:Destroy()
		return
	end

	for _, effect in ipairs(attachment:GetDescendants()) do
		if effect:IsA("ParticleEmitter") then
			effect:Emit(math.max(1, emitCount))
		elseif effect:IsA("Fire") or effect:IsA("Smoke") or effect:IsA("Sparkles")
			or effect:IsA("Beam") or effect:IsA("Trail")
			or effect:IsA("PointLight") or effect:IsA("SpotLight") or effect:IsA("SurfaceLight") then
			effect.Enabled = true
			task.delay(0.65, function()
				if effect.Parent then
					effect.Enabled = false
				end
			end)
		end
	end
	Debris:AddItem(vfxPart, 2)
end
function BombService:_spawnExplosionRing(position: Vector3, config: any)
	if not self._ringTemplate then
		return
	end

	local ring = self._ringTemplate:Clone()
	ring:PivotTo(CFrame.new(position))
	ring.Parent = Workspace

	local duration = math.max(0.1, tonumber(config.RingTweenDuration) or 0.75)
	local sizeMultiplier = math.max(1, tonumber(config.RingScaleMultiplier) or 2.5)
	local expandMultiplier = math.max(1, tonumber(config.RingExpandMultiplier) or 2)
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local rng = Random.new(math.floor(os.clock() * 100000) % 2147483647)
	local animatedParts = 0

	for _, descendant in ipairs(ring:GetDescendants()) do
		if descendant:IsA("BasePart") then
			animatedParts += 1
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false

			local offset = descendant.Position - position
			local expandedPosition = position + Vector3.new(
				offset.X * expandMultiplier,
				offset.Y,
				offset.Z * expandMultiplier
			)
			local chaoticRotation = CFrame.Angles(
				rng:NextNumber(-math.pi, math.pi),
				rng:NextNumber(-math.pi, math.pi),
				rng:NextNumber(-math.pi, math.pi)
			)
			local specialMesh = descendant:FindFirstChildWhichIsA("SpecialMesh")
			local goal: { [string]: any } = {
				CFrame = CFrame.new(expandedPosition) * chaoticRotation * descendant.CFrame.Rotation,
				Transparency = 1,
			}
			if not specialMesh then
				goal.Size = descendant.Size * sizeMultiplier
			end
			TweenService:Create(descendant, tweenInfo, goal):Play()

			if specialMesh then
				TweenService:Create(specialMesh, tweenInfo, {
					Scale = specialMesh.Scale * sizeMultiplier,
				}):Play()
			end
		end
	end

	if animatedParts == 0 then
		warn("[BombService] VFX_ExplosionRing contains no BasePart descendants to animate.")
	end
	Debris:AddItem(ring, duration + 0.2)
end

function BombService:_applyBlast(owner: Player, center: Vector3, config: any)
	local roundService = ServiceResolver.Get(self._context, "RoundService")
	local roundState = roundService and roundService:GetState()
	if roundState ~= GameStates.MapRoundState.EarlyGame and roundState ~= GameStates.MapRoundState.FinalPhase then
		return
	end

	local radius = math.max(0, tonumber(config.BlastRadius) or 22)
	local damage = math.max(0, tonumber(config.Damage) or 1500)
	local falloffPercent = math.clamp(tonumber(config.MaxDamageFalloffPercent) or 20, 0, 100) / 100
	local knockbackSpeed = math.max(0, tonumber(config.KnockbackSpeed) or 45)
	local playerService = ServiceResolver.Get(self._context, "PlayerService")
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local damageService = ServiceResolver.Get(self._context, "DamagePipelineService")

	if playerService and stateService and damageService then
		for _, victim in ipairs(Players:GetPlayers()) do
			local state = stateService:GetState(victim)
			local victimRoot = playerService:GetRoot(victim)
			local offset = victimRoot and (victimRoot.Position - center) or nil
			local distance = offset and offset.Magnitude or math.huge
			if state and state.IsAlive == true and victimRoot and offset and distance <= radius then
				-- Damage falls linearly with distance, but is capped at a 20% reduction
				-- at the edge of the blast radius. Walls and teams do not block Bombs.
				local distanceRatio = if radius > 0 then math.clamp(distance / radius, 0, 1) else 0
				local scaledDamage = damage * (1 - falloffPercent * distanceRatio)
				local planarOffset = Vector3.new(offset.X, 0, offset.Z)
				local outwardDirection = if planarOffset.Magnitude > 0.001 then planarOffset.Unit else Vector3.new(victimRoot.CFrame.LookVector.X, 0, victimRoot.CFrame.LookVector.Z)
				if outwardDirection.Magnitude <= 0.001 then
					outwardDirection = Vector3.new(0, 0, -1)
				else
					outwardDirection = outwardDirection.Unit
				end
				local knockback = if knockbackSpeed > 0 then outwardDirection * knockbackSpeed else nil
				-- The owner still takes the blast damage, but is not credited with a
				-- self-kill. Other victims retain normal Bomb owner attribution.
				local attacker = if victim == owner then nil else owner
				damageService:ApplyHitDamage(victim, scaledDamage, attacker, knockback, {
					SourceType = "Bomb",
					AllowFriendlyFire = true,
					KnockbackSpeedCap = knockbackSpeed,
				})
			end
		end
	else
		warn("[BombService] Damage dependencies unavailable; player blast damage was skipped.")
	end

	local foodService = ServiceResolver.Get(self._context, "FoodService")
	if foodService and typeof(foodService.ApplyAreaDamageToFood) == "function" then
		foodService:ApplyAreaDamageToFood(center, radius, damage, owner, falloffPercent * 100)
	else
		warn("[BombService] FoodService area-damage API unavailable; Food blast damage was skipped.")
	end
end

function BombService:_untrackBomb(owner: Player, bomb: Model)
	local bombs = self._activeBombs[owner]
	if bombs then
		bombs[bomb] = nil
		if next(bombs) == nil then
			self._activeBombs[owner] = nil
		end
	end
end

function BombService:_detonate(owner: Player, bomb: Model, bombRoot: BasePart, config: any)
	if not (bomb.Parent and bombRoot.Parent) or bomb:GetAttribute("BombDetonated") == true then
		self:_untrackBomb(owner, bomb)
		return
	end

	-- Read the assembly's live position at detonation time. The Bomb may have
	-- fallen and rolled away from its original drop point during the fuse.
	local blastPosition = bombRoot.Position
	bomb:SetAttribute("BombDetonated", true)

	for _, descendant in ipairs(bomb:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	SoundManager.Play("SFX_ExplosionBomb", blastPosition)
	self:_activateExplosionVfx(blastPosition, tonumber(config.ExplosionParticleEmitCount) or 28)
	self:_spawnExplosionRing(blastPosition, config)
	self:_applyBlast(owner, blastPosition, config)

	local cleanupDelay = math.max(0.1, tonumber(config.CleanupDelay) or 1.25)
	task.delay(cleanupDelay, function()
		if bomb.Parent then
			bomb:Destroy()
		end
		self:_untrackBomb(owner, bomb)
	end)
end

function BombService:ClearPlayer(player: Player)
	local bombs = self._activeBombs[player]
	self._activeBombs[player] = nil
	if not bombs then
		return
	end
	for bomb in pairs(bombs) do
		if bomb and bomb.Parent then
			bomb:Destroy()
		end
	end
end

return BombService
