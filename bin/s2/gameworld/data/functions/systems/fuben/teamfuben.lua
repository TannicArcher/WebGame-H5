module("teamfuben", package.seeall)


local rankingListName = "teamlikerank"
local rankingListFile = "teamlikerank.rank"
local rankingListMaxSize = TeamFuBenBaseConfig.rankMaxSize
local rankingListBoardSize = TeamFuBenBaseConfig.rankBoardSize
local rankingListColumns = {"name", "viplevel"}
local RoomJob = {
	host = 1, --队长,房主
	helper = 2, --协助者
	joiner = 3, --通关者
}
local p = Protocol
--[[获取全局变量
	roomId=当前房间ID,自增
	roomList = {
		[动态房间ID]={ --附加引用到ins.data下
			aids={ 玩家列表
				[玩家1]={
					rjob = 房间职位
					index = 索引
				},
			},
			pos[索引] = 玩家ID
			id=挑战的副本配置ID
			rid=动态房间ID
			hostAid = 房主的玩家ID
		}
	}
	aidRoomId = {
		[玩家ID]=所在房动态id
	}
]]
teamFuBenData = teamFuBenData or {}
local function getGlobalData()
	return teamFuBenData
end

local function getSysData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.teamfuben == nil then 
		var.teamfuben = {}
	end
	return var.teamfuben
end

--生成一个房间id
local function getRoomId()
	local gdata = getGlobalData()
	gdata.roomId = (gdata.roomId or 0) + 1
	return gdata.roomId
end

--[[获取个人静态变量
	passId = 0--已经通关到的ID
	flowerCount = 收到鲜花个数
	flowerInfo = { 收到的鲜花信息
		aid = 送花人玩家ID
		name = 送花人名
		count = 送花数量
	}
	invTime = 邀请间隔时间
]]
local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if data == nil then return nil end
	if data.teamfuben == nil then
		data.teamfuben = {}
	end
	local svar = System.getStaticVar()
	if data.teamfubenrest ~= svar.teamfubenrest then
		data.teamfubenrest = svar.teamfubenrest
		data.teamfuben.passId = nil
	end
	return data.teamfuben
end

--下发收到的花
local function sendHaveFlowers(actor)
	local var = getData(actor)
	if not var.flowerCount or var.flowerCount <= 0 then
		return
	end
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_TeamFuBenFlowers)
	--print(LActor.getActorId(actor).." teamfuben.sendHaveFlowers count:"..(var.flowerCount or 0))
	LDataPack.writeInt(npack, var.flowerCount or 0)
	for i = 1,(var.flowerCount or 0) do
		local info = var.flowerInfo[i] or {}
		LDataPack.writeString(npack, info.name or "")
		LDataPack.writeInt(npack, info.count or 0)
	end

    LDataPack.flush(npack)

    --清空鲜花记录
    var.flowerCount = nil
    var.flowerInfo = nil
end

--检测是否可以创建副本和挑战副本
local function checkCanOpen()
	local week = System.getDayOfWeek()
	if week == TeamFuBenBaseConfig.closeTime[1] then --周日
		local now = System.getNowTime()
		local y,m,d,h,i,s = System.timeDecode(now)
		if h >= TeamFuBenBaseConfig.closeTime[2] then
			return false
		end
	end
	return true
end

--发送个人基础信息
local function sendBaseInfo(actor)
	local var = getData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_TeamFbInfo)
	LDataPack.writeInt(npack, var.passId or 0)
	LDataPack.writeInt(npack, var.invTime or 0)
    LDataPack.flush(npack)
end

--获取当前可以打的最大副本ID
local function getCanEnterId(actor)
	local var = getData(actor)
	return (var.passId or 0) + 1
end

--返回开房成功
local function sendCreateRoom(actor, rid, id)
	print(LActor.getActorId(actor).." teamfuben.sendCreateRoom rid:"..rid.." id:"..id)
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_CreateTeamRoom)
	LDataPack.writeInt(npack, rid)
	LDataPack.writeInt(npack, id)
    LDataPack.flush(npack)
end

--下发房间变化信息房间内的所有人
local function sendRoomInfo(actor, roomInfo)
	local actorList = {}
	for raid,info in pairs(roomInfo.aids) do
		local ractor = LActor.getActorById(raid)
		if ractor then
			table.insert(actorList, ractor)
		end
	end
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_TeamRoomInfo)
	LDataPack.writeInt(npack, roomInfo.rid)
	LDataPack.writeChar(npack, #actorList)
	for _,ractor in ipairs(actorList) do
		local raid = LActor.getActorId(ractor)
		LDataPack.writeInt(npack, raid)
		LDataPack.writeChar(npack, roomInfo.aids[raid].rjob)
		LDataPack.writeString(npack, LActor.getName(ractor))
		LDataPack.writeByte(npack, LActor.getJob(ractor))
		LDataPack.writeByte(npack, LActor.getSex(ractor))
		local role = LActor.getRole(ractor,0)
		LDataPack.writeInt(npack, LActor.getEquipId(role, EquipSlotType_Coat))
		LDataPack.writeInt(npack, LActor.getEquipId(role, EquipSlotType_Weapon))
		local level, star, exp, status = LActor.getWingInfo(ractor, 0)
		LDataPack.writeInt(npack, level)
		LDataPack.writeChar(npack, status)
		local p1,p2,p3 = LActor.getZhuangBan(ractor, 0)
		LDataPack.writeInt(npack, p1)
		LDataPack.writeInt(npack, p2)
		LDataPack.writeInt(npack, p3)
		LDataPack.writeInt(npack, LActor.getZhuanShengLevel(actor))
		LDataPack.writeInt(npack, LActor.getLevel(actor))
	end
	LDataPack.flush(npack)
end

--请求开房
local function CreateRoom(actor)
	local aid = LActor.getActorId(actor)
	--禁止开始时间
	if not checkCanOpen() then
		print(aid.." teamfuben.reqCreateRoom not on open time")
		return
	end
	--在副本里面
	if LActor.isInFuben(actor) then
		print(aid.." teamfuben.reqCreateRoom is in fuben")
		return
	end
	local id = getCanEnterId(actor)
	--判断配置是否存在
	local cfg = TeamFuBenConfig[id]
	if not cfg then
		print(aid.." teamfuben.reqCreateRoom is not have cfg id:"..id)
		return
	end
	local gdata = getGlobalData()
	if not gdata.roomList then gdata.roomList = {} end
	if not gdata.aidRoomId then gdata.aidRoomId = {} end
	--判断是否已经加入房间
	if gdata.aidRoomId[aid] then
		print(aid.." teamfuben.reqCreateRoom is on id("..gdata.aidRoomId[aid]..") room")
		return
	end
	--创建房间
	local rid = getRoomId()
	--设置房间信息
	gdata.roomList[rid] = {
		id=id,
		hostAid = aid,
		rid=rid,	
	}
	local roomInfo = gdata.roomList[rid]
	roomInfo.aids = {}
	roomInfo.aids[aid] = {
		rjob = RoomJob.host,
		index = 1,
	}
	roomInfo.pos = {}
	roomInfo.pos[1] = aid
	--设置玩家所在房间信息
	gdata.aidRoomId[aid] = rid
	--返回创建房间成功
	sendCreateRoom(actor, rid, id)
	--返回房间信息变更
	sendRoomInfo(actor, roomInfo)
	return rid
end
local function reqCreateRoom(actor, packet)
	CreateRoom(actor)
end


--下发进入一个房间
local function sendEnterRoom(actor, res, id, rid)
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_EnterTeamRoom)
	LDataPack.writeChar(npack, res)
	LDataPack.writeInt(npack, id or 0)
	LDataPack.writeInt(npack, rid or 0)
	LDataPack.flush(npack)
end

--请求进入房间
local function EnterRoom(actor, rid)
	local aid = LActor.getActorId(actor)
	--禁止开始时间
	if not checkCanOpen() then
		print(aid.." teamfuben.reqEnterRoom not on open time")
		sendEnterRoom(actor, 1)
		return
	end
	--在副本里面
	if LActor.isInFuben(actor) then
		print(aid.." teamfuben.reqEnterRoom is in fuben")
		sendEnterRoom(actor, 2)
		return
	end
	local gdata = getGlobalData()
	if not gdata.aidRoomId then gdata.aidRoomId = {} end
	--判断是否已经加入房间
	if gdata.aidRoomId[aid] then
		print(aid.." teamfuben.reqEnterRoom is on id("..gdata.aidRoomId[aid]..") room")
		sendEnterRoom(actor, 3)
		return
	end
	--判断房间是否存在
	if not gdata.roomList then gdata.roomList = {} end
	local roomInfo = gdata.roomList[rid]
	if not roomInfo then
		print(aid.." teamfuben.reqEnterRoom not has id("..rid..") room")
		sendEnterRoom(actor, 4)
		return
	end
	--判断能否进入这个房间
	local cid = getCanEnterId(actor)
	if roomInfo.id > cid then
		print(aid.." teamfuben.reqEnterRoom not can enter id("..(roomInfo.id)..") room")
		sendEnterRoom(actor, 5)
		return
	end
	--获取房间配置
	local config = TeamFuBenConfig[roomInfo.id]
	if not config then
		print(aid.." teamfuben.reqEnterRoom not have config id:"..(roomInfo.id))
		sendEnterRoom(actor, 6)
		return
	end
	local index = nil
	for idx = 1,config.pmaxnum do
		if not roomInfo.pos[idx] then
			index = idx
			break
		end
	end
	--没有位置了;就是满人了
	if not index then
		print(aid.." teamfuben.reqEnterRoom not have free index")
		sendEnterRoom(actor, 7)
		return
	end
	--进入房间
	local rjob = cid > roomInfo.id and RoomJob.helper or RoomJob.joiner
	roomInfo.aids[aid] = {
		rjob = rjob,
		index = index
	}
	roomInfo.pos[index] = aid
	gdata.aidRoomId[aid] = rid
	sendEnterRoom(actor, 0, roomInfo.id, rid)
	--通知所有人房间信息变更
	for raid,_ in pairs(roomInfo.aids or {}) do
		local ractor = LActor.getActorById(raid)
		sendRoomInfo(ractor, roomInfo)
	end
end

local function reqEnterRoom(actor, packet)
	local rid = LDataPack.readInt(packet)
	EnterRoom(actor, rid)
end

local ExitType = {
	MySelf = 1,
	HostKill = 2,
	Disband = 3.
}
--下发退出房间消息
local function sendExitRoom(actor, so)
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_ExitTeamRoom)
	LDataPack.writeChar(npack, so)
	LDataPack.flush(npack)
end

--退出房间操作
local function ExitRoom(aid)
	local gdata = getGlobalData()
	if not gdata.aidRoomId then 
		print(aid.." teamfuben.ExitRoom not gdata.aidRoomId")
		return 
	end
	local rid = gdata.aidRoomId[aid]
	if not rid then 
		print(aid.." teamfuben.ExitRoom not rid")
		return 
	end
	if not gdata.roomList then 
		print(aid.." teamfuben.ExitRoom not gdata.roomList")
		return
	end
	local roomInfo = gdata.roomList[rid]
	if not roomInfo then 
		print(aid.." teamfuben.ExitRoom not roomInfo rid:"..rid)
		return 
	end
	--房主退出的情况
	if aid == roomInfo.hostAid then
		print(aid.." teamfuben.ExitRoom is hoster rid:"..rid)
		for raid,_ in pairs(roomInfo.aids) do
			gdata.aidRoomId[raid] = nil
			--发送解散消息
			if raid ~= roomInfo.hostAid then
				local ractor = LActor.getActorById(raid)
				if ractor then
					sendExitRoom(ractor, ExitType.Disband)
				end
			end
		end
		gdata.roomList[rid] = nil
	else
		print(aid.." teamfuben.ExitRoom not is hoster rid:"..rid)
		local info = roomInfo.aids[aid]
		roomInfo.pos[info.index] = nil
		roomInfo.aids[aid] = nil
		--table.remove(roomInfo.aids, aid)
		gdata.aidRoomId[aid] = nil
		--通知所有人房间信息变更
		for raid,_ in pairs(roomInfo.aids or {}) do
			print("teamfuben.ExitRoom sendRoomInfo to "..raid)
			local ractor = LActor.getActorById(raid)
			if ractor then
				sendRoomInfo(ractor, roomInfo)
			end
		end
	end
end

--请求退出房间
local function reqExitRoom(actor, packet)
	ExitRoom(LActor.getActorId(actor))
	sendExitRoom(actor, ExitType.MySelf)
end

--请求开启副本
local function reqStartRoom(actor, packet)
	local aid = LActor.getActorId(actor)
	if not checkCanOpen() then
		print(aid.." teamfuben.reqStartRoom not on open time")
		return
	end
	if LActor.isInFuben(actor) then
		print(aid.." teamfuben.reqStartRoom is in fuben")
		return
	end
	local gdata = getGlobalData()
	if not gdata.roomList then gdata.roomList = {} end
	if not gdata.aidRoomId then gdata.aidRoomId = {} end
	local rid = gdata.aidRoomId[aid]
	if not rid then
		print(aid.." teamfuben.reqStartRoom not have room")
		return
	end
	--房间信息
	local roomInfo = gdata.roomList[rid]
	if not roomInfo then
		print(aid.." teamfuben.reqStartRoom not have roomInfo")
		return
	end
	--判断是否是房主
	if roomInfo.hostAid ~= aid then
		print(aid.." teamfuben.reqStartRoom is not have host")
		return
	end
	local conf = TeamFuBenConfig[roomInfo.id]
	--创建副本
	local fbhandle = Fuben.createFuBen(conf.fbid)
	--获取INS
	local ins = instancesystem.getInsByHdl(fbhandle)
	if not ins then
		print(aid.." teamfuben.reqStartRoom create failure,not ins")
		return
	end
	ins.data = roomInfo
	--全局数据脱离这个房间
	gdata.roomList[rid] = nil
	--所有人进入副本
	for raid,info in pairs(roomInfo.aids) do
		local ractor = LActor.getActorById(raid)
		if ractor then
			local pos = conf.pos[info.index]
			LActor.enterFuBen(ractor, fbhandle, 0, pos.x, pos.y)
		end
		gdata.aidRoomId[raid] = nil
	end
end

--请求踢玩家出房间
local function reqKickOut(actor, packet)
	local kaid = LDataPack.readInt(packet)
	local aid = LActor.getActorId(actor)
	if aid == kaid then return end
	local gdata = getGlobalData()
	if not gdata.roomList then gdata.roomList = {} end
	if not gdata.aidRoomId then gdata.aidRoomId = {} end
	local rid = gdata.aidRoomId[aid]
	if not rid then
		print(aid.." teamfuben.reqKickOut not have room")
		return
	end
	--判断在不在同一个房间
	if rid ~= gdata.aidRoomId[kaid] then
		print(aid.." teamfuben.reqKickOut kickout aid is not on this room")
		return
	end
	--房间信息
	local roomInfo = gdata.roomList[rid]
	if not roomInfo then
		print(aid.." teamfuben.reqKickOut not have roomInfo")
		return
	end
	--判断是否是房主
	if roomInfo.hostAid ~= aid then
		print(aid.." teamfuben.reqKickOut is not have host")
		return
	end
	--把玩家移出房间
	ExitRoom(kaid)
	local kactor = LActor.getActorById(kaid)
	if kactor then
		sendExitRoom(kactor, ExitType.HostKill)
	end
end

local function sendFuBenResult(actor, result, roomInfo)
	local actorList = {}
	for raid,info in pairs(roomInfo.aids) do
		local ractor = LActor.getActorById(raid)
		if ractor then
			table.insert(actorList, ractor)
		end
	end
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_TeamFuBenResult)
	LDataPack.writeInt(npack, roomInfo.id or 0)
	LDataPack.writeChar(npack, result and 1 or 0)
	LDataPack.writeChar(npack, #actorList)
	for _,ractor in ipairs(actorList) do
		local raid = LActor.getActorId(ractor)
		LDataPack.writeInt(npack, raid)
		LDataPack.writeChar(npack, roomInfo.aids[raid].rjob)
		LDataPack.writeString(npack, LActor.getName(ractor))
		LDataPack.writeByte(npack, LActor.getJob(ractor))
		LDataPack.writeByte(npack, LActor.getSex(ractor))
	end
	LDataPack.flush(npack)	
end

local function clearAllEid(ins)
	if ins.data.rEid then
		for aid,eid in pairs(ins.data.rEid) do
			local actor = LActor.getActorById(aid)
			if actor then
				LActor.cancelScriptEvent(actor, eid)
			end
		end
	end
	ins.data.rEid = nil
end

--记录通关日志并排名
local function recordPassRank(id, players)
	local svar = getSysData()
	if not svar.passrank then svar.passrank = {} end
	table.insert(svar.passrank, {id=id, players=players, time=System.getNowTime()})
	table.sort(svar.passrank, function(a,b)
       	if a.id == b.id then
       		return a.time < b.time
       	end
       	return a.id > b.id
    end)
    local size = #(svar.passrank)
    local prn = TeamFuBenBaseConfig.passRankNum or 3
    if size > prn then
    	for i=prn+1,size do
    		if svar.passrank[prn+1] then
	    		table.remove(svar.passrank, prn+1)
	    	end
    	end
    end
end

--副本胜利的时候
local function onWin(ins)
	--清空所有复活倒计时
	clearAllEid(ins)
	print("teamfuben.onWin id:"..ins.data.id)
	--获取配置
	local conf = TeamFuBenConfig[ins.data.id]
	if not conf then
		print("teamfuben.onWin is not conf id:"..tostring(ins.data.id))
		return
	end
	local players = {}
	--给所有人掉落奖励
	for aid,info in pairs(ins.data.aids) do
		local ractor = LActor.getActorById(aid)
		if ractor then
			if info.rjob ~= RoomJob.helper and getCanEnterId(ractor) == ins.data.id then
				--掉落物品
				local reward = drop.dropGroup(conf.passReward)
				--local x,y = LActor.getPosition(ractor)
				--Fuben.RewardDropBag(ins.scene_list[1], x or 0, y or 0, aid, reward)
				if LActor.canGiveAwards(ractor, reward) then
					LActor.giveAwards(ractor, reward, "teamfuben")
				else
				    --邮件
					local mailData = {
						head=string.format(TeamFuBenBaseConfig.MailHead, conf.name), 
						context=string.format(TeamFuBenBaseConfig.MailContent, conf.name), 
						tAwardList=reward
					}
					mailsystem.sendMailById(aid, mailData)
				end
				--设置通关副本ID
				local var = getData(ractor)
				var.passId = ins.data.id
				sendBaseInfo(ractor)
			end
			if info.rjob == RoomJob.helper then
				if conf.chiv then
					updateRankingList(aid, conf.chiv)
				end
			end
			--发送副本胜利结算框
			sendFuBenResult(ractor, true, ins.data)
		end
		table.insert(players, {name=LActor.getActorName(aid), rjob=info.rjob})
	end
	recordPassRank(ins.data.id, players)
end

--副本输了的时候
local function onLose(ins)
	--清空所有复活倒计时
	clearAllEid(ins)
	print("teamfuben.onLose id:"..ins.data.id)
	for aid,_ in pairs(ins.data.aids) do
		local ractor = LActor.getActorById(aid)
		if ractor then
			--发送副本结算框
			print(aid.." teamfuben.onLose sendFuBenResult")
			sendFuBenResult(ractor, false, ins.data)
		end
	end
end

--玩家在副本内离线的处理
local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

--玩家退出副本
local function onExitFb(ins, actor)
	local roomInfo = ins.data
	local aid = LActor.getActorId(actor)
	local info = roomInfo.aids[aid]
	roomInfo.pos[info.index] = nil
	roomInfo.aids[aid] = nil
end

--玩家登陆
local function onLogin( actor )
	sendBaseInfo(actor)
	sendHaveFlowers(actor)
end

--每日零点
local function onNewDay(actor, islogin)
	if not islogin then
		sendBaseInfo(actor)
	end
end

--玩家正常离线
local function onLogout(actor)
	ExitRoom(LActor.getActorId(actor))
end

local function onEnterFuben(actor, fbid)
	if fbid ~= 0 then
		ExitRoom(LActor.getActorId(actor))
	end
end

local function updateDynamicFirstCache(actor_id)
    local rank = Ranking.getRanking(rankingListName)
	local  rankTbl = Ranking.getRankingItemList(rank, rankingListMaxSize)
	if rankTbl == nil then 
		rankTbl = {} 
	end
	if #rankTbl ~= 0 then 
		local prank = rankTbl[1]
		if actor_id == nil or actor_id == Ranking.getId(prank) then  
			morship.updateDynamicFirstCache(Ranking.getId(prank),RankingType_TeamLike)
		end
	end
end

local function initRankingList()
    local rank = Ranking.getRanking(rankingListName)
    if rank  == nil then
        rank = Ranking.add(rankingListName, rankingListMaxSize)
        if rank == nil then
            print("can not add rank:"..rankingListName)
            return
        end
        if Ranking.load(rank, rankingListFile) == false then
            -- 创建排行榜
            for i=1, #rankingListColumns do
                Ranking.addColumn( rank, rankingListColumns[i] )
            end
        end
    end
    local col = Ranking.getColumnCount(rank)
    for i=col+1,#rankingListColumns do
        Ranking.addColumn(rank, rankingListColumns[i])
    end
    Ranking.save(rank, rankingListFile)
    Ranking.addRef(rank)
    updateDynamicFirstCache()
end

local function resetRankingList()
	print("teamfuben.resetRankingList")
    dRankUpdateBefore(rankingListName)
	local rank = Ranking.getRanking(rankingListName)
	if rank == nil then return end
	Ranking.clearRanking(rank)
end

local function getrank(actor)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return 0 end

    return Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1
end

local function notifyRankingList(actor)
	print(LActor.getActorId(actor).." teamfuben.notifyRankingList")
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local  rankTbl = Ranking.getRankingItemList(rank, rankingListBoardSize)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Ranking, Protocol.sRankingCmd_ResRankingData)
    if npack == nil then return end

    if rankTbl == nil then rankTbl = {} end
    LDataPack.writeShort(npack, RankingType_TeamLike)
    LDataPack.writeShort(npack, #rankTbl)
    if rankTbl and #rankTbl > 0 then
        for i = 1, #rankTbl do
            local prank = rankTbl[i]
            LDataPack.writeData(npack, 5,
                dtShort, i,                 --rank
                dtInt, Ranking.getId(prank), --id
                dtString, Ranking.getSub(prank, 0),--name
                dtShort, Ranking.getSub(prank, 1), --viplevel
                dtInt, Ranking.getPoint(prank) --侠义值
            )
        end
    end
    LDataPack.writeShort(npack, Ranking.getItemIndexFromId(rank, LActor.getActorId(actor)) + 1)
    LDataPack.flush(npack)
end

local function onReqRanking(actor)
    notifyRankingList(actor)
end
_G.onReqTeamLikeRanking = onReqRanking

function updateRankingList(actorId, score)
    local rank = Ranking.getRanking(rankingListName)
    if rank == nil then return end
    local actorData = LActor.getActorDataById(actorId)
    local item = Ranking.getItemPtrFromId(rank, actorId)
    if item ~= nil then
        local p = Ranking.getPoint(item)
        Ranking.setItem(rank, actorId, p + score)
    else
        item = Ranking.tryAddItem(rank, actorId, score)
        if item == nil then return end
        --创建榜单
        Ranking.setSub(item, 0, actorData.actor_name)
    end
    Ranking.setSubInt(item, 1, actorData.vip_level)
    updateDynamicFirstCache()
end

--请求继续副本--CreateRoom(actor)
local function reqContinue(actor, packet)
	local type = LDataPack.readChar(packet)
	local fbhdl = LActor.getFubenHandle(actor)
	local maid = LActor.getActorId(actor)
	--获取副本的ins
	local ins = instancesystem.getInsByHdl(fbhdl)
	if not ins then
		print(maid.." teamfuben.reqContinue is not has ins")
		return
	end
	if not ins.is_win then
		print(maid.." teamfuben.reqContinue is not win")
		return
	end
	local roomInfo = ins.data
	if not roomInfo then 
		print(maid.." teamfuben.reqContinue not have roomInfo")
		return
	end
	if not roomInfo.aids then
		print(maid.." teamfuben.reqContinue not have roomInfo.aids")
		return
	end
	--判断是否房主
	if not roomInfo.hostAid or maid ~= roomInfo.hostAid then
		print(maid.." teamfuben.reqContinue not is host")
		return
	end
	--获取下一关的配置
	local nid = getCanEnterId(actor)
	--判断配置是否存在
	local conf = TeamFuBenConfig[nid]
	if not conf then
		print(maid.." teamfuben.reqContinue not have next conf nid:"..nid)
		return
	end
	if type == 0 then --退出创建房间
		--房主创建房间
		LActor.exitFuben(actor)
		local rid = CreateRoom(actor)
		if not rid then
			print(maid.." teamfuben.reqContinue create room error")
			return
		end
		for aid,info in pairs(roomInfo.aids) do
			local ractor = LActor.getActorById(aid)
			if ractor then
				LActor.exitFuben(ractor)
				--进入房间
				EnterRoom(ractor, rid)
			end
		end
	elseif type == 1 then
		--创建副本
		local fbhandle = Fuben.createFuBen(conf.fbid)
		--获取INS
		local ins = instancesystem.getInsByHdl(fbhandle)
		if not ins then
			print(maid.." teamfuben.reqContinue create failure,not ins")
			return
		end
		--roomInfo.rid = getRoomId() --房间动态ID更新
		--复制一份房间数据
		ins.data = utils.table_clone(roomInfo)
		--更新房间信息
		roomInfo = ins.data
		roomInfo.id = nid --配置ID更新
		--所有人进入副本
		for raid,info in pairs(roomInfo.aids) do
			local ractor = LActor.getActorById(raid)
			if ractor then
				local cid = getCanEnterId(ractor)
				if info.rjob ~= RoomJob.host then
					info.rjob = cid > roomInfo.id and RoomJob.helper or RoomJob.joiner
				end
				local pos = conf.pos[info.index]
				LActor.enterFuBen(ractor, fbhandle, 0, pos.x, pos.y)
			end
		end
	end
end

--通知复活倒计时
local function notifyRebornTime(actor, etime, hdl)
 	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_TeamFuBenRebornTime)
    if npack == nil then return end
    LDataPack.writeDouble(npack, hdl)
    LDataPack.writeInt(npack, etime)
    LDataPack.flush(npack)	
end

local function reborn(actor, handle)
    local ins = instancesystem.getInsByHdl(handle)
    if ins then
	    local actorId = LActor.getActorId(actor)
    	local x,y = LActor.getPosition(actor)
   		LActor.relive(actor, x, y)
   		if ins.data.rEid then
		    ins.data.rEid[actorId] = nil
		end
	end
end

local function onActorDie(ins, actor, killerHdl)
--[[local isAllDie = true
	for aid,_ in ipairs(ins.data.aids) do
		local ractor = LActor.getActorById(aid)
		if ractor then
			if not LActor.isDeath(ractor) then
				isAllDie = false
				break
			end
		end
	end
	if isAllDie then
		--副本输了
		ins:lose()
	else
]]
	--注册复活倒计时
	if not ins.data.rEid then ins.data.rEid = {} end
	local actorId = LActor.getActorId(actor)
	ins.data.rEid[actorId] = LActor.postScriptEventLite(actor, TeamFuBenBaseConfig.rebornCd * 1000, reborn, ins.handle)
	notifyRebornTime(actor, TeamFuBenBaseConfig.rebornCd, killerHdl)
--	end
end

local function reqPassRank(actor, packet)
	local svar = getSysData()
	if not svar.passrank then return end
 	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_TeamFuBenPassRank)
    if npack == nil then return end
    LDataPack.writeChar(npack, #svar.passrank)
    for _,info in ipairs(svar.passrank) do
    	LDataPack.writeInt(npack, info.id)
    	LDataPack.writeChar(npack, #info.players)
    	for _,pinfo in ipairs(info.players) do
    		LDataPack.writeChar(npack, pinfo.rjob)
    		LDataPack.writeString(npack, pinfo.name)
    	end
    end
    LDataPack.flush(npack)
end

--请求邀请玩家
local function reqInvite(actor, packet)
	local msg = LDataPack.readString(packet)
	local aid = LActor.getActorId(actor)
	--获取全局变量
	local gdata = getGlobalData()
	if not gdata.roomList then gdata.roomList = {} end
	if not gdata.aidRoomId then gdata.aidRoomId = {} end
	--是否在房间里
	local rid = gdata.aidRoomId[aid]
	if not rid then
		print(aid.." teamfuben.reqInvite not have room")
		return
	end
	--房间信息
	local roomInfo = gdata.roomList[rid]
	if not roomInfo then
		print(aid.." teamfuben.reqInvite not have roomInfo")
		return
	end
	--判断是否是房主
	if roomInfo.hostAid ~= aid then
		print(aid.." teamfuben.reqInvite is not have host")
		return
	end

	--判断邀请间隔
	local var = getData(actor)
	if (var.invTime or 0) > System.getNowTime() then
		print(aid.." teamfuben.reqInvite have invTime")
		return
	end
	var.invTime = System.getNowTime() + (TeamFuBenBaseConfig.invTime or 0)
	sendBaseInfo(actor)

	local npack = LDataPack.allocPacket()
	if npack == nil then return end
	LDataPack.writeByte(npack,Protocol.CMD_Fuben)
	LDataPack.writeByte(npack,Protocol.sFubenCmd_TeamFuBenInvite)

	LDataPack.writeString(npack, msg)

	System.broadcastData(npack)
end

--请求给玩家送花
local function reqSendFlowers(actor, packet)
	local aid = LDataPack.readInt(packet)
	local count = LDataPack.readInt(packet)
	if not aid or not count then return end
	if aid == 0 then return end
	if not LActor.getActorDataById(aid) then
		print(LActor.getActorId(actor).." teamfuben.reqSendFlowers not have aid actor "..aid)
		return
	end
	if not TeamFuBenBaseConfig.itemId then return end
	--判断道具是否足够
	local haveItemCount = LActor.getItemCount(actor, TeamFuBenBaseConfig.itemId)
	if haveItemCount < count then
		print(LActor.getActorId(actor).." teamfuben.reqSendFlowers not have item count")
		return
	end
	--扣除道具
	LActor.costItem(actor, TeamFuBenBaseConfig.itemId, count, "team flower")
	--给对方的处理
	asynevent.reg(aid,function(imageActor,srcActorId, count)
		--记录送花记录
		local var = getData(imageActor)
		if not var.flowerInfo then var.flowerInfo = {} end
		if not var.flowerCount then var.flowerCount = 0 end
		local isFind = false
		for i = 1,var.flowerCount do
			local info = var.flowerInfo[i]
			if info and info.id == srcActorId then
				info.count = (info.count or 0) + count
				isFind = true
				break
			end
		end
		if not isFind then
			var.flowerCount = var.flowerCount + 1
			var.flowerInfo[var.flowerCount] = {}
			var.flowerInfo[var.flowerCount].id = srcActorId
			var.flowerInfo[var.flowerCount].name = LActor.getActorName(srcActorId)
			var.flowerInfo[var.flowerCount].count = count
		end
		--增加排行榜数值
		updateRankingList(LActor.getActorId(imageActor), (TeamFuBenBaseConfig.flowerChiv or 0)*count)
		--实时通知客户端
		if not LActor.isImage(imageActor) then
			print("teamfuben.reqSendFlowers src:"..srcActorId.." to tar:"..LActor.getActorId(imageActor).." is not image")
			sendHaveFlowers(imageActor)
		else
			print("teamfuben.reqSendFlowers src:"..srcActorId.." to tar:"..LActor.getActorId(imageActor).." is image")
		end
	end, LActor.getActorId(actor), count)
end

--组队副本重置时间到
local function TeamFuBenRest()
	resetRankingList()
	local svar = System.getStaticVar()
	svar.teamfubenrest = System.getNowTime()
	local gdata = getGlobalData()
	for _,roomInfo in pairs(gdata.roomList or {}) do
		if roomInfo.hostAid then
			ExitRoom(roomInfo.hostAid)
			local actor = LActor.getActorById(roomInfo.hostAid)
			if actor then
				sendExitRoom(actor, ExitType.MySelf)
			end
		end
	end
	gdata.roomList = nil
	gdata.aidRoomId = nil
	gdata.roomId = nil
end
_G.TeamFuBenRest = TeamFuBenRest

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeUserLogout, onLogout)
	actorevent.reg(aeNewDayArrive, onNewDay)
	actorevent.reg(aeEnterFuben, onEnterFuben)

	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_CreateTeamRoom, reqCreateRoom) --请求开房间
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_EnterTeamRoom, reqEnterRoom) --请求进入房间
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_ExitTeamRoom, reqExitRoom) --请求退出房间
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_StartTeamRoom, reqStartRoom) --请求开始副本
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_TeamRoomTickActor, reqKickOut)--请求踢玩家
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_TeamFuBenContinue, reqContinue) --请求继续副本
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_TeamFuBenPassRank, reqPassRank) --请求点赞排行
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_TeamFuBenSendFlowers, reqSendFlowers) --请求给玩家送花
	netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_TeamFuBenInvite, reqInvite) --请求邀请玩家

	local isreg = {}
	for _, v in pairs(TeamFuBenConfig) do
		if not isreg[v.fbid] then
			insevent.registerInstanceWin(v.fbid, onWin)
			insevent.registerInstanceLose(v.fbid, onLose)
			insevent.registerInstanceOffline(v.fbid, onOffline)
			insevent.registerInstanceExit(v.fbid, onExitFb)
			insevent.registerInstanceActorDie(v.fbid, onActorDie)
			isreg[v.fbid] = true
		end
	end
	isreg = nil
end
local function releaseRankingList()
    local rank = Ranking.getRanking(rankingListName)
    Ranking.save(rank, rankingListFile)
    Ranking.release(rank)
end
engineevent.regGameStartEvent(initRankingList)
engineevent.regGameStopEvent(releaseRankingList)
table.insert(InitFnTable, initGlobalData)

--teamfb
function gmHandle(actor, args)
	local cmd = args[1]
	if cmd == "create" then
		CreateRoom(actor)
	elseif cmd == "start" then
		reqStartRoom(actor, nil)
	elseif cmd == "rest" then
		TeamFuBenRest()
	elseif cmd == "p" then
		local var = getData(actor)
		var.passId = tonumber(args[2] or 1)
	end
	return true
end
