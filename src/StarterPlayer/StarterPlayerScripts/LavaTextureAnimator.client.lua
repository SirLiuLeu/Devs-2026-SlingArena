--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LAVA_TRAP_NAME = "LavaTrap"
local LAVA_VISUAL_NAME = "Lava_Visual"
local LAVA_TEXTURE_NAME = "LavaTexture"

-- Local-only, deliberately subtle drift (studs per second).
local OFFSET_U_SPEED = 0.025
local OFFSET_V_SPEED = 0.012

local activeTextures = {} :: { [Texture]: boolean }

local function registerLavaTexture(instance: Instance)
	if not instance:IsA("Texture") or instance.Name ~= LAVA_TEXTURE_NAME then
		return
	end

	local visual = instance.Parent
	local lavaTrap = visual and visual.Parent
	if visual and visual.Name == LAVA_VISUAL_NAME and lavaTrap and lavaTrap.Name == LAVA_TRAP_NAME then
		activeTextures[instance] = true
	end
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	registerLavaTexture(descendant)
end

Workspace.DescendantAdded:Connect(registerLavaTexture)

RunService.RenderStepped:Connect(function(deltaTime: number)
	for texture in pairs(activeTextures) do
		if not texture:IsDescendantOf(Workspace) then
			activeTextures[texture] = nil
			continue
		end

		local tileU = math.max(texture.StudsPerTileU, 0.001)
		local tileV = math.max(texture.StudsPerTileV, 0.001)
		texture.OffsetStudsU = (texture.OffsetStudsU + OFFSET_U_SPEED * deltaTime) % tileU
		texture.OffsetStudsV = (texture.OffsetStudsV + OFFSET_V_SPEED * deltaTime) % tileV
	end
end)
