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
	for _, name in ipairs(path) do
		local child = current:FindFirstChild(name)
		if not child then return nil end
		current = child
	end
	return current:IsA("BasePart") and current or nil
end

function WorldProximityUIController.new(shopController, launcherController, petInventoryController)
	return setmetatable({
		_shop = shopController,
		_launcher = launcherController,
		_petInventory = petInventoryController,
		_inside = {},
	}, WorldProximityUIController)
end

function WorldProximityUIController:Start()
	self._shopPart = findPart({ "Maps", "LobbyMap", "Shop", "ShopGUI_Part" })
	self._launcherPart = findPart({ "Maps", "LobbyMap", "Launcher", "LauncherInventoryGUI_Part" })
	self._petInventoryPart = findPart({ "Maps", "LobbyMap", "Pet", "PetInventoryGUI_Part" })

	if self._petInventory and not self._petInventoryPart then
		warn("[WORLD_PROXIMITY_UI] Workspace.Maps.LobbyMap.Pet.PetInventoryGUI_Part is missing.")
	end

	-- Heartbeat + PawnLocator makes this independent of HumanoidRootPart and .Touched hitboxes.
	self._connection = RunService.Heartbeat:Connect(function()
		local pawn = PawnLocator.GetLocalPawn()
		local root = pawn and PawnLocator.GetRootPart(pawn)
		if not root then return end

		if self._shop then
			self:_update("shop", self._shopPart, root, function(inside)
				self._shop:SetVisible(inside)
			end)
		end
		if self._launcher then
			self:_update("launcher", self._launcherPart, root, function(inside)
				self._launcher:SetVisible(inside)
			end)
		end
		if self._petInventory then
			self:_update("petInventory", self._petInventoryPart, root, function(inside)
				self._petInventory:SetVisible(inside)
			end)
		end
	end)
end

function WorldProximityUIController:_update(key: string, part: BasePart?, root: BasePart, callback: (boolean) -> ())
	if not part then return end
	local inside = (part.Position - root.Position).Magnitude < RANGE
	if self._inside[key] ~= inside then
		self._inside[key] = inside
		callback(inside)
	end
end

function WorldProximityUIController:Destroy()
	if self._connection then
		self._connection:Disconnect()
		self._connection = nil
	end
end

return WorldProximityUIController
