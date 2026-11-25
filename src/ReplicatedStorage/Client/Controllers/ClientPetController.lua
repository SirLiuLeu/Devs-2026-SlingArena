--!strict

-- Pet visuals are cloned locally. Nearby players' equipped-pet metadata comes from
-- replicated Player attributes; pet positions are derived from already-replicated pawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetAnimationConfig = require(ReplicatedStorage.Shared.Config.PetAnimationConfig)
local PetRenderConfig = require(ReplicatedStorage.Shared.Config.PetRenderConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)
local PetVisualSignal = require(ReplicatedStorage.Shared.Utils.PetVisualSignal)

local ClientPetController = {}
ClientPetController.__index = ClientPetController

local RENDER_FOLDER_NAME = "ClientPetRender"
local ROOT_PART_NAME = "RootPart"
local FOLLOW_DISTANCE = 6
local FOLLOW_HEIGHT = 1
local SLOT_SPACING = 3
local FOLLOW_LERP_SPEED = 10
local BOB_HEIGHT = 0.35
local BOB_SPEED = 2.5
local SWAY_DISTANCE = 0.3
local SWAY_SPEED = 1.75
local SNAP_DISTANCE = 60
local RUN_SPEED_THRESHOLD = 1.5

type RenderedPet = {
	instanceId: string,
	abilityId: string,
	model: Model,
	transparencies: { [Instance]: number },
	visible: boolean,
	tracks: { [string]: AnimationTrack },
	locomotionState: string?,
	activeAction: string?,
	isMoving: boolean,
	actionStoppedConnection: RBXScriptConnection?,
}

type RenderedPlayerShield = {
	rootPart: BasePart,
	sphere: BasePart,
}

local function getOrCreateRenderFolder(): Folder
	local existing = Workspace:FindFirstChild(RENDER_FOLDER_NAME)
	if existing and existing:IsA("Folder") then return existing end
	local folder = Instance.new("Folder")
	folder.Name = RENDER_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function findOwnedPet(ownedPets: any, instanceId: string): any?
	if type(ownedPets) ~= "table" then return nil end
	local direct = ownedPets[instanceId]
	if type(direct) == "table" then return direct end
	for _, pet in pairs(ownedPets) do
		if type(pet) == "table" and tostring(pet.instanceId or "") == instanceId then return pet end
	end
	return nil
end

local function getAbilityId(ownedPet: any, instanceId: string): string?
	if type(ownedPet) == "table" then
		local abilityId = ownedPet.abilityId
		if type(abilityId) == "string" and abilityId ~= "" then return abilityId end
	end
	return nil
end

local function prepareModel(model: Model): { [Instance]: number }?
	local rootPart = model:FindFirstChild(ROOT_PART_NAME, true)
	if not rootPart or not rootPart:IsA("BasePart") then
		warn(string.format("[CLIENT_PET] %s is missing its required %s BasePart", model.Name, ROOT_PART_NAME))
		return nil
	end
	model.PrimaryPart = rootPart
	local motorNeighbors: { [BasePart]: { BasePart } } = {}
	local function addMotorConnection(part0: BasePart?, part1: BasePart?)
		if not part0 or not part1 then return end
		motorNeighbors[part0] = motorNeighbors[part0] or {}
		motorNeighbors[part1] = motorNeighbors[part1] or {}
		table.insert(motorNeighbors[part0], part1)
		table.insert(motorNeighbors[part1], part0)
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("JointInstance") or descendant:IsA("WeldConstraint") then
			local joint = descendant :: any
			addMotorConnection(joint.Part0, joint.Part1)
		elseif descendant:IsA("RigidConstraint") then
			local attachment0 = descendant.Attachment0
			local attachment1 = descendant.Attachment1
			local part0 = attachment0 and attachment0.Parent
			local part1 = attachment1 and attachment1.Parent
			addMotorConnection(
				if part0 and part0:IsA("BasePart") then part0 else nil,
				if part1 and part1:IsA("BasePart") then part1 else nil
			)
		end
	end
	local articulatedParts: { [BasePart]: boolean } = { [rootPart] = true }
	local pendingParts = { rootPart }
	local pendingIndex = 1
	while pendingIndex <= #pendingParts do
		local currentPart = pendingParts[pendingIndex] :: BasePart
		pendingIndex += 1
		for _, connectedPart in ipairs(motorNeighbors[currentPart] or {}) do
			if not articulatedParts[connectedPart] then
				articulatedParts[connectedPart] = true
				table.insert(pendingParts, connectedPart)
			end
		end
	end

	local transparencies = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant ~= rootPart then transparencies[descendant] = descendant.Transparency end
			-- Anchor the root, but let Motor6D-connected body parts move with animation.
			-- Static decorative parts remain anchored so they cannot fall away.
			descendant.Anchored = not articulatedParts[descendant] or descendant == rootPart
			if descendant ~= rootPart and not descendant.Anchored then
				descendant.Massless = true
			end
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			transparencies[descendant] = descendant.Transparency
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	rootPart.Transparency = 1
	return transparencies
end

local function attachSphere(
	model: Model,
	rootPart: BasePart,
	prefab: BasePart?,
	instanceName: string,
	transparencies: { [Instance]: number }
): (BasePart?, number?)
	if not prefab then return nil, nil end

	local sphere = prefab:Clone()
	sphere.Name = instanceName
	sphere.CFrame = rootPart.CFrame
	sphere.Anchored = false
	sphere.Massless = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.CastShadow = false
	sphere.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Name = instanceName .. "Weld"
	weld.Part0 = rootPart
	weld.Part1 = sphere
	weld.Parent = sphere

	local authoredTransparency = sphere.Transparency
	transparencies[sphere] = authoredTransparency
	return sphere, authoredTransparency
end

local function normalizeAnimationId(value: any): string?
	if type(value) ~= "string" then return nil end
	local trimmed = string.gsub(value, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then return nil end
	if string.match(trimmed, "^%d+$") then return "rbxassetid://" .. trimmed end
	return trimmed
end

local function getPetTrackPriority(name: string): Enum.AnimationPriority
	if name == "Idle" then return Enum.AnimationPriority.Idle end
	if name == "Run" then return Enum.AnimationPriority.Movement end
	if name == "Cast" then return Enum.AnimationPriority.Action end
	return Enum.AnimationPriority.Action2
end

local function loadPetAnimationTracks(model: Model, abilityId: string): { [string]: AnimationTrack }
	local animationSet = PetAnimationConfig.GetByAbilityId(abilityId)
	local animatorParent: Instance? = model:FindFirstChildOfClass("Humanoid")
	if not animatorParent then
		animatorParent = model:FindFirstChildOfClass("AnimationController")
	end
	local configuredIds: { [string]: string? } = {
		Idle = animationSet.Idle,
		Run = animationSet.Run,
		Cast = animationSet.Cast,
		Dance = animationSet.Dance,
	}
	local animationNames = { "Idle", "Run", "Cast", "Dance" }
	local hasConfiguredAnimation = false
	for _, name in ipairs(animationNames) do
		if normalizeAnimationId(configuredIds[name]) then
			hasConfiguredAnimation = true
			break
		end
	end
	if not hasConfiguredAnimation then return {} end

	if not animatorParent then
		local controller = Instance.new("AnimationController")
		controller.Name = "PetAnimationController"
		controller.Parent = model
		animatorParent = controller
	end
	local animator = animatorParent:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animatorParent
	end

	local tracks: { [string]: AnimationTrack } = {}
	for _, name in ipairs(animationNames) do
		local animationId = normalizeAnimationId(configuredIds[name])
		if animationId then
			local animation = Instance.new("Animation")
			animation.Name = "Pet" .. name .. "Animation"
			animation.AnimationId = animationId
			local ok, trackOrError = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			animation:Destroy()
			if ok and trackOrError then
				local track = trackOrError :: AnimationTrack
				track.Name = "Pet" .. name
				track.Looped = name == "Idle" or name == "Run"
				track.Priority = getPetTrackPriority(name)
				tracks[name] = track
			else
				warn(string.format("[CLIENT_PET_ANIMATION] Failed to load %s for %s: %s", name, abilityId, tostring(trackOrError)))
			end
		end
	end
	return tracks
end

local function playPetLocomotion(rendered: RenderedPet)
	if rendered.activeAction then return end
	local stateName = if rendered.isMoving then "Run" else "Idle"
	local targetTrack = rendered.tracks[stateName]
	if rendered.locomotionState == stateName then
		if targetTrack and not targetTrack.IsPlaying then targetTrack:Play(0.12) end
		return
	end
	for _, name in ipairs({ "Idle", "Run" }) do
		local track = rendered.tracks[name]
		if name ~= stateName and track and track.IsPlaying then track:Stop(0.12) end
	end
	rendered.locomotionState = stateName
	if targetTrack and not targetTrack.IsPlaying then targetTrack:Play(0.12) end
end

local function stopPetAction(rendered: RenderedPet)
	if rendered.actionStoppedConnection then
		rendered.actionStoppedConnection:Disconnect()
		rendered.actionStoppedConnection = nil
	end
	local activeAction = rendered.activeAction
	if activeAction then
		local track = rendered.tracks[activeAction]
		if track and track.IsPlaying then track:Stop(0.08) end
	end
	rendered.activeAction = nil
end

local function playPetAction(rendered: RenderedPet, actionName: string)
	local targetTrack = rendered.tracks[actionName]
	if not targetTrack then return end
	if rendered.activeAction == actionName and targetTrack.IsPlaying then return end
	local actionPriority = { Cast = 1, Dance = 2 }
	local currentPriority = actionPriority[rendered.activeAction or ""] or 0
	local requestedPriority = actionPriority[actionName] or 0
	if currentPriority > requestedPriority then return end

	stopPetAction(rendered)
	for _, name in ipairs({ "Idle", "Run" }) do
		local track = rendered.tracks[name]
		if track and track.IsPlaying then track:Stop(0.12) end
	end
	rendered.locomotionState = nil
	rendered.activeAction = actionName
	if targetTrack.IsPlaying then targetTrack:Stop(0) end
	targetTrack.TimePosition = 0
	targetTrack:Play(0.1)
	rendered.actionStoppedConnection = targetTrack.Stopped:Connect(function()
		if rendered.activeAction ~= actionName then return end
		rendered.activeAction = nil
		rendered.locomotionState = nil
		if rendered.actionStoppedConnection then
			rendered.actionStoppedConnection:Disconnect()
			rendered.actionStoppedConnection = nil
		end
		playPetLocomotion(rendered)
	end)
end

local function destroyPetTracks(rendered: RenderedPet)
	stopPetAction(rendered)
	for _, track in pairs(rendered.tracks) do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(rendered.tracks)
end

local function setModelVisible(rendered: RenderedPet, visible: boolean)
	if rendered.visible == visible then return end
	rendered.visible = visible
	for instance, authoredTransparency in pairs(rendered.transparencies) do
		if instance.Parent ~= nil then
			if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
				instance.Transparency = if visible then authoredTransparency else 1
			end
		end
	end
	local rootPart = rendered.model.PrimaryPart
	if rootPart then rootPart.Transparency = 1 end
end

function ClientPetController.new(player: Player)
	local self = setmetatable({}, ClientPetController)
	self._player = player
	local assets = ReplicatedStorage:WaitForChild("Assets")
	self._assets = assets:WaitForChild("Pets")
	self._prefabs = assets:FindFirstChild("Prefabs")
	self._raritySpheres = self._prefabs and self._prefabs:FindFirstChild("RaritySpheres") or nil
	self._missingSpherePrefabs = {}
	self._renderFolder = getOrCreateRenderFolder()
	self._renderedPets = {} :: { [Player]: { [number]: RenderedPet } }
	self._renderedShields = {} :: { [Player]: RenderedPlayerShield }
	self._ownerNear = {} :: { [Player]: boolean }
	self._ownerLastPositions = {} :: { [Player]: Vector3 }
	self._ownerConnections = {} :: { [Player]: { RBXScriptConnection } }
	self._connections = {} :: { RBXScriptConnection }
	self._localOwnedPets = nil
	self._localEquippedPets = nil
	self._hasLocalState = false
	self._rangeCheckElapsed = 0
	self._failedModels = {}
	self._started = false
	return self
end

function ClientPetController:_getRoot(player: Player): BasePart?
	local pawn = PawnLocator.GetPawnByPlayer(player)
	return PawnLocator.GetRootPart(pawn)
end

function ClientPetController:_isOwnerNearLocalPlayer(owner: Player): boolean
	if owner == self._player then
		self._ownerNear[owner] = true
		return true
	end
	if owner.Parent ~= Players then
		self._ownerNear[owner] = false
		return false
	end
	local localRoot = self:_getRoot(self._player)
	local ownerRoot = self:_getRoot(owner)
	if not localRoot or not ownerRoot then
		self._ownerNear[owner] = false
		return false
	end
	local wasNear = self._ownerNear[owner] == true
	local exitDistance = PetRenderConfig.NearbyRenderDistance + PetRenderConfig.NearbyRenderHysteresis
	local threshold = if wasNear then exitDistance else PetRenderConfig.NearbyRenderDistance
	local near = (localRoot.Position - ownerRoot.Position).Magnitude <= threshold
	self._ownerNear[owner] = near
	return near
end

function ClientPetController:_getDesiredPet(owner: Player, slot: number): (string?, string?)
	if owner == self._player and self._hasLocalState then
		local equippedPets = self._localEquippedPets
		local ownedPets = self._localOwnedPets
		local instanceValue = if type(equippedPets) == "table" then (equippedPets[slot] or equippedPets[tostring(slot)]) else nil
		if instanceValue == nil then return nil, nil end
		local instanceId = tostring(instanceValue)
		local ownedPet = findOwnedPet(ownedPets, instanceId)
		local abilityId = getAbilityId(ownedPet, instanceId)
		return instanceId, abilityId
	end

	local instanceId = owner:GetAttribute(string.format("EquippedPetSlot%dInstanceId", slot))
	local abilityId = owner:GetAttribute(string.format("EquippedPetSlot%dAbilityId", slot))
	if type(instanceId) ~= "string" or instanceId == "" or type(abilityId) ~= "string" or abilityId == "" then
		return nil, nil
	end
	return instanceId, abilityId
end

function ClientPetController:_destroyPet(owner: Player, slot: number)
	local ownerPets = self._renderedPets[owner]
	local rendered = ownerPets and ownerPets[slot]
	if rendered then
		destroyPetTracks(rendered)
		rendered.model:Destroy()
		ownerPets[slot] = nil
	end
end

function ClientPetController:_destroyOwnerShield(owner: Player)
	local renderedShield = self._renderedShields[owner]
	if renderedShield then
		if renderedShield.sphere.Parent then
			renderedShield.sphere:Destroy()
		end
		self._renderedShields[owner] = nil
	end
end

function ClientPetController:_reconcileOwnerShield(owner: Player)
	local isShieldActive = owner:GetAttribute("PetAbsorbShieldActive") == true
	if not isShieldActive or owner.Parent ~= Players or not self:_isOwnerNearLocalPlayer(owner) then
		self:_destroyOwnerShield(owner)
		return
	end

	local rootPart = self:_getRoot(owner)
	if not rootPart or rootPart.Parent == nil then
		self:_destroyOwnerShield(owner)
		return
	end

	local current = self._renderedShields[owner]
	if current and current.rootPart == rootPart and current.sphere.Parent then
		return
	end
	self:_destroyOwnerShield(owner)

	local shieldPrefab = self._prefabs and self._prefabs:FindFirstChild("ShieldSphere")
	if not shieldPrefab or not shieldPrefab:IsA("BasePart") then
		if not self._missingSpherePrefabs.ShieldSphere then
			warn("[CLIENT_PET_VISUAL] Missing BasePart prefab Assets.Prefabs.ShieldSphere")
			self._missingSpherePrefabs.ShieldSphere = true
		end
		return
	end

	local sphere = shieldPrefab:Clone()
	sphere.Name = string.format("PlayerShieldSphere_%d", owner.UserId)
	sphere.CFrame = rootPart.CFrame
	sphere.Anchored = false
	sphere.Massless = true
	sphere.CanCollide = false
	sphere.CanTouch = false
	sphere.CanQuery = false
	sphere.CastShadow = false
	sphere.Parent = self._renderFolder

	local weld = Instance.new("WeldConstraint")
	weld.Name = "PlayerShieldSphereWeld"
	weld.Part0 = rootPart
	weld.Part1 = sphere
	weld.Parent = sphere

	self._renderedShields[owner] = {
		rootPart = rootPart,
		sphere = sphere,
	}
end

function ClientPetController:_destroyOwnerModels(owner: Player)
	self:_destroyOwnerShield(owner)
	local ownerPets = self._renderedPets[owner]
	if ownerPets then
		local slots = {}
		for slot in pairs(ownerPets) do table.insert(slots, slot) end
		for _, slot in ipairs(slots) do self:_destroyPet(owner, slot) end
	end
	self._renderedPets[owner] = nil
end

function ClientPetController:_createPet(owner: Player, slot: number, instanceId: string, abilityId: string): RenderedPet?
	local definition = PetsConfig.GetByAbilityId(abilityId)
	if not definition then
		if not self._failedModels[abilityId] then
			warn(string.format("[CLIENT_PET] Unknown Pet AbilityID %q for player %s", abilityId, owner.Name))
			self._failedModels[abilityId] = true
		end
		return nil
	end
	local modelName = definition.modelName or abilityId
	local source = self._assets:FindFirstChild(modelName)
	if not source or not source:IsA("Model") then
		if not self._failedModels[abilityId] then
			warn(string.format("[CLIENT_PET] Missing pet model %q for equipped pet %q", modelName, instanceId))
			self._failedModels[abilityId] = true
		end
		return nil
	end
	local model = source:Clone()
	model.Name = string.format("Pet_%d_%d_%s", owner.UserId, slot, instanceId)
	local transparencies = prepareModel(model)
	if not transparencies then
		model:Destroy()
		return nil
	end

	local rootPart = model.PrimaryPart
	if not rootPart then
		warn(string.format("[CLIENT_PET] %s has no PrimaryPart after RootPart validation", model.Name))
		model:Destroy()
		return nil
	end

	local raritySphereName = tostring(definition.rarity or "") .. "Sphere"
	local rarityPrefab = self._raritySpheres and self._raritySpheres:FindFirstChild(raritySphereName)
	if rarityPrefab and rarityPrefab:IsA("BasePart") then
		attachSphere(model, rootPart, rarityPrefab, "RaritySphere", transparencies)
	elseif not self._missingSpherePrefabs[raritySphereName] then
		warn(string.format("[CLIENT_PET_VISUAL] Missing BasePart prefab Assets.Prefabs.RaritySpheres.%s", raritySphereName))
		self._missingSpherePrefabs[raritySphereName] = true
	end

	model.Parent = self._renderFolder
	local rendered: RenderedPet = {
		instanceId = instanceId,
		abilityId = abilityId,
		model = model,
		transparencies = transparencies,
		visible = true,
		tracks = loadPetAnimationTracks(model, abilityId),
		locomotionState = nil,
		activeAction = nil,
		isMoving = false,
		actionStoppedConnection = nil,
	}
	playPetLocomotion(rendered)
	return rendered
end

function ClientPetController:_reconcileOwner(owner: Player)
	if owner.Parent ~= Players then
		self:_destroyOwnerModels(owner)
		return
	end
	if not self:_isOwnerNearLocalPlayer(owner) then
		self:_destroyOwnerModels(owner)
		return
	end

	self:_reconcileOwnerShield(owner)
	self._renderedPets[owner] = self._renderedPets[owner] or {}
	for slot = 1, PetsConfig.EquippedSlotCount do
		local instanceId, abilityId = self:_getDesiredPet(owner, slot)
		local ownerPets = self._renderedPets[owner]
		local rendered = ownerPets and ownerPets[slot]
		if not instanceId or not abilityId then
			self:_destroyPet(owner, slot)
		elseif not rendered or rendered.instanceId ~= instanceId or rendered.abilityId ~= abilityId or rendered.model.Parent == nil then
			self:_destroyPet(owner, slot)
			local newRendered = self:_createPet(owner, slot, instanceId, abilityId)
			if newRendered then
				self._renderedPets[owner] = self._renderedPets[owner] or {}
				self._renderedPets[owner][slot] = newRendered
			end
		end
	end
	local ownerPets = self._renderedPets[owner]
	if ownerPets and next(ownerPets) == nil then self._renderedPets[owner] = nil end
end

function ClientPetController:ApplyState(state: any)
	if type(state) ~= "table" then return end
	if type(state.EquippedPets) == "table" and type(state.OwnedPets) == "table" then
		self._localOwnedPets = state.OwnedPets
		self._localEquippedPets = state.EquippedPets
		self._hasLocalState = true
	else
		self._localOwnedPets = nil
		self._localEquippedPets = nil
		self._hasLocalState = false
	end
	self:_reconcileOwner(self._player)
end

function ClientPetController:_watchPlayer(player: Player)
	if self._ownerConnections[player] then return end
	local connections = {}
	for slot = 1, PetsConfig.EquippedSlotCount do
		table.insert(connections, player:GetAttributeChangedSignal(string.format("EquippedPetSlot%dInstanceId", slot)):Connect(function()
			self:_reconcileOwner(player)
		end))
		table.insert(connections, player:GetAttributeChangedSignal(string.format("EquippedPetSlot%dDefinitionId", slot)):Connect(function()
			self:_reconcileOwner(player)
		end))
	end
	table.insert(connections, player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(function()
		self:_reconcileOwner(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("State"):Connect(function()
		self:_reconcileOwner(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal(PetVisualSignal.AttributeName):Connect(function()
		self:_playAbilityCast(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal(PetVisualSignal.DanceAttributeName):Connect(function()
		self:_playVictoryDance(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("PetAbsorbShieldActive"):Connect(function()
		self:_reconcileOwnerShield(player)
	end))
	table.insert(connections, player.CharacterAdded:Connect(function()
		self:_reconcileOwner(player)
	end))
	table.insert(connections, player.CharacterRemoving:Connect(function()
		self:_destroyOwnerShield(player)
		if player ~= self._player then self:_destroyOwnerModels(player) end
	end))
	self._ownerConnections[player] = connections
	self:_reconcileOwner(player)
end

function ClientPetController:_unwatchPlayer(player: Player)
	local connections = self._ownerConnections[player]
	if connections then
		for _, connection in ipairs(connections) do connection:Disconnect() end
		self._ownerConnections[player] = nil
	end
	self:_destroyOwnerModels(player)
	self._ownerNear[player] = nil
	self._ownerLastPositions[player] = nil
end


function ClientPetController:_playVictoryDance(owner: Player?)
	local danceOwner = owner or self._player
	local ownerPets = self._renderedPets[danceOwner]
	if not ownerPets then return end
	for _, rendered in pairs(ownerPets) do
		playPetAction(rendered, "Dance")
	end
end

function ClientPetController:_playAbilityCast(owner: Player)
	local abilityId = PetVisualSignal.DecodeCast(owner:GetAttribute(PetVisualSignal.AttributeName))
	if not abilityId then return end
	local ownerPets = self._renderedPets[owner]
	if not ownerPets then return end
	for _, rendered in pairs(ownerPets) do
		if rendered.abilityId == abilityId then
			playPetAction(rendered, "Cast")
		end
	end
end

function ClientPetController:_render(deltaTime: number)
	self._rangeCheckElapsed += deltaTime
	if self._rangeCheckElapsed >= PetRenderConfig.NearbyRangeCheckInterval then
		self._rangeCheckElapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do
			self:_reconcileOwner(player)
		end
	end

	local ownerIsMoving: { [Player]: boolean } = {}
	for owner in pairs(self._renderedPets) do
		local ownerRoot = self:_getRoot(owner)
		if ownerRoot then
			local position = ownerRoot.Position
			local previousPosition = self._ownerLastPositions[owner]
			if previousPosition then
				local delta = position - previousPosition
				local planarDelta = Vector3.new(delta.X, 0, delta.Z)
				local speed = planarDelta.Magnitude / math.max(deltaTime, 1 / 240)
				ownerIsMoving[owner] = planarDelta.Magnitude < SNAP_DISTANCE and speed >= RUN_SPEED_THRESHOLD
			else
				ownerIsMoving[owner] = false
			end
			self._ownerLastPositions[owner] = position
		else
			ownerIsMoving[owner] = false
			self._ownerLastPositions[owner] = nil
		end
	end

	local now = os.clock()
	local alpha = 1 - math.exp(-FOLLOW_LERP_SPEED * deltaTime)
	for owner, ownerPets in pairs(self._renderedPets) do
		local rootPart = self:_getRoot(owner)
		local humanoid = owner.Character and owner.Character:FindFirstChildWhichIsA("Humanoid")
		local isDead = humanoid ~= nil and humanoid.Health <= 0
		if not rootPart or isDead then
			for _, rendered in pairs(ownerPets) do setModelVisible(rendered, false) end
			continue
		end
		for slot, rendered in pairs(ownerPets) do
			if rendered.model.Parent == nil then
				destroyPetTracks(rendered)
				ownerPets[slot] = nil
				continue
			end
			setModelVisible(rendered, true)
			rendered.isMoving = ownerIsMoving[owner] == true
			playPetLocomotion(rendered)
			local lateralOffset = (slot - ((PetsConfig.EquippedSlotCount + 1) / 2)) * SLOT_SPACING
			local bobOffset = math.sin(now * BOB_SPEED + slot) * BOB_HEIGHT
			local swayOffset = math.cos(now * SWAY_SPEED + slot * 0.7) * SWAY_DISTANCE
			local followOrigin = rootPart.CFrame
			local movementAttachment = rootPart:FindFirstChild("LauncherMovementAttachment")
			if movementAttachment and movementAttachment:IsA("Attachment") then
				followOrigin = movementAttachment.WorldCFrame
			end
			local look = followOrigin.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude < 0.001 then flatLook = Vector3.zAxis end
			local heading = CFrame.lookAt(followOrigin.Position, followOrigin.Position + flatLook.Unit)
			local target = heading * CFrame.new(lateralOffset + swayOffset, FOLLOW_HEIGHT + bobOffset, FOLLOW_DISTANCE)
			local current = rendered.model:GetPivot()
			if (current.Position - target.Position).Magnitude >= SNAP_DISTANCE then
				rendered.model:PivotTo(target)
			else
				rendered.model:PivotTo(current:Lerp(target, alpha))
			end
		end
		if next(ownerPets) == nil then self._renderedPets[owner] = nil end
	end
end

function ClientPetController:Start()
	if self._started then return end
	self._started = true
	local remotes = ReplicatedStorage:WaitForChild("LauncherArenaRemotes")
	local stateUpdate = remotes:WaitForChild(RemoteContracts.Names.StateUpdate)
	if stateUpdate:IsA("RemoteEvent") then
		table.insert(self._connections, stateUpdate.OnClientEvent:Connect(function(state)
			self:ApplyState(state)
		end))
	end

	local gameplayFeedback = remotes:WaitForChild(RemoteContracts.Names.GameplayFeedback)
	if gameplayFeedback:IsA("RemoteEvent") then
		table.insert(self._connections, gameplayFeedback.OnClientEvent:Connect(function(message)
			if type(message) == "table" and (message.EventType == "RoundVictory" or message.EventType == "PlayerKill") then
				self:_playVictoryDance()
			end
		end))
	end


	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_watchPlayer(player)
	end))
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_unwatchPlayer(player)
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_watchPlayer(player) end
	table.insert(self._connections, RunService.RenderStepped:Connect(function(deltaTime)
		self:_render(deltaTime)
	end))
end

function ClientPetController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
	local watchedPlayers = {}
	for player in pairs(self._ownerConnections) do table.insert(watchedPlayers, player) end
	for _, player in ipairs(watchedPlayers) do self:_unwatchPlayer(player) end
	local renderedOwners = {}
	for player in pairs(self._renderedPets) do table.insert(renderedOwners, player) end
	for _, player in ipairs(renderedOwners) do self:_destroyOwnerModels(player) end
	table.clear(self._ownerNear)
	table.clear(self._ownerLastPositions)
	self._started = false
end

return ClientPetController
