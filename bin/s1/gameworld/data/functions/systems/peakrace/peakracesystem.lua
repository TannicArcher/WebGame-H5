--巅峰赛季(游戏服)
module("peakracesystem", package.seeall)
local Status = {
	None = 0, --未开始状态
	SignUp = 1, --报名开始状态
	Knockout = 2, --淘汰赛状态
	Prom16 = 3, --16强晋级赛
	Prom8 = 4, --8强晋级赛
	Prom4 = 5, --4强晋级赛
	Finals = 6, --决赛
}
local baseCfg = PeakRaceBase
local TimeCfg = PeakRaceTime
--全局临时Eid储存
EidTable = EidTable or {}
local function isOpenSer()
	return System.getOpenServerDay() >= (baseCfg.openDay or 0)
end
local function getNst(st)
	if st == Status.Finals then
		return nil
	end
	return st+1
end
--[[系统静态变量
	GlobalStartTime = 全局开始时间戳
	curStartTime = 本次的开始时间
	curStatus = 当前处于什么状态
	okStatus[状态]=时间
	KnockOutTimes = 当前淘汰赛第几轮
	KnockOutNextTime = 下一轮淘汰赛开始时间
	KnockOutLeftNum = 淘汰赛剩余人数
	SignUpActor[玩家ID] = {
		loseNum = 0 --报名海选玩家输了多少次
		KnockOutRec = { --淘汰赛输赢记录
			{aid=对方玩家ID,name=对方名字,result=结果,1胜0负}
		}
		toStatus = 晋级到了什么状态
		toIdx = 所在索引
		bettAids[状态]={玩家ID}--下注了的玩家
		toSubIdx = 上面还是下面,0上,1下
	}
	bett[下注的玩家ID]={--下注信息
		[状态]={
			aid = 给谁下了注
			num = 下了多少筹码
		}
	}
	Prom[状态]={
		[索引] = { --pinfo
			[玩家ID] = 赢了多少次
			[玩家ID] = 赢了多少次
		}
	}
	PromWinStep[状态]={
		[索引]={赢的id,赢的id}
	}
	PromWin[状态] = {
		[索引] = 胜出AID
	}
]]
local function getSysData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.peakrace == nil then 
		var.peakrace = {}
	end
	return var.peakrace
end

--[[获取玩家静态变量
	likeCount = 已经点赞次数
	chipsCount = 筹码数量
	mobaiCount = 已经膜拜次数
]]
function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.peakracesys then var.peakracesys = {} end
    return var.peakracesys
end

--清空数据
local function clearSysData()
	local svar = getSysData()
	svar.okStatus = nil
	svar.SignUpActor = nil
	svar.Prom = nil
	svar.PromWinStep = nil
	svar.PromWin = nil
	svar.KnockOutTimes = nil
	svar.KnockOutNextTime = nil
	svar.KnockOutLeftNum = nil
	svar.bett = nil
	--清空排行榜
	peakracerank.resetRankingList()
end

local function setAidToSt(aid, nst, idx, subidx)
	local svar = getSysData()
	if not svar.SignUpActor then return end
	if not svar.SignUpActor[aid] then return end
	svar.SignUpActor[aid].toStatus = nst
	svar.SignUpActor[aid].toIdx = idx
	if subidx then
		svar.SignUpActor[aid].toSubIdx = subidx
	end
end

local function getSubIndex(aid)
	local svar = getSysData()
	if not svar.SignUpActor then return 0 end
	if not svar.SignUpActor[aid] then return 0 end
	return svar.SignUpActor[aid].toSubIdx or 0
end

--获取全局开始时间
local function getOpenTime()
    local Y,M,d,h,m = string.match(baseCfg.openTime, "(%d+)%.(%d+)%.(%d+)")
    if Y == nil or M == nil or d == nil then
        return nil
    end
    return System.timeEncode(Y, M, d, 0, 0, 0)
end

--下发状态变更给客户端
function sendAllStatusChange(actor)
	local npack = nil
	if actor then
		npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendCurStatus)
	else
		npack = LDataPack.allocBroadcastPacket(Protocol.CMD_PeakRace, Protocol.sPeakRace_SendCurStatus)
	end
	if not npack then return end
	local svar = getSysData()
	LDataPack.writeChar(npack, svar.curStatus or 0)
	LDataPack.writeChar(npack, svar.okStatus and svar.okStatus[svar.curStatus] and 1 or 0)
	local csdata = peakracecrossdata.getData()
	LDataPack.writeChar(npack, csdata.curStatus or 0)
	LDataPack.writeChar(npack, csdata.okStatus and csdata.okStatus[csdata.curStatus] and (csdata.okStatus[csdata.curStatus] > 0) and 1 or 0)
	local st = svar.curStatus or 0
	local sto = svar.okStatus and svar.okStatus[svar.curStatus] and 1 or 0
	local cst = csdata.curStatus or 0
	local csto = csdata.okStatus and csdata.okStatus[csdata.curStatus] or 0
	print("peakracesystem.sendAllStatusChange st:"..st..",sto:"..sto..",cst:"..cst..",csto:"..csto)
	if actor then
		LDataPack.flush(npack)
	else
		System.broadcastData(npack)
	end	
end

--检测淘汰赛结束
local function checkKnockoutOver()
	print("peakracesystem.checkKnockoutOver start")
	--把所有人分配到16强数组
	local st = getNst(Status.Knockout)
	local svar = getSysData()
	--已经海选结束了
	if svar.okStatus and svar.okStatus[Status.Knockout] then return end
	if not svar.SignUpActor then 
		print("peakracesystem.checkKnockoutOver not SignUpActor")
		return
	end
	local allAid = {}
	for aid,info in pairs(svar.SignUpActor) do
		if info.loseNum < baseCfg.signUpLose then --配置的海选淘汰次数
			table.insert(allAid, aid)
		end
	end

	svar.KnockOutLeftNum = #allAid --更新剩余人数
	if #allAid <= 0 then
		print("peakracesystem.checkKnockoutOver #allAid <= 0")
		return
	end
	if #allAid > baseCfg.promCount then
		return
	end
	--把16强的人发到跨服服去
	local pack = LDataPack.allocPacket()
	if pack then
		print("peakracesystem.checkKnockoutOver send to cross server")
		LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_SendProm16)
		LDataPack.writeChar(pack, #allAid)
		for _,aid in ipairs(allAid) do
			LDataPack.writeInt(pack, aid)
			LDataPack.writeString(pack, LActor.getActorName(aid))
			LDataPack.writeChar(pack, LActor.getActorJob(aid))
			LDataPack.writeChar(pack, LActor.getActorSex(aid))
		end
		System.sendPacketToAllGameClient(pack, csbase.GetBattleSvrId(bsBattleSrv))
	end
	--发产生16强公告
	if baseCfg.KnockOutNoticeId then
		for _,aid in ipairs(allAid) do
			noticemanager.broadCastNotice(baseCfg.KnockOutNoticeId, LActor.getActorName(aid))
		end
	end
	--继续匹配晋级赛
	svar.PromWinStep = {}
	svar.Prom = {}
	svar.Prom[st] = {}
	svar.PromWin = {}
	svar.PromWin[st] = {}
	local pr = svar.Prom[st]
	local gnum = math.ceil(baseCfg.promCount/2)
	local pr_num = {}
	for i=1,gnum do
		table.insert(pr,{})
		--临时存着一个随机的位置
		table.insert(pr_num, {i=i,p=0})
		table.insert(pr_num, {i=i,p=1})
	end
	while #allAid > 0 do
		local aid = table.remove(allAid, System.rand(#allAid)+1)
		--添加到点赞排行榜
		peakracerank.addToRank(aid, LActor.getActorName(aid), System.getServerId())
		--随机出位置
		local pos = table.remove(pr_num, System.rand(#pr_num)+1)
		pr[pos.i][aid] = 0 --设置到pinfo
		setAidToSt(aid, st, pos.i, pos.p)
	end
	if not svar.okStatus then svar.okStatus = {} end
	svar.okStatus[Status.Knockout] = System.getNowTime()
	sendAllStatusChange(nil)
	if EidTable[Status.Knockout] then
		LActor.cancelScriptEvent(nil, EidTable[Status.Knockout])
		EidTable[Status.Knockout] = nil
	end
	print("peakracesystem.checkKnockoutOver ok")
end

--发放出局邮件
local function sendLoseMail(st, loseAid)
	local cfg = PeakRaceTime[st]
	if not cfg then return end
	if cfg.loseMail then
		mailcommon.sendMailById(loseAid, cfg.loseMail)
	end
end

--发放赌注邮件
local function sendBettMail(st, winAid, loseAid)
	local cfg = PeakRaceTime[st]
	if not cfg then return end
	local winName = LActor.getActorName(winAid)
	local loseName = LActor.getActorName(loseAid)
	local svar = getSysData()
	--赌赢的人
	if cfg.bettWinMail then
		local ainfo = svar.SignUpActor and svar.SignUpActor[winAid]
		local aids = ainfo and ainfo.bettAids and ainfo.bettAids[st]
		for _,aid in ipairs(aids or {}) do
			local bettInfo = svar.bett and svar.bett[aid] and svar.bett[aid][st]
			if bettInfo then
				if bettInfo.aid == winAid then
					local mailInfo = mailcommon.getConfigByMailId(cfg.bettWinMail)
					if mailInfo then
						local rcount = bettInfo.num * 2
						local tMailData = {}
						tMailData.head = mailInfo.title
						tMailData.context = string.format(mailInfo.content, winName, loseName, rcount)
						tMailData.tAwardList = {{type=0,id=NumericType_Chips,count=rcount}}
						mailsystem.sendMailById(aid, tMailData)
					end
				else
					print(aid.." peakracesystem.sendBettMail not have bettInfo.aid("..bettInfo.aid..") ~= winAid:"..winAid)
				end
			else
				print(aid.." peakracesystem.sendBettMail not have bettInfo winAid:"..winAid)
			end
		end
	end
	--赌输了的人
	if cfg.bettLoseMail then
		local ainfo = svar.SignUpActor and svar.SignUpActor[loseAid]
		local aids = ainfo and ainfo.bettAids and ainfo.bettAids[st]
		for _,aid in ipairs(aids or {}) do
			local bettInfo = svar.bett and svar.bett[aid] and svar.bett[aid][st]
			if bettInfo then
				if bettInfo.aid == loseAid then
					local mailInfo = mailcommon.getConfigByMailId(cfg.bettLoseMail)
					if mailInfo then
						--local rcount = bettInfo.num * 2
						local tMailData = {}
						tMailData.head = mailInfo.title
						tMailData.context = string.format(mailInfo.content, winName, loseName, bettInfo.num)
						--tMailData.tAwardList = {type=0,id=NumericType_Chips,count=rcount}
						mailsystem.sendMailById(aid, tMailData)
					end
				else
					print(aid.." peakracesystem.sendBettMail not have bettInfo.aid("..bettInfo.aid..") ~= loseAid:"..loseAid)
				end
			else
				print(aid.." peakracesystem.sendBettMail not have bettInfo loseAid:"..loseAid)
			end
		end		
	end
end

--海选淘汰赛副本结束的时候
local function onSignUpFbEnd(data, winAid, loseAid)
	print("peakracesystem.onSignUpFbEnd, winAid:"..winAid..", loseAid:"..loseAid)
	local svar = getSysData()
	--已经海选结束了
	if svar.okStatus and svar.okStatus[Status.Knockout] then return end
	local stime = svar.curStartTime + PeakRaceTime[Status.Knockout].relTime
	local now_t = System.getNowTime()
	if now_t < stime then
		print("peakracesystem.onSignUpFbEnd status is not on Knockout")
		return
	end
	if not svar.SignUpActor then
		print("peakracesystem.onSignUpFbEnd not SignUpActor")
		return
	end
	if not svar.SignUpActor[loseAid] then
		print("peakracesystem.onSignUpFbEnd not SignUpActor["..loseAid.."]")
		return
	end
	--记录输的人的信息
	local lsinfo = svar.SignUpActor[loseAid]
	lsinfo.loseNum = (lsinfo.loseNum or 0) + 1
	if not lsinfo.KnockOutRec then lsinfo.KnockOutRec = {} end
	table.insert(lsinfo.KnockOutRec, {aid=winAid,name=LActor.getActorName(winAid),result=0})
	--记录赢的人的信息
	local wsinfo = svar.SignUpActor[winAid]
	if not wsinfo.KnockOutRec then wsinfo.KnockOutRec = {} end
	table.insert(wsinfo.KnockOutRec, {aid=loseAid,name=LActor.getActorName(loseAid),result=1})
	--发放出局邮件
	if lsinfo.loseNum >= baseCfg.signUpLose then
		sendLoseMail(Status.Knockout, loseAid)
	end
	--检测一下淘汰赛是否提前结束了
	checkKnockoutOver()
end

--海选匹配一次
local function AllSignUpPk()
	local svar = getSysData()
	EidTable[Status.Knockout] = nil
	--已经海选结束了
	if svar.okStatus and svar.okStatus[Status.Knockout] then return end
	local stime = svar.curStartTime + PeakRaceTime[Status.Knockout].relTime
	local now_t = System.getNowTime()
	if now_t < stime then
		print("peakracesystem.AllSignUpPk status is not on Knockout")
		return
	end
	if not svar.SignUpActor then 
		print("peakracesystem.AllSignUpPk not SignUpActor")
		return 
	end
	local count = 0
	local allAid = {}
	for aid,info in pairs(svar.SignUpActor) do
		if info.loseNum < baseCfg.signUpLose then --配置的海选淘汰次数
			table.insert(allAid, aid)
		end
		count = count + 1
	end
	if count < baseCfg.needPlayer then
		print("peakracesystem.AllSignUpPk not have needPlayer")
		return
	end
	svar.KnockOutLeftNum = #allAid --更新剩余人数
	if #allAid <= baseCfg.promCount then --配置的晋级赛人数
		return true
	end
	svar.KnockOutTimes = (svar.KnockOutTimes or 0) + 1 --第几轮
	--随机两个人出来打
	while #allAid > 1 do
		local aid1 = table.remove(allAid, System.rand(#allAid)+1)
		local aid2 = table.remove(allAid, System.rand(#allAid)+1)
		--创建一个副本
		print("peakracesystem.AllSignUpPk create fuben aid1:"..aid1..",aid2:"..aid2)
		local data = {}
		peakracefb.create(aid1, aid2, onSignUpFbEnd, data)
	end
	--落单的那个人的战报
	if #allAid > 0 then
		local laid = allAid[1]
		local lainfo = svar.SignUpActor[laid]
		if lainfo then
			if not lainfo.KnockOutRec then lainfo.KnockOutRec = {} end
			table.insert(lainfo.KnockOutRec, {result=1})
		end
	end
	svar.KnockOutNextTime = System.getNowTime() + baseCfg.KnockOutTime --下一轮的开始时间
	EidTable[Status.Knockout] = LActor.postScriptEventLite(nil, baseCfg.KnockOutTime * 1000, AllSignUpPk) --注册下一次匹配时间
	return true
end

--晋级赛结束检测
local function checkPromPkOver(st)
	local svar = getSysData()
	--已经检测过结束了
	if svar.okStatus and svar.okStatus[st] then return end
	if not svar.Prom or not svar.Prom[st] then
		print("peakracesystem.checkPromPkOver not svar.Prom st:"..st)
		return
	end
	print("peakracesystem.checkPromPkOver start")
	if not svar.PromWin then svar.PromWin = {} end
	if not svar.PromWin[st] then svar.PromWin[st] = {} end
	local promData = svar.Prom[st]
	local promWinData = svar.PromWin[st]
    --所有人都决出赢了
    local gnum = table.getnEx(promWinData)
	if gnum >= table.getnEx(promData) then
		print("peakracesystem.checkPromPkOver is ok all st:"..st)
		--生成下一个阶段的数据
		local nst = getNst(st)
		if nst then
			if not svar.Prom then svar.Prom = {} end
			if not svar.Prom[nst] then svar.Prom[nst] = {} end
			if not svar.PromWin then svar.PromWin = {} end
			if not svar.PromWin[nst] then svar.PromWin[nst] = {} end
			local pr = svar.Prom[nst]
			local pos = 1
			for i=1,gnum,2 do
				local prinfo = {}
				local aid1 = promWinData[i]
				local aid2 = promWinData[i+1]
				if aid1 and aid1 ~= 0 then
					setAidToSt(aid1, nst, pos)
					prinfo[aid1] = 0 
				end
				print("peakracesystem.checkPromPkOver i:"..i..",nst:"..nst..",pos:"..pos..",aid1:"..tostring(aid1))
				if aid2 and aid2 ~= 0 then
					setAidToSt(aid2, nst, pos)
					prinfo[aid2] = 0
				end
				print("peakracesystem.checkPromPkOver i:"..(i+1)..",nst:"..nst..",pos:"..pos..",aid2:"..tostring(aid2))
				table.insert(pr,prinfo)
				pos = pos + 1
			end
			print("peakracesystem.checkPromPkOver is over st:"..st..",nst:"..nst)
		elseif st == Status.Finals then--决赛结束了
			print("peakracesystem.checkPromPkOver is over Status.Finals st:"..st)
			local winAid = svar.PromWin and svar.PromWin[Status.Finals] and svar.PromWin[Status.Finals][1]
			--给冠军发一个邮件
			if baseCfg.winMail and winAid then
				mailcommon.sendMailById(winAid, baseCfg.winMail)
			end
			--注册下一次的定时器
			calcCurStartTime(true)
			RegTimerEvent()
			--svar.curStatus = Status.None
			--sendAllStatusChange(nil)
		end
		--标记状态处理完成
		if not svar.okStatus then svar.okStatus = {} end
		svar.okStatus[st] = System.getNowTime()	
		sendAllStatusChange(nil)
		if EidTable[st] then
			LActor.cancelScriptEvent(nil, EidTable[st])
			EidTable[st] = nil
		end
		return true
	end	
end

--晋级赛副本结束
local function onPromPkFbEnd(data, winAid, loseAid)
	local pinfo = data.pinfo
	pinfo[winAid] = pinfo[winAid] + 1
	local st = data.st
	local svar = getSysData()
	if not svar.Prom or not svar.Prom[st] then
		print("peakracesystem.onPromPkFbEnd not svar.Prom st:"..st)
		return
	end
	print("peakracesystem.onPromPkFbEnd idx:"..data.idx..",st:"..st..",winAid:"..winAid..",loseAid:"..loseAid)
	if not svar.PromWin then svar.PromWin = {} end
	if not svar.PromWin[st] then svar.PromWin[st] = {} end
	if not svar.PromWinStep then svar.PromWinStep = {} end
	if not svar.PromWinStep[st] then svar.PromWinStep[st] = {} end
	local promData = svar.Prom[st]
	local promWinData = svar.PromWin[st]
	local promWinStepData = svar.PromWinStep[st]
	--记录每一步赢的人
	if not promWinStepData[data.idx] then promWinStepData[data.idx] = {} end
	table.insert(promWinStepData[data.idx], winAid)
	--判断输赢
	if pinfo[winAid] >= baseCfg.promWin then
		print("peakracesystem.onPromPkFbEnd is ok idx:"..data.idx..",st:"..st..",winAid:"..winAid..",loseAid:"..loseAid)
		promWinData[data.idx] = winAid
		--发放赌注邮件
		sendBettMail(st, winAid, loseAid)
		--发放出局邮件
		sendLoseMail(st, loseAid)
		--发单场公告
		if TimeCfg[st].noticeId then
			noticemanager.broadCastNotice(TimeCfg[st].noticeId, LActor.getActorName(winAid), LActor.getActorName(loseAid))
		end
	end
	--检测是否结束这一场次
	checkPromPkOver(st)
end

--晋级赛匹配一次
local function AllPromPk(_, st, noTimer)
	EidTable[st] = nil
	local svar = getSysData()
	if not svar.Prom or not svar.Prom[st] then
		print("peakracesystem.AllPromPk not svar.Prom st:"..st)
		return false
	end
	--注册下一次匹配时间
	EidTable[st] = LActor.postScriptEventLite(nil, baseCfg.promInterval * 1000, AllPromPk, st, false)
	--可以开启这一场的状态,立马发一次
	if noTimer then
		svar.curStatus = st
		sendAllStatusChange(nil)
	end
	if not svar.PromWin then svar.PromWin = {} end
	if not svar.PromWin[st] then svar.PromWin[st] = {} end
	local promData = svar.Prom[st]
	local promWinData = svar.PromWin[st]
	--都比完出结果了
	if table.getnEx(promWinData) >= table.getnEx(promData) then
		print("peakracesystem.AllPromPk is all win over st:"..st)
		return false
	end
	local hasOnes = false
	local notFbPk = true
	for idx,pinfo in ipairs(promData) do
		if not promWinData[idx] then
			local aids = {}
			for aid,_ in pairs(pinfo) do
				table.insert(aids, aid)
			end
			if #aids == 0 then
				promWinData[idx] = 0
				hasOnes = true
			elseif #aids == 1 then
				print("peakracesystem.AllPromPk ones idx("..idx..") aid("..aids[1]..") on win st:"..st)
				promWinData[idx] = aids[1]
				hasOnes = true
			else
				print("peakracesystem.AllPromPk start idx("..idx..") aid1("..aids[1]..") pk aid2("..aids[2]..") st:"..st)
				--创建一个副本
				local data = {}
				data.pinfo = pinfo
				data.st = st
				data.idx = idx
				peakracefb.create(aids[1], aids[2], onPromPkFbEnd, data)
				notFbPk = false
			end
		end
	end
	if hasOnes and notFbPk then
		--检测是否结束这一场次
		checkPromPkOver(st)
	end
	return true
end

--返回报名数据
function sendSignUpData(actor)
	local svar = getSysData()
	local var = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendSignUp)
	if npack then
		local aid = LActor.getActorId(actor)
		LDataPack.writeChar(npack, svar.SignUpActor and svar.SignUpActor[aid] and 1 or 0)
		LDataPack.writeInt(npack, var.likeCount or 0)
		LDataPack.writeInt64I(npack, var.chipsCount or 0)
		LDataPack.writeInt(npack, svar.curStartTime or 0)		
		LDataPack.writeChar(npack, var.mobaiCount or 0)
		LDataPack.flush(npack)
	end
end

--改变筹码
function changeChips(actor, value, log)
	local var = getStaticData(actor)
	var.chipsCount = (var.chipsCount or 0) + value
	local clog = string.format("%d_%d", var.chipsCount, value)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "chips", clog, log or "")
	--下发金钱改变
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base ,Protocol.sBaseCmd_UpdateMoney)
	if npack then
		LDataPack.writeShort(npack, NumericType_Chips)
		LDataPack.writeInt64I(npack, var.chipsCount or 0)
		LDataPack.flush(npack)
	end
end

--改变筹码
function getChips(actor)
	local var = getStaticData(actor)
	return var.chipsCount or 0
end

local function checkCanSignUp()
	if not isOpenSer() then
		return false
	end
	local svar = getSysData()
	local stime = svar.curStartTime + PeakRaceTime[Status.SignUp].relTime
	local etime = svar.curStartTime + PeakRaceTime[Status.Knockout].relTime
	local now_t = System.getNowTime()
	if now_t <= stime or now_t >= etime then
		return false
	end
	return true
end

--请求报名
local function reqSignUp(actor, packet)
	local aid = LActor.getActorId(actor)
	if not checkCanSignUp() then
		print(aid.." peakracesystem.reqSignUp not on signup time")
		return
	end
	--判断转生等级
	if baseCfg.needZsLv > LActor.getZhuanShengLevel(actor) then
		print(aid.." peakracesystem.reqSignUp zhuanshenglv limit")
		return
	end
	local svar = getSysData()
	--判断是否已经报名
	if svar.SignUpActor and svar.SignUpActor[aid] then
		print(aid.." peakracesystem.reqSignUp is signup")
		return
	end
	if not svar.SignUpActor then svar.SignUpActor = {} end
	svar.SignUpActor[aid] = {
		loseNum = 0,
		toStatus = Status.Knockout
	}
	sendSignUpData(actor)
end

--计算当次开始时间
function calcCurStartTime(isnext)
	local svar = getSysData()
	local now_t = System.getNowTime()
	--根据开服时间来调整正式可以开启的时间
	local canOpenT = now_t
	local openRelTime = System.getOpenServerStartDateTime() + baseCfg.openDay * 3600*24
	if now_t < openRelTime then
		canOpenT = openRelTime
	end
	local interval = 3600 * 24 * (baseCfg.interval or 14)
	local difRound = math.floor((canOpenT - svar.GlobalStartTime)/interval)
	svar.curStartTime = svar.GlobalStartTime + difRound*interval
	if isnext then
		svar.curStartTime = svar.curStartTime + interval
	end
end

local function SignUpNotice()
	if not checkCanSignUp() then return end
	local st = Status.SignUp
	if not TimeCfg[st].noticeId then return end
	noticemanager.broadCastNotice(TimeCfg[st].noticeId)
	LActor.postScriptEventLite(nil, baseCfg.signUpNoticeTime * 1000, SignUpNotice) --注册下一次公告
end

--每一个状态处理函数
local statusFunc = {
	[Status.SignUp] = function(st)
		print("peakracesystem.SignUp start st:"..st)
		clearSysData()
		local svar = getSysData()
		svar.curStatus = st
		sendAllStatusChange(nil)
		local actors = System.getOnlineActorList()
		if actors ~= nil then
			for i =1,#actors do
				sendSignUpData(actors[i])
			end
		end
		--发公告
		SignUpNotice()
		
	end,
	[Status.Knockout] = function(st) --淘汰赛开始
		print("peakracesystem.Knockout start st:"..st)
		if AllSignUpPk() then
			local svar = getSysData()
			svar.curStatus = st
			sendAllStatusChange(nil)
			--检测分配第一轮的晋级赛
			checkKnockoutOver()
			--发公告
			if TimeCfg[st].noticeId then
				noticemanager.broadCastNotice(TimeCfg[st].noticeId)
			end
		end
	end,
	[Status.Prom16] = function(st) --16强晋级赛
		print("peakracesystem.Prom16 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Prom8] = function(st) --8强晋级赛
		print("peakracesystem.Prom8 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Prom4] = function(st) --4强晋级赛
		print("peakracesystem.Prom4 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Finals] = function(st) --决赛
		print("peakracesystem.Finals start st:"..st)
		local svar = getSysData()
		if not AllPromPk(nil,st,true) then
			print("peakracesystem.Finals start error,reg next time st:"..st)
			--注册下一次的定时器
			calcCurStartTime(true)
			RegTimerEvent()
			--svar.curStatus = Status.None
			--sendAllStatusChange(nil)
		end
	end,
}

--[[注册所有定时器
	dotime = 执行时间
	status = 状态
	isdo = false,已经执行过
]]
local PeakRaceGlobalEvent = {}
function RegTimerEvent()
	local svar = getSysData()
	local now_t = System.getNowTime()
	--热更的情况,把定时器先回收
	PeakRaceGlobalEvent = {}
	for status,data in pairs(PeakRaceTime) do
		local dotime = svar.curStartTime+data.relTime
		if now_t < dotime then
			table.insert(PeakRaceGlobalEvent, {dotime = dotime, status=status})
		end
	end
	table.sort(PeakRaceGlobalEvent, function(a,b)
        return a.dotime < b.dotime
    end)
	local y,m,d,h,i,s = System.timeDecode(svar.curStartTime)
	print("peakracesystem.RegTimerEvent curStartTime:"..string.format("%d-%d-%d %d:%d:%d",y,m,d,h,i,s))
	for _,ge in ipairs(PeakRaceGlobalEvent) do
		y,m,d,h,i,s = System.timeDecode(ge.dotime)
		print("peakracesystem.RegTimerEvent st:"..ge.status..",dotime:"..string.format("%d-%d-%d %d:%d:%d",y,m,d,h,i,s))
	end
end

local function checkTimerEvent()
	local now_t = System.getNowTime()
	for idx,info in ipairs(PeakRaceGlobalEvent) do
		if info.dotime <= now_t then
			local func = statusFunc[info.status]
			if func then
				func(info.status)
			end
			table.remove(PeakRaceGlobalEvent,idx)
		end
	end
end

--请求淘汰赛战报
local function reqKKinfo(actor, packet)
	local aid = LActor.getActorId(actor)
	print(aid.." peakracesystem.reqKKinfo")
	local svar = getSysData()
	local sinfo = svar.SignUpActor and svar.SignUpActor[aid] or nil
	if not sinfo then
		print(aid.." peakracesystem.reqKKinfo is not SignUpActor info")
		return
	end
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendKKinfo)
	if npack then
		LDataPack.writeShort(npack, svar.KnockOutTimes or 0)
		LDataPack.writeInt(npack, svar.KnockOutNextTime or 0)
		LDataPack.writeShort(npack, svar.KnockOutLeftNum or 0)
		local record = sinfo.KnockOutRec or {}
		LDataPack.writeShort(npack, #record)
		print(aid.." peakracesystem.reqKKinfo record size:"..(#record))
		for _,info in ipairs(record) do
			LDataPack.writeInt(npack, info.aid or 0)
			LDataPack.writeString(npack, info.name or "")
			LDataPack.writeChar(npack, info.result)
		end
		LDataPack.flush(npack)
	end
end

--请求晋级赛数据
local function reqPromInfo(actor, packet)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendPromInfo)
	if npack then
		local svar = getSysData()
		local prom16Data = svar.Prom and svar.Prom[Status.Prom16] or {}
		local prom16Win = svar.PromWin and svar.PromWin[Status.Prom16] or {}
		local prom16WinStep = svar.PromWinStep and svar.PromWinStep[Status.Prom16] or {}
		LDataPack.writeChar(npack, #prom16Data)
		for idx,info in ipairs(prom16Data) do
			local count = 0
			local pos1 = LDataPack.getPosition(npack)
			LDataPack.writeChar(npack, count)
			for aid,_ in pairs(info) do
				LDataPack.writeInt(npack, aid)
				LDataPack.writeString(npack, LActor.getActorName(aid))
				LDataPack.writeChar(npack, LActor.getActorJob(aid))
				LDataPack.writeChar(npack, LActor.getActorSex(aid))
				LDataPack.writeChar(npack, getSubIndex(aid))
				count = count + 1
			end
			local pos2 = LDataPack.getPosition(npack)
			LDataPack.setPosition(npack, pos1)
			LDataPack.writeChar(npack, count)
			LDataPack.setPosition(npack, pos2)
			--下发赢的人
			LDataPack.writeInt(npack, prom16Win[idx] or 0)
			local stepInfo =  prom16WinStep[idx] or {}
			LDataPack.writeChar(npack, #stepInfo)
			for _,aid in ipairs(stepInfo) do
				LDataPack.writeInt(npack, aid)
			end
		end
		--8强赢的人
		local prom8Data = svar.Prom and svar.Prom[Status.Prom8] or {}
		local prom8Win = svar.PromWin and svar.PromWin[Status.Prom8] or {}
		local prom8WinStep = svar.PromWinStep and svar.PromWinStep[Status.Prom8] or {}
		local count = 0
		local pos1 = LDataPack.getPosition(npack)
		LDataPack.writeChar(npack, count)
		for idx,_ in ipairs(prom8Data) do
			LDataPack.writeInt(npack, prom8Win[idx] or 0)
			count = count + 1
			local stepInfo =  prom8WinStep[idx] or {}
			LDataPack.writeChar(npack, #stepInfo)
			for _,aid in ipairs(stepInfo) do
				LDataPack.writeInt(npack, aid)
			end
		end
		local pos2 = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos1)
		LDataPack.writeChar(npack, count)
		LDataPack.setPosition(npack, pos2)
		--4强赢的人
		local prom4Data = svar.Prom and svar.Prom[Status.Prom4] or {}
		local prom4Win = svar.PromWin and svar.PromWin[Status.Prom4] or {}
		local prom4WinStep = svar.PromWinStep and svar.PromWinStep[Status.Prom4] or {}
		count = 0
		pos1 = LDataPack.getPosition(npack)
		LDataPack.writeChar(npack, count)
		for idx,_ in ipairs(prom4Data) do
			LDataPack.writeInt(npack, prom4Win[idx] or 0)
			count = count + 1
			local stepInfo =  prom4WinStep[idx] or {}
			LDataPack.writeChar(npack, #stepInfo)
			for _,aid in ipairs(stepInfo) do
				LDataPack.writeInt(npack, aid)
			end
		end
		pos2 = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos1)
		LDataPack.writeChar(npack, count)
		LDataPack.setPosition(npack, pos2)
		--冠军
		local waid = svar.PromWin and svar.PromWin[Status.Finals] and svar.PromWin[Status.Finals][1] or 0
		LDataPack.writeInt(npack, waid)
		local stepInfo = svar.PromWinStep and svar.PromWinStep[Status.Finals] and svar.PromWinStep[Status.Finals][1] or {}
		LDataPack.writeChar(npack, #stepInfo)
		for _,aid in ipairs(stepInfo) do
			LDataPack.writeInt(npack, aid)
		end
		LDataPack.flush(npack)
	end
end

--请求给人点赞
local function reqLike(actor, packet)
	--判断当前状态是否能够点赞
	local svar = getSysData()
	--是否已经决赛结束了
	--if svar.okStatus and svar.okStatus[Status.Finals] then
		--判断是不是同一天
	--	if not System.isSameDay(svar.okStatus[Status.Finals], System.getNowTime()) then 
	--		print(LActor.getActorId(actor).." peakracesystem.reqLike is Finals ok")
	--		return 
	--	end
	--end

	local aid = LDataPack.readInt(packet)
	local var = getStaticData(actor)
	--判断这个玩家还有没有次数
	if (var.likeCount or 0) >= PeakRaceBase.likeCount then
		print(LActor.getActorId(actor).." peakracesystem.reqLike likeCount is max")
		return
	end
	if not peakracerank.updatePoint(aid) then
		print(LActor.getActorId(actor).." peakracesystem.reqLike updatePoint error")
		return
	end
	--增加点赞次数
	var.likeCount = (var.likeCount or 0) + 1
	--增加筹码
	LActor.changeCurrency(actor, NumericType_Chips, PeakRaceBase.likeChips, "reqlike")
	sendSignUpData(actor)
end

--下发我的下注信息
local function sendBettInfo(actor)
	local maid = LActor.getActorId(actor)
	local svar = getSysData()
	local info = svar.bett and svar.bett[maid]
	if not info then return end --没有下注过就不发了
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendBettInfo)
	if not npack then return end
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
	LDataPack.flush(npack)
end

--获取现在能下注的状态
local function getCanBettStatus()
	local svar = getSysData()
	local st = svar.curStatus
	if not st then return nil end
	--淘汰赛之前,决赛开始之后
	if st < Status.Knockout or st >= Status.Finals then return nil end
	--这个状态结束了;
	if svar.okStatus[st] then
		return st+1 --下一个状态是可以开始下注了
	end
	return nil
end

--请求下注
local function reqBett(actor, packet)
	local maid = LActor.getActorId(actor)
	--被下注的玩家ID
	local aid = LDataPack.readInt(packet)
	local count = LDataPack.readInt(packet)
	local svar = getSysData()
	--判断这个玩家有没报名
	if not svar.SignUpActor or not svar.SignUpActor[aid] then
		print(maid.." peakracesystem.reqBett is not in SignUpActor aid:"..aid)
		return
	end
	local ainfo = svar.SignUpActor[aid]
	--获取当前能下注的状态
	local cst = getCanBettStatus()
	if not cst then
		print(maid.." peakracesystem.reqBett is not in bett status aid:"..aid)
		return
	end
	count = math.min(count, PeakRaceTime[cst].maxBett or 0)
	if count <= 0 then
		print(maid.." peakracesystem.reqBett count is glt 0 aid:"..aid)
		return
	end
	--判断是否已经下注过了
	if svar.bett and svar.bett[maid] and svar.bett[maid][cst] then
		print(maid.." peakracesystem.reqBett is on bett cst:"..cst)
		return
	end
	--判断这个人是否轮空
	local pinfo = svar.Prom and svar.Prom[ainfo.toStatus] and svar.Prom[ainfo.toStatus][ainfo.toIdx]
	if not pinfo then
		print(maid.." peakracesystem.reqBett is not pinfo st:"..tostring(ainfo.toStatus)..", idx:"..tostring(ainfo.toIdx))
		return
	end
	local cp = 0
	for _,_ in pairs(pinfo) do
		cp = cp + 1
	end
	if cp <= 1 then
		print(maid.." peakracesystem.reqBett pinfo is ones count:"..cp)
		return
	end
	--判断是否足够的筹码
	local var = getStaticData(actor)
	if (var.chipsCount or 0) < count then
		print(maid.." peakracesystem.reqBett is not have chips aid:"..aid)
		return
	end
	LActor.changeCurrency(actor, NumericType_Chips, -count, "reqBett")
	--记录下注信息
	if not ainfo.bettAids then ainfo.bettAids = {} end
	if not ainfo.bettAids[cst] then ainfo.bettAids[cst] = {} end
	table.insert(ainfo.bettAids[cst], maid)
	if not svar.bett then svar.bett = {} end
	if not svar.bett[maid] then svar.bett[maid] = {} end
	svar.bett[maid][cst] = {aid=aid,num=count}
	--下发我的下注信息
	sendBettInfo(actor)
end

--请求排行榜数据
local function reqRankData(actor, packet)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendRankData)
	if npack then
		peakracerank.reqRankData(npack)
		LDataPack.flush(npack)
	end
end

--每日零点
local function onNewDay(actor, islogin)
	local var = getStaticData(actor)
	var.likeCount = nil
	var.mobaiCount = nil
	if not islogin then
		sendSignUpData(actor)
	end
end

--在登陆的时候
local function onLogin(actor)
	sendSignUpData(actor)
	sendAllStatusChange(actor)
	sendBettInfo(actor)
end

--请求膜拜跨服冠军
local function onReqMobai(actor, packet)
	--先判断是否已经有冠军了
	local data = peakracecrossdata.getData()
	if not data.winAid or data.winAid == 0 then
		print(LActor.getActorId(actor).." peakracesystem.onReqMobai is not have winer")
		return
	end
	--获取静态变量
	local var = getStaticData(actor)
	--判断是否还有膜拜次数
	if (var.mobaiCount or 0) >= (baseCfg.mobaiNum or 0) then
		print(LActor.getActorId(actor).." peakracesystem.onReqMobai count is max")
		return
	end
	--获得筹码
	if baseCfg.mobaiChips then
		LActor.changeCurrency(actor, NumericType_Chips, baseCfg.mobaiChips, "peak mobai")
	end
	--增加已经膜拜的次数
	var.mobaiCount = (var.mobaiCount or 0) + 1
	--下发膜拜成功消息
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_MobaiSuccess)
	if npack then
		LDataPack.writeChar(npack, var.mobaiCount or 0)
		LDataPack.flush(npack)
	end
end

--初始化全局数据
local function initGlobalData()
	if not System.isCommSrv() then return end

	actorevent.reg(aeNewDayArrive, onNewDay)
    actorevent.reg(aeUserLogin, onLogin)
    --客户端请求来的消息
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqSignUp, reqSignUp) --请求报名
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_GetKKinfo, reqKKinfo) --淘汰赛战报
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_GetPromInfo, reqPromInfo) --晋级赛数据
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqRankData, reqRankData) --请求排行榜数据
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqLike, reqLike) --请求排行榜点赞
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqBett, reqBett) --请求下注	
	netmsgdispatcher.reg(Protocol.CMD_PeakRace, Protocol.cPeakRace_ReqMobai, onReqMobai) --请求膜拜跨服冠军

	--处理全局开始数据
	local open_time = getOpenTime()
	local svar = getSysData()
	if not open_time or svar.GlobalStartTime ~= open_time then
		clearSysData()
	end
	svar.GlobalStartTime = open_time
	calcCurStartTime(false)
	local now_t = System.getNowTime()
	--决赛后启动的服,需要计算下一次的定时器
	if now_t > svar.curStartTime + PeakRaceTime[Status.Finals].relTime then
		calcCurStartTime(true)
	end
	--注册时间定时器
	RegTimerEvent()
	engineevent.regGameTimer(checkTimerEvent)
end

table.insert(InitFnTable, initGlobalData)

function gmDoSt(st)
	local func = statusFunc[st]
	if func then
		func(st)
	end
end

--peak
function gmHandle(actor, arg)
	local cmd = arg[1]
	if cmd == "dst" then
		table.insert(PeakRaceGlobalEvent, {status=tonumber(arg[2]), dotime=System.getNowTime() + (tonumber(arg[3]) or 0)})
		table.sort(PeakRaceGlobalEvent, function(a,b)
	        return a.dotime < b.dotime
	    end)
	    checkTimerEvent()
	elseif cmd == "cst" then
		PeakRaceGlobalEvent = {}
	elseif cmd == "rest" then
		local svar = getSysData()
		svar.curStartTime = math.floor((System.getNowTime() + (tonumber(arg[2]) or 0))/60)*60
		svar.curStatus = Status.None
		sendAllStatusChange(nil)
		RegTimerEvent()
		for st,eid in pairs(EidTable) do
			LActor.cancelScriptEvent(nil, eid)
		end
		EidTable = {}
	elseif cmd == 'mb' and actor then
		onReqMobai(actor, nil)
	elseif actor then
		reqSignUp(actor, nil)
	end
	return true
end
--peaksign
function gmPeakSignHandle(actor, args)
	local svar = getSysData()
	local num = tonumber(args[1])
	if not svar.SignUpActor then svar.SignUpActor = {} end
	local actorDatas = System.getAllActorData()
    for _, data in ipairs(actorDatas) do
        local actorData = toActorBasicData(data)
        if not svar.SignUpActor[actorData.actor_id] then
        	svar.SignUpActor[actorData.actor_id] = {
				loseNum = 0,
				toStatus = Status.Knockout
			}
			num = num - 1
		end
		if num <= 0 then
			return
		end
    end
	return true
end
