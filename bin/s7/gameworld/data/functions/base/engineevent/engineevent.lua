module("engineevent" , package.seeall)

local GameStartEventList = { }
local GameStopEventList = { }
local GameTimer = {}
local PrecisionTime = {}
local NewDay = {}

local common = require("utils.common")

local function regEvent(tbl, proc)
	common.reg(tbl, proc)
end

local function onEvent(tbl, ...)
	common.callFuncInTbl(tbl, ...)
end

local function onPrecisionTimer()
    local now = System.getNowTime()

    local data = System.getStaticVar()
    if data == nil then print("!!!") data = {} end
    local last = data.lastDayTime or 0

    if not System.isSameDay(now,last) then
	    print("engineevent.onPrecisionTimer newday now:"..now..",last:"..tostring(data.lastDayTime))
        data.lastDayTime = now
        onEvent(NewDay)
    end
end

--------------------注册接口---------------------
function regGameStartEvent(proc)
	regEvent(GameStartEventList, proc)
end

function regGameStopEvent(proc)
	regEvent(GameStopEventList, proc)
end

function regGameTimer(proc)
	regEvent(GameTimer,proc)
end

function regPrecisionTimer(proc)
	regEvent(PrecisionTime,proc)
end

function regNewDay(proc)
    regEvent(NewDay, proc)
end

function unregPrecisionTimer(proc)
	for i = #PrecisionTime, 1, -1 do
		if PrecisionTime[i] == proc then
			table.remove(PrecisionTime, i)
		end
	end
end

function preLoadServerName()
	print("preLoadServerName... WarFun")
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print("error, preLoadServerName fail...............")
		return
	end

	local err = System.dbQuery(db, "call loadservername()")
	if err ~= 0 then
		print("error, preLoadServerName dbQuery fail...............")
		return -1
	end

	--[[
	WarFun.clearServerName()
	local row = System.dbCurrentRow(db)
	local count = System.dbGetRowCount(db)
	for i=1,count do
		local serverid = System.dbGetRow(row, 0)
		local readid = System.dbGetRow(row, 1)
		local name = System.dbGetRow(row, 2)

		WarFun.addServerName(tonumber(serverid), tonumber(readid), name or "")
		row = System.dbNextRow(db)
	end
	--]]

	System.dbResetQuery(db)
	System.dbClose(db)
end

function preLoadServerRoute()
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print("error, preLoadServerRoute fail...............")
		return
	end

	local err = System.dbQuery(db, "call loadcharactorserveraddress()")
	if err ~= 0 then
		print("error, loadcharactorserveraddress dbQuery fail...............")
		return -1
	end

	local row = System.dbCurrentRow(db)
	local count = System.dbGetRowCount(db)

	local serverMap = {}
	for i=1,count do
		local serverid = System.dbGetRow(row, 0)
		if not System.geHasRoute(serverid) or serverMap[serverid] then
			serverMap[serverid] = true

			local hostname = System.dbGetRow(row, 1)
			local port = System.dbGetRow(row, 2)

			System.geAddRoutes(tonumber(serverid), hostname or "", tonumber(port))
		end
		row = System.dbNextRow(db)
	end

	System.dbResetQuery(db)
	System.dbClose(db)
end

_G.OnGameStart = function()
--	preLoadServerName()
--	preLoadServerRoute()
	serverroute.loadServerRoute()
	onEvent(GameStartEventList)
end

_G.OnGameStop = function()
	onEvent(GameStopEventList)
end

--一分钟定时执行的函数
_G.OnGameTimer = function()
	onEvent(GameTimer)
end

-- 高精度的定时函数，现在为5s一次
_G.OnGamePrecisionTimer = function()
    onPrecisionTimer()
    onEvent(PrecisionTime)
end


--gm测试
function testNewDay()
    onEvent(NewDay)
end
