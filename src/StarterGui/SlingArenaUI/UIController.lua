--!strict

-- Deprecated: migrated to Rojo UI templates + UIBinder.client.lua
local UIController = {}
UIController.__index = UIController

function UIController.new(_screenGui)
	return setmetatable({}, UIController)
end

function UIController:Start() end
function UIController:Destroy() end

return UIController
