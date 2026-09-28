--!strict

-- Renders an asset model into a ViewportFrame. Each frame retains its preview
-- until its requested definition changes, avoiding clone/rebuild storms during
-- inventory state refreshes.
local PreviewRenderer = {}

local PREVIEW_MODEL_NAME = "PreviewModel"
local PREVIEW_CAMERA_NAME = "PreviewCamera"
local DEFAULT_FOV = 45
local FRAME_PADDING = 1.15

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

local function fitCamera(camera: Camera, model: Model, viewportFrame: ViewportFrame, config: any?)
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

	local rotation = config and config.Rotation
	local rotationCFrame = if typeof(rotation) == "CFrame" then rotation
		elseif typeof(rotation) == "Vector3" then CFrame.fromOrientation(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		else CFrame.identity
	local offset = if config and typeof(config.Offset) == "Vector3" then config.Offset else Vector3.zero
	-- The bounding-box center, rather than RootPart, correctly frames asymmetric pets.
	local viewDirection = rotationCFrame:VectorToWorldSpace(Vector3.new(1, 0.2, 1)).Unit
	local focusPosition = center.Position + offset
	camera.CFrame = CFrame.lookAt(focusPosition + viewDirection * distance, focusPosition)
end

-- Replaces every preview object in viewportFrame with itemId's model from
-- rootFolder. rootFolder is normally ReplicatedStorage.Assets.Pets or
-- ReplicatedStorage.Assets.Launchers; no asset paths are hardcoded here.
function PreviewRenderer.Populate(viewportFrame: ViewportFrame, rootFolder: Instance?, itemId: string, config: any?): Model
	local sourceAsset = if rootFolder then rootFolder:FindFirstChild(itemId) else nil
	local signature = itemId
	local existingModel = viewportFrame:FindFirstChild(PREVIEW_MODEL_NAME)
	local existingCamera = viewportFrame:FindFirstChild(PREVIEW_CAMERA_NAME)
	if viewportFrame:GetAttribute("PreviewSignature") == signature
		and existingModel and existingModel:IsA("Model") and existingCamera and existingCamera:IsA("Camera") then
		fitCamera(existingCamera, existingModel, viewportFrame, config)
		viewportFrame.CurrentCamera = existingCamera
		return existingModel
	end
	clearViewport(viewportFrame)

	local sourceModel = sourceAsset and findSourceModel(sourceAsset) or nil
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

	fitCamera(previewCamera, previewModel, viewportFrame, config)
	viewportFrame.CurrentCamera = previewCamera
	viewportFrame:SetAttribute("PreviewSignature", signature)
	return previewModel
end

return PreviewRenderer
