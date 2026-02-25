--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

export type LeaderboardRow = {
	UserId: number,
	Name: string,
	Level: number,
	Size: number,
	Kills: number,
}

export type LeaderboardUI = {
	Root: Frame,
	Visible: boolean,
	Toggle: (self: LeaderboardUI) -> (),
	Update: (self: LeaderboardUI, leaderboardData: {LeaderboardRow}) -> (),
	Destroy: (self: LeaderboardUI) -> (),
}

local localPlayer = Players.LocalPlayer

local LeaderboardUI = {}
LeaderboardUI.__index = LeaderboardUI

function LeaderboardUI.new(parent: Instance): LeaderboardUI
	local root = Instance.new("Frame")
	root.Name = "Leaderboard"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.fromScale(0.5, -0.75)
	root.Size = UDim2.fromScale(0.64, 0.7)
	root.BackgroundColor3 = Color3.fromRGB(12, 13, 19)
	root.BackgroundTransparency = 0.1
	root.BorderSizePixel = 0
	root.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.05, 0)
	corner.Parent = root

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.03, 0.025)
	title.Size = UDim2.fromScale(0.94, 0.07)
	title.Text = "Leaderboard [Tab]"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(230, 245, 255)
	title.Parent = root

	local headers = Instance.new("TextLabel")
	headers.BackgroundTransparency = 1
	headers.Position = UDim2.fromScale(0.03, 0.1)
	headers.Size = UDim2.fromScale(0.94, 0.055)
	headers.Text = "#      Player                       Lvl      Size      Kills"
	headers.Font = Enum.Font.Code
	headers.TextScaled = true
	headers.TextColor3 = Color3.fromRGB(130, 165, 220)
	headers.TextXAlignment = Enum.TextXAlignment.Left
	headers.Parent = root

	local scrolling = Instance.new("ScrollingFrame")
	scrolling.BackgroundTransparency = 1
	scrolling.Position = UDim2.fromScale(0.03, 0.16)
	scrolling.Size = UDim2.fromScale(0.94, 0.81)
	scrolling.ScrollBarThickness = 6
	scrolling.CanvasSize = UDim2.fromScale(0, 0)
	scrolling.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.006, 0)
	layout.Parent = scrolling

	return setmetatable({
		Root = root,
		Scrolling = scrolling,
		Layout = layout,
		Rows = {},
		LastRanks = {},
		Visible = false,
	}, LeaderboardUI) :: any
end

local function formatRow(rank: number, row: LeaderboardRow): string
	return string.format("%-2d   %-24s %-7d %-8.1f %-5d", rank, row.Name, row.Level, row.Size, row.Kills)
end

function LeaderboardUI:Toggle()
	self.Visible = not self.Visible
	TweenService:Create(self.Root, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = if self.Visible then UDim2.fromScale(0.5, 0.03) else UDim2.fromScale(0.5, -0.75),
	}):Play()
end

function LeaderboardUI:Update(leaderboardData: {LeaderboardRow})
	table.sort(leaderboardData, function(a, b)
		if a.Level == b.Level then
			return a.Kills > b.Kills
		end
		return a.Level > b.Level
	end)

	local maxRows = math.min(#leaderboardData, 50)

	for index = 1, maxRows do
		local rowData = leaderboardData[index]
		local key = tostring(rowData.UserId)
		local rowLabel = self.Rows[key]
		if not rowLabel then
			rowLabel = Instance.new("TextLabel")
			rowLabel.Name = key
			rowLabel.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
			rowLabel.BackgroundTransparency = 0.2
			rowLabel.BorderSizePixel = 0
			rowLabel.Size = UDim2.fromScale(1, 0.06)
			rowLabel.Font = Enum.Font.Code
			rowLabel.TextScaled = true
			rowLabel.TextXAlignment = Enum.TextXAlignment.Left
			rowLabel.Parent = self.Scrolling
			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0.15, 0)
			rowCorner.Parent = rowLabel
			self.Rows[key] = rowLabel
		end

		rowLabel.LayoutOrder = index
		rowLabel.Visible = true
		rowLabel.Text = formatRow(index, rowData)

		local isLocal = rowData.UserId == localPlayer.UserId
		rowLabel.TextColor3 = if isLocal then Color3.fromRGB(255, 238, 145) else Color3.fromRGB(220, 232, 255)
		rowLabel.BackgroundColor3 = if isLocal then Color3.fromRGB(58, 54, 28) else Color3.fromRGB(22, 24, 33)

		local lastRank = self.LastRanks[key]
		if lastRank and lastRank ~= index then
			TweenService:Create(rowLabel, TweenInfo.new(0.2), {
				BackgroundTransparency = 0,
			}):Play()
			task.delay(0.22, function()
				if rowLabel.Parent then
					TweenService:Create(rowLabel, TweenInfo.new(0.25), {
						BackgroundTransparency = if isLocal then 0.15 else 0.2,
					}):Play()
				end
			end)
		end
		self.LastRanks[key] = index
	end

	for key, rowLabel in pairs(self.Rows) do
		if rowLabel.LayoutOrder > maxRows then
			rowLabel.Visible = false
		end
	end

	self.Scrolling.CanvasSize = UDim2.fromScale(0, (0.066 * maxRows) + 0.02)
end

function LeaderboardUI:Destroy()
	self.Root:Destroy()
end

return LeaderboardUI
