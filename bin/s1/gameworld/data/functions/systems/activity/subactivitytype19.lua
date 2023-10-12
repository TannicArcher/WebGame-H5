--跨服消费榜
module("subactivitytype19", package.seeall)
-- local langScript = Lang.ScriptTips
local p = Protocol
local subType = 19
local subConfing = ActivityType19Config

local function onConsumeYuanbao(id, conf)
	return function(actor, value)
		if not System.isCommSrv() then return end
		if activitysystem.activityTimeIsEnd(id) then return end
		
		local var = activitysystem.getSubVar(actor, id)
		var.totalConsume = (var.totalConsume or 0) + value
		
		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCComsumeCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCComsumeCmd_UpdateRankInfo)
		LDataPack.writeInt(pack, System.getServerId())
		LDataPack.writeInt(pack, id)
		LDataPack.writeInt(pack, LActor.getActorId(actor))
		LDataPack.writeInt(pack, var.totalConsume)
		LDataPack.writeString(pack, LActor.getName(actor))
		LDataPack.writeInt(pack, LActor.getJob(actor))
		LDataPack.writeInt(pack, LActor.getSex(actor))
		System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsBattleSrv))
    end
end

function getRank(activityId)
	local rankName = string.format("cscomsumerank_%d", activityId)
	local rank = Ranking.getRanking(rankName)
	if rank then return rank end
	local rankFile = string.format("cscomsumerank_%d.rank", activityId)
	local maxNum = 100
	local coloumns = {"serverId", "actorname", "job", "sex"}
	local rank = nil
	if not System.isCommSrv() then
		rank = rankfunc.initRank(rankName, rankFile, maxNum, coloumns, true)
		Ranking.setAutoSave(rank, true)
	end
	return rank
end

function onUpdateRank_cross(sId, sType, dp)
	local serverId = LDataPack.readInt(dp)
	local activityId = LDataPack.readInt(dp)
	local actorId = LDataPack.readInt(dp)
	local totalConsume = LDataPack.readInt(dp)
	local actorname = LDataPack.readString(dp)
	local job = LDataPack.readInt(dp)
	local sex = LDataPack.readInt(dp)
	local rank = getRank(activityId)
	if rank then
		rankfunc.setRank(rank, actorId, totalConsume, serverId, actorname, job, sex)
	end
end

function onRankDataSync_local(sId, sType, dp)
	local activityId = LDataPack.readInt(dp)
	local actorId = LDataPack.readInt(dp)
	local len = LDataPack.readInt(dp)

	local var = activitysystem.getDyanmicVar(activityId)
	var.rankData = {}

	for i=1,len do
		local t = {}
		t.serverId = LDataPack.readInt(dp)
		t.actorId = LDataPack.readInt(dp)
		t.totalConsume = LDataPack.readInt(dp)
		t.actorname = LDataPack.readString(dp)
		t.rankIndex = LDataPack.readInt(dp)
		t.job = LDataPack.readInt(dp)
		t.sex = LDataPack.readInt(dp)

		table.insert(var.rankData, t)
	end

	local actor = LActor.getActorById(actorId)
	if actor then
		sendRankData(actor, activityId)
	end
end

function getRankList(activityId)
	local list = {}
	local conf = subConfing[activityId]
	if not conf then return list end

	local rank = getRank(activityId)
	local len = Ranking.getRankItemCount(rank)
	local rankTb = Ranking.getRankingItemList(rank, len)
	if not rankTb then return list end

	local typeList = {}
	for _,item in ipairs(rankTb) do
		local totalConsume = Ranking.getPoint(item)
		for _,t in ipairs(conf) do
			local range = t.range[2] - t.range[1] + 1
			typeList[t.index] = typeList[t.index] or 0

			if t.condition <= totalConsume and range > typeList[t.index] then
				local tb = {}
				tb.serverId = Ranking.getSubInt(item, 0)
				tb.actorId = Ranking.getId(item)
				tb.totalConsume = Ranking.getPoint(item)
				tb.actorname = Ranking.getSub(item, 1)
				tb.rankIndex = t.range[1] + typeList[t.index]
				tb.job = Ranking.getSubInt(item, 2)
				tb.sex = Ranking.getSubInt(item, 3)

				typeList[t.index] = typeList[t.index] + 1
				table.insert(list, tb)
				break
			end
		end
	end
	return list
end

function onRankDataRequest_cross(sId, sType, dp)	
	local serverId = LDataPack.readInt(dp)
	local activityId = LDataPack.readInt(dp)
	local actorId = LDataPack.readInt(dp)
	local list = getRankList(activityId)

	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCComsumeCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCComsumeCmd_RankDataSync)

	LDataPack.writeInt(pack, activityId)
	LDataPack.writeInt(pack, actorId)
	LDataPack.writeInt(pack, #list)
	for _,t in ipairs(list) do
		LDataPack.writeInt(pack, t.serverId)
		LDataPack.writeInt(pack, t.actorId)
		LDataPack.writeInt(pack, t.totalConsume)
		LDataPack.writeString(pack, t.actorname)
		LDataPack.writeInt(pack, t.rankIndex)
		LDataPack.writeInt(pack, t.job)
		LDataPack.writeInt(pack, t.sex)
	end
	System.sendPacketToAllGameClient(pack, serverId)	
end

function sendRankData(actor, activityId)
	local actorVar = activitysystem.getSubVar(actor, activityId)
	local totalConsume = actorVar.totalConsume or 0

	local var = activitysystem.getDyanmicVar(activityId)
	var.rankData = var.rankData or {}

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_CSComsumeRank)  
	LDataPack.writeInt(npack, activityId)
	LDataPack.writeInt(npack, #var.rankData)
	for _,t in ipairs(var.rankData) do
		LDataPack.writeInt(npack, t.actorId)
		LDataPack.writeInt(npack, t.totalConsume)
		LDataPack.writeInt(npack, t.rankIndex)
		LDataPack.writeInt(npack, t.serverId)
		LDataPack.writeString(npack, t.actorname)
		LDataPack.writeInt(npack, t.job)
		LDataPack.writeInt(npack, t.sex)
	end
	LDataPack.writeInt(npack, totalConsume)
	LDataPack.flush(npack)
end

function onRoleDataSync_cross(tarActor, serverId, srcActorId)
	local pack = LDataPack.allocPacket()
	if pack == nil then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCComsumeCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCComsumeCmd_RoleDataSync)

	LDataPack.writeInt(pack, srcActorId)
	LDataPack.writeInt(pack, LActor.getActorId(tarActor))

	local count = LActor.getRoleCount(tarActor)
	if roleId < 0 or roleId >= count then
		LDataPack.writeShort(pack, 1)
	else
		LDataPack.writeShort(pack, count)
	end
	local showPack = LActor.getRoleShowPacket(tarActor, roleId)
	LDataPack.writePacket(pack,showPack)
	System.sendPacketToAllGameClient(pack, serverId)
end

function onRoleDataRequest_cross(sId, sType, dp)
	local serverId = LDataPack.readInt(dp)
	local srcActorId = LDataPack.readInt(dp)
	local tarActorId = LDataPack.readInt(dp)
	local roleId = LDataPack.readInt(dp)
	local tarActor = LActor.getActorById(tarActorId)
	if tarActor then
		onRoleDataSync_cross(tarActor, serverId, srcActorId)
	else
		asynevent.reg(tarActorId, onRoleDataSync_cross, serverId, srcActorId)
	end
end

-- function onRoleDataSync_local(sId, sType, dp)
-- 	local srcActorId = LDataPack.readInt(dp)
-- 	local tarActorId = LDataPack.readInt(dp)
-- 	local srcActor = LActor.getActorById(srcActorId)
-- 	if not srcActor then
-- 		return
-- 	end	

-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_CSRoleData)  
-- 	LDataPack.writeInt(npack, tarActorId)
-- 	LDataPack.writePacket(npack,dp)
-- 	LDataPack.flush(npack)	
-- end

-- function sendRoleData(actor, tarActorId, roleId)
-- 	local tarActor = LActor.getActorById(tarActorId)
-- 	if not tarActor then
-- 		return
-- 	end

-- 	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_CSRoleData)  
-- 	LDataPack.writeInt(npack, tarActorId)

-- 	local count = LActor.getRoleCount(tarActor)
-- 	if roleId < 0 or roleId >= count then
-- 		LDataPack.writeShort(npack, 1)
-- 	else
-- 		LDataPack.writeShort(npack, count)
-- 	end
-- 	local showPack = LActor.getRoleShowPacket(tarActor, roleId)
-- 	LDataPack.writePacket(npack,showPack)
-- 	LDataPack.flush(npack)	
-- end

function sendReward(id)
	print("subactivitytype19.sendReward id:"..id)
	local conf = subConfing[id]
	if not conf then return end

	local list = getRankList(id)
	for _,item in pairs(list) do
		for _,t in pairs(conf) do
			if item.rankIndex >= t.range[1] and item.rankIndex <= t.range[2] then
				local mailData = { 
					head=Lang.ScriptTips.cscomsume001, 
					context=string.format(Lang.ScriptTips.cscomsume002, item.rankIndex), 
					tAwardList=t.rewards 
				}
				print("subactivitytype19.sendReward sendMail id:"..id..", aid:"..tostring(item.actorId)..",rank:"..tostring(item.rankIndex)..",sid:"..tostring(item.serverId))
				mailsystem.sendMailById(item.actorId, mailData, item.serverId)
			end
		end
	end
end

_G.CSCumsumeRankNewday = function()
	if System.isCommSrv() then return end
	for id,conf in pairs(subConfing) do
		if activitysystem.getStatByTime(id) == commActivityStat.casEnd then 
			local var = activitysystem.getActivityStaticVar(id)
			if var.awardFlag == nil then
				var.awardFlag = 1
				sendReward(id)
			else
				print("subactivitytype19.CSCumsumeRankNewday var.awardFlag is not nil id:"..id)
			end
		else
			print("subactivitytype19.CSCumsumeRankNewday activity is not casEnd id:"..id)
		end
	end
end

-- 活动初始化
local function init(id, conf)
	actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao(id, conf))
end

function rankData_c2s(actor, packet)
	local activityId = LDataPack.readInt(packet)

	if not System.isCommSrv() then return end
	if not subConfing[activityId] then return end
	if activitysystem.activityTimeIsEnd(activityId) then return end

	local curTime = System.getNowTime()
	local var = activitysystem.getDyanmicVar(activityId)
	if curTime - (var.updateTime or 0) > 60 then
		var.updateTime = curTime

		local pack = LDataPack.allocPacket()
		if pack == nil then return end
		LDataPack.writeByte(pack, CrossSrvCmd.SCComsumeCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCComsumeCmd_RankDataRequest)
		LDataPack.writeInt(pack, System.getServerId())
		LDataPack.writeInt(pack, activityId)
		LDataPack.writeInt(pack, LActor.getActorId(actor))
		System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsBattleSrv))	
		return	
	end

	sendRankData(actor, activityId)
end

-- function roleData_c2s(actor, packet)
-- 	local tarActorId = LDataPack.readInt(packet)
-- 	local roleId = LDataPack.readShort(packet)
-- 	local tarActor = LActor.getActorById(tarActorId)
-- 	if tarActor then
-- 		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_CSRoleData)  
-- 		LDataPack.writeInt(npack, tarActorId)

-- 		local count = LActor.getRoleCount(tarActor)
-- 		if roleId < 0 or roleId >= count then
-- 			LDataPack.writeShort(npack, 1)
-- 		else
-- 			LDataPack.writeShort(npack, count)
-- 		end
-- 		local showPack = LActor.getRoleShowPacket(tarActor, roleId)
-- 		LDataPack.writePacket(npack,showPack)
-- 		LDataPack.flush(npack)	
-- 		return
-- 	end

-- 	local pack = LDataPack.allocPacket()
-- 	if pack == nil then return end
-- 	LDataPack.writeByte(pack, CrossSrvCmd.SCComsumeCmd)
-- 	LDataPack.writeByte(pack, CrossSrvSubCmd.SCComsumeCmd_RoleDataRequest)
-- 	LDataPack.writeInt(pack, System.getServerId())
-- 	LDataPack.writeInt(pack, LActor.getActorId(actor))
-- 	LDataPack.writeInt(pack, tarActorId)
-- 	LDataPack.writeInt(pack, roleId)
-- 	System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsBattleSrv))
-- end

subactivities.regConf(subType, subConfing)
subactivities.regInitFunc(subType, init)

csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_UpdateRankInfo, onUpdateRank_cross)
csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_RankDataRequest, onRankDataRequest_cross)
csmsgdispatcher.Reg(CrossSrvCmd.SCComsumeCmd, CrossSrvSubCmd.SCComsumeCmd_RankDataSync, onRankDataSync_local)

netmsgdispatcher.reg(Protocol.CMD_Activity, Protocol.cActivityCmd_CSComsumeRank, rankData_c2s)

