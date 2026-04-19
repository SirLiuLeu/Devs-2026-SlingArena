--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local CombatService = require(ServerScriptService.Services.CombatService)
local MapServiceModule = require(ServerScriptService.Services.MapService)
local FoodServiceModule = require(ServerScriptService.Services.FoodService)
local SlingServiceModule = require(ServerScriptService.Services.SlingService)
local PlayerStateServiceModule = require(ServerScriptService.Services.PlayerStateService)
local ProjectTreeSpec = require(ReplicatedStorage.Shared.ProjectTreeSpec)
local SlingUiState = require(ReplicatedStorage.Shared.Utils.SlingUiState)
local RemoteContracts = require(ReplicatedStorage.Shared.RemoteContracts)

local function runTest(name: string, testFn)
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[CoreLoopTests] PASS %s", name))
	else
		warn(string.format("[CoreLoopTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function testArenaSpawnAndPrefabApisExist()
	if type(MapServiceModule.GetArenaSpawn) ~= "function" then
		error("MapService.GetArenaSpawn must exist")
	end
	if type(MapServiceModule.SpawnFood) ~= "function" then
		error("MapService.SpawnFood must exist")
	end
	if type(MapServiceModule.SpawnTrap) ~= "function" then
		error("MapService.SpawnTrap must exist")
	end
end

local function testTeleportPlayerJoinLeaveFlow()
	local joinTeleported = false
	local leaveTeleported = false
	local state = { map = nil, arena = nil }
	local fakePlayer = { Name = "Tester", UserId = 1001, Parent = game:GetService("Players") }

	local fakeRoundContext = {
		Remotes = Instance.new("Folder"),
		EventBus = { On = function() end },
		Services = {
			MapService = {
				GetActiveMap = function() return "LobbyMap" end,
				ActivateMap = function() end,
				GetArenaSpawn = function()
					local p = Instance.new("Part")
					p.CFrame = CFrame.new(10, 5, 10)
					return p
				end,
				GetLobbySpawn = function()
					local p = Instance.new("Part")
					p.CFrame = CFrame.new(0, 5, 0)
					return p
				end,
				GetMapDuration = function() return 1 end,
				GetDefaultArenaMapName = function() return "Arena_01" end,
			},
			PlayerService = {
				GetPawn = function() return {} end,
				SpawnPawn = function() return {} end,
				TeleportCharacterToSpawn = function(_, __, spawnPart)
					if spawnPart.Position.X == 10 then
						joinTeleported = true
					else
						leaveTeleported = true
					end
					return true
				end,
				IsAlive = function() return true end,
			},
			PlayerStateService = {
				SetMapName = function(_, __, value) state.map = value end,
				SetArenaStatus = function(_, __, value) state.arena = value end,
				SetTeleporting = function() end,
				GetDamageDealt = function() return 0 end,
			},
		},
	}

	local RoundService = require(ServerScriptService.Services.RoundService)
	local service = RoundService.new(fakeRoundContext)
	service:JoinArena(fakePlayer)
	if not joinTeleported or state.map ~= "Arena_01" or state.arena ~= "InArena" then
		error("JoinArena should teleport and set Arena_01/InArena")
	end
	service:LeaveArena(fakePlayer)
	if not leaveTeleported or state.map ~= "LobbyMap" or state.arena ~= "Lobby" then
		error("LeaveArena should teleport back to lobby and set Lobby status")
	end
end

local function assertAlmostEqual(actual: number, expected: number, epsilon: number, message: string)
	if math.abs(actual - expected) > epsilon then
		error(string.format("%s | actual=%.4f expected=%.4f", message, actual, expected))
	end
end

local function testChargeToLaunchForce()
	local minForce = SlingshotConfig.MIN_LAUNCH_FORCE
	local maxForce = SlingshotConfig.MAX_LAUNCH_FORCE

	local halfForce = SlingServiceModule.CalculateLaunchForce(0.5, minForce, maxForce, 1)
	assertAlmostEqual(halfForce, maxForce * 0.5, 0.0001, "chargePercent=0.5 should scale force")

	local maxForceResult = SlingServiceModule.CalculateLaunchForce(1, minForce, maxForce, 1)
	assertAlmostEqual(maxForceResult, maxForce, 0.0001, "chargePercent=1 should reach max force")

	local zeroForce = SlingServiceModule.CalculateLaunchForce(0, minForce, maxForce, 1)
	assertAlmostEqual(zeroForce, 0, 0.0001, "chargePercent=0 should produce no launch force")

	local clampedForce = SlingServiceModule.CalculateLaunchForce(5, minForce, maxForce, 2)
	assertAlmostEqual(clampedForce, maxForce, 0.0001, "force should clamp at max charge")

	local nanForce = SlingServiceModule.CalculateLaunchForce(0/0, minForce, maxForce, 1)
	if nanForce ~= nanForce then
		error("launch force must never be NaN")
	end
	assertAlmostEqual(nanForce, 0, 0.0001, "NaN charge input should sanitize to 0 force")
end

local function testReleaseDistanceMultiplierApplied()
	local boostedForce = SlingServiceModule.CalculateLaunchForce(1, SlingshotConfig.MIN_LAUNCH_FORCE, SlingshotConfig.MAX_LAUNCH_FORCE, 1)
	assertAlmostEqual(boostedForce, SlingshotConfig.MAX_LAUNCH_FORCE, 0.0001, "Release force should clamp to base max force before planar speed limits")
end

local function testReleaseSpeedMultiplierApplied()
	local root = Instance.new("Part")
	root.Anchored = true
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = workspace

	local state = {
		ChargeSpeed = 1,
		LaunchSpeed = SlingshotConfig.BaseLaunchForce,
		MovementState = "Idle",
	}
	local context = buildFakeSlingContext(root, state)
	local service = SlingServiceModule.new(context)
	local player = { UserId = 787, Name = "ReleaseSpeedTester", Parent = game:GetService("Players") }

	service:StartCharge(player, Vector3.new(40, 5, 0))
	local chargeState = service._chargeState[player]
	if not chargeState then
		root:Destroy()
		error("StartCharge should create per-player charge state for release speed test")
	end
	chargeState.chargeStartTime = os.clock() - SlingshotConfig.MAX_CHARGE_TIME

	service:ReleaseCharge(player, Vector3.new(40, 5, 0))
	local horizontalSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	assertAlmostEqual(horizontalSpeed, 48, 0.0001, "Full charge release should clamp planar speed to 3x default move speed")

	root:Destroy()
end

local function testChargeRatioProgressAndClamp()
	local maxChargeTime = SlingshotConfig.MAX_CHARGE_TIME
	local quarter = SlingServiceModule.CalculateChargeRatio(0, maxChargeTime * 0.25, maxChargeTime)
	assertAlmostEqual(quarter, 0.25, 0.0001, "Charge ratio should increase over elapsed charge time")

	local clamped = SlingServiceModule.CalculateChargeRatio(0, maxChargeTime * 2, maxChargeTime)
	assertAlmostEqual(clamped, 1, 0.0001, "Charge ratio should clamp to max value")
end

local function buildFakeSlingContext(rootPart: BasePart, stateTable: any, options: any?)
	local chargeEvents = {}
	local opts = options or {}
	local roundState = opts.roundState or "ActiveRound"
	local isQueued = opts.isQueued
	if isQueued == nil then
		isQueued = true
	end
	return {
		Remotes = Instance.new("Folder"),
		EventBus = {
			Fire = function(_, eventName, ...)
				table.insert(chargeEvents, { Event = eventName, Args = { ... } })
			end,
		},
		Services = {
			RoundService = {
				GetState = function() return roundState end,
				IsPlayerQueued = function() return isQueued end,
			},
			PlayerService = {
				GetRoot = function() return rootPart end,
				IsAlive = function() return true end,
			},
			PlayerStateService = {
				GetState = function() return stateTable end,
				SetCharging = function(_, _, charging, ratio)
					stateTable.IsCharging = charging
					stateTable.ChargeValue = ratio
				end,
				SetMovementState = function(_, _, movement)
					stateTable.MovementState = movement
				end,
				SetCooldownEndTime = function(_, _, cooldownEndTime)
					stateTable.CooldownEndTime = cooldownEndTime
				end,
				SetLastReleaseDuration = function(_, _, duration)
					stateTable.LastReleaseDuration = duration
				end,
			},
		},
	}, chargeEvents
end

local function testLobbyAllowsMoveAndRelease()
	local root = Instance.new("Part")
	root.Anchored = true
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = workspace

	local state = {
		ChargeSpeed = 1,
		MovementState = "Idle",
		MoveSpeed = 22,
	}
	local context = buildFakeSlingContext(root, state, { roundState = "Lobby", isQueued = false })
	local service = SlingServiceModule.new(context)
	local player = { UserId = 901, Name = "LobbyControlTester", Parent = game:GetService("Players") }

	service:HandleMoveRequest(player, { W = false, A = false, S = false, D = true })
	service:_stepMovement(1 / 60)
	if (service._input[player] :: Vector3).Magnitude <= 0 then
		root:Destroy()
		error("MoveRequest should be accepted in Lobby state")
	end

	service:StartCharge(player, Vector3.new(20, 5, 0))
	if not service._chargeState[player] then
		root:Destroy()
		error("StartCharge should be accepted in Lobby state")
	end

	service._chargeState[player].chargeStartTime = os.clock() - SlingshotConfig.MAX_CHARGE_TIME
	service:ReleaseCharge(player, Vector3.new(20, 5, 0))
	if state.MovementState ~= "Launched" then
		root:Destroy()
		error("ReleaseCharge should transition to Launched in Lobby state")
	end

	root:Destroy()
end

local function testLaunchedStatePreservesMomentum()
	local root = Instance.new("Part")
	root.Anchored = true
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = workspace
	root.AssemblyLinearVelocity = Vector3.new(120, 0, 0)

	local state = {
		ChargeSpeed = 1,
		MovementState = "Launched",
		MoveSpeed = 30,
	}
	local context = buildFakeSlingContext(root, state)
	local service = SlingServiceModule.new(context)
	local player = { UserId = 902, Name = "LaunchMomentumTester", Parent = game:GetService("Players") }

	service._input[player] = Vector3.new(1, 0, 0)
	service:_applyRootVelocity(player, root, service._input[player], 1 / 60)
	if root.AssemblyLinearVelocity.X < 119 then
		root:Destroy()
		error("Launched state should preserve horizontal release momentum")
	end

	root:Destroy()
end

local function testChargeResetAfterRelease()
	local root = Instance.new("Part")
	root.Anchored = true
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = workspace

	local state = {
		ChargeSpeed = 1,
		LaunchSpeed = SlingshotConfig.BaseLaunchForce,
		MovementState = "Idle",
	}
	local context = buildFakeSlingContext(root, state)
	local service = SlingServiceModule.new(context)
	local player = { UserId = 777, Name = "ChargeResetTester", Parent = game:GetService("Players") }

	service:StartCharge(player, Vector3.new(15, 5, 0))
	local chargeState = service._chargeState[player]
	if not chargeState then
		root:Destroy()
		error("StartCharge should create per-player charge state")
	end
	chargeState.chargeStartTime = os.clock() - SlingshotConfig.MAX_CHARGE_TIME

	service:ReleaseCharge(player, Vector3.new(30, 5, 0))
	if service._chargeState[player] ~= nil then
		root:Destroy()
		error("Charge state must reset to nil after release")
	end

	root:Destroy()
end

local function testRecoverCooldownMatchesReleaseDuration()
	local root = Instance.new("Part")
	root.Anchored = true
	root.Position = Vector3.new(0, 5, 0)
	root.Parent = workspace

	local state = {
		ChargeSpeed = 1,
		LaunchSpeed = SlingshotConfig.BaseLaunchForce,
		MovementState = "Launched",
		CooldownEndTime = 0,
		LastReleaseDuration = 0,
	}
	local context = buildFakeSlingContext(root, state)
	local service = SlingServiceModule.new(context)
	local player = { UserId = 778, Name = "RecoverDurationTester", Parent = game:GetService("Players") }

	service._releaseState[player] = {
		releaseStartTime = os.clock() - 1.25,
	}
	root.AssemblyLinearVelocity = Vector3.zero

	service:_stepMovementStates()
	if state.MovementState ~= "Recovering" then
		root:Destroy()
		error("Launched sling should transition into Recovering when velocity stops")
	end
	if state.LastReleaseDuration < 1.15 or state.LastReleaseDuration > 1.35 then
		root:Destroy()
		error(string.format("Recover cooldown should match the actual release duration, got %.3f", state.LastReleaseDuration))
	end
	local remaining = state.CooldownEndTime - os.clock()
	if remaining < 1.1 or remaining > 1.4 then
		root:Destroy()
		error(string.format("Cooldown end time should be offset by the release duration, got %.3f", remaining))
	end

	root:Destroy()
end

local function testLaunchDirectionNormalizedFromAim()
	local origin = Vector3.new(0, 0, 0)
	local aimTarget = Vector3.new(3, 0, 4)
	local direction = SlingServiceModule.ResolveAimDirection(origin, aimTarget)
	assertAlmostEqual(direction.Magnitude, 1, 0.0001, "Resolved launch direction must be normalized")
	assertAlmostEqual(direction.X, 0.6, 0.0001, "Direction X should point toward player aim")
	assertAlmostEqual(direction.Z, 0.8, 0.0001, "Direction Z should point toward player aim")
end

local function testChargeReleaseLaunchVectorIsFinite()
	local direction = SlingServiceModule.ResolveAimDirection(Vector3.new(0, 0, 0), Vector3.new(10, 0, 0))
	local launchForce = SlingServiceModule.CalculateLaunchForce(0.8, SlingshotConfig.MIN_LAUNCH_FORCE, SlingshotConfig.MAX_LAUNCH_FORCE, 1)
	local launchVector = SlingServiceModule.BuildLaunchVector(direction, launchForce)
	if launchVector.X ~= launchVector.X or launchVector.Y ~= launchVector.Y or launchVector.Z ~= launchVector.Z then
		error("Launch vector must not contain NaN values")
	end
	assertAlmostEqual(launchVector.Magnitude, launchForce, 0.0001, "Launch force should be applied to the normalized direction")
end

local function testCooldownDisplayStateDecreasesCorrectly()
	local cooldownEnd = 15
	local uiStateAt10 = SlingServiceModule.BuildCooldownUiState(cooldownEnd, 10)
	local uiStateAt14 = SlingServiceModule.BuildCooldownUiState(cooldownEnd, 14)
	assertAlmostEqual(uiStateAt10.CooldownRemaining, 5, 0.0001, "Cooldown remaining should reflect current timestamp")
	assertAlmostEqual(uiStateAt14.CooldownRemaining, 1, 0.0001, "Cooldown remaining should decrease over time")
	if uiStateAt14.CooldownRemaining >= uiStateAt10.CooldownRemaining then
		error("UI cooldown values must strictly decrease as time advances")
	end
end

local function testSlingUiChargeAndCooldownRatios()
	assertAlmostEqual(SlingUiState.ComputeChargeRatio(1, 2), 0.5, 0.0001, "Charge ratio should fill from 0 to 1 over charge time")
	assertAlmostEqual(SlingUiState.ComputeChargeRatio(4, 2), 1, 0.0001, "Charge ratio should clamp at 1")
	assertAlmostEqual(SlingUiState.ComputeCooldownRatio(0.75, 3), 0.25, 0.0001, "Cooldown bar should fill from elapsed cooldown time")
	assertAlmostEqual(SlingUiState.ComputeCooldownRatio(3, 3), 1, 0.0001, "Cooldown fill should complete at the recover duration")
	assertAlmostEqual(SlingUiState.ComputeAimDistance(1.5, 20), 20, 0.0001, "Aim distance should clamp to max release distance")
end

local function testSlingUiDirectionRotation()
	local rightRotation = SlingUiState.ComputeDirectionRotation(Vector2.new(10, 0))
	if rightRotation == nil then
		error("Direction rotation should exist for non-zero drag")
	end
	assertAlmostEqual(rightRotation, 0, 0.0001, "Right drag should rotate indicator to 0 degrees")

	local downRotation = SlingUiState.ComputeDirectionRotation(Vector2.new(0, 10))
	if downRotation == nil then
		error("Direction rotation should exist for non-zero drag")
	end
	assertAlmostEqual(downRotation, 90, 0.0001, "Downward drag should rotate indicator to 90 degrees")

	if SlingUiState.ComputeDirectionRotation(Vector2.zero) ~= nil then
		error("Zero drag should not force a rotation update")
	end
end


local function testCollisionTriggersDamageFormula()
	local service = CombatService.new({})
	local attacker = {
		BaseDamage = 20,
		Size = 2,
		ChargeValue = 1,
		SlingshotType = "Default",
		DamageMultiplier = 1,
	}
	local speed = 80
	local expected = math.clamp(speed * math.log(attacker.Size + 1) * (SlingshotConfig.SlingshotModifiers.Default or 1) * attacker.DamageMultiplier * (1 + BalanceConfig.ChargeDamageFactor), 0, BalanceConfig.MaxDamagePerHit)
	local damage = service:ComputeImpactDamage(attacker, speed, 1)
	assertAlmostEqual(damage, expected, 0.0001, "Damage formula should follow speed*log(size+1)*mods")
end

local function testKnockbackDirectionForSmallerAttacker()
	local service = CombatService.new({})
	local knockback = service:ComputeKnockback({ Size = 1 }, { Size = 3 }, Vector3.new(1, 0, 0), 50)
	if knockback.X >= 0 then
		error("Smaller attacker must receive reversed knockback direction")
	end
end

local function testExpLevelUpThreshold()
	local required = LevelConfig.RequiredExp(1)
	if required <= 0 then
		error("Required EXP must be greater than 0")
	end
end


local function testFoodGridCellBuilderEvenCoverage()
	local boundsCFrame = CFrame.new(0, 0, 0)
	local boundsSize = Vector3.new(48, 10, 48)
	local cells = MapServiceModule.BuildGridCellPositions(boundsCFrame, boundsSize, 24)
	if #cells ~= 4 then
		error(string.format("Expected 4 grid cells for 48x48 with size 24, got %d", #cells))
	end
	local hasNegativeX = false
	local hasPositiveX = false
	local hasNegativeZ = false
	local hasPositiveZ = false
	for _, cell in ipairs(cells) do
		if cell.X < 0 then
			hasNegativeX = true
		else
			hasPositiveX = true
		end
		if cell.Z < 0 then
			hasNegativeZ = true
		else
			hasPositiveZ = true
		end
	end
	if not (hasNegativeX and hasPositiveX and hasNegativeZ and hasPositiveZ) then
		error("Grid cells must cover both sides of map axes for even distribution")
	end
end

local function testSelfDamageClampOnMaxCharge()
	local maxSelfHp = 100
	local impactDamage = 200
	local cappedImpact = math.min(impactDamage, maxSelfHp * BalanceConfig.MaxSelfDamageToCurrentHpRatio)
	local selfDamage = cappedImpact * BalanceConfig.SelfDamageRatio
	assertAlmostEqual(selfDamage, 75, 0.0001, "Max-charge self-damage should clamp to 1.5x hp then *0.5")
end




local function testFoodZonePoolsFollowDesignRules()
	local service = MapServiceModule.new({
		Remotes = Instance.new("Folder"),
		Services = {},
		EventBus = { Fire = function() end },
	})
	local edge = service:GetFoodTypePoolForZone("Edge")
	local middle = service:GetFoodTypePoolForZone("Middle")
	local center = service:GetFoodTypePoolForZone("Center")

	local function toSet(list)
		local set = {}
		for _, value in ipairs(list) do
			set[value] = true
		end
		return set
	end

	local edgeSet = toSet(edge)
	if not (edgeSet.Food5 and edgeSet.Food6 and edgeSet.Food7 and #edge == 3) then
		error("Edge zone must allow only Food5, Food6, Food7")
	end

	local middleSet = toSet(middle)
	if not (middleSet.Food2 and middleSet.Food3 and middleSet.Food4 and middleSet.Food5 and middleSet.Food6 and middleSet.Food7 and #middle == 6) then
		error("Middle zone must allow Food2..Food7")
	end

	local centerSet = toSet(center)
	if not (centerSet.Food1 and centerSet.Food2 and centerSet.Food3 and centerSet.Food4 and #center == 4) then
		error("Center zone must allow Food1..Food4")
	end
end

local function testArenaSpawnLookupUsesRequestedMap()
	local mapsFolder = Instance.new("Folder")
	mapsFolder.Name = "Maps"
	mapsFolder.Parent = workspace

	local function createArena(name: string, markerPosition: Vector3): Model
		local arena = Instance.new("Model")
		arena.Name = name
		arena.Parent = mapsFolder
		local spawnFolder = Instance.new("Folder")
		spawnFolder.Name = "SpawnPoints"
		spawnFolder.Parent = arena
		local spawn = Instance.new("Part")
		spawn.Name = "SpawnPoint_Main"
		spawn.Position = markerPosition
		spawn.Parent = spawnFolder
		return arena
	end

	createArena("Arena_01", Vector3.new(10, 4, 10))
	createArena("Arena_02", Vector3.new(120, 4, 120))

	local service = MapServiceModule.new({
		Remotes = Instance.new("Folder"),
		Services = {},
		EventBus = { Fire = function() end },
	})
	service._mapRoot = mapsFolder

	local spawn = service:GetArenaSpawn("Arena_02")
	if not spawn then
		mapsFolder:Destroy()
		error("Expected arena spawn for Arena_02")
	end
	if not spawn:IsDescendantOf(mapsFolder:FindFirstChild("Arena_02") :: Model) then
		mapsFolder:Destroy()
		error("GetArenaSpawn(mapName) must use the requested map")
	end

	mapsFolder:Destroy()
end


local function testFoodServiceUsesExactFoodSpawnHeight()
	local map = Instance.new("Model")
	map.Name = "Arena_FoodHeight"
	map.Parent = workspace

	local foodContainer = Instance.new("Folder")
	foodContainer.Name = "FoodContainer"
	foodContainer.Parent = map

	local spawns = Instance.new("Folder")
	spawns.Name = "FoodSpawns"
	spawns.Parent = map

	local centerZones = Instance.new("Folder")
	centerZones.Name = "CenterZones"
	centerZones.Parent = spawns

	local spawn = Instance.new("Part")
	spawn.Name = "FoodSpawn_Height"
	spawn.Anchored = true
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.CFrame = CFrame.new(0, 10, 0)
	spawn.Parent = centerZones

	local serverStorage = game:GetService("ServerStorage")
	local templates = serverStorage:FindFirstChild("FoodTemplates")
	local createdTemplates = false
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "FoodTemplates"
		templates.Parent = serverStorage
		createdTemplates = true
	end

	local existingFood1 = templates:FindFirstChild("Food1")
	local createdTemplateModel = false
	if not existingFood1 then
		local template = Instance.new("Model")
		template.Name = "Food1"
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.Size = Vector3.new(2, 2, 2)
		root.CFrame = CFrame.new(0, 1, 0)
		root.Parent = template
		template.PrimaryPart = root
		template.Parent = templates
		createdTemplateModel = true
	end

	local service = FoodServiceModule.new({
		Services = {
			PlayerService = { GetPawn = function() return nil end },
			PlayerStateService = { Heal = function() end, PublishState = function() end },
		},
		EventBus = { Fire = function() end },
	})

	service:SpawnFoodForMap(map)
	local spawned = foodContainer:GetChildren()[1]
	if not spawned or not spawned:IsA("Model") then
		map:Destroy()
		error("Expected spawned food model for height alignment test")
	end

	local root = spawned.PrimaryPart or spawned:FindFirstChildWhichIsA("BasePart")
	if not root then
		map:Destroy()
		error("Spawned food height test model missing root")
	end

	assertAlmostEqual(root.Position.Y, spawn.Position.Y, 0.01, "Food root position should use the exact FoodSpawn height")
	if not root.Anchored then
		map:Destroy()
		error("Spawned food root should stay anchored to avoid physics drift")
	end

	map:Destroy()
	if createdTemplateModel then
		local model = templates:FindFirstChild("Food1")
		if model then model:Destroy() end
	end
	if createdTemplates then templates:Destroy() end
end

local function testFoodServiceUsesFoodSpawnPartsExactly()
	local map = Instance.new("Model")
	map.Name = "Arena_Test"
	map.Parent = workspace

	local foodContainer = Instance.new("Folder")
	foodContainer.Name = "FoodContainer"
	foodContainer.Parent = map

	local spawns = Instance.new("Folder")
	spawns.Name = "FoodSpawns"
	spawns.Parent = map

	local edgeZones = Instance.new("Folder")
	edgeZones.Name = "EdgeZones"
	edgeZones.Parent = spawns

	local spawn = Instance.new("Part")
	spawn.Name = "FoodSpawn_01"
	spawn.Anchored = true
	spawn.Size = Vector3.new(4, 1, 4)
	spawn.Position = Vector3.new(32, 6, -12)
	spawn.Parent = edgeZones

	local serverStorage = game:GetService("ServerStorage")
	local templates = serverStorage:FindFirstChild("FoodTemplates")
	local createdTemplates = false
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "FoodTemplates"
		templates.Parent = serverStorage
		createdTemplates = true
	end

	local createdTemplateModel = false
	if not templates:FindFirstChild("Food5") then
		local template = Instance.new("Model")
		template.Name = "Food5"
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Anchored = true
		root.Size = Vector3.new(2, 2, 2)
		root.Parent = template
		template.PrimaryPart = root
		template.Parent = templates
		createdTemplateModel = true
	end

	local service = FoodServiceModule.new({
		Services = {
			PlayerService = { GetPawn = function() return nil end },
			PlayerStateService = { Heal = function() end, PublishState = function() end },
		},
		EventBus = { Fire = function() end },
	})

	service:SpawnFoodForMap(map)
	local foods = foodContainer:GetChildren()
	if #foods ~= 5 then
		map:Destroy()
		if createdTemplateModel then
			local model = templates:FindFirstChild("Food5")
			if model then model:Destroy() end
		end
		if createdTemplates then templates:Destroy() end
		error(string.format("Expected exactly 5 foods spawned for one FoodSpawn_* part, got %d", #foods))
	end

	for _, spawned in ipairs(foods) do
		local root = spawned.PrimaryPart or spawned:FindFirstChildWhichIsA("BasePart")
		if not root then
			map:Destroy()
			error("Spawned food is missing root part")
		end
		local xDelta = math.abs(root.Position.X - spawn.Position.X)
		local zDelta = math.abs(root.Position.Z - spawn.Position.Z)
		if xDelta > 5.05 or zDelta > 5.05 then
			map:Destroy()
			error("Food must spawn within FoodSpawn radius ±5")
		end
	end

	map:Destroy()
	if createdTemplateModel then
		local model = templates:FindFirstChild("Food5")
		if model then model:Destroy() end
	end
	if createdTemplates then templates:Destroy() end
end


local function testLobbySpawnPrefersExplicitPath()
	local maps = Instance.new("Folder")
	maps.Name = "Maps"
	maps.Parent = workspace

	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = maps

	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "SpawnPoints"
	spawnFolder.Parent = lobby

	local spawn = Instance.new("Part")
	spawn.Name = "SpawnPoint"
	spawn.Position = Vector3.new(11, 4, -9)
	spawn.Parent = spawnFolder

	local service = MapServiceModule.new({
		Remotes = Instance.new("Folder"),
		Services = {},
		EventBus = { Fire = function() end },
	})
	service._mapRoot = maps

	local found = service:GetLobbySpawn()
	if found ~= spawn then
		maps:Destroy()
		error("GetLobbySpawn should prefer Workspace.Maps.Lobby.SpawnPoints.SpawnPoint")
	end
	maps:Destroy()
end

local function testActivateMapDoesNotHideInactiveMaps()
	local mapsFolder = Instance.new("Folder")
	mapsFolder.Name = "Maps"
	mapsFolder.Parent = workspace

	local function createMap(name: string, transparency: number): Part
		local map = Instance.new("Model")
		map.Name = name
		map.Parent = mapsFolder
		local part = Instance.new("Part")
		part.Name = "Ground"
		part.Transparency = transparency
		part.CanCollide = true
		part.Parent = map
		return part
	end

	local lobbyPart = createMap("LobbyMap", 0.1)
	local arenaPart = createMap("Arena_01", 0.2)

	local service = MapServiceModule.new({
		Remotes = Instance.new("Folder"),
		Services = {},
		EventBus = { Fire = function() end },
	})
	service._mapRoot = mapsFolder

	service:ActivateMap("LobbyMap")
	service:ActivateMap("Arena_01")

	if math.abs(lobbyPart.Transparency - 0.1) > 0.001 then
		mapsFolder:Destroy()
		error("Lobby map part transparency should stay at its authored value")
	end
	if math.abs(arenaPart.Transparency - 0.2) > 0.001 then
		mapsFolder:Destroy()
		error("Arena map part transparency should stay at its authored value")
	end

	mapsFolder:Destroy()
end

local function testRemoteContractIncludesConsumeHpPotion()
	if RemoteContracts.Names.ConsumeHpPotion ~= "ConsumeHpPotion" then
		error("RemoteContracts must include ConsumeHpPotion name")
	end
	if not RemoteContracts.Validate(RemoteContracts.Names.ConsumeHpPotion) then
		error("ConsumeHpPotion validator should accept empty payload")
	end
end

local function testHpPotionConsumptionClampsAndConsumesOneItem()
	local service = PlayerStateServiceModule.new({
		EventBus = { Fire = function() end },
		Remotes = Instance.new("Folder"),
	})

	local fakePlayer = { Name = "PotionTester", UserId = 2002, Character = nil }
	service._states[fakePlayer] = {
		UserId = 2002,
		MapName = "LobbyMap",
		ArenaStatus = "Lobby",
		Level = 1,
		Exp = 0,
		Size = 1,
		MaxHP = 100,
		CurrentHP = 95,
		BaseDamage = 10,
		RegenRate = 1,
		ReflectDamage = 0,
		LaunchSpeed = 1,
		LaunchRange = 1,
		ChargeSpeed = 1,
		MoveSpeed = 1,
		DamageMultiplier = 1,
		HPBonus = 0,
		LaunchSpeedBonus = 0,
		RegenBonus = 0,
		KnockbackResistance = 0,
		SlingshotType = "Default",
		ChargeValue = 0,
		CurrentVelocity = Vector3.zero,
		InvulnerableUntil = 0,
		LastDamageTime = 0,
		InvulCooldownUntil = 0,
		Diamonds = 0,
		HpPotions = 2,
		NextHpPotionUseTime = 0,
		RespawnCountThisMatch = 0,
		AttributePoints = 0,
		DamageDealt = 0,
		IsTeleporting = false,
		CooldownEndTime = 0,
		LastReleaseDuration = 0,
		Attributes = {
			Damage = 0,
			MaxHP = 0,
			Regen = 0,
			Range = 0,
			Reflect = 0,
			LaunchSpeed = 0,
			ChargeSpeed = 0,
			MoveSpeed = 0,
		},
		IsAlive = true,
		IsCharging = false,
		MovementState = "Idle",
		ScaleMultiplier = 1,
		BonusMaxHP = 0,
		BonusDamageMultiplier = 0,
		LevelDamageBonus = 0,
	}
	service.PublishState = function() end

	local ok = service:TryConsumeHpPotion(fakePlayer)
	local state = service._states[fakePlayer]
	if not ok then
		error("TryConsumeHpPotion should succeed when player has potion and missing hp")
	end
	if state.HpPotions ~= 1 then
		error("TryConsumeHpPotion should consume exactly one potion")
	end
	if state.CurrentHP ~= state.MaxHP then
		error("TryConsumeHpPotion should clamp healed hp at MaxHP")
	end
end

runTest("ChargeToLaunchForce", testChargeToLaunchForce)
runTest("ChargeRatio_ProgressAndClamp", testChargeRatioProgressAndClamp)
runTest("ReleaseDistanceMultiplier_Applied", testReleaseDistanceMultiplierApplied)
runTest("ReleaseSpeedMultiplier_Applied", testReleaseSpeedMultiplierApplied)
runTest("Lobby_AllowsMoveAndRelease", testLobbyAllowsMoveAndRelease)
runTest("LaunchedState_PreservesMomentum", testLaunchedStatePreservesMomentum)
runTest("ChargeRelease_ResetsChargeState", testChargeResetAfterRelease)
runTest("RecoverCooldown_MatchesReleaseDuration", testRecoverCooldownMatchesReleaseDuration)
runTest("LaunchDirection_NormalizedFromAim", testLaunchDirectionNormalizedFromAim)
runTest("ChargeRelease_ForceVectorFinite", testChargeReleaseLaunchVectorIsFinite)
runTest("CooldownDisplay_DecreasesOverTime", testCooldownDisplayStateDecreasesCorrectly)
runTest("SlingUI_ChargeAndCooldownRatios", testSlingUiChargeAndCooldownRatios)
runTest("SlingUI_DirectionRotation", testSlingUiDirectionRotation)
runTest("CollisionTriggersDamageFormula", testCollisionTriggersDamageFormula)
runTest("KnockbackDirectionForSmallerAttacker", testKnockbackDirectionForSmallerAttacker)
runTest("ExpLevelUpThreshold", testExpLevelUpThreshold)
runTest("SelfDamageClampOnMaxCharge", testSelfDamageClampOnMaxCharge)
runTest("FoodGridCellBuilderEvenCoverage", testFoodGridCellBuilderEvenCoverage)
runTest("FoodZonePoolsFollowDesignRules", testFoodZonePoolsFollowDesignRules)
runTest("MapLoading_ArenaSpawnAndPrefabApisExist", testArenaSpawnAndPrefabApisExist)
runTest("TeleportLogic_JoinLeaveFlow", testTeleportPlayerJoinLeaveFlow)
runTest("MapSpawn_UsesRequestedArenaMap", testArenaSpawnLookupUsesRequestedMap)
runTest("MapActivation_DoesNotHideInactiveMaps", testActivateMapDoesNotHideInactiveMaps)
runTest("FoodService_UsesFoodSpawnPartsExactly", testFoodServiceUsesFoodSpawnPartsExactly)
runTest("FoodService_UsesExactFoodSpawnHeight", testFoodServiceUsesExactFoodSpawnHeight)
runTest("LobbySpawn_PrefersExplicitPath", testLobbySpawnPrefersExplicitPath)
runTest("RemoteContract_ConsumeHpPotionExists", testRemoteContractIncludesConsumeHpPotion)
runTest("HpPotion_ConsumptionAndClamp", testHpPotionConsumptionClampsAndConsumesOneItem)

print("[CoreLoopTests] all checks passed")
