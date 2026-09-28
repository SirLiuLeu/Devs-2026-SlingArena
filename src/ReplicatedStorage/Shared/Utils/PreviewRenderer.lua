--!strict

-- Viewports retain a clone until their requested definition changes. This keeps
-- inventory reconciliation from cloning every model again on state updates.
local PreviewRenderer = {}

local PREVIEW_MODEL_NAME = "PreviewModel"
local PREVIEW_CAMERA_NAME = "PreviewCamera"
local DEFAULT_FOV = 45
local FRAME_PADDING = 1.15

-- Optional per-pet framing overrides. Rotation is applied around the model
-- centre; Offset is expressed in model-space studs.
PreviewRenderer.PetPreviewConfig = {} :: { [string]: { Rotation: CFrame?, Offset: Vector3? } }
local cameraResults = {} :: { [string]: { CFrame: CFrame, FieldOfView: number } }

local function clearViewport(viewportFrame: ViewportFrame)
	viewportFrame.CurrentCamera = nil
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
end

local function findSourceModel(asset: Instance): Model?
	if asset:IsA("Model") then
		return asset
	end
	return asset:FindFirstChildWhichIsA("Model", true)
end

local function findSourceCamera(asset: Instance): Camera?
	return asset:FindFirstChildWhichIsA("Camera", true)
end

local function getConfigKey(config: { Rotation: CFrame?, Offset: Vector3? }?): string
	if not config then return "default" end
	local rotation = config.Rotation
	local offset = config.Offset
	if rotation then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rotation:GetComponents()
		return string.format("r=%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,o=%s", x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22, tostring(offset or Vector3.zero))
	end
	return "r=default,o=" .. tostring(offset or Vector3.zero)
end

local function createPlaceholder(itemId: string): Model
	local model = Instance.new("Model")
	model.Name = PREVIEW_MODEL_NAME

	local part = Instance.new("Part")
	part.Name = "MissingAssetPlaceholder"
	part.Size = Vector3.new(2, 2, 2)
	part.Color = Color3.fromRGB(255, 70, 70)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("MissingItemId", itemId)
	part.Parent = model
	model.PrimaryPart = part

	return model
end

local function fitCamera(camera: Camera, model: Model, viewportFrame: ViewportFrame, config: { Rotation: CFrame?, Offset: Vector3? }?)
	local center, size = model:GetBoundingBox()
	local width = math.max(size.X, 0.01)
	local height = math.max(size.Y, 0.01)
	local depth = math.max(size.Z, 0.01)
	local viewportSize = viewportFrame.AbsoluteSize
	local aspectRatio = if viewportSize.Y > 0 then viewportSize.X / viewportSize.Y else 1
	local verticalFovRadians = math.rad(DEFAULT_FOV)
	local halfVerticalFovTangent = math.tan(verticalFovRadians / 2)
	local distanceForHeight = (height / 2) / halfVerticalFovTangent
	local distanceForWidth = (width / 2) / (halfVerticalFovTangent * math.max(aspectRatio, 0.01))
	local distance = (math.max(distanceForHeight, distanceForWidth) + depth / 2) * FRAME_PADDING

	camera.FieldOfView = DEFAULT_FOV

	-- Bounding-box centre frames asymmetric pets correctly; RootPart is often
	-- intentionally offset in these assets.
	local rotation = (config and config.Rotation) or CFrame.new()
	local offset = (config and config.Offset) or Vector3.zero
	local focusPosition = center.Position + center:VectorToWorldSpace(offset)
	local forward = rotation:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local up = rotation:VectorToWorldSpace(Vector3.yAxis)
	camera.CFrame = CFrame.lookAt(focusPosition + forward * distance, focusPosition, up)
end

-- Replaces every preview object in viewportFrame with itemId's model from
-- rootFolder. rootFolder is normally ReplicatedStorage.Assets.Pets or
-- ReplicatedStorage.Assets.Launchers; no asset paths are hardcoded here.
function PreviewRenderer.Populate(viewportFrame: ViewportFrame, rootFolder: Instance?, itemId: string, config: { Rotation: CFrame?, Offset: Vector3? }?): Model
	local sourceAsset = if rootFolder then rootFolder:FindFirstChild(itemId) else nil
	local sourceModel = sourceAsset and findSourceModel(sourceAsset) or nil
	local effectiveConfig = config or PreviewRenderer.PetPreviewConfig[itemId]
	local sourceKey = string.format("%s:%s:%s", itemId, sourceModel and sourceModel:GetDebugId() or "missing", getConfigKey(effectiveConfig))
	local existing = viewportFrame:FindFirstChild(PREVIEW_MODEL_NAME)
	if existing and existing:IsA("Model") and viewportFrame:GetAttribute("PreviewSourceKey") == sourceKey then
		return existing
	end
	clearViewport(viewportFrame)
	local previewModel: Model

	if sourceModel then
		local clonedModel = sourceModel:Clone()
		if not clonedModel:IsA("Model") then
			warn(string.format("[PREVIEW_RENDERER] Could not clone model %q", itemId))
			previewModel = createPlaceholder(itemId)
		else
			previewModel = clonedModel
		end
		previewModel.Name = PREVIEW_MODEL_NAME
	else
		local folderName = if rootFolder then rootFolder:GetFullName() else "<nil>"
		warn(string.format("[PREVIEW_RENDERER] Missing preview model %q in %s", itemId, folderName))
		previewModel = createPlaceholder(itemId)
	end
	previewModel.Parent = viewportFrame

	local sourceCamera = sourceAsset and findSourceCamera(sourceAsset) or nil
	local previewCamera: Camera
	if sourceCamera then
		local clonedCamera = sourceCamera:Clone()
		if clonedCamera:IsA("Camera") then
			previewCamera = clonedCamera
		else
			previewCamera = Instance.new("Camera")
		end
	else
		previewCamera = Instance.new("Camera")
	end
	previewCamera.Name = PREVIEW_CAMERA_NAME
	previewCamera.Parent = viewportFrame

	local viewportSize = viewportFrame.AbsoluteSize
	local cameraKey = string.format("%s:%dx%d", sourceKey, viewportSize.X, viewportSize.Y)
	local cachedCamera = cameraResults[cameraKey]
	if cachedCamera then
		previewCamera.FieldOfView = cachedCamera.FieldOfView
		previewCamera.CFrame = cachedCamera.CFrame
	else
		fitCamera(previewCamera, previewModel, viewportFrame, effectiveConfig)
		cameraResults[cameraKey] = { CFrame = previewCamera.CFrame, FieldOfView = previewCamera.FieldOfView }
	end
	viewportFrame.CurrentCamera = previewCamera
	viewportFrame:SetAttribute("PreviewSourceKey", sourceKey)
	return previewModel
end

return PreviewRenderer
