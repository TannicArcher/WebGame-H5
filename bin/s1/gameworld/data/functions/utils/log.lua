--[[
	author = 'Roson'
	time   = 07.16.2015
	name   = 打印LOG助手
	ver    = 0.1
]]

module("utils.log", package.seeall)

local FUNCTION_FORMAT_BY_ACTOR = "[ACTOR->%s] [FUN->%s] %s"
local FUNCTION_FORMAT = "[PACKAGE->%s][FUN->%s] %s,%s"
local PARAM_FORMAT = "[%s] "
local LOG_STR = "%s%s"

local NA_STR = "N/A"

function paramFormat( ... )
	local logStr = ""
	if not arg or #arg <= 0 then return logStr end

	local format = string.format
	for _,v in pairs(arg) do
		local ret = format(PARAM_FORMAT, tostring(v))
		logStr = format(LOG_STR, logStr, ret)
	end

	return logStr
end

function printLogStreamByActor(actor, funcName, ...)
	-- 处理ACTOR
	if not actor then actor = NA_STR end

	if type(actor) ~= "number" then
		if type(actor) == "string" then
			actor = tonumber(actor)
		else
			actor = LActor.getActorId(actor)
		end
	end

	local paramStr = paramFormat(...)

	print(string.format(FUNCTION_FORMAT_BY_ACTOR, actor or NA_STR, funcName or NA_STR, paramStr or NA_STR))
end

function printLogStream(package, funcName, key, ...)
	local paramStr = paramFormat(...)

	print(string.format(FUNCTION_FORMAT, package or NA_STR, funcName or NA_STR, key or NA_STR, paramStr or NA_STR))
end

function rankLogStream(rankList, package, rankName, maxCount)
	if not rankList then return end

	package = package or "N/A"
	rankName = rankName or "N/A"

	local Ranking = Ranking

	local rankCount = Ranking.getRankItemCount(rankList)
	maxCount = maxCount or rankCount
	rankCount = math.min(rankCount, maxCount)
	if rankCount <= 0 then return end

	local getItemFromIndex = Ranking.getItemFromIndex
	local getId = Ranking.getId
	local getPoint = Ranking.getPoint

	for i=1,rankCount do
		local rankItem = getItemFromIndex(rankList, i)
		if not rankItem then break end

		local actorId = getId(rankItem)
		local point = getPoint(rankItem)

		--然后开始写入日志
		System.logCounter(actorId, 0, 0, "rank", "", "userid:"..actorId, package, rankName, i, "", point, lfBI)
	end

end

-- 格式化打印
function log_print(fmt, ...)
	print(string.format(fmt, ...))
end

-- 打印调试信息, sModule表示当前正在调试的模块，在debug.txt中定义，传入nil表示不分模块
function log_debug(sModule, fmt, ...)
	if sModule == nil or sModule == DEBUG_MODULE then
		print(string.format(fmt, ...))
	end
end

-- 打印表
function print_lua_table(lua_table, indent)
	indent = indent or 0
	for k, v in pairs(lua_table) do
		if type(k) == "string" then
			k = string.format("%q", k)
		end
		local szSuffix = ""
		if type(v) == "table" then
			szSuffix = "{"
		end
		local szPrefix = string.rep("    ", indent)
		formatting = szPrefix.."["..k.."]".." = "..szSuffix
		if type(v) == "table" then
			print(formatting)
			print_lua_table(v, indent + 1)
			print(szPrefix.."},")
		else
			local szValue = ""
			if type(v) == "string" then
				szValue = string.format("%q", v)
			else
				szValue = tostring(v)
			end
			print(formatting..szValue..",")
		end
	end
end

function rankBackup(rank)
	if not rank then
		System.log("log", "rankBackup", "backup", "error rank is NULL" )
		return 
	end

	local rName = Ranking.getRankName(rank)
	if not rName then
		assert(false)
		return 
	end

	Ranking.save(rank, rName .. "_backup")
	Ranking.setRankName(rank, rName)
end

table.print = print_lua_table

LActor.log = printLogStreamByActor
System.log = printLogStream
System.logRank = rankLogStream


-- 导出的打印函数
_G.log_print = log_print
_G.log_debug = (GAME_DEBUG and log_debug or function() end)


_G.rank_backup = rankBackup
