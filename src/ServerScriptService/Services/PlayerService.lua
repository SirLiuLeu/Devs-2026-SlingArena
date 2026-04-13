--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)

local PlayerService = {}
PlayerService.__index = PlayerService

function PlayerService.new(context)
	local self = setmetatable({}, PlayerService)
	self._context = context
	self._deathConnections = {}
	self._pawnsFolder = Workspace:FindFirstChild("SlingPawns")
	self._slingTemplate = nil
	self._worldUiTemplate = nil
	if not self._pawnsFolder then
		self._pawnsFolder = Instance.new("Folder")
		self._pawnsFolder.Name = "SlingPawns"
		self._pawnsFolder.Parent = Workspace
	end
	return self
end

function PlayerService:Init()
	Players.CharacterAutoLoads = false
	self:_loadSlingTemplate()
	self:_loadWorldUiTemplate()

	self._context.EventBus:On("PlayerStateUpdated", function(player: Player, state)
		self:_updateWorldUi(player, state)
	end)

	Players.PlayerAdded:Connect(function(player)
		self:SpawnPawn(player, 1, "LobbyMap")
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
	end)

	for _, player in Players:GetPlayers() do
		self:SpawnPawn(player, 1, "LobbyMap")
	end

	local debugResetRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.DebugResetSling)
	if debugResetRemote and debugResetRemote:IsA("RemoteEvent") then
		debugResetRemote.OnServerEvent:Connect(function(player)
			self:SpawnPawn(player, nil, self._context.Services.MapService:GetActiveMap() or "LobbyMap")
		end)
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
	--       SlingWorldUI (BillboardGui)
	--         HpBarBackground (Frame)
	--           HpBarFill (Frame)
	--         LevelLabel (TextLabel)
	--         TeamLabel (TextLabel)

	local resolved = ReplicatedStorage
	for token in string.gmatch(ProjectTreeSpec.GameplayInstances.ReplicatedStorage.Assets.SlingWorldUI, "[^%.]+") do
		resolved = resolved:FindFirstChild(token)
		if not resolved then
			break
		end
	end
	if resolved and resolved:IsA("BillboardGui") then
		self._worldUiTemplate = resolved
		return self._worldUiTemplate
	end

	warn("[WORLD_UI] ReplicatedStorage.Assets.UI.SlingWorldUI missing. Create it manually in Studio.")
	self._worldUiTemplate = nil
	return nil
end

function PlayerService:_attachWorldUi(pawn: Model)
	local worldUiTemplate = self:_loadWorldUiTemplate()
	if not worldUiTemplate then
		return
	end

	local existing = pawn:FindFirstChild("SlingWorldUI")
	if existing and existing:IsA("BillboardGui") then
		existing:Destroy()
	end

	local worldUi = worldUiTemplate:Clone()
	worldUi.Name = "SlingWorldUI"
	worldUi.Adornee = pawn.PrimaryPart
	worldUi.Parent = pawn
end

function PlayerService:_updateWorldUi(player: Player, state)
	local pawn = self:GetPawn(player)
	if not pawn then
		return
	end
	local worldUi = pawn:FindFirstChild("SlingWorldUI")
	if not (worldUi and worldUi:IsA("BillboardGui")) then
		self:_attachWorldUi(pawn)
		worldUi = pawn:FindFirstChild("SlingWorldUI")
	end
	if not (worldUi and worldUi:IsA("BillboardGui")) then
		return
	end

	if pawn.PrimaryPart then
		worldUi.Adornee = pawn.PrimaryPart
	end

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

function PlayerService:_loadSlingTemplate(): Model
	if self._slingTemplate then
		return self._slingTemplate
	end

	local slingsFolder = ReplicatedStorage:WaitForChild("Slings", 5)
	local slingModel = nil
	if slingsFolder then
		slingModel = slingsFolder:FindFirstChild("SlingModel")
	end
	if not (slingModel and slingModel:IsA("Model")) then
		warn("[PLAYER_SERVICE] ReplicatedStorage/Slings/SlingModel missing. Using fallback physics model.")
		local fallback = Instance.new("Model")
		fallback.Name = "SlingModel"
		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Shape = Enum.PartType.Ball
		rootPart.Size = Vector3.new(4, 4, 4)
		rootPart.TopSurface = Enum.SurfaceType.Smooth
		rootPart.BottomSurface = Enum.SurfaceType.Smooth
		rootPart.Parent = fallback
		fallback.PrimaryPart = rootPart
		slingModel = fallback
	end

	local template = slingModel:Clone()
	template.Name = "SlingModelTemplate"
	template.Parent = nil

	if Config.SlingScale ~= 1 then
		template:ScaleTo(Config.SlingScale)
	end

	local root = template.PrimaryPart
	if not root then
		root = template:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	if not (root and root:IsA("BasePart")) then
		warn("[PLAYER_SERVICE] SlingModel missing PrimaryPart/HumanoidRootPart. Injecting fallback root part.")
		local fallbackRoot = Instance.new("Part")
		fallbackRoot.Name = "HumanoidRootPart"
		fallbackRoot.Shape = Enum.PartType.Ball
		fallbackRoot.Size = Vector3.new(4, 4, 4)
		fallbackRoot.Parent = template
		root = fallbackRoot
	end
	template.PrimaryPart = root

	local attachment = root:FindFirstChild("Attachment")
	local linearVelocity = root:FindFirstChild("LinearVelocity")
	local alignOrientation = root:FindFirstChild("AlignOrientation")
	local body = template:FindFirstChild("Body")
	local bodyWeld = template:FindFirstChild("BodyWeld")

	if attachment and attachment:IsA("Attachment") then
		if linearVelocity and linearVelocity:IsA("LinearVelocity") then
			linearVelocity.Attachment0 = attachment
			linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			linearVelocity.Enabled = false
		end
		if alignOrientation and alignOrientation:IsA("AlignOrientation") then
			alignOrientation.Attachment0 = attachment
			alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
			alignOrientation.RigidityEnabled = true
		end
	end

	if body and body:IsA("BasePart") then
		body.CustomPhysicalProperties = PhysicalProperties.new(Config.Mass, 0.4, 0.5, 1, 1)
	end
	if bodyWeld and bodyWeld:IsA("WeldConstraint") and body and body:IsA("BasePart") then
		bodyWeld.Part0 = root
		bodyWeld.Part1 = body
	end

	self._slingTemplate = template
	return template
end

function PlayerService:GetPawn(player)
	return self._pawnsFolder:FindFirstChild(player.Name)
end

function PlayerService:IsAlive(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	return state ~= nil and state.IsAlive
end

function PlayerService:_disconnectDeathSignal(player)
	local connection = self._deathConnections[player]
	if connection then
		connection:Disconnect()
		self._deathConnections[player] = nil
	end
end

function PlayerService:SpawnPawn(player, spawnIndex: number?, mapName: string?)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)

	local template = self:_loadSlingTemplate()
	local pawn = template:Clone()
	pawn.Name = player.Name
	local index = spawnIndex or (player.UserId % 8) + 1
	local mapService = self._context.Services.MapService
	local playerState = self._context.Services.PlayerStateService:GetState(player)
	local teamId = playerState and playerState.TeamId or nil
	local spawnCFrame = CFrame.new(mapService:GetSpawnPoint(index, mapName))
	if type(mapService.GetSpawnCFrame) == "function" then
		spawnCFrame = mapService:GetSpawnCFrame(index, mapName, teamId)
	end
	pawn:PivotTo(spawnCFrame)
	pawn.Parent = self._pawnsFolder
	self:_attachWorldUi(pawn)
	pawn:SetAttribute("ScaleValue", Config.SlingScale)
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
			descendant:SetNetworkOwner(nil)
		elseif descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end

	player.Character = pawn
	self._context.Services.PlayerStateService:ResetForRespawn(player)
	local state = self._context.Services.PlayerStateService:GetState(player)
	if state then
		self:_updateWorldUi(player, state)
	end

	return pawn
end

function PlayerService:DespawnPawn(player)
	self:_disconnectDeathSignal(player)
	self:_destroyPawn(player)
	self._context.Services.PlayerStateService:SetAlive(player, false)
end

function PlayerService:_destroyPawn(player)
	local pawn = self:GetPawn(player)
	if pawn then
		pawn:Destroy()
	end
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
	local pawn = self:GetPawn(player)
	if not pawn then
		return nil
	end
	local root = pawn.PrimaryPart or pawn:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
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
	local character = player.Character
	if not character or not character:IsA("Model") then
		character = self:GetPawn(player)
	end
	if not character or not character:IsA("Model") then
		return false
	end
	character:PivotTo(spawn.CFrame)
	return true
end

return PlayerService
