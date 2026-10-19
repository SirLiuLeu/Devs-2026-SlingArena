--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local ConfirmationUIController = {}
ConfirmationUIController.__index = ConfirmationUIController

function ConfirmationUIController.new(playerGui: PlayerGui)
	return setmetatable({
		_playerGui = playerGui,
		_buttonConnections = {},
		_boundConfirm = nil,
		_boundCancel = nil,
		_pendingCallback = nil,
		_pendingCancelCallback = nil,
		_requestSequence = 0,
		_activeRequestId = nil,
	}, ConfirmationUIController)
end

function ConfirmationUIController:_setVisible(visible: boolean)
	if self._root and self._root.Parent then
		self._root.Visible = visible
	end
	if self._gui and self._gui.Parent then
		self._gui.Enabled = visible
	end
end

function ConfirmationUIController:_bindButtons()
	if self._boundConfirm == self._confirm and self._boundCancel == self._cancel then
		return
	end

	for _, connection in ipairs(self._buttonConnections) do
		connection:Disconnect()
	end
	table.clear(self._buttonConnections)
	self._boundConfirm = self._confirm
	self._boundCancel = self._cancel

	if self._confirm then
		table.insert(self._buttonConnections, self._confirm.Activated:Connect(function()
			self:_finish(true, "confirm_button")
		end))
	end
	if self._cancel then
		table.insert(self._buttonConnections, self._cancel.Activated:Connect(function()
			self:_finish(false, "cancel_button")
		end))
	end
end

function ConfirmationUIController:_resolveReferences(): boolean
	local ui = ProjectTreeSpec.UI.Confirmation
	self._gui = PathResolver.resolvePath(self._playerGui, ui.ScreenGui) :: ScreenGui?
	self._root = PathResolver.resolvePath(self._playerGui, ui.Root) :: GuiObject?
	self._text = PathResolver.resolvePath(self._playerGui, ui.ConfirmText) :: TextLabel?
	self._confirm = PathResolver.resolvePath(self._playerGui, ui.Confirm) :: GuiButton?
	self._cancel = PathResolver.resolvePath(self._playerGui, ui.Cancel) :: GuiButton?

	if not self._gui then warn("[CONFIRMATION_UI] Missing PlayerGui.ConfirmationGui (ScreenGui).") end
	if not self._root then warn("[CONFIRMATION_UI] Missing PlayerGui.ConfirmationGui.Root (GuiObject).") end
	if not self._text then warn("[CONFIRMATION_UI] Missing PlayerGui.ConfirmationGui.Root.ConfirmText (TextLabel).") end
	if not self._confirm then warn("[CONFIRMATION_UI] Missing PlayerGui.ConfirmationGui.Root.Confirm (GuiButton).") end
	if not self._cancel then warn("[CONFIRMATION_UI] Missing PlayerGui.ConfirmationGui.Root.Cancel (GuiButton).") end

	self:_bindButtons()
	return self._gui ~= nil and self._root ~= nil and self._text ~= nil and self._confirm ~= nil and self._cancel ~= nil
end

function ConfirmationUIController:Start()
	self:_resolveReferences()
	self:_setVisible(false)
end

function ConfirmationUIController:RequestConfirm(text: string, onConfirmCallback: () -> (), onCancelCallback: (() -> ())?): boolean
	if not self:_resolveReferences() then
		warn("[CONFIRMATION_UI] Confirmation request was not shown; GUI/root/ConfirmText/Confirm/Cancel is missing.")
		return false
	end

	if self._activeRequestId ~= nil then
		warn(string.format(
			"[CONFIRMATION_UI] Replacing active confirmation request id=%d with a new request.",
			self._activeRequestId
		))
		self:_finish(false, "replaced_by_new_request")
	else
		self:_setVisible(false)
	end

	self._requestSequence += 1
	local requestId = self._requestSequence
	self._activeRequestId = requestId
	self._pendingCallback = onConfirmCallback
	self._pendingCancelCallback = onCancelCallback
	if self._text then self._text.Text = text end
	self:_setVisible(true)

	print(string.format("[CONFIRMATION_UI] stage=opened requestId=%d text=%q", requestId, text))
	return true
end

function ConfirmationUIController:_finish(confirmed: boolean, reason: string)
	local requestId = self._activeRequestId
	if requestId == nil then
		print(string.format("[CONFIRMATION_UI] stage=ignored_click action=%s reason=NoActiveRequest", reason))
		self:_setVisible(false)
		return
	end

	local callback = if confirmed then self._pendingCallback else self._pendingCancelCallback
	self._activeRequestId = nil
	self._pendingCallback = nil
	self._pendingCancelCallback = nil
	self:_setVisible(false)

	print(string.format(
		"[CONFIRMATION_UI] stage=closed requestId=%d action=%s reason=%s",
		requestId,
		if confirmed then "confirm" else "cancel",
		reason
	))

	if callback then
		local ok, callbackError = pcall(callback)
		if not ok then
			warn(string.format(
				"[CONFIRMATION_UI] Callback failed requestId=%d action=%s error=%s",
				requestId,
				if confirmed then "confirm" else "cancel",
				tostring(callbackError)
			))
		end
	end
end

function ConfirmationUIController:Close()
	if self._activeRequestId ~= nil then
		self:_finish(false, "programmatic_close")
	else
		self:_setVisible(false)
	end
end

function ConfirmationUIController:Destroy()
	self:Close()
	for _, connection in ipairs(self._buttonConnections) do
		connection:Disconnect()
	end
	table.clear(self._buttonConnections)
	self._boundConfirm = nil
	self._boundCancel = nil
end

return ConfirmationUIController
