--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ConfirmationTextConfig = require(ReplicatedStorage.Shared.Config.ConfirmationTextConfig)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)

-- Fill these two IDs manually. Both assets are preloaded before either is assigned
-- to ToggleDropdown, so the icon never changes to an unloaded asset.
local TOGGLE_EXPANDED_ICON_ID = ""
local TOGGLE_COLLAPSED_ICON_ID = ""

local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DailyQuestUIController = {}
DailyQuestUIController.__index = DailyQuestUIController

local function normalizeImageId(value: string): string?
	local trimmed = string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return nil
	end
	if string.match(trimmed, "^%d+$") then
		return "rbxassetid://" .. trimmed
	end
	return trimmed
end

local function setVisible(instance: Instance?, visible: boolean)
	if instance and instance:IsA("GuiObject") then
		instance.Visible = visible
	end
end

local function formatCooldown(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local minutes = math.floor(total / 60)
	local remainder = total % 60
	return string.format("Nhiệm vụ tiếp theo trong %dp%02ds", minutes, remainder)
end

function DailyQuestUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, DailyQuestUIController)
	self._playerGui = playerGui
	self._connections = {}
	self._uiConnections = {}
	self._logicConnections = {}
	self._snapshot = nil
	self._expanded = true
	self._hasUnseenAssignment = false
	self._lastAssignmentId = nil
	self._pendingSkip = false
	self._toggleIconsReady = false
	self._timeAccumulator = 0
	return self
end

function DailyQuestUIController:SetLogicService(logicService: any)
	self._logicService = logicService
end

function DailyQuestUIController:SetConfirmationController(controller: any)
	self._confirmationController = controller
end

function DailyQuestUIController:SetToastController(controller: any)
	self._toastController = controller
end

function DailyQuestUIController:_disconnectUiConnections()
	for _, connection in ipairs(self._uiConnections) do
		connection:Disconnect()
	end
	table.clear(self._uiConnections)
end

function DailyQuestUIController:_resolveUi(): boolean
	local paths = ProjectTreeSpec.UI.MainHub.DailyQuest
	local frame = PathResolver.resolvePath(self._playerGui, paths.Root, { shouldWarn = false })
	if not frame or not frame:IsA("Frame") then
		return false
	end
	if self._frame == frame and self._rootBody and self._rootBody.Parent then
		return true
	end

	self:_disconnectUiConnections()
	self._expandedSize = nil
	self._frame = frame
	self._frame.Visible = true
	self._rootBody = PathResolver.resolvePath(self._playerGui, paths.RootBody, { shouldWarn = false })
	self._skipButton = PathResolver.resolvePath(self._playerGui, paths.SkipTaskBtn, { shouldWarn = false })
	self._claimButton = PathResolver.resolvePath(self._playerGui, paths.ClaimRewardBtn, { shouldWarn = false })
	self._diamondIcon = PathResolver.resolvePath(self._playerGui, paths.DiamondIcon, { shouldWarn = false })
	self._progressLabel = PathResolver.resolvePath(self._playerGui, paths.ProgressLabel, { shouldWarn = false })
	self._descriptionLabel = PathResolver.resolvePath(self._playerGui, paths.TaskDescriptionLabel, { shouldWarn = false })
	self._toggleButton = PathResolver.resolvePath(self._playerGui, paths.ToggleDropdown, { shouldWarn = false })
	self._notificationIcon = PathResolver.resolvePath(self._playerGui, paths.NotificationIIcon, { shouldWarn = false })

	-- Do not expose an empty image slot while the two authored icons are loading.
	if self._toggleButton and not self._toggleIconsReady then
		self._toggleButton.Visible = false
	end

	if not self._rootBody or not self._rootBody:IsA("Frame") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody is missing or is not a Frame.")
		return false
	end
	if not self._skipButton or not self._skipButton:IsA("ImageButton") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.SkipTaskBtn is missing or is not an ImageButton.")
	end
	if not self._claimButton or not self._claimButton:IsA("TextButton") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn is missing or is not a TextButton.")
	end
	if not self._diamondIcon or not self._diamondIcon:IsA("ImageLabel") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn.DiamondIcon is missing or is not an ImageLabel.")
	end
	if not self._progressLabel or not self._progressLabel:IsA("TextLabel") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn.ProgressLabel is missing or is not a TextLabel.")
	end
	if not self._descriptionLabel or not self._descriptionLabel:IsA("TextLabel") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn.TaskDescriptionLabel is missing or is not a TextLabel.")
	end
	if not self._toggleButton or not self._toggleButton:IsA("ImageButton") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.ToggleDropdown is missing or is not an ImageButton.")
	end
	if not self._notificationIcon or not self._notificationIcon:IsA("ImageLabel") then
		warn("[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody.NotificationIIcon is missing or is not an ImageLabel.")
	end

	if self._toggleButton and self._toggleButton.Parent ~= self._frame
		and not self._toggleButton:IsDescendantOf(self._rootBody) then
		warn("[DailyQuestUI] ToggleDropdown must be a sibling of QuestDaily or a child of RootBody.")
	end
	if self._notificationIcon and self._notificationIcon.Parent ~= self._frame
		and not self._notificationIcon:IsDescendantOf(self._rootBody) then
		warn("[DailyQuestUI] NotificationIIcon must be a sibling of QuestDaily or a child of RootBody.")
	end

	self:_prepareRootBodyGeometry()
	self:_bindUiActions()
	self:_preloadToggleIcons()
	self._rootBody.Visible = true
	self:_setExpanded(true, false)
	if self._snapshot then
		self:RenderSnapshot(self._snapshot)
	end
	return true
end

function DailyQuestUIController:_prepareRootBodyGeometry()
	if not self._frame or not self._rootBody or not self._toggleButton then
		return
	end
	if not self._expandedSize then
		self._expandedSize = self._rootBody.Size
	end

	local bodyAbsoluteRight = self._rootBody.AbsolutePosition.X + self._rootBody.AbsoluteSize.X
	local rootPosition = self._rootBody.Position
	self._toggleInsideBody = self._toggleButton:IsDescendantOf(self._rootBody)
	local rightEdgeX = bodyAbsoluteRight - self._frame.AbsolutePosition.X

	if self._toggleInsideBody and self._toggleButton.Parent == self._rootBody then
		local togglePosition = self._toggleButton.Position
		local toggleRightGap = math.max(0, bodyAbsoluteRight - (self._toggleButton.AbsolutePosition.X + self._toggleButton.AbsoluteSize.X))
		self._toggleRightGap = toggleRightGap
		self._toggleWidth = self._toggleButton.AbsoluteSize.X
		self._toggleButton.AnchorPoint = Vector2.new(1, self._toggleButton.AnchorPoint.Y)
		self._toggleButton.Position = UDim2.new(1, -toggleRightGap, togglePosition.Y.Scale, togglePosition.Y.Offset)
	end

	if self._notificationIcon and self._notificationIcon:IsDescendantOf(self._rootBody)
		and self._notificationIcon.Parent == self._rootBody then
		local notificationPosition = self._notificationIcon.Position
		local notificationRightGap = math.max(0, bodyAbsoluteRight - (self._notificationIcon.AbsolutePosition.X + self._notificationIcon.AbsoluteSize.X))
		self._notificationRightGap = notificationRightGap
		self._notificationWidth = self._notificationIcon.AbsoluteSize.X
		self._notificationIcon.AnchorPoint = Vector2.new(1, self._notificationIcon.AnchorPoint.Y)
		self._notificationIcon.Position = UDim2.new(1, -notificationRightGap, notificationPosition.Y.Scale, notificationPosition.Y.Offset)
	end

	-- Keep the panel's right edge fixed. The body grows leftwards, while the
	-- nested toggle and notification remain anchored to that fixed right edge.
	self._rootBody.AnchorPoint = Vector2.new(1, self._rootBody.AnchorPoint.Y)
	self._rootBody.Position = UDim2.new(0, rightEdgeX, rootPosition.Y.Scale, rootPosition.Y.Offset)
	self._rootBody.ClipsDescendants = true

	if self._toggleInsideBody and self._toggleButton.Parent ~= self._rootBody then
		warn("[DailyQuestUI] ToggleDropdown should be a direct child of RootBody for reliable collapse animation.")
	end
	if self._notificationIcon and self._notificationIcon:IsDescendantOf(self._rootBody)
		and self._notificationIcon.Parent ~= self._rootBody then
		warn("[DailyQuestUI] NotificationIIcon should be a direct child of RootBody so it remains visible when collapsed.")
	end
end

function DailyQuestUIController:_preloadToggleIcons()
	if self._iconPreloadStarted then
		return
	end
	self._iconPreloadStarted = true

	local expandedId = normalizeImageId(TOGGLE_EXPANDED_ICON_ID)
	local collapsedId = normalizeImageId(TOGGLE_COLLAPSED_ICON_ID)
	if not expandedId or not collapsedId then
		warn("[DailyQuestUI] Fill both TOGGLE_EXPANDED_ICON_ID and TOGGLE_COLLAPSED_ICON_ID before testing the toggle.")
		return
	end

	-- PreloadAsync consumes Instances. Temporary hidden ImageLabels let Roblox
	-- fetch both image assets before ToggleDropdown.Image is changed.
	task.spawn(function()
		local preloadGui = Instance.new("ScreenGui")
		preloadGui.Name = "__DailyQuestIconPreload"
		preloadGui.Enabled = false
		preloadGui.ResetOnSpawn = false
		local preloadFrame = Instance.new("Frame")
		preloadFrame.Name = "Assets"
		preloadFrame.Size = UDim2.fromOffset(1, 1)
		preloadFrame.BackgroundTransparency = 1
		preloadFrame.Parent = preloadGui

		local preloadImages = {}
		for index, imageId in ipairs({ expandedId, collapsedId }) do
			local image = Instance.new("ImageLabel")
			image.Name = "ToggleIcon" .. tostring(index)
			image.Size = UDim2.fromOffset(1, 1)
			image.BackgroundTransparency = 1
			image.Image = imageId
			image.Visible = false
			image.Parent = preloadFrame
			table.insert(preloadImages, image)
		end
		preloadGui.Parent = self._playerGui

		local loadedAssets = 0
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(preloadImages, function(_assetId, fetchStatus)
				if fetchStatus == Enum.AssetFetchStatus.Success then
					loadedAssets += 1
				end
			end)
		end)
		preloadGui:Destroy()

		if not ok or loadedAssets < #preloadImages then
			warn(string.format("[DailyQuestUI] Both toggle icons must preload successfully before switching. loaded=%d/%d error=%s", loadedAssets, #preloadImages, tostring(err)))
			return
		end

		self._toggleIconsReady = true
		self:_applyToggleIcon()
		if self._toggleButton and self._toggleButton.Parent then
			self._toggleButton.Visible = true
		end
	end)
end

function DailyQuestUIController:_applyToggleIcon()
	if not self._toggleButton or not self._toggleIconsReady then
		return
	end
	local imageId = if self._expanded
		then normalizeImageId(TOGGLE_EXPANDED_ICON_ID)
		else normalizeImageId(TOGGLE_COLLAPSED_ICON_ID)
	if imageId then
		self._toggleButton.Image = imageId
	end
end

function DailyQuestUIController:_setExpanded(expanded: boolean, animate: boolean?)
	if not self._rootBody or not self._rootBody.Parent then
		self._expanded = expanded
		return
	end
	if not self._toggleButton or not self._toggleButton.Parent then
		self._expanded = true
		self._rootBody.Visible = true
		self._rootBody.Size = self._expandedSize or self._rootBody.Size
		return
	end
	self._expanded = expanded
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end

	local fullSize = self._expandedSize or self._rootBody.Size
	local collapsedWidth = 0
	if self._toggleInsideBody and self._toggleButton then
		collapsedWidth = math.max(
			(tonumber(self._toggleRightGap) or 0) + self._toggleButton.AbsoluteSize.X,
			(tonumber(self._notificationRightGap) or 0) + (tonumber(self._notificationWidth) or 0)
		)
	end
	local targetSize = if expanded
		then fullSize
		else UDim2.new(0, collapsedWidth, fullSize.Y.Scale, fullSize.Y.Offset)

	if expanded or self._toggleInsideBody then
		self._rootBody.Visible = true
	end

	self:_applyToggleIcon()
	if animate == false then
		self._rootBody.Size = targetSize
	else
		self._tween = TweenService:Create(self._rootBody, TWEEN_INFO, { Size = targetSize })
		self._tween:Play()
		if not expanded and not self._toggleInsideBody then
			local closingTween = self._tween
			closingTween.Completed:Once(function()
				if self._tween == closingTween and not self._expanded and self._rootBody then
					self._rootBody.Visible = false
				end
			end)
		end
	end

	if expanded then
		self._hasUnseenAssignment = false
	end
	self:_renderNotification()
end

function DailyQuestUIController:SetExpanded(expanded: boolean)
	if expanded then
		self._hasUnseenAssignment = false
	end
	self:_setExpanded(expanded, true)
end

function DailyQuestUIController:_bindUiActions()
	if self._toggleButton then
		table.insert(self._uiConnections, self._toggleButton.Activated:Connect(function()
			local willExpand = not self._expanded
			if willExpand then
				self._hasUnseenAssignment = false
			end
			self:_setExpanded(willExpand, true)
		end))
	end

	if self._skipButton then
		table.insert(self._uiConnections, self._skipButton.Activated:Connect(function()
			local questState = self._snapshot and self._snapshot.DailyQuest
			local quest = questState and questState.ActiveQuest
			if self._pendingSkip or not quest or quest.State ~= "Active" then
				return
			end
			if not self._confirmationController then
				warn("[DailyQuestUI] ConfirmationUIController is unavailable; Skip was not sent.")
				return
			end
			self._confirmationController:RequestConfirm(
				ConfirmationTextConfig.Get("SkipDailyQuest"),
				function()
					if self._logicService and self._logicService:SkipQuest(quest.AssignmentId) then
						self._pendingSkip = true
						self:_renderCurrentState()
					end
				end
			)
		end))
	end

	if self._claimButton then
		table.insert(self._uiConnections, self._claimButton.Activated:Connect(function()
			local questState = self._snapshot and self._snapshot.DailyQuest
			local quest = questState and questState.ActiveQuest
			if not questState or questState.Status ~= "Ready" or not quest then
				return
			end
			if self._logicService then
				self._logicService:ClaimQuest(quest.AssignmentId)
			end
		end))
	end
end

function DailyQuestUIController:Start()
	if self._logicService then
		table.insert(self._logicConnections, self._logicService:BindChanged(function(snapshot)
			self:RenderSnapshot(snapshot)
		end))
		table.insert(self._logicConnections, self._logicService:BindClaimCompleted(function(result)
			self:_handleClaimResult(result)
		end))
		table.insert(self._logicConnections, self._logicService:BindSkipCompleted(function(result)
			self:_handleSkipResult(result)
		end))
		self._snapshot = self._logicService:GetSnapshot()
	end

	self:_resolveUi()
	table.insert(self._connections, self._playerGui.ChildAdded:Connect(function(child)
		if child.Name == "MainHUD" then
			task.defer(function()
				self:_resolveUi()
			end)
		end
	end))
	table.insert(self._connections, self._playerGui.ChildRemoved:Connect(function(child)
		if self._frame and (child == self._frame or self._frame:IsDescendantOf(child)) then
			self:_disconnectUiConnections()
			self._frame = nil
			self._rootBody = nil
			self._toggleButton = nil
			self._notificationIcon = nil
		end
	end))
	self._heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self._timeAccumulator += deltaTime
		if self._timeAccumulator >= 0.25 then
			self._timeAccumulator = 0
			self:_refreshCooldownText()
		end
	end)
	if self._snapshot then
		self:RenderSnapshot(self._snapshot)
	end
end

function DailyQuestUIController:RenderSnapshot(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	local previousAssignmentId = self._lastAssignmentId
	self._snapshot = snapshot
	local daily = snapshot.DailyQuest or {}
	local active = daily.ActiveQuest
	local currentAssignmentId = type(active) == "table" and active.AssignmentId or nil
	if currentAssignmentId then
		if previousAssignmentId and previousAssignmentId ~= currentAssignmentId and not self._expanded then
			self._hasUnseenAssignment = true
		end
		self._lastAssignmentId = currentAssignmentId
	end

	self:_resolveUi()
	self:_renderCurrentState()
end

function DailyQuestUIController:_renderCurrentState()
	local snapshot = self._snapshot
	local daily = snapshot and snapshot.DailyQuest
	if not daily or not self._rootBody then
		self:_renderNotification()
		return
	end

	local status = tostring(daily.Status or "Preparing")
	local quest = daily.ActiveQuest
	local isCooldown = status == "Cooldown"
	local isCompleted = status == "CompletedForDay"
	local isReady = status == "Ready" and type(quest) == "table"
	local isActive = status == "Active" and type(quest) == "table"

	if isCooldown then
		setVisible(self._skipButton, false)
		setVisible(self._claimButton, true)
		if self._claimButton and self._claimButton:IsA("TextButton") then
			self._claimButton.Active = false
			self._claimButton.AutoButtonColor = false
			self._claimButton.Text = ""
		end
		setVisible(self._diamondIcon, false)
		setVisible(self._progressLabel, false)
		setVisible(self._descriptionLabel, true)
		if self._descriptionLabel and self._descriptionLabel:IsA("TextLabel") then
			self._descriptionLabel.Text = formatCooldown((tonumber(daily.NextQuestAt) or 0) - Workspace:GetServerTimeNow())
		end
	elseif isCompleted then
		setVisible(self._skipButton, false)
		setVisible(self._claimButton, true)
		if self._claimButton and self._claimButton:IsA("TextButton") then
			self._claimButton.Active = false
			self._claimButton.AutoButtonColor = false
			self._claimButton.Text = ""
		end
		setVisible(self._diamondIcon, false)
		setVisible(self._progressLabel, false)
		setVisible(self._descriptionLabel, true)
		if self._descriptionLabel and self._descriptionLabel:IsA("TextLabel") then
			self._descriptionLabel.Text = "Bạn đã hoàn thành 5 nhiệm vụ hôm nay!"
		end
	else
		local safeQuest = type(quest) == "table" and quest or {}
		local progress = math.max(0, math.floor(tonumber(safeQuest.Progress) or 0))
		local target = math.max(1, math.floor(tonumber(safeQuest.Target) or 1))
		local reward = type(safeQuest.Reward) == "table" and safeQuest.Reward or {}
		local diamonds = math.max(0, math.floor(tonumber(reward.Diamonds) or 0))

		setVisible(self._claimButton, true)
		setVisible(self._diamondIcon, true)
		setVisible(self._progressLabel, true)
		setVisible(self._descriptionLabel, true)
		setVisible(self._skipButton, isActive)

		if self._claimButton and self._claimButton:IsA("TextButton") then
			self._claimButton.Active = isReady and not (self._logicService and self._logicService:IsClaimPending())
			self._claimButton.AutoButtonColor = isReady and not (self._logicService and self._logicService:IsClaimPending())
			self._claimButton.Text = ""
		end
		if self._skipButton and self._skipButton:IsA("ImageButton") then
			self._skipButton.Active = isActive and not self._pendingSkip
			self._skipButton.AutoButtonColor = isActive and not self._pendingSkip
		end
		if self._progressLabel and self._progressLabel:IsA("TextLabel") then
			self._progressLabel.Text = string.format("%d / %d  (+%d)", progress, target, diamonds)
		end
		if self._descriptionLabel and self._descriptionLabel:IsA("TextLabel") then
			self._descriptionLabel.Text = if isReady then ("Hoàn thành! " .. tostring(safeQuest.Desc or "Nhiệm vụ")) else tostring(safeQuest.Desc or "Đang tải nhiệm vụ...")
		end
	end

	if not self._expanded and self._toggleInsideBody then
		setVisible(self._skipButton, false)
		setVisible(self._claimButton, false)
	end
	self:_refreshCooldownText()
	self:_renderNotification()
end

function DailyQuestUIController:_refreshCooldownText()
	local daily = self._snapshot and self._snapshot.DailyQuest
	if not daily or daily.Status ~= "Cooldown" or not self._descriptionLabel or not self._descriptionLabel:IsA("TextLabel") then
		return
	end
	self._descriptionLabel.Text = formatCooldown((tonumber(daily.NextQuestAt) or 0) - Workspace:GetServerTimeNow())
end

function DailyQuestUIController:_renderNotification()
	if not self._notificationIcon then
		return
	end
	local daily = self._snapshot and self._snapshot.DailyQuest
	local waitingForClaim = daily and daily.Status == "Ready"
	self._notificationIcon.Visible = waitingForClaim == true or self._hasUnseenAssignment == true
end

function DailyQuestUIController:_handleClaimResult(result: any)
	if type(result) ~= "table" then
		return
	end
	if result.Success == true then
		SoundManager.Play("SFX_Success")
		if self._toastController then
			local diamonds = tonumber(result.Reward and result.Reward.Diamonds) or 0
			self._toastController:Enqueue({
				Text = string.format("Đã nhận nhiệm vụ và %d kim cương.", diamonds),
				Toast = true,
			})
		end
	else
		if self._toastController then
			self._toastController:Enqueue({
				Text = "Không thể nhận thưởng nhiệm vụ. Vui lòng thử lại.",
				Toast = true,
			})
		end
	end
end

function DailyQuestUIController:_handleSkipResult(result: any)
	if type(result) ~= "table" then
		return
	end
	self._pendingSkip = false
	if result.Success ~= true and self._toastController then
		self._toastController:Enqueue({
			Text = "Không thể đổi nhiệm vụ. Hãy kiểm tra trạng thái nhiệm vụ.",
			Toast = true,
		})
	end
	self:_renderCurrentState()
end

function DailyQuestUIController:Destroy()
	self:_disconnectUiConnections()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	for _, connection in ipairs(self._logicConnections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	table.clear(self._logicConnections)
	if self._heartbeatConnection then
		self._heartbeatConnection:Disconnect()
		self._heartbeatConnection = nil
	end
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end
end

return DailyQuestUIController
