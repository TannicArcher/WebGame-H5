--巅峰赛季跨服的数据传输与缓存服务(游戏服)
module("peakracecrossdata", package.seeall)
PeakRaceCrossData = PeakRaceCrossData or {}
--[[游戏服缓存数据
	curStatus = 当前处于什么状态
	okStatus[状态]=是否OK
	winAid = 冠军ID
	secAid = 亚军ID
]]
function getData()
	return PeakRaceCrossData
end
local baseCfg = PeakRaceBase
local Status = peakracecrosssystem.Status
--跨服的状态变更
local function onCrossStatusChange(sId, sType, dp)
	local data = getData()
	data.curStatus = LDataPack.readChar(dp)
	if not data.okStatus then data.okStatus = {} end
	data.okStatus[data.curStatus] = LDataPack.readInt(dp)
	data.winAid = LDataPack.readInt(dp)
	data.secAid = LDataPack.readInt(dp)
	print("peakracecrossdata.onCrossStatusChange st:"..data.curStatus..",isok:"..data.okStatus[data.curStatus])
	peakracesystem.sendAllStatusChange()
end

--跨服回来的消息直接到客户端
local function SendPacketToClient(aid, cmdid, dp)
	print("peakracecrossdata.SendPacketToClient,cmdid:"..cmdid..",aid:"..aid)
	local actor = LActor.getActorById(aid)
	if actor then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, cmdid)
		LDataPack.writePacket(npack,dp,false)
		LDataPack.flush(npack)
	end
end

local function getToGameAllocPacket(aid)
	local pack = LDataPack.allocPacket()
	if pack then
		LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_DataTunnel)
		LDataPack.writeInt(pack, aid)
	end
	return pack
end

--跨服收到游戏服转来请求淘汰赛战报的消息处理
local function GetCrossKKinfo(sId, aid, dp)
	print(aid.." peakracecrossdata.GetCrossKKinfo")
	local svar = peakracecrosssystem.getSysData()
	local sinfo = svar.SignUpActor and svar.SignUpActor[aid] or nil
	if not sinfo then
		print(aid.." peakracecrossdata.GetCrossKKinfo is not SignUpActor info")
		return
	end
	local pack = getToGameAllocPacket(aid)
	if pack then
		LDataPack.writeByte(pack, Protocol.sPeakRace_SendCrossKKinfo) --消息号
		--写数据部分
		LDataPack.writeShort(pack, svar.KnockOutTimes or 0)
		LDataPack.writeInt(pack, svar.KnockOutNextTime or 0)
		LDataPack.writeShort(pack, svar.KnockOutLeftNum or 0)
		local record = sinfo.KnockOutRec or {}
		LDataPack.writeShort(pack, #record)
		print(aid.." peakracecrossdata.GetCrossKKinfo record size:"..(#record))
		for _,info in ipairs(record) do
			LDataPack.writeInt(pack, info.aid or 0)
			LDataPack.writeString(pack, info.name or "")
			LDataPack.writeInt(pack, peakracecrosssystem.getActorSid(info.aid))
			LDataPack.writeChar(pack, info.result)
		end
		--发包
		System.sendPacketToAllGameClient(pack, sId)
	end
end

local function writeStatusData(svar, st, npack)
	local promData = svar.Prom and svar.Prom[st] or {}
	local promWin = svar.PromWin and svar.PromWin[st] or {}
	local promWinStep = svar.PromWinStep and svar.PromWinStep[st] or {}
	local count = 0
	local pos1 = LDataPack.getPosition(npack)
	LDataPack.writeChar(npack, count)
	for idx,_ in ipairs(promData) do
		LDataPack.writeInt(npack, promWin[idx] or 0)
		count = count + 1
		local stepInfo =  promWinStep[idx] or {}
		LDataPack.writeChar(npack, #stepInfo)
		for _,aid in ipairs(stepInfo) do
			LDataPack.writeInt(npack, aid)
		end
	end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos1)
	LDataPack.writeChar(npack, count)
	LDataPack.setPosition(npack, pos2)
end

--跨服收到游戏服转来请求晋级赛数据的消息处理
local function GetCorssPromInfo(sId, aid, dp)
	print("peakracecrossdata.GetCorssPromInfo, aid:"..aid)
	local npack = getToGameAllocPacket(aid)
	if npack then
		LDataPack.writeByte(npack, Protocol.sPeakRace_SendCorssPromInfo) --消息号
		local svar = peakracecrosssystem.getSysData()
		local prom64Data = svar.Prom and svar.Prom[Status.Prom64] or {}
		local prom64Win = svar.PromWin and svar.PromWin[Status.Prom64] or {}
		local prom64WinStep = svar.PromWinStep and svar.PromWinStep[Status.Prom64] or {}
		LDataPack.writeChar(npack, #prom64Data)
		for idx,info in ipairs(prom64Data) do
			local count = 0
			local pos1 = LDataPack.getPosition(npack)
			LDataPack.writeChar(npack, count)
			for aid,_ in pairs(info) do
				local ainfo = peakracecrosssystem.getActorInfo(aid)
				LDataPack.writeInt(npack, aid)
				LDataPack.writeInt(npack, ainfo and ainfo.sid or 0)
				LDataPack.writeString(npack, ainfo and ainfo.name or "")
				LDataPack.writeChar(npack, ainfo and ainfo.job or 0)
				LDataPack.writeChar(npack, ainfo and ainfo.sex or 0)
				LDataPack.writeChar(npack, ainfo and ainfo.toSubIdx or 0)
				count = count + 1
			end
			local pos2 = LDataPack.getPosition(npack)
			LDataPack.setPosition(npack, pos1)
			LDataPack.writeChar(npack, count)
			LDataPack.setPosition(npack, pos2)
			--下发赢的人
			LDataPack.writeInt(npack, prom64Win[idx] or 0)
			local stepInfo =  prom64WinStep[idx] or {}
			LDataPack.writeChar(npack, #stepInfo)
			for _,aid in ipairs(stepInfo) do
				LDataPack.writeInt(npack, aid)
			end
		end
		--32强赢的人
		writeStatusData(svar, Status.Prom32, npack)
		--16强赢的人
		writeStatusData(svar, Status.Prom16, npack)
		--8强赢的人
		writeStatusData(svar, Status.Prom8, npack)
		--4强赢的人
		writeStatusData(svar, Status.Prom4, npack)
		--冠军
		local waid = svar.PromWin and svar.PromWin[Status.Finals] and svar.PromWin[Status.Finals][1] or 0
		LDataPack.writeInt(npack, waid)
		local stepInfo = svar.PromWinStep and svar.PromWinStep[Status.Finals] and svar.PromWinStep[Status.Finals][1] or {}
		LDataPack.writeChar(npack, #stepInfo)
		for _,aid in ipairs(stepInfo) do
			LDataPack.writeInt(npack, aid)
		end
		--发包
		print("peakracecrossdata.GetCorssPromInfo sendPacketToAllGameClient, aid:"..aid..",sId:"..sId)
		System.sendPacketToAllGameClient(npack, sId)
	end
end

local function ReqCrossRankData(sId, aid, dp)
	local npack = getToGameAllocPacket(aid)
	if npack then
		LDataPack.writeByte(npack, Protocol.sPeakRace_SendCrossRankData) --消息号
		peakracerank.reqRankData(npack)
		--发包
		System.sendPacketToAllGameClient(npack, sId)
	end	
end

local function ReqCrossLike(sId, aid, dp)
	local aid = LDataPack.readInt(dp)
	if not peakracerank.updatePoint(aid) then
		print(LActor.getActorId(actor).." peakracecrossdata.ReqCrossLike updatePoint error")
		return
	end
	--给玩家返回最新的排行榜
	ReqCrossRankData(sId, aid, nil)
end

--给指定服的玩家下发他的下注信息
local function ReqCrossBettInfo(sId, aid)
	local svar = peakracecrosssystem.getSysData()
	local info = svar.bett and svar.bett[aid]
	if not info then return end --没有下注过就不发了
	local npack = getToGameAllocPacket(aid)
	if npack then
		LDataPack.writeByte(npack, Protocol.sPeakRace_SendCrossBettInfo) --消息号
		local count = 0
		local pos1 = LDataPack.getPosition(npack)
		LDataPack.writeChar(npack, count)
		for st,v in pairs(info) do
			LDataPack.writeChar(npack, st)
			LDataPack.writeInt(npack, v.aid)
			LDataPack.writeInt(npack, v.num)
			count = count + 1
		end
		local pos2 = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos1)
		LDataPack.writeChar(npack, count)
		LDataPack.setPosition(npack, pos2)
		--发包
		System.sendPacketToAllGameClient(npack, sId)
	end	
end

local function sendCrossBeetErr(sId, aid, count)
	local pack = LDataPack.allocPacket()
	if pack then
		LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_BeetErr)
		LDataPack.writeInt(pack, aid)
		LDataPack.writeInt(pack, count)
		--发包
		System.sendPacketToAllGameClient(pack, sId)
	end	
end

local function ReqCrossBett(sId, aid, dp)
	local baid = LDataPack.readInt(dp)
	local count = LDataPack.readInt(dp)
	--获取当前能下注的状态
	local cst = peakracecrosssystem.getCanBettStatus()
	if not cst then
		print(aid.." peakracecrosssystem.reqBett is not in bett status baid:"..baid)
		sendCrossBeetErr(sId, aid, count)
		return
	end
	local svar = peakracecrosssystem.getSysData()
	--判断是否已经下注过了
	if svar.bett and svar.bett[aid] and svar.bett[aid][cst] then
		print(aid.." peakracecrosssystem.reqBett is on bett cst:"..cst)
		sendCrossBeetErr(sId, aid, count)
		return
	end
	local ainfo = svar.SignUpActor[baid]
	if not ainfo then
		print(aid.." peakracecrosssystem.reqBett is ont ainfo baid:"..baid)
		sendCrossBeetErr(sId, aid, count)
		return
	end
	--判断这个人是否轮空
	local pinfo = svar.Prom and svar.Prom[ainfo.toStatus] and svar.Prom[ainfo.toStatus][ainfo.toIdx]
	if not pinfo then
		print(aid.." peakracecrosssystem.reqBett is not pinfo st:"..tostring(ainfo.toStatus)..", idx:"..tostring(ainfo.toIdx))
		sendCrossBeetErr(sId, aid, count)
		return
	end
	local cp = 0
	for _,_ in pairs(pinfo) do
		cp = cp + 1
	end
	if cp <= 1 then
		print(aid.." peakracesystem.reqBett pinfo is ones count:"..cp)
		sendCrossBeetErr(sId, aid, count)
		return
	end
	--记录下注信息
	if not ainfo.bettAids then ainfo.bettAids = {} end
	if not ainfo.bettAids[cst] then ainfo.bettAids[cst] = {} end
	table.insert(ainfo.bettAids[cst], {aid=aid,sid=sId})
	if not svar.bett then svar.bett = {} end
	if not svar.bett[aid] then svar.bett[aid] = {} end
	svar.bett[aid][cst] = {aid=baid,num=count}
	--回应最新的下注信息
	ReqCrossBettInfo(sId, aid)
end

local function onDataChangeRecv(sId, sType, dp)
	local aid = LDataPack.readInt(dp)
	local cmdid = LDataPack.readByte(dp)
	if not System.isCommSrv() then --跨服接受这里的数据
		print("peakracecrossdata.onDataChangeRecv,cmdid:"..cmdid)
		if cmdid == Protocol.cPeakRace_GetCrossKKinfo then
			GetCrossKKinfo(sId, aid, dp)
		elseif cmdid == Protocol.cPeakRace_GetCorssPromInfo then
			GetCorssPromInfo(sId, aid, dp)
		elseif cmdid == Protocol.cPeakRace_ReqCrossRankData then
			ReqCrossRankData(sId, aid, dp)
		elseif cmdid == Protocol.cPeakRace_ReqCrossLike then
			ReqCrossLike(sId, aid, dp)
		elseif cmdid == Protocol.cPeakRace_ReqCrossBett then
			ReqCrossBett(sId, aid, dp)
		elseif cmdid == Protocol.cPeakRace_ReqCrossBettInfo then
			ReqCrossBettInfo(sId, aid)
		end
	else --游戏服接受这里的数据
		SendPacketToClient(aid, cmdid, dp)
	end
end

local function onBeetErr(sId, sType, dp)
	local aid = LDataPack.readInt(dp)
	local count = LDataPack.readInt(dp)
	local actor = LActor.getActorById(aid)
	if actor then
		--补回筹码
		LActor.changeCurrency(actor, NumericType_Chips, count, "crossbeeterr")
	end
end

local function SendPackToCrossDataChange(actor, cmdid, packet)
	--把客户端的包发到跨服
	local pack = LDataPack.allocPacket()
	if pack then
		LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_DataTunnel)
		LDataPack.writeInt(pack, LActor.getActorId(actor))
		LDataPack.writeByte(pack, cmdid)
		LDataPack.writePacket(pack,packet,false)
		print("peakracecrossdata.SendPackToCrossDataChange,cmdid:"..cmdid)
		System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsBattleSrv))
	end
end

--获取现在能下注的状态[只能在游戏服调用跨服的状态]
function getCanBettStatus()
	local svar = getData()
	local st = svar.curStatus
	if not st then return nil end
	--淘汰赛之前,决赛开始之后
	if st < Status.Knockout or st >= Status.Finals then return nil end
	--这个状态结束了;
	if svar.okStatus[st] ~= 0 then
		return st+1 --下一个状态是可以开始下注了
	end
	return nil
end

local function onLogin(actor)
	local aid = LActor.getActorId(actor)
	local data = getData()
	if aid == data.winAid then
		--冠军上线
		if baseCfg.crossWinNoticeId then
			noticemanager.broadCastNoticeToAllSrv(baseCfg.crossWinNoticeId, LActor.getName(actor), System.getServerId())
		end
	elseif aid == data.secAid then
		--亚军上线
		if baseCfg.crossSecNoticeId then
			noticemanager.broadCastNoticeToAllSrv(baseCfg.crossSecNoticeId, LActor.getName(actor), System.getServerId())
		end
	end
end

--初始化全局数据
local function initGlobalData()
	--游戏服处理跨服服来的消息处理
	csmsgdispatcher.Reg(CrossSrvCmd.SCPeakRaceCmd, CrossSrvSubCmd.SCPeakRaceCmd_StatusChange, onCrossStatusChange)

	--游戏服处理客户端消息
	if System.isCommSrv() then
		actorevent.reg(aeUserLogin, onLogin)
		netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_GetCrossKKinfo, function(actor, packet)
			SendPackToCrossDataChange(actor, Protocol.cPeakRace_GetCrossKKinfo, packet)
		end) --淘汰赛战报
		netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_GetCorssPromInfo, function(actor, packet)
			SendPackToCrossDataChange(actor, Protocol.cPeakRace_GetCorssPromInfo, packet)
		end)--请求晋级赛信息
		netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqCrossRankData, function(actor, packet)
			SendPackToCrossDataChange(actor, Protocol.cPeakRace_ReqCrossRankData, packet)
		end) --请求排行榜数据
		netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqCrossLike, function(actor, packet)
			--判断当前状态是否能够点赞
			local svar = getData()
			--是否已经决赛结束了
			if svar.okStatus and svar.okStatus[Status.Finals] and svar.okStatus[Status.Finals] ~= 0 then 
				local now_t = System.getNowTime()
				if svar.okStatus[Status.Finals] < now_t and 
					not System.isSameDay(svar.okStatus[Status.Finals], now_t) then 
					print(LActor.getActorId(actor).." peakracecrossdata.reqLike is Finals ok")
					return 
				end
			end

			local var = peakracesystem.getStaticData(actor)
			--判断这个玩家还有没有次数
			if (var.likeCount or 0) >= PeakRaceBase.likeCount then
				print(LActor.getActorId(actor).." peakracecrossdata.reqLike likeCount is max")
				return
			end
			--增加点赞次数
			var.likeCount = (var.likeCount or 0) + 1
			--增加筹码
			LActor.changeCurrency(actor, NumericType_Chips, PeakRaceBase.likeChips, "reqcrosslike")
			--发送到跨服增加点赞数
			SendPackToCrossDataChange(actor, Protocol.cPeakRace_ReqCrossLike, packet)
			peakracesystem.sendSignUpData(actor)
		end) --请求排行榜点赞
		netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqCrossBett, function(actor, packet)
			local pos = LDataPack.getPosition(packet)
			local baid = LDataPack.readInt(packet)
			local count = LDataPack.readInt(packet)
			local maid = LActor.getActorId(actor)
			print(maid.." peakracecrossdata.reqBett to baid:"..baid)
			local cst = getCanBettStatus()
			if not cst then
				print(maid.." peakracecrossdata.reqBett is not in bett status")
				return
			end
			count = math.min(count, PeakRaceCrossTime[cst].maxBett or 0)
			if count <= 0 then
				print(maid.." peakracesystem.reqBett count is glt 0")
				return
			end
			--判断是否足够的筹码
			local chipsCount = peakracesystem.getChips(actor)
			if chipsCount < count then
				print(maid.." peakracecrossdata.reqBett is not have chips,chipsCount:"..chipsCount..",count:"..count)
				return
			end
			LActor.changeCurrency(actor, NumericType_Chips, -count, "reqcrossBett") --扣除筹码
			LDataPack.setPosition(packet, pos)
			LDataPack.writeInt(packet, baid)
			LDataPack.writeInt(packet, count)
			LDataPack.setPosition(packet, pos)
			--发包给跨服
			SendPackToCrossDataChange(actor, Protocol.cPeakRace_ReqCrossBett, packet)
		end) --请求下注
		netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqCrossBettInfo, function(actor, packet)
			SendPackToCrossDataChange(actor, Protocol.cPeakRace_ReqCrossBettInfo, packet)
		end) --请求我的下注信息
	end

	--跨服和游戏服之间的数据通道
	csmsgdispatcher.Reg(CrossSrvCmd.SCPeakRaceCmd, CrossSrvSubCmd.SCPeakRaceCmd_DataTunnel, onDataChangeRecv)
	csmsgdispatcher.Reg(CrossSrvCmd.SCPeakRaceCmd, CrossSrvSubCmd.SCPeakRaceCmd_BeetErr, onBeetErr)
end

table.insert(InitFnTable, initGlobalData)
