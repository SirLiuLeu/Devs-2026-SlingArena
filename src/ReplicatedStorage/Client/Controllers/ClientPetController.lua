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
local FOLLOW_HEIGHT = 3
local SLOT_SPACING = 3
local FOLLOW_LERP_SPEED = 10
local BOB_HEIGHT = 0.35
local BOB_SPEED = 2.5
local SWAY_DISTANCE = 0.3
local SNAP_DISTANCE = 80

type RenderedPet = {
	instanceId: string,
	definitionId: string,
	model: Model,
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

local function prepareModel(model: Model): boolean
	local rootPart = model:FindFirstChild(ROOT_PART_NAME, true)
	if not rootPart or not rootPart:IsA("BasePart") then
		warn(string.format("[CLIENT_PET] %s is missing its required %s BasePart", model.Name, ROOT_PART_NAME))
		return false
	end
	model.PrimaryPart = rootPart
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	return true
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
	self._stateAlive = nil :: boolean?
	self._started = false
	return self
end

function ClientPetController:_invalidatePawn()
	self._cachedCharacter = nil
	self._cachedPawn = nil
	self._cachedRootPart = nil
	self._cachedMode = nil
end

function ClientPetController:_getRootPart(): BasePart?
	local character = self._player.Character
	local mode = self._player:GetAttribute("ActivePlayerMode")
	if character ~= self._cachedCharacter or mode ~= self._cachedMode or (self._cachedRootPart and self._cachedRootPart.Parent == nil) then
		self._cachedCharacter = character
		self._cachedMode = mode
		self._cachedPawn = PawnLocator.GetPawnByPlayer(self._player)
		self._cachedRootPart = PawnLocator.GetRootPart(self._cachedPawn)
	end
	return self._cachedRootPart
end

function ClientPetController:_isAlive(pawn: Model?): boolean
	if self._stateAlive == false then return false end
	if not pawn then return false end
	local humanoid = pawn:FindFirstChildWhichIsA("Humanoid")
	if humanoid then return humanoid.Health > 0 end
	local health = pawn:GetAttribute("Health")
	if typeof(health) == "number" then return health > 0 end
	return self._player:GetAttribute("IsAlive") ~= false
end

local function setPetHidden(model: Model, hidden: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = if hidden then 1 else 0
		end
	end
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
	if not prepareModel(model) then
		model:Destroy()
		return nil
	end
	model.Parent = self._renderFolder
	local rendered = { instanceId = instanceId, definitionId = definitionId, model = model }
	self._renderedPets[slot] = rendered
	return rendered
end

function ClientPetController:ApplyState(state: any)
	if type(state) ~= "table" then
		return
	end
	if typeof(state.IsAlive) == "boolean" then self._stateAlive = state.IsAlive end

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
	local rootPart = self:_getRootPart()
	local alive = self:_isAlive(self._cachedPawn)

	local alpha = 1 - math.exp(-FOLLOW_LERP_SPEED * deltaTime)
	local now = os.clock()
	for slot, rendered in pairs(self._renderedPets) do
		if rendered.model.Parent == nil then
			self._renderedPets[slot] = nil
			continue
		end
		setPetHidden(rendered.model, not alive)
		if not alive or not rootPart then continue end
		local lateralOffset = (slot - ((PetsConfig.EquippedSlotCount + 1) / 2)) * SLOT_SPACING
		local bobOffset = math.sin(now * BOB_SPEED + slot) * BOB_HEIGHT
		local swayOffset = math.cos(now * BOB_SPEED * 0.7 + slot) * SWAY_DISTANCE
		-- Launchers can roll in flight. Retain only their heading so companion models stay upright.
		local heading = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
		if heading.Magnitude < 0.001 then heading = Vector3.zAxis end
		local yaw = CFrame.lookAt(rootPart.Position, rootPart.Position + heading.Unit)
		local target = yaw * CFrame.new(lateralOffset + swayOffset, FOLLOW_HEIGHT + bobOffset, FOLLOW_DISTANCE)
		local current = rendered.model:GetPivot()
		if (current.Position - target.Position).Magnitude > SNAP_DISTANCE then
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
	table.insert(self._connections, self._player.CharacterAdded:Connect(function()
		self:_invalidatePawn()
	end))
	table.insert(self._connections, self._player:GetAttributeChangedSignal("ActivePlayerMode"):Connect(function()
		self:_invalidatePawn()
	end))
	local pawnsFolder = Workspace:FindFirstChild("LauncherPawns")
	local function bindPawnsFolder(folder: Instance)
		if not folder:IsA("Folder") then return end
		table.insert(self._connections, folder.ChildAdded:Connect(function(child)
			if child:IsA("Model") and (child.Name == self._player.Name or child.Name == self._player.Name .. "_Pawn") then self:_invalidatePawn() end
		end))
		table.insert(self._connections, folder.ChildRemoved:Connect(function(child)
			if child == self._cachedPawn then self:_invalidatePawn() end
		end))
	end
	if pawnsFolder then
		bindPawnsFolder(pawnsFolder)
	else
		table.insert(self._connections, Workspace.ChildAdded:Connect(function(child)
			if child.Name == "LauncherPawns" then
				bindPawnsFolder(child)
				self:_invalidatePawn()
			end
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
