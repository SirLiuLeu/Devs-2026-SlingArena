--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PawnLocator = {}

local function getPawnsFolder(): Folder?
	local folder = Workspace:FindFirstChild("LauncherPawns")
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

function PawnLocator.GetPawnByPlayer(player: Player): Model?
	if player.Character and player.Character:IsA("Model") then
		return player.Character
	end

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
	local root = pawn:FindFirstChild("Hitbox", true)
	if root and root:IsA("BasePart") then
		return root
	end
	if pawn.PrimaryPart and pawn.PrimaryPart:IsA("BasePart") then
		return pawn.PrimaryPart
	end
	return pawn:FindFirstChildWhichIsA("BasePart")
end

return PawnLocator
