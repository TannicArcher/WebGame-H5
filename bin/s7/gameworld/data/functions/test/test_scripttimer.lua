-- 全局定时器配置测试
module("test.test_scripttimer" , package.seeall)
setfenv(1, test.test_scripttimer)
local checkFunc = require("test.assert_func")
require("scripttimer.scripttimerconf")
local scripttimer = require("base.scripttimer.scripttimer")
local TimerConfig = TimerConfig
local TEST = _G.TEST
local Item = Item
local test_scripttimer_func = {}
--数字属性类型名称
local numAtts = {"month", "day", "hour", "minute", "level", "reliveTime"}
--引用属性类型名称
local refAtts = { "txt" }
--数字属性范围检测配置
local rangeAtts = {
	{ name = "month", min = 1, max = 12 },
	{ name = "day", min = 1, max = 31 },
	{ name = "hour", min = 0, max = 23 },
	{ name = "minute", min = 0, max = 59 },
	{ name = "level", min = 0, max = 9999 },
}
--子表属性包含检测
local tipTypeRangeAtts = {
	{ name = "tipType", range = {1, 2, 4, 8, 16, 32, 64, 128} }
}

--检测全局方法是否存在
local function globalFuncCheck(k, conf)
	if conf.func then
		local func = _G[conf.func]
		Assert(func, string.format("err: id [%d] - _G[%s] can't find it.",k , conf.func))
	end
end

test_scripttimer_func.test_config = function( ... )

	-- 检查配置表中各项的参数
	local TimerConfig = TimerConfig
	Assert(TimerConfig,string.format("err:can't find TimerConfig"))
	if not TimerConfig then
		return
	end

	local onTime = scripttimer.onTime
	for k,conf in pairs(TimerConfig) do
		Assert(conf ~= nil, string.format("err:key<%d> is nil",k))
		if conf then
			--print("检测数字各项基本配置")--允许为空
			checkFunc.numAttCheck(k, numAtts,conf, true)
			--print("检测属性设置是否在范围内")
			checkFunc.numAttRangeCheck(k, rangeAtts, conf)
			--print("检测引用的各项配置")
			checkFunc.refAttCheck(k, refAtts, conf)
			--print(检查全局方法是否存在)
			globalFuncCheck(k, conf)
			--print(检测子表同母表的包含关系)
			checkFunc.childTabAttCheck(k, tipTypeRangeAtts, conf)
			--print("强制执行所有的方法，如果卡住则是被卡住的ID出现了问题")
			--该测试最好在非协程情况下执行，可以直接将错误打印出来
			if onTime then
				onTime(conf)
			end
		end
	end
end

TEST("scripttimer", "config", test_scripttimer_func.test_config, false)



