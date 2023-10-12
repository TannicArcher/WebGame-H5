module("subactivitytype1", package.seeall)


local p = Protocol
local subType = 1
local function writeRewardRecord(npack, record, config, id, actor)
	if npack == nil then return end
	if record and record.data then
		LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
		LDataPack.writeInt(npack, record.data.useyuanbao or 0)
	else
		LDataPack.writeInt(npack, 0)
		LDataPack.writeInt(npack, 0)
	end

	-- 全服统计
	local gdata = activitysystem.getGlobalVar(id)	
	local count = #config
	LDataPack.writeShort(npack, count)
	for i=1,count do
		LDataPack.writeShort(npack, gdata and gdata.recCount and gdata.recCount[i] or 0)
	end
end

local function getTotalWingLv(actor)
	local lv = 0
	local role_count = LActor.getRoleCount(actor)
	for role_id=0,role_count-1 do
		local level, exp, status, ctime = LActor.getWingInfo(actor, role_id)
		if status ~= 0 then
			lv = lv + level + 1
		end
	end
	return lv
end

local function getTotalZhulingLv(actor)
	local lv = 0
	local role_count = LActor.getRoleCount(actor)
	for role_id=0,role_count-1 do
		local tZhulingInfo = LActor.getZhulingInfo(actor, role_id)
		if tZhulingInfo then
			--按EnhanceConfig配置的顺序遍历
			for index = 1, #ForgeIndexConfig do
				local posId = ForgeIndexConfig[index].posId					
				lv = lv + (tZhulingInfo[posId] or 0)
			end
		end
	end	
	return lv
end

local function getTotalSoulShieldLv(actor)
	local lv = 0
	local role_count = LActor.getRoleCount(actor)
	for role_id=0,role_count-1 do
		local stage,level,exp = LActor.getSoulShieldinfo(actor, role_id, ssLoongSoul)
		lv = lv + level
	end	
	return lv
end
local QualityType_Orange = 4--神装的品质
local function getTotalOrangeEquipLv(actor)
	local lv = 0 --QualityType_Orange
	local role_count = LActor.getRoleCount(actor)
	for role_id=0,role_count-1 do
		local role = LActor.getRole(actor, role_id)
		if role then
			for _,v in ipairs(ForgeIndexConfig) do
				if LActor.getEquipQuality(role, v.posId) == QualityType_Orange then
					local level,zsLevel = LActor.getEquipLevel(role, v.posId, 0)
					lv = lv + zsLevel
				end
			end
		end
	end
	return lv
end

local function getConsumeYb(actor, id)
	local record = activitysystem.getSubVar(actor, id)
	if record and record.data then
		return record.data.useyuanbao or 0
	end

	return 0
end

local function checkLevelReward(index, config, actor, record, gdata, id)
	if config[index] == nil then
		return false
	end

	if index < 0 or index > 32 then
		print("config is err , index is invalid.."..index)
		return false
	end
	
	local cfg = config[index]

	--领取次数
	if cfg.total and gdata.recCount and (gdata.recCount[index] or 0)  >= cfg.total then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not total count")
		return false
	end
	
	--等级
	if LActor.getLevel(actor) < (cfg.level or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not level")
		return false
	end

	--转生
	if LActor.getZhuanShengLevel(actor) < (cfg.zslevel or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not zhuanshenglevel")
		return false
	end

	-- 战灵等级
	if cfg.zhanlingLv and zhanlingsystem.getZhanLingLevel(actor) < cfg.zhanlingLv then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not zhanlingLv")
		return
	end

	--翅膀
	if cfg.wingLv and getTotalWingLv(actor) < (cfg.wingLv or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not wingLv("..getTotalWingLv(actor)..") cfg("..(cfg.wingLv or 0)..")")
		return false
	end
	
	--铸造
	if cfg.zzLv and getTotalZhulingLv(actor) < (cfg.zzLv or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not zzLv("..getTotalZhulingLv(actor)..") cfg("..(cfg.zzLv or 0)..")")
		return false
	end
	
	--龙魂
	if cfg.lhLv and getTotalSoulShieldLv(actor) < (cfg.lhLv or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not lhLv("..getTotalSoulShieldLv(actor)..") cfg("..(cfg.lhLv or 0)..")")
		return false
	end
	
	--神装
	if cfg.szLv and getTotalOrangeEquipLv(actor) < (cfg.szLv or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not szLv("..getTotalOrangeEquipLv(actor)..") cfg("..(cfg.szLv or 0)..")")
		return false
	end
	
	--图鉴总战力
	if cfg.tjPower and LActor.TuJianPower(actor) < (cfg.tjPower or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not tjPower("..LActor.TuJianPower(actor)..") cfg("..(cfg.tjPower or 0)..")")
		return false
	end

	--装备总评分
	if cfg.equipPower and LActor.getEquipBasePower(actor) < (cfg.equipPower or 0) then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not equipPower("..LActor.getEquipBasePower(actor)..") cfg("..(cfg.equipPower or 0)..")")
		return false
	end
	--累计消费
	if cfg.consumeYuanbao and getConsumeYb(actor, id) < cfg.consumeYuanbao then
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not consumeYuanbao("..getConsumeYb(actor, id)..") cfg("..(cfg.consumeYuanbao or 0)..")")
		return false;
	end
	--烈焰戒指等级
	if cfg.huoyanRingLv and LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) < cfg.huoyanRingLv then
		local lv = LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing)
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not huoyanRingLv("..lv..") cfg("..(cfg.huoyanRingLv or 0)..")")
		return false
	end

	-- 轮回等级
	if cfg.lunhLv and LActor.getReincarnateLv(actor) < cfg.lunhLv then
		local lv = LActor.getReincarnateLv(actor)
		print(LActor.getActorId(actor).." subactivitytype1.checkLevelReward not lunhLv("..lv..") cfg("..(cfg.lunhLv or 0)..")")
		return false
	end
	
	if record.data.rewardsRecord == nil then
		record.data.rewardsRecord = 0
	end

	if System.bitOPMask(record.data.rewardsRecord, index) then
		return false
	end

	if not LActor.canGiveAwards(actor, config[index].rewards) then
		return false
	end

	return true
end

local function getLevelReward(id, typeconfig, actor, record, packet)
	local index = LDataPack.readShort(packet)
	local config = typeconfig[id]
	local gdata = activitysystem.getGlobalVar(id)
	local ret = checkLevelReward(index, config, actor, record, gdata, id)

	if ret then
		-- 记录
		record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, index, true)
		LActor.giveAwards(actor, config[index].rewards, "activity type1 rewards")
		--记录已领取次数,全服统计
		if gdata.recCount == nil then gdata.recCount = {} end
		gdata.recCount[index] = (gdata.recCount[index] or 0) + 1
		--公告广播
		if config[index].notice then
			noticemanager.broadCastNotice(config[index].notice, LActor.getName(actor))
		end
	end
	
	local npack = LDataPack.allocPacket(actor, p.CMD_Activity, p.sActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

--消费
local function onUseYB(id, conf)
	return function(actor, value)	
		local record = activitysystem.getSubVar(actor, id)
		if record and record.data then
			record.data.useyuanbao = (record.data.useyuanbao or 0) + value
			activitysystem.sendActivityData(actor, id)
		end
	end
end

local function initFunc(id, conf)
	local needRegEvent = false
	--启动服务器时检测是否有配置consumeYuanbao字段
	for _,v in pairs(conf) do
		if v.consumeYuanbao then
			needRegEvent = true
			break
		end
	end
	--有consumeYuanbao字段就监听消费
	if needRegEvent then
		actorevent.reg(aeConsumeYuanbao, onUseYB(id, conf))
	end
end

subactivities.regConf(subType, ActivityType1Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRewardRecord)
subactivities.regGetRewardFunc(subType, getLevelReward)
