--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NotificationConfigData = require(ReplicatedStorage.Shared.Config.NotificationConfigData)

local ToastUIController = {}
ToastUIController.__index = ToastUIController

local MAX_QUEUE_SIZE = 5
local FADE_SECONDS = 0.25

export type ToastItem = {
	Type: string,
	I18nKey: string,
	Priority: number,
	Args: { [string]: any },
	Text: string,
	Config: NotificationConfigData.NotificationConfig,
	Sequence: number,
}

function ToastUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, ToastUIController)
	self._playerGui = playerGui
	self._queue = {} :: { ToastItem }
	self._active = false
	self._destroyed = false
	self._tweens = {} :: { Tween }
	self._sequence = 0
	return self
end

local function formatTemplate(templateText: string, args: { [string]: any }): string
	return (string.gsub(templateText, "{([%w_]+)}", function(key)
		local value = args[key]
		return if value == nil then "" else tostring(value)
	end))
end

function ToastUIController:_normalize(message: any): ToastItem?
	local notificationType = "Generic"
	local args = {} :: { [string]: any }
	local text = ""
	local priorityOverride = nil :: number?
	local i18nKeyOverride = nil :: string?

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
	else
		text = tostring(message or "")
		args.message = text
	end

	local config = NotificationConfigData.Get(notificationType)
	if text == "" then
		text = formatTemplate(config.FallbackText, args)
	end
	if text == "" then
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
	}
end

function ToastUIController:_sortQueue()
	table.sort(self._queue, function(a, b)
		if a.Priority == b.Priority then
			return a.Sequence < b.Sequence
		end
		return a.Priority > b.Priority
	end)
end

function ToastUIController:_tryInsert(item: ToastItem)
	if #self._queue < MAX_QUEUE_SIZE then
		table.insert(self._queue, item)
		self:_sortQueue()
		return
	end

	local lowestIndex = 1
	for index, queued in ipairs(self._queue) do
		local lowest = self._queue[lowestIndex]
		if queued.Priority < lowest.Priority or (queued.Priority == lowest.Priority and queued.Sequence > lowest.Sequence) then
			lowestIndex = index
		end
	end
	if item.Priority <= self._queue[lowestIndex].Priority then
		return
	end
	table.remove(self._queue, lowestIndex)
	table.insert(self._queue, item)
	self:_sortQueue()
end

function ToastUIController:Enqueue(message: any)
	if self._destroyed then
		return
	end
	local item = self:_normalize(message)
	if not item then
		return
	end
	self:_tryInsert(item)
	self:_pump()
end

function ToastUIController:_makeToast(item: ToastItem): Frame
	local style = item.Config.Style
	local frame = Instance.new("Frame")
	frame.Name = "ToastNotification"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.08)
	frame.Size = UDim2.fromOffset(460, 56)
	frame.BackgroundColor3 = style.BackgroundColor
	frame.BackgroundTransparency = 1
	frame.Parent = self._playerGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 6, 1, 0)
	accent.BackgroundColor3 = style.AccentColor
	accent.BackgroundTransparency = 1
	accent.BorderSizePixel = 0
	accent.Parent = frame

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = style.Icon
	icon.ImageColor3 = style.AccentColor
	icon.ImageTransparency = if style.Icon == "" then 1 else 1
	icon.Position = UDim2.fromOffset(18, 12)
	icon.Size = UDim2.fromOffset(32, 32)
	icon.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Message"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(60, 0)
	label.Size = UDim2.new(1, -76, 1, 0)
	label.Font = Enum.Font.GothamBold
	label.Text = item.Text
	label.TextColor3 = style.TextColor
	label.TextTransparency = 1
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
	return frame
end

function ToastUIController:_trackTween(tween: Tween): Tween
	table.insert(self._tweens, tween)
	return tween
end

function ToastUIController:_cleanupToast(toast: Instance?, tweens: { Tween })
	for _, tween in ipairs(tweens) do
		pcall(function()
			tween:Cancel()
			tween:Destroy()
		end)
	end
	if toast then
		toast:Destroy()
	end
end

function ToastUIController:_pump()
	if self._active or self._destroyed then
		return
	end
	self:_sortQueue()
	local item = table.remove(self._queue, 1)
	if not item then
		return
	end
	self._active = true
	task.spawn(function()
		local toast = self:_makeToast(item)
		local message = toast:FindFirstChild("Message") :: TextLabel?
		local accent = toast:FindFirstChild("Accent") :: Frame?
		local icon = toast:FindFirstChild("Icon") :: ImageLabel?
		local tweens = {
			self:_trackTween(TweenService:Create(toast, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 0.12 })),
		}
		if message then table.insert(tweens, self:_trackTween(TweenService:Create(message, TweenInfo.new(FADE_SECONDS), { TextTransparency = 0 }))) end
		if accent then table.insert(tweens, self:_trackTween(TweenService:Create(accent, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 0 }))) end
		if icon and icon.Image ~= "" then table.insert(tweens, self:_trackTween(TweenService:Create(icon, TweenInfo.new(FADE_SECONDS), { ImageTransparency = 0 }))) end
		for _, tween in ipairs(tweens) do tween:Play() end
		tweens[1].Completed:Wait()
		task.wait(item.Config.DisplaySeconds or 2.5)
		if not self._destroyed then
			local fade = self:_trackTween(TweenService:Create(toast, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 1 }))
			table.insert(tweens, fade)
			if message then table.insert(tweens, self:_trackTween(TweenService:Create(message, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1 }))) end
			if accent then table.insert(tweens, self:_trackTween(TweenService:Create(accent, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 1 }))) end
			if icon then table.insert(tweens, self:_trackTween(TweenService:Create(icon, TweenInfo.new(FADE_SECONDS), { ImageTransparency = 1 }))) end
			for index = #tweens - 3, #tweens do if tweens[index] then tweens[index]:Play() end end
			fade.Completed:Wait()
		end
		self:_cleanupToast(toast, tweens)
		self._active = false
		self:_pump()
	end)
end

function ToastUIController:Destroy()
	self._destroyed = true
	table.clear(self._queue)
	for _, tween in ipairs(self._tweens) do
		pcall(function()
			tween:Cancel()
			tween:Destroy()
		end)
	end
	table.clear(self._tweens)
	for _, child in ipairs(self._playerGui:GetChildren()) do
		if child.Name == "ToastNotification" then
			child:Destroy()
		end
	end
end

return ToastUIController
