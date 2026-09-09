--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local WorldProximityUIController = {}
WorldProximityUIController.__index = WorldProximityUIController
local RANGE = 10

local function findPart(path: { string }): BasePart?
	local current: Instance = Workspace
	for _, name in ipairs(path) do current = current:FindFirstChild(name) :: Instance; if not current then return nil end end
	return current:IsA("BasePart") and current or nil
end

function WorldProximityUIController.new(shopController, launcherController)
	return setmetatable({ _shop = shopController, _launcher = launcherController, _inside = {} }, WorldProximityUIController)
end

function WorldProximityUIController:Start()
	self._shopPart = findPart({ "Maps", "LobbyMap", "Shop", "ShopGUI_Part" })
	self._launcherPart = findPart({ "Maps", "LobbyMap", "Launcher", "LauncherInventoryGUI_Part" })
	-- Heartbeat + PawnLocator makes this independent of HumanoidRootPart and .Touched hitboxes.
	self._connection = RunService.Heartbeat:Connect(function()
		local pawn = PawnLocator.GetLocalPawn()
		local root = pawn and PawnLocator.GetRootPart(pawn)
		if not root then return end
		self:_update("shop", self._shopPart, root, function(inside) self._shop:SetVisible(inside) end)
		self:_update("launcher", self._launcherPart, root, function(inside) self._launcher:SetVisible(inside) end)
	end)
end
function WorldProximityUIController:_update(key, part, root, callback)
	if not part then return end
	local inside = (part.Position - root.Position).Magnitude < RANGE
	if self._inside[key] ~= inside then self._inside[key] = inside; callback(inside) end
end
function WorldProximityUIController:Destroy() if self._connection then self._connection:Disconnect() end end
return WorldProximityUIController
