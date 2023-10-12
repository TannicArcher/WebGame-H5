module("fieldplayer", package.seeall)
--遭遇战野外玩家
--[[
	数据定义:
	{
		robot = { --机器人数据
			[怪点索引] = {
				idx = 1,--怪点索引
				id = 1,--玩家ID
				level = 1,--玩家等级
				name, --玩家名字
			}
		}
		timerEid = {
			[怪点索引] = 刷怪定时器ID
		}
		initlv = 0, --初始化时候的关卡等级
	}
]]
--获取玩家数据
local function getData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		return nil
	end
	if var.fieldplayer == nil then
		var.fieldplayer = {}
	end
	if var.fieldplayer.timerEid == nil then
		var.fieldplayer.timerEid = {}
	end
	if var.fieldplayer.robot == nil then
		var.fieldplayer.robot = {}
	end
	return var.fieldplayer
end

local function clearData(actor)
	local var = LActor.getStaticVar(actor)
	var.fieldplayer = {}
end

local function getCacheData(actor)
    local var = LActor.getDynamicVar(actor)
    if var == nil then
        print("get fieldplayer cache data error. aid:"..LActor.getActorId(actor))
        return nil
    end

    if var.fieldplayer == nil then
        var.fieldplayer = {}
    end
    return var.fieldplayer
end

local function inTable(val, tab)
	for _,v in ipairs(tab or {}) do
		if v == val then
			return true
		end
	end
	return false
end

--让客户端出现一个野外玩家, maxNum:查找数量, sp:位置开始, ep:位置结束, posCfg:位置配置, conf:关卡配置
local function createFieldPlayer(actor, maxNum, sp, ep, posCfg, conf)
	print(LActor.getActorId(actor).." createFieldPlayer: maxNum="..tostring(maxNum)..", sp="..tostring(sp)..", ep="..tostring(ep))
	--获取匹配玩家
	local ret = System.FindFieldPlayer(actor, conf.matchLevel[1], conf.matchLevel[2], maxNum, conf.matchLevel[3])
	if ret == nil then return end
	local var = getData(actor)
	if var.robot == nil then var.robot = {} end
	--获取已经刷出来的所有玩家ID
	local list = {}
	for i = 1,maxNum do 
		if var.robot[i] then
			table.insert(list, var.robot[i].id)
		end
	end
	--刷出玩家
	for i = sp,ep do
		if posCfg[i] == nil then break end
		for k,aid in ipairs(ret) do 
			if inTable(aid, list) == false then 
				local level = LActor.getActorLevel(aid)
				level = level + 1000* LActor.getActorZhuanShengLevel(aid)
				local name = LActor.getActorName(aid)
				table.remove(ret, k)
				--行为类型
				local actionType = 0
				local rate = math.random(1,100)
				local atmp = 0
				for _,v in ipairs(conf.actionPro) do 
					atmp = atmp + v.rate
					if rate <= atmp then
						actionType = v.type
						break
					end
				end
				--是否侵略
				local isForay = math.random(1,100) <= conf.forayPro and 1 or 0
				--给客户端发送玩家的数据
				var.robot[i] = { idx = i, id = aid, level = level, name = name, actionType = actionType, isForay = isForay }
				local ox = 0
				if conf.escape and conf.escape.x then ox = conf.escape.x end
				local oy = 0
				if conf.escape and conf.escape.y then oy = conf.escape.y end
				LActor.createFieldPlayerData(actor, i, aid, posCfg[i][1], posCfg[i][2], actionType, isForay, conf.killNum or 0, ox, oy)
				break
			end
		end
	end
end

--定时刷出了一个机器人
local function reviveFieldPlayer(actor, idx)
	print(LActor.getActorId(actor).." reviveFieldPlayer, idx:"..idx)
	local var = getData(actor)
	local conf = SkirmishFieldPlayerConfig[var.initlv]
	if not conf then 
		print(LActor.getActorId(actor).." reviveFieldPlayer not have config level="..tostring(var.initlv))
		return 
	end
	var.timerEid[idx] = nil
	if not conf.intoPos[idx] then
		print(LActor.getActorId(actor).." reviveFieldPlayer not have intoPos config idx="..tostring(idx))
		return
	end
	createFieldPlayer(actor, #conf.enterPos, idx, idx, conf.intoPos, conf)
end

--初始化玩家
local function initFieldPlayer(actor)
	--print(LActor.getActorId(actor).." initFieldPlayer")
	--获取通关关数
	local level = LActor.getChapterLevel(actor)
	--获取关卡配置
	local conf = SkirmishFieldPlayerConfig[level]
	if not conf then 
		--print(LActor.getActorId(actor).." initFieldPlayer not have config level="..tostring(level))
		return 
	end
	--判断概率是否出机器人
	if math.random(1,100) > conf.robotPro then return end
	--随机出现初始个数
	local maxNum = #conf.enterPos
	local rnum = math.random(0,maxNum)
	print(LActor.getActorId(actor).." initFieldPlayer rnum="..tostring(rnum))
	if rnum > 0 then
		createFieldPlayer(actor, maxNum, 1, rnum, conf.enterPos, conf)
	end
	--注册定时器
	local var = getData(actor)
	var.initlv = level
	for i = rnum + 1, maxNum do
		var.timerEid[i] = LActor.postScriptEventLite(actor, math.random(conf.reviveTime[1], conf.reviveTime[2]) * 1000, reviveFieldPlayer, i)
		--print("initFieldPlayer: var.timerEid["..i.."]"..tostring(var.timerEid[i]))
	end
end

--清除所有并重新初始化
local function clearAllAndReInit(actor, init)
	local var = getData(actor)
	if var.initlv then
		local config = SkirmishFieldPlayerConfig[var.initlv]
		for k,v in ipairs(config.enterPos) do 
			if var.timerEid[k] then
				LActor.cancelScriptEvent(actor, var.timerEid[k])
				var.timerEid[k] = nil
			end
		end
		clearData(actor)
	end
	if init then
		initFieldPlayer(actor)
	end
end

--回馈对野外玩家的战斗结果
local function onResult(actor, packet)
	local id = LDataPack.readInt(packet)
	local result = LDataPack.readInt(packet)
	local var = getData(actor)
	if var.robot[id] == nil then
        print(LActor.getActorId(actor).." fieldplayersystem onResult id:"..id.." not have robot")
        return
    end
	local level = var.robot[id].level
    if level > 1000 then
        level = math.floor(level / 1000) * 1000
    elseif level > ZHUAN_SHENG_BASE_LEVEL then
        level = ZHUAN_SHENG_BASE_LEVEL
    end
	local conf = SkirmishRewardConfig[level]
	if conf == nil then print("fieldplayersystem onResult config is nil: level:".. level.. " aid:"..LActor.getActorId(actor)) return end
	
	--获取奖励
	local rewards = {}
    if result == 1 then
		local cache = getCacheData(actor)
		rewards = drop.dropGroup(conf.dropId)
		cache.rewards = rewards
		--记录增加红名值
		skirmish.changePkval(actor, nil, SkirmishBaseConfig.onesPkval)
		--/************************/--
		var.robot[id] = nil
		--获取通关关数
		local level = LActor.getChapterLevel(actor)
		local config = SkirmishFieldPlayerConfig[level]
		if not config then 
			print(LActor.getActorId(actor).." onResultFieldPlayer not have config level="..tostring(level))
			return 
		end
		--注册复活定时器
		if config.enterPos[id] and config.intoPos[id] then
			local t = math.random(config.reviveTime[1], config.reviveTime[2])
			var.timerEid[id] = LActor.postScriptEventLite(actor, t * 1000, reviveFieldPlayer, id)
			--print("FieldPlayer onResult: var.timerEid["..id.."]"..tostring(var.timerEid[id]))
		end
	else
		LActor.reEnterScene(actor)
		clearAllAndReInit(actor, true)
    end
	LActor.recover(actor)
	
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sFieldPlayerCmd_ResultDrop)
	if npack then
		LDataPack.writeInt(npack, id)
		LDataPack.writeInt(npack, result)
		LDataPack.writeShort(npack, #rewards)
		for _, a in ipairs(rewards) do
			LDataPack.writeInt(npack, a.type or 0)
			LDataPack.writeInt(npack, a.id or 0)
			LDataPack.writeInt(npack, a.count or 0)
		end
		LDataPack.flush(npack)
	end
end

--一个玩家机器人且地图了
local function reqPlayerOutside(actor, packet)
	local id = LDataPack.readInt(packet)
	local var = getData(actor)
	if var.robot[id] == nil then
		print(LActor.getActorId(actor).." reqPlayerOutside not have robot id="..tostring(id))
		return
	end
	if var.robot[id].actionType ~= 1 then --不是闯关机器人; 不会自己走掉的
		print(LActor.getActorId(actor).." reqPlayerOutside robot actionType("..tostring(var.robot[id].actionType)..") ~= 1 id="..tostring(id))
		return
	end
	var.robot[id] = nil
	if var.timerEid[id] then
		LActor.cancelScriptEvent(actor, var.timerEid[id])
		var.timerEid[id] = nil
	end
	local config = SkirmishFieldPlayerConfig[var.initlv]
	if not config then return end
	local t = math.random(config.reviveTime[1], config.reviveTime[2])
	var.timerEid[id] = LActor.postScriptEventLite(actor, t * 1000, reviveFieldPlayer, id)
	--print("filedplayer.reqPlayerOutside: var.timerEid["..id.."]"..tostring(var.timerEid[id]))
end

--领取掉落
local function onReqDrop(actor, packet)
    local cache = getCacheData(actor)
    if cache.rewards == nil then return end

    LActor.giveAwards(actor, cache.rewards, "fieldplayer drop")
    cache.rewards = nil
end

--进入副本的时候
local function onEnterFuben(actor, fubenId, isLogin)
	if isLogin then return end
	local init = (fubenId == 0)
	clearAllAndReInit(actor, init)
end

local function onLogin(actor)
	clearData(actor)
	initFieldPlayer(actor)
end

local function initGlobalData()
	if not System.isCommSrv() then return end
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeEnterFuben, onEnterFuben)
	netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cFieldPlayerCmd_ReportResult, onResult)
	netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cFieldPlayerCmd_PlayerOutside, reqPlayerOutside)
	netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cFieldPlayerCmd_ReqDrop, onReqDrop)
end
table.insert(InitFnTable, initGlobalData)

--测试指令
function gm_fieldplayer(actor, arg)
	LActor.reEnterScene(actor)
	clearAllAndReInit(actor, true)
end
