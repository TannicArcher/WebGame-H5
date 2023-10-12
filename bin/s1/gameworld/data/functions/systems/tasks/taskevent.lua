module("taskevent", package.seeall)


--[[
  任务条件记录
  taskEventRecord = {
    type: value number  -- (type: taskcommon.taskType  value:条件累积值
  }
--]]

--外部接口
function getRecord(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        print("get taskevent static data error")
        return nil
    end

    if var.taskEventRecord == nil then
        var.taskEventRecord = {}
        --此处不做初始化, 防止类型扩展时初始化不到
    end
    return var.taskEventRecord
end

function needParam(type)
    if type == taskcommon.taskType.emPassDup
            or type == taskcommon.taskType.emPassTypeDup 
            or type == taskcommon.taskType.emFinishTypeDup 
            or type == taskcommon.taskType.emFinishDup
            or type == taskcommon.taskType.emFullBoss
            or type == taskcommon.taskType.emArtifact
			or type == taskcommon.taskType.emReqChapterReward
			or type == taskcommon.taskType.emReqChapterWorldReward
			or type == taskcommon.taskType.emEquipSlotCount
			or type == taskcommon.taskType.emActImba
			or type == taskcommon.taskType.emGetTypeItem
			or type == taskcommon.taskType.emActImbaItem
            or type == taskcommon.taskType.emCaiKuangId
            or type == taskcommon.taskType.emLimitTagTaskFinish
			or type == taskcommon.taskType.emOverTypeDup
			then 
        return  taskcommon.Param.emFuben
    elseif type == taskcommon.taskType.emOrange 
        or type == taskcommon.taskType.emLegend 
            then
        return  taskcommon.Param.emChenZhuan
	elseif type == taskcommon.taskType.emEquipLvCount 
			or type == taskcommon.taskType.emEquipOrangeCount 
            then
        return taskcommon.Param.emParamEGt
    elseif type == taskcommon.taskType.emSkirmishRank 
            then
        return taskcommon.Param.emParamELt
    else 
        return  taskcommon.Param.emOrdinary
    end
end

local initRecordFuncs = {}
initRecordFuncs[taskcommon.taskType.emChapterLevel] = LActor.getChapterLevel
initRecordFuncs[taskcommon.taskType.emActorLevel] = LActor.getLevel

--后面扩展的任务类型才需要,前面的任务不需要初始化功能
function initRecord(type, actor)
	if initRecordFuncs[type] then
		return initRecordFuncs[type](actor)
	else
		return 0
	end
end

local function updateTask(actor, type, param, count, roleId)
	dailytask.updateDailyTask(actor, type, param, count)
	achievetask.updateAchieveTask(actor, type, param, count)
	guildtask.updateTask(actor, type, param, count)
	limittimetask.updateTask(actor, type, param, count)
	godweaponbase.addGodweaponTaskTarget(actor, type, param)
    prestigesystem.updateTask(actor, type, param, count)
    activitysystem.updateTask(actor, type, param, count)
end

function onUpgradeSkillCount(actor, roleId, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emSkillLevelup] = (record[taskcommon.taskType.emSkillLevelup] or 0) + count

    updateTask(actor, taskcommon.taskType.emSkillLevelup, 0, count, roleId)
end

function onEnhanceEquip(actor, roleId, posId, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emEnhanceEquip] = (record[taskcommon.taskType.emEnhanceEquip] or 0) + 1

    updateTask(actor, taskcommon.taskType.emEnhanceEquip, 0, 1, roleId)
end

function onWingTrainCount(actor, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emWingTrainCount] = (record[taskcommon.taskType.emWingTrainCount] or 0) + count

    updateTask(actor, taskcommon.taskType.emWingTrainCount, 0, count)
end

function onSmeltEquip(actor, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emSmeltEquip] = (record[taskcommon.taskType.emSmeltEquip] or 0) + count
    updateTask(actor, taskcommon.taskType.emSmeltEquip, 0, count)
end

function onSkirmish(actor, result)
    local record = getRecord(actor)
    record[taskcommon.taskType.emSkirmish] = (record[taskcommon.taskType.emSkirmish] or 0) + 1

    updateTask(actor, taskcommon.taskType.emSkirmish, 0, 1)
end

function onUpgradeSkillLevel(actor, roleId, index, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emSkillLevel] or 0
    if level > recordLevel then
        record[taskcommon.taskType.emSkillLevel] = level
    end
    updateTask(actor, taskcommon.taskType.emSkillLevel, 0, level, roleId)
end

function onEquipLevel(actor, roleId, posId, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emEquipLevel] or 0
    if level > recordLevel then
        record[taskcommon.taskType.emEquipLevel] = level
    end
    updateTask(actor, taskcommon.taskType.emEquipLevel, 0, level, roleId)
end

function onLevelUp(actor, level)
	--local record = getRecord(actor)
	--record[taskcommon.taskType.emActorLevel] = level
    updateTask(actor, taskcommon.taskType.emActorLevel, 0, level)
end

function onFightPower(actor, fightPower)
    local record = getRecord(actor)
    local recordPower = record[taskcommon.taskType.emFightPower] or 0
    if fightPower > recordPower then
        record[taskcommon.taskType.emFightPower] = fightPower
    end

    updateTask(actor, taskcommon.taskType.emFightPower, 0, fightPower)
end

function onEnterFuben(actor, fubenId, isLogin)
    if isLogin then return end
	local config = InstanceConfig[fubenId]
	--野外BOSS和全民BOSS另外处理
	if config then
        local record = getRecord(actor)
		--进入指定ID副本
		if config.type ~= FuBenType_Chapter and config.type ~= FuBenType_Pata then
			if record[taskcommon.taskType.emPassDup] == nil then
				record[taskcommon.taskType.emPassDup] = {}
			end
			record[taskcommon.taskType.emPassDup][fubenId] = (record[taskcommon.taskType.emPassDup][fubenId] or 0) + 1
		end
		updateTask(actor, taskcommon.taskType.emPassDup, fubenId, 1)
		--进入指定类型副本
        if record[taskcommon.taskType.emPassTypeDup] == nil then
            record[taskcommon.taskType.emPassTypeDup] = {}
        end
        record[taskcommon.taskType.emPassTypeDup][config.type] = (record[taskcommon.taskType.emPassTypeDup][config.type] or 0) + 1
		updateTask(actor, taskcommon.taskType.emPassTypeDup, config.type, 1)
		
		if fubenId == 0 then
			local clv = LActor.getChapterLevel(actor)
			record[taskcommon.taskType.emEnterChapterLv] = clv
			updateTask(actor, taskcommon.taskType.emEnterChapterLv, 0, clv)
		end
	end
end

--因为玩家看到的显示的1级其实是后端数据的0级
--所以这里level+1，让策划填表和前端显示不用填0级和显示进度0/0那么奇怪
function onWingLevelUp(actor, roleId, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emWingMaxLevel] or 1
    if level + 1 > recordLevel then
        record[taskcommon.taskType.emWingMaxLevel] = level + 1
    end
    record[taskcommon.taskType.emWingLevelUpCount] = (record[taskcommon.taskType.emWingLevelUpCount] or 0) + 1

    updateTask(actor, taskcommon.taskType.emWingMaxLevel, 0, level + 1, roleId)

    updateTask(actor, taskcommon.taskType.emWingLevelUpCount, 0, 1, roleId)
end

function onWingStarUp(actor, roleId, starUpCount)
    local record = getRecord(actor)
    record[taskcommon.taskType.emWingStarUpCount] = (record[taskcommon.taskType.emWingStarUpCount] or 0) + starUpCount
    record[taskcommon.taskType.emWingtotalStar] = (record[taskcommon.taskType.emWingtotalStar] or 0) + starUpCount
    print("starUpCount:"..starUpCount)
    updateTask(actor, taskcommon.taskType.emWingtotalStar, 0, starUpCount, roleId)
    updateTask(actor, taskcommon.taskType.emWingStarUpCount, 0, starUpCount, roleId)
end

function onLearnMiJi(actor, roleId, id)
	local record = getRecord(actor)
	record[taskcommon.taskType.emLearnMiJiCount] = (record[taskcommon.taskType.emLearnMiJiCount] or 0) + 1

	updateTask(actor, taskcommon.taskType.emLearnMiJiCount, 0, 1, roleId)
end

function onJingmaiLevelup(actor, roleId, level, stage)
    local record = getRecord(actor)
    local recordStage = record[taskcommon.taskType.emJingmaiStage] or 0
    if stage > recordStage then
        record[taskcommon.taskType.emJingmaiStage] = stage
    end
    record[taskcommon.taskType.emUpgradeJingmaiCount] = (record[taskcommon.taskType.emUpgradeJingmaiCount] or 0)+ 1
    record[taskcommon.taskType.emJingMaitotalLevel] = (record[taskcommon.taskType.emJingMaitotalLevel] or 0)+ level
    updateTask(actor, taskcommon.taskType.emJingMaitotalLevel, 0, level, roleId)
    updateTask(actor, taskcommon.taskType.emJingmaiStage, 0, 1, roleId)
    updateTask(actor, taskcommon.taskType.emUpgradeJingmaiCount, 0, 1, roleId)
end

function onGetTreasureBoxType(actor, type)
    local record = getRecord(actor)
    if record[taskcommon.taskType.emGetTreasureBoxType] == nil then
        record[taskcommon.taskType.emGetTreasureBoxType] = {}
    end
    record[taskcommon.taskType.emGetTreasureBoxType][type] = (record[taskcommon.taskType.emGetTreasureBoxType][type] or 0)+ 1
    updateTask(actor, taskcommon.taskType.emGetTreasureBoxType, type, 1)
end

function onChallengeFb(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emChallengeFb] = (record[taskcommon.taskType.emChallengeFb] or 0)+ 1
    updateTask(actor, taskcommon.taskType.emChallengeFb, 0, 1)
end

function onTuJian(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emTuJian] = (record[taskcommon.taskType.emTuJian] or 0)+ 1
    updateTask(actor, taskcommon.taskType.emTuJian, 0, 1)
end

function onFuWenLevel(actor, level)
    local record = getRecord(actor)
    record[taskcommon.taskType.emFuWenLevel] = level
    updateTask(actor, taskcommon.taskType.emFuWenLevel, 0, level)
end

function onTreasureBoxReward(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emTreasureBoxReward] = (record[taskcommon.taskType.emTreasureBoxReward] or 0)+ 1
    updateTask(actor, taskcommon.taskType.emTreasureBoxReward, 0, 1)
end

function onStoneLevelup(actor, roleId, posId, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emStoneLevel] or 0
    if level > recordLevel then
        record[taskcommon.taskType.emStoneLevel] = level
    end
    record[taskcommon.taskType.emUpgradeStoneCount] = (record[taskcommon.taskType.emUpgradeStoneCount] or 0)+ 1
    record[taskcommon.taskType.emStonetotalLevel] = (record[taskcommon.taskType.emStonetotalLevel] or 0)+ 1

    updateTask(actor, taskcommon.taskType.emStoneLevel, 0, level, roleId)
    updateTask(actor, taskcommon.taskType.emUpgradeStoneCount, 0, 1, roleId)
    updateTask(actor, taskcommon.taskType.emStonetotalLevel, 0, 1, roleId)
end

function onZhulingLevelup(actor, roleId, posId, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emZhulingLevel] or 0
    if level > recordLevel then
        record[taskcommon.taskType.emZhulingLevel] = level
    end

    --local record = getRecord(actor)
    --record[taskcommon.taskType.emEquipZhuling] = (record[taskcommon.taskType.emEquipZhuling] or 0) + 1
    record[taskcommon.taskType.emZhulingtotalLevel] = (record[taskcommon.taskType.emZhulingtotalLevel] or 0)+ 1

    --updateTask(actor, taskcommon.taskType.emEquipZhuling, 0, 1, roleId)
    updateTask(actor, taskcommon.taskType.emZhulingtotalLevel, 0, 1, roleId)
    updateTask(actor, taskcommon.taskType.emZhulingLevel, 0, level, roleId)
end

function onTupoLevelup(actor, roleId, posId, level)
    local record = getRecord(actor)
    local recordLevel = record[taskcommon.taskType.emTupoLevel] or 0
    if level > recordLevel then
        record[taskcommon.taskType.emTupoLevel] = level
    end

    updateTask(actor, taskcommon.taskType.emTupoLevel, 0, level, roleId)
end

function onStoreCost(actor, currencyType, value)
	if (currencyType == NumericType_YuanBao) then
        local record = getRecord(actor)
        record[taskcommon.taskType.emUseYBInStore] = (record[taskcommon.taskType.emUseYBInStore] or 0) + value

        updateTask(actor, taskcommon.taskType.emUseYBInStore, 0, value)
	end
end

function onOpenRole(actor, roleCount)
    local record = getRecord(actor)
    record[taskcommon.taskType.emRoleCount] = roleCount

    updateTask(actor, taskcommon.taskType.emRoleCount, 0, roleCount)
end

function onZhuansheng(actor, zhuanshengLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emZhuanshengCount] = zhuanshengLevel

    updateTask(actor, taskcommon.taskType.emZhuanshengCount, 0, zhuanshengLevel)
end

function onEquipItem(actor, roleId, slot)
    local record = getRecord(actor)
	--装备穿戴次数
    record[taskcommon.taskType.emEquipCount] = (record[taskcommon.taskType.emEquipCount] or 0) + 1
    updateTask(actor, taskcommon.taskType.emEquipCount, 0, 1, roleId)
	
	--指定部位穿戴次数
	if record[taskcommon.taskType.emEquipSlotCount] == nil then
		record[taskcommon.taskType.emEquipSlotCount] = {}
	end
	record[taskcommon.taskType.emEquipSlotCount][slot] = (record[taskcommon.taskType.emEquipSlotCount][slot] or 0) + 1
	updateTask(actor, taskcommon.taskType.emEquipSlotCount, slot, 1, roleId)
	
	--穿戴指定等级装备个数
	local role = LActor.getRole(actor, roleId)
	if role then
		local lvCoun = {}
		--遍历角色全身装备
		for _,v in ipairs(ForgeIndexConfig) do
			local index = v.posId 
			local level,szLevel = LActor.getEquipLevel(role,index, 0)
			lvCoun[szLevel*1000+level] = (lvCoun[szLevel*1000+level] or 0)+1
		end
		--计算向下累加后的等级对应个数表
		local lvCounLe = utils.table_clone(lvCoun)
		for lv,count in pairs(lvCoun) do
			for lvL,_ in pairs(lvCounLe) do
				if lvL < lv then
					lvCounLe[lvL] = lvCounLe[lvL] + count
				end
			end
		end
		--任务update
		record[taskcommon.taskType.emEquipLvCount] = {}
		for lv,count in pairs(lvCounLe) do --会求最大的,所以没问题的,不怕重复覆盖
			record[taskcommon.taskType.emEquipLvCount][lv] = count
			updateTask(actor, taskcommon.taskType.emEquipLvCount, lv, count, roleId)
		end
	end

    --穿戴指定等级橙装装备个数
    if role and LActor.getEquipQuality(role, slot) >= 4 then
		local lvCoun = {}
		for i=0, LActor.getRoleCount(actor)-1 do
			local role = LActor.getRole(actor, i)
			if role then
				--遍历角色全身装备
				for _,v in ipairs(ForgeIndexConfig) do
					local index = v.posId
					 if 4 <= LActor.getEquipQuality(role,index) then
						local level,szLevel = LActor.getEquipLevel(role,index, 0)
						lvCoun[szLevel*1000+level] = (lvCoun[szLevel*1000+level] or 0)+1
					end
				end
			end
		end
		--计算向下累加后的等级对应个数表
		local lvCounLe = utils.table_clone(lvCoun)
		for lv,count in pairs(lvCoun) do
			for lvL,_ in pairs(lvCounLe) do
				if lvL < lv then
					lvCounLe[lvL] = lvCounLe[lvL] + count
				end
			end
		end
		--任务update
		record[taskcommon.taskType.emEquipOrangeCount] = {}
		for lv,count in pairs(lvCounLe) do --会求最大的,所以没问题的,不怕重复覆盖
			record[taskcommon.taskType.emEquipOrangeCount][lv] = count
			updateTask(actor, taskcommon.taskType.emEquipOrangeCount, lv, count, roleId)
		end
    end
end

function onUpgradeLoongSoul(actor, roleId, loongSoulLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emUpgradeLoongCount] = (record[taskcommon.taskType.emUpgradeLoongCount] or 0) + 1

    updateTask(actor, taskcommon.taskType.emUpgradeLoongCount, 0, 1, roleId)
end

function onUpgradeShield(actor, roleId, shieldLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emUpgradeShieldCount] = (record[taskcommon.taskType.emUpgradeShieldCount] or 0) + 1

    updateTask(actor, taskcommon.taskType.emUpgradeShieldCount, 0, 1, roleId)
end

function onKillFeildBoss(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emfieldBossCount] = (record[taskcommon.taskType.emfieldBossCount] or 0) + 1

    updateTask(actor, taskcommon.taskType.emfieldBossCount, 0, 1)
end

function onLoseFinishFuben(actor, fubenId, fbtype)
	local record = getRecord(actor)
	if record[taskcommon.taskType.emOverTypeDup] == nil then
        record[taskcommon.taskType.emOverTypeDup] = {}
    end
    record[taskcommon.taskType.emOverTypeDup][fbtype] = (record[taskcommon.taskType.emOverTypeDup][fbtype] or 0) + 1
	updateTask(actor, taskcommon.taskType.emOverTypeDup, fbtype, 1)
end

function onFinishFuben(actor, fubenId)
    local config = InstanceConfig[fubenId]
    if config == nil then return end

    local record = getRecord(actor)
	
	if config.type ~= FuBenType_Chapter and config.type ~= FuBenType_Pata then
		if record[taskcommon.taskType.emFinishDup] == nil then
			record[taskcommon.taskType.emFinishDup] = {}
		end
		record[taskcommon.taskType.emFinishDup][fubenId] = (record[taskcommon.taskType.emFinishDup][fubenId] or 0) + 1
	end

    if record[taskcommon.taskType.emFinishTypeDup] == nil then
        record[taskcommon.taskType.emFinishTypeDup] = {}
    end
    record[taskcommon.taskType.emFinishTypeDup][config.type] = (record[taskcommon.taskType.emFinishTypeDup][config.type] or 0) + 1

    updateTask(actor, taskcommon.taskType.emFinishDup, fubenId, 1)
    updateTask(actor, taskcommon.taskType.emFinishTypeDup, config.type, 1)
	onLoseFinishFuben(actor, fubenId, config.type)
end

function onLoseFuben(actor, fubenId)
	local config = InstanceConfig[fubenId]
    if config == nil then return end
	onLoseFinishFuben(actor, fubenId, config.type)
end

function onJoinActivity(actor, id, count)
   if true == activitysystem.activityTimeIsEnd(id) then return end
   updateTask(actor, taskcommon.taskType.emJoinActivityId, id, count)
end

function onConsumeYuanbao(actor, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emConsumeYuanbao] = (record[taskcommon.taskType.emConsumeYuanbao] or 0) + count
    updateTask(actor, taskcommon.taskType.emConsumeYuanbao, 0, count)
end

function onConsumeGold(actor, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emConsumeGold] = (record[taskcommon.taskType.emConsumeGold] or 0) + count
    updateTask(actor, taskcommon.taskType.emConsumeGold, 0, count)
end

function onRichManCircle(actor, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emRichManCircle] = (record[taskcommon.taskType.emRichManCircle] or 0) + count
    updateTask(actor, taskcommon.taskType.emRichManCircle, 0, count)
end

function onExpFubenAwardType(actor, id, count)
    if not id or not count then return end
    local record = getRecord(actor)
    if nil == record[taskcommon.taskType.emExpFubenAwardType] then 
        record[taskcommon.taskType.emExpFubenAwardType] = {} 
    elseif type(record[taskcommon.taskType.emExpFubenAwardType]) == "number" then
        record[taskcommon.taskType.emExpFubenAwardType] = {} 
    end
    record[taskcommon.taskType.emExpFubenAwardType][id] = (record[taskcommon.taskType.emExpFubenAwardType][id] or 0) + count
    updateTask(actor, taskcommon.taskType.emExpFubenAwardType, id, count)
end

function onRechargeGold(actor, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emRechargeGold] = (record[taskcommon.taskType.emRechargeGold] or 0) + count
    updateTask(actor, taskcommon.taskType.emRechargeGold, 0, count)
end

function onGuildDonate(actor, type, id, value)
    local record = getRecord(actor)
    if type == AwardType_Numeric then
        if id == NumericType_YuanBao then
            record[taskcommon.taskType.emGuildDonateYb] = (record[taskcommon.taskType.emGuildDonateYb] or 0) + value
            updateTask(actor, taskcommon.taskType.emGuildDonateYb, value, 1)
        elseif id == NumericType_Gold then
            record[taskcommon.taskType.emGuildDonateGold] = (record[taskcommon.taskType.emGuildDonateGold] or 0) + value
            updateTask(actor, taskcommon.taskType.emGuildDonateGold, 0, 1)
        end
    elseif type == AwardType_Item then
        record[taskcommon.taskType.emGuildDonateItem] = (record[taskcommon.taskType.emGuildDonateItem] or 0) + value
        updateTask(actor, taskcommon.taskType.emGuildDonateItem, id, value)
    end
end

function onTianTiChallenge(actor)
	local record = getRecord(actor)
	record[taskcommon.taskType.emTianTiChallenge] = (record[taskcommon.taskType.emTianTiChallenge] or 0) + 1
	updateTask(actor, taskcommon.taskType.emTianTiChallenge, 0, 1)
end

function onChapterLevel(actor, chapterLevel)
	local record = getRecord(actor)
	record[taskcommon.taskType.emChapterLevel] = chapterLevel
	updateTask(actor, taskcommon.taskType.emChapterLevel, 0, chapterLevel)
end

function onMagicLevel(actor, MagicLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMagicLevel] = MagicLevel
    updateTask(actor, taskcommon.taskType.emMagicLevel, 0, MagicLevel)
end

function onWarSpiritlevel(actor, WarSpiritlevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emWarSpiritlevel] = WarSpiritlevel
    updateTask(actor, taskcommon.taskType.emWarSpiritlevel, 0, WarSpiritlevel)
end

function onWarSpiritstage(actor, WarSpiritstage)
    local record = getRecord(actor)
    record[taskcommon.taskType.emWarSpiritstage] = WarSpiritstage
    updateTask(actor, taskcommon.taskType.emWarSpiritstage, 0, WarSpiritstage)
end

function onOrange(actor, equipid)
    local record = getRecord(actor)
    local conf = LegendComposeConfig[equipid]
    if not conf or not conf.level then
        return
    end
 
    --橙装类型为1,传奇类型为2
    local level = conf.level

    if conf.type == 1 then
        record[taskcommon.taskType.emOrange] = level
        updateTask(actor, taskcommon.taskType.emOrange, level, 1)
    elseif conf.type == 2 then
        record[taskcommon.taskType.emLegend] = level
        updateTask(actor, taskcommon.taskType.emLegend, level, 1)
    end
end


function onCasting(actor, onCastingcount)
    local record = getRecord(actor)
    record[taskcommon.taskType.emCasting] = (record[taskcommon.taskType.emCasting] or 0) + 1
    updateTask(actor, taskcommon.taskType.emCasting, 0, 1)
end

function onArtifact(actor, Artifactid)
    local record = getRecord(actor)
    if not record[taskcommon.taskType.emArtifact] then
        record[taskcommon.taskType.emArtifact] = {}
    end

    record[taskcommon.taskType.emArtifact][Artifactid] = 1
    updateTask(actor, taskcommon.taskType.emArtifact, Artifactid, 1)
end

function onArtifactstage(actor, Artifactstage)
    local record = getRecord(actor)
    record[taskcommon.taskType.emArtifactstage] = (record[taskcommon.taskType.emArtifactstage] or 0) + 1
    updateTask(actor, taskcommon.taskType.emArtifactstage, 0, 1)
end

function onParalysis(actor, Paralysis)
    local record = getRecord(actor)
    record[taskcommon.taskType.emParalysis] = (record[taskcommon.taskType.emParalysis] or 0) + 1
    updateTask(actor, taskcommon.taskType.emParalysis, 0, 1)
end

function onProtective(actor, Protective)
    local record = getRecord(actor)
    record[taskcommon.taskType.emProtective] = (record[taskcommon.taskType.emProtective] or 0) + 1
    updateTask(actor, taskcommon.taskType.emProtective, 0, 1)
end

function onPersonalBoss(actor, PersonalBoss)
    local record = getRecord(actor)
    record[taskcommon.taskType.emPersonalBoss] = PersonalBoss
    updateTask(actor, taskcommon.taskType.emPersonalBoss, 0, PersonalBoss)
end

function onFullBoss(actor, index)
    local record = getRecord(actor)
    if not record[taskcommon.taskType.emFullBoss] then
        record[taskcommon.taskType.emFullBoss] = {}
    end
    record[taskcommon.taskType.emFullBoss][index] = 1
    updateTask(actor, taskcommon.taskType.emFullBoss, index, 1)
	record[taskcommon.taskType.emAllFullBoss] = (record[taskcommon.taskType.emAllFullBoss] or 0) + 1
	updateTask(actor, taskcommon.taskType.emAllFullBoss, 0, 1)
end


function onTransferBoss(actor, TransferBoss)
    local record = getRecord(actor)
    record[taskcommon.taskType.emTransferBoss] = TransferBoss
    updateTask(actor, taskcommon.taskType.emTransferBoss, 0, TransferBoss)
end

function onHegemony(actor, Hegemony)
    local record = getRecord(actor)
    record[taskcommon.taskType.emHegemony] = Hegemony
    updateTask(actor, taskcommon.taskType.emHegemony, 0, Hegemony)
end

function onloongLevelCount(actor, roleId, shieldLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emLoongLevelCount] = (record[taskcommon.taskType.emLoongLevelCount] or 0) + 1

    updateTask(actor, taskcommon.taskType.emLoongLevelCount, 0, 1, roleId)
end

function onShieldLevelCount(actor, roleId, shieldLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emShieldLevelCount] = (record[taskcommon.taskType.emShieldLevelCount] or 0) + 1

    updateTask(actor, taskcommon.taskType.emShieldLevelCount, 0, 1, roleId)
end

function onXueyuLevelCount(actor, roleId, shieldLevel)
    local record = getRecord(actor)
    record[taskcommon.taskType.emXueyuLevelCount] = (record[taskcommon.taskType.emXueyuLevelCount] or 0) + 1
    updateTask(actor, taskcommon.taskType.emXueyuLevelCount, 0, 1, roleId)
end

function onGuildSkill(actor)
	local record = getRecord(actor)
	record[taskcommon.taskType.emGuildskill] = (record[taskcommon.taskType.emGuildskill] or 0) + 1
	updateTask(actor, taskcommon.taskType.emGuildskill, 0, 1)
end

function onMorship(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMorship] = (record[taskcommon.taskType.emMorship] or 0) + 1
    updateTask(actor, taskcommon.taskType.emMorship, 0, 1)
end

function onReqChapterReward(actor, idx)
	local record = getRecord(actor)
    if record[taskcommon.taskType.emReqChapterReward] == nil then
        record[taskcommon.taskType.emReqChapterReward] = {}
    end
    record[taskcommon.taskType.emReqChapterReward][idx] = (record[taskcommon.taskType.emReqChapterReward][idx] or 0)+ 1
	updateTask(actor, taskcommon.taskType.emReqChapterReward, idx, 1)
end

function onReqChapterWorldReward(actor, idx)
	local record = getRecord(actor)
    if record[taskcommon.taskType.emReqChapterWorldReward] == nil then
        record[taskcommon.taskType.emReqChapterWorldReward] = {}
    end
    record[taskcommon.taskType.emReqChapterWorldReward][idx] = (record[taskcommon.taskType.emReqChapterWorldReward][idx] or 0)+ 1
	updateTask(actor, taskcommon.taskType.emReqChapterWorldReward, idx, 1)
end

function onKillChapterMonster(actor, mid, num)
	local record = getRecord(actor)
    record[taskcommon.taskType.emKillChapterMonster] = 0
	updateTask(actor, taskcommon.taskType.emKillChapterMonster, 0, num)	
end

function onGetWroldBossBelong(actor, bossId)
	local record = getRecord(actor)
    record[taskcommon.taskType.emGetWroldBossBelong] = (record[taskcommon.taskType.emGetWroldBossBelong] or 0) + 1
	updateTask(actor, taskcommon.taskType.emGetWroldBossBelong, 0, 1)	
end

function onKnighthoodLv(actor, level)
	local record = getRecord(actor)
    record[taskcommon.taskType.emKnighthoodLv] = level
	updateTask(actor, taskcommon.taskType.emKnighthoodLv, 0, level)	
end

function onUpdateVipInfo(actor)
	local level = LActor.getVipLevel(actor)
	local record = getRecord(actor)
    record[taskcommon.taskType.emVipChangeLv] = level
	updateTask(actor, taskcommon.taskType.emVipChangeLv, 0, level)	
end

function onRecharge(actor, value)
    local record = getRecord(actor)
    record[taskcommon.taskType.emRechargeNum] = (record[taskcommon.taskType.emRechargeNum] or 0) + 1
	updateTask(actor, taskcommon.taskType.emRechargeNum, 0, 1)
end

function onXunBao(actor, type, count)
    local record = getRecord(actor)
    record[taskcommon.taskType.emXunBao] = (record[taskcommon.taskType.emXunBao] or 0) + count
	updateTask(actor, taskcommon.taskType.emXunBao, 0, count)
	if type == 1 then
		record[taskcommon.taskType.emXunBaoEquip] = (record[taskcommon.taskType.emXunBaoEquip] or 0) + count
		updateTask(actor, taskcommon.taskType.emXunBaoEquip, 0, count)
	elseif type == 2 then
		record[taskcommon.taskType.emXunBaoFuwen] = (record[taskcommon.taskType.emXunBaoFuwen] or 0) + count
		updateTask(actor, taskcommon.taskType.emXunBaoFuwen, 0, count)
    elseif type == 3 then
        record[taskcommon.taskType.emXunBaoheirloom] = (record[taskcommon.taskType.emXunBaoheirloom] or 0) + count
        updateTask(actor, taskcommon.taskType.emXunBaoheirloom, 0, count)
	end
end

function onNeiGongUp(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emNeiGongUpNum] = (record[taskcommon.taskType.emNeiGongUpNum] or 0) + 1
	updateTask(actor, taskcommon.taskType.emNeiGongUpNum, 0, 1)
end

function onActTogetherhit(actor, level)
	local record = getRecord(actor)
	record[taskcommon.taskType.emActTogetherhit] = (record[taskcommon.taskType.emActTogetherhit] or 0) + 1
	updateTask(actor, taskcommon.taskType.emActTogetherhit, 0, 1)
end

function onActImba(actor, id)
	local record = getRecord(actor)
	if record[taskcommon.taskType.emActImba] == nil then
		record[taskcommon.taskType.emActImba] = {}
	end
	
	record[taskcommon.taskType.emActImba][id] = (record[taskcommon.taskType.emActImba][id] or 0) + 1
	updateTask(actor, taskcommon.taskType.emActImba, id, 1)
end

function onActImbaItem(actor, id)
	local record = getRecord(actor)
	if record[taskcommon.taskType.emActImbaItem] == nil then
		record[taskcommon.taskType.emActImbaItem] = {}
	end
	
	record[taskcommon.taskType.emActImbaItem][id] = (record[taskcommon.taskType.emActImbaItem][id] or 0) + 1
	updateTask(actor, taskcommon.taskType.emActImbaItem, id, 1)
end

function onActAExring(actor, idx)
	local record = getRecord(actor)
	record[taskcommon.taskType.emActAExring] = (record[taskcommon.taskType.emActAExring] or 0) + 1
	updateTask(actor, taskcommon.taskType.emActAExring, 0, 1)	
end

function onOpenMonthCard(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emOpenMonthCard] = (record[taskcommon.taskType.emOpenMonthCard] or 0) + 1
    updateTask(actor, taskcommon.taskType.emOpenMonthCard, 0, 1)   
end

function onShareGame(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emShareGame] = (record[taskcommon.taskType.emShareGame] or 0) + 1
    updateTask(actor, taskcommon.taskType.emShareGame, 0, 1)   
end

function onTianTiLevel(actor, level, id)
    local record = getRecord(actor)
    local temp = level * 100 + id
    if (record[taskcommon.taskType.emTianTiLevel] or 0) < temp then
        record[taskcommon.taskType.emTianTiLevel] = temp
    end

    updateTask(actor, taskcommon.taskType.emTianTiLevel, 0, temp)   
end

function onSkirmishRank(actor, rankId)
    local record = getRecord(actor)

    record[taskcommon.taskType.emSkirmishRank] = rankId

    updateTask(actor, taskcommon.taskType.emSkirmishRank, rankId, 1)   
end

function onDayLiLian(actor, num)
    local record = getRecord(actor)

    record[taskcommon.taskType.emDayLiLian] = (record[taskcommon.taskType.emDayLiLian] or 0) + num

    updateTask(actor, taskcommon.taskType.emDayLiLian, 0, num)   
end

function onDayFuBenSweep(actor)
    local record = getRecord(actor)

    record[taskcommon.taskType.emDayFuBenSweep] = (record[taskcommon.taskType.emDayFuBenSweep] or 0) + 1

    updateTask(actor, taskcommon.taskType.emDayFuBenSweep, 0, 1)   
end

function onFinishLimitTask(actor, tag)
    local record = getRecord(actor)

    if tag then
        if record[taskcommon.taskType.emLimitTagTaskFinish] == nil then record[taskcommon.taskType.emLimitTagTaskFinish] = {} end
        record[taskcommon.taskType.emLimitTagTaskFinish][tag] = (record[taskcommon.taskType.emLimitTagTaskFinish][tag] or 0) + 1

        updateTask(actor, taskcommon.taskType.emLimitTagTaskFinish, tag, 1)
    else
        record[taskcommon.taskType.emFinishLimitTask] = (record[taskcommon.taskType.emFinishLimitTask] or 0) + 1

        updateTask(actor, taskcommon.taskType.emFinishLimitTask, 0, 1)
    end
end

function onGetItem(actor, type, item_id)
    local record = getRecord(actor)

    if record[taskcommon.taskType.emGetTypeItem] == nil then record[taskcommon.taskType.emGetTypeItem] = {} end
	record[taskcommon.taskType.emGetTypeItem][type] = (record[taskcommon.taskType.emGetTypeItem][type] or 0) + 1

    updateTask(actor, taskcommon.taskType.emGetTypeItem, type, 1)   	
end

function onCaiKuang(actor, kuangId)
    local record = getRecord(actor)
    --任意矿
	record[taskcommon.taskType.emCaiKuang] = (record[taskcommon.taskType.emCaiKuang]or 0) + 1
    updateTask(actor, taskcommon.taskType.emCaiKuang, 0, 1) 
    --指定类型矿
    if record[taskcommon.taskType.emCaiKuangId] == nil then record[taskcommon.taskType.emCaiKuangId] = {} end
    updateTask(actor, taskcommon.taskType.emCaiKuangId, kuangId, 1) 
end

function onHolyBoss(actor, id)
    local record = getRecord(actor)
    record[taskcommon.taskType.emHolyBoss] = (record[taskcommon.taskType.emHolyBoss] or 0) + 1
    updateTask(actor, taskcommon.taskType.emHolyBoss, 0, 1)
end

function onMiJingBoss(actor, id)
    local record = getRecord(actor)
    record[taskcommon.taskType.emMiJingBoss] = (record[taskcommon.taskType.emMiJingBoss] or 0) + 1
    updateTask(actor, taskcommon.taskType.emMiJingBoss, 0, 1)
end

function onLoginDay(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emLoginDay] = (record[taskcommon.taskType.emLoginDay] or 0) + 1
    updateTask(actor, taskcommon.taskType.emLoginDay, 0, 1)
end

function onNewWorldBoss(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emNewWroldBoss] = (record[taskcommon.taskType.emNewWroldBoss] or 0) + 1
    updateTask(actor, taskcommon.taskType.emNewWroldBoss, 0, 1)
end

function onCampBattleFb(actor)
    local record = getRecord(actor)
    record[taskcommon.taskType.emCampBattleFb] = (record[taskcommon.taskType.emCampBattleFb] or 0) + 1
    updateTask(actor, taskcommon.taskType.emCampBattleFb, 0, 1)
end

actorevent.reg(aeLevel, onLevelUp)
actorevent.reg(aeUpgradeSkillCount, onUpgradeSkillCount)
actorevent.reg(aeSkillLevelup, onUpgradeSkillLevel)
actorevent.reg(aeStrongLevelChanged, onEnhanceEquip)
actorevent.reg(aeStrongLevelChanged, onEquipLevel)
actorevent.reg(aeWingTrain, onWingTrainCount)
actorevent.reg(aeWingLevelUp, onWingLevelUp)
actorevent.reg(aeWingStarUp, onWingStarUp)
actorevent.reg(aeSmeltEquip, onSmeltEquip)
actorevent.reg(aeFightPower, onFightPower)
actorevent.reg(aeSkirmish, onSkirmish)
actorevent.reg(aeUpgradeJingmai, onJingmaiLevelup)
actorevent.reg(aeUpgradeStone, onStoneLevelup)
actorevent.reg(aeUpgradeZhuling, onZhulingLevelup)
actorevent.reg(aeUpgradeTupo, onTupoLevelup)
actorevent.reg(aeStoreCost, onStoreCost)
actorevent.reg(aeEnterFuben, onEnterFuben)
actorevent.reg(aeFieldBoss, onKillFeildBoss)
actorevent.reg(aeOpenRole, onOpenRole)
actorevent.reg(aeZhuansheng, onZhuansheng)
actorevent.reg(aeUpgradeLoongSoul, onUpgradeLoongSoul)
actorevent.reg(aeUpgradeShield, onUpgradeShield)
actorevent.reg(aeAddEquiment, onEquipItem)
actorevent.reg(aeFinishFuben, onFinishFuben)
actorevent.reg(aeLearnMiJi, onLearnMiJi)
actorevent.reg(aeGuildDonate, onGuildDonate)
actorevent.reg(aeTianTiChallenge, onTianTiChallenge)
actorevent.reg(aeChapterLevelFinish, onChapterLevel)
actorevent.reg(aeMagicLevel, onMagicLevel)
actorevent.reg(aeWarSpiritlevel, onWarSpiritlevel)
actorevent.reg(aeWarSpiritstage, onWarSpiritstage)
actorevent.reg(aeOrange, onOrange)
actorevent.reg(aeCasting, onCasting)
actorevent.reg(aeArtifact, onArtifact)
actorevent.reg(aeArtifactstage, onArtifactstage)
actorevent.reg(aeParalysis, onParalysis)
actorevent.reg(aeProtective, onProtective)
actorevent.reg(aePersonalBoss, onPersonalBoss)
actorevent.reg(aeFullBoss, onFullBoss)
actorevent.reg(aeTransferBoss, onTransferBoss)
actorevent.reg(aeHegemony, onHegemony)
actorevent.reg(aeloongLevelCount, onloongLevelCount)
actorevent.reg(aeShieldLevelCount, onShieldLevelCount)
actorevent.reg(aeXueyuLevelCount, onXueyuLevelCount)
actorevent.reg(aeGuildSkill, onGuildSkill)
actorevent.reg(aeMorship, onMorship)
actorevent.reg(aeGetTreasureBoxType, onGetTreasureBoxType)
actorevent.reg(aeChallengeFb, onChallengeFb)
actorevent.reg(aeTuJian, onTuJian)
actorevent.reg(aeFuWenLevel, onFuWenLevel)
actorevent.reg(aeTreasureBoxReward, onTreasureBoxReward)
actorevent.reg(aeReqChapterReward, onReqChapterReward)
actorevent.reg(aeReqChapterWorldReward, onReqChapterWorldReward)
actorevent.reg(aeKillChapterMonster, onKillChapterMonster)
actorevent.reg(aeGetWroldBossBelong, onGetWroldBossBelong)
actorevent.reg(aeKnighthoodLv, onKnighthoodLv)
actorevent.reg(aeUpdateVipInfo, onUpdateVipInfo)
actorevent.reg(aeRecharge, onRecharge)
actorevent.reg(aeXunBao, onXunBao)
actorevent.reg(aeNeiGongUp, onNeiGongUp)
actorevent.reg(aeActTogetherhit, onActTogetherhit)
actorevent.reg(aeActImba, onActImba)
actorevent.reg(aeActAExring, onActAExring)
actorevent.reg(aeOpenMonthCard, onOpenMonthCard)
actorevent.reg(aeShareGame, onShareGame)
actorevent.reg(aeTianTiLevel, onTianTiLevel)
actorevent.reg(aeSkirmishRank, onSkirmishRank)
actorevent.reg(aeDayLiLian, onDayLiLian)
actorevent.reg(aeDayFuBenSweep, onDayFuBenSweep)
actorevent.reg(aeFinishLimitTask, onFinishLimitTask)
actorevent.reg(aeGetItem, onGetItem)
actorevent.reg(aeActImbaItem, onActImbaItem)
actorevent.reg(aeCaiKuang, onCaiKuang)
actorevent.reg(aeHolyBoss, onHolyBoss)
actorevent.reg(aeNewWorldBoss, onNewWorldBoss)
actorevent.reg(aeCampBattleFb, onCampBattleFb)
actorevent.reg(aeMiJingBoss, onMiJingBoss)
actorevent.reg(aeNewDayArrive, onLoginDay)
actorevent.reg(aeLoseFuben, onLoseFuben)
actorevent.reg(aeJoinActivityId, onJoinActivity)
actorevent.reg(aeConsumeYuanbao, onConsumeYuanbao)
actorevent.reg(aeConsumeGold, onConsumeGold)
actorevent.reg(aeRichManCircle, onRichManCircle)
actorevent.reg(aeExpFubenAwardType, onExpFubenAwardType)
actorevent.reg(aeRecharge, onRechargeGold)