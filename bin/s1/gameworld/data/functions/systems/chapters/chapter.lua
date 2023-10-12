module("chapter", package.seeall)

require("systems.instance.instancesystem")

local LDataPack = LDataPack
local LActor = LActor
local p = Protocol

--掉落类型定义
expTime = 1
dropTime = 2
eliteDropTime = 3

--[[
	chapterData = {
		level
		rewardRecord,   --章节领取记录
		dq_rewardRecord, --地区领取奖励记录
	}
	chaptercache = {
		expReward = 0
		reward = {}
		offlinedata = {
		    time,
		    orinExp, --基础经验
		    orinGold, --基础金币
		    exp,  --加成后经验
		    gold, --加成后金币
		    equipCount,
		    selledCount,
		}
	}
 --]]

--外部使用了
function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.chapterData == nil then
		var.chapterData = {}
		initRecordData(actor, var.chapterData)
	end
	return var.chapterData
end

local function getDynamicData(actor)
	local var = LActor.getDynamicVar(actor)
	if var == nil then return nil end

	if var.chapterData == nil then
		var.chapterData = {}
	end
	return var.chapterData
end

function initRecordData(actor, data)
	data.level = 1
	LActor.setChapterLevel(actor, 1)    --在actorbasicData里也保存
end

local function GetALLMonsterToJson(allMonsterId)
	if not allMonsterId then return "" end
	if #allMonsterId <= 0 then return "" end
	local json = "{"
	for k,monsterId in ipairs(allMonsterId) do
		local moncfg = MonstersConfig[monsterId]
		if moncfg then
			json = json..string.format("\"%d\":%s", monsterId, utils.tableToJson(moncfg))
			if k ~= #allMonsterId then
				json = json..","
			end
		end		
	end
	json = json.."}"
	return json
end

local allchapterjson = {}
local cck = {"rCount","goldEff","expEff","zyPos","energy","waveEnergy",
"waveMonsterCount","waveMonsterId","outPos","rPos","eliteMonsterId","wanderpercent"} --客户端需要的字段
local allmonjson = {}
function initChapterData(actor, data)
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_InitChapter)
	if npack ==  nil then return end

	LDataPack.writeInt(npack, data.level)
	--挂机关卡表数据
	local conf = ChaptersConfig[data.level]
	local lcfg = ChaptersConfig[data.level-1] --上一关的配置
	if lcfg then
		LDataPack.writeInt(npack, lcfg.goldEff or 0)
		LDataPack.writeInt(npack, lcfg.expEff or 0)
	else		
		LDataPack.writeInt(npack, 0)
		LDataPack.writeInt(npack, 0)
	end
	--[[
	LDataPack.writeShort(npack, conf.rCount or 0)
	LDataPack.writeInt(npack, conf.goldEff or 0)
	LDataPack.writeInt(npack, conf.expEff or 0)
	LDataPack.writeShort(npack, #(conf.zyPos or {}))
	for _,v in ipairs(conf.zyPos or {}) do
		LDataPack.writeShort(npack, v.x)
		LDataPack.writeShort(npack, v.y)
	end
	LDataPack.writeInt(npack, conf.energy or 0)
	LDataPack.writeInt(npack, conf.waveEnergy or 0)
	LDataPack.writeShort(npack, conf.waveMonsterCount or 0)
	LDataPack.writeShort(npack, #(conf.waveMonsterId or {}))
	for _,v in ipairs(conf.waveMonsterId or {}) do
		LDataPack.writeInt(npack, v)
	end
	LDataPack.writeShort(npack, conf.outPos and conf.outPos.x or 0)
	LDataPack.writeShort(npack, conf.outPos and conf.outPos.y or 0)
	LDataPack.writeShort(npack, conf.outPos and conf.outPos.a or 0)
	LDataPack.writeShort(npack, #(conf.rPos or {}))
	for _,vv in ipairs(conf.rPos or {}) do
		LDataPack.writeShort(npack, #(vv or {}))
		for _,v in ipairs(vv or {}) do 
			LDataPack.writeShort(npack, v.x)
			LDataPack.writeShort(npack, v.y)
		end
	end	
	LDataPack.writeInt(npack, conf.eliteMonsterId or 0)	
	LDataPack.writeInt(npack, conf.wanderpercent or 5000)	
	]]
	--关卡配置
	if not allchapterjson[data.level] then
		local cfg = {}
		for _,v in ipairs(cck) do
			cfg[v] = conf[v]
		end
		allchapterjson[data.level] =  utils.tableToJson(cfg)
	end
	LDataPack.writeString(npack, allchapterjson[data.level])
	--发所有怪物
	if not allmonjson[data.level] then
		local allMonsterId = {}
		for _,v in ipairs(conf.waveMonsterId or {}) do
			table.insert(allMonsterId, v)
		end
		if conf.eliteMonsterId then
			table.insert(allMonsterId, conf.eliteMonsterId)
		end
		allmonjson[data.level] = GetALLMonsterToJson(allMonsterId)
	end
	LDataPack.writeString(npack, allmonjson[data.level])
	
	LDataPack.flush(npack)
end

local function SendHaveReward(actor, type)
	--print("SendHaveReward:"..type)
	--[[ 协议定义
	proto{
	int 掉落数据个数
	array 掉落数据{
		int  奖励类型
		int  奖励id
		int  数量
	}
	char 是否精英怪掉落
	-- ]]
	--计算经验和金币的倍率
	local expex = specialattribute.get(actor,specialattribute.expEx)
	local goldex = specialattribute.get(actor,specialattribute.goldEx)
	if expex ~= 0 then expex = expex / 10000 end
	if goldex ~= 0 then	goldex = goldex / 10000	end
	--获取玩家数据
	local data = getStaticData(actor)
	local cache = getDynamicData(actor)
	if type == eliteDropTime then
		if cache.elitereward and #cache.elitereward >= 5 then
			return --最多五只精英怪
		end
	else
		if cache.reward and #cache.reward > 50 then
			--这里先这样处理试试, 因为定时发奖励,策划又没考虑到, 如果前端卡死
			--或者在后台时候,玩家并没有下线, 这样定时发了特多奖励的时候,会使得
			--这个table无限增大
			return
		end		
	end
	--获取当前等级配置
	local conf = ChaptersConfig[data.level]
	if conf == nil then
		conf = ChaptersConfig[data.level - 1]
		if conf == nil then
			print("prepare new wave error config not found")
		end
	end
	--cache.reward = {}
	--计算掉落
	local getExp = 0 --应该得到的经验
	local getRet = {} --应该得到的掉落
	if type == expTime then --拿经验的
		getExp = conf.waveExp * (1 + expex)
	elseif type == eliteDropTime then --这个是精英怪
		getRet = drop.dropGroup(conf.eliteDropId)
	elseif type == dropTime then --拿普通掉落的
		getRet = drop.dropGroup(conf.monsterDropId)
	end
	--没有奖励就返回了
	if #getRet == 0 and getExp == 0 then
		return
	end
	--给客户端发包
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_SendHaveReward)
	if npack ==  nil then return end
	LDataPack.writeInt(npack,getExp) --经验
	LDataPack.writeInt(npack,#getRet) --掉物
	for _, v in ipairs(getRet) do
		--金币加成
		if v.type ==  AwardType_Numeric and v.id == NumericType_Gold then 
			v.count = math.floor(v.count * (1 + goldex))
		end
		--写入奖励
		LDataPack.writeData(npack, 3,
			dtInt, v.type or 0,
			dtInt, v.id or 0,
			dtInt, v.count or 0
		)
	end
	LDataPack.writeChar(npack, (type == eliteDropTime) and 1 or 0) --是否精英掉落
	LDataPack.flush(npack)
	--奖励累加入缓存
	if cache.reward == nil then cache.reward = {} end
	if cache.elitereward == nil then cache.elitereward = {} end
	--print(LActor.getActorId(actor).." SendHaveReward:"..type..", exp:"..getExp..", reward:"..utils.t2s(getRet))
	if #getRet > 0 then
		if type == eliteDropTime then
			table.insert(cache.elitereward, getRet)
		else
			table.insert(cache.reward, getRet)
		end
	end
	cache.expReward = (cache.expReward or 0) + getExp
end

local function createBossFuben(actor)
	local data = getStaticData(actor)
	if ChaptersConfig[data.level + 1] == nil then
		print("aid:"..LActor.getActorId(actor).." create chapter boss failed. last chapter")
		return
	end
	local conf = ChaptersConfig[data.level]
	local hfuben = Fuben.createFuBen(conf.bossFid)
	if hfuben == 0 then
		print("create fuben failed. "..conf.bossFid)
		return
	end
	local ins = instancesystem.getInsByHdl(hfuben)
	if ins ~= nil then
		--ins.data.isChapter = true
		ins.data.cid = data.level
	end
	return hfuben,ins
end

local function sendBossMonsterCfg(actor, conf)
	local npack = LDataPack.allocPacket(actor, p.CMD_Base, p.sBaseCmd_SendMonsterCfg)
	if npack ==  nil then return end
	if not conf.bossJson then
		local allMonsterId = {}
		for _,mg in ipairs(InstanceConfig[conf.bossFid].monsterGroup or {}) do
			for _,m in ipairs(mg) do
				table.insert(allMonsterId, m.monId)
			end
		end
		conf.bossJson = GetALLMonsterToJson(allMonsterId)
	end
	LDataPack.writeString(npack, conf.bossJson)
	LDataPack.flush(npack)
end

local function onChallengeBoss(actor, packet)
	local data = getStaticData(actor)
	local conf = ChaptersConfig[data.level]
	if conf == nil then print("chapters conf is nil. level:"..tostring(data.level)) return end

	if LActor.isInFuben(actor) then
		print("challenge boss invalid .actor is in fuben. actor: ".. LActor.getActorId(actor))
		return
	end

	sendBossMonsterCfg(actor, conf)
	--if LActor.checkEnterFuBen(actor) == false then return end

	local hfuben,ins = createBossFuben(actor)
	if not hfuben then return end
	local x = LDataPack.readInt(packet)
	local y = LDataPack.readInt(packet)
	print(LActor.getActorId(actor).." chapter.onChallengeBoss x:"..x..",y:"..y)
	LActor.enterFuBen(actor, hfuben, -1, x, y, true)
end

local function checkWave(actor)
	if LActor.isInFuben(actor) then return false end
	return true
end

local function onBossWin(ins)
	local actor = ins:getActorList()[1]
	print("chapter.onBossWin aid:"..LActor.getActorId(actor))
	if actor == nil then print("can't find actor") return end --胜利的时候不可能找不到吧

	local conf = ChaptersConfig[ins.data.cid]
	if conf == nil then return end

	local rewards = drop.dropGroup(conf.reward)
	instancesystem.setInsRewards(ins, actor, rewards)

	--解锁宝箱
	treasureboxsystem.addGrid(actor, ins.data.cid)
	
	--标记为通关
	local data = getStaticData(actor)
	data.level = data.level + 1
	--把这个值放在ActorBasicData里, 离线需要用到
	LActor.setChapterLevel(actor, data.level)
	chapterrank.updateRankingList(actor, data.level)
end

local function onBossLose(ins)
	print("chapter.onBossLose")
	local actor = ins:getActorList()[1]
	if actor == nil then print("can't find actor") return end

	instancesystem.setInsRewards(ins, actor, nil)
end

local function sendWorldReward( actor,data )
	-- 1-5协议
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_UpdateChapterRewardInfo)
	LDataPack.writeShort(npack, data.rewardRecord or 0)
	LDataPack.flush(npack)

	if (data.dq_rewardRecord == nil) then data.dq_rewardRecord = {} end
	local total = #WorldRewardConfig
	-- 1-6协议
	local npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_UpdateWorldRewardInfo)
	LDataPack.writeInt(npack, total)
	for i = 1,total do
		if (data.rewardRecord or 0 >= WorldRewardConfig[i].needLevel) then
			LDataPack.writeInt(npack, data.dq_rewardRecord[i] or 0)
		else
			LDataPack.writeInt(npack, data.dq_rewardRecord[i] or 2)
		end
	end
	LDataPack.flush(npack)
end

local function onReqChapterReward(actor, packet)
	local data = getStaticData(actor)
	if data.rewardRecord == nil then data.rewardRecord = 0 end
	local chapterLevel = data.rewardRecord + 1
	local ret = true
	local conf = ChaptersRewardConfig[chapterLevel]
	if conf == nil then
		print("can not find conf. level:"..chapterLevel)
		return
	end

	if conf.needLevel > data.level then
		print("1 illegal req for chapter reward. actor:"..LActor.getActorId(actor))
		ret = false
	end
	if not LActor.canGiveAwards(actor, conf.rewards) then
		print("2 illegal req for chapter reward. actor:"..LActor.getActorId(actor))
		ret = false
	end
	if ret then
		data.rewardRecord = data.rewardRecord + 1
		LActor.giveAwards(actor, conf.rewards, "chapter rewards")
		actorevent.onEvent(actor, aeReqChapterReward, chapterLevel)
	end

	sendWorldReward(actor,data)
end

--领取地区奖励(世界奖励)
local function onReqWorldReward(actor,packet)
	local index = LDataPack.readInt(packet)
	local data = getStaticData(actor)
	local ret = true
	
	if data.dq_rewardRecord == nil then data.dq_rewardRecord = {} end
	local conf = WorldRewardConfig[index]
	if not conf then
		print("can not find conf. level:"..index)
		return
	end

	if conf.needLevel > data.level then
		print("1 illegal req for chapter reward. actor:"..LActor.getActorId(actor))
		ret = false
	end
	
	if (data.dq_rewardRecord[index] and data.dq_rewardRecord[index] == 1) then
		return
	end

	if not LActor.canGiveAwards(actor, conf.rewards) then
		print("2 illegal req for chapter reward. actor:"..LActor.getActorId(actor))
		ret = false
	end
	
	if ret then
		data.dq_rewardRecord[index] = 1
		LActor.giveAwards(actor, conf.rewards, "chapter rewards")
		actorevent.onEvent(actor, aeReqChapterWorldReward, index)
	end
	sendWorldReward( actor,data )
end

--登陆时候获取章节奖励和离线奖励记录消息
local function onLoginOfflineReward(actor)
	local cache = getDynamicData(actor)
	
    if cache.offlinedata ~= nil then
        npack = LDataPack.allocPacket(actor, p.CMD_Fuben, p.sFubenCmd_OfflineRewardRecord)
        if npack == nil then return end
        LDataPack.writeInt(npack, cache.offlinedata.time)
        LDataPack.writeInt(npack, cache.offlinedata.orinExp)
        LDataPack.writeInt(npack, cache.offlinedata.orinGold)
        LDataPack.writeInt(npack, cache.offlinedata.equipCount or 0)
        LDataPack.writeInt(npack, cache.offlinedata.selledCount or 0)
        --
        local arrayCount = specialattribute.moduleCount or 0
        LDataPack.writeInt(npack, arrayCount)
        for index=1,arrayCount do
        	local expex,goldex = specialattribute.getBySysType(actor,index)
        	if expex ~= 0 then expex = expex / 100 end
        	if goldex ~= 0 then goldex = goldex / 100 end
        	local exp,gold = 0,0
        	exp = math.floor(cache.offlinedata.orinExp * expex)
        	gold = math.floor(cache.offlinedata.orinGold * goldex)
        	LDataPack.writeData(npack, 3,
        						dtInt, index,
        						dtInt, exp,
        						dtInt, gold)
        end
		local pos = LDataPack.getPosition(npack)
		LDataPack.writeByte(npack, 0)
		local clen = 0
		for id,count in pairs(cache.offlinedata.currency) do
			LDataPack.writeByte(npack, id)
			LDataPack.writeInt(npack, count)
			clen = clen + 1
		end
		local pos2 = LDataPack.getPosition(npack)
		LDataPack.setPosition(npack, pos)
		LDataPack.writeByte(npack, clen)
		LDataPack.setPosition(npack, pos2)
        LDataPack.flush(npack)
        System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
            "offlinerewards", cache.offlinedata.time, string.format("exp:%d gold:%d", cache.offlinedata.exp, cache.offlinedata.gold),
            "", string.format("equipCount:%d, selledCount:%d", cache.offlinedata.equipCount or 0, cache.offlinedata.selledCount or 0),
            "", "")
        cache.offlinedata = nil
    end
	
    sendWorldReward(actor,getStaticData(actor))
end

--定时掉落奖励时间到
local function onScriptTimeOn(actor, type)
	local cache = getDynamicData(actor)
	if type == expTime then cache.expEid = nil end
	if type == dropTime then cache.dropEid = nil end
	if type == eliteDropTime then cache.eliteEid = nil end
	if LActor.isImage(actor) then return end
	if LActor.isInFuben(actor) then	return end
	--发送掉落给客户端
	SendHaveReward(actor, type)
	--再次注册时间定时器
	local data = getStaticData(actor)
	--获取当前等级配置
	local conf = ChaptersConfig[data.level]
	if conf == nil then
		conf = ChaptersConfig[data.level -1]
		if conf == nil then
			return
		end
	end
	--注册定时掉落定时器
	if type == expTime then cache.expEid = LActor.postScriptEventLite(actor, conf.expTime * 1000, onScriptTimeOn, expTime) end
	if type == dropTime then cache.dropEid = LActor.postScriptEventLite(actor, conf.dropTime * 1000, onScriptTimeOn, dropTime) end
	if type == eliteDropTime then cache.eliteEid = LActor.postScriptEventLite(actor, conf.eliteDropTime * 1000, onScriptTimeOn, eliteDropTime) end
end

--注册定时掉落定时器
local function regScriptTimer(actor)
	if LActor.isImage(actor) then return end
	local data = getStaticData(actor)
	--获取当前等级配置
	local conf = ChaptersConfig[data.level]
	if conf == nil then
		conf = ChaptersConfig[data.level -1]
		if conf == nil then
			return
		end
	end
	local cache = getDynamicData(actor)
	--注册定时掉落定时器
	if conf.expTime then cache.expEid = LActor.postScriptEventLite(actor, conf.expTime * 1000, onScriptTimeOn, expTime) end
	if conf.dropTime then cache.dropEid = LActor.postScriptEventLite(actor, conf.dropTime * 1000, onScriptTimeOn, dropTime) end
	if conf.eliteDropTime then cache.eliteEid = LActor.postScriptEventLite(actor, conf.eliteDropTime * 1000, onScriptTimeOn, eliteDropTime) end
end

local function onLogin(actor)
	onLoginOfflineReward(actor)
end

local function onEnterStaticFuben(ins, actor)
	--print("chapter onEnterStaticFuben")
	local data = getStaticData(actor)
	initChapterData(actor, data)
	local cache = getDynamicData(actor)
	cache.reward = nil
	cache.elitereward = nil
	cache.expReward = nil
	--prepareNewWave(actor, data.level, data.wave)
	--定时掉落处理
	if cache.expEid then LActor.cancelScriptEvent(actor, cache.expEid) end
	if cache.dropEid then LActor.cancelScriptEvent(actor, cache.dropEid) end
	if cache.eliteEid then LActor.cancelScriptEvent(actor, cache.eliteEid) end
	regScriptTimer(actor)
end

local function onExitStaticFuben(ins, actor)
	--去除定时奖励定时器
	local cache = getDynamicData(actor)
	if cache.expEid then 
		LActor.cancelScriptEvent(actor, cache.expEid)
		cache.expEid = nil
	end
	if cache.dropEid then 
		LActor.cancelScriptEvent(actor, cache.dropEid)
		cache.dropEid = nil
	end
	if cache.eliteEid then
		LActor.cancelScriptEvent(actor, cache.eliteEid)
		cache.eliteEid = nil
	end
end

local function onBeforeLogin(actor, offlineTime, logoutTime)
	local data = getStaticData(actor)
	local clv = LActor.getChapterLevel(actor)
	if data.level ~= clv then
		print(LActor.getActorId(actor).." chapter.initChapterData data.level("..data.level..") ~= clv("..clv..")")
		data.level = clv
	end

	if offlineTime < 60 then return end
	if LActor.isImage(actor) then return end

	local var = getDynamicData(actor)
	local chapterLevel = data.level - 1
	local conf = ChaptersConfig[chapterLevel]
	if conf == nil then
		conf = ChaptersConfig[chapterLevel -1]
		if conf == nil then
			return
		end
	end
	local effTime = math.floor(offlineTime/60) --精确到分钟
	print("chapter.onBeforeLogin aid:"..LActor.getActorId(actor)..", effTime:"..effTime)
	if effTime > 1440 then effTime = 1440 end
	if effTime > 480 then effTime = math.floor(480 + (effTime - 480)*0.8) end
	local tmpExp = math.floor(conf.expEff / 60 * effTime)
	local tmpGold = math.floor(conf.goldEff / 60 * effTime)
	var.offlinedata = {
		time = offlineTime,
		orinExp = tmpExp,
		orinGold = tmpGold,
		exp = tmpExp,
		gold = tmpGold,
		currency = {},
		--equipCount
		--selledCount
	}
	--普通怪
	local dropCount = math.floor(conf.dropEff / 60 * effTime)
	local reward = drop.dropGroupExpected(conf.offlineDropId, dropCount)
	--精英怪
	local dropEliteCount = math.floor((conf.dropEliteEff or 0) / 60 * effTime)
	local rewardElite = drop.dropGroupExpected(conf.offlineEliteDropId or 0, dropEliteCount)
	--合并到奖励里面
	for _,v in ipairs(rewardElite) do
		table.insert(reward, v)
	end
	rewardElite = nil
	
	local bagSpace = LActor.getEquipBagSpace(actor)
	local equipCount = 0
	local rewardCount = actorawards.awardsNeedCount(reward, LActor.getJob(actor))
	local selledCount, selledGold = 0,0
	
	if bagSpace >= rewardCount then
		equipCount = rewardCount
		for _, v in ipairs(reward) do
			LActor.giveAward(actor, v.type, v.id, v.count, "offline reward")
			if (v.type or 0) ~= AwardType_Item then
				var.offlinedata.currency[v.id] = (var.offlinedata.currency[v.id] or 0) + v.count
			end
		end
	else
		local left_reward = {}
		--过滤获取掉所有的非装备的奖励
		for _, v in ipairs(reward) do
			if (v.type or 0) == AwardType_Item then
				--判断是否是装备
				if itemConf and item.isEquip(ItemConfig[v.id or 0]) then
					local count = math.floor(v.count/rewardCount*bagSpace)
					v.count = v.count - count
					equipCount = equipCount + count
					if v.count > 0 then
						table.insert(left_reward, v)
					end
					if count > 0 then
						LActor.giveAward(actor, v.type, v.id, count, "offline reward")
					end
				else --不是装备,直接发奖励,不用考虑格子数
					LActor.giveAward(actor, v.type, v.id, v.count, "offline reward")
				end
			else --不是道具,就是货币类型,直接发奖励,不需要考虑格子数
				LActor.giveAward(actor, v.type, v.id, v.count, "offline reward")
				var.offlinedata.currency[v.id] = (var.offlinedata.currency[v.id] or 0) + v.count
			end
		end
			
		local left = bagSpace - equipCount --还剩余的背包格子
		for _, v in ipairs(left_reward) do --这里全部会是需要背包格子的装备
			if (v.type or 0) == AwardType_Item then
				if left > 0 then --还有剩余的背包格子
					--填充满背包
					local gcount = math.min(left, v.count)
					LActor.giveAward(actor, v.type, v.id, gcount, "offline reward")
					v.count = v.count - gcount --奖励自己减少个数
					equipCount = equipCount + gcount --获得装备个数累加
					left = left - gcount --剩余格子数减少
				end
				if v.count > 0 then
					--剩余的卖掉
					local conf = EquipConfig[v.id]
					if conf then
						selledGold = selledGold + (conf.moneyNum or 0) * v.count
						selledCount = selledCount + v.count
					end
				end
			end
		end
	end

	local expex = specialattribute.get(actor,specialattribute.expEx)
	local goldex = specialattribute.get(actor,specialattribute.goldEx)
	if expex ~= 0 then 
		expex = expex / 100
	end
	if goldex ~= 0 then
		goldex = goldex / 100
	end

	var.offlinedata.equipCount = equipCount
	var.offlinedata.selledCount = selledCount

	var.offlinedata.exp = math.floor(var.offlinedata.exp * (1 + expex))
	var.offlinedata.gold = math.floor(var.offlinedata.gold * (1 + goldex))

	var.offlinedata.gold = var.offlinedata.gold + selledGold


	LActor.addExp(actor, var.offlinedata.exp , "offline reward")
	LActor.changeGold(actor, var.offlinedata.gold , "offline reward")
end

--local function onFitterGetBossRewards(ins, actor, rewards)
--	if rewards == nil then
--		return
--	end
--	ins:setRewards(actor, rewards)
--end

--[[
local function onGetBossRewards(ins, actor)
	--关卡副本特殊处理
	if ins.data.isChapter and ins.is_win and ins.data.rewarded == nil then
		--更新关卡记录
		local data = getStaticData(actor)
		data.level = data.level + 1
		--把这个值放在ActorBasicData里, 离线需要用到
		LActor.setChapterLevel(actor, data.level)
		--LActor.exitFuben(actor)
        chapterrank.updateRankingList(actor, data.level)
		ins.data.rewarded = true
	end
end
]]

local function getChapterSceneId(cid)
    if ChaptersConfig[cid] == nil then
        print("chapter config is nil. level:"..cid)
        return 0,0,0
    end
	local cfg = ChaptersConfig[cid]
	local x = 0
	local y = 0
	if cfg.enterPos and cfg.enterPos.x then
		x = cfg.enterPos.x
	end
	if cfg.enterPos and cfg.enterPos.y then
		y = cfg.enterPos.y
	end
    return cfg.sid, x, y
end

--请求领取奖励
local function onReqGetReward(actor, packet)
	local type = LDataPack.readByte(packet)
	local cache = getDynamicData(actor)
	--处理奖励
	local allAwards = {}
	if type == 0 then --杀死了一只普通怪
		if cache.reward and #cache.reward > 0 then
			for _, awards in ipairs(cache.reward) do
				for _,v in ipairs(awards) do
					local isFind = false
					for _,av in ipairs(allAwards) do
						if av.type == v.type and av.id == v.id then
							av.count = av.count + v.count
							isFind = true
							break
						end
					end
					if isFind == false then
						table.insert(allAwards, {type = v.type, id = v.id, count = v.count})
					end
				end
			end
		end

		--处理经验
		if cache.expReward and cache.expReward > 0 then
			local  notShowLog = false
			local data = getStaticData(actor)
			if (data.level % 10) == 0 then 
				notShowLog = true
			end
			LActor.addExp(actor, cache.expReward, "chapter",notShowLog)
		end
		cache.expReward = nil
		cache.reward = nil
	else --杀死了一只精英怪
		if not cache.elitereward or #cache.elitereward <= 0 then
			return
		end
		allAwards = table.remove(cache.elitereward, 1)
	end
	
	if not LActor.canGiveAwards(actor, allAwards) then LActor.sendTipWithId(actor, 1) end
	LActor.giveAwards(actor, allAwards, "chapter wave reward")
end

local function killChapterMonster(actor, packet)
	local data = getStaticData(actor)
	if not data.level then return end
	local monsterId = LDataPack.readInt(packet)
	actorevent.onEvent(actor, aeKillChapterMonster, monsterId, 1)
end
netmsgdispatcher.reg(Protocol.CMD_Fuben, Protocol.cFubenCmd_KillChapterMonster, killChapterMonster) --客户端杀了一只怪

netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_ReqGetReward, onReqGetReward)--请求领取奖励
netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_ChallengeBoss, onChallengeBoss)
netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_ReqChapterReward, onReqChapterReward)
netmsgdispatcher.reg(p.CMD_Fuben, p.cFubenCmd_ReqWorldReward, onReqWorldReward)

local function onOffline(ins, actor)
	if ins.is_win then
		local aid = LActor.getActorId(actor)
		local rewards = ins.actor_list[aid].rewards
		if rewards then
			if LActor.canGiveAwards(actor, rewards) then
				for _,v in ipairs(rewards) do
					if not v.ng then
						LActor.giveAward(actor, v, "chapter,win,offline")
					end
				end
			else
				local mailCfg = mailcommon.getConfigByMailId(6)
				local mailData = {
					head=mailCfg.title,
					context=mailCfg.content,
					tAwardList={}
				}
				for _,v in ipairs(rewards) do
					if not v.ng then
						table.insert(mailData.tAwardList, v)
					end
				end
				mailsystem.sendMailById(LActor.getActorId(actor), mailData)
			end
		end
		ins.actor_list[aid].rewards = nil
	end
	LActor.exitFuben(actor)
end

--注册相关回调
for _, v in pairs(ChaptersConfig) do
	insevent.registerInstanceWin(v.bossFid, onBossWin)
	insevent.registerInstanceLose(v.bossFid, onBossLose)
	--insevent.registerInsFittertanceGetRewards(v.bossFid, onFitterGetBossRewards)
	--insevent.registerInstanceGetRewards(v.bossFid, onGetBossRewards)
	insevent.registerInstanceOffline(v.bossFid, onOffline)
end


actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeBeforeLogin, onBeforeLogin)

insevent.registerInstanceEnter(0, onEnterStaticFuben)
insevent.registerInstanceExit(0, onExitStaticFuben)


function gmChapter2(actor, lv)
	if lv == nil then
		if LActor.isInFuben(actor) then
			--更新关卡记录
			local data =getStaticData(actor)
			data.level = data.level + 1
			--把这个值放在ActorBasicData里, 离线需要用到
			LActor.setChapterLevel(actor, data.level)

			LActor.exitFuben(actor)
			return
		end

		--if LActor.checkEnterFuBen(actor) == false then return end
		createBossFuben(actor)
	else
		lv = tonumber(lv)
		if lv ~= nil  and ChaptersConfig[lv] ~= nil then
			--更新关卡记录
			local data =getStaticData(actor)
			data.level = lv
			--把这个值放在ActorBasicData里, 离线需要用到
			LActor.setChapterLevel(actor, data.level)
			if LActor.isInFuben(actor) then
				LActor.exitFuben(actor)
				return
			else
				LActor.relive(actor)
			end
		end
	end
end

_G.getChapterSceneId = getChapterSceneId
