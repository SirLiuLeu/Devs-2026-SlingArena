--!strict

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PawnLocator = require(ReplicatedStorage.Shared.Utils.PawnLocator)

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local GachaRewardConfig = require(ReplicatedStorage.Shared.Config.GachaRewardConfig)
local GachaSpinLogic = require(ReplicatedStorage.Shared.Utils.GachaSpinLogic)

local SpinUIController = {}
SpinUIController.__index = SpinUIController

function SpinUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, SpinUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._activeTween = nil
	self._isInsideZone = false
	return self
end

function SpinUIController:_resolve()
	self._spinGui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.MainHub.Panels.Spin)
	self._root = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Spin.Root)
	self._spin1 = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Spin.Spin1)
	self._spin2 = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Spin.Spin2)
	self._closeButton = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Spin.CloseButton)
	self._wheel = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Spin.Wheel)
	self._gachaModel = PathResolver.resolvePath(Workspace, ProjectTreeSpec.World.GachaSpin.Model)
end

function SpinUIController:SetVisible(isVisible: boolean)
	if self._spinGui and self._spinGui:IsA("ScreenGui") then
		self._spinGui.Enabled = isVisible
	end
end

function SpinUIController:_playSpin(fullRotations: number)
	if not (self._wheel and self._wheel:IsA("GuiObject")) then
		warn("[SPIN_UI] SpinUI.Root.WheelContainer.GachaWheel is missing")
		return
	end

	local reward = GachaSpinLogic.SelectReward(Random.new(), GachaRewardConfig.GetRewards())
	if not reward then
		return
	end
	local landingRotation = GachaSpinLogic.ComputeLandingRotation(reward.id, fullRotations)
	if self._activeTween then
		self._activeTween:Cancel()
		self._activeTween = nil
	end
	local tween = TweenService:Create(self._wheel, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = self._wheel.Rotation + landingRotation,
	})
	self._activeTween = tween
	tween:Play()
	tween.Completed:Connect(function()
		local normalizedPointer = (360 - (self._wheel.Rotation % 360)) % 360
		local slices = GachaSpinLogic.BuildSlices(GachaRewardConfig.GetRewards())
		local resolvedReward = GachaSpinLogic.ResolveRewardAtAngle(slices, normalizedPointer)
		if not resolvedReward or resolvedReward.id ~= reward.id then
			warn(string.format("[SPIN_UI] UI mismatch logic=%s visual=%s", reward.id, resolvedReward and resolvedReward.id or "nil"))
		end
	end)
end

function SpinUIController:_bindButtons()
	if self._spin1 and self._spin1:IsA("TextButton") then
		table.insert(self._connections, self._spin1.MouseButton1Click:Connect(function()
			self:_playSpin(4)
		end))
	end
	if self._spin2 and self._spin2:IsA("TextButton") then
		table.insert(self._connections, self._spin2.MouseButton1Click:Connect(function()
			self:_playSpin(6)
		end))
	end
	if self._closeButton and self._closeButton:IsA("TextButton") then
		table.insert(self._connections, self._closeButton.MouseButton1Click:Connect(function()
			self:SetVisible(false)
		end))
	end
end

function SpinUIController:_bindWorldTrigger()
	if not self._gachaModel then
		warn("[SPIN_UI] Workspace.Maps.LobbyMap.GachaSpin missing")
		return
	end
	for _, descendant in ipairs(self._gachaModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(self._connections, descendant.Touched:Connect(function()
				self:SetVisible(true)
			end))
		end
	end

	table.insert(self._connections, game:GetService("RunService").Heartbeat:Connect(function()
		local hrp = PawnLocator.GetRootPart(PawnLocator.GetLocalPawn())
		local modelPart = self._gachaModel:IsA("Model") and self._gachaModel.PrimaryPart or nil
		if not (hrp and hrp:IsA("BasePart") and modelPart) then
			return
		end
		local inRadius = (hrp.Position - modelPart.Position).Magnitude <= 18
		if inRadius and not self._isInsideZone then
			self._isInsideZone = true
			self:SetVisible(true)
		elseif (not inRadius) and self._isInsideZone then
			self._isInsideZone = false
			self:SetVisible(false)
		end
	end))
end

function SpinUIController:Start()
	-- [UI_CREATION_GUIDE]
	-- Create in Studio:
	-- StarterGui
	--   SpinUI (ScreenGui)
	--     Root (Frame)
	--       WheelContainer (Frame)
	--         GachaWheel (ImageLabel)
	--         Pointer (ImageLabel)
	--       Buttons (Frame)
	--         Spin1 (TextButton)
	--         Spin2 (TextButton)
	--       CloseButton (TextButton)
	self:_resolve()
	self:_bindButtons()
	self:_bindWorldTrigger()
end

function SpinUIController:Destroy()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	if self._activeTween then
		self._activeTween:Cancel()
		self._activeTween = nil
	end
end

return SpinUIController
