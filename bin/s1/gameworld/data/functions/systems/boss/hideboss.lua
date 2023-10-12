module("hideboss", package.seeall)

local p = Protocol
--[[个人静态变量
	hideVal = 当前隐藏值(祝福值)
	hideBossId = 当前可挑战的隐藏boss的ID
	hideBossTime = 当前可挑战的隐藏boss的结束时间
]]
local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if nil == var.hideboss then var.hideboss = {} end
    return var.hideboss
end

--改变隐藏值
local function changeHideVal(actor, val)
	local var = getStaticData(actor)
	print(LActor.getActorId(actor).." hideboss.changeHideVal val:"..val)
	var.hideVal = (var.hideVal or 0) + val
end

--获取当前隐藏值
local function getHideVal(actor)
	local var = getStaticData(actor)
	return var.hideVal or 0
end

--下发隐藏boss的信息
local function sendHideBossInfo(actor)
	local var = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sHideBoss_Info)
    LDataPack.writeInt(npack, var.hideBossId or 0)
	LDataPack.writeInt(npack, var.hideBossTime or 0)
    LDataPack.flush(npack)
end

--监听到一次boss结算
local function onBossFinish(actor, cfgId, fbId, isbelong)
	print(LActor.getActorId(actor).." hideboss.onBossFinish cfgId:"..cfgId)
	local cfg = HideBossConfig[cfgId]
	if not cfg then return end
	if isbelong then
		changeHideVal(actor, cfg.belongHideVal or 0)
		local need = cfg.needHideVal and cfg.needHideVal[LActor.getZhuanShengLevel(actor)]
		if need then
			--这里检测是否需要刷出一个挑战boss
			local hval = getHideVal(actor)
			if hval >= need then
				if not cfg.rate or cfg.rate >= math.random(1,10000) then
					changeHideVal(actor, 0-cfg.costVal)
					local var = getStaticData(actor)
					var.hideBossId = cfgId
					var.hideBossTime = (cfg.time or 0) + System.getNowTime()
					sendHideBossInfo(actor)
					--发广播
					if cfg.noticeId then
						noticemanager.broadCastNotice(cfg.noticeId, LActor.getName(actor))
					end
				end
			end
		end
	else
		changeHideVal(actor, cfg.joinHideVal or 0)
	end
end

--副本胜利的时候
local function onWin(ins)
	local actor = ins:getActorList()[1]
	if actor == nil then print("hideboss.onWin can't find actor") return end
	if ins.data and ins.data.dropId then
		rewards = drop.dropGroup(ins.data.dropId)	
		instancesystem.setInsRewards(ins, actor, rewards)
	end
end

--请求进入副本
local function onReqEnter(actor, packt)
	local var = getStaticData(actor)
	if not var.hideBossId then
		print(LActor.getActorId(actor).." hideboss.onReqEnter is not hideBossId")
		return
	end
	--判断是否已经过期
	if (var.hideBossTime or 0) < System.getNowTime() then
		print(LActor.getActorId(actor).." hideboss.onReqEnter is timeOver")
		return
	end
	--获取配置
	local cfg = HideBossConfig[var.hideBossId]
	if not cfg then
		print(LActor.getActorId(actor).." hideboss.onReqEnter is not config id:"..var.hideBossId)
		return
	end
	--创建副本
	local hfuben = Fuben.createFuBen(cfg.fbid)
	if not hfuben or hfuben == 0 then
		print(LActor.getActorId(actor).." hideboss.onReqEnter fuben create failure id:"..cfg.fbid)
		return
	end
	local ins = instancesystem.getInsByHdl(hfuben)
	if not ins then
		print(LActor.getActorId(actor).." hideboss.onReqEnter fuben create failure not ins id:"..cfg.fbid)
		return
	end
	if not ins.data then ins.data = {} end
	ins.data.dropId = cfg.dropId
	--进入副本
	LActor.enterFuBen(actor, hfuben)
	--清空数据
	var.hideBossId = nil
	var.hideBossTime = nil
	--下发信息
	sendHideBossInfo(actor)
end

--玩家登陆的时候
local function onLogin(actor)
	sendHideBossInfo(actor)
end

--启动初始化
local function initGlobalData()
	if not System.isCommSrv() then return end
    --副本事件
	local isRegFbId = {}
    for _, conf in pairs(HideBossConfig) do
		if not isRegFbId[conf.fbid] then  
			isRegFbId[conf.fbid] = true
			insevent.registerInstanceWin(conf.fbid, onWin)
		end
    end
	isRegFbId = nil
	--玩家事件
    actorevent.reg(aeUserLogin, onLogin)
    actorevent.reg(aeWorldBoss, onBossFinish)
	--客户端请求处理
	netmsgdispatcher.reg(p.CMD_Boss, p.cHideBoss_ReqEnter, onReqEnter) --获取boss列表数据
end

table.insert(InitFnTable, initGlobalData)

--hideboss
gmHandle = function(actor, args)
	local cmd = args[1]
	if cmd == 'v' then
		changeHideVal(actor, tonumber(args[2]))
	elseif cmd == 'e' then
		onReqEnter(actor, nil)
	end
end
