--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local LauncherConfig = require(ReplicatedStorage.Shared.Config.LauncherConfig)
local StatusEffectVfx = require(ReplicatedStorage.Shared.Utils.StatusEffectVfx)
local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local LauncherAnimationController = require(script.Parent.AnimationController)
local ServiceResolver = require(script.Parent.Parent.Infrastructure.ServiceResolver)

local EQUIPPED_LAUNCHER_MODEL_NAME = "EquippedLauncherModel"
local TYPO_EQUIPPED_LAUNCHER_MODEL_NAME = "EquipedLauncherModel"
local PLAYER_CHARACTER_MODEL_NAME = "Player"
local LAUNCHER_ROOT_PART_NAME = "RootPart"
local HITBOX_ROOT_WELD_NAME = "WeldConstraint_HitboxRootPart"
local LEGACY_HITBOX_MESH_WELD_NAME = "WeldConstraint_HitboxMesh"

local function setPreplacedStatusEffectsEnabled(root: BasePart, enabled: boolean)
	StatusEffectVfx.SetAllStatusEffectsEnabled(root, enabled)
end

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new(context)
	local self = setmetatable({}, PlayerService)
	self._context = context
	self._deathConnections = {}
	self._pawnsFolder = Workspace:FindFirstChild("LauncherPawns")
	self._launcherTemplate = nil
	self._worldUiTemplate = nil
	self._playerToLauncher = {}
	self._launcherToPlayer = {}
	self._animationControllers = {}
	if not self._pawnsFolder then
		self._pawnsFolder = Instance.new("Folder")
		self._pawnsFolder.Name = "LauncherPawns"
		self._pawnsFolder.Parent = Workspace
	end
	return self
end

function PlayerService:Init()
	Players.CharacterAutoLoads = false
	self:_loadLauncherTemplate()
	self:_loadWorldUiTemplate()

	self._context.EventBus:On("PlayerStateUpdated", function(player: Player, state)
		self:_updateWorldUi(player, state)
		self:_updateLauncherAnimations(player, state)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_waitForPlayerReady(player)
		self:SpawnForActiveMode(player, 1, "LobbyMap", GameStates.PlayerMode.Human)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
		self._playerToLauncher[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self:_waitForPlayerReady(player)
		self:SpawnForActiveMode(player, 1, "LobbyMap", GameStates.PlayerMode.Human)
	end

	local debugResetRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.DebugResetLauncher)
	if debugResetRemote and debugResetRemote:IsA("RemoteEvent") then
		debugResetRemote.OnServerEvent:Connect(function(player)
			self:RespawnCurrentMode(player, nil, ServiceResolver.Get(self._context, "MapService"):GetActiveMap() or "LobbyMap")
		end)
	end
end

function PlayerService:ShowFloatingHpChange(adornee: BasePart?, amount: number)
	if not (adornee and adornee.Parent) or amount == 0 then
		return
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local uiFolder = assets and assets:FindFirstChild("UI")
	local template = uiFolder and uiFolder:FindFirstChild("FloatingDamage")
	if not (template and template:IsA("BillboardGui")) then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Name = "FloatingDamage"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = adornee.Position
	anchor.Parent = Workspace

	local ui = template:Clone()
	ui.Name = "FloatingDamage"
	ui.Adornee = anchor
	ui.Enabled = true
	ui.Parent = anchor

	local value = ui:FindFirstChild("Value")
	if value and value:IsA("TextLabel") then
		value.Text = string.format("%s%d", if amount > 0 then "+" else "-", math.floor(math.abs(amount) + 0.5))
		value.TextColor3 = if amount > 0 then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(255, 80, 80)
		TweenService:Create(value, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end
	TweenService:Create(anchor, TweenInfo.new(0.8), { Position = anchor.Position + Vector3.new(0, 3, 0) }):Play()
	Debris:AddItem(anchor, 0.85)
end


function PlayerService:ShowHpBarRestore(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local pawn = self:GetPawn(player)
	local worldUi = pawn and pawn:FindFirstChild("LauncherWorldUI")
	local hpBarBackground = worldUi and worldUi:FindFirstChild("HpBarBackground")
	if not (hpBarBackground and hpBarBackground:IsA("Frame")) then
		return
	end

	local label = Instance.new("TextLabel")
	label.Name = "LevelUpHpRestore"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0, -2)
	label.Size = UDim2.new(1.4, 0, 0, 18)
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("+%d HP", math.floor(amount + 0.5))
	label.TextColor3 = Color3.fromRGB(80, 255, 120)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0.25
	label.TextScaled = true
	label.ZIndex = 10
	label.Parent = hpBarBackground

	TweenService:Create(label, TweenInfo.new(0.9), {
		Position = UDim2.new(0.5, 0, 0, -24),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(label, 0.95)
end

function PlayerService:_waitForPlayerReady(player: Player)
	while player.Parent == Players and not player:FindFirstChildOfClass("PlayerGui") do
		task.wait()
	end
end

function PlayerService:_loadWorldUiTemplate(): BillboardGui?
	if self._worldUiTemplate and self._worldUiTemplate.Parent ~= nil then
		return self._worldUiTemplate
	end

	-- [UI_CREATION_GUIDE]
	-- Create in Studio:
	-- ReplicatedStorage
	--   Assets (Folder)
	--     UI (Folder)
	--       LauncherWorldUI (BillboardGui)
	--         HpBarBackground (Frame)
	--           HpBarFill (Frame)
	--         NameLabel (TextLabel)
	--         LevelLabel (TextLabel)

	local resolved = ReplicatedStorage
	for token in string.gmatch(ProjectTreeSpec.GameplayInstances.ReplicatedStorage.Assets.LauncherWorldUI, "[^%.]+") do
		resolved = resolved:FindFirstChild(token)
		if not resolved then
			break
		end
	end
	if resolved and resolved:IsA("BillboardGui") then
		self._worldUiTemplate = resolved
		return self._worldUiTemplate
	end

	warn("[WORLD_UI] ReplicatedStorage.Assets.UI.LauncherWorldUI missing. Create it manually in Studio.")
	self._worldUiTemplate = nil
	return nil
end

function PlayerService:_setWorldUiPlayerName(worldUi: BillboardGui, player: Player)
	local nameLabel = worldUi:FindFirstChild("NameLabel")
	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.Text = player.Name
		nameLabel.Visible = true
		nameLabel.Active = true
	end
end

function PlayerService:_attachWorldUi(pawn: Model, player: Player?)
	local worldUiTemplate = self:_loadWorldUiTemplate()
	if not worldUiTemplate then
		return
	end

	local existing = pawn:FindFirstChild("LauncherWorldUI")
	if existing and existing:IsA("BillboardGui") then
		existing:Destroy()
	end

	local worldUi = worldUiTemplate:Clone()
	worldUi.Name = "LauncherWorldUI"
	worldUi.Adornee = pawn.PrimaryPart
	if player then
		self:_setWorldUiPlayerName(worldUi, player)
	end
	worldUi.Parent = pawn
end

function PlayerService:_updateWorldUi(player: Player, state)
	local pawn = self:GetPawn(player)
	if not pawn then
		return
	end
	local worldUi = pawn:FindFirstChild("LauncherWorldUI")
	if not (worldUi and worldUi:IsA("BillboardGui")) then
		self:_attachWorldUi(pawn, player)
		worldUi = pawn:FindFirstChild("LauncherWorldUI")
	end
	if not (worldUi and worldUi:IsA("BillboardGui")) then
		return
	end

	if pawn.PrimaryPart then
		worldUi.Adornee = pawn.PrimaryPart
	end
	self:_setWorldUiPlayerName(worldUi, player)

	local hpFill = worldUi:FindFirstChild("HpBarBackground")
	hpFill = hpFill and hpFill:FindFirstChild("HpBarFill")
	if hpFill and hpFill:IsA("Frame") then
		local maxHp = math.max(state.MaxHP or 1, 1)
		local hpRatio = math.clamp((state.CurrentHP or 0) / maxHp, 0, 1)
		hpFill.Size = UDim2.new(hpRatio, 0, 1, 0)
		if state.TeamId == "TeamRed" then
			hpFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
		elseif state.TeamId == "TeamBlue" then
			hpFill.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
		end
	end

	local levelLabel = worldUi:FindFirstChild("LevelLabel")
	if levelLabel and levelLabel:IsA("TextLabel") then
		levelLabel.Text = string.format("Lv.%d", math.max(1, math.floor(state.Level or 1)))
	end
	local teamLabel = worldUi:FindFirstChild("TeamLabel")
	if teamLabel and teamLabel:IsA("TextLabel") then
		teamLabel.Text = tostring(state.TeamId or "NoTeam")
	end
end

function PlayerService:_resolveLauncherModelSource(launcherId: string): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local launchersFolder = assetsFolder and assetsFolder:FindFirstChild("Launchers")
	local launcherModel = launchersFolder and launchersFolder:FindFirstChild(launcherId)
	if launcherModel and launcherModel:IsA("Model") then
		return launcherModel
	end
	return nil
end

function PlayerService:_resolvePlayerModelSource(): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local launchersFolder = assetsFolder and assetsFolder:FindFirstChild("Launchers")
	local playerModel = launchersFolder and launchersFolder:FindFirstChild(PLAYER_CHARACTER_MODEL_NAME)
	if playerModel and playerModel:IsA("Model") then
		return playerModel
	end
	return nil
end

function PlayerService:_findEquippedLauncherModel(pawn: Model): Model?
	local equipped = pawn:FindFirstChild(EQUIPPED_LAUNCHER_MODEL_NAME)
	if equipped and equipped:IsA("Model") then
		return equipped
	end
	local legacy = pawn:FindFirstChild(TYPO_EQUIPPED_LAUNCHER_MODEL_NAME)
	if legacy and legacy:IsA("Model") then
		legacy.Name = EQUIPPED_LAUNCHER_MODEL_NAME
		return legacy
	end
	return nil
end

function PlayerService:_resolveLauncherVisualRoot(model: Model): BasePart?
	local rootPart = model:FindFirstChild(LAUNCHER_ROOT_PART_NAME)
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		return model.PrimaryPart
	end
	return nil
end

function PlayerService:_cloneEquippedLauncherModel(pawn: Model, launcherModel: Model): Model
	local existing = self:_findEquippedLauncherModel(pawn)
	if existing then
		existing:Destroy()
	end

	local equipped = launcherModel:Clone()
	equipped.Name = EQUIPPED_LAUNCHER_MODEL_NAME
	equipped.Parent = pawn
	return equipped
end

function PlayerService:_updateHitboxRootPartWeld(pawn: Model, hitbox: BasePart, visualRoot: BasePart)
	local legacyWeld = pawn:FindFirstChild(LEGACY_HITBOX_MESH_WELD_NAME)
	if legacyWeld then
		legacyWeld:Destroy()
	end

	local weld = pawn:FindFirstChild(HITBOX_ROOT_WELD_NAME)
	if not (weld and weld:IsA("WeldConstraint")) then
		if weld then
			weld:Destroy()
		end
		weld = Instance.new("WeldConstraint")
		weld.Name = HITBOX_ROOT_WELD_NAME
		weld.Parent = pawn
	end
	weld.Part0 = hitbox
	weld.Part1 = visualRoot
end

function PlayerService:_configureVisualRig(rig: Model)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

function PlayerService:_validateLauncherMotor6Ds(rig: Model, launcherId: string): boolean
	local isValid = true
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if not (part0 and part0:IsDescendantOf(rig)) then
				isValid = false
				warn(string.format("[PLAYER_SERVICE] Launcher %s Motor6D %s has invalid Part0 after cloning", launcherId, descendant:GetFullName()))
			end
			if not (part1 and part1:IsDescendantOf(rig)) then
				isValid = false
				warn(string.format("[PLAYER_SERVICE] Launcher %s Motor6D %s has invalid Part1 after cloning", launcherId, descendant:GetFullName()))
			end
		end
	end
	return isValid
end

function PlayerService:_applyLauncherVisual(pawn: Model, launcherId: string): boolean
	local hitbox = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox", true)
	if not (hitbox and hitbox:IsA("BasePart")) then
		return false
	end
	pawn.PrimaryPart = hitbox

	local launcherModel = self:_resolveLauncherModelSource(launcherId)
	if not launcherModel then
		warn(string.format("[PLAYER_SERVICE] Launcher model missing for %s", launcherId))
		return false
	end

	local sourceRoot = self:_resolveLauncherVisualRoot(launcherModel)
	if not sourceRoot then
		warn(string.format("[PLAYER_SERVICE] Launcher model %s has no RootPart/PrimaryPart", launcherId))
		return false
	end

	local existingEquipped = self:_findEquippedLauncherModel(pawn)
	local oldRoot = existingEquipped and (existingEquipped.PrimaryPart or existingEquipped:FindFirstChild(LAUNCHER_ROOT_PART_NAME))
	local targetCFrame = if oldRoot and oldRoot:IsA("BasePart") then oldRoot.CFrame else hitbox.CFrame
	local equipped = self:_cloneEquippedLauncherModel(pawn, launcherModel)
	local visualRoot = self:_resolveLauncherVisualRoot(equipped)
	if not visualRoot then
		warn(string.format("[PLAYER_SERVICE] Cloned launcher model %s has no RootPart/PrimaryPart", launcherId))
		return false
	end
	visualRoot.Name = LAUNCHER_ROOT_PART_NAME
	equipped.PrimaryPart = visualRoot
	equipped:PivotTo(targetCFrame)
	self:_configureVisualRig(equipped)
	self:_validateLauncherMotor6Ds(equipped, launcherId)
	equipped:SetAttribute("LauncherId", launcherId)
	pawn:SetAttribute("LauncherId", launcherId)
	self:_updateHitboxRootPartWeld(pawn, hitbox, visualRoot)
	return true
end


function PlayerService:_resolveEquipmentModelSource(equipmentId: string): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local equipmentFolder = assetsFolder and assetsFolder:FindFirstChild("Equipment")
	local equipmentModel = equipmentFolder and equipmentFolder:FindFirstChild(equipmentId)
	if equipmentModel and equipmentModel:IsA("Model") then return equipmentModel end
	return nil
end

function PlayerService:_findEquipmentModel(pawn: Model, slot: number): Model?
	local model = pawn:FindFirstChild("EquippedEquipmentSlot" .. tostring(slot))
	return if model and model:IsA("Model") then model else nil
end

function PlayerService:UnequipEquipmentModel(player: Player, slot: number): boolean
	local pawn = self:GetPawn(player)
	if not pawn then return false end
	local existing = self:_findEquipmentModel(pawn, slot)
	if existing then existing:Destroy() end
	return true
end

function PlayerService:_resolveEquipmentAttachment(hitbox: BasePart, slot: number): (Attachment?, string?)
	local slotAttachment = hitbox:FindFirstChild("EquipmentSlot" .. tostring(slot), true)
	if slotAttachment and slotAttachment:IsA("Attachment") then
		return slotAttachment, slotAttachment.Name
	end
	return nil, nil
end

function PlayerService:EquipEquipmentModel(player: Player, slot: number, equipmentId: string): boolean
	if type(slot) ~= "number" or slot < 1 or slot > 3 then return false end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not (stateService and stateService:IsLauncher(player)) then
		self:UnequipEquipmentModel(player, slot)
		return false
	end
	local pawn = self:GetPawn(player)
	if not pawn then return false end
	local hitbox = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox", true)
	if not (hitbox and hitbox:IsA("BasePart")) then return false end
	local modelTemplate = self:_resolveEquipmentModelSource(equipmentId)
	if not modelTemplate then
		warn(string.format("[PLAYER_SERVICE] Equipment model missing for %s", equipmentId))
		return false
	end
	self:UnequipEquipmentModel(player, slot)
	local model = modelTemplate:Clone()
	model.Name = "EquippedEquipmentSlot" .. tostring(slot)
	model.Parent = pawn
	local root = model:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then
		warn(string.format("[PLAYER_SERVICE] Equipment model %s must contain one BasePart child named Root", equipmentId))
		model:Destroy()
		return false
	end
	local attachment, attachName = self:_resolveEquipmentAttachment(hitbox, slot)
	if not attachment then
		warn(string.format("[PLAYER_SERVICE] Launcher Hitbox.EquipmentSlot%d attachment missing; create it in ReplicatedStorage.Assets.Launchers.Player.Hitbox.", slot))
		model:Destroy()
		return false
	end
	model.PrimaryPart = root
	model:PivotTo(attachment.WorldCFrame)
	self:_configureVisualRig(model)
	local weld = Instance.new("WeldConstraint")
	weld.Name = "WeldConstraint_EquipmentSlot" .. tostring(slot)
	weld.Part0 = hitbox
	weld.Part1 = root
	weld.Parent = model
	model:SetAttribute("EquipmentId", equipmentId)
	model:SetAttribute("EquipmentSlot", slot)
	model:SetAttribute("EquipmentAttachPoint", attachName)
	return true
end

function PlayerService:RefreshEquipmentModels(player: Player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not (stateService and stateService:IsLauncher(player)) then
		for slot = 1, 3 do self:UnequipEquipmentModel(player, slot) end
		return
	end
	local dataService = ServiceResolver.Get(self._context, "PlayerDataService")
	if not dataService then return end
	local owned = dataService:GetOwnedEquipment(player)
	local equipped = dataService:GetEquippedEquipment(player)
	for slot = 1, 3 do
		local instanceId = equipped[slot]
		local instance = instanceId and owned[instanceId]
		if type(instance) == "table" and type(instance.definitionId) == "string" then
			self:EquipEquipmentModel(player, slot, instance.definitionId)
		else
			self:UnequipEquipmentModel(player, slot)
		end
	end
end

function PlayerService:_prepareLauncherModel(model: Model): BasePart?
	local root = model:FindFirstChild("Hitbox", true) :: BasePart?
	if not root then
		root = model.PrimaryPart
	end
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	model.PrimaryPart = root
	root.Massless = false

	-- Status VFX are pre-placed under Hitbox attachments; keep them disabled until flags enable them.
	setPreplacedStatusEffectsEnabled(root, false)

	local attachment = root:FindFirstChild("LauncherMovementAttachment") or root:FindFirstChild("AttachmentOrientation") or root:FindFirstChild("Attachment")
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	local alignOrientation = root:FindFirstChild("AlignOrientation")
	local body = model:FindFirstChild("Body", true)
	local bodyWeld = model:FindFirstChild("BodyWeld", true)
	local attachments = model:FindFirstChild("Attachments")
	local trail = model:FindFirstChild("Trail")

	if attachment and attachment:IsA("Attachment") then
		if linearVelocity and linearVelocity:IsA("LinearVelocity") then
			linearVelocity.Attachment0 = attachment
			linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			linearVelocity.Enabled = false
		end
		if alignOrientation and alignOrientation:IsA("AlignOrientation") then
			alignOrientation.Attachment0 = attachment
			alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
			alignOrientation.RigidityEnabled = false
			alignOrientation.MaxTorque = math.huge
			alignOrientation.Responsiveness = 20
		end
	end

	if trail and trail:IsA("Trail") then
		local trailStart = (attachments and attachments:FindFirstChild("TrailStart")) or root:FindFirstChild("TrailStart")
		local trailEnd = (attachments and attachments:FindFirstChild("TrailEnd")) or root:FindFirstChild("TrailEnd")
		if trailStart and trailStart:IsA("Attachment") then
			trail.Attachment0 = trailStart
		end
		if trailEnd and trailEnd:IsA("Attachment") then
			trail.Attachment1 = trailEnd
		end
	end

	root.CustomPhysicalProperties = PhysicalProperties.new(
		PhysicsConfig.PhysicalProperties.Density,
		PhysicsConfig.PhysicalProperties.Friction,
		PhysicsConfig.PhysicalProperties.Elasticity,
		PhysicsConfig.PhysicalProperties.FrictionWeight,
		PhysicsConfig.PhysicalProperties.ElasticityWeight
	)
	if body and body:IsA("BasePart") then
		body.CustomPhysicalProperties = root.CustomPhysicalProperties
	end
	if bodyWeld and bodyWeld:IsA("WeldConstraint") and body and body:IsA("BasePart") then
		bodyWeld.Part0 = root
		bodyWeld.Part1 = body
	end

	return root
end

function PlayerService:_loadLauncherTemplate(): Model?
	if self._launcherTemplate then
		return self._launcherTemplate
	end

	local playerModel = self:_resolvePlayerModelSource()
	if not playerModel then
		warn("[PLAYER_SERVICE] ReplicatedStorage/Assets/Launchers/Player missing. Pawn spawn aborted.")
		return nil
	end

	local template = playerModel:Clone()
	template.Name = PLAYER_CHARACTER_MODEL_NAME
	template.Parent = nil

	if LauncherConfig.ModelScale ~= 1 then
		template:ScaleTo(LauncherConfig.ModelScale)
	end

	if not self:_prepareLauncherModel(template) then
		warn("[PLAYER_SERVICE] Player model has no PrimaryPart/Hitbox. Pawn spawn aborted.")
		return nil
	end
	self:_applyLauncherVisual(template, LauncherConfig.DefaultLauncherId)

	self._launcherTemplate = template
	return template
end

function PlayerService:GetPawn(player)
	local mapped = self._playerToLauncher[player]
	if mapped and mapped.Parent then
		return mapped
	end
	local byName = self._pawnsFolder:FindFirstChild(player.Name .. "_Pawn")
	if byName and byName:IsA("Model") then
		self._playerToLauncher[player] = byName
		self._launcherToPlayer[byName] = player
		return byName
	end
	return nil
end

function PlayerService:GetPlayerFromPawn(pawn: Model): Player?
	local mapped = self._launcherToPlayer[pawn]
	if mapped and mapped.Parent == Players then
		return mapped
	end
	for player, playerPawn in pairs(self._playerToLauncher) do
		if playerPawn == pawn and player.Parent == Players then
			self._launcherToPlayer[pawn] = player
			return player
		end
	end
	return nil
end

function PlayerService:IsAlive(player)
	local state = ServiceResolver.Get(self._context, "PlayerStateService"):GetState(player)
	return state ~= nil and state.IsAlive
end

function PlayerService:_disconnectDeathSignal(player)
	local connection = self._deathConnections[player]
	if connection then
		connection:Disconnect()
		self._deathConnections[player] = nil
	end
end


function PlayerService:SwitchPlayerModeInLobby(player: Player, modeName: string): boolean
	if modeName ~= GameStates.PlayerMode.Launcher and modeName ~= GameStates.PlayerMode.Human then
		return false
	end

	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player) or nil
	if not state or state.LocationState ~= GameStates.SessionState.Lobby then
		if stateService then
			stateService:PublishState(player)
		end
		return false
	end

	if not stateService:SetSelectedPlayerMode(player, modeName) then
		return false
	end

	local launcherService = ServiceResolver.Get(self._context, "LauncherService")
	if modeName == GameStates.PlayerMode.Human and launcherService and typeof(launcherService.ResetPlayerRuntime) == "function" then
		launcherService:ResetPlayerRuntime(player)
	end

	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	local character = player.Character
	if character then
		player.Character = nil
		character:Destroy()
	end

	if modeName == GameStates.PlayerMode.Human then
		return self:SpawnHumanCharacter(player, 1, "LobbyMap") ~= nil
	end
	return self:SpawnPawn(player, 1, "LobbyMap") ~= nil
end

function PlayerService:SpawnForActiveMode(player: Player, spawnIndex: number?, mapName: string?, modeName: string?)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local resolvedMode = modeName or (stateService and stateService:GetActivePlayerMode(player)) or GameStates.PlayerMode.Launcher
	if resolvedMode == GameStates.PlayerMode.Human then
		return self:SpawnHumanCharacter(player, spawnIndex, mapName)
	end
	return self:SpawnPawn(player, spawnIndex, mapName)
end

function PlayerService:RespawnCurrentMode(player: Player, spawnIndex: number?, mapName: string?)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local state = stateService and stateService:GetState(player) or nil
	local modeName = (state and state.ActivePlayerMode) or GameStates.PlayerMode.Human
	return self:SpawnForActiveMode(player, spawnIndex, mapName or (state and state.CurrentMap) or "LobbyMap", modeName)
end

function PlayerService:RespawnAfterDelay(player: Player, delaySeconds: number?, spawnIndex: number?, mapName: string?)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local expectedMode = (stateService and stateService:GetActivePlayerMode(player)) or GameStates.PlayerMode.Human
	task.delay(delaySeconds or 3, function()
		if player.Parent ~= Players then
			return
		end
		local state = stateService and stateService:GetState(player) or nil
		local respawnMap = mapName or (state and state.CurrentMap) or ServiceResolver.Get(self._context, "MapService"):GetActiveMap() or "LobbyMap"
		local modeName = (state and state.ActivePlayerMode) or expectedMode
		self:SpawnForActiveMode(player, spawnIndex, respawnMap, modeName)
	end)
end

function PlayerService:_waitForLoadedCharacter(player: Player): Model?
	local previousCharacter = player.Character
	local characterAdded = player.CharacterAdded
	player:LoadCharacter()

	local character = player.Character
	if character and character ~= previousCharacter and character:IsA("Model") then
		return character
	end

	character = characterAdded:Wait()
	if character and character:IsA("Model") then
		return character
	end
	return nil
end

function PlayerService:_waitForHumanoidCharacterParts(character: Model): (Humanoid?, BasePart?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local foundHumanoid = character:WaitForChild("Humanoid")
		humanoid = if foundHumanoid and foundHumanoid:IsA("Humanoid") then foundHumanoid else nil
	end

	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not root then
		local foundRoot = character:WaitForChild("HumanoidRootPart")
		root = if foundRoot and foundRoot:IsA("BasePart") then foundRoot else character.PrimaryPart
	end

	return humanoid, if root and root:IsA("BasePart") then root else nil
end

function PlayerService:SpawnHumanCharacter(player: Player, spawnIndex: number?, mapName: string?)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	local launcherService = ServiceResolver.Get(self._context, "LauncherService")
	if launcherService and typeof(launcherService.ResetPlayerRuntime) == "function" then
		launcherService:ResetPlayerRuntime(player)
	end
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService then
		stateService:SetActivePlayerMode(player, GameStates.PlayerMode.Human, nil, false)
	end

	local character = self:_waitForLoadedCharacter(player)
	if not character then
		return nil
	end

	local humanoid, root = self:_waitForHumanoidCharacterParts(character)
	if humanoid then
		self._deathConnections[player] = humanoid.Died:Connect(function()
			local damageService = ServiceResolver.Get(self._context, "DamagePipelineService")
			if damageService then
				damageService:HandlePlayerDeath(player)
			end
		end)
	end

	local mapService = ServiceResolver.Get(self._context, "MapService")
	if root and mapService then
		local playerState = stateService and stateService:GetState(player) or nil
		local teamId = playerState and playerState.TeamId or nil
		local index = spawnIndex or (player.UserId % 8) + 1
		local spawnCFrame = CFrame.new(mapService:GetSpawnPoint(index, mapName))
		if type(mapService.GetSpawnCFrame) == "function" then
			spawnCFrame = mapService:GetSpawnCFrame(index, mapName, teamId)
		end
		character:PivotTo(spawnCFrame)
	end
	if stateService then
		stateService:SetAlive(player, true)
	end
	return character
end

function PlayerService:_destroyLauncherAnimationController(pawn: Model?)
	if not pawn then
		return
	end
	local controller = self._animationControllers[pawn]
	if controller then
		controller:Destroy()
		self._animationControllers[pawn] = nil
	end
end

function PlayerService:_initializeLauncherAnimations(player: Player, pawn: Model)
	self:_destroyLauncherAnimationController(pawn)
	local equipped = self:_findEquippedLauncherModel(pawn)
	if not equipped then
		return
	end
	self._animationControllers[pawn] = LauncherAnimationController.new(pawn, equipped)
	local state = ServiceResolver.Get(self._context, "PlayerStateService"):GetState(player)
	if state then
		self._animationControllers[pawn]:ApplyState(state)
	end
end

function PlayerService:_updateLauncherAnimations(player: Player, state)
	local pawn = self:GetPawn(player)
	if not pawn then
		return
	end
	local controller = self._animationControllers[pawn]
	if not controller then
		self:_initializeLauncherAnimations(player, pawn)
		controller = self._animationControllers[pawn]
	end
	if controller then
		controller:ApplyState(state)
	end
end

function PlayerService:SpawnPawn(player, spawnIndex: number?, mapName: string?)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	local existingCharacter = player.Character
	if existingCharacter then
		player.Character = nil
		existingCharacter:Destroy()
	end
	local stateServiceForMode = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateServiceForMode then
		stateServiceForMode:SetActivePlayerMode(player, GameStates.PlayerMode.Launcher)
	end

	local template = self:_loadLauncherTemplate()
	if not template then
		return nil
	end
	local pawn = template:Clone()
	pawn.Name = player.Name .. "_Pawn"
	local playerState = ServiceResolver.Get(self._context, "PlayerStateService"):GetState(player)
	local currentLauncherId = LauncherConfig.DefaultLauncherId
	if playerState and LauncherConfig.GetById(playerState.LaunchershotType or "") then
		currentLauncherId = playerState.LaunchershotType
	end
	pawn:SetAttribute("LauncherId", currentLauncherId)
	if not pawn.PrimaryPart then
		local root = pawn:FindFirstChild("Hitbox", true)
		if root and root:IsA("BasePart") then
			pawn.PrimaryPart = root
		end
	end
	if not pawn.PrimaryPart then
		warn("[PLAYER_SERVICE] Player clone missing PrimaryPart. Pawn spawn aborted.")
		return nil
	end
	pawn.PrimaryPart.Massless = false
	local index = spawnIndex or (player.UserId % 8) + 1
	self:_applyLauncherVisual(pawn, currentLauncherId)
	local mapService = ServiceResolver.Get(self._context, "MapService")
	local teamId = playerState and playerState.TeamId or nil
	local spawnCFrame = CFrame.new(mapService:GetSpawnPoint(index, mapName))
	if type(mapService.GetSpawnCFrame) == "function" then
		spawnCFrame = mapService:GetSpawnCFrame(index, mapName, teamId)
	end
	pawn:PivotTo(spawnCFrame)
	pawn.Parent = self._pawnsFolder
	player.Character = pawn
	setPreplacedStatusEffectsEnabled(pawn.PrimaryPart, false)
	pawn.PrimaryPart.Massless = false
	pawn.PrimaryPart:SetNetworkOwner(player)
	self._playerToLauncher[player] = pawn
	self._launcherToPlayer[pawn] = player
	self:RefreshEquipmentModels(player)
	self:_attachWorldUi(pawn, player)
	self:_initializeLauncherAnimations(player, pawn)
	pawn:SetAttribute("ScaleValue", LauncherConfig.ModelScale)
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		elseif descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end

	ServiceResolver.Get(self._context, "PlayerStateService"):ResetForRespawn(player)
	local state = ServiceResolver.Get(self._context, "PlayerStateService"):GetState(player)
	if state then
		self:_updateWorldUi(player, state)
	end

	return pawn
end

function PlayerService:EquipLauncherModel(player: Player, launcherId: string): boolean
	if not LauncherConfig.GetById(launcherId) then
		return false
	end

	local pawn = self:GetPawn(player)
	if not pawn then
		return false
	end

	local root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox", true)
	if not (root and root:IsA("BasePart")) then
		warn(string.format("[PLAYER_SERVICE] Player pawn missing Hitbox for %s", player.Name))
		return false
	end
	pawn.PrimaryPart = root

	if not self:_applyLauncherVisual(pawn, launcherId) then
		return false
	end
	self:_initializeLauncherAnimations(player, pawn)

	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not (stateService and stateService:IsHuman(player)) then
		player.Character = pawn
	end
	root:SetNetworkOwner(player)

	local state = stateService and stateService:GetState(player) or nil
	if state then
		self:_updateWorldUi(player, state)
	end
	return true
end

function PlayerService:DespawnPawn(player)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	ServiceResolver.Get(self._context, "PlayerStateService"):SetAlive(player, false)
end

function PlayerService:_destroyPawn(player)
	local pawn = self:GetPawn(player)
	if pawn then
		self:_destroyLauncherAnimationController(pawn)
		self._launcherToPlayer[pawn] = nil
		pawn:Destroy()
	end
	self._playerToLauncher[player] = nil
end

function PlayerService:IsGrounded(player): boolean
	local root = self:GetRoot(player)
	if not root then
		return false
	end
	local result = Workspace:Raycast(root.Position, Vector3.new(0, -4, 0))
	return result ~= nil
end

function PlayerService:GetRoot(player)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if stateService and stateService:IsHuman(player) then
		local character = player.Character
		local root = character and (character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart)
		return if root and root:IsA("BasePart") then root else nil
	end
	local pawn = self:GetPawn(player)
	if not pawn then
		return nil
	end
	local root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox", true)
	if root and root:IsA("BasePart") then
		if pawn.PrimaryPart == nil then
			pawn.PrimaryPart = root
		end
		if root.Name ~= "Hitbox" then
			warn(string.format("[PlayerService] PrimaryPart is not Hitbox for %s (%s)", player.Name, root:GetFullName()))
		end
		return root
	end
	warn(string.format("[PlayerService] Missing PrimaryPart/Hitbox for %s", player.Name))
	return nil
end

function PlayerService:GrowPawn(player: Player, growthDelta: number)
	local pawn = self:GetPawn(player)
	if not pawn then
		return
	end
	local currentScale = pawn:GetAttribute("ScaleValue")
	if typeof(currentScale) ~= "number" then
		currentScale = pawn:GetScale()
	end
	local newScale = math.max(0.5, currentScale + math.max(0, growthDelta))
	pawn:SetAttribute("ScaleValue", newScale)
	pawn:ScaleTo(newScale)
end

function PlayerService:TeleportCharacterToSpawn(player: Player, spawn: BasePart?): boolean
	if not spawn then
		return false
	end
	local model = self:GetPawn(player) or player.Character
	if not (model and model:IsA("Model")) then
		return false
	end
	model:PivotTo(spawn.CFrame)
	return true
end

return PlayerService
