--时间域模块
module("timedomain", package.seeall)

--[[ 时间域结构
    rule 规则 y.m.d-h:m ~/^ y.m.d-h:m [0,1,2,3..6]
                ~ 表示确定的两个时间点之间内，匹配星期
                ^ 表示前后两个时间域组成的时间段， 匹配星期
                * 表示不限制
                []是星期几，不填或[*] 或 []表示不限

    rule = "2015.10.1-10:0 ~ 2015.10.7-18:0 []"  10月1日10点开始，7日18点结束，不限星期几
           = "2015.10.1-10:0 ~ 2015.10.7-18:0 [*]"  10月1日10点开始，7日18点结束，不限星期几
             = "2015.10.1-10:0 ~ 2015.10.7-18:0 "  10月1日10点开始，7日18点结束，不限星期几

              "*.8.1-*:* ^ *.9.15-*:* [0,6]"   每年8月9月的1-15号的周末

              "*.*.*-20:0 ^ *.*.*-22:00 "   每天晚8点到10点
              "*.*.*-20:0 ^ *.*.*-22:00 [3,6]"   周3周6 晚8点到10点
              "*.*.*-22:0 ^ *.*.*-10:00 "   每天晚10点至次日早10点
              !!!   "*.*.1-22:0 ^ *.*.2-10:00 "   1日晚10点至2日早10点 2日晚10点日3日早10点
--]]


--用作活动时间配置，都是在启动时注册，会重复注册所以热更新时清空
ruleStart = {}
ruleEnd = {}

--对外接口
function checkTime(rule)
    return System.checkRuleTime(rule)
end

function checkTimes(rules)
	local active = 0
	for _, rule in ipairs(rules) do
		active = active + ((System.checkRuleTime(rule) and 1) or 0)
	end
	return active > 0
end

function getTimes(rules)
	if rules == nil then return -1, -1 end
	if #rules == 1 then
		return getStartTime(rules[1]), getEndTime(rules[1])
	end

	local timeList = {}
	for i, rule in ipairs(rules) do
		local startTime, endTime =getStartTime(rule), getEndTime(rule)
		if startTime == -1 or endTime == -1 then return -1, -1 end
		--print("on getTimes. rule:"..rule.." s:"..os.date("%a, %d %b %Y %X GMT", startTime).." e:"..os.date("%a, %d %b %Y %X GMT", endTime))
		print("on getTimes. rule:"..rule.." s:"..startTime.." e:"..endTime)
		startTime = System.encodeTime(startTime)
		endTime = System.encodeTime(endTime)
		table.insert(timeList, {s=startTime, e = endTime})
	end
	table.sort(timeList, function(a,b) return a.s<b.s end)
	local endTime = timeList[1].e
	for _, time in ipairs(timeList) do
		if time.s < endTime then
			endTime = time.e
		else
			break
		end
	end

	print("final: s:"..timeList[1].s.. " e:"..endTime)
	return timeList[1].s, endTime
end

function getStartTime(rule)
    return System.getRuleStartTime(rule)
end

function getEndTime(rule)
    return System.getRuleEndTime(rule)
end

function regStart(rule, func, ...)
    if ruleStart[rule] == nil then
        ruleStart[rule] = {}
        System.regStartScript(rule)
    end
    table.insert(ruleStart[rule], {func, arg})
end

function regEnd(rule, func, ...)
    if ruleEnd[rule] == nil then
        ruleEnd[rule] = {}
        System.regEndScript(rule)
    end
    table.insert(ruleEnd[rule], {func, arg})
end

--------------------------------封装部分--------------------------------------

local function onTimeRuleStart(rule)
	if ruleStart[rule] == nil then return end
    for _, v in pairs(ruleStart[rule]) do
	    v[1](rule, v[2])
	    print("on rule start:"..rule)
    end
end

local function onTimeRuleEnd(rule)
	if ruleEnd[rule] == nil then return end
    for _, v in pairs(ruleEnd[rule]) do
	    v[1](rule, v[2])
	    print("on rule end:"..rule)
    end
end

_G.onTimeRuleStart = onTimeRuleStart
_G.onTimeRuleEnd = onTimeRuleEnd
