--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OnlineRewardLogicService = require(ReplicatedStorage.Client.Services.OnlineRewardLogicService)

local function runTest(name: string, testFn)
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[OnlineRewardLogicTests] PASS %s", name))
	else
		warn(string.format("[OnlineRewardLogicTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function testLoadMockDataCreatesTwelveSlots()
	local service = OnlineRewardLogicService.new()
	service:LoadMockData()
	local snapshot = service:GetSnapshot()

	if #snapshot.slots ~= 12 then
		error(string.format("Expected 12 reward slots, got %d", #snapshot.slots))
	end
	if snapshot.columns ~= 4 or snapshot.rows ~= 3 then
		error("Expected 4x3 reward grid config")
	end

	service:Destroy()
end

local function testSkipAllThenClaimAllTransitionsStates()
	local service = OnlineRewardLogicService.new()
	service:LoadMockData()
	service:SkipAll()

	local readyCount = 0
	for _, slot in ipairs(service:GetSnapshot().slots) do
		if slot.state == "Ready" then
			readyCount += 1
		end
	end
	if readyCount ~= 12 then
		error(string.format("Expected all 12 slots Ready after skip-all, got %d", readyCount))
	end

	local claimed = service:ClaimAllReady()
	if claimed ~= 12 then
		error(string.format("Expected claim-all to claim 12 slots, got %d", claimed))
	end

	for _, slot in ipairs(service:GetSnapshot().slots) do
		if slot.state ~= "Claimed" then
			error("All slots should be Claimed after claim-all")
		end
	end

	service:Destroy()
end

runTest("mock data contains 12 rewards in 4x3 grid", testLoadMockDataCreatesTwelveSlots)
runTest("skip-all and claim-all state transitions", testSkipAllThenClaimAllTransitionsStates)
