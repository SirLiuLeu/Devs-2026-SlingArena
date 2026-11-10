--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)
local ConfirmationTextConfig = require(ReplicatedStorage.Shared.Config.ConfirmationTextConfig)
local SoundManager = require(ReplicatedStorage.Shared.Utils.SoundManager)

local TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local DailyQuestUIController = {}
DailyQuestUIController.__index = DailyQuestUIController

local function setVisible(instance: Instance?, visible: boolean)
	if instance and instance:IsA("GuiObject") then
		instance.Visible = visible
	end
end

local CLAIM_READY_COLOR = Color3.fromRGB(52, 168, 83)
local CLAIM_DISABLED_COLOR = Color3.fromRGB(105, 110, 118)

local function setClaimVisualState(self: any, canClaim: boolean)
	local button = self._claimButton
	if button and button:IsA("TextButton") then
		button.Active = canClaim
		button.Selectable = canClaim
		button.AutoButtonColor = canClaim
		button.BackgroundColor3 = if canClaim then CLAIM_READY_COLOR else CLAIM_DISABLED_COLOR
		button.BackgroundTransparency = if canClaim then 0 else 0.28
		button.TextTransparency = if canClaim then 0 else 0.4
	end

	if self._diamondIcon and self._diamondIcon:IsA("ImageLabel") then
		self._diamondIcon.ImageTransparency = if canClaim then 0 else 0.35
	end
	if self._diamondCountText and self._diamondCountText:IsA("TextLabel") then
		self._diamondCountText.TextTransparency = if canClaim then 0 else 0.35
	end
end

local DAILY_QUEST_HIERARCHY_NODE_NAMES: { [string]: boolean } = {
	MainHUD = true,
	Root = true,
	QuestDaily = true,
	RootBody = true,
	SkipTaskBtn = true,
	ClaimRewardBtn = true,
	DiamondIcon = true,
	DiamondCountText = true,
	TaskDescriptionLabel = true,
	ToggleDropdown = true,
	OpenIcon = true,
	ClosedIcon = true,
	NotificationIcon = true,
}

local function isExpectedClass(instance: Instance?, expectedClass: string?): boolean
	return instance ~= nil and (expectedClass == nil or instance:IsA(expectedClass))
end

local function findUniqueDescendant(root: Instance?, name: string, expectedClass: string?): Instance?
	if not root then
		return nil
	end
	if root.Name == name and isExpectedClass(root, expectedClass) then
		return root
	end

	local directChild = root:FindFirstChild(name)
	if isExpectedClass(directChild, expectedClass) then
		return directChild
	end

	local match: Instance? = nil
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant.Name == name and isExpectedClass(descendant, expectedClass) then
			if match then
				-- Do not bind an arbitrary duplicate name from inside QuestDaily.
				return nil
			end
			match = descendant
		end
	end
	return match
end

local function resolveDailyQuestElement(
	playerGui: PlayerGui,
	frame: Frame,
	paths: any,
	pathKey: string,
	name: string,
	expectedClass: string,
	firstRoot: Instance?,
	secondRoot: Instance?,
	thirdRoot: Instance?
): Instance?
	local path = paths[pathKey]
	local exact = if type(path) == "string"
		then PathResolver.resolvePath(playerGui, path, { shouldWarn = false })
		else nil
	if isExpectedClass(exact, expectedClass) then
		return exact
	end

	local candidate = findUniqueDescendant(firstRoot, name, expectedClass)
		or findUniqueDescendant(secondRoot, name, expectedClass)
		or findUniqueDescendant(thirdRoot, name, expectedClass)
		or findUniqueDescendant(frame, name, expectedClass)
	if candidate then
		return candidate
	end

	-- Return a uniquely named but incorrectly typed instance as well, so the
	-- controller can report the real class mismatch instead of a false "missing".
	return exact or findUniqueDescendant(frame, name, nil)
end

local function warnMissingUiReference(self, key: string, message: string)
	self._warnedUiReferences = self._warnedUiReferences or {}
	if self._warnedUiReferences[key] then
		return
	end
	self._warnedUiReferences[key] = true
	warn(message)
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
	self._timeAccumulator = 0
	self._warnedUiReferences = {}
	self._destroyed = false
	self._resolveQueued = false
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
		if not self._warnedMissingFrame then
			warn("[DailyQuestUI] MainHUD.Root.QuestDaily is missing or is not a Frame.")
			self._warnedMissingFrame = true
		end
		return false
	end
	self._warnedMissingFrame = false

	local previousFrame = self._frame
	local previousRootBody = self._rootBody
	local previousSkipButton = self._skipButton
	local previousClaimButton = self._claimButton
	local previousDiamondIcon = self._diamondIcon
	local previousDiamondCountText = self._diamondCountText
	local previousDescriptionLabel = self._descriptionLabel
	local previousToggleButton = self._toggleButton
	local previousOpenIcon = self._openIcon
	local previousClosedIcon = self._closedIcon
	local previousNotificationIcon = self._notificationIcon
	local frameChanged = previousFrame ~= frame

	local rootBody = resolveDailyQuestElement(
		self._playerGui,
		frame,
		paths,
		"RootBody",
		"RootBody",
		"Frame",
		frame,
		nil,
		nil
	)
	if rootBody and not rootBody:IsA("Frame") then
		rootBody = nil
	end

	local skipButton = resolveDailyQuestElement(self._playerGui, frame, paths, "SkipTaskBtn", "SkipTaskBtn", "ImageButton", rootBody, frame, nil)
	local claimButton = resolveDailyQuestElement(self._playerGui, frame, paths, "ClaimRewardBtn", "ClaimRewardBtn", "TextButton", rootBody, frame, nil)
	local diamondIcon = resolveDailyQuestElement(self._playerGui, frame, paths, "DiamondIcon", "DiamondIcon", "ImageLabel", claimButton, rootBody, frame)
	local diamondCountText = resolveDailyQuestElement(self._playerGui, frame, paths, "DiamondCountText", "DiamondCountText", "TextLabel", claimButton, rootBody, frame)
	local descriptionLabel = resolveDailyQuestElement(self._playerGui, frame, paths, "TaskDescriptionLabel", "TaskDescriptionLabel", "TextLabel", rootBody, frame, nil)
	local toggleButton = resolveDailyQuestElement(self._playerGui, frame, paths, "ToggleDropdown", "ToggleDropdown", "TextButton", rootBody, frame, nil)
	local openIcon = resolveDailyQuestElement(self._playerGui, frame, paths, "OpenIcon", "OpenIcon", "ImageLabel", toggleButton, rootBody, frame)
	local closedIcon = resolveDailyQuestElement(self._playerGui, frame, paths, "ClosedIcon", "ClosedIcon", "ImageLabel", toggleButton, rootBody, frame)
	local notificationIcon = resolveDailyQuestElement(self._playerGui, frame, paths, "NotificationIcon", "NotificationIcon", "ImageLabel", rootBody, frame, nil)

	self._frame = frame
	self._frame.Visible = true
	self._rootBody = rootBody
	self._skipButton = skipButton
	self._claimButton = claimButton
	self._diamondIcon = diamondIcon
	self._diamondCountText = diamondCountText
	self._descriptionLabel = descriptionLabel
	self._toggleButton = toggleButton
	self._openIcon = openIcon
	self._closedIcon = closedIcon
	self._notificationIcon = notificationIcon

	local referencesChanged = frameChanged
		or previousRootBody ~= rootBody
		or previousSkipButton ~= skipButton
		or previousClaimButton ~= claimButton
		or previousDiamondIcon ~= diamondIcon
		or previousDiamondCountText ~= diamondCountText
		or previousDescriptionLabel ~= descriptionLabel
		or previousToggleButton ~= toggleButton
		or previousOpenIcon ~= openIcon
		or previousClosedIcon ~= closedIcon
		or previousNotificationIcon ~= notificationIcon

	if referencesChanged then
		self:_disconnectUiConnections()
	end
	if frameChanged or previousRootBody ~= rootBody then
		self._expandedSize = nil
		self._warnedUiReferences = {}
	end

	if not rootBody then
		warnMissingUiReference(self, "RootBody", "[DailyQuestUI] MainHUD.Root.QuestDaily.RootBody is missing or is not a Frame.")
		return false
	end
	self._warnedUiReferences.RootBody = nil

	local function validateReference(key: string, instance: Instance?, className: string, path: string)
		if instance and instance:IsA(className) then
			self._warnedUiReferences[key] = nil
		else
			warnMissingUiReference(
				self,
				key,
				string.format("[DailyQuestUI] %s is missing or is not a %s.", path, className)
			)
		end
	end

	validateReference("SkipTaskBtn", skipButton, "ImageButton", "MainHUD.Root.QuestDaily.RootBody.SkipTaskBtn")
	validateReference("ClaimRewardBtn", claimButton, "TextButton", "MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn")
	validateReference("DiamondIcon", diamondIcon, "ImageLabel", "MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn.DiamondIcon")
	validateReference("DiamondCountText", diamondCountText, "TextLabel", "MainHUD.Root.QuestDaily.RootBody.ClaimRewardBtn.DiamondCountText")
	validateReference("TaskDescriptionLabel", descriptionLabel, "TextLabel", "MainHUD.Root.QuestDaily.RootBody.TaskDescriptionLabel")
	validateReference("ToggleDropdown", toggleButton, "TextButton", "MainHUD.Root.QuestDaily.RootBody.ToggleDropdown")
	validateReference("OpenIcon", openIcon, "ImageLabel", "MainHUD.Root.QuestDaily.RootBody.ToggleDropdown.OpenIcon")
	validateReference("ClosedIcon", closedIcon, "ImageLabel", "MainHUD.Root.QuestDaily.RootBody.ToggleDropdown.ClosedIcon")
	validateReference("NotificationIcon", notificationIcon, "ImageLabel", "MainHUD.Root.QuestDaily.RootBody.NotificationIcon")

	if toggleButton and toggleButton:IsA("TextButton") and toggleButton.Text ~= "" then
		toggleButton.Text = ""
	end

	if referencesChanged then
		if frameChanged then
			self._expanded = true
		end
		self:_prepareRootBodyGeometry()
		self._rootBody.Visible = true
		self:_bindUiActions()
		self:_setExpanded(self._expanded, false)
	end

	return true
end

function DailyQuestUIController:_scheduleResolveUi()
	if self._resolveQueued or self._destroyed then
		return
	end
	self._resolveQueued = true
	task.defer(function()
		self._resolveQueued = false
		if self._destroyed then
			return
		end
		self:_resolveUi()
	end)
end

function DailyQuestUIController:_prepareRootBodyGeometry()
	if not self._frame or not self._rootBody or not self._toggleButton or not self._toggleButton:IsA("GuiObject") then
		return
	end
	if not self._expandedSize then
		self._expandedSize = self._rootBody.Size
	end

	-- Use ToggleDropdown's left edge as the panel's expansion origin.
	-- The toggle is repositioned to local X=0 while preserving its screen position.
	local toggleAbsoluteLeft = self._toggleButton.AbsolutePosition.X
	local rootPosition = self._rootBody.Position
	self._toggleInsideBody = self._toggleButton:IsDescendantOf(self._rootBody)
	local leftEdgeX = toggleAbsoluteLeft - self._frame.AbsolutePosition.X

	if self._toggleInsideBody and self._toggleButton.Parent == self._rootBody then
		local togglePosition = self._toggleButton.Position
		self._toggleLeftGap = 0
		self._toggleButton.AnchorPoint = Vector2.new(0, self._toggleButton.AnchorPoint.Y)
		self._toggleButton.Position = UDim2.new(0, 0, togglePosition.Y.Scale, togglePosition.Y.Offset)
	end

	if self._notificationIcon and self._notificationIcon:IsA("GuiObject")
		and self._notificationIcon:IsDescendantOf(self._rootBody)
		and self._notificationIcon.Parent == self._rootBody then
		local notificationPosition = self._notificationIcon.Position
		local notificationLeftGap = math.max(0, self._notificationIcon.AbsolutePosition.X - toggleAbsoluteLeft)
		self._notificationLeftGap = notificationLeftGap
		self._notificationWidth = self._notificationIcon.AbsoluteSize.X
		self._notificationIcon.AnchorPoint = Vector2.new(0, self._notificationIcon.AnchorPoint.Y)
		self._notificationIcon.Position = UDim2.new(0, notificationLeftGap, notificationPosition.Y.Scale, notificationPosition.Y.Offset)
	end

	self._rootBody.AnchorPoint = Vector2.new(0, self._rootBody.AnchorPoint.Y)
	self._rootBody.Position = UDim2.new(0, leftEdgeX, rootPosition.Y.Scale, rootPosition.Y.Offset)
	self._rootBody.ClipsDescendants = true

	if self._toggleInsideBody and self._toggleButton.Parent ~= self._rootBody then
		warn("[DailyQuestUI] ToggleDropdown should be a direct child of RootBody for reliable collapse animation.")
	end
	if self._notificationIcon and self._notificationIcon:IsDescendantOf(self._rootBody)
		and self._notificationIcon.Parent ~= self._rootBody then
		warn("[DailyQuestUI] NotificationIcon should be a direct child of RootBody so it remains visible when collapsed.")
	end
end

function DailyQuestUIController:_syncToggleIcons()
	if self._openIcon and self._openIcon:IsA("ImageLabel") then
		self._openIcon.Visible = self._expanded
	end
	if self._closedIcon and self._closedIcon:IsA("ImageLabel") then
		self._closedIcon.Visible = not self._expanded
	end
end

function DailyQuestUIController:_setExpanded(expanded: boolean, animate: boolean?)
	if not self._rootBody or not self._rootBody.Parent then
		self._expanded = expanded
		self:_syncToggleIcons()
		self:_renderNotification()
		return
	end
	if not self._toggleButton or not self._toggleButton.Parent then
		self._expanded = true
		self:_syncToggleIcons()
		self._rootBody.Visible = true
		self._rootBody.Size = self._expandedSize or self._rootBody.Size
		self:_renderCurrentState()
		return
	end
	self._expanded = expanded
	self:_syncToggleIcons()
	if self._tween then
		self._tween:Cancel()
		self._tween = nil
	end

	local fullSize = self._expandedSize or self._rootBody.Size
	local collapsedWidth = 0
	if self._toggleInsideBody and self._toggleButton then
		-- Keep only the toggle and its adjacent notification badge in the
		-- collapsed footprint; the panel still retracts to the toggle origin.
		collapsedWidth = math.max(
			(tonumber(self._toggleLeftGap) or 0) + self._toggleButton.AbsoluteSize.X,
			(tonumber(self._notificationLeftGap) or 0) + (tonumber(self._notificationWidth) or 0)
		)
	end
	local targetSize = if expanded
		then fullSize
		else UDim2.new(0, collapsedWidth, fullSize.Y.Scale, fullSize.Y.Offset)

	if expanded or self._toggleInsideBody then
		self._rootBody.Visible = true
	end

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
	self:_renderCurrentState()
end

function DailyQuestUIController:SetExpanded(expanded: boolean)
	if expanded then
		self._hasUnseenAssignment = false
	end
	self:_setExpanded(expanded, true)
end

function DailyQuestUIController:_bindUiActions()
	if self._toggleButton and self._toggleButton:IsA("GuiButton") then
		table.insert(self._uiConnections, self._toggleButton.Activated:Connect(function()
			local willExpand = not self._expanded
			if willExpand then
				self._hasUnseenAssignment = false
			end
			self:_setExpanded(willExpand, true)
		end))
	end

	if self._skipButton and self._skipButton:IsA("GuiButton") then
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

	if self._claimButton and self._claimButton:IsA("GuiButton") then
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
	self._destroyed = false
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
	local function onQuestUiHierarchyChanged(descendant: Instance)
		if DAILY_QUEST_HIERARCHY_NODE_NAMES[descendant.Name] then
			self:_scheduleResolveUi()
		end
	end
	table.insert(self._connections, self._playerGui.DescendantAdded:Connect(onQuestUiHierarchyChanged))
	table.insert(self._connections, self._playerGui.DescendantRemoving:Connect(onQuestUiHierarchyChanged))
	table.insert(self._connections, self._playerGui.ChildAdded:Connect(function(child)
		if child.Name == "MainHUD" then
			self:_scheduleResolveUi()
		end
	end))
	table.insert(self._connections, self._playerGui.ChildRemoved:Connect(function(child)
		if self._frame and (child == self._frame or self._frame:IsDescendantOf(child)) then
			self:_disconnectUiConnections()
			self._frame = nil
			self._rootBody = nil
			self._skipButton = nil
			self._claimButton = nil
			self._diamondIcon = nil
			self._diamondCountText = nil
			self._descriptionLabel = nil
			self._toggleButton = nil
			self._openIcon = nil
			self._closedIcon = nil
			self._notificationIcon = nil
			self._expandedSize = nil
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
		setClaimVisualState(self, false)
		setVisible(self._diamondIcon, false)
		setVisible(self._diamondCountText, false)
		self:_renderNotification()
		return
	end

	local status = tostring(daily.Status or "Preparing")
	local quest = daily.ActiveQuest
	local isCooldown = status == "Cooldown"
	local isCompleted = status == "CompletedForDay"
	local hasQuest = type(quest) == "table"
	local isReady = status == "Ready" and hasQuest
	local isActive = status == "Active" and hasQuest

	if isCooldown then
		setVisible(self._skipButton, false)
		setVisible(self._claimButton, true)
		setClaimVisualState(self, false)
		if self._claimButton and self._claimButton:IsA("TextButton") then
			self._claimButton.Text = ""
		end
		setVisible(self._diamondIcon, false)
		setVisible(self._diamondCountText, false)
		setVisible(self._descriptionLabel, true)
		if self._descriptionLabel and self._descriptionLabel:IsA("TextLabel") then
			self._descriptionLabel.Text = formatCooldown((tonumber(daily.NextQuestAt) or 0) - Workspace:GetServerTimeNow())
		end
	elseif isCompleted then
		setVisible(self._skipButton, false)
		setVisible(self._claimButton, true)
		setClaimVisualState(self, false)
		if self._claimButton and self._claimButton:IsA("TextButton") then
			self._claimButton.Text = ""
		end
		setVisible(self._diamondIcon, false)
		setVisible(self._diamondCountText, false)
		setVisible(self._descriptionLabel, true)
		if self._descriptionLabel and self._descriptionLabel:IsA("TextLabel") then
			self._descriptionLabel.Text = string.format("Bạn đã hoàn thành %d nhiệm vụ hôm nay!", math.max(1, math.floor(tonumber(daily.MaxSteps) or 5)))
		end
	else
		local safeQuest = if hasQuest then quest else {}
		local progress = math.max(0, math.floor(tonumber(safeQuest.Progress) or 0))
		local target = math.max(1, math.floor(tonumber(safeQuest.Target) or 1))
		local reward = type(safeQuest.Reward) == "table" and safeQuest.Reward or {}
		local diamonds = math.max(0, math.floor(tonumber(reward.Diamonds) or 0))
		local claimPending = self._logicService ~= nil and self._logicService:IsClaimPending()
		local canClaim = isReady and not claimPending

		setVisible(self._claimButton, true)
		setVisible(self._diamondIcon, hasQuest)
		setVisible(self._diamondCountText, hasQuest)
		setVisible(self._descriptionLabel, true)
		setVisible(self._skipButton, isActive)
		setClaimVisualState(self, canClaim)

		if self._claimButton and self._claimButton:IsA("TextButton") then
			self._claimButton.Text = ""
		end
		if self._diamondCountText and self._diamondCountText:IsA("TextLabel") then
			self._diamondCountText.Text = if hasQuest then tostring(diamonds) else ""
		end
		if self._skipButton and self._skipButton:IsA("ImageButton") then
			self._skipButton.Active = isActive and not self._pendingSkip
			self._skipButton.AutoButtonColor = isActive and not self._pendingSkip
		end
		if self._descriptionLabel and self._descriptionLabel:IsA("TextLabel") then
			local description = tostring(safeQuest.Desc or "Đang tải nhiệm vụ...")
			local progressSuffix = if hasQuest then string.format(" (%d/%d)", progress, target) else ""
			self._descriptionLabel.Text = (if isReady then "Hoàn thành! " else "") .. description .. progressSuffix
		end
	end

	if not self._expanded then
		setVisible(self._skipButton, false)
		setVisible(self._claimButton, false)
		setVisible(self._diamondIcon, false)
		setVisible(self._diamondCountText, false)
		setVisible(self._descriptionLabel, false)
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
	if not self._notificationIcon or not self._notificationIcon:IsA("ImageLabel") then
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
		-- NotificationService already displays the authoritative DiamondReward toast.
		SoundManager.Play("SFX_Success")
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
	self._destroyed = true
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
