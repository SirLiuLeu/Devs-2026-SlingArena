--!strict

local Workspace = game:GetService("Workspace")

local DEFAULT_RADIUS = 6
local PULL_ALPHA = 0.18
local MAX_PER_TICK = 24

local Magnet = {}

local function getRoot(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

function Magnet.OnLaunch(_context, _payload) end
function Magnet.OnCollision(_context, _collisionType: string, _target: any, _payload: any) end

function Magnet.OnTick(context, _dt: number)
	local playerService = context.PlayerService
	local playerRoot = playerService and playerService:GetRoot(context.player)
	if not (playerRoot and playerRoot:IsA("BasePart")) then return end

	local pulled = 0
	for _, descendant in Workspace:GetDescendants() do
		if pulled >= MAX_PER_TICK then break end
		if descendant:IsA("Model") and descendant:GetAttribute("FoodRarity") == "Common" and descendant:GetAttribute("FoodId") ~= nil then
			local foodRoot = getRoot(descendant)
			if foodRoot and not foodRoot.Anchored then
				local offset = playerRoot.Position - foodRoot.Position
				local radius = math.max(0, tonumber((context.definition.passiveAbility or {}).value) or DEFAULT_RADIUS)
				if offset.Magnitude <= radius then
					foodRoot.AssemblyLinearVelocity = foodRoot.AssemblyLinearVelocity:Lerp(offset.Unit * math.min(offset.Magnitude * 8, 60), PULL_ALPHA)
					pulled += 1
				end
			end
		end
	end
end

function Magnet.OnAttack(_context, _payload: any) end

return Magnet
