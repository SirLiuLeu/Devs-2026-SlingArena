--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationConfigData = require(ReplicatedStorage.Shared.Config.NotificationConfigData)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local NotificationService = {}
NotificationService.__index = NotificationService

type Context = { Remotes: Instance, EventBus: any, Services: any }

type NotificationPayload = {
	Type: string,
	I18nKey: string?,
	Priority: number?,
	Args: { [string]: any }?,
	Text: string?,
	CreatedAt: number?,
}

function NotificationService.new(context: Context)
	local self = setmetatable({}, NotificationService)
	self._context = context
	self._remote = context.Remotes:FindFirstChild(RemoteContracts.Names.Notification) :: RemoteEvent?
	self._connections = {} :: { RBXScriptConnection }
	return self
end

function NotificationService:Init() end

function NotificationService:Start()
	local eventBus = self._context.EventBus
	if not eventBus then
		return
	end
	table.insert(self._connections, eventBus:On("PlayerRewardGranted", function(player: Player, reward: any, reason: string?)
		self:_handleRewardGranted(player, reward, reason)
	end))
	table.insert(self._connections, eventBus:On("PlayerKilled", function(killer: Player, victim: Player)
		self:_handlePlayerKilled(killer, victim)
	end))
	table.insert(self._connections, eventBus:On("RoundStateChanged", function(payload: any)
		self:_handleRoundStateChanged(payload)
	end))
	table.insert(self._connections, eventBus:On("ArenaJoinCooldown", function(player: Player, remainingSeconds: number)
		self:_send(player, "ArenaJoinCooldown", { seconds = math.max(1, math.ceil(remainingSeconds)) })
	end))
end

function NotificationService:_build(notificationType: string, args: { [string]: any }?, text: string?): NotificationPayload
	local config = NotificationConfigData.Get(notificationType)
	return {
		Type = config.Type,
		I18nKey = config.I18nKey,
		Priority = config.Priority,
		Args = args or {},
		Text = text,
		CreatedAt = os.clock(),
	}
end

function NotificationService:_send(player: Player?, notificationType: string, args: { [string]: any }?, text: string?)
	if not player or not self._remote then
		return
	end
	self._remote:FireClient(player, self:_build(notificationType, args, text))
end

function NotificationService:_sendAll(notificationType: string, args: { [string]: any }?, text: string?)
	if not self._remote then
		return
	end
	self._remote:FireAllClients(self:_build(notificationType, args, text))
end

function NotificationService:_handleRewardGranted(player: Player, reward: any, reason: string?)
	if type(reward) ~= "table" then
		return
	end
	local diamonds = math.max(0, math.floor(tonumber(reward.Diamonds or reward.diamonds) or 0))
	if diamonds <= 0 then
		return
	end
	self:_send(player, "DiamondReward", { amount = diamonds, reason = reason or "Reward" })
end

function NotificationService:_handlePlayerKilled(killer: Player, victim: Player)
	if killer == victim then
		return
	end
	self:_send(killer, "PlayerKill", {
		killerName = killer.DisplayName or killer.Name,
		victimName = victim.DisplayName or victim.Name,
	})
end

function NotificationService:_handleRoundStateChanged(payload: any)
	local state = if type(payload) == "table" then tostring(payload.State or "") else tostring(payload or "")
	if state == "" then
		return
	end
	self:_sendAll("RoundState", {
		state = state,
		previousState = if type(payload) == "table" then payload.PreviousState else nil,
		roundId = if type(payload) == "table" then payload.RoundId else nil,
	})
end

function NotificationService:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
end

-- Example standardized EventBus dispatches consumed by NotificationService:
-- context.EventBus:Fire("PlayerRewardGranted", player, { Diamonds = 100 }, "QuestClaim")
-- context.EventBus:Fire("PlayerKilled", killerPlayer, victimPlayer)
-- context.EventBus:Fire("RoundStateChanged", { State = "EarlyGame", PreviousState = "Awaits", RoundId = 3 })
-- context.EventBus:Fire("ArenaJoinCooldown", player, 12.4)

return NotificationService
