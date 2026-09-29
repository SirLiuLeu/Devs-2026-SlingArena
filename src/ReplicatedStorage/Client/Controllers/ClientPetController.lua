--!strict

-- Client-only visual companion renderer. Pet models are never welded to or
-- simulated by the server; each player renders only their own equipped pets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
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
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = RENDER_FOLDER_NAME
	folder.Parent = Workspace
	return folder
end

local function findOwnedPet(ownedPets: any, instanceId: string): any?
	if type(ownedPets) ~= "table" then
		return nil
	end
	local direct = ownedPets[instanceId]
	if type(direct) == "table" then
		return direct
	end
	for _, pet in pairs(ownedPets) do
		if type(pet) == "table" and tostring(pet.instanceId or "") == instanceId then
			return pet
		end
	end
	return nil
end

local function getDefinitionId(ownedPet: any, instanceId: string): string?
	if type(ownedPet) == "table" then
		local definitionId = ownedPet.definitionId or ownedPet.id
		if type(definitionId) == "string" and definitionId ~= "" then
			return definitionId
		end
	end
	-- This also supports a state payload that directly places definition ids in
	-- EquippedPets, which is useful for lightweight test payloads.
	if PetsConfig.GetById(instanceId) then
		return instanceId
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

function ClientPetController.new(player: Player)
	local self = setmetatable({}, ClientPetController)
	self._player = player
	self._assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
	self._renderFolder = getOrCreateRenderFolder()
	self._renderedPets = {} :: { [number]: RenderedPet }
	self._connections = {} :: { RBXScriptConnection }
	self._cachedCharacter = nil :: Model?
	self._cachedPawn = nil :: Model?
	self._cachedRootPart = nil :: BasePart?
	self._cachedMode = nil :: any
	self._started = false
	return self
end

function ClientPetController:_getFollowRoot(): BasePart?
	local character = self._player.Character
	local mode = self._player:GetAttribute("ActivePlayerMode") or self._player:GetAttribute("State")
	local pawn = PawnLocator.GetPawnByPlayer(self._player)
	local root = self._cachedRootPart
	if character ~= self._cachedCharacter or pawn ~= self._cachedPawn or mode ~= self._cachedMode
		or not root or root.Parent == nil then
		self._cachedCharacter = character
		self._cachedPawn = pawn
		self._cachedMode = mode
		self._cachedRootPart = PawnLocator.GetRootPart(pawn)
	end
	return self._cachedRootPart
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

function ClientPetController:_destroyPet(slot: number)
	local rendered = self._renderedPets[slot]
	if rendered then
		rendered.model:Destroy()
		self._renderedPets[slot] = nil
	end
end

function ClientPetController:_createPet(slot: number, instanceId: string, definitionId: string): RenderedPet?
	local definition = PetsConfig.GetById(definitionId)
	local modelName = definition and definition.Name or definitionId
	local source = self._assets:FindFirstChild(modelName)
	if not source or not source:IsA("Model") then
		warn(string.format("[CLIENT_PET] Missing pet model %q for equipped pet %q", modelName, instanceId))
		return nil
	end

	local model = source:Clone()
	model.Name = string.format("Pet_%d_%s", slot, instanceId)
	local transparencies = prepareModel(model)
	if not transparencies then
		model:Destroy()
		return nil
	end
	model.Parent = self._renderFolder
	local rendered = { instanceId = instanceId, definitionId = definitionId, model = model, transparencies = transparencies, visible = true }
	self._renderedPets[slot] = rendered
	return rendered
end

function ClientPetController:ApplyState(state: any)
	if type(state) ~= "table" then
		return
	end

	local equippedPets = state.EquippedPets
	local ownedPets = state.OwnedPets
	if type(equippedPets) ~= "table" then
		for slot in pairs(self._renderedPets) do self:_destroyPet(slot) end
		return
	end

	for slot = 1, PetsConfig.EquippedSlotCount do
		local instanceIdValue = equippedPets[slot] or equippedPets[tostring(slot)]
		local instanceId = if instanceIdValue == nil then nil else tostring(instanceIdValue)
		local ownedPet = instanceId and findOwnedPet(ownedPets, instanceId) or nil
		local definitionId = instanceId and getDefinitionId(ownedPet, instanceId) or nil
		local rendered = self._renderedPets[slot]

		if not instanceId or not definitionId then
			self:_destroyPet(slot)
		elseif not rendered or rendered.instanceId ~= instanceId or rendered.definitionId ~= definitionId then
			self:_destroyPet(slot)
			self:_createPet(slot, instanceId, definitionId)
		end
	end
end

function ClientPetController:_render(deltaTime: number)
	local rootPart = self:_getFollowRoot()
	local humanoid = self._player.Character and self._player.Character:FindFirstChildWhichIsA("Humanoid")
	local isDead = humanoid ~= nil and humanoid.Health <= 0
	if not rootPart or isDead then
		for _, rendered in pairs(self._renderedPets) do
			setModelVisible(rendered, false)
		end
		return
	end

	local alpha = 1 - math.exp(-FOLLOW_LERP_SPEED * deltaTime)
	local now = os.clock()
	for slot, rendered in pairs(self._renderedPets) do
		if rendered.model.Parent == nil then
			self._renderedPets[slot] = nil
			continue
		end
		setModelVisible(rendered, true)
		local lateralOffset = (slot - ((PetsConfig.EquippedSlotCount + 1) / 2)) * SLOT_SPACING
		local bobOffset = math.sin(now * BOB_SPEED + slot) * BOB_HEIGHT
		local swayOffset = math.cos(now * SWAY_SPEED + slot * 0.7) * SWAY_DISTANCE
		-- Launcher pawns roll in flight. Only use their heading to keep pets upright.
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
	table.insert(self._connections, RunService.RenderStepped:Connect(function(deltaTime)
		self:_render(deltaTime)
	end))
end

function ClientPetController:Destroy()
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
	for slot in pairs(self._renderedPets) do self:_destroyPet(slot) end
	self._started = false
end

return ClientPetController
