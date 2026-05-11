--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config.Config)
local PhysicsConfig = require(ReplicatedStorage.Shared.Config.PhysicsConfig)
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
	self._playerToSling = {}
	self._slingToPlayer = {}
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
		self:_waitForPlayerReady(player)
		self:SpawnPawn(player, 1, "LobbyMap")
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_disconnectDeathSignal(player)
		self:_destroyPawn(player)
		self._playerToSling[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self:_waitForPlayerReady(player)
		self:SpawnPawn(player, 1, "LobbyMap")
	end

	local debugResetRemote = self._context.Remotes:FindFirstChild(RemoteContracts.Names.DebugResetSling)
	if debugResetRemote and debugResetRemote:IsA("RemoteEvent") then
		debugResetRemote.OnServerEvent:Connect(function(player)
			self:SpawnPawn(player, nil, self._context.Services.MapService:GetActiveMap() or "LobbyMap")
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

function PlayerService:_loadSlingTemplate(): Model?
	if self._slingTemplate then
		return self._slingTemplate
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	local slingsFolder = assetsFolder and assetsFolder:FindFirstChild("Slings")
	local slingModel = slingsFolder and slingsFolder:FindFirstChild("Sling_Template")
	if not (slingModel and slingModel:IsA("Model")) then
		warn("[PLAYER_SERVICE] ReplicatedStorage/Assets/Slings/Sling_Template missing. Pawn spawn aborted.")
		return nil
	end

	local template = slingModel:Clone()
	template.Name = "SlingTemplate"
	template.Parent = nil

	if Config.SlingScale ~= 1 then
		template:ScaleTo(Config.SlingScale)
	end

	local root = template:FindFirstChild("Hitbox") :: BasePart?
	if not root then
		root = template.PrimaryPart
	end
	if not (root and root:IsA("BasePart")) then
		warn("[PLAYER_SERVICE] Sling_Template has no PrimaryPart/Hitbox. Pawn spawn aborted.")
		return nil
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
			alignOrientation.RigidityEnabled = false
			alignOrientation.MaxTorque = math.huge
			alignOrientation.Responsiveness = 20
		end
	end

	if body and body:IsA("BasePart") then
		body.CustomPhysicalProperties = PhysicalProperties.new(
				PhysicsConfig.PhysicalProperties.Density,
				PhysicsConfig.PhysicalProperties.Friction,
				PhysicsConfig.PhysicalProperties.Elasticity,
				PhysicsConfig.PhysicalProperties.FrictionWeight,
				PhysicsConfig.PhysicalProperties.ElasticityWeight
			)
	end
	if bodyWeld and bodyWeld:IsA("WeldConstraint") and body and body:IsA("BasePart") then
		bodyWeld.Part0 = root
		bodyWeld.Part1 = body
	end

	self._slingTemplate = template
	return template
end

function PlayerService:GetPawn(player)
	local mapped = self._playerToSling[player]
	if mapped and mapped.Parent then
		return mapped
	end
	local byName = self._pawnsFolder:FindFirstChild(player.Name .. "_Pawn")
	if byName and byName:IsA("Model") then
		self._playerToSling[player] = byName
		self._slingToPlayer[byName] = player
		return byName
	end
	return nil
end

function PlayerService:GetPlayerFromPawn(pawn: Model): Player?
	local mapped = self._slingToPlayer[pawn]
	if mapped and mapped.Parent == Players then
		return mapped
	end
	for player, playerPawn in pairs(self._playerToSling) do
		if playerPawn == pawn and player.Parent == Players then
			self._slingToPlayer[pawn] = player
			return player
		end
	end
	return nil
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
	if not template then
		return nil
	end
	local pawn = template:Clone()
	if not pawn.PrimaryPart then
		local root = pawn:FindFirstChild("Hitbox")
		if root and root:IsA("BasePart") then
			pawn.PrimaryPart = root
		end
	end
	if not pawn.PrimaryPart then
		warn("[PLAYER_SERVICE] Pawn clone missing PrimaryPart. Pawn spawn aborted.")
		return nil
	end

	pawn.Name = player.Name .. "_Pawn"
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
	player.Character = pawn
	pawn.PrimaryPart:SetNetworkOwner(player)
	self._playerToSling[player] = pawn
	self._slingToPlayer[pawn] = player
	self:_attachWorldUi(pawn)
	pawn:SetAttribute("ScaleValue", Config.SlingScale)
	for _, descendant in pawn:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		elseif descendant:IsA("BodyMover") then
			descendant:Destroy()
		end
	end

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
		self._slingToPlayer[pawn] = nil
		pawn:Destroy()
	end
	self._playerToSling[player] = nil
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
	local root = pawn.PrimaryPart or pawn:FindFirstChild("Hitbox")
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
	local pawn = self:GetPawn(player)
	if not pawn then
		return false
	end
	pawn:PivotTo(spawn.CFrame)
	return true
end

return PlayerService
