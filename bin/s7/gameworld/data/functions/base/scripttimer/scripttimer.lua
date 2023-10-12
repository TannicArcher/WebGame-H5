--根据TimerConfig配置执行函数(系统执行)
module("scripttimer", package.seeall)

 
--TimerConfig = nil
--require("scripttimer.scripttimerconf")
--local config = TimerConfig

_G.SCRIPTTIMELIST = nil

function checkTime(data, value)
	if type(data) == "number" then
		return data == value
	elseif type(data) == "table" then
		for _, info in ipairs(data) do
			--找到直接返回true
			if info == value then return true end
		end
		--没找到返回false
		return false
	end
end

function checkScriptTimer()
	local now = System.getNowTime()
	local _, month, day, hour, minute, _ = System.timeDecode(now)
	local week = System.getDayOfWeek()
	local delList = {}
	--todo这里可以优化, 只需要根据hour,minute 来定位该分钟是否需要执行
	for pos, info in ipairs(_G.SCRIPTTIMELIST) do
		--是否需要执行
		local isExe = true
		local conf = info.config
		--如果是开服相关的(因为和开服时间相关, 只执行一次)
		if info.exeTime then
			--如果已经到时间,设置需要执行,且记录位置删除
			if now >= info.exeTime then
				table.insert(delList, pos)
			else
				isExe = false
			end
		else
			--与开服时间不相关的,进行一系列检查
			if isExe and checkTime(conf.hour, hour) == false then isExe = false end
			if isExe and checkTime(conf.minute, minute) == false then isExe = false end
			if isExe and checkTime(conf.month, month) == false then isExe = false end
			if isExe and checkTime(conf.day, day) == false then isExe = false end
			if isExe and checkTime(conf.week, week) == false then isExe = false end
		end

		if isExe then
			--初始化的时候已经判断, 一定是函数, 这里就不再判断了
			local func = _G[conf.func]
			if conf.params then
				func(now, unpack(conf.params))
			else
				func(now)
			end
			print("ScriptTimer runFunc " .. conf.func)
		end
	end
	
	table.sort(delList, function(a,b) return a > b end )
	for _, pos in ipairs(delList) do
		table.remove(_G.SCRIPTTIMELIST, pos)
	end
end

function initScriptTimer()
	local now = System.getNowTime()
	_G.SCRIPTTIMELIST = {}
	for _, info in ipairs(TimerConfig) do
		--配置的函数并不存在
		assert(type(_G[info.func]) == "function")
		if info.params then
			--参数列表必须是表形式
			assert(type(info.params) == "table")
		end
		--配置了与开服相关
		if info.openSrv == 1 then
			--只检查小时(有可能同小时内有多个执行)
			assert(type(info.day) == "number")
			assert(type(info.hour) == "number")
			assert(type(info.minute) == "number")

			--获取服务器开服时间当天的0点
			local openTime = System.getOpenServerStartDateTime()
			local exeTime = openTime + (info.day - 1)*(3600 * 24) + info.hour*3600 + info.minute*60
			if now <= exeTime then
				table.insert(_G.SCRIPTTIMELIST, {exeTime = exeTime, config = info})
			end
		elseif info.hfSrv == 1 then
			--只检查小时(有可能同小时内有多个执行)
			assert(type(info.day) == "number")
			assert(type(info.hour) == "number")
			assert(type(info.minute) == "number")

			--获取服务器开服时间当天的0点
			local hfTime = hefutime.getHeFuDayStartTime()
			if hfTime then
				local exeTime = hfTime + (info.day - 1)*(3600 * 24) + info.hour*3600 + info.minute*60
				if now <= exeTime then
					table.insert(_G.SCRIPTTIMELIST, {exeTime = exeTime, config = info})
				end
			end
		else
			table.insert(_G.SCRIPTTIMELIST, {config = info})
		end
	end
	--直接注册GameTimer(c++已经保证GameTimer是X分0秒执行)
	engineevent.regGameTimer(checkScriptTimer)
end

function reg(timeInfo)
	if type(timeInfo) ~= "table" then
		assert(false)
		return
	end
	table.insert(TimerConfig, timeInfo)
end
