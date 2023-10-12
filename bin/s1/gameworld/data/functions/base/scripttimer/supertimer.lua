--定时器的基类
--根据定义的参数来进行判定加入的Timer
--该模块包含的定时器的触发时间为0秒时，但是设定精度为分钟
module("base.scripttimer.supertimer", package.seeall)
setfenv(1, base.scripttimer.supertimer)
local algorithm    = require("utils.algorithm")
local binSearch    = algorithm.binSearch --二分查找
local getNextMonth = algorithm.getNextMonth
local System       = System

local TIMES       = math.huge --方法的默认执行次数, 可以在执行指定次数后而自动销毁
_G.supertimer_tid = 0
tasksList         = {} --存储定时任务的位置

local function getTid()
	supertimer_tid = supertimer_tid + 1
	return supertimer_tid
end

--获取某时间戳的0Hour
function get0HourTime(time)
	return math.floor(time / (3600 * 24)) * (3600 * 24)
end

--将时间位置移动到该星期的星期X(0-6)
function getWeekTime(time, week)
	local year, month, day, _, _, _ = System.timeDecode(time)
	local wday = System.getWeekDataTime(year, month, day)
	local fixDay = week - wday
	return time + fixDay * 3600 * 24
end

--如果当前周(周几)已过，取下一周(周几)openweeks = { 3,
-- 对于设置
function getAdjustWeekTime(time, week)
	local year, month, day, _, _, _ = System.timeDecode(time)
	local wday = System.getWeekDataTime(year, month, day)
	local fixDay = week - wday
	if week < wday then
		fixDay = week + 7 - wday
	end
	return time + fixDay * 3600 * 24
end

--用于计算下月同一日0Hour的方法
function getNextMon0Time(year, month, day)
	local n_year, n_month = getNextMonth(year, month)
	return System.timeEncode(n_year, n_month, day, 0, 0, 0)
end

--获取步进至下一个月的时间
function getNextMonOffTime(exeTime)
	if not exeTime then exeTime = System.getNowTime() end
	local year, month, day, _, _, _ = System.timeDecode(exeTime)
	local today0Hour = System.timeEncode(year, month, day, 0, 0, 0)
	local nextMon0Hour = getNextMon0Time(year, month, day)
	return nextMon0Hour - today0Hour
end

--获取步进至下一年的时间
function getNextYearOffTime(exeTime)
	if not exeTime then exeTime = System.getNowTime() end
	local year, month, day, _, _, _ = System.timeDecode(exeTime)
	local today0Hour = System.timeEncode(year, month, day, 0, 0, 0)
	local next_Year0Hour = System.timeEncode(year + 1, month, day, 0, 0, 0)
	return next_Year0Hour - today0Hour
end

--获取年步进的exeTime和其stepSec
function getExeTime_Year(month, day, hour, minute, sec)
	assert(day ~= nil)
	hour = hour or 0
	minute = minute or 0
	sec = sec or 0
	local year, _, _ = System.getDate()
	local time = System.timeEncode(year, month, day, hour, minute, sec)
	return time, getNextYearOffTime
end

--获取月步进的exeTime和其stepSec
function getExeTime_Month(day, hour, minute, sec)
	hour = hour or 0
	minute = minute or 0
	sec = sec or 0
	local year, month, _ = System.getDate()
	local time = System.timeEncode(year, month, day, hour, minute, sec)
	return time, getNextMonOffTime
end

--获取天步进的exeTime和其stepSec
function getExeTime_Day(hour, minute, sec, exeTime)
	if not exeTime then exeTime = System.getNowTime() end
	local year, month, day, _, _, _ = System.timeDecode(exeTime)
	minute = minute or 0
	sec = sec or 0
	local time = System.timeEncode(year, month, day, hour, minute, sec)
	return time, 3600 * 24
end

--获取周步进的exeTime和其stepSec
function getExeTime_Week(week, hour, minute, sec, time)
	hour = hour or 0
	minute = minute or 0
	sec = sec or 0
	local exeTime, stepSec = getExeTime_Day(hour, minute, sec, time)
	if week ~= -1 then
		exeTime = getAdjustWeekTime(exeTime, week) --将时间位置移动到星期X
		stepSec = 3600 * 24 * 7
	end
	return exeTime, stepSec
end

--本模块的二分法判定(找最后的位置)
function binFunc(val, item)
	if val.exeTime < item.exeTime then return -1
	elseif val.exeTime > item.exeTime then return 1
	else return 0
	end
end

--二分法思想查找适合的插入位置-非递归
function SearchIndx(tab, task)
	return binSearch(tab, task, binFunc)
end

--创建一个定时任务
function createTask(exeTime, times, stepSec, func, ...)
	local task = {}
	task.arg = arg
	task.func = func
	task.exeTime = exeTime
	task.times = times
	task.tid = getTid()
	if times == -1 then task.times = TIMES end
	task.stepSec = stepSec or 0
	return task
end

--获取步进
function getStepSec(stepSec, exeTime)
	if not stepSec then return end
	local step
	if type(stepSec) ~= 'function' then
		step = stepSec
	--传入exeTime可以保证计算时是按照设定触发时间计算而不是按照实际触发时间
	else step = stepSec(exeTime) end
	if type(step) == 'number' and step > 0 then return step end
end

--如果exeTime小于当前时间，会步进一次
function fixExeTime(exeTime, stepSec)
	local time_now = System.getNowTime()
	if time_now > exeTime then
		local step = getStepSec(stepSec, exeTime)
		if not step then return end
		exeTime = exeTime + step
	end
	return exeTime
end

function runFunc(time, func, params)
	if not func then return end
	local ret
	if type(params) ~= 'table' then
		ret = func(time, params)
	else
		ret = func(time, unpack(params))
	end
	return ret
end

function printTime(time, key)
	if not time then return end
	local y, m, d, h, mi, s = System.timeDecode(time)
	--print(string.format("[%s] %s-%s-%s %s:%s:%s", key or "PRINT_TIME", y or 0, m or 0, d or 0, h or 0, mi or 0, s or 0))
end

--到达触发时间的触发事件
function onTimerEvent(time_now)
	if not time_now then time_now = System.getNowTime() end
	printTime(time_now, "ON_TIMER_EVENT")
	local taskCount = 0
	local tasksList = tasksList

	for i=1, #tasksList do --限制最大检索次数
		local task = tasksList[1] --取第一个task
		--print("task.exeTime:"..task.exeTime)
		if time_now < task.exeTime then break end
		printTime(task.exeTime, "TASK_EXETIME")
		taskCount = taskCount + 1
		table.remove(tasksList, 1)
		runFunc(task.exeTime, task.func, task.arg)
		task.times = task.times - 1

		if task.times >= 0 then
			local step = getStepSec(task.stepSec, exeTime)
			if step and step > 0 then
				task.exeTime = task.exeTime + step
				printTime(task.exeTime, "TASK_EXETIME_NEW")
				local indx = SearchIndx(tasksList, task)
				table.insert(tasksList, indx, task)
			end
		end
	end

	if taskCount > 0 then
		-- print(string.format("[SUPERTIMER][ONTIMER] TIME: %s , TASKCOUNT: %s ", time_now or 0, taskCount or 0))
		-- print("================ BEGIN ================")
		-- for i=1, #tasksList do --限制最大检索次数
		-- 	local task = tasksList[i] --取第一个task
		-- 	print(task.exeTime, "SORT")
		-- end
		-- print("================ END ================")
	end
end

function removeTimer(tid)
	if not tid then return end

	for pos, task in ipairs(tasksList) do
		if task.tid == tid then
			table.remove(tasksList, pos)
			return
		end
	end
	--print("unfind."..tid)
end

--注册定时任务
function regTimerEvent(exeTime, times, stepSec, func, ... )
	if not (exeTime and times and func) then return end
	if times == 0 or times < -1 then
		print("superTimer[ERROR]:times value must in (0,N] or -1")
		return
	end
	--只执行一次不需要步进
	if times ~= 1 then
		local t_sec = getStepSec(stepSec, exeTime)
		--这个地方可以根据扫描频率进行修改校验
		if t_sec and t_sec < 60 then
			print("superTimer[ERROR]:stepSec value must >= 1 min")
			return
		end
	end
	local task = createTask(exeTime, times, stepSec, func, ...)
	--print("CreateTask OK!")
	printTime(task.exeTime, "CREATE_TASK")
	local indx = SearchIndx(tasksList, task)
	-- setNextOnTime(task)
	table.insert(tasksList, indx, task)
	return task.tid
end

-- 对外的接口，对 regTimerEvent 的简单封装，简化参数
-- 注册一个延迟多少秒后执行的函数,只执行一次
function regDelayTimerEvent(delay, func, ...)
	return regTimerEvent(System.getNowTime() + delay, 1, nil, func, ...)
end

local running = false
local function superOnTimerEvent( ... )
	if running then return end
	running = true
	onTimerEvent()
	running = false
	--计算下一次触发的时间
	-- setNextOnTime()
end

-- _G.SuperTimerOnTimeEvent = superOnTimerEvent

-- function setNextOnTime(task)
-- 	local time_now = System.getNowTime()
-- 	local list_0 = tasksList[0]
-- 	if not list_0 then return end
-- 	if task and task.exeTime >= list_0.exeTime then return end
-- 	local time = list_0.exeTime - time_now
-- 	if sId then LActor.cancelScriptTimer(nil, sId) end
-- 	sId = LActor.postScriptEvent(nil, time * 1000, "SuperTimerOnTimeEvent", 0, 1)
-- end

--目前的触发间隔为1min
engineevent.regGameTimer(superOnTimerEvent)

