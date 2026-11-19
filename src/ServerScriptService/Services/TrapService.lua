--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)
local ServiceResolver = require(script.Parent.Infrastructure.ServiceResolver)
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
	if trapPart.Name ~= "Lava_Hitbox" then
		return nil, nil, nil
	end

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

function TrapService.new(context)
	local self = setmetatable({}, TrapService)
	self._context = context
	self._lastTriggeredAt = {} :: { [string]: number }
	self._trapConnections = {}
	self._activeContacts = {} :: { [string]: boolean }
	self._contactMissedAt = {} :: { [string]: number }
	self._contactDamageStacks = {} :: { [string]: number }
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
		if not trap:IsA("Model") or trap.Name ~= "LavaTrap" then
			continue
		end

		local hitbox = trap:FindFirstChild("Lava_Hitbox")
		if hitbox and hitbox:IsA("BasePart") then
			table.insert(parts, hitbox)
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
	table.clear(self._contactMissedAt)
	table.clear(self._contactDamageStacks)
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

function TrapService:_applyLavaContactTick(
	player: Player,
	trapPart: BasePart,
	trapType: string,
	trapConfig: any,
	sourceRoot: Model,
	damageAmount: number
)
	local flagName = trapConfig.Flag
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	local damagePipeline = ServiceResolver.Get(self._context, "DamagePipelineService")
	if not (flagName and stateService and damagePipeline) then
		return
	end

	local state = stateService:GetState(player)
	if not state or not state.IsAlive then
		return
	end

	local sourceId = getTrapSourceId(sourceRoot, trapType)
	local tickInterval = math.max(0.05, tonumber(trapConfig.DamageInterval) or 0.3)
	local duration = math.max(tickInterval + 0.25, tonumber(trapConfig.ContactSlowDuration) or 0)
	stateService:ApplyFlag(player, flagName, duration, sourceRoot, {
		SourceId = sourceId,
		Stackable = false,
		MaxStack = 1,
	})

	local slowAmount = math.max(0, tonumber(trapConfig.ContactSlowAmount) or 0)
	if slowAmount > 0 then
		stateService:ApplyFlag(player, "Slow", duration, sourceRoot, {
			SourceId = `${sourceId}:Slow`,
			SlowAmount = slowAmount,
		})
	end

	damagePipeline:ApplyDoTDamage(player, damageAmount, trapPart, flagName)
end

function TrapService:_stopLavaContact(player: Player, trapType: string, trapConfig: any, sourceRoot: Model)
	local stateService = ServiceResolver.Get(self._context, "PlayerStateService")
	if not stateService then
		return
	end

	local sourceId = getTrapSourceId(sourceRoot, trapType)
	if trapConfig.Flag then
		stateService:RemoveFlag(player, trapConfig.Flag, sourceRoot, { SourceId = sourceId })
	end
	stateService:RemoveFlag(player, "Slow", sourceRoot, { SourceId = `${sourceId}:Slow` })
end

TrapService._behaviorHandlers = {
	ContactRamp = {
		Begin = function(self, player: Player, trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model, contactKey: string)
			if self._activeContacts[contactKey] then
				return
			end

			self._activeContacts[contactKey] = true
			self._contactDamageStacks[contactKey] = 0
			SoundManager.Play("SFX_TrapHit", trapPart.Position)
			self:_emitPopup(player, trapConfig)

			local damageInterval = math.max(0.05, tonumber(trapConfig.DamageInterval) or 0.3)
			local damagePerStack = math.max(1, tonumber(trapConfig.DamagePerStack) or 100)
			local maxDamage = math.max(damagePerStack, tonumber(trapConfig.MaxDamagePerTick) or 2000)
			local maxStacks = math.max(1, math.ceil(maxDamage / damagePerStack))

			task.spawn(function()
				while self._activeContacts[contactKey] do
					local damageStack = math.min((self._contactDamageStacks[contactKey] or 0) + 1, maxStacks)
					self._contactDamageStacks[contactKey] = damageStack
					local damageAmount = math.min(damageStack * damagePerStack, maxDamage)
					self:_applyLavaContactTick(player, trapPart, trapType, trapConfig, sourceRoot, damageAmount)
					task.wait(damageInterval)
				end
			end)
		end,
		End = function(self, player: Player, _trapPart: BasePart, trapType: string, trapConfig: any, sourceRoot: Model, contactKey: string)
			self._activeContacts[contactKey] = nil
			self._contactMissedAt[contactKey] = nil
			self._contactDamageStacks[contactKey] = nil
			self:_stopLavaContact(player, trapType, trapConfig, sourceRoot)
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

	local playerService = ServiceResolver.Get(self._context, "PlayerService")
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
				self._contactMissedAt[contactKey] = nil
				if not self._contactCounts[contactKey] then
					self._contactTrapParts[contactKey] = trapPart
					self:_beginTrapContact(player, trapPart)
				end
			end
		end
	end

	local now = os.clock()
	for contactKey in pairs(self._contactCounts) do
		if not observedContacts[contactKey] then
			local trapPart = self._contactTrapParts[contactKey]
			local canResolveTrap = false
			if trapPart then
				local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
				if trapType and trapConfig and sourceRoot then
					canResolveTrap = true
					local missedAt = self._contactMissedAt[contactKey]
					if not missedAt then
						self._contactMissedAt[contactKey] = now
					else
						local graceDuration = math.max(0, tonumber(trapConfig.ContactExitGraceDuration) or 0.45)
						if now - missedAt >= graceDuration then
							self:_updateContactCountFromKey(contactKey, trapPart, trapType, trapConfig, sourceRoot, -1)
							self._activeContacts[contactKey] = nil
							self._contactDamageStacks[contactKey] = nil
							self._contactTrapParts[contactKey] = nil
							self._contactMissedAt[contactKey] = nil
						end
					end
				end
			end

			if not canResolveTrap then
				-- The trap was removed or became invalid; do not leave a live ramp task behind.
				self._activeContacts[contactKey] = nil
				self._contactCounts[contactKey] = nil
				self._contactTrapParts[contactKey] = nil
				self._contactMissedAt[contactKey] = nil
				self._contactDamageStacks[contactKey] = nil
			end
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
