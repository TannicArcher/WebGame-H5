-- 活动状态配置测试
module("test.test_activitytimer" , package.seeall)
setfenv(1, test.test_activitytimer)
local checkFunc = require("test.assert_func")
require("activity.activitytimeconf")
local ActivityTime = ActivityTime
local TEST = _G.TEST
local Item = Item
local test_test_activitytimer = {}
--数字属性类型名称
local numAtts = { "id" }

--数字属性范围检测配置
local rangeAtts = {
	{ name = "id", min = 1, max = 999 },
	{ name = "openserverday", min = 0, max = 99 },
}

local statusRangeAtts = {
	{ name = "week", min = -1, max = 6 },
	{ name = "hour", min = 0, max = 23 },
	{ name = "min", min = 0, max = 59 },
	{ name = "time", min = 0, max = 360000 },
	{ name = "statusid", min = 1, max = 3 },
}

local function statusAttCheck(k, status)

	if status == nil or #status == 0 then
		Assert(false, string.format("err: id [%d] - status can't not nil or count = 0.",k))
		return
	end
	for x,conf in pairs(status) do
		local k = string.format("%s_%s_%s", k, x, "status")
		checkFunc.numAttRangeCheck(k, statusRangeAtts, conf)
	end
	--其它的类型暂时不判定
end

local function openweeksCheck(k, conf)
	if conf.openweeks then
		local one = string.format("%s_%s_%s", k, "openweeks",1)
		Assert(conf.openweeks[1] >= 1, string.format("err:key<%d> must >= 1",k))
		local two = string.format("%s_%s_%s", k, "openweeks",2)
		local wday = conf.openweeks[2]
		Assert(wday >= 0 and wday <= 6, string.format("err:key<%d> must in [0,6]",k))
	end
end

local function onlyOneIdCheck(tab)
	local ids = {}
	for indx, conf in pairs(tab) do
		Assert(not ids[conf.id], string.format("err: id<%s> config is more than one in - [%s].",conf.id, indx))
		if ids[conf.id] == nil then
			ids[conf.id] = 1
		end
	end
end

local function timeListCheck(k, status)
	for indx, conf in pairs(status) do
		local r_conf = status[indx + 1]
		if conf and r_conf then

			Assert(r_conf.week >= conf.week, string.format("err: id<%s> status[%s].week small than status[%s].",k, indx, indx + 1))
			if r_conf.week == conf.week then
				local r_time = r_conf.hour * 3600 + r_conf.min * 60
				local c_time = conf.hour * 3600 + conf.min * 60

				Assert(r_time > c_time, string.format("err: id<%s> status[%s].(hour,min) bigger than status[%s].",k, indx, indx + 1))
				Assert(r_time - c_time >= conf.time, string.format("err: id<%s> status[%s].time bigger then next status time span.",k, indx))
			end
		end
	end
end

test_test_activitytimer.test_config = function( ... )
	-- 检查配置表中各项的参数
	local ActivityTime = ActivityTime

	Assert(ActivityTime,string.format("err:can't find ActivityTime"))
	if not ActivityTime then
		return
	end
	onlyOneIdCheck(ActivityTime)
	for k,conf in pairs(ActivityTime) do
		Assert(conf ~= nil, string.format("err:key<%d> is nil",k))
		if conf then
			--print("检测数字各项基本配置")
			checkFunc.numAttCheck(k, numAtts,conf)
			--print("检测属性设置是否在范围内")
			checkFunc.numAttRangeCheck(k, rangeAtts, conf)
			--检测openweeks配置
			openweeksCheck(k, conf)
			--print("检查status配置")
			statusAttCheck(k, conf.status)
			--print("检查status时间顺序")
			timeListCheck(k, conf.status)
		end
	end
end

TEST("activitytimer", "config", test_test_activitytimer.test_config, false)


