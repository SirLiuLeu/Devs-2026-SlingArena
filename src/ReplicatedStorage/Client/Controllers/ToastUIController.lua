--!strict

local TweenService = game:GetService("TweenService")

local ToastUIController = {}
ToastUIController.__index = ToastUIController

local MAX_QUEUE_SIZE = 5
local DISPLAY_SECONDS = 2.5
local FADE_SECONDS = 0.25

function ToastUIController.new(playerGui: PlayerGui)
	local self = setmetatable({}, ToastUIController)
	self._playerGui = playerGui
	self._queue = {} :: { string }
	self._active = false
	self._destroyed = false
	self._tweens = {} :: { Tween }
	return self
end

function ToastUIController:Enqueue(message: any)
	if self._destroyed then
		return
	end
	local text = if type(message) == "table" then tostring(message.Message or message.Text or message.EventType or "") else tostring(message)
	if text == "" then
		return
	end
	if #self._queue >= MAX_QUEUE_SIZE then
		table.remove(self._queue, 1)
	end
	table.insert(self._queue, text)
	self:_pump()
end

function ToastUIController:_makeToast(text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "ToastNotification"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.08)
	label.Size = UDim2.fromOffset(420, 48)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = text
	label.Parent = self._playerGui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
	return label
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
	local text = table.remove(self._queue, 1)
	if not text then
		return
	end
	self._active = true
	task.spawn(function()
		local toast = self:_makeToast(text)
		local tweens = {
			self:_trackTween(TweenService:Create(toast, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 0.2, TextTransparency = 0 })),
		}
		tweens[1]:Play()
		tweens[1].Completed:Wait()
		task.wait(DISPLAY_SECONDS)
		if not self._destroyed then
			local fade = self:_trackTween(TweenService:Create(toast, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 1, TextTransparency = 1 }))
			table.insert(tweens, fade)
			fade:Play()
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
