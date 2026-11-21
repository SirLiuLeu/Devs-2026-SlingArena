--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NotificationConfigData = require(ReplicatedStorage.Shared.Config.NotificationConfigData)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local ToastUIController = {}
ToastUIController.__index = ToastUIController

local MAX_VISIBLE_TOASTS = 5
local MAX_QUEUE_SIZE = 25
local FADE_IN_SECONDS = 0.15
local DEFAULT_DISPLAY_SECONDS = 3
local DEFAULT_FADE_OUT_SECONDS = 2
local POLL_INTERVAL_SECONDS = 0.1

export type ToastItem = {
	Type: string,
	I18nKey: string,
	Priority: number,
	Args: { [string]: any },
	Text: string,
	Config: NotificationConfigData.NotificationConfig,
	Sequence: number,
	ReplaceKey: string?,
}

type ToastRecord = {
	Item: ToastItem,
	Sequence: number,
	Count: number,
	DedupKey: string?,
	ReplaceKey: string?,
	Frame: Frame?,
	MessageLabel: TextLabel?,
	Removed: boolean,
	ExpiresAt: number?,
	Tweens: { Tween },
}

local function formatTemplate(templateText: string, args: { [string]: any }): string
	return (string.gsub(templateText, "{([%w_]+)}", function(key)
		local value = args[key]
		return if value == nil then "" else tostring(value)
	end))
end

function ToastUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, ToastUIController)
	self._playerGui = playerGui
	self._queue = {} :: { ToastRecord }
	self._active = {} :: { ToastRecord }
	self._recordsByReplaceKey = {} :: { [string]: ToastRecord }
	self._lastToastRecord = nil :: ToastRecord?
	self._destroyed = false
	self._sequence = 0
	self._screenGui = nil :: ScreenGui?
	self._container = nil :: GuiObject?
	self._template = nil :: Frame?
	self:_resolveUi()
	return self
end

function ToastUIController:_resolveUi(): boolean
	local screenPath = ProjectTreeSpec.UI.Notification.ScreenGui
	local containerPath = ProjectTreeSpec.UI.Notification.Container
	local templatePath = ProjectTreeSpec.GameplayInstances.ReplicatedStorage.Assets.ToastTemplate

	self._screenGui = PathResolver.resolvePath(self._playerGui, screenPath, { shouldWarn = false }) :: ScreenGui?
	self._container = PathResolver.resolvePath(self._playerGui, containerPath, { shouldWarn = false }) :: GuiObject?
	self._template = PathResolver.resolvePath(ReplicatedStorage, templatePath, { shouldWarn = false }) :: Frame?

	if self._screenGui then
		self._screenGui.Enabled = true
		self._screenGui.ResetOnSpawn = false
		self._screenGui.DisplayOrder = math.max(self._screenGui.DisplayOrder, 100)
	end
	if self._template then
		self._template.Visible = false
	end

	local listLayout = self._container and self._container:FindFirstChildWhichIsA("UIListLayout")
	if listLayout then
		listLayout.FillDirection = Enum.FillDirection.Vertical
		listLayout.SortOrder = Enum.SortOrder.Name
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	end

	return self._screenGui ~= nil and self._container ~= nil and self._template ~= nil
end

function ToastUIController:_normalize(message: any): ToastItem?
	local notificationType = "Generic"
	local args = {} :: { [string]: any }
	local text = ""
	local priorityOverride = nil :: number?
	local i18nKeyOverride = nil :: string?
	local replaceKeyOverride = nil :: string?

	if type(message) == "table" then
		notificationType = tostring(message.Type or message.NotificationType or message.EventType or notificationType)
		if type(message.Args) == "table" then
			args = table.clone(message.Args)
		elseif type(message.Payload) == "table" then
			args = table.clone(message.Payload)
		end
		text = tostring(message.Text or message.Message or "")
		priorityOverride = if type(message.Priority) == "number" then message.Priority else nil
		i18nKeyOverride = if type(message.I18nKey) == "string" then message.I18nKey else nil
		replaceKeyOverride = if type(message.ReplaceKey) == "string" then message.ReplaceKey else nil
	else
		text = tostring(message or "")
		args.message = text
	end

	local config = NotificationConfigData.Get(notificationType)
	if text == "" then
		text = formatTemplate(config.FallbackText, args)
	end
	if text == "" then
		warn("[ToastUIController] Empty notification text was dropped.")
		return nil
	end

	self._sequence += 1
	return {
		Type = config.Type,
		I18nKey = i18nKeyOverride or config.I18nKey,
		Priority = priorityOverride or config.Priority,
		Args = args,
		Text = text,
		Config = config,
		Sequence = self._sequence,
		ReplaceKey = replaceKeyOverride or config.ReplaceKey,
	}
end

function ToastUIController:_displayText(record: ToastRecord): string
	if record.Count > 1 then
		return record.Item.Text .. " x" .. tostring(record.Count)
	end
	return record.Item.Text
end

function ToastUIController:_updateVisual(record: ToastRecord)
	local frame = record.Frame
	if not frame or not frame.Parent then
		return
	end

	local style = record.Item.Config.Style
	frame.BackgroundColor3 = style.BackgroundColor
	local message = record.MessageLabel
	if message then
		message.Text = self:_displayText(record)
		message.TextColor3 = style.TextColor
	end

	local icon = frame:FindFirstChild("Icon", true)
	if icon and icon:IsA("ImageLabel") then
		icon.Image = style.Icon or ""
		icon.ImageColor3 = style.AccentColor
		icon.Visible = style.Icon ~= nil and style.Icon ~= ""
	end

	local stroke = frame:FindFirstChildWhichIsA("UIStroke", true)
	if stroke then
		stroke.Color = style.AccentColor
	end
end

function ToastUIController:_discardRecord(record: ToastRecord)
	if record.Removed then
		return
	end
	record.Removed = true
	if record.Frame then
		record.Frame:Destroy()
		record.Frame = nil
	end
	if record.ReplaceKey and self._recordsByReplaceKey[record.ReplaceKey] == record then
		self._recordsByReplaceKey[record.ReplaceKey] = nil
	end
	if self._lastToastRecord == record then
		self._lastToastRecord = nil
	end
	for _, tween in ipairs(record.Tweens) do
		pcall(function()
			tween:Cancel()
			tween:Destroy()
		end)
	end
	table.clear(record.Tweens)
end

function ToastUIController:_sortQueue()
	table.sort(self._queue, function(a, b)
		if a.Item.Priority == b.Item.Priority then
			return a.Sequence < b.Sequence
		end
		return a.Item.Priority > b.Item.Priority
	end)
end

function ToastUIController:_insertRecord(record: ToastRecord)
	table.insert(self._queue, record)
	self:_sortQueue()

	if #self._queue > MAX_QUEUE_SIZE then
		local dropped = table.remove(self._queue, #self._queue)
		if dropped then
			self:_discardRecord(dropped)
			warn("[ToastUIController] Toast queue was full; the lowest-priority pending toast was dropped.")
		end
	end
end

function ToastUIController:_resetLastDuplicateCount()
	local lastRecord = self._lastToastRecord
	if lastRecord and not lastRecord.Removed and lastRecord.Count > 1 then
		lastRecord.Count = 1
		self:_updateVisual(lastRecord)
	end
	self._lastToastRecord = nil
end

function ToastUIController:_newRecord(item: ToastItem): ToastRecord
	return {
		Item = item,
		Sequence = item.Sequence,
		Count = 1,
		DedupKey = item.Type .. "|" .. item.Text,
		ReplaceKey = item.ReplaceKey,
		Frame = nil,
		MessageLabel = nil,
		Removed = false,
		ExpiresAt = nil,
		Tweens = {},
	}
end

function ToastUIController:Enqueue(message: any)
	if self._destroyed then
		return
	end
	if not self:_resolveUi() then
		warn("[ToastUIController] NotificationGui, ToastContainer, or ToastTemplate is missing; notification was dropped.")
		return
	end

	local item = self:_normalize(message)
	if not item then
		return
	end

	local now = os.clock()
	if item.ReplaceKey then
		self:_resetLastDuplicateCount()
		local existing = self._recordsByReplaceKey[item.ReplaceKey]
		if existing and not existing.Removed then
			existing.Item = item
			existing.Count = 1
			if existing.Frame then
				existing.ExpiresAt = now + (item.Config.DisplaySeconds or DEFAULT_DISPLAY_SECONDS)
			end
			self:_updateVisual(existing)
			self:_sortQueue()
			return
		end

		local record = self:_newRecord(item)
		self._recordsByReplaceKey[item.ReplaceKey] = record
		self:_insertRecord(record)
		self:_pump()
		return
	end

	local lastRecord = self._lastToastRecord
	local dedupKey = item.Type .. "|" .. item.Text
	if lastRecord and not lastRecord.Removed and lastRecord.DedupKey == dedupKey then
		lastRecord.Count += 1
		if lastRecord.Frame then
			lastRecord.ExpiresAt = now + (item.Config.DisplaySeconds or DEFAULT_DISPLAY_SECONDS)
		end
		self:_updateVisual(lastRecord)
		return
	end

	self:_resetLastDuplicateCount()
	local record = self:_newRecord(item)
	self._lastToastRecord = record
	self:_insertRecord(record)
	self:_pump()
end

function ToastUIController:_createFadeTweens(record: ToastRecord, fadeOut: boolean): { Tween }
	local frame = record.Frame
	if not frame then
		return {}
	end
	local duration = if fadeOut
		then (record.Item.Config.FadeOutSeconds or DEFAULT_FADE_OUT_SECONDS)
		else FADE_IN_SECONDS
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, if fadeOut then Enum.EasingDirection.In else Enum.EasingDirection.Out)
	local transparency = if fadeOut then 1 else 0
	local tweens = {
		TweenService:Create(frame, tweenInfo, { BackgroundTransparency = if fadeOut then 1 else 0.12 }),
	}

	if record.MessageLabel then
		table.insert(tweens, TweenService:Create(record.MessageLabel, tweenInfo, { TextTransparency = transparency }))
	end
	local icon = frame:FindFirstChild("Icon", true)
	if icon and icon:IsA("ImageLabel") and icon.Visible then
		table.insert(tweens, TweenService:Create(icon, tweenInfo, { ImageTransparency = transparency }))
	end
	local stroke = frame:FindFirstChildWhichIsA("UIStroke", true)
	if stroke then
		table.insert(tweens, TweenService:Create(stroke, tweenInfo, { Transparency = transparency }))
	end

	for _, tween in ipairs(tweens) do
		table.insert(record.Tweens, tween)
	end
	return tweens
end

function ToastUIController:_finishRecord(record: ToastRecord)
	for index, activeRecord in ipairs(self._active) do
		if activeRecord == record then
			table.remove(self._active, index)
			break
		end
	end
	self:_discardRecord(record)
	self:_pump()
end

function ToastUIController:_showRecord(record: ToastRecord)
	if self._destroyed or record.Removed then
		return
	end
	if not self:_resolveUi() or not self._template or not self._container then
		self:_finishRecord(record)
		return
	end

	local frame = self._template:Clone()
	frame.Name = "Slot_" .. tostring(record.Sequence)
	frame.Visible = true
	frame.LayoutOrder = -record.Sequence
	frame.BackgroundColor3 = record.Item.Config.Style.BackgroundColor
	frame.BackgroundTransparency = 1
	record.Frame = frame

	local message = frame:FindFirstChild("Message", true)
	if message and message:IsA("TextLabel") then
		record.MessageLabel = message
		message.Text = self:_displayText(record)
		message.TextColor3 = record.Item.Config.Style.TextColor
		message.TextTransparency = 1
	end

	local icon = frame:FindFirstChild("Icon", true)
	if icon and icon:IsA("ImageLabel") then
		icon.Image = record.Item.Config.Style.Icon or ""
		icon.ImageColor3 = record.Item.Config.Style.AccentColor
		icon.ImageTransparency = 1
		icon.Visible = record.Item.Config.Style.Icon ~= nil and record.Item.Config.Style.Icon ~= ""
	end

	local stroke = frame:FindFirstChildWhichIsA("UIStroke", true)
	if stroke then
		stroke.Color = record.Item.Config.Style.AccentColor
		stroke.Transparency = 1
	end

	frame.Parent = self._container
	record.ExpiresAt = os.clock() + (record.Item.Config.DisplaySeconds or DEFAULT_DISPLAY_SECONDS)

	local fadeInTweens = self:_createFadeTweens(record, false)
	for _, tween in ipairs(fadeInTweens) do
		tween:Play()
	end
	if fadeInTweens[1] then
		fadeInTweens[1].Completed:Wait()
	end
	if self._destroyed or record.Removed then
		return
	end

	while not self._destroyed and not record.Removed do
		while not self._destroyed and not record.Removed do
			local remaining = (record.ExpiresAt or os.clock()) - os.clock()
			if remaining <= 0 then
				break
			end
			task.wait(math.min(POLL_INTERVAL_SECONDS, remaining))
		end

		if self._destroyed or record.Removed then
			return
		end

		local fadeOutStartedAt = os.clock()
		local fadeOutDuration = record.Item.Config.FadeOutSeconds or DEFAULT_FADE_OUT_SECONDS
		local fadeOutTweens = self:_createFadeTweens(record, true)
		for _, tween in ipairs(fadeOutTweens) do
			tween:Play()
		end

		local displayExtended = false
		while not self._destroyed and not record.Removed do
			-- A duplicate/replace-key update during fade-out extends the current toast.
			if (record.ExpiresAt or 0) > fadeOutStartedAt then
				for _, tween in ipairs(fadeOutTweens) do
					pcall(function()
						tween:Cancel()
						tween:Destroy()
					end)
				end

				if frame.Parent then
					frame.BackgroundTransparency = 0.12
				end
				if record.MessageLabel then
					record.MessageLabel.TextTransparency = 0
				end
				local currentIcon = frame:FindFirstChild("Icon", true)
				if currentIcon and currentIcon:IsA("ImageLabel") and currentIcon.Visible then
					currentIcon.ImageTransparency = 0
				end
				local currentStroke = frame:FindFirstChildWhichIsA("UIStroke", true)
				if currentStroke then
					currentStroke.Transparency = 0
				end
				displayExtended = true
				break
			end

			local fadeRemaining = fadeOutDuration - (os.clock() - fadeOutStartedAt)
			if fadeRemaining <= 0 then
				break
			end
			task.wait(math.min(POLL_INTERVAL_SECONDS, fadeRemaining))
		end

		if self._destroyed or record.Removed then
			return
		end
		if not displayExtended then
			self:_finishRecord(record)
			return
		end
	end
end

function ToastUIController:_pump()
	if self._destroyed then
		return
	end
	self:_sortQueue()
	while #self._active < MAX_VISIBLE_TOASTS and #self._queue > 0 do
		local record = table.remove(self._queue, 1)
		if record and not record.Removed then
			table.insert(self._active, record)
			task.spawn(function()
				self:_showRecord(record)
			end)
		end
	end
end

function ToastUIController:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, record in ipairs(self._queue) do
		self:_discardRecord(record)
	end
	for _, record in ipairs(self._active) do
		self:_discardRecord(record)
	end
	table.clear(self._queue)
	table.clear(self._active)
	table.clear(self._recordsByReplaceKey)
	self._lastToastRecord = nil
	-- NotificationGui is Studio-authored and is intentionally not destroyed here.
end

return ToastUIController
