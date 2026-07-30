--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)
local TrapService = {}
TrapService.__index = TrapService

local function getArenaMapModel(): Model?
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if not (mapsRoot and mapsRoot:IsA("Folder")) then
		return nil
	end

	local arenaMap = mapsRoot:FindFirstChild("ArenaMap")
	if arenaMap and arenaMap:IsA("Model") then
		return arenaMap
	end

	return nil
end

local function getTrapFolderFromArena(arenaMap: Instance?): Folder?
	if not arenaMap or not arenaMap:IsA("Model") then
		return nil
	end
	local trapFolder = arenaMap:FindFirstChild("Traps")
	if trapFolder and trapFolder:IsA("Folder") then
		return trapFolder
	end
	return nil
end

local function getTrapInfo(trapPart: BasePart): (string?, any?, Model?)
	local arenaMap = getArenaMapModel()
	local trapFolder = getTrapFolderFromArena(arenaMap)
	if not trapFolder then
		return nil, nil, nil
	end

	local current: Instance? = trapPart
	while current and current.Parent ~= trapFolder do
		current = current.Parent
	end
	if not (current and current:IsA("Model")) then
		return nil, nil, nil
	end

	local trapConfig = (TrapConfig.Types or {})[current.Name]
	if trapConfig then
		return current.Name, trapConfig, current
	end
	return nil, nil, nil
end

local function getDetectionRadius(trapPart: BasePart, trapConfig: any): number
	local explicitRadius = tonumber(trapConfig.DetectionRadius)
	if explicitRadius and explicitRadius > 0 then
		return explicitRadius
	end
	local padding = math.max(0, tonumber(trapConfig.DetectionPadding) or 3)
	return (math.max(trapPart.Size.X, trapPart.Size.Y, trapPart.Size.Z) * 0.5) + padding
end

local function isRootInTrapRange(root: BasePart, trapPart: BasePart, trapConfig: any): boolean
	local localPosition = trapPart.CFrame:PointToObjectSpace(root.Position)
	local halfSize = trapPart.Size * 0.5
	local closest = Vector3.new(
		math.clamp(localPosition.X, -halfSize.X, halfSize.X),
		math.clamp(localPosition.Y, -halfSize.Y, halfSize.Y),
		math.clamp(localPosition.Z, -halfSize.Z, halfSize.Z)
	)
	local distance = (localPosition - closest).Magnitude
	local rootRadius = math.max(root.Size.X, root.Size.Z) * 0.5
	local padding = math.max(0, tonumber(trapConfig.DetectionPadding) or 3)
	return distance <= rootRadius + padding
end

local function getTrapSourceId(sourceRoot: Model, trapType: string): string
	local trapId = sourceRoot:GetAttribute("TrapId")
	if type(trapId) == "string" and trapId ~= "" then
		return `Trap:{trapType}:{trapId}`
	end
	return `Trap:{trapType}:{sourceRoot:GetFullName()}`
end

local function resolveLavaDamageAmount(playerState: any, trapConfig: any): number
	local maxHp = tonumber(playerState.MaxHP) or 0
	local percent = math.max(0, tonumber(trapConfig.DamagePerTick) or 0)
	if maxHp > 0 then
		return maxHp * percent
	end
	return 0
end

function TrapService.new(context)
	local self = setmetatable({}, TrapService)
	self._context = context
	self._lastTriggeredAt = {} :: { [string]: number }
	self._trapConnections = {}
	self._activeContacts = {} :: { [string]: boolean }
	self._contactCounts = {} :: { [string]: number }
	self._activeTrapParts = {} :: { BasePart }
	self._contactTrapParts = {} :: { [string]: BasePart }
	self._scanAccumulator = 0
	return self
end

function TrapService:Init()
	-- TrapService owns trap collision exclusively through server-side distance checks.
	table.insert(self._trapConnections, RunService.Heartbeat:Connect(function(dt)
		self:_scanTrapContacts(dt)
	end))
end

function TrapService:GetActiveTrapParts(): { BasePart }
	local parts = {}
	local arenaMap = getArenaMapModel()
	local trapFolder = getTrapFolderFromArena(arenaMap)
	if not trapFolder then
		return parts
	end
	for _, trap in ipairs(trapFolder:GetChildren()) do
		if trap:IsA("BasePart") and getTrapInfo(trap) then
			table.insert(parts, trap)
		end
		for _, trapPart in ipairs(trap:GetDescendants()) do
			if trapPart:IsA("BasePart") and getTrapInfo(trapPart) then
				table.insert(parts, trapPart)
			end
		end
	end
	return parts
end

function TrapService:_disconnectTrapResources()
	for _, connection in ipairs(self._trapConnections) do
		connection:Disconnect()
	end
	table.clear(self._trapConnections)
	table.clear(self._activeContacts)
	table.clear(self._contactCounts)
	table.clear(self._activeTrapParts)
	table.clear(self._contactTrapParts)
end

function TrapService:_refreshActiveTrapParts()
	self._activeTrapParts = self:GetActiveTrapParts()
end

function TrapService:LoadMapResources(mapName: string)
	if mapName ~= "ArenaMap" then
		return
	end
	local arenaMap = getArenaMapModel()
	local trapFolder = getTrapFolderFromArena(arenaMap)
	if not trapFolder then
		warn("[TrapService] Missing Workspace.Maps.ArenaMap.Traps folder. Create traps manually in Studio.")
		return
	end
	self:_disconnectTrapResources()
	self:_refreshActiveTrapParts()
	table.insert(self._trapConnections, trapFolder.DescendantAdded:Connect(function()
		self:_refreshActiveTrapParts()
	end))
	table.insert(self._trapConnections, trapFolder.DescendantRemoving:Connect(function()
		task.defer(function()
			self:_refreshActiveTrapParts()
		end)
	end))
	table.insert(self._trapConnections, RunService.Heartbeat:Connect(function(dt)
		self:_scanTrapContacts(dt)
	end))
end

function TrapService:SpawnTrapForActiveMap(_count: number)
	self:LoadMapResources("ArenaMap")
end

function TrapService:_getContactKey(player: Player, trapType: string, sourceRoot: Model): string
	return `{player.UserId}:{getTrapSourceId(sourceRoot, trapType)}`
end

function TrapService:_emitPopup(player: Player, trapConfig: any)
	local popup = self._context.Remotes:FindFirstChild("PopupMessage")
	if popup and popup:IsA("RemoteEvent") and trapConfig.PopupText then
		popup:FireClient(player, { Type = "Trap", Text = trapConfig.PopupText })
	end
end

function TrapService:_applyHitCooldownTrap(player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model)
	local now = os.clock()
	local cooldown = math.max(0, tonumber(trapConfig.Cooldown) or 0)
	local cooldownKey = self:_getContactKey(player, trapType, sourceRoot)
	local last = self._lastTriggeredAt[cooldownKey] or 0
	if now - last < cooldown then
		return
	end

	local damageApplied = false
	local damagePipeline = self._context.Services.DamagePipelineService
	if trapConfig.Damage and damagePipeline then
		damageApplied = damagePipeline:ApplyHitDamage(player, trapConfig.Damage, nil, nil) == true
	end
	if not damageApplied then
		return
	end
	self._lastTriggeredAt[cooldownKey] = now

	self:_emitPopup(player, trapConfig)
end

function TrapService:_applyContactDotTrapTick(player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model)
	local flagName = trapConfig.Flag
	local stateService = self._context.Services.PlayerStateService
	local damagePipeline = self._context.Services.DamagePipelineService
	if not (flagName and stateService and damagePipeline) then
		return
	end
	local state = stateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end

	local sourceId = getTrapSourceId(sourceRoot, trapType)
	local tickInterval = math.max(0.05, tonumber(trapConfig.TickInterval) or 0.5)
	local duration = math.max(tickInterval + 0.25, tonumber(trapConfig.ContactSlowDuration) or 0)
	stateService:ApplyFlag(player, flagName, duration, sourceRoot, {
		SourceId = sourceId,
		Stackable = false,
		MaxStack = math.max(1, tonumber(trapConfig.MaxStack) or 1),
	})
	local slowAmount = math.max(0, tonumber(trapConfig.ContactSlowAmount) or 0)
	if slowAmount > 0 then
		stateService:ApplyFlag(player, "Slow", duration, sourceRoot, {
			SourceId = `{sourceId}:Slow`,
			SlowAmount = slowAmount,
		})
	end
	local amount = resolveLavaDamageAmount(state, trapConfig)
	if amount > 0 and damagePipeline:ApplyDoTDamage(player, amount, trapPart, flagName) then
		self:_emitPopup(player, trapConfig)
	end
end

function TrapService:_stopContactDotTrap(player: Player, trapType: string, trapConfig: any, sourceRoot: Model)
	local stateService = self._context.Services.PlayerStateService
	if not stateService then
		return
	end
	local sourceId = getTrapSourceId(sourceRoot, trapType)
	if trapConfig.Flag then
		stateService:RemoveFlag(player, trapConfig.Flag, sourceRoot, { SourceId = sourceId })
	end
	stateService:RemoveFlag(player, "Slow", sourceRoot, { SourceId = `{sourceId}:Slow` })
end

TrapService._behaviorHandlers = {
	HitCooldown = {
		Begin = function(self, player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model)
			self:_applyHitCooldownTrap(player, trapPart, trapType, trapConfig, sourceRoot)
		end,
	},
	ContactDot = {
		Begin = function(self, player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model, contactKey: string)
			if self._activeContacts[contactKey] then
				return
			end
			self._activeContacts[contactKey] = true
			task.spawn(function()
				while self._activeContacts[contactKey] do
					self:_applyContactDotTrapTick(player, trapPart, trapType, trapConfig, sourceRoot)
					task.wait(math.max(0.05, tonumber(trapConfig.TickInterval) or 0.5))
				end
			end)
		end,
		End = function(self, player: Player, _trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model, contactKey: string)
			self._activeContacts[contactKey] = nil
			self:_stopContactDotTrap(player, trapType, trapConfig, sourceRoot)
		end,
	},
}

function TrapService:_scanTrapContacts(dt: number)
	self._scanAccumulator += dt
	local interval = math.max(0.05, tonumber(TrapConfig.ScanInterval) or 0.1)
	if self._scanAccumulator < interval then
		return
	end
	self._scanAccumulator = 0

	local playerService = self._context.Services.PlayerService
	if not playerService then
		return
	end

	local observedContacts = {} :: { [string]: boolean }
	for _, player in ipairs(Players:GetPlayers()) do
		local root = playerService:GetRoot(player)
		if not (root and playerService:IsAlive(player)) then
			continue
		end
		for _, trapPart in ipairs(self._activeTrapParts) do
			if not trapPart.Parent then
				continue
			end
			local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
			if not (trapType and trapConfig and sourceRoot) then
				continue
			end
			if (root.Position - trapPart.Position).Magnitude > getDetectionRadius(trapPart, trapConfig) then
				continue
			end
			if isRootInTrapRange(root, trapPart, trapConfig) then
				local contactKey = self:_getContactKey(player, trapType, sourceRoot)
				observedContacts[contactKey] = true
				if not self._contactCounts[contactKey] then
					self._contactTrapParts[contactKey] = trapPart
					self:_beginTrapContact(player, trapPart)
				end
			end
		end
	end

	for contactKey in pairs(self._contactCounts) do
		if not observedContacts[contactKey] then
			local trapPart = self._contactTrapParts[contactKey]
			if trapPart then
				local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
				if trapType and trapConfig and sourceRoot then
					self:_updateContactCountFromKey(contactKey, trapPart, trapType, trapConfig, sourceRoot, -1)
				end
			end
			self._contactCounts[contactKey] = nil
			self._contactTrapParts[contactKey] = nil
			self._activeContacts[contactKey] = nil
		end
	end
end

function TrapService:_updateContactCountFromKey(contactKey: string, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model, delta: number)
	local previous = self._contactCounts[contactKey] or 0
	local nextCount = math.max(0, previous + delta)
	local handler = self._behaviorHandlers[trapConfig.Behavior]

	if nextCount == 0 then
		self._contactCounts[contactKey] = nil
	else
		self._contactCounts[contactKey] = nextCount
	end

	if delta > 0 and previous == 0 and handler and handler.Begin then
		local userId = tonumber(string.match(contactKey, "^(%-?%d+):"))
		local player = userId and Players:GetPlayerByUserId(userId)
		if player then
			handler.Begin(self, player, trapPart, trapType, trapConfig, sourceRoot, contactKey)
		end
	elseif delta < 0 and previous > 0 and nextCount == 0 and handler and handler.End then
		local userId = tonumber(string.match(contactKey, "^(%-?%d+):"))
		local player = userId and Players:GetPlayerByUserId(userId)
		if player then
			handler.End(self, player, trapPart, trapType, trapConfig, sourceRoot, contactKey)
		end
	end
end

function TrapService:_updateContactCount(player: Player, trapPart: BasePart, delta: number)
	local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
	if not (trapType and trapConfig and sourceRoot) then
		return
	end
	local contactKey = self:_getContactKey(player, trapType, sourceRoot)
	self._contactTrapParts[contactKey] = trapPart
	self:_updateContactCountFromKey(contactKey, trapPart, trapType, trapConfig, sourceRoot, delta)
end

function TrapService:_beginTrapContact(player: Player, trapPart: BasePart)
	self:_updateContactCount(player, trapPart, 1)
end

function TrapService:_endTrapContact(player: Player, trapPart: BasePart)
	self:_updateContactCount(player, trapPart, -1)
end

return TrapService
