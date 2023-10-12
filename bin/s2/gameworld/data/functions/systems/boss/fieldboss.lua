module("fieldboss", package.seeall)


--[[
fieldBossData = {
	nextRefreshTime,
	id, -- boss组id 0为空
}]
 ]]

local id = 0
for _, conf in ipairs(FieldBossConfig) do
	if id >= conf.id then
		print("0000000000000000000000000000000000000000000000 fieldbossconfig id order error")
	end
	id = conf.id
end

--外部回调接口
function onDefeatBoss(actor)
	actorevent.onEvent(actor, aeFieldBoss)
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		print("get fieldBossData error.")
		return nil
	end

	if var.fieldBossData == nil  then
		var.fieldBossData = {}
		initRecordData(actor, var)
	end
	return var.fieldBossData
end

local function getDynamicData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end

	if var.fieldBossData == nil then
		var.fieldBossData = {}
	end
	return var.fieldBossData
end

function initRecordData(actor, var)
	var.fieldBossData.nextRefreshTime = 0
	var.fieldBossData.id = 0
end

local function getConfig(actor)
	local lv = LActor.getChapterLevel(actor)
	for _, conf in ipairs(FieldBossConfig) do
		if conf.level > lv then
			return conf
		end
	end
	return nil
end

function refreshBoss(actor, nextTime)
	--屏蔽该系统功能,2017年2月9日 12:49:30 屏蔽遗漏,成就事件可能会调用到achievetask.achieveFinishEvent
	if true then return end 
	print("====================================================refreshBoss")
	local data = getStaticData(actor)
	if data == nil then return end

	if data.id ~= 0 then return end
	--注册多个刷新事件时的验证
	if nextTime and data.nextRefreshTime ~= nextTime then
        return
    end

	local conf = getConfig(actor)
	if conf == nil then
		print("can't find field boss config, lv:"..LActor.getLevel(actor))
		return
	end
	data.id = conf.id

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sFieldBossCmd_UpdateBoss)
	LDataPack.writeInt(npack, data.id)
	LDataPack.flush(npack)
end

local function onResult(actor, packet)
	local result = LDataPack.readByte(packet)

	local data = getStaticData(actor)
	if data.id == 0 then
		print("field boss id is nil ,illegal result")
		return
	end

	if result == 0 then
		-- 如果客户端需要服务端给重置血量和场景，可以处理下
		LActor.reEnterScene(actor)
		return
	end
	LActor.recover(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sFieldBossCmd_UpdateBoss)
	LDataPack.writeInt(npack, 0)
	LDataPack.flush(npack)

	npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sFieldBossCmd_AffirmResult)
	LDataPack.writeByte(npack, result)
	--奖励列表
	local conf = FieldBossConfig[data.id]
	if not conf then print("field boss config not found. id:".. data.id) return end

	print("=================conf.dropid:"..conf.dropId)
	local ret = drop.dropGroup(conf.dropId)
	print("=================count:"..#ret)
	LDataPack.writeShort(npack,#ret)
	if #ret ~= 0 then
		local cache = getDynamicData(actor)
		cache.reward = ret
		for _, v in ipairs(ret) do
			LDataPack.writeData(npack, 3,
				dtInt, v.type or 0,
				dtInt, v.id or 0,
				dtInt, v.count or 0
			)
			--print(string.format("drop:%d %d %d", v.type, v.id, v.count))
		end
	end
	LDataPack.flush(npack)
    onDefeatBoss(actor)
    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "fieldboss result", tostring(result), tostring(data.id), "", result == 1 and "win" or "lose", "", "")
	--修改记录
	data.id = 0
	--下一次时间
	

	conf = getConfig(actor)
	if not conf then print("field boss config not found. lv:".. LActor.getChapterLevel(actor)) return end

	local randtime = (System.getRandomNumber(conf.refreshTimeMax-conf.refreshTimeMin) + conf.refreshTimeMin) * 60
	data.nextRefreshTime = System.getNowTime() +randtime

	LActor.postScriptEventLite(actor, randtime * 1000 , refreshBoss, data.nextRefreshTime)
	
end

local function onLogin(actor)
	if true then return end --屏蔽该系统功能,2017年2月9日 12:49:30
	local data = getStaticData(actor)
	if data.id ~= 0 then
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sFieldBossCmd_UpdateBoss)
		LDataPack.writeInt(npack, data.id)
		LDataPack.flush(npack)
		return
	end

	if (data.nextRefreshTime or 0)== 0 then
		local conf = getConfig(actor)
		if conf == nil then print("field boss config not found.lv:".. LActor.getChapterLevel(actor)) return end

		local randtime = (System.getRandomNumber(conf.refreshTimeMax-conf.refreshTimeMin) + conf.refreshTimeMin) * 60
		data.nextRefreshTime = System.getNowTime() +randtime
		LActor.postScriptEventLite(actor, randtime * 1000, refreshBoss, data.nextRefreshTime)
	else
		local now = System.getNowTime()
		if (data.nextRefreshTime)> now then
			LActor.postScriptEventLite(actor, (data.nextRefreshTime - now)* 1000, refreshBoss, data.nextRefreshTime)
		else
			refreshBoss(actor)
		end
    end

    local cache = getDynamicData(actor)
    if cache.reward ~= nil then
        LActor.giveAwards(actor, cache.reward, "fieldboss reward on login")
        cache.reward = nil
    end
end

local function onReqReward(actor)
	local cache = getDynamicData(actor)
	if cache.reward == nil then
		print("请求野外boss奖励失败，没有缓存奖励 actor:"..LActor.getActorId(actor))
		return
	end

	LActor.giveAwards(actor, cache.reward, "fieldboss reward")
	cache.reward = nil
end

actorevent.reg(aeUserLogin, onLogin)

netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cFieldBossCmd_ReportResult, onResult)
netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cFieldBossCmd_ReqReward, onReqReward)

function gmShowRefreshTime(actor)
    local data = getStaticData(actor)
    print("----------------------------------------")
    local now = System.getNowTime()
    local t = (data.nextRefreshTime or 0) - now
    if t < 0 then t = 0 end

    print(t)
    print("----------------------------------------")
end
