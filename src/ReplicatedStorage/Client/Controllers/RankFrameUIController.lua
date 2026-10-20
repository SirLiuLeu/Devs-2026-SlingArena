--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local MAX_ROWS = 5

local RankFrameUIController = {}
RankFrameUIController.__index = RankFrameUIController

local function disconnectAll(connections: { RBXScriptConnection })
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function readPlayerLevel(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue and (levelValue:IsA("IntValue") or levelValue:IsA("NumberValue")) then
		return math.max(1, math.floor(levelValue.Value))
	end

	local levelAttribute = player:GetAttribute("Level")
	if typeof(levelAttribute) == "number" then
		return math.max(1, math.floor(levelAttribute))
	end

	return 1
end

function RankFrameUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, RankFrameUIController)
	self.PlayerGui = playerGui
	self.Connections = {}
	self.PlayerBindings = {}
	self.List = nil
	self.Template = nil
	self._started = false
	self._refreshQueued = false
	self._warnedMissingUi = false
	self._warnedInvalidTemplate = false
	return self
end

function RankFrameUIController:_resolveUi()
	local listPath = ProjectTreeSpec.UI.MainHub.RankFrameList
	local templatePath = ProjectTreeSpec.ReplicatedStorage.Assets.PlayerRowTemplate_RankFrame
	local list = PathResolver.resolvePath(self.PlayerGui, listPath, { shouldWarn = false })
	local template = PathResolver.resolvePath(ReplicatedStorage, templatePath, { shouldWarn = false })

	self.List = if list and list:IsA("GuiObject") then list else nil
	self.Template = if template and template:IsA("Frame") then template else nil

	if not self.List or not self.Template then
		if not self._warnedMissingUi then
			self._warnedMissingUi = true
			warn(string.format(
				"[RankFrameUI] Missing UI/template. Expected PlayerGui.%s and ReplicatedStorage.%s.",
				listPath,
				templatePath
			))
		end
	else
		self._warnedMissingUi = false
	end
end

function RankFrameUIController:_scheduleRefresh()
	if not self._started or self._refreshQueued then
		return
	end

	self._refreshQueued = true
	task.defer(function()
		self._refreshQueued = false
		if not self._started then
			return
		end
		self:_resolveUi()
		self:_render()
	end)
end

function RankFrameUIController:_bindLevelValue(player: Player, binding: any, value: Instance?)
	if binding.LevelValue == value then
		return
	end
	if binding.LevelConnection then
		binding.LevelConnection:Disconnect()
		binding.LevelConnection = nil
	end

	binding.LevelValue = if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then value else nil
	if binding.LevelValue then
		binding.LevelConnection = binding.LevelValue:GetPropertyChangedSignal("Value"):Connect(function()
			self:_scheduleRefresh()
		end)
	end
	self:_scheduleRefresh()
end

function RankFrameUIController:_watchLeaderstats(player: Player, binding: any, stats: Folder?)
	if binding.Stats == stats then
		return
	end

	disconnectAll(binding.StatsConnections)
	if binding.LevelConnection then
		binding.LevelConnection:Disconnect()
		binding.LevelConnection = nil
	end
	binding.Stats = stats
	binding.LevelValue = nil

	if stats then
		table.insert(binding.StatsConnections, stats.ChildAdded:Connect(function(child)
			if child.Name == "Level" then
				self:_bindLevelValue(player, binding, child)
			end
		end))
		table.insert(binding.StatsConnections, stats.ChildRemoved:Connect(function(child)
			if child == binding.LevelValue then
				self:_bindLevelValue(player, binding, nil)
			end
		end))
		self:_bindLevelValue(player, binding, stats:FindFirstChild("Level"))
	end

	self:_scheduleRefresh()
end

function RankFrameUIController:_bindPlayer(player: Player)
	if self.PlayerBindings[player] then
		return
	end

	local binding = {
		Connections = {},
		StatsConnections = {},
		Stats = nil,
		LevelValue = nil,
		LevelConnection = nil,
	}
	self.PlayerBindings[player] = binding

	table.insert(binding.Connections, player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" and child:IsA("Folder") then
			self:_watchLeaderstats(player, binding, child)
		end
	end))
	table.insert(binding.Connections, player.ChildRemoved:Connect(function(child)
		if child == binding.Stats then
			self:_watchLeaderstats(player, binding, nil)
		end
	end))

	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:IsA("Folder") then
		self:_watchLeaderstats(player, binding, stats)
	end
end

function RankFrameUIController:_unbindPlayer(player: Player)
	local binding = self.PlayerBindings[player]
	if not binding then
		return
	end

	disconnectAll(binding.Connections)
	disconnectAll(binding.StatsConnections)
	if binding.LevelConnection then
		binding.LevelConnection:Disconnect()
	end
	self.PlayerBindings[player] = nil
	self:_scheduleRefresh()
end

function RankFrameUIController:_render()
	local list = self.List
	local template = self.Template
	if not list or not list.Parent or not template then
		return
	end

	for _, child in ipairs(list:GetChildren()) do
		if child:GetAttribute("RankFrameGeneratedRow") == true then
			child:Destroy()
		end
	end

	local rankedPlayers = Players:GetPlayers()
	table.sort(rankedPlayers, function(a, b)
		local levelA = readPlayerLevel(a)
		local levelB = readPlayerLevel(b)
		if levelA ~= levelB then
			return levelA > levelB
		end
		return a.UserId < b.UserId
	end)

	local rowCount = math.min(MAX_ROWS, #rankedPlayers)
	for index = 1, rowCount do
		local rankedPlayer = rankedPlayers[index]
		local row = template:Clone()
		row.Name = string.format("Slot%d", index)
		row:SetAttribute("RankFrameGeneratedRow", true)
		row.LayoutOrder = index
		row.Visible = true

		local nameLabel = row:FindFirstChild("Name")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = rankedPlayer.DisplayName ~= "" and rankedPlayer.DisplayName or rankedPlayer.Name
		elseif not self._warnedInvalidTemplate then
			self._warnedInvalidTemplate = true
			warn("[RankFrameUI] PlayerRowTemplate_RankFrame is missing its Name TextLabel.")
		end

		local levelLabel = row:FindFirstChild("Level")
		if levelLabel and levelLabel:IsA("TextLabel") then
			levelLabel.Text = string.format("Lv.%d", readPlayerLevel(rankedPlayer))
		elseif not self._warnedInvalidTemplate then
			self._warnedInvalidTemplate = true
			warn("[RankFrameUI] PlayerRowTemplate_RankFrame is missing its Level TextLabel.")
		end

		row.Parent = list
	end
end

function RankFrameUIController:Start()
	if self._started then
		return
	end
	self._started = true
	self:_resolveUi()

	table.insert(self.Connections, Players.PlayerAdded:Connect(function(player)
		self:_bindPlayer(player)
		self:_scheduleRefresh()
	end))
	table.insert(self.Connections, Players.PlayerRemoving:Connect(function(player)
		self:_unbindPlayer(player)
	end))

	table.insert(self.Connections, self.PlayerGui.DescendantAdded:Connect(function(descendant)
		if not self.List or not self.List.Parent or descendant.Name == "RankFrame" or descendant.Name == "List" then
			self:_scheduleRefresh()
		end
	end))
	table.insert(self.Connections, self.PlayerGui.DescendantRemoving:Connect(function(descendant)
		if self.List and (self.List == descendant or self.List:IsDescendantOf(descendant)) then
			self.List = nil
			self:_scheduleRefresh()
		end
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		self:_bindPlayer(player)
	end
	self:_render()
end

function RankFrameUIController:Destroy()
	self._started = false
	for player in pairs(self.PlayerBindings) do
		self:_unbindPlayer(player)
	end
	disconnectAll(self.Connections)
end

return RankFrameUIController
