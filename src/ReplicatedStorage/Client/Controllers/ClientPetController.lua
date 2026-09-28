--!strict

-- Client-only visual companion renderer. Pet models are never welded to or
-- simulated by the server; each player renders only their own equipped pets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PetsConfig = require(ReplicatedStorage.Shared.Config.PetsConfig)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

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
	self._started = false
	return self
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
	local character = self._player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local alpha = 1 - math.exp(-FOLLOW_LERP_SPEED * deltaTime)
	local now = os.clock()
	for slot, rendered in pairs(self._renderedPets) do
		if rendered.model.Parent == nil then
			self._renderedPets[slot] = nil
			continue
		end
		local lateralOffset = (slot - ((PetsConfig.EquippedSlotCount + 1) / 2)) * SLOT_SPACING
		local bobOffset = math.sin(now * BOB_SPEED + slot) * BOB_HEIGHT
		-- Pet assets are authored facing local -Z, so no corrective rotation is needed.
		local target = rootPart.CFrame * CFrame.new(lateralOffset, FOLLOW_HEIGHT + bobOffset, FOLLOW_DISTANCE)
		rendered.model:PivotTo(rendered.model:GetPivot():Lerp(target, alpha))
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
