module("test.gunit", package.seeall)
setfenv(1, test.gunit)
--[[
定义单元测试框架的基本函数
--]]

local allTest = {}
_G.testParams = {errorCnt = 0, case = "", test = ""}

_G.test_co_list = {}
-- 每秒定时执行
_G.OnUnitTestTimer = function()
	if not main_test_co then return end
	local del_co = {}
	local actor = LActor.getActorById(testParams.actorid or 0)
	--如果actor已经不在线
	if not actor then 
		--清空
		print("actor is invalid, stop tests !!")
		test_co_list = {}
		if (coroutine.status(main_test_co) ~= "dead") then
			coroutine.resume(main_test_co)
		end
		return
	end
	for idx, test_co in ipairs(test_co_list) do
		if (coroutine.status(test_co) == "dead") then 
			table.insert(del_co, idx)
		else
			coroutine.resume(test_co)
		end
	end
	--清除已经结束的coroutine
	for _, v in ipairs(del_co) do 
		table.remove(test_co_list, v)
	end

	if #del_co > 0 and #test_co_list <= 0 then 
		if (coroutine.status(main_test_co) ~= "dead") then
			coroutine.resume(main_test_co)
		end
	end
end

--添加一个测试，caseName是案例名称，testName是测试名称，func是测试函数, co表示是否用协程执行函数
_G.TEST = function(caseName, testName, func, co)
	if func == nil then print("TEST error:func is nil") end

	if allTest[caseName] == nil then
		allTest[caseName] = {}
	end
	local tests = allTest[caseName]
	if tests[testName] ~= nil then
		print("testName is not nil:" .. testName)
	end
	tests[testName] = {}
	tests[testName].func = func
	tests[testName].co = co
end

local function startTest(actorid, caseName, testName, t)
	testParams.case = caseName 
	testParams.test = testName
	testParams.testCnt = testParams.testCnt + 1
	local actor = LActor.getActorById(actorid)
	if not actor then return end
	if t.co then
		local test_co = coroutine.create(t.func)
		table.insert(test_co_list, test_co)
		coroutine.resume(test_co,actor)
	else
		t.func(actor)
	end
end
-- 测试所有的案例
-- 可以指定运行的caseName或testName
_G.RUN_ALL_TEST = function(actorid, caseName, testName)
	testParams.case = caseName
	testParams.test = testName
	testParams.actorid = actorid
	testParams.errorCnt = 0
	testParams.caseCnt = 0
	testParams.testCnt = 0
	print(string.format("[========] run tests start:%s,%s...", caseName or "all", testName or "all"))

	if caseName ~= nil then
		local tests = allTest[caseName]
		if tests ~= nil then
			testParams.caseCnt = testParams.caseCnt + 1
			for tn,t in pairs(tests) do
				if testName == nil 
					or (testName ~= nil and testName == tn) then
					startTest(actorid, caseName, tn, t)
				end 
			end
		end
	else
		-- 全部执行
		for cn,v in pairs(allTest) do
			if v ~= nil then
				testParams.caseCnt = testParams.caseCnt + 1
				for k1,t in pairs(v) do
					startTest(actorid, cn, k1, t)
				end
			end
		end
	end
	--如果test中有使用coroutine，则主coroutine跳出
	if #test_co_list > 0 then
		coroutine.yield()
	end

	print("======================Test Report==================")
	local str = string.format("[========] %d cases %d tests ran", testParams.caseCnt,
			testParams.testCnt)
	print(str)

	if caseName == nil then
		for k,v in pairs(allTest) do
			local tmpTestCnt = 0
			if v ~= nil then
				for t in pairs(v) do
					tmpTestCnt = tmpTestCnt + 1
				end
			end
			str = string.format("[In the case [%s] of %d test is ran]",k,tmpTestCnt)
			print(str)
		end
	end

	if testParams.errorCnt > 0 then
		str = string.format("[=FAILED=] %d tests error", testParams.errorCnt)
	else
		str = string.format("[=PASSED=] %d tests passed", testParams.testCnt)
	end
	print(str)

	_G.main_test_co = nil
end

