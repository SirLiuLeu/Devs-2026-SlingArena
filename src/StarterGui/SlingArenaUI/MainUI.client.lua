--!strict

local Players = game:GetService("Players")

local UIController = require(script.Parent.UIController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SlingArenaMainUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local controller = UIController.new(screenGui)
controller:Start()
