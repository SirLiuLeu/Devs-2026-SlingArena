--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local EventBus = require(ServerScriptService.Services.Infrastructure.EventBus)
local ServiceRegistry = require(ServerScriptService.Services.Infrastructure.ServiceRegistry)
local PlayerStateService = require(ServerScriptService.Services.PlayerStateService)

type IPlayerStateService = PlayerStateService.IPlayerStateService

export type MockPlayerStateService = IPlayerStateService & {
	RecalculateCount: number,
	RuntimeDiamonds: number?,
}

export type MockPlayerStateServiceOptions = {
	isLauncher: boolean?,
}

export type TestContext = {
	EventBus: any,
	Services: { [string]: any },
	ServiceRegistry: any,
}

local TestContext = {}

-- Canonical fixture for services that only need PlayerStateService's public
-- contract. Its no-op methods deliberately make event callbacks safe in tests.
function TestContext.newMockPlayerStateService(options: MockPlayerStateServiceOptions?): MockPlayerStateService
	local isLauncher = options and options.isLauncher == true
	local mock = {
		RecalculateCount = 0,
		IsLauncher = function(_self: MockPlayerStateService, _player: Player): boolean return isLauncher end,
		IsHuman = function(_self: MockPlayerStateService, _player: Player): boolean return true end,
		GetState = function(_self: MockPlayerStateService, _player: Player): any return nil end,
		RecalculateDerivedStats = function(self: MockPlayerStateService, _player: Player, _forcePublish: boolean?) self.RecalculateCount += 1 end,
		Heal = function(_self: MockPlayerStateService, _player: Player, _amount: number) end,
		PublishState = function(_self: MockPlayerStateService, _player: Player) end,
	}
	return mock :: any
end

function TestContext.new(): TestContext
	local registry = ServiceRegistry.new()
	local services: { [string]: any } = {}
	local playerStateService = TestContext.newMockPlayerStateService()
	registry:Register("PlayerStateService", playerStateService)
	services.PlayerStateService = playerStateService
	return {
		EventBus = EventBus.new(),
		Services = services,
		ServiceRegistry = registry,
	}
end

return TestContext
