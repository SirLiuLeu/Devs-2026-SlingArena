--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)

type SoundDescriptor = { [string]: any }
type ActiveSoundInfo = { Name: string, PoolLimit: number, Anchor: BasePart?, StartedAt: number }

local SoundManager = {}
local pools: { [string]: { Sound } } = {}
local active: { [Sound]: ActiveSoundInfo } = {}
local loops: { [string]: Sound } = {}
local anchorPool: { BasePart } = {}
local warned: { [string]: boolean } = {}
local anchorFolder: Folder? = nil

local releaseSound: (Sound) -> ()
local releaseAnchor: (BasePart) -> ()

local function warnOnce(key: string, message: string)
	if warned[key] then return end
	warned[key] = true
	warn("[SoundManager] " .. message)
end

local function normalizeSoundId(value: any): string?
	if type(value) == "number" then
		if value <= 0 then return nil end
		return "rbxassetid://" .. tostring(math.floor(value))
	end
	if type(value) ~= "string" then return nil end
	local trimmed = string.gsub(value, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then return nil end
	if string.match(trimmed, "^%d+$") then return "rbxassetid://" .. trimmed end
	return trimmed
end

local function resolveDescriptor(soundName: string, overrides: SoundDescriptor?): SoundDescriptor?
	local definition = SoundConfig[soundName]
	if type(definition) ~= "table" then
		warnOnce("unknown:" .. soundName, "No SoundConfig entry named '" .. soundName .. "'.")
		return nil
	end
	local resolved: SoundDescriptor = {}
	for key, value in pairs(definition) do resolved[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do resolved[key] = value end
	end
	resolved.SoundId = normalizeSoundId(resolved.SoundId)
	if not resolved.SoundId then
		warnOnce("id:" .. soundName, "SoundId for '" .. soundName .. "' is empty; fill it in Shared.Config.SoundConfig.")
		return nil
	end
	return resolved
end

local function ensureAnchorFolder(): Folder?
	if anchorFolder and anchorFolder.Parent then return anchorFolder end
	local folderName = if RunService:IsServer() then "__SlingArenaSFXPool_Server" else "__SlingArenaSFXPool_Client"
	local existing = Workspace:FindFirstChild(folderName)
	if existing and existing:IsA("Folder") then
		anchorFolder = existing
		return existing
	end
	if existing then
		warnOnce("anchor-folder:" .. folderName, "Workspace." .. folderName .. " exists but is not a Folder.")
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = Workspace
	anchorFolder = folder
	return folder
end

local function acquireAnchor(): BasePart?
	local folder = ensureAnchorFolder()
	if not folder then return nil end
	local anchor = table.remove(anchorPool)
	if not anchor then
		anchor = Instance.new("Part")
		anchor.Name = "SFXEmitter"
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Anchored = true
		anchor.Transparency = 1
		anchor.CastShadow = false
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor.Massless = true
	end
	anchor.CFrame = CFrame.new(0, -10000, 0)
	anchor.Parent = folder
	return anchor
end

releaseAnchor = function(anchor: BasePart)
	if not anchor.Parent then return end
	anchor.CFrame = CFrame.new(0, -10000, 0)
	local folder = ensureAnchorFolder()
	if folder then anchor.Parent = folder end
	if #anchorPool < 16 then table.insert(anchorPool, anchor) else anchor:Destroy() end
end

local function removeLoopReferences(sound: Sound)
	for loopKey, loopSound in pairs(loops) do
		if loopSound == sound then loops[loopKey] = nil end
	end
end

releaseSound = function(sound: Sound)
	local info = active[sound]
	if not info then return end
	active[sound] = nil
	removeLoopReferences(sound)
	if not sound.Parent then
		if info.Anchor then releaseAnchor(info.Anchor) end
		return
	end
	sound:Stop()
	sound.Looped = false
	sound.TimePosition = 0
	sound.Volume = 0
	sound.Parent = SoundService
	if info.Anchor then releaseAnchor(info.Anchor) end
	local pool = pools[info.Name]
	if not pool then
		pool = {}
		pools[info.Name] = pool
	end
	if #pool < info.PoolLimit then table.insert(pool, sound) else sound:Destroy() end
end

local function createSound(soundName: string): Sound
	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.Parent = SoundService
	sound.Ended:Connect(function() releaseSound(sound) end)
	sound.Destroying:Connect(function()
		local info = active[sound]
		if info then
			active[sound] = nil
			removeLoopReferences(sound)
			if info.Anchor then releaseAnchor(info.Anchor) end
		end
	end)
	return sound
end

local function countActive(soundName: string): (number, Sound?)
	local count = 0
	local oldestSound: Sound? = nil
	local oldestAt = math.huge
	for sound, info in pairs(active) do
		if info.Name == soundName then
			count += 1
			if info.StartedAt < oldestAt then
				oldestAt = info.StartedAt
				oldestSound = sound
			end
		end
	end
	return count, oldestSound
end

local function acquireSound(soundName: string, descriptor: SoundDescriptor): Sound
	local pool = pools[soundName]
	local sound = if pool then table.remove(pool) else nil
	if not sound then sound = createSound(soundName) end
	active[sound] = {
		Name = soundName,
		PoolLimit = math.max(0, math.floor(tonumber(descriptor.MaxPoolSize) or 6)),
		Anchor = nil,
		StartedAt = os.clock(),
	}
	return sound
end

local function resolveParent(parentOrPosition: any): (Instance, BasePart?)
	if typeof(parentOrPosition) == "Vector3" then
		local anchor = acquireAnchor()
		if anchor then
			anchor.CFrame = CFrame.new(parentOrPosition)
			return anchor, anchor
		end
		return SoundService, nil
	end
	if typeof(parentOrPosition) == "Instance" then
		if parentOrPosition:IsA("Attachment") or parentOrPosition:IsA("BasePart") then return parentOrPosition, nil end
		if parentOrPosition:IsA("Model") then
			local root = parentOrPosition.PrimaryPart or parentOrPosition:FindFirstChildWhichIsA("BasePart", true)
			if root then return root, nil end
		end
	end
	return SoundService, nil
end

function SoundManager.Play(soundName: string, parentOrPosition: any?, overrides: SoundDescriptor?): Sound?
	local descriptor = resolveDescriptor(soundName, overrides)
	if not descriptor then return nil end
	local maxConcurrent = math.max(1, math.floor(tonumber(descriptor.MaxConcurrent) or 6))
	local count, oldest = countActive(soundName)
	while count >= maxConcurrent and oldest do
		releaseSound(oldest)
		count, oldest = countActive(soundName)
	end
	local sound = acquireSound(soundName, descriptor)
	sound.SoundId = descriptor.SoundId
	sound.Volume = math.max(0, tonumber(descriptor.Volume) or 1)
	sound.PlaybackSpeed = math.clamp(tonumber(descriptor.Pitch) or 1, 0.05, 4)
	sound.Looped = descriptor.Looped == true
	local rollOffMode = descriptor.RollOffMode
	if type(rollOffMode) == "string" then rollOffMode = (Enum.RollOffMode :: any)[rollOffMode] end
	if typeof(rollOffMode) == "EnumItem" then sound.RollOffMode = rollOffMode end
	sound.RollOffMinDistance = math.max(0, tonumber(descriptor.RollOffMinDistance) or 5)
	sound.RollOffMaxDistance = math.max(sound.RollOffMinDistance, tonumber(descriptor.RollOffMaxDistance) or 100)
	sound.EmitterSize = math.max(0, tonumber(descriptor.EmitterSize) or 3)
	local parent: Instance = SoundService
	local anchor: BasePart? = nil
	if descriptor.Spatial == true then
		parent, anchor = resolveParent(parentOrPosition)
	end
	local info = active[sound]
	if info then info.Anchor = anchor end
	sound.Parent = parent
	sound.TimePosition = 0
	sound:Play()
	return sound
end

function SoundManager.PlayAt(soundName: string, position: Vector3, overrides: SoundDescriptor?): Sound?
	return SoundManager.Play(soundName, position, overrides)
end

function SoundManager.PlayOn(soundName: string, parent: Instance, overrides: SoundDescriptor?): Sound?
	return SoundManager.Play(soundName, parent, overrides)
end

function SoundManager.PlayLoop(soundName: string, loopKey: string, parentOrPosition: any?, overrides: SoundDescriptor?): Sound?
	if type(loopKey) ~= "string" or loopKey == "" then return nil end
	SoundManager.StopLoop(loopKey)
	local merged: SoundDescriptor = {}
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do merged[key] = value end
	end
	merged.Looped = true
	local sound = SoundManager.Play(soundName, parentOrPosition, merged)
	if sound then loops[loopKey] = sound end
	return sound
end

function SoundManager.Stop(sound: Sound?)
	if sound and active[sound] then releaseSound(sound) end
end

function SoundManager.StopLoop(loopKey: string)
	local sound = loops[loopKey]
	if sound then
		loops[loopKey] = nil
		SoundManager.Stop(sound)
	end
end

function SoundManager.StopAllLoops()
	local loopKeys = {}
	for loopKey in pairs(loops) do table.insert(loopKeys, loopKey) end
	for _, loopKey in ipairs(loopKeys) do SoundManager.StopLoop(loopKey) end
end

return SoundManager
