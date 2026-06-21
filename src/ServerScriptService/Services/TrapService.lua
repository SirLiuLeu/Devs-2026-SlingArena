--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrapConfig = require(ReplicatedStorage.Shared.Config.TrapConfig)
local TrapService = {}
TrapService.__index = TrapService

local function getArenaMapModel(): Model?
	local mapsRoot = Workspace:FindFirstChild("Maps")
	if mapsRoot and mapsRoot:IsA("Folder") then
		local nestedArena = mapsRoot:FindFirstChild("ArenaMap")
		if nestedArena and nestedArena:IsA("Model") then
			return nestedArena
		end
	end

	local directArena = Workspace:FindFirstChild("ArenaMap")
	if directArena and directArena:IsA("Model") then
		return directArena
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

local function getAttributedTrapModel(part: BasePart): (Model?, string?, any?)
	local current: Instance? = part
	while current do
		if current:IsA("Model") then
			local trapTypeAttribute = current:GetAttribute("TrapType")
			if type(trapTypeAttribute) == "string" then
				local trapConfig = (TrapConfig.Types or {})[trapTypeAttribute]
				if trapConfig then
					return current, trapTypeAttribute, trapConfig
				end
			end
		end
		current = current.Parent
	end
	return nil, nil, nil
end

local function getTrapInfo(trapPart: BasePart): (string?, any?, Model?)
	local trapModel, trapType, trapConfig = getAttributedTrapModel(trapPart)
	return trapType, trapConfig, trapModel
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
	self._trapTouchedConnections = {}
	self._activeContacts = {} :: { [string]: boolean }
	self._contactCounts = {} :: { [string]: number }
	self._boundTrapParts = {} :: { [BasePart]: boolean }
	return self
end

function TrapService:Init()
	-- TrapService owns trap collision exclusively through server Touched/TouchEnded events.
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

function TrapService:_disconnectTrapTouched()
	for _, connection in ipairs(self._trapTouchedConnections) do
		connection:Disconnect()
	end
	table.clear(self._trapTouchedConnections)
	table.clear(self._activeContacts)
	table.clear(self._contactCounts)
	table.clear(self._boundTrapParts)
end

function TrapService:_getPlayerFromHit(hit: Instance): Player?
	local pawn = hit:FindFirstAncestorOfClass("Model")
	if not pawn then
		return nil
	end
	local playerService = self._context.Services.PlayerService
	return playerService and playerService:GetPlayerFromPawn(pawn) or nil
end

function TrapService:_bindTrapTouched(trapPart: BasePart)
	if self._boundTrapParts[trapPart] then
		return
	end
	if not getTrapInfo(trapPart) then
		return
	end
	self._boundTrapParts[trapPart] = true
	table.insert(self._trapTouchedConnections, trapPart.Touched:Connect(function(hit)
		local player = self:_getPlayerFromHit(hit)
		if player then
			self:_beginTrapContact(player, trapPart)
		end
	end))
	table.insert(self._trapTouchedConnections, trapPart.TouchEnded:Connect(function(hit)
		local player = self:_getPlayerFromHit(hit)
		if player then
			self:_endTrapContact(player, trapPart)
		end
	end))
end

function TrapService:_bindTrapDescendant(instance: Instance)
	if instance:IsA("BasePart") then
		self:_bindTrapTouched(instance)
	end
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
	self:_disconnectTrapTouched()
	for _, trapPart in ipairs(self:GetActiveTrapParts()) do
		self:_bindTrapTouched(trapPart)
	end
	table.insert(self._trapTouchedConnections, trapFolder.DescendantAdded:Connect(function(descendant)
		self:_bindTrapDescendant(descendant)
	end))
	task.defer(function()
		if trapFolder.Parent then
			for _, trapPart in ipairs(self:GetActiveTrapParts()) do
				self:_bindTrapTouched(trapPart)
			end
		end
	end)
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

function TrapService:_fireTrapPenalty(player: Player, trapConfig: any)
	local penalty = math.max(0, tonumber(trapConfig.ExpPenaltyOnHit) or 0)
	if penalty > 0 then
		self._context.EventBus:Fire("TrapCollision", player, penalty)
	end
end

function TrapService:_resolveKnockbackDirection(player: Player, trapPart: BasePart, trapConfig: any): Vector3
	local playerService = self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	local mode = trapConfig.KnockbackDirection or "AwayFromTrap"
	if mode == "TrapForward" then
		return trapPart.CFrame.LookVector
	end
	if mode == "TrapBackward" then
		return -trapPart.CFrame.LookVector
	end
	if root then
		local away = root.Position - trapPart.Position
		if away.Magnitude >= 0.01 then
			return away.Unit
		end
	end
	return Vector3.new(1, 0, 0)
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
		damageApplied = damagePipeline:ApplyHitDamage(player, trapConfig.Damage, nil, nil, { SuppressKnockback = true }) == true
	end
	if not damageApplied then
		return
	end
	self._lastTriggeredAt[cooldownKey] = now
	self:_fireTrapPenalty(player, trapConfig)

	local playerService = self._context.Services.PlayerService
	local root = playerService and playerService:GetRoot(player)
	local knockback = math.max(0, tonumber(trapConfig.Knockback) or 0)
	local upwardBoost = math.max(0, tonumber(trapConfig.UpwardBoost) or 0)
	if root and (knockback > 0 or upwardBoost > 0) then
		local direction = self:_resolveKnockbackDirection(player, trapPart, trapConfig)
		root.AssemblyLinearVelocity += direction.Unit * knockback + Vector3.new(0, upwardBoost, 0)
	end
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
		self:_fireTrapPenalty(player, trapConfig)
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

function TrapService:_updateContactCount(player: Player, trapPart: BasePart, delta: number)
	local trapType, trapConfig, sourceRoot = getTrapInfo(trapPart)
	if not (trapType and trapConfig and sourceRoot) then
		return
	end
	local contactKey = self:_getContactKey(player, trapType, sourceRoot)
	local previous = self._contactCounts[contactKey] or 0
	local nextCount = math.max(0, previous + delta)
	local handler = self._behaviorHandlers[trapConfig.Behavior]

	if nextCount == 0 then
		self._contactCounts[contactKey] = nil
	else
		self._contactCounts[contactKey] = nextCount
	end

	if delta > 0 and previous == 0 and handler and handler.Begin then
		handler.Begin(self, player, trapPart, trapType, trapConfig, sourceRoot, contactKey)
	elseif delta < 0 and previous > 0 and nextCount == 0 and handler and handler.End then
		handler.End(self, player, trapPart, trapType, trapConfig, sourceRoot, contactKey)
	end
end

function TrapService:_beginTrapContact(player: Player, trapPart: BasePart)
	self:_updateContactCount(player, trapPart, 1)
end

function TrapService:_endTrapContact(player: Player, trapPart: BasePart)
	self:_updateContactCount(player, trapPart, -1)
end

return TrapService
