--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryDataProvider = require(ReplicatedStorage.Client.Services.InventoryDataProvider)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local provider = InventoryDataProvider.GetDefault()

local giveSlingButton = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.InventoryTest.GiveSlingButton)
if not giveSlingButton or not giveSlingButton:IsA("TextButton") then
	warn("[INVENTORY_TEST_UI] GiveSlingButton missing")
else
	giveSlingButton.MouseButton1Click:Connect(function()
		provider:GiveTestSling()
	end)
end

local giveItemButton = PathResolver.resolvePath(playerGui, ProjectTreeSpec.UI.InventoryTest.GiveItemButton)
if not giveItemButton or not giveItemButton:IsA("TextButton") then
	warn("[INVENTORY_TEST_UI] GiveItemButton missing")
else
	giveItemButton.MouseButton1Click:Connect(function()
		provider:GiveTestItem()
	end)
end
