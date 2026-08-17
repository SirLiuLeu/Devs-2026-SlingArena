--!strict

local BaseAbility = {}
BaseAbility.__index = BaseAbility

function BaseAbility.new(context, player: Player, config)
	local self = setmetatable({}, BaseAbility)
	self.Context = context
	self.Player = player
	self.Config = config or {}
	self.State = {}
	return self
end

function BaseAbility:OnInit(_launcherModel: Model?) end
function BaseAbility:OnLaunch(_contextData: any) end
function BaseAbility:OnCollision(_contextData: any) end
function BaseAbility:OnTick(_dt: number) end
function BaseAbility:OnDestroy() end

return BaseAbility
