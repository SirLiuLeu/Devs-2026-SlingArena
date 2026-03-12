--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BalanceConfig = require(ReplicatedStorage.Shared.Config.BalanceConfig)
local SlingshotConfig = require(ReplicatedStorage.Shared.Config.SlingshotConfig)
local LevelConfig = require(ReplicatedStorage.Shared.Config.LevelConfig)
local CombatService = require(ServerScriptService.Services.CombatService)
local MapServiceModule = require(ServerScriptService.Services.MapService)

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
	local ratio = 0.5
	local launchForce = minForce + (maxForce - minForce) * ratio
	assertAlmostEqual(launchForce, (minForce + maxForce) * 0.5, 0.0001, "Launch force lerp should match")
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

runTest("ChargeToLaunchForce", testChargeToLaunchForce)
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

print("[CoreLoopTests] all checks passed")
