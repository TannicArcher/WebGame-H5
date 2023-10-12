-- 达标
module("psubactivitytype1", package.seeall)
--[[
data define:
	data = {
		rewardsRecord 按位领取
		useyuanbao 消费
	}
]]

local p = Protocol
local subType = 1

-- 下发数据
local function writeRewardRecord(npack, record, config, id, actor)
	if npack == nil then return end
	if record and record.data then
		LDataPack.writeInt(npack, record.data.rewardsRecord or 0)
		LDataPack.writeInt(npack, record.data.useyuanbao or 0)
	else
		LDataPack.writeInt(npack, 0)
		LDataPack.writeInt(npack, 0)
	end
	LDataPack.writeShort(npack, 0)
end

-- 翅膀
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

-- 铸造
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

-- 龙魂
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

-- 获取消耗的元宝
local function getConsumeYb(actor, id)
	local record = pactivitysystem.getSubVar(actor, id)
	if record and record.data then
		return record.data.useyuanbao or 0
	end

	return 0
end

-- 检测达标奖励
local function checkLevelReward(index, config, actor, record, id)
	if config[index] == nil then
		return false
	end

	if index < 0 or index > 32 then
		print("config is err , index is invalid.."..index)
		return false
	end
	
	local cfg = config[index]
	
	--等级
	if LActor.getLevel(actor) < (cfg.level or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not level("..LActor.getLevel(actor)..") cfg("..(cfg.level or 0)..")")
		return false
	end

	--转生
	if LActor.getZhuanShengLevel(actor) < (cfg.zslevel or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not zhuanshenglevel("..LActor.getZhuanShengLevel(actor)..") cfg("..(cfg.zslevel or 0)..")")
		return false
	end

	-- 战灵等级
	if cfg.zhanlingLv and zhanlingsystem.getZhanLingLevel(actor) < cfg.zhanlingLv then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not zhanlingLv("..zhanlingsystem.getZhanLingLevel(actor)..") cfg("..(cfg.zhanlingLv or 0)..")")
		return
	end

	--翅膀
	if cfg.wingLv and getTotalWingLv(actor) < (cfg.wingLv or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not wingLv("..getTotalWingLv(actor)..") cfg("..(cfg.wingLv or 0)..")")
		return false
	end
	
	--铸造
	if cfg.zzLv and getTotalZhulingLv(actor) < (cfg.zzLv or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not zzLv("..getTotalZhulingLv(actor)..") cfg("..(cfg.zzLv or 0)..")")
		return false
	end
	
	--龙魂
	if cfg.lhLv and getTotalSoulShieldLv(actor) < (cfg.lhLv or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not lhLv("..getTotalSoulShieldLv(actor)..") cfg("..(cfg.lhLv or 0)..")")
		return false
	end
	
	--神装
	if cfg.szLv and getTotalOrangeEquipLv(actor) < (cfg.szLv or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not szLv("..getTotalOrangeEquipLv(actor)..") cfg("..(cfg.szLv or 0)..")")
		return false
	end
	
	--图鉴总战力
	if cfg.tjPower and LActor.TuJianPower(actor) < (cfg.tjPower or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not tjPower("..LActor.TuJianPower(actor)..") cfg("..(cfg.tjPower or 0)..")")
		return false
	end

	--装备总评分
	if cfg.equipPower and LActor.getEquipBasePower(actor) < (cfg.equipPower or 0) then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not equipPower("..LActor.getEquipBasePower(actor)..") cfg("..(cfg.equipPower or 0)..")")
		return false
	end
	--累计消费
	if cfg.consumeYuanbao and getConsumeYb(actor, id) < cfg.consumeYuanbao then
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not consumeYuanbao("..getConsumeYb(actor, id)..") cfg("..(cfg.consumeYuanbao or 0)..")")
		return false;
	end
	--烈焰戒指等级
	if cfg.huoyanRingLv and LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing) < cfg.huoyanRingLv then
		local lv = LActor.getActorExRingLevel(actor, ActorExRingType_HuoYanRing)
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not huoyanRingLv("..lv..") cfg("..(cfg.huoyanRingLv or 0)..")")
		return false
	end

	-- 轮回等级
	if cfg.lunhLv and LActor.getReincarnateLv(actor) < cfg.lunhLv then
		local lv = LActor.getReincarnateLv(actor)
		print(LActor.getActorId(actor).." psubactivitytype1.checkLevelReward not lunhLv("..lv..") cfg("..(cfg.lunhLv or 0)..")")
		return false
	end
	
	-- 初始化记录
	if not record.data then record.data = {} end

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
	local ret = checkLevelReward(index, config, actor, record, id)

	if ret then
		-- 记录
		record.data.rewardsRecord = System.bitOpSetMask(record.data.rewardsRecord, index, true)
		LActor.giveAwards(actor, config[index].rewards, "pactivity type1 rewards")
		--公告广播
		if config[index].notice then
			noticemanager.broadCastNotice(config[index].notice, LActor.getName(actor))
		end
		-- print("xxxxxxxxxx psubactivitytype1 getLevelReward,actor:"..LActor.getActorId(actor)..",rewards:"..utils.t2s(config[index].rewards))
	end
	
	local npack = LDataPack.allocPacket(actor, p.CMD_PActivity, p.sPActivityCmd_GetRewardResult)
	LDataPack.writeByte(npack, ret and 1 or 0)
	LDataPack.writeInt(npack, id)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, record.data and record.data.rewardsRecord or 0)
	LDataPack.flush(npack)
end

--消费
local function onUseYB(id, conf)
	return function(actor, value)
		-- 判断活动是否开启过，未开启的活动不处理
		if not pactivitysystem.isPActivityOpened(actor, id) then
			return
		end
		if pactivitysystem.isPActivityEnd(actor, id) then return end

		local record = pactivitysystem.getSubVar(actor, id)
		if not record then
			print("psubactivitytype1 onUseYB record is nil,actor:"..LActor.getActorId(actor)..",id"..id)
			return
		end

		-- 初始化数据
		if not record.data then record.data = {} end
		record.data.useyuanbao = (record.data.useyuanbao or 0) + value
		pactivitysystem.sendActivityData(actor, id)

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

pactivitysystem.regConf(subType, PActivityType1Config)
pactivitysystem.regInitFunc(subType, initFunc)
pactivitysystem.regWriteRecordFunc(subType, writeRewardRecord)
pactivitysystem.regGetRewardFunc(subType, getLevelReward)
