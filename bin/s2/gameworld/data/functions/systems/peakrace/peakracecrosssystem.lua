--巅峰赛季逻辑系统(跨服)
module("peakracecrosssystem", package.seeall)
Status = {
	None = 0, --未开始状态
	Knockout = 1, --淘汰赛状态
	Prom64 = 2, --64强晋级赛
	Prom32 = 3, --32强晋级赛
	Prom16 = 4, --16强晋级赛
	Prom8 = 5, --8强晋级赛
	Prom4 = 6, --4强晋级赛
	Finals = 7, --决赛
}
local baseCfg = PeakRaceBase
local TimeCfg = PeakRaceCrossTime
--全局临时Eid储存
EidTable = EidTable or {}
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
	isSendLikeRankReward = 是否已经发放点赞排名奖励
	SignUpActor[玩家ID] = {
		loseNum = 0 --报名海选玩家输了多少次
		name = 玩家名
		sid = 玩家所在服务器
		job = 职业
		sex = 性别
		KnockOutRec = { --淘汰赛输赢记录
			{aid=对方玩家ID,name=对方名字,result=结果,1胜0负}
		}
		toStatus = 晋级到了什么状态
		toIdx = 所在索引
		bettAids[状态]={{aid=玩家ID,sid=服ID}}--下注了的玩家
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
function getSysData()
	local var = System.getStaticVar()
	if var == nil then 
		return nil
	end
	if var.peakracecross == nil then 
		var.peakracecross = {}
	end
	return var.peakracecross
end

--根据ID获取参赛选手的信息
function getActorInfo(aid)
	local svar = getSysData()
	return svar.SignUpActor and svar.SignUpActor[aid] or {}
end

--根据ID获取玩家名
function getActorName(aid)
	local svar = getSysData()
	return svar.SignUpActor and svar.SignUpActor[aid] and svar.SignUpActor[aid].name or ""
end

--根据ID获取玩家所在服务器
function getActorSid(aid)
	local svar = getSysData()
	return svar.SignUpActor and svar.SignUpActor[aid] and svar.SignUpActor[aid].sid or 0
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
	svar.isSendLikeRankReward = nil
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

--获取全局开始时间
local function getOpenTime()
    local Y,M,d,h,m = string.match(baseCfg.openTime, "(%d+)%.(%d+)%.(%d+)")
    if Y == nil or M == nil or d == nil then
        return nil
    end
    return System.timeEncode(Y, M, d, 0, 0, 0)
end

--获取冠亚军玩家ID
local function getFinalsAid()
	local svar = getSysData()
	local winAid = svar.PromWin and svar.PromWin[Status.Finals] and svar.PromWin[Status.Finals][1] or 0
	local secAid = 0
	if winAid ~= 0 and svar.Prom and svar.Prom[Status.Finals] and svar.Prom[Status.Finals][1] then
		for aid,_ in pairs(svar.Prom[Status.Finals][1]) do
			if aid ~= winAid then
				secAid = aid
				break
			end
		end
	end
	return winAid, secAid
end

--发送状态改变到所有游戏服
local function sendStatusChangeToServ(sid)
	if not sid then sid = 0 end
	local svar = getSysData()
	local pack = LDataPack.allocPacket()
	if not pack then return end
	LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
	LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_StatusChange)
	LDataPack.writeChar(pack, svar.curStatus or 0)
	LDataPack.writeInt(pack, svar.okStatus and svar.okStatus[svar.curStatus] or 0)
	local winAid,secAid = getFinalsAid()
	LDataPack.writeInt(pack, winAid)
	LDataPack.writeInt(pack, secAid)
	System.sendPacketToAllGameClient(pack, sid)
	local o = svar.okStatus and svar.okStatus[svar.curStatus] or 0
	print("peakracecrosssystem.sendStatusChangeToServ send status to all server:"..sid..",st:"..tostring(svar.curStatus)..",o:"..o)
end

--检测淘汰赛结束
local function checkKnockoutOver()
	print("peakracecrosssystem.checkKnockoutOver start")
	--把所有人分配到64强数组
	local st = getNst(Status.Knockout)
	local svar = getSysData()
	--已经海选结束了
	if svar.okStatus and svar.okStatus[Status.Knockout] then return end
	if not svar.SignUpActor then 
		print("peakracecrosssystem.checkKnockoutOver not SignUpActor")
		return
	end
	local allAid = {}
	for aid,info in pairs(svar.SignUpActor) do
		if (info.loseNum or 0) < baseCfg.signUpLose then --配置的海选淘汰次数
			table.insert(allAid, aid)
		end
	end
	svar.KnockOutLeftNum = #allAid --更新剩余人数
	if #allAid <= 0 then
		print("peakracecrosssystem.checkKnockoutOver #allAid <= 0")
		return
	end
	if #allAid > baseCfg.crossPromCount then
		return
	end
	--发产生64强公告
	if baseCfg.CrossKnockOutNoticeId then
		for _,aid in ipairs(allAid) do
			noticemanager.broadCastNotice(baseCfg.CrossKnockOutNoticeId, getActorName(aid), getActorSid(aid))
		end
	end
	--继续匹配晋级赛
	svar.PromWinStep = {}
	svar.Prom = {}
	svar.Prom[st] = {}
	svar.PromWin = {}
	svar.PromWin[st] = {}
	local pr = svar.Prom[st]

	local gnum = math.ceil(baseCfg.crossPromCount/2)
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
		peakracerank.addToRank(aid, getActorName(aid), getActorSid(aid))
		--随机出位置
		local pos = table.remove(pr_num, System.rand(#pr_num)+1)
		pr[pos.i][aid] = 0 --设置到pinfo
		setAidToSt(aid, st, pos.i, pos.p)
	end

	if not svar.okStatus then svar.okStatus = {} end
	svar.okStatus[Status.Knockout] = System.getNowTime()
	sendStatusChangeToServ()
	if EidTable[Status.Knockout] then
		LActor.cancelScriptEvent(nil, EidTable[Status.Knockout])
		EidTable[Status.Knockout] = nil
	end
	print("peakracecrosssystem.checkKnockoutOver ok")
end

--发放出局邮件
local function sendLoseMail(st, loseAid)
	local cfg = PeakRaceCrossTime[st]
	if not cfg then return end
	if cfg.loseMail then
		mailcommon.sendMailById(loseAid, cfg.loseMail, getActorSid(loseAid))
	end
end

--发放赌注邮件
local function sendBettMail(st, winAid, loseAid)
	local cfg = PeakRaceCrossTime[st]
	if not cfg then return end
	local winName = getActorName(winAid)
	local loseName = getActorName(loseAid)
	local svar = getSysData()
	--赌赢的人
	if cfg.bettWinMail then
		local ainfo = svar.SignUpActor and svar.SignUpActor[winAid]
		local aids = ainfo and ainfo.bettAids and ainfo.bettAids[st]
		for _,bainfo in ipairs(aids or {}) do
			local bettInfo = svar.bett and svar.bett[bainfo.aid] and svar.bett[bainfo.aid][st]
			if bettInfo then
				if bettInfo.aid == winAid then
					local mailInfo = mailcommon.getConfigByMailId(cfg.bettWinMail)
					if mailInfo then
						local rcount = bettInfo.num * 2
						local tMailData = {}
						tMailData.head = mailInfo.title
						tMailData.context = string.format(mailInfo.content, winName, loseName, rcount)
						tMailData.tAwardList = {{type=0,id=NumericType_Chips,count=rcount}}
						mailsystem.sendMailById(bainfo.aid, tMailData, bainfo.sid)
					end
				else
					print(bainfo.aid.." peakracecrosssystem.sendBettMail not have bettInfo.aid("..bettInfo.aid..") ~= winAid:"..winAid)
				end
			else
				print(bainfo.aid.." peakracecrosssystem.sendBettMail not have bettInfo winAid:"..winAid)
			end
		end
	end
	--赌输了的人
	if cfg.bettLoseMail then
		local ainfo = svar.SignUpActor and svar.SignUpActor[loseAid]
		local aids = ainfo and ainfo.bettAids and ainfo.bettAids[st]
		for _,bainfo in ipairs(aids or {}) do
			local bettInfo = svar.bett and svar.bett[bainfo.aid] and svar.bett[bainfo.aid][st]
			if bettInfo then
				if bettInfo.aid == loseAid then
					local mailInfo = mailcommon.getConfigByMailId(cfg.bettLoseMail)
					if mailInfo then
						--local rcount = bettInfo.num * 2
						local tMailData = {}
						tMailData.head = mailInfo.title
						tMailData.context = string.format(mailInfo.content, winName, loseName, bettInfo.num)
						--tMailData.tAwardList = {type=0,id=NumericType_Chips,count=rcount}
						mailsystem.sendMailById(bainfo.aid, tMailData, bainfo.sid)
					end
				else
					print(bainfo.aid.." peakracecrosssystem.sendBettMail not have bettInfo.aid("..bettInfo.aid..") ~= loseAid:"..loseAid)
				end
			else
				print(bainfo.aid.." peakracecrosssystem.sendBettMail not have bettInfo loseAid:"..loseAid)
			end
		end		
	end
end

--海选淘汰赛副本结束的时候
local function onSignUpFbEnd(data, winAid, loseAid)	
	print("peakracecrosssystem.onSignUpFbEnd, winAid:"..winAid..", loseAid:"..loseAid)
	local svar = getSysData()
	--已经海选结束了
	if svar.okStatus and svar.okStatus[Status.Knockout] then return end
	local stime = svar.curStartTime + PeakRaceCrossTime[Status.Knockout].relTime
	local now_t = System.getNowTime()
	if now_t < stime then
		print("peakracecrosssystem.onSignUpFbEnd status is not on Knockout")
		return
	end
	if not svar.SignUpActor then
		print("peakracecrosssystem.onSignUpFbEnd not SignUpActor")
		return
	end
	if not svar.SignUpActor[loseAid] then
		print("peakracecrosssystem.onSignUpFbEnd not SignUpActor["..loseAid.."]")
		return
	end
	--记录输的人的信息
	local lsinfo = svar.SignUpActor[loseAid]
	lsinfo.loseNum = (lsinfo.loseNum or 0) + 1
	if not lsinfo.KnockOutRec then lsinfo.KnockOutRec = {} end
	table.insert(lsinfo.KnockOutRec, {aid=winAid,name=getActorName(winAid),result=0})
	--记录赢的人的信息
	local wsinfo = svar.SignUpActor[winAid]
	if not wsinfo.KnockOutRec then wsinfo.KnockOutRec = {} end
	table.insert(wsinfo.KnockOutRec, {aid=loseAid,name=getActorName(loseAid),result=1})
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
	--已经海选结束了
	if svar.okStatus and svar.okStatus[Status.Knockout] then return end
	local stime = svar.curStartTime + PeakRaceCrossTime[Status.Knockout].relTime
	local now_t = System.getNowTime()
	if now_t < stime then
		print("peakracecrosssystem.AllSignUpPk status is not on Knockout")
		return
	end
	if not svar.SignUpActor then 
		print("peakracecrosssystem.AllSignUpPk not SignUpActor")
		return 
	end
	local count = 0
	local allAid = {}
	for aid,info in pairs(svar.SignUpActor) do
		if (info.loseNum or 0) < baseCfg.signUpLose then --配置的海选淘汰次数
			table.insert(allAid, aid)
		end
		count = count + 1
	end
	if count < baseCfg.needPlayer then
		print("peakracecrosssystem.AllSignUpPk not have needPlayer")
		return
	end
	svar.KnockOutLeftNum = #allAid --更新剩余人数
	if #allAid <= baseCfg.crossPromCount then --配置的晋级赛人数
		return true
	end
	svar.KnockOutTimes = (svar.KnockOutTimes or 0) + 1 --第几轮
	--随机两个人出来打
	while #allAid > 1 do
		local aid1 = table.remove(allAid, System.rand(#allAid)+1)
		local aid2 = table.remove(allAid, System.rand(#allAid)+1)
		--创建一个副本
		print("peakracecrosssystem.AllSignUpPk create fuben aid1:"..aid1..",aid2:"..aid2)
		local data = {}
		peakracecrossfb.create(aid1, aid2, onSignUpFbEnd, data)
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
	LActor.postScriptEventLite(nil, baseCfg.KnockOutTime * 1000, AllSignUpPk) --注册下一次匹配时间
	return true
end

--晋级赛结束检测
local function checkPromPkOver(st)
	local svar = getSysData()
	--已经检测过结束了
	if svar.okStatus and svar.okStatus[st] then return end
	if not svar.Prom or not svar.Prom[st] then
		print("peakracecrosssystem.checkPromPkOver not svar.Prom st:"..st)
		return
	end
	print("peakracecrosssystem.checkPromPkOver start")
	if not svar.PromWin then svar.PromWin = {} end
	if not svar.PromWin[st] then svar.PromWin[st] = {} end
	local promData = svar.Prom[st]
	local promWinData = svar.PromWin[st]
    --所有人都决出赢了
    local gnum = table.getnEx(promWinData)
	if gnum >= table.getnEx(promData) then
		print("peakracecrosssystem.checkPromPkOver is ok all st:"..st)
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
				print("peakracecrosssystem.checkPromPkOver i:"..i..",nst:"..nst..",pos:"..pos..",aid1:"..tostring(aid1))
				if aid2 and aid2 ~= 0 then
					setAidToSt(aid2, nst, pos)
					prinfo[aid2] = 0 
				end
				print("peakracecrosssystem.checkPromPkOver i:"..(i+1)..",nst:"..nst..",pos:"..pos..",aid2:"..tostring(aid2))
				table.insert(pr,prinfo)
				pos = pos + 1
			end
			print("peakracecrosssystem.checkPromPkOver is over st:"..st..",nst:"..nst)
		elseif st == Status.Finals then--决赛结束了
			print("peakracecrosssystem.checkPromPkOver is over Status.Finals st:"..st)
			local winAid = svar.PromWin and svar.PromWin[Status.Finals] and svar.PromWin[Status.Finals][1]
			--给冠军发一个邮件
			if baseCfg.crossWinMail and winAid then
				mailcommon.sendMailById(winAid, baseCfg.crossWinMail, getActorSid(winAid))
			end
			--注册下一次的定时器
			calcCurStartTime(true)
			RegTimerEvent()
			--svar.curStatus = Status.None
			--sendStatusChangeToServ()
		end
		--标记状态处理完成
		if not svar.okStatus then svar.okStatus = {} end
		svar.okStatus[st] = System.getNowTime()
		sendStatusChangeToServ()
		if EidTable[st] then
			LActor.cancelScriptEvent(nil, EidTable[st])
			EidTable[st] = nil
		end
	end	
end

--晋级赛副本结束
local function onPromPkFbEnd(data, winAid, loseAid)
	local pinfo = data.pinfo
	pinfo[winAid] = pinfo[winAid] + 1
	local st = data.st
	local svar = getSysData()
	if not svar.Prom or not svar.Prom[st] then
		print("peakracecrosssystem.onPromPkFbEnd not svar.Prom st:"..st)
		return
	end
	print("peakracecrosssystem.onPromPkFbEnd idx:"..data.idx..",st:"..st..",winAid:"..winAid..",loseAid:"..loseAid)
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
		print("peakracecrosssystem.onPromPkFbEnd is ok idx:"..data.idx..",st:"..st..",winAid:"..winAid..",loseAid:"..loseAid)
		promWinData[data.idx] = winAid
		--发放赌注邮件
		sendBettMail(st, winAid, loseAid)
		--发放出局邮件
		sendLoseMail(st, loseAid)
		--发单场公告
		if TimeCfg[st].noticeId then
			noticemanager.broadCastNotice(TimeCfg[st].noticeId, getActorName(winAid), getActorSid(winAid), getActorName(loseAid), getActorSid(loseAid))
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
		print("peakracecrosssystem.AllPromPk not svar.Prom st:"..st)
		return false
	end
	--注册下一次匹配时间
	EidTable[st] = LActor.postScriptEventLite(nil, baseCfg.promInterval * 1000, AllPromPk, st, false)
	--可以开启这一场的状态,立马发一次
	if noTimer then
		svar.curStatus = st
		sendStatusChangeToServ()
	end
	if not svar.PromWin then svar.PromWin = {} end
	if not svar.PromWin[st] then svar.PromWin[st] = {} end
	local promData = svar.Prom[st]
	local promWinData = svar.PromWin[st]
	--都比完出结果了
	if table.getnEx(promWinData) >= table.getnEx(promData) then
		print("peakracecrosssystem.AllPromPk is all win over st:"..st)
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
				print("peakracecrosssystem.AllPromPk ones idx("..idx..") aid("..aids[1]..") on win st:"..st)
				promWinData[idx] = aids[1] 
				hasOnes = true
			else
				print("peakracecrosssystem.AllPromPk start idx("..idx..") aid1("..aids[1]..") pk aid2("..aids[2]..") st:"..st)
				--创建一个副本
				local data = {}
				data.pinfo = pinfo
				data.st = st
				data.idx = idx
				peakracecrossfb.create(aids[1], aids[2], onPromPkFbEnd, data)
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

--计算当次开始时间
function calcCurStartTime(isnext)
	local svar = getSysData()
	local now_t = System.getNowTime()
	local interval = 3600 * 24 * (baseCfg.interval or 14)
	local difRound = math.floor((now_t - svar.GlobalStartTime)/interval)
	svar.curStartTime = svar.GlobalStartTime + difRound*interval
	if isnext then
		svar.curStartTime = svar.curStartTime + interval
	end
end

--每一个状态处理函数
local statusFunc = {
	[Status.None] = function(st) --清除数据
		print("peakracecrosssystem.None start do clearSysData st:"..st)
		local svar = getSysData()
		svar.curStatus = st
		clearSysData()
		sendStatusChangeToServ()
	end,
	[Status.Knockout] = function(st) --淘汰赛开始
		print("peakracecrosssystem.Knockout start st:"..st)
		if AllSignUpPk() then
			local svar = getSysData()
			svar.curStatus = st
			sendStatusChangeToServ()
			--检测分配第一轮的晋级赛
			checkKnockoutOver()
			--发公告
			if TimeCfg[st].noticeId then
				noticemanager.broadCastNotice(TimeCfg[st].noticeId)
			end
		end
	end,
	[Status.Prom64] = function(st) --16强晋级赛
		print("peakracecrosssystem.Prom64 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Prom32] = function(st) --16强晋级赛
		print("peakracecrosssystem.Prom32 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Prom16] = function(st) --16强晋级赛
		print("peakracecrosssystem.Prom16 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Prom8] = function(st) --8强晋级赛
		print("peakracecrosssystem.Prom8 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Prom4] = function(st) --4强晋级赛
		print("peakracecrosssystem.Prom4 start st:"..st)
		AllPromPk(nil,st,true)
	end,
	[Status.Finals] = function(st) --决赛
		print("peakracecrosssystem.Finals start st:"..st)
		local svar = getSysData()
		if not AllPromPk(nil,st,true) then
			print("peakracecrosssystem.Finals start error,reg next time st:"..st)
			--注册下一次的定时器
			calcCurStartTime(true)
			RegTimerEvent()
			--svar.curStatus = Status.None
			--sendStatusChangeToServ()
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
	for status,data in pairs(PeakRaceCrossTime) do
		local dotime = svar.curStartTime+data.relTime
		if now_t < dotime then
			table.insert(PeakRaceGlobalEvent, {dotime = dotime, status=status})
		end
	end
	table.sort(PeakRaceGlobalEvent, function(a,b)
        return a.dotime < b.dotime
    end)
	local y,m,d,h,i,s = System.timeDecode(svar.curStartTime)
	print("peakracecrosssystem.RegTimerEvent curStartTime:"..string.format("%d-%d-%d %d:%d:%d",y,m,d,h,i,s))
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

--获取现在能下注的状态
function getCanBettStatus()
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

--接收单服来的数据
local function onGetSerProm16(sId, sType, dp)
	local svar = getSysData()
	--清数据那一刻的时间
	local stime = svar.curStartTime + PeakRaceCrossTime[Status.None].relTime
	--淘汰赛开始的时间
	local etime = svar.curStartTime + PeakRaceCrossTime[Status.Knockout].relTime
	local now_t = System.getNowTime()
	if now_t <= stime or now_t >= etime then
		print(sId.." peakracecrosssystem.onGetSerProm16 status is not on SignUp")
		return
	end
	if not svar.SignUpActor then svar.SignUpActor = {} end
	local count = LDataPack.readChar(dp) --玩家个数
	print(sId.." peakracecrosssystem.onGetSerProm16 SignUp count:"..count)
	for i=1,count do
		local aid = LDataPack.readInt(dp)
		local name = LDataPack.readString(dp)
		local job = LDataPack.readChar(dp)
		local sex = LDataPack.readChar(dp)
		svar.SignUpActor[aid] = {aid = aid, name = name, job = job, sex = sex,sid = sId,loseNum = 0,}
		print(sId.." peakracecrosssystem.onGetSerProm16 SignUp aid:"..aid)
	end
end

--服务器连接上来的时候
local function OnServerConn(serverId, serverType)
	sendStatusChangeToServ(serverId)
end

--发放点赞排名奖励
local function PeakRaceSendLikeRankReward()
	if System.isCommSrv() then return end
	--判断是否已经发过奖励了
	local svar = getSysData()
	if svar.isSendLikeRankReward then
		return
	end
	--遍历发邮件
	for rank,mid in ipairs(PeakRaceBase.likeRankMailId) do
		if not peakracerank.sendRankMailReward(rank, mid) then
			break
		end
	end
	--设置奖励已经发放
	svar.isSendLikeRankReward = 1
end
_G.PeakRaceSendLikeRankReward = PeakRaceSendLikeRankReward

--初始化全局数据
local function initGlobalData()
	if System.isCommSrv() or System.getBattleSrvFlag() ~= bsBattleSrv then return end

    --游戏服来的消息处理
    csmsgdispatcher.Reg(CrossSrvCmd.SCPeakRaceCmd, CrossSrvSubCmd.SCPeakRaceCmd_SendProm16, onGetSerProm16)

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
	if now_t > svar.curStartTime + PeakRaceCrossTime[Status.Finals].relTime then
		calcCurStartTime(true)
	end
	--注册时间定时器
	RegTimerEvent()
	engineevent.regGameTimer(checkTimerEvent)
	--游戏服连接的时候
	csbase.RegConnected(OnServerConn)
end

table.insert(InitFnTable, initGlobalData)

--peak
function gmHandle(arg)
	local cmd = arg[1] or ""
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
		sendStatusChangeToServ()
		RegTimerEvent()
	end
	return true
end
