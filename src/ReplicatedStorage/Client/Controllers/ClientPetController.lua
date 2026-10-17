--!strict

-- Pet visuals are cloned locally. Nearby players' equipped-pet metadata comes from
-- replicated Player attributes; pet positions are derived from already-replicated pawns.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local PetRenderConfig = require(ReplicatedStorage.Shared.Config.PetRenderConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

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

type RenderedPet = {
	instanceId: string,
	definitionId: string,
	model: Model,
	transparencies: { [Instance]: number },
	visible: boolean,
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

local function getDefinitionId(ownedPet: any, instanceId: string): string?
	if type(ownedPet) == "table" then
		local definitionId = ownedPet.definitionId or ownedPet.id
		if type(definitionId) == "string" and definitionId ~= "" then return definitionId end
	end
	if PetsConfig.GetById(instanceId) then return instanceId end
	return nil
end

local function prepareModel(model: Model): { [Instance]: number }?
	local rootPart = model:FindFirstChild(ROOT_PART_NAME, true)
	if not rootPart or not rootPart:IsA("BasePart") then
		warn(string.format("[CLIENT_PET] %s is missing its required %s BasePart", model.Name, ROOT_PART_NAME))
		return nil
	end
	model.PrimaryPart = rootPart
	local transparencies = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant ~= rootPart then transparencies[descendant] = descendant.Transparency end
			descendant.Anchored = true
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
	self._assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
	self._renderFolder = getOrCreateRenderFolder()
	self._renderedPets = {} :: { [Player]: { [number]: RenderedPet } }
	self._ownerNear = {} :: { [Player]: boolean }
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
		local definitionId = getDefinitionId(ownedPet, instanceId)
		return instanceId, definitionId
	end

	local instanceId = owner:GetAttribute(string.format("EquippedPetSlot%dInstanceId", slot))
	local definitionId = owner:GetAttribute(string.format("EquippedPetSlot%dDefinitionId", slot))
	if type(instanceId) ~= "string" or instanceId == "" or type(definitionId) ~= "string" or definitionId == "" then
		return nil, nil
	end
	return instanceId, definitionId
end

function ClientPetController:_destroyPet(owner: Player, slot: number)
	local ownerPets = self._renderedPets[owner]
	local rendered = ownerPets and ownerPets[slot]
	if rendered then
		rendered.model:Destroy()
		ownerPets[slot] = nil
	end
end

function ClientPetController:_destroyOwnerModels(owner: Player)
	local ownerPets = self._renderedPets[owner]
	if ownerPets then
		local slots = {}
		for slot in pairs(ownerPets) do table.insert(slots, slot) end
		for _, slot in ipairs(slots) do self:_destroyPet(owner, slot) end
	end
	self._renderedPets[owner] = nil
end

function ClientPetController:_createPet(owner: Player, slot: number, instanceId: string, definitionId: string): RenderedPet?
	local definition = PetsConfig.GetById(definitionId)
	if not definition then
		if not self._failedModels[definitionId] then
			warn(string.format("[CLIENT_PET] Unknown pet definition %q for player %s", definitionId, owner.Name))
			self._failedModels[definitionId] = true
		end
		return nil
	end
	local modelName = definition.Name or definitionId
	local source = self._assets:FindFirstChild(modelName)
	if not source or not source:IsA("Model") then
		if not self._failedModels[definitionId] then
			warn(string.format("[CLIENT_PET] Missing pet model %q for equipped pet %q", modelName, instanceId))
			self._failedModels[definitionId] = true
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
	model.Parent = self._renderFolder
	return {
		instanceId = instanceId,
		definitionId = definitionId,
		model = model,
		transparencies = transparencies,
		visible = true,
	}
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

	self._renderedPets[owner] = self._renderedPets[owner] or {}
	for slot = 1, PetsConfig.EquippedSlotCount do
		local instanceId, definitionId = self:_getDesiredPet(owner, slot)
		local ownerPets = self._renderedPets[owner]
		local rendered = ownerPets and ownerPets[slot]
		if not instanceId or not definitionId then
			self:_destroyPet(owner, slot)
		elseif not rendered or rendered.instanceId ~= instanceId or rendered.definitionId ~= definitionId or rendered.model.Parent == nil then
			self:_destroyPet(owner, slot)
			local newRendered = self:_createPet(owner, slot, instanceId, definitionId)
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
	table.insert(connections, player.CharacterAdded:Connect(function()
		self:_reconcileOwner(player)
	end))
	table.insert(connections, player.CharacterRemoving:Connect(function()
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
end

function ClientPetController:_render(deltaTime: number)
	self._rangeCheckElapsed += deltaTime
	if self._rangeCheckElapsed >= PetRenderConfig.NearbyRangeCheckInterval then
		self._rangeCheckElapsed = 0
		for _, player in ipairs(Players:GetPlayers()) do
			self:_reconcileOwner(player)
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
				ownerPets[slot] = nil
				continue
			end
			setModelVisible(rendered, true)
			local lateralOffset = (slot - ((PetsConfig.EquippedSlotCount + 1) / 2)) * SLOT_SPACING
			local bobOffset = math.sin(now * BOB_SPEED + slot) * BOB_HEIGHT
			local swayOffset = math.cos(now * SWAY_SPEED + slot * 0.7) * SWAY_DISTANCE
			local look = rootPart.CFrame.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z)
			if flatLook.Magnitude < 0.001 then flatLook = Vector3.zAxis end
			local heading = CFrame.lookAt(rootPart.Position, rootPart.Position + flatLook.Unit)
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
	for player in pairs(self._ownerConnections) do self:_unwatchPlayer(player) end
	for player in pairs(self._renderedPets) do self:_destroyOwnerModels(player) end
	table.clear(self._ownerNear)
	self._started = false
end

return ClientPetController
