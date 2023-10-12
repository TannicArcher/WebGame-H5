--巅峰赛季副本(游戏服)
module("peakracefb", package.seeall)

local baseCfg = PeakRaceBase

--检测一个玩家是否能进入战斗副本
local function checkPlayerCanIn(actor)
	if not actor then return false end
	if LActor.isInFuben(actor) then return false end
	return true
end

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
local function pkPowerOnCallBack(data, aid1, aid2, callback, fblose)
	local a1power = LActor.getActorPower(aid1)
	local a2power = LActor.getActorPower(aid2)
	print("peakracefb.pkPowerOnCallBack aid1:"..aid1.."("..a1power..") aid2:"..aid2.."("..a1power..")")
	local winAid = nil
	local loseAid = nil
	if a1power > a2power then
		winAid = aid1
		loseAid = aid2
	else
		winAid = aid2
		loseAid = aid1
	end
	callback(data, winAid, loseAid)
	if fblose then
		local wactor = LActor.getActorById(winAid)
		if wactor then
			--发胜利结果
			sendFuBenResult(wactor, LActor.getActorName(loseAid), true)
		end
		local lactor = LActor.getActorById(loseAid)
		if lactor then
			--发失败结果
			sendFuBenResult(lactor, LActor.getActorName(winAid), false)
		end
	end
end

--创建一个副本
function create(aid1, aid2, callback, data)
	--拿到两个玩家
	local actor1 = LActor.getActorById(aid1)
	local actor2 = LActor.getActorById(aid2)
	local a1c = checkPlayerCanIn(actor1)
	local a2c = checkPlayerCanIn(actor2)
	--双方不在线或者都在副本里面比战力
	if not a1c and not a2c then 
		pkPowerOnCallBack(data, aid1, aid2, callback)
		return
	else --肯定有一个可以进入副本的
		local fbhandle = Fuben.createFuBen(baseCfg.fbid)
		local ins = instancesystem.getInsByHdl(fbhandle)
		if not ins then
			print("peakracefb.create ins is nil, create fuben error")
			return
		end
		ins.data = data
		if not ins.data then ins.data = {} end
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
		--记录玩家
		ins.data.aids = {}
		table.insert(ins.data.aids, aid1)
		table.insert(ins.data.aids, aid2)
		--记录回调函数
		ins.data.fbCallBack = callback
		local pos = baseCfg.pos[1]
		if a1c then
			LActor.enterFuBen(actor1, fbhandle, 0, pos.x, pos.y)
			LActor.setCamp(actor1, aid1)
		else --创建镜像
			LActor.createRoldClone(aid1, ins.scene_list[1], pos.x, pos.y)
		end
		pos = baseCfg.pos[2]
		if a2c then
			LActor.enterFuBen(actor2, fbhandle, 0, pos.x, pos.y)
			LActor.setCamp(actor2, aid2)
		else --创建镜像
			LActor.createRoldClone(aid2, ins.scene_list[1], pos.x, pos.y)
		end
	end
end

--玩家死亡
local function onActorDie(ins, actor, killerHdl)
	if ins.is_end then return end
	local loseAid = LActor.getActorId(actor)
	local winAid = nil
	for _,aid in ipairs(ins.data.aids) do
		if aid ~= loseAid then
			winAid = aid
			break
		end
	end
	--发失败结果
	sendFuBenResult(actor, LActor.getActorName(winAid), false)
	local killer = LActor.getActor(LActor.getEntity(killerHdl))
	if killer and LActor.getFubenHandle(killer) == ins.handle then
		--发胜利结果
		sendFuBenResult(killer, LActor.getActorName(loseAid), true)
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
		local loseAid = nil
		for _,aid in ipairs(ins.data.aids) do
			if aid ~= winAid then
				loseAid = aid
				break
			end
		end
		ins.data.fbCallBack(ins.data, winAid, loseAid)
		sendFuBenResult(actor, LActor.getActorName(loseAid), true)
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
	local winAid = nil
	for _,aid in ipairs(ins.data.aids) do
		if aid ~= loseAid then
			winAid = aid
			break
		end
	end
	if winAid then
		local wactor = LActor.getActorById(winAid)
		if wactor and LActor.getFubenHandle(wactor) == ins.handle then
			--发胜利结果
			sendFuBenResult(wactor, LActor.getActorName(loseAid), true)
		end
		ins.data.fbCallBack(ins.data, winAid, loseAid)
	end
	ins:setEnd()
end

--跨服需要玩家进入战场
local function onCrossNeedEnter(sId, sType, dp)
	local aid = LDataPack.readInt(dp) --读取玩家ID
	local fbhandle = LDataPack.readUInt(dp) --读取副本handle
	local idx = LDataPack.readChar(dp) --读取左边还是右边
	local actor = LActor.getActorById(aid)
	local canEnter = checkPlayerCanIn(actor)
	local pack = LDataPack.allocPacket()
	if pack then
		print("peakracefb.onCrossNeedEnter send actor enterFuBen status aid:"..aid..",canEnter:"..tostring(canEnter)..",fbhandle:"..fbhandle)
		LDataPack.writeByte(pack, CrossSrvCmd.SCPeakRaceCmd)
		LDataPack.writeByte(pack, CrossSrvSubCmd.SCPeakRaceCmd_EnterStatus)
		LDataPack.writeUInt(pack, fbhandle)
		LDataPack.writeInt(pack, aid)
		LDataPack.writeChar(pack, canEnter and 1 or 0)
		LDataPack.writeInt64(pack, LActor.getActorPower(aid))
		System.sendPacketToAllGameClient(pack, sId)
	end
	if actor and canEnter then
		--获取坐标
		local pos = baseCfg.pos[idx]
		--把玩家传到副本里面
		LActor.loginOtherSrv(actor, csbase.GetBattleSvrId(bsBattleSrv), fbhandle, 0, pos.x, pos.y)
	end
end

local function onOffline(ins, actor)
	LActor.exitFuben(actor)
end

--玩家进入副本的回调
local function onEnterFb(ins, actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_PeakRace, Protocol.sPeakRace_SendFbStartTime)
	if npack then
		LDataPack.writeInt(npack, ins.data.startTime or 0)
		LDataPack.flush(npack)
	end
end

--初始化全局数据
local function initGlobalData()
	if not System.isCommSrv() then return end
	insevent.registerInstanceActorDie(baseCfg.fbid, onActorDie)
	insevent.regCloneRoleDie(baseCfg.fbid, onCloneRoleDie)
	insevent.registerInstanceLose(baseCfg.fbid, onLose)
	insevent.registerInstanceExit(baseCfg.fbid, onExitFb)
	insevent.registerInstanceOffline(baseCfg.fbid, onOffline)
	insevent.registerInstanceEnter(baseCfg.fbid, onEnterFb) --玩家进入副本时
	--跨服服来的消息处理
    csmsgdispatcher.Reg(CrossSrvCmd.SCPeakRaceCmd, CrossSrvSubCmd.SCPeakRaceCmd_NeedEnter, onCrossNeedEnter)
end

table.insert(InitFnTable, initGlobalData)
