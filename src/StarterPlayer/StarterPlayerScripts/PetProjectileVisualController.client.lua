--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)
local RenderConfig = require(ReplicatedStorage.Shared.Config.PetProjectileRenderConfig)
local localPlayer = Players.LocalPlayer
local active = {}
local warnedMissingPrefab = {}

local PREFABS = {
	PlasmaCannon = "PlasmaBall",
	SlowBlaster = "SlowBall",
}

local function getRoot(player: Player?): BasePart?
	local character = player and player.Character
	if not character then return nil end
	local hitbox = character:FindFirstChild("Hitbox", true)
	if hitbox and hitbox:IsA("BasePart") then return hitbox end
	local root = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	return if root and root:IsA("BasePart") then root else nil
end

local function getVisualRoot(model: Instance): BasePart?
	if model:IsA("BasePart") then return model end
	if model:IsA("Model") then
		if not model.PrimaryPart then
			local part = model:FindFirstChildWhichIsA("BasePart", true)
			if part then model.PrimaryPart = part end
		end
		return model.PrimaryPart
	end
	return nil
end

local function setVisualCFrame(data, position: Vector3, facing: Vector3)
	local direction = if facing.Magnitude > 0.01 then facing.Unit else Vector3.zAxis
	local cf = CFrame.lookAt(position, position + direction)
	if data.visual:IsA("Model") then data.visual:PivotTo(cf) else data.root.CFrame = cf end
end

local function destroyVisual(id: string)
	local data = active[id]
	if not data then return end
	active[id] = nil
	if data.visual and data.visual.Parent then data.visual:Destroy() end
end

local function getCount(): number
	local count = 0
	for _ in pairs(active) do count += 1 end
	return count
end

local function spawnVisual(payload: any)
	if type(payload) ~= "table" or type(payload.id) ~= "string"
		or typeof(payload.origin) ~= "Vector3" or typeof(payload.velocity) ~= "Vector3"
		or type(payload.projectileType) ~= "string" then return end
	if active[payload.id] then destroyVisual(payload.id) end
	local prefabName = PREFABS[payload.projectileType]
	if not prefabName then return end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local prefabs = assets and assets:FindFirstChild("Prefabs")
	local template = prefabs and prefabs:FindFirstChild(prefabName)
	if not template then
		if not warnedMissingPrefab[prefabName] then
			warn(string.format("[PET_PROJECTILE_VISUAL] ReplicatedStorage.Assets.Prefabs.%s is missing; create it in Studio.", prefabName))
			warnedMissingPrefab[prefabName] = true
		end
		return
	end
	local localRoot = getRoot(localPlayer)
	if not localRoot or (localRoot.Position - payload.origin).Magnitude > RenderConfig.NearbyRenderDistance then return end
	if getCount() >= RenderConfig.MaxLocalProjectiles then
		local oldestId, oldestTime = nil, math.huge
		for id, item in pairs(active) do
			if item.spawnServerTime < oldestTime then oldestId, oldestTime = id, item.spawnServerTime end
		end
		if oldestId then destroyVisual(oldestId) end
	end
	local visual = template:Clone()
	local root = getVisualRoot(visual)
	if not root then
		warn(string.format("[PET_PROJECTILE_VISUAL] %s must be a BasePart or Model containing a BasePart.", prefabName))
		visual:Destroy()
		return
	end
	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant.Disabled = true
		end
	end
	if visual:IsA("BasePart") then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
	end
	visual.Parent = Workspace
	local speed = math.max(0, tonumber(payload.speed) or payload.velocity.Magnitude)
	local spawnServerTime = tonumber(payload.spawnServerTime) or Workspace:GetServerTimeNow()
	local lifetime = math.max(0, tonumber(payload.lifetime) or 10)
	local elapsed = math.max(0, Workspace:GetServerTimeNow() - spawnServerTime)
	if elapsed >= lifetime then visual:Destroy(); return end
	local position = payload.origin
	if payload.projectileType == "PlasmaCannon" then
		local gravity = Vector3.new(0, -Workspace.Gravity, 0)
		position += payload.velocity * elapsed + gravity * (0.5 * elapsed * elapsed)
	else
		local initialDirection = if payload.velocity.Magnitude > 0.01 then payload.velocity.Unit else Vector3.zAxis
		position += initialDirection * speed * elapsed
	end
	local targetUserId = tonumber(payload.targetUserId)
	local target = targetUserId and Players:GetPlayerByUserId(targetUserId) or nil
	setVisualCFrame({ visual = visual, root = root }, position, payload.velocity)
	active[payload.id] = {
		id = payload.id,
		visual = visual,
		root = root,
		projectileType = payload.projectileType,
		origin = payload.origin,
		velocity = payload.velocity,
		position = position,
		speed = speed,
		spawnServerTime = spawnServerTime,
		lifetime = lifetime,
		target = target,
		targetUserId = targetUserId,
		lastClientTime = Workspace:GetServerTimeNow(),
	}
end

local function connectRemote()
	local remotes = ReplicatedStorage:FindFirstChild("LauncherArenaRemotes")
	local remote = remotes and remotes:FindFirstChild(RemoteContracts.Names.PetProjectileVisual)
	if remote and remote:IsA("RemoteEvent") then
		remote.OnClientEvent:Connect(function(action: any, payload: any)
			if action == "Spawn" then
				spawnVisual(payload)
			elseif action == "End" and type(payload) == "string" then
				destroyVisual(payload)
			end
		end)
		return true
	end
	warn("[PET_PROJECTILE_VISUAL] LauncherArenaRemotes.PetProjectileVisual missing; waiting for the RemoteEvent to be added through Rojo.")
	if remotes then
		local connection
		connection = remotes.ChildAdded:Connect(function(child)
			if child.Name == RemoteContracts.Names.PetProjectileVisual and child:IsA("RemoteEvent") then
				connection:Disconnect()
				connectRemote()
			end
		end)
	end
	return false
end

connectRemote()

RunService.RenderStepped:Connect(function()
	if next(active) == nil then return end
	local now = Workspace:GetServerTimeNow()
	local localRoot = getRoot(localPlayer)
	for id, data in pairs(active) do
		local elapsed = now - data.spawnServerTime
		if not (data.visual and data.visual.Parent) or elapsed >= data.lifetime or not localRoot then
			destroyVisual(id)
			continue
		end
		local position
		local facing
		if data.projectileType == "PlasmaCannon" then
			local gravity = Vector3.new(0, -Workspace.Gravity, 0)
			position = data.origin + data.velocity * elapsed + gravity * (0.5 * elapsed * elapsed)
			facing = data.velocity + gravity * elapsed
		else
			local dt = math.max(0, math.min(0.1, now - data.lastClientTime))
			local target = data.targetUserId and Players:GetPlayerByUserId(data.targetUserId) or data.target
			local targetRoot = target and getRoot(target)
			local direction = targetRoot and (targetRoot.Position - data.position) or data.velocity
			if direction.Magnitude > 0.01 then
				direction = direction.Unit
				data.position += direction * data.speed * dt
				data.velocity = direction * data.speed
			end
			position = data.position
			facing = data.velocity
		end
		data.lastClientTime = now
		if (localRoot.Position - position).Magnitude > RenderConfig.NearbyRenderDistance then
			destroyVisual(id)
			continue
		end
		setVisualCFrame(data, position, facing)
	end
end)
