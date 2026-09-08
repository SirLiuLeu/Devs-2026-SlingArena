--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local PathResolver = require(ReplicatedStorage.Shared.Utils.PathResolver)

local ConfirmationUIController = {}
ConfirmationUIController.__index = ConfirmationUIController

function ConfirmationUIController.new(playerGui: PlayerGui)
	return setmetatable({ _playerGui = playerGui, _connections = {} }, ConfirmationUIController)
end

function ConfirmationUIController:Start()
	self._gui = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Confirmation.ScreenGui) :: ScreenGui?
	self._root = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Confirmation.Root) :: GuiObject?
	self._text = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Confirmation.ConfirmText) :: TextLabel?
	self._confirm = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Confirmation.Confirm) :: GuiButton?
	self._cancel = PathResolver.resolvePath(self._playerGui, ProjectTreeSpec.UI.Confirmation.Cancel) :: GuiButton?
	if self._gui then self._gui.Enabled = false end
end

function ConfirmationUIController:RequestConfirm(text: string, onConfirmCallback: () -> ())
	if not self._gui or not self._confirm or not self._cancel then return end
	self:Close()
	if self._text then self._text.Text = text end
	self._gui.Enabled = true
	local resolved = false
	local function finish(confirmed: boolean)
		if resolved then return end
		resolved = true
		self:Close()
		if confirmed then onConfirmCallback() end
	end
	table.insert(self._connections, self._confirm.MouseButton1Click:Connect(function() finish(true) end))
	table.insert(self._connections, self._cancel.MouseButton1Click:Connect(function() finish(false) end))
end

function ConfirmationUIController:Close()
	if self._gui then self._gui.Enabled = false end
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	table.clear(self._connections)
end

function ConfirmationUIController:Destroy() self:Close() end
return ConfirmationUIController
