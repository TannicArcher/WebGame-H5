--红包雨
module("subactivitytype12", package.seeall)


--[[ 全局保存数据
     hongbao
	{
	   index   索引
	   endTime 剩余时间
	   sex      性别
	   job      职业
	   name     名字
	   srvId    服务器id
       blessWord   祝福语
       count   已领取次数
       rewardRecord    领取记录
       {
	     [actorid] = 1
       }

       ybRecord    领元宝记录
       {
	      sex      性别
	      job      职业
	      name     名字
	      num      元宝数量
	     }
       }
	}

	record
	{
	 name     名字
	 srvId    服务器id
	 index   索引
	}

	--个人数据
	score   积分
--]]


local subType = 12
local RECORDMAX = 20   --最大记录条数
local HongBaoMax = 20  --登陆最大领取数量
local SINGLE = 1       --单个红包刷新
local TOTAL = 2        --全部红包刷新

--检测是否可以领取红包
local function checkCanAward(actor, info)
	if info.rewardRecord and info.rewardRecord[LActor.getActorId(actor)] then
		return false
	end
	return true
end

local function onReCharge(id, conf)
	return function(actor, val)
		if activitysystem.activityTimeIsEnd(id) then return end

		local var = activitysystem.getSubVar(actor, id)

		var.score = (var.score or 0) + math.floor(val/100)
		activitysystem.sendActivityData(actor, id)
	end
end

--下发数据
local function writeRecord(npack, record, conf, id, actor)
    if nil == record then record = {} end
    LDataPack.writeInt(npack, record.score or 0)
    local gVar = activitysystem.getGlobalVar(id)
    LDataPack.writeShort(npack, #(gVar.record or {}))
    for _, info in ipairs(gVar.record or {}) do
    	LDataPack.writeShort(npack, info.index)
    	LDataPack.writeString(npack, info.name)
    	LDataPack.writeInt(npack, info.srvId)
    end
end

local function sendBaseInfo(actor, id)
	local gVar = activitysystem.getGlobalVar(id)
	if not gVar.hongbao then gVar.hongbao = {} end

	--先保存当前位置，后面再插入数据
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateHongBao)

	LDataPack.writeInt(npack, id)
    LDataPack.writeShort(npack, TOTAL)
    local oldPos = LDataPack.getPosition(npack)
    LDataPack.writeShort(npack, 0)

    local count = 0
    for id, info in pairs(gVar.hongbao) do
        if (info.endTime or 0) > System.getNowTime() then
	        if true == checkCanAward(actor, info) then
	            LDataPack.writeWord(npack, id)
	            LDataPack.writeInt(npack, info.endTime)
	            count = count + 1
	            if count > HongBaoMax then
	            	print(LActor.getActorId(actor).." subactivitytype12.sendBaseInfo count > 20")
	            	break
	            end
	        end
	    else
	    	gVar.hongbao[id] = nil
	    end
    end

    local newPos = LDataPack.getPosition(npack)

     --往前面插入数据
    LDataPack.setPosition(npack, oldPos)
    LDataPack.writeShort(npack, count)
    LDataPack.setPosition(npack, newPos)

    LDataPack.flush(npack)
end

--type1表示增加新红包记录，type2表示增加新领取者记录
local function addNewRecord(type, id, hongbaoId, actorId, isGold, num, config, job, sex, index, srvId, name, word)
	local gVar = activitysystem.getGlobalVar(id)
	if not gVar.hongbao then gVar.hongbao = {} end
	if not gVar.record then gVar.record = {} end

	if 1 == type then
		gVar.hongbaoId = (gVar.hongbaoId or 0) + 1
	    if gVar.hongbaoId > 65535 then gVar.hongbaoId = 0 end  ----不能大于unsigned short
		local endTime = System.getNowTime() + config.exitTime
		gVar.hongbao[gVar.hongbaoId] = {job=job, name=name, index=index, sex=sex, srvId=srvId, blessWord=word, endTime=endTime}

		--记录发红包者,太多就移除第一条
		if config.isRecord then
			if #gVar.record >= RECORDMAX then table.remove(gVar.record, 1) end
			table.insert(gVar.record, {name=name, srvId=srvId, index=index})
		end

		--广播新红包
		local npack = LDataPack.allocBroadcastPacket(Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateHongBao)
		LDataPack.writeInt(npack, id)
	    LDataPack.writeShort(npack, SINGLE)
	    LDataPack.writeShort(npack, 1)
	    LDataPack.writeWord(npack, gVar.hongbaoId)
		LDataPack.writeInt(npack, endTime)

	    System.broadcastData(npack)

	    print("subactivitytype12.addNewRecord send hongbao success index:"..tostring(index)..", name:"..tostring(name)
	    	..", srvId:"..tostring(srvId)..", hongbaoId:"..tostring(gVar.hongbaoId))
	else
		if not gVar.hongbao[hongbaoId].rewardRecord then gVar.hongbao[hongbaoId].rewardRecord = {} end
		gVar.hongbao[hongbaoId].rewardRecord[actorId] = 1

		if not isGold then
			if not gVar.hongbao[hongbaoId].ybRecord then gVar.hongbao[hongbaoId].ybRecord = {} end
			table.insert(gVar.hongbao[hongbaoId].ybRecord, {name=name, job=job, sex=sex, num=num})
		end
	end
end

--判断本服还是跨服做不同的处理
local function handleInfo(actor, id, config, blessWord)
	local job = LActor.getJob(actor)
	local sex = LActor.getSex(actor)
	local srvId = LActor.getServerId(actor)
	local name = LActor.getName(actor)

	if config.isCross and csbase.hasCross then
		local npack = LDataPack.allocPacket()
		LDataPack.writeByte(npack, CrossSrvCmd.SCActivityCmd)
		LDataPack.writeByte(npack, CrossSrvSubCmd.SCActivityCmd_BroadCast)

		LDataPack.writeInt(npack, id)
		LDataPack.writeShort(npack, job)
		LDataPack.writeShort(npack, sex)
		LDataPack.writeShort(npack, config.index)
		LDataPack.writeInt(npack, srvId)
		LDataPack.writeString(npack, name)
		LDataPack.writeString(npack, blessWord or "")

		System.sendPacketToAllGameClient(npack, csbase.GetBattleSvrId(bsBattleSrv))
	else
		addNewRecord(1, id, nil, nil, nil, nil, config, job, sex, config.index, srvId, name, blessWord)
	end
end

--处理跨服红包
local function onCrossInfo(id, typeconfig, npack)
	local conf = typeconfig[id]
    if nil == conf then
        print("subactivitytype12.onCrossInfo:conf is nil, id:"..tostring(id))
        return
    end

	local job = LDataPack.readShort(npack)
	local sex = LDataPack.readShort(npack)
	local index = LDataPack.readShort(npack)
	local srvId = LDataPack.readInt(npack)
	local name = LDataPack.readString(npack)
	local word = LDataPack.readString(npack)

	addNewRecord(1, id, nil, nil, nil, nil, conf[index], job, sex, index, srvId, name, word)
end

--查询红包信息
local function onReqInfo(id, typeconfig, actor, record, packet)
	local actorId = LActor.getActorId(actor)
	local hongbaoId = LDataPack.readWord(packet)
	local gVar = activitysystem.getGlobalVar(id)
	if not gVar.hongbao then gVar.hongbao = {} end

	--红包是否存在
	local res = true
	if not gVar.hongbao[hongbaoId] then
		print("subactivitytype12.onReqInfo: id error, actorId:"..tostring(actorId)..",id:"..tostring(hongbaoId))
		res = false
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, Protocol.sActivityCmd_UpdateInfo)
	LDataPack.writeInt(npack, id)
	LDataPack.writeByte(npack, res and 1 or 0)
	if res then
		local info = gVar.hongbao[hongbaoId]
		LDataPack.writeWord(npack, hongbaoId)
		LDataPack.writeShort(npack, info.job or 0)
		LDataPack.writeShort(npack, info.sex or 0)
		LDataPack.writeShort(npack, info.index)
		LDataPack.writeInt(npack, info.srvId)
		LDataPack.writeString(npack, info.name)
		LDataPack.writeString(npack, info.blessWord or "")
	end

	LDataPack.flush(npack)
end

local function getReward(id, typeconfig, actor, hongbaoId)
	local actorId = LActor.getActorId(actor)

	local gVar = activitysystem.getGlobalVar(id)
	if not gVar.hongbao then gVar.hongbao = {} end

	--红包存不存在
	if not gVar.hongbao[hongbaoId] then
		print("subactivitytype12.getReward: hongbao not exist, actorId:"..tostring(actorId)..", id:"..tostring(hongbaoId))
		return false
	end

	local data = gVar.hongbao[hongbaoId]

	local conf = typeconfig[id][data.index]
	if not conf then print("subactivitytype12.getReward: conf nil, actorId:"..tostring(actorId)..", index:"..tostring(data.index)) return false end

	--是否已过期
	if data.endTime < System.getNowTime() then
		print("subactivitytype12.getReward: endTime invaild, actorId:"..tostring(actorId)..", id:"..tostring(hongbaoId))
		return false
	end

	--是否领过了
	if false == checkCanAward(actor, data) then
		print("subactivitytype12.getReward: already reward, actorId:"..tostring(actorId)..", id:"..tostring(hongbaoId))
		return false
	end

	--判断是领红包还是金币
	local isGold = false
	if conf.ybCount and (data.count or 0) >= conf.ybCount then isGold = true end

	local yb = 0
	local gold = 0
	if isGold then
		gold = math.random(conf.goldRandom[1], conf.goldRandom[2])
		LActor.changeCurrency(actor, NumericType_Gold, gold, "type12,index "..tostring(data.index))
	else
		yb = math.random(conf.ybRandom[1], conf.ybRandom[2])
		LActor.changeCurrency(actor, NumericType_YuanBao, yb, "type12,index "..tostring(data.index))
	end

	data.count = (data.count or 0) + 1

	addNewRecord(2, id, hongbaoId, actorId, isGold, yb, nil, LActor.getJob(actor), LActor.getSex(actor), nil, nil, LActor.getName(actor))
	return true, yb, gold
end

local function onGetReward(id, typeconfig, actor, record, packet)
	local actorId = LActor.getActorId(actor)
    local index = LDataPack.readShort(packet)
    local type = LDataPack.readShort(packet)
    local blessWord = LDataPack.readString(packet)

    --type 1发红包 2领红包
    if 1 == type then
    	local conf = typeconfig[id][index]
    	if not conf then print("subactivitytype12.onGetReward: conf nil, actorId:"..tostring(actorId)..", index:"..tostring(index)) return end

    	--积分够不够
    	if (record.score or 0) < conf.score then
    		print("subactivitytype12.onGetReward: score not enough, actorId:"..tostring(actorId)..", score:"..tostring(record.score or 0))
    		return
    	end

    	--祝福语是不是太啰嗦了
    	if blessWord and friendsystem.utf8len(blessWord) > conf.wordCount then
    		print("subactivitytype12.onGetReward: too much word, actorId:"..tostring(actorId))
    		return
    	end

    	record.score = record.score - conf.score

    	handleInfo(actor, id, conf, blessWord)

    	activitysystem.sendActivityData(actor, id)

    elseif 2 == type then
    	local isSuccess, yb, gold = getReward(id, typeconfig, actor, index)
		local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity,  Protocol.sActivityCmd_GetRewardResult)
		LDataPack.writeByte(npack, isSuccess and 1 or 0)
		LDataPack.writeInt(npack, id)
		LDataPack.writeShort(npack, index)
		LDataPack.writeInt(npack, yb or 0)
		LDataPack.writeInt(npack, gold or 0)

		if isSuccess then
			local data = activitysystem.getGlobalVar(id).hongbao[index]
			LDataPack.writeShort(npack, #(data.ybRecord or {}))
			for _, info in pairs(data.ybRecord or {}) do
				LDataPack.writeShort(npack, info.job or 0)
				LDataPack.writeShort(npack, info.sex or 0)
				LDataPack.writeString(npack, info.name or "")
				LDataPack.writeInt(npack, info.num or 0)
			end
		else
			LDataPack.writeShort(npack, 0)
		end

		LDataPack.flush(npack)
    else
    	print("subactivitytype12.onGetReward: type error, actorId:"..tostring(actorId))
    end
end

local function initFunc(id, conf)
    actorevent.reg(aeRecharge, onReCharge(id, conf))
end

--玩家登陆回调（在发送所有活动的基础信息(协议25-1)之后）
subactivities.actorLoginFuncs[subType] = function(actor, type, id)
    if activitysystem.activityTimeIsEnd(id) then return end
    sendBaseInfo(actor, id)
end

subactivities.regConf(subType, ActivityType12Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)
subactivities.regGetRewardFunc(subType, onGetReward)
subactivities.regReqInfoFunc(subType, onReqInfo)
subactivities.regReqCrossFunc(subType, onCrossInfo)

