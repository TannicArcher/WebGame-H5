--巅峰赛季副本(游戏服)
module("peakracecrossfb", package.seeall)

local baseCfg = PeakRaceBase
local AStatus = {
	sendCheck = 0,--发送检测请求中
	canEnter = 1,--能进入副本
	notEnter = 2,--不能进入副本
}

--下发副本结果到客户端
local function sendFuBenResult(actor, pname, result)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendFbResult)
	if npack then
		local sinfo 
		LDataPack.writeChar(npack, result and 1 or 0)
		LDataPack.writeString(npack, pname or "")
		LDataPack.flush(npack)
	end
end

--比较战力来算输赢
local function pkPowerOnCallBack(data, ainfo1, ainfo2, callback, fblose)
	print("peakracefb.pkPowerOnCallBack aid1:"..ainfo1.aid.."("..(ainfo1.power or 0)..") aid2:"..ainfo2.aid.."("..(ainfo2.power or 0)..")")
	local winAid = nil
	local loseAid = nil
	if (ainfo1.power or 0) > (ainfo2.power or 0) then
		winAid = ainfo1.aid
		loseAid = ainfo2.aid
	else
		winAid = ainfo2.aid
		loseAid = ainfo1.aid
	end
	callback(data, winAid, loseAid)
	if fblose then
		local wactor = LActor.getActorById(winAid)
		if wactor then
			--发胜利结果
			sendFuBenResult(wactor, peakracecrosssystem.getActorName(loseAid), true)
		end
		local lactor = LActor.getActorById(loseAid)
		if lactor then
			--发失败结果
			sendFuBenResult(lactor, peakracecrosssystem.getActorName(winAid), false)
		end
	end
end

--创建一个副本
function create(aid1, aid2, callback, data)
	local fbhandle = Fuben.createFuBen(baseCfg.fbid)
	local ins = instancesystem.getInsByHdl(fbhandle)
	if not ins then
		print("peakracecrossfb.create ins is nil, create fuben error")
		return
	end
	ins.data = data
	if not ins.data then ins.data = {} end
	--记录回调函数
	ins.data.fbCallBack = callback
	ins.data.aids = {}
	table.insert(ins.data.aids, {aid=aid1,sid=peakracecrosssystem.getActorSid(aid1)})
	table.insert(ins.data.aids, {aid=aid2,sid=peakracecrosssystem.getActorSid(aid2)})
	--通知双方进入战场
	for idx,v in ipairs(ins.data.aids) do
		if v.sid and v.sid ~= 0 then
			local pack = LDataPack.allocPacket()
			if pack then
				print("peakracecrossfb.create send actor enterFuBen sid:"..v.sid..",aid:"..v.aid..",fbhandle:"..fbhandle)
				LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
				LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_NeedEnter)
				LDataPack.writeInt(pack, v.aid)
				LDataPack.writeUInt(pack, fbhandle)
				LDataPack.writeChar(pack, idx)
				System.sendPacketToAllGameClient(pack, v.sid)
			end
			v.status = AStatus.sendCheck
		else
			v.status = AStatus.notEnter
		end
	end
end

--获取另外一个玩家ID
local function getPerAid(data, aid)
	for _,v in ipairs(data.aids) do
		if v.aid ~= aid then
			return v.aid
		end
	end
	return nil
end

--玩家死亡
local function onActorDie(ins, actor, killerHdl)
	if ins.is_end then return end
	local loseAid = LActor.getActorId(actor)
	local winAid = getPerAid(ins.data, loseAid)
	--发失败结果
	sendFuBenResult(actor, peakracecrosssystem.getActorName(winAid), false)
	local killer = LActor.getActor(LActor.getEntity(killerHdl))
	if killer and LActor.getFubenHandle(killer) == ins.handle then
		--发胜利结果
		sendFuBenResult(killer, peakracecrosssystem.getActorName(loseAid), true)
	end
	ins.data.fbCallBack(ins.data, winAid, loseAid)
	ins:setEnd()
end

--镜像怪死亡
local function onCloneRoleDie(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then 
		return
	end
	if LActor.cloneRoleEmpty(ins.scene_list[1])  then 
		local winAid = LActor.getActorId(actor)
		local loseAid = getPerAid(ins.data, winAid)
		ins.data.fbCallBack(ins.data, winAid, loseAid)
		sendFuBenResult(actor, peakracecrosssystem.getActorName(loseAid), true)
		ins:setEnd()
	end
end

--副本超时
local function onLose(ins)
	pkPowerOnCallBack(ins.data, ins.data.aids[1], ins.data.aids[2], ins.data.fbCallBack, true)
end

--玩家退出副本
local function onExitFb(ins, actor)
	if ins.is_end then return end
	local loseAid = LActor.getActorId(actor)
	local winAid = getPerAid(ins.data, loseAid)
	if winAid then
		local wactor = LActor.getActorById(winAid)
		if wactor and LActor.getFubenHandle(wactor) == ins.handle then
			--发胜利结果
			sendFuBenResult(wactor, peakracecrosssystem.getActorName(loseAid), true)
		end
		ins.data.fbCallBack(ins.data, winAid, loseAid)
	end
	ins:setEnd()
end

local function onServerEnterStatus(sId, sType, dp)
	local fbhandle = LDataPack.readUInt(dp)
	local aid = LDataPack.readInt(dp)
	local canEnter = LDataPack.readChar(dp) == 1
	local power = LDataPack.readInt64(dp) --战力
	local ins = instancesystem.getInsByHdl(fbhandle)
	if not ins then
		print("peakracecrossfb.onServerEnterStatus ins is nil,handle:"..tostring(fbhandle))
		return
	end
	print("peakracecrossfb.onServerEnterStatus aid:"..aid..",canEnter:"..tostring(canEnter))
	local okbypower = true
	local allOk = true
	local data = ins.data
	for _,v in ipairs(data.aids) do
		if v.aid == aid then
			v.status = canEnter and AStatus.canEnter or AStatus.notEnter
			v.power = power
		end
		if v.status == AStatus.sendCheck or v.status ~= AStatus.notEnter then
			okbypower = false
		end
		if v.status == AStatus.sendCheck then
			allOk = false
		end
	end
	if okbypower then
		ins:setEnd()
		ins:release()
		pkPowerOnCallBack(data, ins.data.aids[1], ins.data.aids[2], ins.data.fbCallBack, false)
	elseif allOk then
		--开启倒计时
		if baseCfg.readyTime then
			--停止副本AI
			Fuben.setIsNeedAi(ins.handle, false)
			--注册定时开启消息
			ins.data.startTime = System.getNowTime() + baseCfg.readyTime
			ins.data.saiEid = LActor.postScriptEventLite(nil, baseCfg.readyTime * 1000, function(_,handle)
				local ins = instancesystem.getInsByHdl(handle)
				if ins then
					Fuben.setIsNeedAi(ins.handle, true)
				end
				ins.data.saiEid = nil
			end, ins.handle)
		end
		for idx,v in ipairs(data.aids) do
			if v.status == AStatus.notEnter then
				--创建镜像
				local pos = baseCfg.pos[idx]
				LActor.createRoldClone(v.aid, ins.scene_list[1], pos.x, pos.y, v.sid)
				break
			end
		end
	end
end

--玩家进入副本的回调
local function onEnterFb(ins, actor)
	--获取玩家ID
	local aid = LActor.getActorId(actor)
	--设置阵营
	LActor.setCamp(actor, aid)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendFbStartTime)
	if npack then
		LDataPack.writeInt(npack, ins.data.startTime or 0)
		LDataPack.flush(npack)
	end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

--初始化全局数据
local function initGlobalData()	
	if System.isCommSrv() or System.getBattleSrvFlag() ~= bsBattleSrv then return end
	insevent.registerInstanceActorDie(baseCfg.fbid, onActorDie)
	insevent.regCloneRoleDie(baseCfg.fbid, onCloneRoleDie)
	insevent.registerInstanceLose(baseCfg.fbid, onLose)
	insevent.registerInstanceExit(baseCfg.fbid, onExitFb)
	insevent.registerInstanceEnter(baseCfg.fbid, onEnterFb) --玩家进入副本时
	insevent.registerInstanceOffline(baseCfg.fbid, onOffline)
	--游戏服服来的消息处理
    csmsgdispatcher.Reg(CrossSrvCmd.SCPeakRaceCmd, CrossSrvSubCmd.SCPeakRaceCmd_EnterStatus, onServerEnterStatus)
end

table.insert(InitFnTable, initGlobalData)
