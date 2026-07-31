--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopLogicService = require(ReplicatedStorage.Client.Services.ShopLogicService)
local DailyLoginLogicService = require(ReplicatedStorage.Client.Services.DailyLoginLogicService)

local function runTest(name: string, testFn)
	local ok, err = pcall(testFn)
	if ok then
		print(string.format("[ShopDailyUiLogicTests] PASS %s", name))
	else
		warn(string.format("[ShopDailyUiLogicTests] FAIL %s :: %s", name, tostring(err)))
		error(err)
	end
end

local function testShopPurchaseAndCurrencyName()
	local service = ShopLogicService.new()
	service:LoadMockData()

	local before = service:GetSnapshot()
	if before.currencyName ~= "Dinamond" then
		error("Shop currencyName must be Dinamond")
	end

	local ok = service:PurchaseItem("item_hp_potion", 1)
	if not ok then
		error("Expected HP potion x1 purchase to succeed")
	end

	local after = service:GetSnapshot()
	if after.balance ~= before.balance - 1 then
		error("Expected Dinamond balance to decrease by 1 after HP Potion x1 purchase")
	end

	service:Destroy()
end

local function testDailyLoginClaimFlow()
	local service = DailyLoginLogicService.new()
	service:LoadMockData()

	local snapshot = service:GetSnapshot()
	if snapshot.currentDay ~= 1 then
		error("Expected current day to start at 1")
	end

	local ok = service:ClaimDay(1)
	if not ok then
		error("Expected day 1 to be claimable")
	end

	snapshot = service:GetSnapshot()
	if snapshot.currentDay ~= 2 then
		error("Expected current day to move to 2 after claiming day 1")
	end

	local canClaimDay1Again = service:ClaimDay(1)
	if canClaimDay1Again then
		error("Expected day 1 to be no longer claimable after being claimed")
	end

	service:Destroy()
end

runTest("Shop purchase + Dinamond name", testShopPurchaseAndCurrencyName)
runTest("Daily login progression", testDailyLoginClaimFlow)
