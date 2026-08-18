--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameStates = require(ReplicatedStorage.Shared.Constants.GameStates)
local PlayerModeState = require(ReplicatedStorage.Shared.Utils.PlayerModeState)

local PawnLocator = {}

local function getPawnsFolder(): Folder?
	local folder = Workspace:FindFirstChild("LauncherPawns")
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

local function getLauncherPawnByPlayer(player: Player): Model?
	local pawnsFolder = getPawnsFolder()
	if not pawnsFolder then
		return nil
	end
	local pawn = pawnsFolder:FindFirstChild(player.Name)
	if pawn and pawn:IsA("Model") then
		return pawn
	end
	local suffixPawn = pawnsFolder:FindFirstChild(player.Name .. "_Pawn")
	if suffixPawn and suffixPawn:IsA("Model") then
		return suffixPawn
	end
	return nil
end

function PawnLocator.GetPawnByPlayer(player: Player): Model?
	if not PlayerModeState.IsLauncherMode(player, nil) then
		return if player.Character and player.Character:IsA("Model") then player.Character else nil
	end

	local launcherPawn = getLauncherPawnByPlayer(player)
	if launcherPawn then
		return launcherPawn
	end
	return if player.Character and player.Character:IsA("Model") then player.Character else nil
end

function PawnLocator.GetLocalPawn(): Model?
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return nil
	end
	return PawnLocator.GetPawnByPlayer(localPlayer)
end

function PawnLocator.GetRootPart(pawn: Model?): BasePart?
	if not pawn then
		return nil
	end
	local humanoidRoot = pawn:FindFirstChild("HumanoidRootPart")
	if humanoidRoot and humanoidRoot:IsA("BasePart") then
		return humanoidRoot
	end
	local root = pawn:FindFirstChild("Hitbox", true)
	if root and root:IsA("BasePart") then
		return root
	end
	if pawn.PrimaryPart and pawn.PrimaryPart:IsA("BasePart") then
		return pawn.PrimaryPart
	end
	return pawn:FindFirstChildWhichIsA("BasePart")
end

function PawnLocator.GetLauncherPawnByPlayer(player: Player): Model?
	return getLauncherPawnByPlayer(player)
end

function PawnLocator.GetHumanCharacterByPlayer(player: Player): Model?
	return if player.Character and player.Character:IsA("Model") then player.Character else nil
end

return PawnLocator
