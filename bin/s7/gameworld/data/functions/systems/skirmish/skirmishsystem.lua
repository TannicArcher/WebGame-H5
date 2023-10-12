module("skirmish", package.seeall)


--[[    遭遇战数据
encounterData = {
	lastRefreshTime, --上一次刷新时间
	challengeCount, --每日挑战次数
	winCount, -- 每日胜利次数
	--actors = {} --[3]    --注意不是lua里的table 要用数组形式遍历
	actors = {id, name,level, pos}[3]
	records = {{time, result, name, exp, gold, fame, essence}[5]} --userdata
	recordsCount
	fame    --每日声望
	refreshCount --刷新次数
	pkval --红名值
}

encounterCache = {
    rewards = {}
}
 ]]
local SkirmishRefreshTime = (SkirmishBaseConfig.refreshTime or 12) * 60 
local SkirmishListSize = SkirmishBaseConfig.listSize or 3
local failedRewardRate = SkirmishBaseConfig.failedRewardRate or 0.25

local maxFame = 0
for _, fame in pairs(SkirmishFameConfig) do
    if maxFame < fame.fame then
        maxFame = fame.fame
    end
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then
		print("get encounter static data error. aid:"..LActor.getActorId(actor))
		return nil
	end

	if var.encounterData == nil then
		var.encounterData = {}
		initRecordData(actor, var)
	end
	return var.encounterData
end

local function getCacheData(actor)
    local var = LActor.getDynamicVar(actor)
    if var == nil then
        print("get encounter cache data error. aid:"..LActor.getActorId(actor))
        return nil
    end

    if var.encounterData == nil then
        var.encounterData = {}
    end
    return var.encounterData
end

function initRecordData(actor, var)
	var.encounterData.lastRefreshTime = System.getNowTime()
	var.encounterData.actors  = {}
	var.encounterData.records = {}
	var.encounterData.recordsCount = 0
end

local function sendActorData(actor,index, id, pos, level, name, attrper)
	LActor.createSkirmishData(actor, index, id, level, name, attrper or 0)
end

local function updateRank(actor, level)
	if skirmishranking.RANK_MIN_LEVEL > level then return end
    local data = getStaticData(actor)
	if data.fame and data.fame > 0 then
		skirmishranking.setRankingList(actor, data.fame)
	end
end

local function getActorDataCount(actor)
	local data = getStaticData(actor)
	if data == nil then return 0 end

	local count = 0
	for i = 1,SkirmishListSize do
		if data.actors[i] ~= nil then
			count = count + 1
		end
	end
	return count
end

local function addActor(actor, data, id, attrper)
	print("skirmish addActor.."..tostring(LActor.getActorName(id)).."id:"..LActor.getActorId(actor))
	local level, index, name, pos = 0,0,nil,0
	if LActor.getActorId(actor) == id then
		--随机等级
		level = LActor.getLevel(actor) + math.random(0,3)
        if level > MAX_ACTOR_LEVEL then level = MAX_ACTOR_LEVEL end
		level = level + 1000* LActor.getZhuanShengLevel(actor)
		if attrper then 
			name = SkirmishBaseConfig.onesName
		else
			--随机名字
			local count = 0
			while true do
				if 50 < count then 
					print("skirmish.addActor: while getRandomName count is more than 50!!!!!!!!!!!!!")
					break 
				end 
				name = LActorMgr.getRandomName(math.random(0, 1))
				if name == nil then print("add skirmish actor err. can't get random name") return end
				if not LActorMgr.nameHasUser(actorname) then
					local valid = true
					for i = 1,SkirmishListSize do
						if data.actors[i] ~= nil and data.actors[i].name == name then
							valid = false
							break
						end
					end
					if valid then
						break
					end
				end

				count = count + 1
			end
		end
	else
		level = LActor.getActorLevel(id)
        level = level + 1000* LActor.getActorZhuanShengLevel(id)
		name = LActor.getActorName(id)
	end

	--保存
	for i = 1,SkirmishListSize do
		if data.actors[i] == nil then
			index = i
			data.actors[i] = {id=id, level = level, pos = 0, name = name, attrper = attrper}
			break
		end
	end
	sendActorData(actor, index, id ,pos, level, name, attrper)
    --print("skirmish sendActorData index"..index.." pos:"..pos.." level:"..level.." name:"..name)
end


--查找遭遇战玩家id
local function findSkirmish(self, existList)
	local level = LActor.getChapterLevel(self)
	local selfid = LActor.getActorId(self)
	local randomlist = {}

	local ret = System.findSkirmish(self)
    if ret == nil then ret = {} end

	while #ret < SkirmishListSize do
		table.insert(ret, LActor.getActorId(self))
    end

    for _, i in ipairs(ret) do
        local valid = true
        for _, id in ipairs(existList) do
            if i == id and i ~= selfid then
                valid = false
            end
        end
        if valid then
            return i
        end
    end

    return selfid
end

function refreshActor(actor, lastRefreshTime )
	--print("###############0")
	local data = getStaticData(actor)
	if data == nil then return end

	--print("###############1 ".. data.lastRefreshTime)
	--print("###############1 ".. lastRefreshTime)
	if data.lastRefreshTime ~= lastRefreshTime then return end

	local list = {}
	for i = 1,SkirmishListSize do
		if data.actors[i] ~= nil then
			table.insert(list, data.actors[i].id)
		end
	end
	--检查条件
	local count = #list
	--print("###############2".. count)
	if count >= SkirmishListSize then
		return false
	end

    --[[
	--检测红名值是否已经上限
	if (data.pkval or 0) >= SkirmishBaseConfig.maxPkval then
		print("skirmishsystem, refreshActor: data.pkval("..data.pkval..") >= SkirmishBaseConfig.maxPkval("..SkirmishBaseConfig.maxPkval..") return")
		return false
	end
	]]

	local aid = findSkirmish(actor, list)
	if aid ~= nil then
		--print("###############4   ".. count)
		--print("###############5   ".. aid)
		addActor(actor, data, aid)
		data.lastRefreshTime = System.getNowTime()
		if count + 1 < SkirmishListSize then
			LActor.postScriptEventLite(actor, SkirmishRefreshTime * 1000, refreshActor, data.lastRefreshTime)
		else
			data.lastRefreshTime = System.getNowTime() - SkirmishRefreshTime
		end

		updateInfo(actor)
	end
end

function updateInfo(actor)
	local data = getStaticData(actor)
	if data == nil then return end
	--下发数据
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sSkirmishCmd_InitData)
	if npack == nil then return end
	LDataPack.writeInt(npack, data.lastRefreshTime + SkirmishRefreshTime)
    LDataPack.writeInt(npack, data.challengeCount or 0)
    LDataPack.writeInt(npack, data.winCount or 0)
    LDataPack.writeInt(npack, data.refreshCount or 0)
	LDataPack.writeInt(npack, data.pkval or 0)
	--... 挑战次数
	--... 其他信息等等
	LDataPack.flush(npack)
end

--查看第一个遭遇玩家是否还存在
function getAttrperIndex(actor)
	local data = getStaticData(actor)
	for i=1, SkirmishListSize do
    	if data.actors[i] and data.actors[i].attrper then return i end
   	end

   	return 0
end

local function onLogin(actor)
	local data = getStaticData(actor)
	if data == nil then return end
	--限制条件
	if LActor.getChapterLevel(actor) < SkirmishBaseConfig.openLevel then
        --清理下旧数据
        for i=1,SkirmishListSize do
	        data.actors[i] = nil
        end
        return
    end

    --没打死第一个遭遇战玩家也没下面代码的事了
    local index = getAttrperIndex(actor)
    if 0 ~= index then
		local actordata = data.actors[index]
		sendActorData(actor, index, actordata.id, actordata.pos, actordata.level or 1, actordata.name, actordata.attrper or 0)
    	return
    end

	local count = 0
	local list = {}
	local selfid = LActor.getActorId(actor)
	for i = 1,SkirmishListSize do
		if data.actors[i] ~= nil then
			table.insert(list, data.actors[i].id)
			count = count + 1
			--更新等级
			if selfid == data.actors[i].id then
				local level = data.actors[i].level + math.random(0, 3)
                if level % 1000 > MAX_ACTOR_LEVEL then
                    level = math.floor(level /1000) * 1000 + MAX_ACTOR_LEVEL
                end
				data.actors[i].level = level
			else
				--小号长时间不登录后,服务器不再加载其数据,可能会获取不到等级
				if LActor.getActorLevel(data.actors[i].id) ~= 0 then
					data.actors[i].level = LActor.getActorLevel(data.actors[i].id)
					data.actors[i].level = data.actors[i].level + 1000* LActor.getActorZhuanShengLevel(data.actors[i].id)
				end
			end
			--发送玩家信息
			local actordata = data.actors[i]
			sendActorData(actor, i, actordata.id, actordata.pos, actordata.level or 1,actordata.name,actordata.attrper or 0)
		end
	end
	--print("------------------------4_ count:"..count)
	--检查时间，补充玩家
	if count < SkirmishListSize then
		local n = (System.getNowTime() - data.lastRefreshTime)/ SkirmishRefreshTime -- 20 分钟 刷新一次
		--print("------------------------1_ now:: "..System.getNowTime())
		--print("------------------------1_ last: "..data.lastRefreshTime)
		--print("------------------------1_ n: "..n)
		while (n > 1 and count < SkirmishListSize) do
			local aid = findSkirmish(actor, list)
			--print("------------------------1_ aid: "..aid)
			--print("------------------------1_ selfid: "..selfid)
			if aid ~= nil then
				addActor(actor, data, aid)
				n = n - 1
				count = count + 1
				data.lastRefreshTime = data.lastRefreshTime + SkirmishRefreshTime
                table.insert(list, aid)
			end
		end
		if count < SkirmishListSize then
			local delay = SkirmishRefreshTime - (System.getNowTime() - data.lastRefreshTime)
			LActor.postScriptEventLite(actor, delay * 1000, refreshActor, data.lastRefreshTime)
		else
			data.lastRefreshTime = System.getNowTime() - SkirmishRefreshTime -- 发给前端下次刷新时间为当前时间，不再显示
		end
	end
	--登陆清理缓存数据,确保一下吧
	local cache = getCacheData(actor)
	cache.pkeid = nil
	--计算离线时间补扣的红名值
	local subpkval = 0
	local fillTime = 0
	local nowTime = System.getNowTime()
	if not data.lastRefreshPkvalTime then data.lastRefreshPkvalTime = nowTime end
	local lastTime = data.lastRefreshPkvalTime
	local blankTime = nowTime - lastTime --间隔时间
	if blankTime > 0 and (SkirmishBaseConfig.refreshPkvalTime or 0) > 0 then --避免配置错误出现除零操作
		local subTimes = math.floor(blankTime/(SkirmishBaseConfig.refreshPkvalTime*60))
		subpkval = SkirmishBaseConfig.refreshSubPkval*subTimes
		fillTime = blankTime - (SkirmishBaseConfig.refreshPkvalTime*60*subTimes)
	end
	changePkval(actor, data, subpkval * -1, fillTime)
	updateInfo(actor)
	updateRank(actor, LActor.getLevel(actor))
end



local function onReqRefresh(actor, packet)
	if true then return end --不能手工刷新了
    if LActor.getChapterLevel(actor) < SkirmishBaseConfig.openLevel then return end
	local data = getStaticData(actor)
	if data == nil then return end

	local list = {}
	for i = 1,SkirmishListSize do
		if data.actors[i] ~= nil then
			table.insert(list, data.actors[i].id)
		end
	end
	--检查条件
	if #list >= SkirmishListSize then
		return false
	end
	--钱
    local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if yb < SkirmishBaseConfig.refreshCost then
        return false
    end

	local aid = findSkirmish(actor, list)
	if aid ~= nil then
        --扣钱
        LActor.changeYuanBao(actor, 0-SkirmishBaseConfig.refreshCost, "refresh skirmishData")
		addActor(actor, data, aid)
        data.refreshCount = (data.refreshCount or 0) + 1
		local count = getActorDataCount(actor)
		if count == SkirmishListSize then
			data.lastRefreshTime = System.getNowTime() - SkirmishRefreshTime
		end
		updateInfo(actor)
		return true
	end

	return false

end

--定时清除红名值时间到
local function clearPkvalOnTime(actor, lastRefreshTime)
	local data = getStaticData(actor)
	if data.lastRefreshPkvalTime ~= lastRefreshTime then return end
	data.lastRefreshPkvalTime = System.getNowTime()
	local cache = getCacheData(actor)
	cache.pkeid = nil
	changePkval(actor, data, -1 * SkirmishBaseConfig.refreshSubPkval)
	updateInfo(actor)
end

--改变红名值
function changePkval(actor, data, val, fillTime)
	if not data then data = getStaticData(actor) end
	data.pkval = (data.pkval or 0) + val
	if data.pkval < 0 then data.pkval = 0 end
	if not SkirmishBaseConfig.refreshPkvalTime then 
		print("skirmishsystem,changePkval: SkirmishBaseConfig.refreshPkvalTime is nil")
		return 
	end
	local cache = getCacheData(actor)
	if data.pkval > 0 then --还有红名值,定时清除红名值
		if not cache.pkeid then
			data.lastRefreshPkvalTime = System.getNowTime()-(fillTime or 0)
			cache.pkeid = LActor.postScriptEventLite(actor, (SkirmishBaseConfig.refreshPkvalTime * 60 - (fillTime or 0)) * 1000, clearPkvalOnTime, data.lastRefreshPkvalTime)
		end
	else
		if cache.pkeid then
			LActor.cancelScriptEvent(actor, cache.pkeid)
			cache.pkeid = nil
		end
	end
end

--请求手动清除红名值
local function reqClearPkval(actor, packet)
	if LActor.getChapterLevel(actor) < SkirmishBaseConfig.openLevel then return end
	local data = getStaticData(actor)
	if data == nil then return end
	local actorId = LActor.getActorId(actor)

	--达到最大红名值才扣钱
	if (data.pkval or 0) < SkirmishBaseConfig.maxPkval then
		print("skirmishsystem,reqClearPkval: maxPkval level limit, pkval:"..tostring(data.pkval)..", actorId:"..tostring(actorId))
		return
	end

	--获取需要扣除的红名值
	local count = (data.pkval or 0) - (SkirmishBaseConfig.maxPkval -1)
	local needMoney = SkirmishBaseConfig.subPkvalCost * count

    local yb = LActor.getCurrency(actor, NumericType_YuanBao)
    if yb < needMoney then return end

    --扣钱
    LActor.changeYuanBao(actor, 0-needMoney, "refresh skirmishPkval")
	changePkval(actor, data, -1 * count)
	updateInfo(actor)
	--返回个包给客户端
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sSkirmishCmd_ResClearPkval)
	if npack then
		LDataPack.flush(npack)
	end
	--清除红名值直接刷出一个遭遇战玩家
	refreshActor(actor, data.lastRefreshTime)
end

local function onResult(actor, packet)
	local id = LDataPack.readInt(packet)
    id = id + 1  --后来改成从0开始
	local result = LDataPack.readInt(packet)

	local data = getStaticData(actor)
    print("skirmishsystem on result id:"..id.. " aid:"..LActor.getActorId(actor))
	if data.actors[id] == nil then
        print("skirmishsystem on result data.actors["..id.."] is nil")
        return
    end
	--检测红名值是否已经上限
	if (data.pkval or 0) >= SkirmishBaseConfig.maxPkval then
		print("skirmishsystem, onResult: data.pkval("..data.pkval..") >= SkirmishBaseConfig.maxPkval("..SkirmishBaseConfig.maxPkval..") return")
		return
	end
	--todo 检测一下？


    local level = data.actors[id].level
    if level > 1000 then
        level = math.floor(level / 1000) * 1000
    elseif level > ZHUAN_SHENG_BASE_LEVEL then
        level = ZHUAN_SHENG_BASE_LEVEL
    end

	local conf = SkirmishRewardConfig[level]
	if conf == nil then print("skirmish base config is nil: level:".. level.. " aid:"..LActor.getActorId(actor)) return end

    --清理前先获取到目标名字，后面用
    local actorName = data.actors[id].name
    data.challengeCount = (data.challengeCount or 0) + 1

    --计算奖励
    local exp = conf.rewards.exp
    local gold = conf.rewards.gold
    local essence = conf.rewards.essence or 0
    if (data.challengeCount or 0) > SkirmishBaseConfig.noExpCount then
        exp = 0
    end
    local fame = 0
    local rewards = {}
    local isAttrper = false
    if result == 1 then
		data.winCount = (data.winCount or 0) + 1 --赢的次数+1
		if data.actors[id].attrper then 
			--系统刚开的时候的第一只遭遇战玩家,会有它,并且需要按配置的特殊奖励
			rewards = drop.dropGroup(SkirmishBaseConfig.onesRewards or 0) or {}
			isAttrper = true
		else
			local fameconf = SkirmishFameConfig[data.winCount]
			if fameconf == nil then
				fame = maxFame
			else
				fame = fameconf.fame
			end
			rewards = drop.dropGroup(conf.dropId)
		end
    else
        exp = math.floor(exp * failedRewardRate)
        gold = math.floor(gold * failedRewardRate)
        essence = math.floor(essence * failedRewardRate)
    end
	--清除当前刷出的遭遇战人物数据
	data.actors[id] = nil
	--返回个结果包给客户端
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sSkirmishCmd_AffirmResult)
	if npack == nil then return end
	LDataPack.writeInt(npack, id)
	LDataPack.writeInt(npack, result)
    LDataPack.writeInt(npack, exp)
    LDataPack.writeInt(npack, gold)
    LDataPack.writeInt(npack, essence)
    LDataPack.writeInt(npack, fame)
    --掉落信息
	local rcount = 0
	local pos = LDataPack.getPosition(npack)
    LDataPack.writeShort(npack, rcount)
	local job = LActor.getJob(actor)
    for _, a in ipairs(rewards) do
		if not a.job or a.job == job then
			LDataPack.writeInt(npack, a.type or 0)
			LDataPack.writeInt(npack, a.id or 0)
			LDataPack.writeInt(npack, a.count or 0)
			rcount = rcount + 1
		end
    end
	local pos2 = LDataPack.getPosition(npack)
	LDataPack.setPosition(npack, pos)
	LDataPack.writeShort(npack, rcount)
	LDataPack.setPosition(npack, pos2)
    LDataPack.flush(npack)
	
    --增加挑战记录
    if data.records == nil then data.records = {} end --旧数据为空
    data.records[(data.recordsCount or 0) % 5 + 1] =
    {time= System.getNowTime(), result=result, name=actorName,
        gold = gold, exp = exp, fame = fame , essence = essence}
    data.recordsCount = (data.recordsCount or 0) + 1

    local cache = getCacheData(actor)
    cache.rewards = rewards

    --实际奖励
    LActor.changeCurrency(actor, NumericType_Exp, exp, "skirmish result reward1")
    LActor.changeCurrency(actor, NumericType_Gold, gold, "skirmish result reward2")
    LActor.changeCurrency(actor, NumericType_Essence, essence, "skirmish result reward3")

    if result == 1 then
        data.fame = (data.fame or 0) + fame
        updateRank(actor, LActor.getLevel(actor))
		--记录增加红名值
		changePkval(actor, data, SkirmishBaseConfig.onesPkval)

		--打死第一只遭遇战玩家后，按要求立即刷新玩家
		if isAttrper then
			local list = {}
			for i=1, SkirmishBaseConfig.firstRefreshCount do
				local aid = findSkirmish(actor, list)
				if aid ~= nil then addActor(actor, data, aid) end
				table.insert(list, aid)
            end

            --做个单独处理，防止不刷敌人
            if SkirmishBaseConfig.firstRefreshCount < SkirmishListSize then
        		data.lastRefreshTime = System.getNowTime()
           		LActor.postScriptEventLite(actor, SkirmishRefreshTime * 1000, refreshActor, data.lastRefreshTime)
           	end
       	end
    end
    --日志
    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
        "skirmish", tostring(result), actorName, "", "result"..(result==1 and "win" or "lose"), "", "")

    --下次刷新时间
	local count = getActorDataCount(actor)
	if count == (SkirmishListSize - 1) then
		data.lastRefreshTime = System.getNowTime()
		local delay = SkirmishRefreshTime - (System.getNowTime() - data.lastRefreshTime)
		LActor.postScriptEventLite(actor, delay * 1000, refreshActor, data.lastRefreshTime)
	end

	updateInfo(actor)
	if result == 0 then
		--进入已在关卡坐标
		local data = chapter.getStaticData(actor)
		local conf = ChaptersConfig[data.level or 0]
		if conf then
			LActor.reEnterScene(actor, conf.enterPos.x or 0, conf.enterPos.y or 0)
		end

		chapter.initChapterData(actor, chapter.getStaticData(actor))
	end
	LActor.recover(actor)

	actorevent.onEvent(actor, aeSkirmish, result)
end

local function onReqRecord(actor, packet)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sSkirmishCmd_ResRecord)
    if npack == nil then return end
    local data = getStaticData(actor)
    if data.records == nil then data.records = {} end

    local count = data.recordsCount or 0
    local index = 1
    if count > 5 then
        count = 5
        index = data.recordsCount - 5
    end
    LDataPack.writeShort(npack, count)
    for i = index, index+5 do
        local v = data.records[(i-1)%5 + 1]
        if v ~= nil then
            LDataPack.writeInt(npack, v.time)
            LDataPack.writeByte(npack, v.result)
            LDataPack.writeString(npack, v.name)
            LDataPack.writeInt(npack, v.exp)
            LDataPack.writeInt(npack, v.gold)
            LDataPack.writeInt(npack, v.fame)
            LDataPack.writeInt(npack, v.essence or 0)
        end
    end
    LDataPack.flush(npack)
end


local function onReqFame(actor, packet)
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skirmish, Protocol.sSkirmishCmd_ResFame)
    if npack == nil then return end
    local data = getStaticData(actor)

    LDataPack.writeInt(npack, data.fame or 0)
    local rank = skirmishranking.getrank(actor)
    LDataPack.writeShort(npack, rank)
    LDataPack.flush(npack)
end

local function onReqDrop(actor, packet)
    local cache = getCacheData(actor)
    if cache.rewards == nil then return end

    LActor.giveAwards(actor, cache.rewards, "skirmish drop")
    cache.rewards = nil
end

local function onNewDay(actor, isLogin)
    local data = getStaticData(actor)
    if data == nil then return end
    data.winCount = 0
    data.challengeCount = 0
    data.fame = 0
    data.refreshCount = 0
    if not isLogin then
        updateInfo(actor)
    end
end

local function onChapterFinish(actor, level)
    if level == SkirmishBaseConfig.openLevel then
       local data = getStaticData(actor)
       if data == nil then return end

       local list = {}
       for i=1,SkirmishListSize do
           if data.actors[i] ~= nil then
               table.insert(list, data.actors[i].id)
           end
       end

       if #list ~= 0 then
           print("error: chapter open level.list not nil")
           return
       end
       
       if (SkirmishBaseConfig.openCount or 0)> 0 then
           for i=1,SkirmishBaseConfig.openCount do
				local aid = nil
				if i == 1 then 
					aid = LActor.getActorId(actor)
					else
					aid = findSkirmish(actor, list)
				end
				if aid ~= nil then
					if i == 1 then 
						 addActor(actor, data, aid, SkirmishBaseConfig.onesAttrper or 0)
					else
						 addActor(actor, data, aid)
					end
					table.insert(list, aid)
				end
           end
       end
       --[[
       local count = getActorDataCount(actor)
       if count < SkirmishListSize then
           data.lastRefreshTime = System.getNowTime()
           LActor.postScriptEventLite(actor, SkirmishRefreshTime * 1000, refreshActor, data.lastRefreshTime)
       else
           data.lastRefreshTime = System.getNowTime() - SkirmishRefreshTime
       end
		]]
		data.lastRefreshTime = System.getNowTime() - SkirmishRefreshTime
		updateInfo(actor)
    end
end

local function onLevelUp(actor, level)
	if skirmishranking.RANK_MIN_LEVEL == level then
		updateRank(actor, level)
	end
end

actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeNewDayArrive, onNewDay)
actorevent.reg(aeChapterLevelFinish, onChapterFinish)
actorevent.reg(aeLevel, onLevelUp)


netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cSkirmishCmd_ReqRefresh, onReqRefresh)
netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cSkirmishCmd_ReportResult, onResult)
netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cSkirmishCmd_ReqRecord, onReqRecord)
netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cSkirmishCmd_ReqFame, onReqFame)
netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cSkirmishCmd_ReqDrop, onReqDrop)
netmsgdispatcher.reg(Protocol.CMD_Skirmish, Protocol.cSkirmishCmd_ReqClearPkval, reqClearPkval)

function gmTestFame(actor)
    local data = getStaticData(actor)
    data.winCount = (data.winCount or 0) + 1

    --更新
    print("affirm result")
    --计算奖励
    local fame = 0
    local conf = SkirmishFameConfig[data.winCount]
    if conf == nil then
        fame = maxFame
    else
        fame = conf.fame
    end

    data.fame = (data.fame or 0) + fame
    skirmishranking.updateRankingList(actor, data.fame)
end

function gmResetFame(actor)
	if actor == nil then return end

	local data = getStaticData(actor)
	if data == nil then return end

	onNewDay(actor)
	skirmishranking.setRankingList(actor, 0)
	LActor.saveDb(actor)

	print("gm set actor:"..LActor.getActorId(actor).." fame:"..0)
end
