module("taskcommon", package.seeall)

eCoverType = 1 		--覆盖类型的任务目标
eAddType = 2 		--累加类型的任务目标

statusType = {
	emDoing = 0,
	emCanAward = 1,
	emHaveAward = 2,
}

Param = {
	emOrdinary = 1,
	emFuben = 2,
	emChenZhuan = 3,
	emParamEGt = 4,
}

taskType = {
	emSkillLevelup 		= 1,	--技能升级次数 +
	emEnhanceEquip 		= 2,	--装备强化次数 +
	emWingTrainCount	= 3,	--翅膀强化次数 +
	emSmeltEquip 		= 4,	--熔炼装备次数 +
	emSkirmish 			= 5,	--遭遇战次数 +
	emSkillLevel 		= 6,	--任意技能等级 c
	emEquipLevel 		= 7,	--任意装备(强化)等级 c
	emActorLevel 		= 8,	--角色等级 c
	emFightPower 		= 9,	--角色战斗力 c
	emPassDup 			= 10,	--进入指定副本 +
	emPassTypeDup 		= 11,	--进入指定类型副本 +
	emWingLevelUpCount 	= 12,	--翅膀升级次数 +
	emJingmaiStage 		= 13, 	--经脉等级 c
	emStoneLevel 		= 14, 	--宝石等级 c
	emZhulingLevel 		= 15,	--注灵(铸造)单部位最高等级 c
	emTupoLevel 		= 16, 	--突破等级 c
	emUseYBInStore 		= 17,	--在商店消耗多少元宝 +
	emRoleCount 		= 18, 	--角色数量 c
	emZhuanshengCount 	= 19,	--转生次数 c
	emEquipCount 		= 20, 	--装备穿戴次数 +
	emUpgradeStoneCount	= 21,	--提升精炼次数 +
	emUpgradeJingmaiCount = 22,	--提升经脉次数 +
	emUpgradeLoongCount	= 23,	--提升龙魂(宝物)总等级 +
	emUpgradeShieldCount= 24,	--提升护盾次数 +
	emfieldBossCount 	= 25,	--击杀野外BOSS次数 +
    emFinishDup         = 26,   --通关指定副本 +
    emFinishTypeDup     = 27,   --通关指定类型副本 +
    emWingMaxLevel      = 28,   --翅膀最高等级 c
    emWingStarUpCount   = 29,   --翅膀升星 + --翅膀没有星级,废弃
	emLearnMiJiCount    = 30,   --学习秘籍的次数+
    emGuildDonateYb		= 31,	--公会捐献元宝 +
    emGuildDonateGold	= 32,	--公会捐献金币 +
    emGuildDonateItem	= 33,	--公会捐献道具 +
    --emEquipZhuling 		= 34, 	--装备注灵(精练)总等级,和55重复 +
	emTianTiChallenge 	= 35, 	--天梯挑战 +
	emChapterLevel   	= 36, 	--关卡数 c
	emMagicLevel		= 37,   --神功等级->历练(爵位)等级 c
	emWarSpiritlevel	= 38,   --战灵等级
	emWarSpiritstage    = 39,   --战灵阶级
	emOrange			= 40,   --橙装数量 c
	emLegend			= 41,   --传奇数量 c
	emCasting			= 42,   --装备铸魂
	emArtifact    		= 43,   --装备神器
	emArtifactstage		= 44,   --神器阶级
	emParalysis         = 45,   --麻痹戒子升级
	emProtective		= 46,   --护身戒子升级
	emPersonalBoss		= 47,   --击杀个人BOSS
	emFullBoss 			= 48,   --击杀全民BOSS
	emTransferBoss		= 49,   --击杀转职BOSS
	emHegemony 			= 50, 	--王者争霸次数(竞技)
	emLoongLevelCount	= 51,	--龙魂(宝物)点了升级按钮多少次 +
	emShieldLevelCount	= 52,	--护盾总等级
	emXueyuLevelCount	= 53,   --血玉总等级
	emStonetotalLevel   = 54,	--宝石总等级
	emZhulingtotalLevel = 55,   --3角色注灵(铸造)总等级
	emJingMaitotalLevel = 56,   --经脉总等级
	emWingtotalStar		= 57,	--翅膀总星级
	emGuildskill		= 58,	--修炼工会技能
	emAllFullBoss		= 59,   --击杀(有伤害排名奖励)全民BOSS +次数(任意boss, 与48不同)
	emMorship			= 60,   --膜拜
	emGetTreasureBoxType= 61,	--获取指定类型宝箱
	emChallengeFb 		= 62,	--闯天关
	emTuJian	 		= 63,	--图鉴
	emFuWenLevel		= 64,	--战纹等级
	emTreasureBoxReward	= 65,	--领取宝箱奖励次数
	emReqChapterReward	= 66,	--领取指定章节奖励的任务 +
	emReqChapterWorldReward = 67,--领取指定世界奖励的任务 +
	emKillChapterMonster = 68, --指定关卡杀怪数量 +
	emVipChangeLv 		= 69, --vip等级 c
	emKnighthoodLv		= 70, --勋章等级 c
	emRechargeNum		= 71, --充值次数 +
	emGetWroldBossBelong= 72, --世界boss归属次数 +
	emEquipLvCount		= 73, --穿戴指定等级装备个数 c
	emXunBao			= 74, --寻宝指定次数 +
	emNeiGongUpNum		= 75, --内功升级升阶次数 +
	emActTogetherhit	= 76, --激活(升级)合击技能 +
	emActImba			= 77, --激活神器 +
	emActAExring		= 78, --激活任意玩家特戒 +
	emEnterChapterLv	= 79, --进入指定关卡 c
	emEquipSlotCount 	= 80, --指定部位装备穿戴次数 +
	emOpenMonthCard 	= 81, --开通月卡 +
	emShareGame 	 	= 82, --分享一次 +
	emTianTiLevel 	 	= 83, --王者争霸达到指定段位 c
	emSkirmishRank 	 	= 84, --达到遭遇战排名 c
	emEquipOrangeCount 	= 85, --穿戴指定等级橙装装备个数 c
	emDayLiLian 		= 86, --当天达到多少历练 +
	emDayFuBenSweep		= 87, --副本扫荡次数 +
	emFinishLimitTask	= 88, --完成限时任务 +
	emGetTypeItem		= 89, --获取指定类型的道具 +
	emActImbaItem		= 90, --激活神器碎片 +
	emXunBaoEquip		= 91, --装备寻宝 +
	emXunBaoFuwen		= 92, --符文寻宝 +
	emCaiKuang			= 93, --采矿次数 +
	emCaiKuangId		= 94, --采矿指定矿的次数 +
	emHolyBoss			= 95, --参与神域BOSS次数 +
	emNewWroldBoss		= 96, --参与世界boss次数 +
	emCampBattleFb		= 97, --参与阵营战次数 +
	emMiJingBoss		= 98, --参与秘境boss次数 +
	emLimitTagTaskFinish = 99, --完成指定标识的限时任务 +
	emLoginDay			= 100, --登陆天数 +
	emOverTypeDup		= 101, --参与完成指定类型副本(输赢都算) +
	emJoinActivityId    = 102, --参与指定类型活动 +
	emConsumeYuanbao    = 103, --消耗元宝 +
	emConsumeGold       = 104, --消耗金币 +
	emRichManCircle     = 105, --大富翁圈数 +
	emExpFubenAwardType = 106, --经验副本奖励类型 +
	emRechargeGold		= 107, --充值金额 +
	emXunBaoheirloom	= 108, --传世装备寻宝 +
}

taskTypeHandleType = {
	[taskType.emSkillLevelup] = eAddType,
	[taskType.emEnhanceEquip] = eAddType,
	[taskType.emWingTrainCount] = eAddType,
	[taskType.emSmeltEquip] = eAddType,
	[taskType.emSkirmish] = eAddType,
	[taskType.emSkillLevel] = eCoverType,
	[taskType.emEquipLevel] = eCoverType,
	[taskType.emActorLevel] = eCoverType,
	[taskType.emFightPower] = eCoverType,
	[taskType.emPassDup] = eAddType,
	[taskType.emPassTypeDup] = eAddType,
	[taskType.emWingLevelUpCount] = eAddType,
	[taskType.emJingmaiStage] = eAddType,
	[taskType.emStoneLevel] = eCoverType,
	[taskType.emZhulingLevel] = eCoverType,
	[taskType.emTupoLevel] = eCoverType,
	[taskType.emUseYBInStore] = eAddType,
	[taskType.emRoleCount] = eCoverType,
	[taskType.emZhuanshengCount] = eCoverType,
	[taskType.emEquipCount] = eAddType,
	[taskType.emUpgradeStoneCount] = eAddType,
	[taskType.emUpgradeJingmaiCount] = eAddType,
	[taskType.emUpgradeLoongCount] = eAddType,
	[taskType.emUpgradeShieldCount] = eAddType,
	[taskType.emfieldBossCount] = eAddType,
    [taskType.emFinishDup] = eAddType,
    [taskType.emFinishTypeDup] = eAddType,
    [taskType.emWingMaxLevel] = eCoverType,
    [taskType.emWingStarUpCount] = eAddType,
	[taskType.emLearnMiJiCount] = eAddType,
    [taskType.emGuildDonateYb] = eAddType,
    [taskType.emGuildDonateGold] = eAddType,
    [taskType.emGuildDonateItem] = eAddType,
    --[taskType.emEquipZhuling] = eAddType,
	[taskType.emTianTiChallenge] = eAddType,
	[taskType.emChapterLevel] = eCoverType,
	[taskType.emMagicLevel] = eCoverType,
	[taskType.emWarSpiritlevel] = eCoverType,
	[taskType.emWarSpiritstage] = eCoverType,
	[taskType.emOrange] = eCoverType,
	[taskType.emLegend] = eCoverType,
	[taskType.emCasting] = eAddType,
	[taskType.emArtifact] = eCoverType,
	[taskType.emArtifactstage] = eAddType,
	[taskType.emParalysis] = eAddType,
	[taskType.emProtective] = eAddType,
	[taskType.emPersonalBoss] = eAddType,
	[taskType.emFullBoss] = eAddType,
	[taskType.emTransferBoss] = eCoverType,
	[taskType.emHegemony] = eAddType,
	[taskType.emLoongLevelCount] = eAddType,
	[taskType.emShieldLevelCount] = eAddType,
	[taskType.emXueyuLevelCount] = eAddType,
	[taskType.emStonetotalLevel] = eAddType,
	[taskType.emJingMaitotalLevel] = eAddType,
	[taskType.emZhulingtotalLevel] = eAddType,
	[taskType.emWingtotalStar] = eAddType,
	[taskType.emGuildskill]		= eAddType,
	[taskType.emAllFullBoss]		= eAddType,
	[taskType.emMorship]		= eAddType,
	[taskType.emGetTreasureBoxType] =  eAddType,
	[taskType.emChallengeFb] =  eAddType,
	[taskType.emTuJian] =  eAddType,
	[taskType.emFuWenLevel] =  eCoverType,
	[taskType.emTreasureBoxReward] =  eAddType,
	[taskType.emReqChapterReward] = eAddType,
	[taskType.emReqChapterWorldReward] = eAddType,
	[taskType.emKillChapterMonster] = eAddType,
	[taskType.emVipChangeLv] = eCoverType,
	[taskType.emKnighthoodLv] = eCoverType,
	[taskType.emRechargeNum] = eAddType,
	[taskType.emGetWroldBossBelong] = eAddType,
	[taskType.emEquipLvCount] = eCoverType,
	[taskType.emXunBao] = eAddType,
	[taskType.emNeiGongUpNum] = eAddType,
	[taskType.emActTogetherhit] = eAddType,
	[taskType.emActImba] = eAddType,
	[taskType.emActAExring] = eAddType,
	[taskType.emEnterChapterLv] = eCoverType,
	[taskType.emEquipSlotCount] = eAddType,
	[taskType.emOpenMonthCard] = eAddType,
	[taskType.emShareGame] = eAddType,
	[taskType.emTianTiLevel] = eCoverType,
	[taskType.emSkirmishRank] = eCoverType,
	[taskType.emEquipOrangeCount] = eCoverType,
	[taskType.emDayLiLian] = eAddType,
	[taskType.emDayFuBenSweep] = eAddType,
	[taskType.emFinishLimitTask] = eAddType,
	[taskType.emGetTypeItem] = eAddType,
	[taskType.emActImbaItem] = eAddType,
	[taskType.emXunBaoEquip] = eAddType,
	[taskType.emXunBaoFuwen] = eAddType,
	[taskType.emCaiKuang] = eAddType,
	[taskType.emCaiKuangId] = eAddType,
	[taskType.emHolyBoss] = eAddType,
	[taskType.emNewWroldBoss] = eAddType,
	[taskType.emCampBattleFb] = eAddType,
	[taskType.emMiJingBoss] = eAddType,
	[taskType.emLimitTagTaskFinish] = eAddType,
	[taskType.emLoginDay] = eAddType,
	[taskType.emOverTypeDup] = eAddType,
	[taskType.emJoinActivityId] = eAddType,
	[taskType.emConsumeYuanbao] = eAddType,
	[taskType.emConsumeGold] = eAddType,
	[taskType.emRichManCircle] = eAddType,
	[taskType.emExpFubenAwardType] = eAddType,
	[taskType.emRechargeGold] = eAddType,
	[taskType.emXunBaoheirloom] = eAddType,
}

ParamJudgeEGt = 1 --大于等于
ParamJudgeELt = 2 --小于等于
taskTypeParamJudge = {
	[taskType.emOrange] = ParamJudgeEGt,
	[taskType.emLegend] = ParamJudgeEGt,
	[taskType.emEquipLvCount] = ParamJudgeEGt,
	[taskType.emEquipOrangeCount] = ParamJudgeEGt,
	[taskType.emSkirmishRank] = ParamJudgeELt,
}

function checkParam(taskType, param, cparam)
	local judge = taskTypeParamJudge[taskType]
	if not judge then --默认等于
		return param == cparam
	elseif judge == ParamJudgeEGt then
		return param >= cparam
	elseif judge == ParamJudgeELt then
		return param <= cparam
	end
	return false
end

taskEventType = {
	emFieldBoss = 1,
}

local tAchieveTask = {}
local tTypeTaskList = {}
for _,tb in pairs(AchievementTaskConfig) do
	local achieveId = tb.achievementId
	tAchieveTask[achieveId] = tAchieveTask[achieveId] or {}
	tAchieveTask[achieveId][tb.taskId] = tb

	tTypeTaskList[tb.type] = tTypeTaskList[tb.type] or {}
	table.insert(tTypeTaskList[tb.type], tb)
end

function getTaskListByType(type)
	return tTypeTaskList[type]
end


function getDailyTaskConfig(dailyId)
	return DailyConfig[dailyId]
end

function getAchieveConfig()
	return tAchieveTask
end

function getAchieveCount()
	local count = 0
	for _,_ in pairs(tAchieveTask) do
		count  = count + 1
	end
	return count
end

function getActiveAwardConfig(activeId)
	return DailyAwardConfig[activeId]
end

function getHandleType(taskType)
	return taskTypeHandleType[taskType]
end
