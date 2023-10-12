-- 转盘抽奖
module("psubactivitytype9", package.seeall)
--[[
个人data define:
	recidx = {
		可领的索引,
	}
	count = 累计抽奖次数,
	rewardsRecord = 已经的累计抽奖次数标记位 
	useIdx = 使用全局库索引
}
--]]

local p = Protocol
local subType = 9
local RType = {
	times = 0,--领取次数奖励
	once = 1,--转盘抽
	tenc = 2,--十次连抽
}

--下发数据
local function writeRecord(npack, record, conf, id, actor)
	if nil == record then record = {} end
	LDataPack.writeInt(npack, record.rewardsRecord or 0)
	LDataPack.writeInt(npack, record.count or 0)
	local count = #(record.recidx or {})
	LDataPack.writeChar(npack, count)
	for i=1,count do
		LDataPack.writeChar(npack, record.recidx[i])
	end
	LDataPack.writeChar(npack, 0)
end

--增加领奖索引
local function addrecidx(record, idx)
	if not record.recidx then record.recidx = {} end
	local count = #(record.recidx or {}) + 1
	record.recidx[count] = idx
end

--检测是否需要公告
local function checkNotice(actor, cfg, id, idx)
	if cfg.noticeId then --公告
		local name = LActor.getName(actor)
		noticemanager.broadCastNotice(cfg.noticeId, name)
	end
end

--根据次数获取单个的抽奖概率
local function getOneRate(cfg, num)
	local maxK = 0
	local rr = 0
	for k,v in pairs(cfg.rate) do
		if num%k == 0 and k > maxK then --能整除的最大的次数概率
			maxK = k
			rr = v
		end
	end
	return rr
end

--获取抽奖总概率
local function getRateTotal(config, num)
	local total = 0
	local AllItem = {}
	for _, v in ipairs(config) do
		local rate = getOneRate(v, num)
		total = total + rate
		table.insert(AllItem, rate)
	end	
	return total,AllItem
end

local function giveRewards(actor, id, record, config)
	if not record.recidx or not record.recidx[1] then return end
	--print(LActor.getActorId(actor).." psubactivitytype9.giveRewards id:"..id)
	for i=1,#(record.recidx) do
		local idx = record.recidx[i]
		local cfg = config[idx]
		if cfg then
			LActor.giveAwards(actor, cfg.reward, "ptype9 once "..idx)
			checkNotice(actor, cfg, id, idx)
		end
	end
end

local function GetPerRandIndex(actor, id, conf, record)
	if not record.useIdx and conf.perNum and #(conf.perNum) > 0 then 
		record.useIdx = math.random(1, #(conf.perNum))
	end
	if not record.useIdx then return end
	local cfg = conf.perNum[record.useIdx]
	if not cfg then
		print(LActor.getActorId(actor).." psubactivitytype9.GetPerRandIndex cfg is nil, id:"..id)
		return
	end
	local index = cfg[(record.count or 0)+1]
	return index
end

--抽奖
local function hut(id, config, actor, record, packet, conf)
	--全局玩家随机
	local gidx = GetPerRandIndex(actor, id, conf, record)
	if gidx then
		addrecidx(record, gidx)
	else
		--正常随机
		local num = (record.count or 0) + 1
		local RateTotal,AllItem = getRateTotal(config, num)
		local rand = math.random(0, RateTotal and (RateTotal - 1) or 0)
		--print(LActor.getActorId(actor).." psubactivitytype9.hut id:"..id..",RateTotal:"..RateTotal..",rand:"..rand)
		local sumRate = 0
		for idx, rate in ipairs(AllItem) do
			sumRate = sumRate + rate
			if rand < sumRate then
				--print(LActor.getActorId(actor).." psubactivitytype9.hut get id:"..id..",idx:"..idx)
				addrecidx(record, idx)
				break
			end
		end
	end
	--print(LActor.getActorId(actor).." psubactivitytype9.hut id:"..id..",sumRate:"..sumRate)
	record.count = (record.count or 0) + 1
end

--领取类型
local rtFunc = {
	[RType.times] = function(id, config, actor, record, packet, conf)
		local idx = LDataPack.readChar(packet)
		--print(LActor.getActorId(actor).." psubactivitytype9.RType.times get reward id:"..idx)		
		local rcfg = conf.reward[idx]
		if not rcfg then 
			print(LActor.getActorId(actor).." psubactivitytype9.RType.times not have reward id:"..idx)			
			return
		end
		if (record.count or 0) < rcfg.times then 
			print(LActor.getActorId(actor).." psubactivitytype9.RType.times not times id:"..idx)
			return
		end
		if System.bitOPMask(record.rewardsRecord or 0, idx) then
			print(LActor.getActorId(actor).." psubactivitytype9.RType.times is receive:"..idx)
			return
		end
		record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord or 0, idx, true)
		LActor.giveAwards(actor, {rcfg}, "ptype9 times "..idx)
		pactivitysystem.sendActivityData(actor, id)
	end,
	[RType.once] = function(id, config, actor, record, packet, conf)
		--先判断是否有奖励
		local count = #(record.recidx or {})
		if count > 0 then --领奖
			giveRewards(actor, id, record, config)
			record.recidx = nil
		else --抽奖
			--先判断有没道具
			if conf.item and LActor.getItemCount(actor, conf.item) > 0 then
				LActor.costItem(actor, conf.item, 1, "ptype9 once"..id)
			else
				--判断是否够元宝
				if LActor.getCurrency(actor, NumericType_YuanBao) < conf.yb then
					print(LActor.getActorId(actor).." psubactivitytype9.RType.once:not have yb")
					return
				end
				--扣元宝
				LActor.changeYuanBao(actor, 0 - conf.yb, "ptype9 once,id"..id)
			end
			--抽奖
			hut(id, config, actor, record, packet, conf)
		end
		pactivitysystem.sendActivityData(actor, id)
	end,
	[RType.tenc] = function(id, config, actor, record, packet, conf)
		local counts = 10
		--先判断有没道具
		local itemCount = 0
		local needYb = 0
		if conf.item then
			itemCount = math.min(LActor.getItemCount(actor, conf.item), counts)
		end
		if itemCount <= 0 then --没有道具用元宝
			needYb = counts * conf.yb
			--判断是否够元宝
			if LActor.getCurrency(actor, NumericType_YuanBao) < needYb then
				print(LActor.getActorId(actor).." subactivitytype9.RType.once:not have yb")
				return
			end
		else --有道具; 扣完对应的道具次数
			counts = itemCount
		end
		--扣元宝扣道具
		if itemCount > 0 then
			LActor.costItem(actor, conf.item, itemCount, "ptype9 tenc"..id)
		end
		if needYb > 0 then
			LActor.changeYuanBao(actor, 0-needYb, "ptype9 tenc"..id)
		end
		--循环抽奖
		for i=1,counts do
			--抽奖
			hut(id, config, actor, record, packet, conf)
		end
		giveRewards(actor, id, record, config)
		--发消息
		pactivitysystem.sendActivityData(actor, id)
		record.recidx = nil
	end,
}

--请求领取奖励
local function getReward(id, typeconfig, actor, record, packet)
	local rt = LDataPack.readShort(packet)
	local func = rtFunc[rt]
	if not func then 
		print(LActor.getActorId(actor).." psubactivitytype9.getReward not func("..rt..") id:"..id)
		return 
	end
	if not typeconfig[id] then 
		print(LActor.getActorId(actor).." psubactivitytype9.getReward not have config id:"..id)
		return
	end
	local conf = typeconfig[id][0]
	if not conf then 
		print(LActor.getActorId(actor).." psubactivitytype9.getReward not have conf[0] id:"..id)
		return 
	end
	func(id, typeconfig[id], actor, record, packet, conf)
end

local function onLogout(id, conf)
	return function(actor)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		local record = pactivitysystem.getSubVar(actor, id)
		if record.recidx then
			giveRewards(actor, id, record, conf)
			record.recidx = nil
		end
	end
end

local function onNewDay(id, conf)
	return function(actor)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		local record = pactivitysystem.getSubVar(actor, id)
		if conf[0] and conf[0].isReset then
			record.rewardsRecord = nil
			record.count = nil
		end

		record.recidx = nil
	end
end

local function initFunc(id, conf)
	actorevent.reg(aeUserLogout, onLogout(id, conf))
	actorevent.reg(aeNewDayArrive, onNewDay(id, conf))
end

pactivitysystem.regConf(subType, PActivityType9Config)
pactivitysystem.regInitFunc(subType, initFunc)
pactivitysystem.regWriteRecordFunc(subType, writeRecord)
pactivitysystem.regGetRewardFunc(subType, getReward)
