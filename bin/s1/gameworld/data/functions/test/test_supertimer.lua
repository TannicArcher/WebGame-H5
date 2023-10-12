-- LUA定时器配置测试
module("test.test_supertimer" , package.seeall)
setfenv(1, test.test_supertimer)
math.randomseed(tostring(System.getNowTime()):reverse():sub(1, 6))
local checkFunc = require("test.assert_func")
local sTimer = require("base.scripttimer.supertimer")
local tids = {}
local buildId = 0
local statusTask = {}

local timeMathAtts = {
	{ exeTime = 137340432, func = sTimer.get0HourTime, ret = 137289600, err = "supertimer.get0HourTime haven error."},
	{ exeTime = {137340432, 2}, func = sTimer.getWeekTime, ret = 137081232, err = "supertimer.getWeekTime haven error."},
	{ exeTime = {2014, 5, 9}, func = sTimer.getNextMon0Time, ret = 139968000, err = "supertimer.getNextMon0Time haven error."},
	{ exeTime = 137340432, func = sTimer.getNextMonOffTime, ret = 2678400, err = "supertimer.getNextMonOffTime haven error."},
	{ exeTime = {0, 0, 0, 137340432}, func = sTimer.getExeTime_Day, ret = 137289600, err = "supertimer.getExeTime_Day haven error."},
	{ exeTime = {5, 0, 0, 0, 137340432}, func = sTimer.getExeTime_Week, ret = 137289600, err = "supertimer.getExeTime_Week haven error."},
}

local function test_stepSec_func(num)
	local step = num
	return function (exeTime)
		return step
	end
end

local stepSecAtts = {
	{ step = -2, ret = nil, err = "step < 0 then still return sth."},
	{ step = 0, ret = nil, err = "step = 0 then still return sth."},
	{ step = 1, ret = 1, err = "step > 0 but not return a same number."},
	{ step = {}, ret = nil, err = "step.type is table then still return sth."},
	{ step = nil, ret = nil, err = "step is nil then still return sth."},
	{ step = "1", ret = nil, err = "step.type is string then still return sth."},
	{ step = false, ret = nil, err = "step.type is boolen then still return sth."},
	{ step = test_stepSec_func(-3), ret = nil, err = "func return step < 0 then still return sth."},
	{ step = test_stepSec_func(0), ret = nil, err = "func return step = 0 then still return sth."},
	{ step = test_stepSec_func(1), ret = 1, err = "func return step > 0 but not return a same number."},
	{ step = test_stepSec_func({}), ret = nil, err = "func return step.type is table then still return sth."},
	{ step = test_stepSec_func(nil), ret = nil, err = "func return step is nil then still return sth."},
	{ step = test_stepSec_func("hello"), ret = nil, err = "func return step.type is string then still return sth."},
	{ step = test_stepSec_func(true), ret = nil, err = "func return step.type is boolen then still return sth."},
}

local function baseGetStepSecCheck( ... )
	local getStepSec = sTimer.getStepSec
	for _,conf in pairs(stepSecAtts) do
		local ret = getStepSec(conf.step)
		Assert_eq(ret, conf.ret, conf.err)
	end
end

--基本的supertimer二分法插入顺序检测
local function baseBinSearchCheck( ... )
	local tmp_List = {}
	local SearchIndx = sTimer.SearchIndx
	for i=1,5000 do
		local task = {}
		task.id = i
		task.exeTime = math.random(1000, 2000) -- 必然在相同时间内会有重复的exeTime
		local indx = SearchIndx(tmp_List, task)
		table.insert(tmp_List, indx, task)
	end
	local flag = true
	for i=1, 5000 do
		if i == 5000 then return end
		if tmp_List[i].exeTime == tmp_List[i + 1].exeTime then
			flag = tmp_List[i].id < tmp_List[i + 1].id
			Assert(flag, "superTimer.binSearch haven error by same number.")
		else
			flag = tmp_List[i].exeTime < tmp_List[i + 1].exeTime
			Assert(flag, "superTimer.binSearch haven error by order.")
		end
		if not flag then return end
	end
end

local function setAnCheck(exeTime, i )
	buildId = buildId + 1
	local conf = statusTask[i]
	conf.buildId = buildId
	conf.times = conf.times - 1
end

local function getBuildId(task)
	if not task then return end
	local id = task.arg[1]
	if not id then return end
	local build = statusTask[id]
	if build then return build.buildId end
end

local function getTimes(task)
	if not task then return end
	local id = task.arg[1]
	if not id then return end
	local build = statusTask[id]
	if build then
		local times = build.times
		if times < 0 then times = math.huge end
		return times
	end
end

local function testTaskCheck(tasksList)
	for i=1,299 do
		local task = tasksList[i]
		local n_task = tasksList[i + 1]
		if not (task and n_task) then return true end
		if task.exeTime > 100000 then return true end
		local a_id, n_id = getBuildId(task), getBuildId(n_task)
		if a_id and n_id then
			--检测排序
			if task.exeTime > n_task.exeTime or (a_id > n_id and task.exeTime == n_task.exeTime)  then
				return false
			end
			--检测可运行次数
			if task.times ~= getTimes(task) and n_task.times ~= getTimes(n_task) then
				return false
			end
		end
	end
	return true
end

local function superTimerStepSecCheck( ... )
	--初始化
	buildId      = 0
	statusTask   = {}
	tids         = {}

	for i = 1,300 do
		buildId = buildId + 1
		local exeTime = math.random(1000, 1100) -- 必然在相同时间内会有重复的exeTime
		local stepSec = math.random(1, 25)
		local times   = math.random(-1,20)
		statusTask[i] = {}
		local conf = statusTask[i]
		conf.buildId = buildId
		conf.times = times
		if times ~= 0 then --0无法注册到sTimer内
			local tid = sTimer.regTimerEvent(exeTime, times, stepSec, setAnCheck, i)
			table.insert(tids, tid)
		else --stepSec传入一个方法
			conf.times = -1
			local tid = sTimer.regTimerEvent(exeTime, -1, test_stepSec_func(stepSec), setAnCheck, i)
			table.insert(tids, tid)
		end
	end

	local tasksList = sTimer.tasksList
	local onTimerEvent = sTimer.onTimerEvent
	if not onTimerEvent or not tasksList then
		Assert(false, "supertimer.tasksList or onTimerEvent not global function in module.")
	else
		local ret = testTaskCheck(tasksList)
		Assert(ret, "superTimer stepSec First Check is failed.")
		for i=1000,1500 do
			onTimerEvent(i)
			ret = testTaskCheck(tasksList)
			if not ret then
				Assert(ret, "superTimer stepSec Check is failed.")
				break
			end
		end
	end
	--销毁定时器
	for _, tid in pairs(tids) do
		sTimer.removeTimer(tid)
	end
end

local function timeMathCheck( ... )
	for _, conf in pairs(timeMathAtts) do
		local ret = checkFunc.runFunc(conf.func, conf.exeTime)
		Assert(ret[1] == conf.ret, conf.err)
	end
end

local function stepSecCheck()
	local tasksList = sTimer.tasksList
	local getStepSec = sTimer.getStepSec
	for _,v in pairs(tasksList) do
		local step = getStepSec(v.stepSec)
		 Assert(type(step) == 'number' and step >= 1, string.format("tid [%s] stepSec haven a error.", v.tid))
	end
end

TEST("supertimer", "baseGetStepSecCheck", baseGetStepSecCheck, false)
TEST("supertimer", "timeMathCheck", timeMathCheck, false)
TEST("supertimer", "binSearch", baseBinSearchCheck, false)
TEST("supertimer", "superTimerStepSecCheck", superTimerStepSecCheck, false)
TEST("supertimer", "stepSecCheck", stepSecCheck, false)






