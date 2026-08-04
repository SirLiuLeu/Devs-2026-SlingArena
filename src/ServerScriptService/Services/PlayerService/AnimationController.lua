--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local LauncherAnimationIds = require(ReplicatedStorage.Shared.Config.LauncherAnimationIds)

local LauncherAnimationController = {}
LauncherAnimationController.__index = LauncherAnimationController

local TRACK_NAMES = { "Idle", "Movement", "Charge", "Launch", "Knockback" }
local LOOPED = {
	Idle = true,
	Movement = true,
	Charge = true,
	Launch = false,
	Knockback = false,
}
local PRIORITY = {
	Idle = Enum.AnimationPriority.Idle,
	Movement = Enum.AnimationPriority.Movement,
	Charge = Enum.AnimationPriority.Action,
	Launch = Enum.AnimationPriority.Action2,
	Knockback = Enum.AnimationPriority.Action3,
}

local function normalizeAnimationId(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local trimmed = string.gsub(value, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return nil
	end
	if string.match(trimmed, "^%d+$") then
		return "rbxassetid://" .. trimmed
	end
	return trimmed
end

local function getOrCreateAnimator(rig: Model): Animator
	local animationController = rig:FindFirstChildOfClass("AnimationController")
	if not animationController then
		animationController = Instance.new("AnimationController")
		animationController.Name = "LauncherAnimationController"
		animationController.Parent = rig
	end

	local animator = animationController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animationController
	end
	return animator
end

function LauncherAnimationController.new(pawn: Model, rig: Model)
	local self = setmetatable({}, LauncherAnimationController)
	self._pawn = pawn
	self._rig = rig
	self._animator = getOrCreateAnimator(rig)
	self._tracks = {}
	self._currentState = nil
	self._destroyed = false

	for _, name in TRACK_NAMES do
		local animationId = normalizeAnimationId(LauncherAnimationIds[name])
		if animationId then
			local animation = Instance.new("Animation")
			animation.Name = "Launcher" .. name .. "Animation"
			animation.AnimationId = animationId
			local track = self._animator:LoadAnimation(animation)
			track.Name = "Launcher" .. name
			track.Looped = LOOPED[name] == true
			track.Priority = PRIORITY[name]
			self._tracks[name] = track
			animation:Destroy()
		end
	end

	return self
end

function LauncherAnimationController:_stopExcept(stateName: string?, fadeTime: number?)
	for name, track in pairs(self._tracks) do
		if name ~= stateName and track.IsPlaying then
			track:Stop(fadeTime or 0.12)
		end
	end
end

function LauncherAnimationController:_play(stateName: string, fadeTime: number?)
	local track = self._tracks[stateName]
	self:_stopExcept(stateName, fadeTime)
	if not track then
		self._currentState = stateName
		return
	end
	if not track.IsPlaying then
		track:Play(fadeTime or 0.12)
	elseif stateName == "Launch" or stateName == "Knockback" then
		track.TimePosition = 0
	end
	self._currentState = stateName
end

function LauncherAnimationController:_resolveState(state: any): string?
	if not state or state.IsAlive == false then
		return nil
	end
	local movementState = state.MovementState
	if movementState == GameStates.PlayerState.Knockback then
		return "Knockback"
	elseif movementState == GameStates.PlayerState.Launching then
		return "Launch"
	elseif state.IsCharging == true or movementState == GameStates.PlayerState.Charging then
		return "Charge"
	elseif movementState == GameStates.PlayerState.Moving then
		return "Movement"
	elseif movementState == GameStates.PlayerState.Idle then
		return "Idle"
	end
	return nil
end

function LauncherAnimationController:ApplyState(state: any)
	if self._destroyed then
		return
	end
	local nextState = self:_resolveState(state)
	if not nextState then
		self:_stopExcept(nil, 0.08)
		self._currentState = nil
		return
	end
	if nextState == self._currentState then
		return
	end
	self:_play(nextState, 0.12)
end

function LauncherAnimationController:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, track in pairs(self._tracks) do
		track:Stop(0)
		track:Destroy()
	end
	table.clear(self._tracks)
end

return LauncherAnimationController
