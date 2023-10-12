--无极战场匹配模块(跨服服)
module("crosswujimatch", package.seeall)

--[[获取全局数据
	match[匹配池ID] = {
		[玩家ID] = {
			aid = 玩家ID
			name = 玩家名字
			sid = 服务器ID
			zslv = 转生等级
			isdon = 是否扩张匹配
			entryCount = 已轮空次数
			pid = 当前的匹配池ID
			mtime = 报名匹配时间
			power = 战斗力
		},
		...
	}
	matchAidPool[玩家ID]=匹配池ID
	-----------
	matchEid = 定时匹配的EID
]]
globalWuJiMatchData = globalWuJiMatchData or {}
local function getGlobalData()
	return globalWuJiMatchData
end

--插入信息到匹配数据里(匹配信息结构)
local function addToMacth(info)
	print(info.aid.." wujisystem.addToMacth")
	local pid = 1
	info.pid = pid
	--获取全局变量
	local gdata = getGlobalData()
	--维护玩家ID对应匹配池表
	if not gdata.matchAidPool then gdata.matchAidPool = {} end
	if gdata.matchAidPool[info.aid] then
		print(info.aid.." crosswujimatch.addToMacth is in matchAidPool")
		return
	end
	gdata.matchAidPool[info.aid] = pid
	--维护玩家信息表
	if not gdata.match then gdata.match = {} end
	if not gdata.match[pid] then gdata.match[pid] = {} end
	gdata.match[pid][info.aid] = info
end

--从匹配数据删除
local function delToMatch(aid)
	print(aid.." wujisystem.delToMatch")
	--获取全局变量
	local gdata = getGlobalData()
	--维护玩家ID对应匹配池表
	if not gdata.matchAidPool then return end
	if not gdata.matchAidPool[aid] then
		print(aid.." crosswujimatch.delToMatch is not in matchAidPool") 
		return
	end
	local oldPid = gdata.matchAidPool[aid]
	gdata.matchAidPool[aid] = nil
	--维护玩家信息表
	local oldInfo = gdata.match[oldPid][aid]
	gdata.match[oldPid][aid] = nil
	return oldPid, oldInfo
end

--改变玩家所在匹配池
local function changeToMatch(aid, pid)
	print(aid.." wujisystem.changeToMatch pid:"..pid)
	if not pid then return end
	--获取全局变量
	local gdata = getGlobalData()
	--维护玩家ID对应匹配池表
	if not gdata.matchAidPool then return end
	if not gdata.matchAidPool[aid] then
		print(aid.." crosswujimatch.changeToMatch is not in matchAidPool") 
		return
	end
	local oldPid = gdata.matchAidPool[aid]
	gdata.matchAidPool[aid] = pid --设置新的匹配池ID
	--维护玩家信息表
	local oldInfo = gdata.match[oldPid][aid]
	gdata.match[oldPid][aid] = nil --从旧匹配池删除
	if not gdata.match[pid] then gdata.match[pid] = {} end
	oldInfo.pid = pid
	gdata.match[pid][aid] = oldInfo --放入新的匹配池
end

--清空匹配池数据
local function clearAllMatchData()
	--获取全局变量
	local gdata = getGlobalData()
	gdata.match = nil
	gdata.matchAidPool = nil
end

--游戏服请求过来匹配
local function onToMatch(sId, sType, dp)
	local aid = LDataPack.readInt(dp) --玩家ID
	local name = LDataPack.readString(dp) --玩家名字
	local zslv = LDataPack.readInt(dp) --转生等级
	local isdon = LDataPack.readChar(dp) --是否扩张匹配
	local power = LDataPack.readInt64(dp) --战斗力
	local info = {
		aid=aid,sid=sId,zslv=zslv,isdon=isdon,entryCount=0,
		mtime = System.getNowTime(), power = power, name=name
	}
	--添加到匹配池
	addToMacth(info)
end

--游戏服请求过来取消匹配
local function onToCancelMatch(sId, sType, dp)
	local aid = LDataPack.readInt(dp) --玩家ID
	--从匹配池中删除
	delToMatch(aid)
end

--一组人匹配成功了
local function MatchSuccess(infoptab, pid)
	print("crosswujimatch.MatchSuccess infoptab size:"..(#infoptab))
	--随机一个匹配规则
	local rand = math.random(1, #WuJiMatchGroupConfig)
	local gcfg = WuJiMatchGroupConfig[rand].grouping
	--按战力排序
	table.sort( infoptab, function(a,b)
		return a.power > b.power
	end)
	print("crosswujimatch.MatchSuccess sort infoptab size:"..(#infoptab))
	--获取1阵营
	local tab1 = {}
	for _,r in ipairs(gcfg[1]) do
		print("crosswujimatch.MatchSuccess get 1 r:"..r)
		local info = infoptab[r]
		info.camp = 1
		info.idx = #tab1 + 1
		table.insert(tab1, info)
	end
	--获取2阵营
	local tab2 = {}
	for _,r in ipairs(gcfg[2]) do
		print("crosswujimatch.MatchSuccess get 2 r:"..r)
		local info = infoptab[r]
		info.camp = 2
		info.idx = #tab2 + 1
		table.insert(tab2, info)
	end
	--创建个战斗房间给它们
	local fbhdl = crosswujifbmgr.CreateBattleRoom(tab1, tab2)
	--通知这些人进入战场
	for _,info in ipairs(infoptab) do
		--发送匹配成功到游戏服
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCWujiCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCWujiCmd_MatchSuccess)
		LDataPack.writeInt(npack, info.aid)
		LDataPack.writeUInt(npack, fbhdl)
		LDataPack.writeInt(npack, info.camp)
		LDataPack.writeInt(npack, info.idx)
		System.sendPacketToAllGameClient(npack, info.sid)
	end
end

--匹配一个区间
local function doMatchByOne(gdata, pid, conf, allEntryInfo)
	if not gdata.match or not gdata.match[pid] then return end
	pdata = gdata.match[pid]
	--把所有人分组
	local tGroup = {}
	for aid,info in pairs(pdata or {}) do
		for i,zstb in ipairs(conf.groupingList) do
			if info.zslv >= zstb[1] and info.zslv <= zstb[2] then
				if not tGroup[i] then tGroup[i] = {} end
				table.insert(tGroup[i], info)
				break
			end
		end
	end
	--匹配所有转生等级分组
	local bnum = WujiBaseConfig.memberCnt * 2
	for _, infotab in ipairs(tGroup) do
		local addEnTab = infotab
		if #infotab >= bnum then
			--按时间排序
			table.sort( infotab, function(a,b)
		        return a.mtime < b.mtime
		    end)
		    --遍历匹配
			local infoptab = {}
			for _,info in ipairs(infotab) do
				table.insert(infoptab, info)
				--找到8人一组
				if #infoptab >= bnum then
					--从待匹配池中删除
					for _,tinfo in ipairs(infoptab) do
						delToMatch(tinfo.aid)
					end
					--调用匹配成功
					MatchSuccess(infoptab, pid)
					--清空开始匹配下一组
					infoptab = {}
				end
			end
			--剩余不够人数的轮空次数+1
			addEnTab = infoptab
		end
		--增加轮空次数
		for _,info in ipairs(addEnTab) do
			info.entryCount = info.entryCount + 1
			table.insert(allEntryInfo, info)
		end	
	end
end

--匹配一次所有人
local function doMatchAll(gdata)
	local allEntryInfo = {} --所有轮空的人
	for pid,conf in ipairs(WuJiMatchPoolConfig) do
		doMatchByOne(gdata, pid, conf, allEntryInfo)
	end
	return allEntryInfo
end

--检测是否需要换匹配池
local function checkChangeMatchPool(info)
	if not info.isdon or info.isdon ~= 1 then
		return --不往下匹配
	end
	--获取下一个池的配置
	local newPid = info.pid + 1
	local cfg = WuJiMatchPoolConfig[newPid]
	if not cfg then return end --已经到最大了
	if cfg.entryLimit <= info.entryCount then
		changeToMatch(info.aid, newPid)
	end
end

--匹配时间到(_,第几次匹配)
local function onMatchTime(_, count)
	--获取全局变量
	local gdata = getGlobalData()
	--处理匹配逻辑
	local allEntryInfo = doMatchAll(gdata)
	--处理未匹配成功的逻辑
	for _,info in ipairs(allEntryInfo) do
		checkChangeMatchPool(info)
	end
	--再次注册匹配函数
	local matchEventTime = WujiBaseConfig.matchCd
	gdata.matchEid = LActor.postScriptEventLite(nil, matchEventTime * 1000, onMatchTime, count+1)
end

--活动开始事件
function onWuJiStart()
	clearAllMatchData()
	--获取全局变量
	local gdata = getGlobalData()
	--注册匹配函数
	local matchEventTime = WujiBaseConfig.matchCd
	gdata.matchEid = LActor.postScriptEventLite(nil, matchEventTime * 1000, onMatchTime, 1)
end

--活动结束事件
function onWuJiClose()
	--获取全局变量
	local gdata = getGlobalData()
	--去除定时事件
	if gdata.matchEid then
		LActor.cancelScriptEvent(nil, gdata.matchEid)
		gdata.matchEid = nil
	end
	clearAllMatchData()
end

--启动初始化
local function initGlobalData()
	if System.isCommSrv() then return end
    --游戏服来的消息处理
    csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_ToMatch, onToMatch)
	csmsgdispatcher.Reg(CrossSrvCmd.SCWujiCmd, CrossSrvSubCmd.SCWujiCmd_ToCancelMatch, onToCancelMatch)
end

table.insert(InitFnTable, initGlobalData)
