--#pragma once



--#define CMD_MAX_COUNT 256
--#define SUBCMD_MAX_COUNT 256

Protocol = {
	-- SystemCMD  
	CMD_Base = 0,	-- baseproto
	CMD_Fuben = 1,
	CMD_Skill = 2,
	CMD_Bag = 3,
	CMD_Equip = 4,
	CMD_Skirmish = 5,	-- 遭遇战
	CMD_Wing = 6,	-- 翅膀
	CMD_Enhance = 7,	-- 强化系统  各种属性系统
	CMD_Mail = 8,	-- 邮件系统
	CMD_Task = 9,	-- 任务系统
	CMD_Boss = 10,	-- Boss系统
	CMD_Stone = 11,	-- 宝石系统
	CMD_Jingmai = 12,	-- 经脉系统
	CMD_ZhuanSheng = 13,-- 转生系统
	CMD_Zhuling = 14,	-- 注灵系统
	CMD_Tupo = 15,	-- 突破系统
	CMD_Store = 16,	-- 商店系统
	CMD_ExRing = 17,	-- 特戒系统
	CMD_Ranking = 18,	-- 排行榜系统
	CMD_Vip = 19,	-- vip系统
	CMD_Notice = 20,	-- 公告系统
	CMD_SoulShield = 21,-- 龙魂护盾系统
	CMD_TreasureHunt = 22, --探宝
	CMD_Train = 23,	-- 历练系统
	CMD_ChallengeFb = 24,--挑战副本
	CMD_Activity = 25,	-- 活动系统
	CMD_Artifacts = 26, -- 神器系统
	CMD_Recharge = 27,  -- 充值相关
	CMD_Refinesystem = 28, --练制系统
	CMD_Gift = 29,	-- 礼包相关
	CMD_Chat = 30,	-- 聊天
	CMD_EquipPoint = 31, --装备点
	CMD_OtherBoss = 32,	-- 其他boss
	CMD_PlatformActivity = 33, -- 平台活动
	CMD_MiJi = 35, -- 秘籍
	CMD_Tianti = 34, -- 天梯
	CMD_CashCow = 36, -- 摇钱树
	CMD_Guild = 37, -- 公会
	CMD_Title = 38, -- 称号
	CMD_Guildfb = 39, --公会副本
	CMD_GuildBattle = 40, --公会战
	CMD_GuildRobber = 41, --公会强盗
	CMD_GuildStore = 42, --公会商店
	CMD_ZhanLing = 43,  --战灵系统
	CMD_ZhuangBan = 44,  --装扮系统
	CMD_Platform = 45,   --平台(黄钻特权)
	CMD_GuildBoss = 46,  --公会boss
	CMD_Friend = 47,   --好友系统
	CMD_Kuang = 49,    --采矿系统
	CMD_FuWen = 50,  --符文系统
	CMD_NeiGong = 51,  --内功系统
	CMD_TreasureBox = 52,  --宝箱系统
	CMD_TuJian = 53,  --图鉴系统
	CMD_DailySign = 54,  --签到系统
	CMD_Heirloom = 55,	--传世装备
	CMD_WeaponSoul = 56,--兵魂系统
	CMD_RichMan = 57,--大富翁(藏宝阁大冒险)
	CMD_City = 58,--主城系统
	CMD_RoleActivate = 59,--开服激活角色奖励
	CMD_GodWeapon = 60,	--神兵
	CMD_CampBattle = 61,	--阵营战
	CMD_PassionPoint = 62,	--激情泡点
	CMD_HolyCompose = 63,	--圣物合成
	CMD_Reincarnate = 64,	--轮回
	CMD_WuJi = 65,--无极战场
	CMD_Prestige = 66,	--威望系统
	CMD_PeakRace = 67, --巅峰赛季
	CMD_PActivity = 68,	-- 个人活动系统
	CMD_HeartMethod = 69,  --心法系统
	CMD_JadePlate = 70,  --新玉佩系统
	CMD_FlameStamp = 71, --烈焰印记
	CMD_CrossBoss = 72, --跨服boss
	CMD_ShenShou = 73, --神兽系统
	CMD_HunGu = 74, --魂骨系统
	CMD_DevilBoss = 75, --魔界侵入
	CMD_Auction = 76, --拍卖系统
	CMD_Cross3Vs3 = 77,	--跨服3v3

	CMD_Login = 255,


	 --最大255

	--[[------------------------子协议定义---------------------------]]
	-- BaseCmd   -- CMD_Base
	sBaseCmd_ActorBaseData = 1,
	sBaseCmd_RoleData = 2,
	sBaseCmd_EnterScene = 3,
	sBaseCmd_OtherEntity = 4,
	sBaseCmd_UpdateMoney = 5,
	sBaseCmd_GetItem = 6,
	sBaseCmd_UpdateExp = 7,
	sBaseCmd_UpdateRoleAttribute = 8,
	sBaseCmd_UpdateHp = 9,
	sBaseCmd_EntityDisapear = 10,
	sBaseCmd_EntityMove = 11,
	sBaseCmd_EntityStop = 12,
	sBaseCmd_EntitySpecialMove = 13,
	sBaseCmd_SyncTime = 14,
	sBaseCmd_UpdateMp = 15,
	sBaseCmd_ResActorInfo = 16,
	sBaseCmd_ServerTips = 17,
	sBaseCmd_FirstLogin = 18,
	sBaseCmd_ClientConfig = 19,
	sBaseCmd_ActorDie = 20,
	sBaseCmd_GuildInfo = 21,
	sBaseCmd_ChangeName = 22,

	sBaseCmd_ServerOpenDay = 23,
	sBaseCmd_UpdateAttr = 24,
	sBaseCmd_BubbleText = 25,
	sBaseCmd_UpdateNp = 26,
	sBaseCmd_UpdateRoleExAttribute = 27,
	sBaseCmd_GetFubenMoveLine = 31,
	sBaseCmd_NotifyFlyHp = 32,
	sBaseCmd_SwitchTarget = 33,
	sBaseCmd_SendMonsterCfg = 34,
	sBaseCmd_NewDay = 35,
	sBaseCmd_SwitchCamp = 36,
	sBaseCmd_FloatText = 37,

	cBaseCmd_GmCmd = 0,
	cBaseCmd_CreateRole = 2,
	cBaseCmd_ReqTime = 14,
	cBaseCmd_GetActorInfo = 16,
	cBaseCmd_ClientConfig = 19,
	cBaseCmd_ChangeName = 22,
	cBaseCmd_SwitchTarget = 25,
	cBaseCmd_GetFubenMoveLine = 31,
	cBaseCmd_StopAi = 33,
	cBaseCmd_SetSendPackList = 34,

	cBaseCmd_HeartBeat = 255,
	

	-- FubenCmd   -- CMD_Fuben,
	sFubenCmd_InitChapter = 1,
	sFubenCmd_SendHaveReward = 2,
	sFubenCmd_FubenResult = 3,
	sFubenCmd_ActorDie = 4,

	sFubenCmd_UpdateChapterRewardInfo = 5,
	sFubenCmd_UpdateWorldRewardInfo = 6,

	sFubenCmd_DailyFbInitData = 10,	-- 每日副本初始化数据
	sFubenCmd_DailyFbUpdateData = 11, -- 每日副本更新数据
	sFubenCmd_OfflineRewardRecord = 12, -- 离线奖励记录
	sFubenCmd_LeftTime = 13, -- 剩余时间
	sFubenCmd_OtherBossfb2Count = 14,
	sFubenCmd_OtherBossfb2Result = 15,
	sFubenCmd_SendExpFbInfo = 16,
	sFubenCmd_SendMonsterCount = 17,
	sFubenCmd_updateRebornTime = 18,
	sFubenCmd_SendActorExRingFbInfo = 21,

	sFubenCmd_GGWEnterFuben = 24,
	sFubenCmd_GGWSysInfo = 25,
	sFubenCmd_GGWUseSkillRes = 27,
	sFubenCmd_GGWUpdateFBInfo = 28,
	sFubenCmd_GGWBossAward = 29,

	sFubenCmd_CreateTeamRoom = 30,
	sFubenCmd_EnterTeamRoom = 31,
	sFubenCmd_ExitTeamRoom = 32,
	sFubenCmd_TeamRoomInfo = 33,
	sFubenCmd_TeamFbInfo = 34,
	sFubenCmd_TeamFuBenResult = 35,
	sFubenCmd_TeamFuBenRebornTime = 36,
	sFubenCmd_TeamFuBenPassRank = 37,
	sFubenCmd_TeamFuBenFlowers = 38,
	sFubenCmd_TeamFuBenInvite = 39,
	sFubenCmd_GGWSendRecord = 40,

	cFubenCmd_ReqGetReward = 1,
	cFubenCmd_ChallengeBoss = 2,
	cFubenCmd_GetBossReward = 3,
	cFubenCmd_QuitFuben = 4,	-- 通用退出

	cFubenCmd_ReqChapterReward = 5,
	cFubenCmd_ReqWorldReward = 6,

	cFubenCmd_DailyFbChallenge = 10,	-- 每日副本挑战请求
	cFubenCmd_DailyFbBuyCount = 11,	-- 每日副本购买次数
	cFubenCmd_OtherBoss2Challenge = 12,
	cFubenCmd_KillChapterMonster = 13,--客户端杀了一只怪
	cFubenCmd_ExpFbChallenge = 14,
	cFubenCmd_ExpFbRaid = 15,
	cFubenCmd_ExpFbReceive = 16,
	cFubenCmd_EnterLeadFuben = 18,
	cFubenCmd_AttackLeadRobot = 19,
	cFubenCmd_BuyReborn = 20,
	cFubenCmd_ActorExRingFbChallenge = 22,
	cFubenCmd_ActorExRingFbReceive = 23,


	cFubenCmd_GGWEnterFuben = 24,
	cFubenCmd_GGWSummonBoss = 26,
	cFubenCmd_GGWUseSkill = 27,
	cFubenCmd_GGWBossAward = 29,
	cFubenCmd_CreateTeamRoom = 30,
	cFubenCmd_EnterTeamRoom = 31,
	cFubenCmd_ExitTeamRoom = 32,
	cFubenCmd_StartTeamRoom = 33,
	cFubenCmd_TeamRoomTickActor = 34,
	cFubenCmd_TeamFuBenContinue = 35,
	cFubenCmd_TeamFuBenPassRank = 36,
	cFubenCmd_TeamFuBenSendFlowers = 37,
	cFubenCmd_TeamFuBenInvite = 38,
	cFubenCmd_GGWSendRecord = 40,

	cFubenCmd_ActorExRingFbRaids = 41,
	cFubenCmd_GGWSweep = 42,
	

	-- SkillCmd  
	sSkillCmd_CastSkill = 1,
	sSkillCmd_AppendSkillEffect = 2,
	sSkillCmd_RemoveSkillEffect = 3,
	sSkillCmd_UpdateSkill = 4,
	sSkillCmd_UpdateSkillALL = 5,
	sSkillCmd_AddEffect = 6,
	sSkillCmd_DelEffect = 7,
	sSkillCmd_UpgradeSkillBreak = 8,
	sSkillCmd_TogetherHitLv = 9,
	sSkillCmd_TogetherHitEquip = 10,
	sSkillCmd_TogetherHitEquipItem = 11,
	sSkillCmd_TogetherHitLvUpCond = 12,
	sSkillCmd_TogetherHitPuncheInfo = 13,

	cSkillCmd_CastSkill = 1,
	cSkillCmd_UpgradeSkill = 4,
	cSkillCmd_UpgradeSkillALL = 5,
	cSkillCmd_UpgradeSkillBreak = 8,
	cSkillCmd_TogetherHitActUplv = 9,
	cSkillCmd_UseTogetherHit = 10,
	cSkillCmd_TogetherHitEquipItem = 11,
	cSkillCmd_TogetherHitEquipExchange = 12,
	cSkillCmd_TogetherHitPuncheLvup = 13,
	cSkillCmd_TogeatterExchange = 14,
	

	-- BagCmd  
	sBagCmd_InitData = 1,
	sBagCmd_UpdateCapacity = 2,
	sBagCmd_DeleteItem = 3,
	sBagCmd_AddItem = 4,
	sBagCmd_UpdateItem = 5,


	cBagCmd_ReqExpandCapacity = 2,
	cBagCmd_DecomposeEquip = 3,
	cBagCmd_DepotPickUp = 4,

	sBagCmd_UseItem = 6,
	cBagCmd_UseItem = 6,

	sBagCmd_ComposeItem = 7,
	cBagCmd_ComposeItem = 7,

	sBagCmd_UseOptionalGift = 8,
	cBagCmd_UseOptionalGift = 8,
	

	-- EquipCmd  
	sEquipCmd_EquipItem = 1,
	sEquipCmd_EquipSmelt = 2,
	sEquipCmd_Levelup = 3,
	sEquipCmd_Compose = 4,
	sEquipCmd_ReqFulingSmelt = 5,
	sEquipCmd_ReqTakeOutEquip = 6,
	sEquipCmd_ReqSoulEquip = 7,
	sEquipCmd_ReqZhiZunLevelUp = 8,

	cEquipCmd_ReqEquipItem = 1,
	cEquipCmd_ReqEquipSmelt = 2,
	cEquipCmd_ReqLevelup = 3,
	cEquipCmd_ReqCompose = 4,
	cEquipCmd_ReqFulingSmelt = 5,
	cEquipCmd_ReqTakeOutEquip = 6,
	cEquipCmd_ReqSoulEquip = 7,
	cEquipCmd_ReqZhiZunLevelUp = 8,
	

	-- SkirmishCmd  
	-- 野外玩家遭遇战
	sSkirmishCmd_InitData = 1,
	sSkirmishCmd_UpdateActorData = 2,
	sSkirmishCmd_AffirmResult = 3,
	sSkirmishCmd_ResRecord = 4,
	sSkirmishCmd_ResFame = 7,
	sSkirmishCmd_ResClearPkval = 10,

	cSkirmishCmd_ReqRefresh = 1,
	cSkirmishCmd_ReportResult = 2,
	cSkirmishCmd_ReqDrop = 3,
	cSkirmishCmd_ReqRecord = 4,
	cSkirmishCmd_ReqFame = 7,
	cSkirmishCmd_ReqClearPkval = 8,


	-- 野外boss
	sFieldBossCmd_UpdateBoss = 5,
	sFieldBossCmd_AffirmResult = 6,

	cFieldBossCmd_ReportResult = 5,
	cFieldBossCmd_ReqReward = 6,

	--野外玩家
	sFiledPlayerCmd_UpdateActorData = 8,
	sFieldPlayerCmd_ResultDrop = 9,

	cFieldPlayerCmd_ReportResult = 9,
	cFieldPlayerCmd_PlayerOutside = 10,
	cFieldPlayerCmd_ReqDrop = 11,

	

	-- WingCmd  
	sWingCmd_InitData = 1,
	sWingCmd_ReqTrain = 2,
	sWingCmd_ReqOpen = 4,
	sWingCmd_EquipItem = 11,
	sWingCmd_GodWingData = 5,
	sWingCmd_GodWingEquip = 3,
	sWingCmd_RepUsePill = 8,

	cWingCmd_Train = 2,
	cWingCmd_Open = 4,
	cWingCmd_ReqEquipItem = 11,
	cWingCmd_UseItemUp = 12,
	cWingCmd_GodWingEquip = 3,
	cWingCmd_GodWingCompose = 6,
	cWingCmd_GodWingExchange = 7,
	cWingCmd_ReqUsePill = 8,
	

	-- EnhanceCmd  
	sEnhanceCmd_ReqEnhance = 2,
	sEnhanceCmd_UpdateBlessInfo = 3,
	sEnhanceCmd_BlessDecomposeResult = 4,
	sEnhanceCmd_RongLuUpdate = 5,

	cEnhanceCmd_Enhance = 2,
	cEnhanceCmd_EquipBless = 3,
	cEnhanceCmd_EquipBlessDecompose = 4,
	cEnhanceCmd_RongLuRongLian = 5,
	

	-- MailCmd  
	sMailCmd_MailListSync = 1,
	sMailCmd_ReqRead = 2,
	sMailCmd_DeleteMail = 3,
	sMailCmd_ReAward = 4,
	sMailCmd_AddMail = 5,


	cMailCmd_Read = 2,
	cMailCmd_Award = 4,
	

	-- TaskCmd  
	sTaskCmd_DailyDataListSync = 1,
	sTaskCmd_DailyDataSync = 2,
	sTaskCmd_ActiveValueSync = 3,
	sTaskCmd_ReActiveAward = 4,
	sTaskCmd_AchieveDataListSync = 5,
	sTaskCmd_DeleteAchieveTask = 6,
	sTaskCmd_AcceptAchieveTask = 7,
	sTaskCmd_AchieveDataSync = 8,
	sTaskCmd_LimitTimeTaskInit = 9,
	sTaskCmd_LimitTaskInfo = 10,

	cTaskCmd_DailyAward = 1,
	cTaskCmd_ActiveAward = 2,
	cTaskCmd_AchieveAward = 3,
	cTaskCmd_LimitRecevie = 5,
	cTaskCmd_LimitReward = 6,
	

	-- BossCmd  
	sBossCmd_PersonalInfo = 1,
	sBossCmd_BossList = 2,
	sBossCmd_UpdateBoss = 3,
	sBossCmd_ChallengeRecord = 4,
	sBossCmd_ChallengeReward = 5,
	sBossCmd_UpdateRank = 6,
	sWorldBoss_UpdateBossViewInfo = 10,
	sWorldBoss_SceneInfo = 11,
	sWorldBoss_QuitInfo = 12,
	sWorldBoss_BuyCdResult = 14,
	sWorldBoss_StartLottery = 16,
	sWorldBoss_ReqLottery = 17,
	sWorldBoss_UpdateLottery = 18,
	sWorldBoss_UpdateBelong = 7,
	sWorldBoss_BossShield = 11,
	sBossCmd_BossInfo = 20,
	sWorldBoss_UpdatePersonInfo = 21,
	sWorldBoss_UpdateGlobalInfo = 22,
	sWorldBoss_UpdateAttackedListInfo = 23,
	sWorldBoss_MultiKillNotice = 24,
	sWorldBoss_updateRebornTime = 25,
	sWorldBoss_sendWin = 26,
	sWorldBoss_Refresh = 27,
	sWorldBoss_ChallengeRecord = 28,
	sWorldBoss_SendReward = 29,
	sWorldBoss_SetClientData = 30,
	sNewWorldBoss_SendResult = 31,
	sNewWorldBoss_SendBossId = 32,
	sNewWorldBoss_RebornCd = 33,
	sNewWorldBoss_SendIcon = 34,
	sNewWorldBoss_BuyAttrCount = 35,
	sNewWorldBoss_RankInfo = 36,
	sWorldBoss_SendBossDie = 37,
	sHideBoss_Info = 38,

	cBossCmd_ReqPersonalInfo = 1,
	cBossCmd_ReqBossList = 2,
	cBossCmd_SetClientData = 3,
	cBossCmd_ReqChallengeRecord = 4,
	cBossCmd_ReqChallengeBoss = 5,
	cBossCmd_ReqRank = 6,

	cWorldBoss_ReqBossViewInfo = 10,
	cWorldBoss_BuyCd = 14,
	cWorldBoss_ChallengeBoss = 15,
	cWorldBoss_ReqLottery = 17,
	cWorldBoss_ChallengeRecord = 28,
	cWorldBoss_SetClientData = 29,
	cWorldBoss_BuyDayCount = 30,
	cNewWorldBoss_ReqEnter = 31,
	cNewWorldBoss_GetBossId = 32,
	cNewWorldBoss_BuyReborn = 33,
	cNewWorldBoss_BuyAttr = 34,
	cWorldBoss_CancelBelong = 35,
	cHideBoss_ReqEnter = 36,
	

	-- StoneCmd  
	sStoneCmd_DataSync = 1,
	sStoneCmd_ReqLevelUp = 2,

	cStoneCmd_LevelUp = 2,
	

	-- JingmaiCmd  
	sJingmaiCmd_DataSync = 1,

	cJingmaiCmd_levelup = 1,
	cJingmaiCmd_stageup = 2,
	cJingmaiCmd_open = 3,
	cJingmaiCmd_onelevel = 4,
	sJingmaiCmd_onelevel = 4,
	

	-- ZhuanShengCmd  
	sZhuanShengCmd_UpdateInfo = 1,
	cZhuanShengCmd_ReqPromote = 1,
	cZhuanShengCmd_ReqUpgrade = 2,
	

	-- ZhulingCmd  
	sZhulingCmd_DataSync = 1,
	sZhulingCmd_ReqLevelup = 2,

	cZhulingCmd_Levelup = 2,
	

	-- TupoCmd  
	sTupoCmd_DataSync = 1,
	sTupoCmd_ReqLevelup = 2,

	cZTupoCmd_Levelup = 2,
	

	-- StoreCmd  
	sStoreCmd_DataSync = 1,
	sStoreCmd_ReqBuy = 2,
	sStoreCmd_ItemStoreData = 3,
	sStoreCmd_StoreRefresh = 4,
	sStoreCmd_BuyIntegralItem = 5,
	sCMD_StoreFeatsInfo = 6,
	sCMD_StoreFeatsExchange = 7,

	cStoreCmd_DataRequest = 1,
	cStoreCmd_Buy = 2,
	cStoreCmd_Refresh = 3,
	cStoreCmd_BuyIntegralItem = 5,
	cCMD_StoreFeatsInfo = 6,
	cCMD_StoreFeatsExchange = 7,	
	

	-- ExRingCmd  
	sExRingCmd_UpdateRing = 1,
	sExRingCmd_ActActorRing = 2,
	sExRingCmd_UpgradeActorRing = 3,
	sExRingCmd_ActorData = 4,
	sExRingCmd_AdvancedActorRing = 5,
	sExRingCmd_OutOrInActorRing = 6,
	sExRingCmd_UnlockActorRing = 7,
	sExRingCmd_SkillBookData = 8,
	sExRingCmd_ItemUseData = 9,

	cExRingCmd_UpgradeRing = 1,
	cExRingCmd_ActActorRing = 2,
	cExRingCmd_UpgradeActorRing = 3,
	cExRingCmd_AdvancedActorRing = 5,
	cExRingCmd_OutOrInActorRing = 6,
	cExRingCmd_UnlockActorRing = 7,
	cExRingCmd_OpenSkillGrid = 8,
	cExRingCmd_InsertSkillBook = 9,
	cExRingCmd_LvUpSkillBook = 10,
	

	-- RankingCmd  
	cRankingCmd_ReqRankingData = 1,
	cRankingCmd_ReqWorshipData = 2,
	cRankingCmd_ReqWorship = 3,
	cRankingCmd_ReqAllWorshipData = 4,

	sRankingCmd_ResRankingData = 1,
	sRankingCmd_ResWorshipData = 2,
	sRankingCmd_UpdateWorship = 3,
	sRankingCmd_ResAllWorshipData = 4,
	

	-- VipCmd  
	sVipCmd_InitData = 1,
	sVipCmd_UpdateExp = 2,
	sVipCmd_UpdateRecord = 3,
	sVipCmd_GetWeekReward = 4,
	sVipCmd_GiftInfo = 5,
	sVipCmd_ReqSuperVipInfo = 6,

	cVipCmd_ReqReward = 1,
	cVipCmd_GetWeekReward = 4,
	cVipCmd_BuyGift = 5,
	cVipCmd_ReqSuperVipInfo = 6,
	

	-- NoticeCmd  
	sNoticeCmd_NoticeSync = 1,
	sNoticeCmd_TodayLook = 2,

	cNoticeCmd_SetTodayLook = 2,
	

	-- SoulShieldCmd  
	sSoulShieldCmd_ReqLevelUp = 1,
	sSoulShieldCmd_ReqStageUp = 2,
	sSoulShieldCmd_ReqAct = 3,

	cSoulShieldCmd_LevelUp = 1,
	cSoulShieldCmd_StageUp = 2,
	cSoulShieldCmd_Act = 3,
	

	-- TreasureHuntCmd  
	sTreasureHuntCmd_ResHunt = 1,
	sTreasureHuntCmd_ResRecord = 2,

	cTreasureHuntCmd_Hunt = 1,
	cTreasureHuntCmd_ReqRecord = 2,
	

	-- TrainCmd  
	sTrainCmd_InfoSync = 1,
	sTrainCmd_GetTrianAward = 3,

	cTrainCmd_LevelUp = 1,
	cTrainCmd_GetLevelAward = 2,
	cTrainCmd_GetTrianAward = 3,
	

	-- ChallengeCmd  
	sChallengeCmd_InfoSync = 1,
	sChallengeCmd_GetReward = 2,
	sChallengeCmd_LeftTime = 3,
	sChallengeCmd_RecReward = 4,
	sChallengeCmd_LotteryRes = 5,

	cChallengeCmd_Challenge = 1,
	cChallengeCmd_GetReward = 2,
	cChallengeCmd_RecReward = 4,
	cChallengeCmd_ReqLottery = 5,
	cChallengeCmd_RecLottery = 6,
	

	-- ActivityCmd  
	sActivityCmd_InitActivityData = 1,
	sActivityCmd_SendActivityData = 7,
	sActivityCmd_GetRewardResult = 2,
	sActivityCmd_GetLoginRewardDataResult = 11,
	sActivityCmd_GetLoginRewardResult = 12,
	sActivityCmd_SendDaBiaoData = 3,
	sActivityCmd_DaBiaoReward = 4,
	sActivityCmd_SendLoginDaysData = 5,
	sActivityCmd_UpdateInfo = 6,
	sActivityCmd_UpdateHongBao = 8,
	sActivityCmd_RouletteInfo = 15,
	sActivityCmd_BuyRoulette = 16,
	sActivityCmd_RouletteBeginRun = 17,
	sActivityCmd_RouletteEndRun = 18,
	sActivityCmd_RouletteGlobalInfo = 19,
	sActivityCmd_GetNextLoginRewardResult = 20,
	sActivityCmd_GetNextLoginRewardDataResult = 21,
	sActivityCmd_CSComsumeRank = 22,


	cActivityCmd_GetActivityData = 7,
	cActivityCmd_GetRewardRequest = 2,
	cActivityCmd_SendDaBiaoData = 3,
	cActivityCmd_GetLoginReward = 12,
	cActivityCmd_DaBiaoReward = 4,
	cActivityCmd_UpdateInfo = 6,
	cActivityCmd_RouletteInfo = 15,
	cActivityCmd_BuyRoulette = 16,
	cActivityCmd_RouletteBeginRun = 17,
	cActivityCmd_RouletteEndRun = 18,
	cActivityCmd_GetNextLoginReward = 20,
	cActivityCmd_CSComsumeRank = 22,



	

	-- 个人活动命令
	-- PActivityCmd  
	sPActivityCmd_InitActivityData = 1, -- 下发个人活动总的信息
	sPActivityCmd_SendActivityData = 7, -- 下发个人活动单个活动的信息
	sPActivityCmd_GetRewardResult = 2, -- 下发领取奖励记录

	cPActivityCmd_GetActivityData = 7, -- 请求单个活动数据
	cPActivityCmd_GetRewardRequest = 2, -- 请求单个活动奖励
	

	--  KnighthoodCmd
	 
	sTrainCmd_KnighthoodData = 5,
	cTrainCmd_LevelUpKnighthood = 6,
	cTrainCmd_StageUpKnighthood = 7,
	cTrainCmd_ReqActKnigthood = 8,
	

	-- YuPeiCmd  
	sTrainCmd_YuPeiData = 10,
	cTrainCmd_LevelUpYuPei = 10,
	

	-- ArtifactsCmd
	 
	sArtifactsCmd_ArtifactsData = 1,
	sArtifactsCmd_ArtifactsRankUpResult = 2,
	sArtifactsCmd_SyncImbaData = 3,
	sArtifactsCmd_UpdateImbaData = 4,

	cArtifactsCmd_ArtifactsRankUp = 2,
	cArtifactsCmd_ActImba = 3,
	cArtifactsCmd_ActImbaItem = 4,
	

	-- RechargeCmd
	 
	sRechargeCmd_UpdateFirstRecharge = 1,
	sRechargeCmd_InitChongZhi2 = 6,
	sRechargeCmd_UpdateChongZhi2 = 7,
	sRechargeCmd_RechargeItemRecord = 8,
	sRechargeCmd_RechargeDaysAward = 9,
	sRechargeCmd_MonthCardData = 20,
	sRechargeCmd_PrivilegeMonthCardData = 11, -- 下发特权数据
	sRechargeCmd_MultiDayRechargeData = 12,
	
	cRechargeCmd_GetFirstRechargeReward = 2,
	cRechargeCmd_GetDailyRechargeReward = 3,
	cRechargeCmd_ReqRewardChongZhi2 = 7,
	cRechargeCmd_RechargeDaysAward = 8,
	cRechargeCmd_GetPrivilegeAward = 10, -- 客户端请求领取特权奖励
	cRechargeCmd_GetMultiDayRechargeAward = 11,
	
	

	-- RefinesystemCmd
	 
	sRefinesystemCmd_RefinesystemData = 1,
	cRefinesystemCmd_Refine = 2,
	

	-- GiftCmd
	 
	sGiftCodeCmd_Result = 1,
	cGiftCodeCmd_GetGift = 1,
	

	-- ChatCmd
	 
	sChatCmd_ChatMsg = 1,
	cChatCmd_ChatMsg = 1,

	sChatCmd_SystemMsg = 2,

	sChatCmd_ChatMsgResult = 3,
	sChatCmd_Tipmsg = 4,
	sChatCmd_ShutUpTime = 5,
	


	-- EquipPointCmd
	 
	sEquipPoint_EquipPointData = 1,



	cEquipPoint_RankUp = 3,
	sEquipPoint_RankUp = 3,

	cEquipPoint_GrowUp = 4,
	sEquipPoint_GrowUp = 4,

	cEquipPoint_Resolve = 5,
	sEquipPoint_Resolve = 5,
	

	-- OtherBossCmd
	 
	cOtherBoss1Cmd_ReqBossList = 1,
	cOtherBoss1Cmd_ReqChallenge = 3,
	cOtherBoss1Cmd_ReqRankList = 4,
	cOtherBoss1Cmd_ReqLottery = 5,
	cOtherBoss1Cmd_ReqBuyCd = 6,


	sOtherBoss1Cmd_ResBossList = 1,
	sOtherBoss1Cmd_UpdateGlobalInfo = 2,
	sOtherBoss1Cmd_UpdatePersonInfo = 3,
	sOtherBoss1Cmd_ResRankList = 4,
	sOtherBoss1Cmd_UpdateLottery = 5,
	sOtherBoss1Cmd_ResChallenge = 7,
	sOtherBoss1Cmd_BossResult = 9,
	sOtherBoss1Cmd_ActorDie = 10,
	sOtherBoss1Cmd_ReqLottery = 11,
	sOtherBoss1Cmd_ReqLotteryBroast = 12,
	

	-- PlatformActivity
	 
	sPlatformActivityCmd_GetGiftbag = 1,
	sPlatformActivityCmd_15LevelNotify = 3,
	sPlatformActivityCmd_WeiXinShare = 4,


	cPlatformActivityCmd_GetGiftbag = 1,
	cPlatformActivityCmd_WeiXiGuanZhu = 2,
	cPlatformActivityCmd_WeiXinShare = 4,
	

	-- MiJiCmd
	 
	cMiJiCmd_LearnMiji = 2,
	cMiJiCmd_TransformMiJi = 3,
	cMiJiCmd_LearnMijiOk = 4,
	cMiJiCmd_Lock = 5,
	cMiJiCmd_Unlock = 6,

	sMiJiCmd_InitData = 1,
	sMiJiCmd_UpdateMiji = 2,
	sMiJiCmd_TransformMiJi = 3,
	sMiJiCmd_LockInfo = 6,
	
	-- Tianti
	 

	sTiantiCmd_TianData = 1,
	sTiantiCmd_MatchingActor = 2,
	sTiantiCmd_EndChallenges = 3,
	sTiantiCmd_RankData = 5,
	sTiantiCmd_BuyChallengesCount = 6,
	
	cTiantiCmd_MatchingActor = 2,
	cTiantiCmd_BeginChallenges = 3,
	cTinatiCmd_GetLastWeekAward = 4,
	cTiantiCmd_RankData = 5,
	cTiantiCmd_BuyChallengesCount = 6,
	

	
	-- Guild
	 
	cGuildCmd_GuildInfo = 1,
	cGuildCmd_MemberList = 2,
	cGuildCmd_GuildList = 3,
	cGuildCmd_CreateGuild = 4,
	cGuildCmd_ExitGuild = 5,
	cGuildCmd_ApplyJoin = 6,
	cGuildCmd_ApplyInfo = 7,
	cGuildCmd_RespondJoin = 8,
	cGuildCmd_ChangePos = 9,
	cGuildCmd_Impeach = 10,
	cGuildCmd_Kick = 11,
	cGuildCmd_Donate = 13,
	cGuildCmd_ChangeMemo = 14,
	cGuildCmd_SkillInfo = 15,
	cGuildCmd_UpgradeSkill = 16,
	cGuildCmd_UpgradeBuilding = 17,
	cGuildCmd_PracticeBuilding = 18,
	cGuildCmd_GetTaskAward = 21,
	cGuildCmd_GuildLogList = 22,
	cGuildCmd_DonateCount = 24,
	cGuildCmd_BasicInfo = 25,
	cGuildCmd_Chat = 26,
	cGuildCmd_ChatLog = 27,
	cGuildCmd_AutoApprove = 28,
	cGuildCmd_GuildSearchList = 29,
	cGuildCmd_DonateBonFire = 30,
	cGuildCmd_ChangeName = 31,

	sGuildCmd_GuildInfo = 1,
	sGuildCmd_MemberList = 2,
	sGuildCmd_GuildList = 3,
	sGuildCmd_CreateGuild = 4,
	sGuildCmd_Join = 6,
	sGuildCmd_ApplyInfo = 7,
	sGuildCmd_JoinResult = 8,
	sGuildCmd_ChangePos = 9,
	sGuildCmd_Exit = 11,
	sGuildCmd_Update = 12,
	sGuildCmd_FundChanged = 13,
	sGuildCmd_ChangeMemoResult = 14,
	sGuildCmd_SkillInfo = 15,
	sGuildCmd_UpgradeSkill = 16,
	sGuildCmd_UpgradeBuilding = 17,
	sGuildCmd_PracticeBuilding = 18,
	sGuildCmd_TaskInfoList = 19,
	sGuildCmd_TaskInfoChanged = 20,
	sGuildCmd_GuildLogList = 22,
	sGuildCmd_AddGuildLog = 23,
	sGuildCmd_DonateCount = 24,
	sGuildCmd_BasicInfo = 25,
	sGuildCmd_Chat = 26,
	sGuildCmd_ChatLog = 27,
	sGuildCmd_AutoApprove = 28,
	sGuildCmd_GuildSearchList = 29,
	sGuildCmd_bonFireUpdate = 30,
	
	-- TitleCmd
	 
	sTitleCmd_Info = 1,
	sTitleCmd_Add = 2,
	sTitleCmd_Del = 3,
	sTitleCmd_Update = 4,

	cTitleCmd_Info = 1,
	cTitleCmd_SetTitle = 4,
	
	-- CashCowCmd
	 
	sCashCowCmd_AllInfoSync = 1,
	sCashCowCmd_Shake = 2,
	sCashCowCmd_GetBox = 3,

	cCashCowCmd_Shake = 2,
	cCashCowCmd_GetBox = 3,
	
	-- GuildfbCmd
	 
	sGuildfbCmd_ActorInfo  = 1,
	sGuildfbCmd_Rank       = 2,
	sGuildfbCmd_DayTop     = 3,
	sGuildfbCmd_WavePass   = 4,
	sGuildCmd_InfoChange   = 5,
	sGuildfbCmd_DayAward   = 6,
	sGuildfbCmd_NextWave   = 7,
	sGuildfbCmd_WaveTime   = 8,
	sGuildfbCmd_StopSweep  = 9,

	--cGuildfbCmd_ActorInfo  = 1,
	cGuildfbCmd_Rank       = 2,
	cGuildfbCmd_DayTop     = 3,
	cGuildfbCmd_WavePass   = 4,
	cGuildfbCmd_Challenge  = 5,
	cGuildfbCmd_Sweep      = 6,
	cGuildfbCmd_Cheer      = 7,
	cGuildfbCmd_Welfare    = 8,
	

	-- GuildRobber
	 
	sGuildRobberCmd_list    = 1,
	sGuildRobberCmd_change  = 2,
	sGuildRobberCmd_refresh = 3,
	sGuildRobberCmd_times   = 4,

	cGuildRobberCmd_querylist = 1,
	cGuildRobberCmd_challenge = 2,
	


	-- GuildStoreCmd
	 
	sGuildStoreCmd_CommInfo = 1,
	sGuildStoreCmd_Log = 2,
	sGuildStoreCmd_Unpack = 3,

	cGuildStoreCmd_CommInfo = 1,
	cGuildStoreCmd_Log = 2,
	cGuildStoreCmd_Unpack = 3,
	

	-- GuildBattleCmd
	 
	sGuildBattleCmd_SendRedPacketData         = 1,
	sGuildBattleCmd_SendRedPacket             = 2,
	sGuildBattleCmd_GetRedPacket              = 3,
	sGuildBattleCmd_Enter                     = 4,
	sGuildBattleCmd_EnterNext                 = 5,
	sGuildBattleCmd_GuileAndActorIntegral     = 6,
	sGuildBattleCmd_SceneFeats                = 7,
	sGuildBattleCmd_GuildRanking              = 8,
	sGuildBattleCmd_IntegralRanking           = 9,
	sGuildBattleCmd_ResurgenceInfo            = 10,
	sGuildBattleCmd_ImperialPalaceAttribution = 11,
	sGuildBattleCmd_SignInData                = 12,
	sGuildBattleCmd_GuileActorIntegralList    = 14,
	sGuildBattleCmd_FlagsData                 = 15,
	sGuildBattleCmd_Settlement                = 17,
	sGuildBattleCmd_ShieldData                = 18,
	sGuildBattleCmd_DistributionData          = 19,
	sGuildBattleCmd_DistributionAward         = 20,
	sGuildBattleCmd_WinGuildInfo              = 21,
	sGuildBattleCmd_Open		      = 22,
	sGuildBattleCmd_GateShield                = 23,
	sGuildBattleCmd_JoinLottery               = 24,
	sGuildBattleCmd_ReturnJoinLottery         = 25,
	sGuildBattleCmd_GuildRankingGtopThree     = 26,
	sGuildBattleCmd_AttackInfo                = 27,
	sGuildBattleCmd_ActorDie		  = 28,
	sGuildBattleCmd_PersonalAwardData         = 29,
	sGuildBattleCmd_GetPersonalAward          = 30,
	sGuildBattleCmd_GateCountDown             = 31,
	sGuildBattleCmd_ReturnJoinLotteryBigNum   = 32,
	sGuildBattleCmd_SendKillCount		  = 33,
	sGuildBattleCmd_GetHefuBelongInfo	  = 34,


	cGuildBattleCmd_SendRedPacket             = 2,
	cGuildBattleCmd_GetRedPacket              = 3,
	cGuildBattleCmd_Enter                     = 4,
	cGuildBattleCmd_EnterNext                 = 5,
	cGuildBattleCmd_GuildRanking              = 8,
	cGuildBattleCmd_IntegralRanking           = 9,
	cGuildBattleCmd_GetSignInAward            = 13,
	cGuildBattleCmd_GuileActorIntegralList    = 14,
	cGuildBattleCmd_GotoFlags                 = 16,
	cGuildBattleCmd_DistributionAward         = 20,
	cGuildBattleCmd_WinGuildInfo              = 21,
	cGuildBattleCmd_RequestJoinLottery        = 25,
	cGuildBattleCmd_PersonalAwardData         = 29,
	cGuildBattleCmd_GetPersonalAward          = 30,
	cGuildBattleCmd_GetHefuBelongInfo	  = 34,

	

	-- ZhanLingCmd
	 
	sZhanLingCmd_SendInfo = 1, --登陆下发数据
	sZhanLingCmd_RepAddExp = 2, --回应提升经验
	sZhanLingCmd_RepUseItem = 3, --回应使用提升丹
	sZhanLingCmd_RepEquip = 4, --回应戴上装备
	sZhanLingCmd_SendEquipInfo = 6, --发送装备信息
	sZhanLingCmd_ShowZhanLing = 7, --展示战灵形象
	sZhanLingCmd_ShowTalent = 8, --触发战神附体
	sZhanLingCmd_RepLevelUpTalent = 11, --回应激活皮肤/升级皮肤天赋
	sZhanLingCmd_RepChangeFashion = 12, --回应换战灵皮肤

	cZhanLingCmd_ReqAddExp = 2, --请求提升经验
	cZhanLingCmd_ReqUseItem = 3, --请求使用提升丹
	cZhanLingCmd_ReqEquip = 4,  --请求戴上装备
	cZhanLingCmd_ReqCompose = 5, --请求合成装备
	cZhanLingCmd_ReqLevelUpTalent = 11, --请求激活皮肤/升级皮肤天赋
	cZhanLingCmd_ReqChangeFashion = 12, --请求切换战灵皮肤
	

	-- ZhuangBanCmd
	 
	sZhuangBanCmd_QueryInfo = 1,
	sZhuangBanCmd_Active = 2,
	sZhuangBanCmd_Use = 3,
	sZhuangBanCmd_UnUse = 4,
	sZhuangBanCmd_Invalid = 5,
	sZhuangBanCmd_UpLevel = 6,

	cZhuangBanCmd_QueryInfo = 1,
	cZhuangBanCmd_Active = 2,
	cZhuangBanCmd_Use = 3,
	cZhuangBanCmd_UnUse = 4,
	cZhuangBanCmd_UpLevel = 6,
	

	-- PlatformCmd
	 
	cPlatformCmd_QueryInfo = 1,
	cPlatformCmd_GetGift = 2,

	sPlatformCmd_QueryInfo = 1,
	sPlatformCmd_GetGift = 2,
	

	-- GuildBossCmd 
	 
	sGuildBossCmd_BaseInfo = 1,
	sGuildBossCmd_Result = 2,
	sGuildBossCmd_AllInfo = 3,
	sGuildBossCmd_EnterRet = 4,
	sGuildBossCmd_RankInfo = 5,

	cGuildBossCmd_Enter = 1,
	cGuildBossCmd_RecPassAward = 2,
	cGuildBossCmd_GetAllInfo = 3,
	cGuildBossCmd_GetRankInfo = 5,
	

	-- FriendCmd
	 
	sFriendCmd_GetFriendList = 1,
	sFriendCmd_GetChatsList = 2,
	sFriendCmd_GetApplyList = 3,
	sFriendCmd_GetBlackList = 4,
	sFriendCmd_AddListX = 7,
	sFriendCmd_DelListX = 9,
	sFriendCmd_online = 10,
	sFriendCmd_Chat = 11,
	sFriendCmd_SingleChat = 13,
	sFriendCmd_ChatCache = 14,

	cFriendCmd_GetFriendList = 1,
	cFriendCmd_GetChatsList = 2,
	cFriendCmd_GetApplyList = 3,
	cFriendCmd_GetBlackList = 4,
	cFriendCmd_AddFriend = 5,
	cFriendCmd_AddBlack = 6,
	cFriendCmd_AddResp = 8,
	cFriendCmd_DelListX = 9,
	cFriendCmd_Chat = 11,
	cFriendCmd_ChatCache = 14,
	

	-- KuangCmd
	 
	sKuang_KuangInfo = 1,
	sKuang_RefreshKuangLevel = 2,
	sKuang_StartCaiKuang = 3,
	sKuang_SceneData = 4,
	sKuang_QueryRecord = 6,
	sKuang_Attack = 7,
	sKuang_AttackBack = 13,
	sKuang_UpdateActorData = 9,
	sKuang_UpdateSceneData = 11,
	sKuang_CaiKuangEnd = 15,
	sKuang_KuangRecordUpdate = 16,
	sKuang_GetActorData = 17,

	cKuang_EnterFuben = 1,
	cKuang_RefreshKuangLevel = 2,
	cKuang_StartCaiKuang = 3,
	cKuang_GetCaiKuangReward = 5,
	cKuang_QueryRecord = 6,
	cKuang_Attack = 7,
	cKuang_Revenge = 8,
	cKuang_ReportRevengeResult = 10,
	cKuang_QuickFinish = 12,
	cKuang_ReportAttackResult = 13,
	cKuang_SwitchScene = 14,
	cKuang_GetActorData = 17,
	

	-- CMD_FuWen
	 
	cFuWenCmd_EquipFuwen = 1,
	cFuWenCmd_LevelUpFuwen = 2,
	cFuWenCmd_DecomPoseFuwen = 3,
	cFuWenCmd_ConverFuwen = 4,
	cFuWenCmd_TreasureHunt = 5,
	cFuWenCmd_TreasureLog = 6,
	cFuWenCmd_GetReward = 7,
	cFuWenCmd_Compose = 9,

	sFuWenCmd_EquipFuwen = 1,
	sFuWenCmd_LevelUpFuwen = 2,
	sFuWenCmd_DecomPoseFuwen = 3,
	sFuWenCmd_ConverFuwen = 4,
	sFuWenCmd_TreasureHunt = 5,
	sFuWenCmd_TreasureLog = 6,
	sFuWenCmd_RewardInfo = 8,
	sFuWenCmd_DelFuwen = 10,
	

	-- CMD_NeiGong
	 
	sNeiGongCmd_DataSync = 1,
	sNeiGongCmd_open = 3,

	cNeiGongCmd_LevelUp = 1,
	cNeiGongCmd_StageUp = 2,
	cNeiGongCmd_open = 3,
	

	-- CMD_TreasureBox
	 
	sTreasureBoxCmd_DataUpdateSync = 1,
	sTreasureBoxCmd_RecordUpdateSync = 3,
	sTreasureBoxCmd_BoxNoticeSync = 5,
	sTreasureBoxCmd_RewardNoticeSync = 6,

	cTreasureBoxCmd_ReqInfo = 1,
	cTreasureBoxCmd_SetBox = 2,
	cTreasureBoxCmd_GetFreeReward = 4,
	

	-- CMD_TuJian
	 
	cTuJianCmd_ReqInfo = 1,
	cTuJianCmd_ReqActivate = 2,
	cTuJianCmd_ReqDecompose = 3,
	cTuJianCmd_ReqUpLv = 4,

	sTuJianCmd_ReqInfo = 1,
	

	-- CMD_DailySign
	 
	cDailySignCmd_ReqGetMonthSignReward = 1,
	cDailySignCmd_ReqMonthSignSupply = 2,
	cDailySignCmd_ReqGetMonthSignDaysReward = 3,

	sDailySignCmd_MonthSignInfo = 1,
	

	-- HeirloomCMD
	 
	cHeirloomCmd_ReqCompose = 1,
	cHeirloomCmd_ReqActive = 2,
	cHeirloomCmd_ReqLvUp = 3,
	cHeirloomCmd_TreasureHunt = 4,
	cHeirloomCmd_TreasureLog = 5,
	cHeirloomCmd_GetReward = 6,

	sHeirloomCmd_Info = 1,
	sHeirloomCmd_TreasureHunt = 4,
	sHeirloomCmd_TreasureLog = 5,
	sHeirloomCmd_RewardInfo = 7,
	

	-- WeaponSoulCMD
	 
	cWeaponSoulCmd_ReqLevelUp = 1,
	cWeaponSoulCmd_ReqActive = 2,
	cWeaponSoulCmd_ReqUsed = 3,
	cWeaponSoulCmd_ReqItemAct = 4,
	cWeaponSoulCmd_ReqUseItem = 5,

	sWeaponSoulCmd_DataInfo = 0,
	sWeaponSoulCmd_PosInfo = 1,
	sWeaponSoulCmd_ActiveInfo = 2,
	sWeaponSoulCmd_UsedInfo = 3,
	sWeaponSoulCmd_ItemActInfo = 4,
	sWeaponSoulCmd_ItemDataInfo = 5,
	

	-- RichManCMD
	 
	sRichManCmd_Info = 1,
	sRichManCmd_TurnStep = 2,
	sRichManCmd_RoundAward = 3,
	sRichManCmd_AllRand = 4,
	sRichManCmd_UpdateTouzi = 5,

	cRichManCmd_ReqGetInfo = 1,
	cRichManCmd_ReqTurnStep = 2,
	cRichManCmd_ReqGetRoundAward = 3,
	

	-- CityCMD  
	sCityCmd_Belong = 1,
	sCityCmd_SendReward = 2,
	sCityCmd_BossProgress = 3,
	sCityCmd_CurBoss = 4,
	sCityCmd_RebornTime = 5,
	sCityCmd_BossShield = 6,
	sCityCmd_EnterCd = 7,

	cCityCmd_Enter = 1,
	cCityCmd_StopAi = 2,
	cCityCmd_BuyReborn = 3,
	

	-- RoleActivateCMD
	 
	sRoleActivateCMD_Reward = 1,
	sRoleActivateCMD_Info = 2,

	cRoleActivateCMD_Reward = 1,
	

	-- GodWeaponCMD
	 
	sGodWeaponCmd_UpdateExpInfo = 1,
	sGodWeaponCmd_UpdateAllInfo = 2,
	sGodWeaponCmd_FubenInfo = 6,
	sGodWeaponCmd_FubenRankInfo = 9,
	sGodWeaponCmd_TaskInfo = 10,
	sGodWeaponCmd_SendFubenRewards = 13,

	cGodWeaponCmd_SkillLevelUp = 3,
	cGodWeaponCmd_FitGodItem = 4,
	cGodWeaponCmd_WeaponLevelUp = 5,
	cGodWeaponCmd_GetFubenInfo = 6,
	cGodWeaponCmd_FubenEnter = 7,
	cGodWeaponCmd_FubenBuyBuff = 8,
	cGodWeaponCmd_GetFubenRankInfo = 9,
	cGodWeaponCmd_AcceptTask = 11,
	cGodWeaponCmd_FinishTask = 12,
	cGodWeaponCmd_GetFubenRewards = 13,
	cGodWeaponCmd_ResetSkill = 14,
	

	-- CampBattleCMD
	 
	sCampBattleCmd_Enter = 1,
	sCampBattleCmd_RankingTopData = 2,
	sCampBattleCmd_Open = 3,
	sCampBattleCmd_ResurgenceInfo = 4,
	sCampBattleCmd_GetPersonalAward = 5,
	sCampBattleCmd_PersonalAwardData = 6,
	sCampBattleCmd_ActorIntegral = 7,
	sCampBattleCmd_NoticeCampchange = 9,
	sCampBattleCmd_MyData = 10,
	sCampBattleCmd_NotifyCd = 11,
	sCampBattleCmd_NotifyEnd = 12,
	sCampBattleCmd_NotifyCountDown = 13,
	sCampBattleCmd_NotifyBeginNewRound = 14,
	sCampBattleCmd_SendKillCount = 15,

	cCampBattleCmd_Enter = 1,
	cCampBattleCmd_BuyCd = 4,
	cCampBattleCmd_GetPersonalAward = 5,
	

	-- PassionPointCMD
	 
	sPassionPointCMD_EnterFb = 1,
	sPassionPointCMD_BelongInfo = 2,
	sPassionPointCMD_NotifyCd = 3,
	sPassionPointCMD_Open = 4,
	sPassionPointCMD_ResurgenceInfo = 5,
	sPassionPointCMD_ReqMyselfInfo = 6,
	sPassionPointCMD_UpdateArea = 7,
	sPassionPointCMD_Settlement = 8,
	sPassionPointCMD_ActorData = 9,

	cPassionPointCMD_EnterFb = 1,
	cPassionPointCMD_BuyCd = 5,
	cPassionPointCMD_ReqMyselfInfo = 6,
	

	-- HolyComposeCMD
	 
	sHolyComposeCMD_ReqCompose = 1,
	sHolyComposeCMD_ReqFuse = 2,

	cHolyComposeCMD_ReqCompose = 1,
	cHolyComposeCMD_ReqFuse = 2,
	

	-- ReincarnateCMD
	 
	sReincarnateCMD_UpdateInfo = 1,
	sReincarnateCMD_EquipCompose = 4,

	cReincarnateCMD_ReqPromote = 2,
	cReincarnateCMD_ReqUpgrade = 3,
	cReincarnateCMD_EquipCompose = 4,
	

	-- PrestigeCMD
	 
	sPrestigeCMD_ReqPrestigeInfo = 1,

	cPrestigeCMD_ReqGetBack = 2,
	

	-- PeakRaceCMD  
	cPeakRace_ReqSignUp = 1,
	cPeakRace_GetKKinfo = 3,
	cPeakRace_GetPromInfo = 4,
	cPeakRace_ReqRankData = 5,
	cPeakRace_ReqLike = 6,
	cPeakRace_ReqBett = 7,
	cPeakRace_GetCrossKKinfo = 8,
	cPeakRace_GetCorssPromInfo = 9,
	cPeakRace_ReqCrossRankData = 10,
	cPeakRace_ReqCrossLike = 11,
	cPeakRace_ReqCrossBett = 12,
	cPeakRace_ReqCrossBettInfo = 13,
	cPeakRace_ReqMobai = 14,

	sPeakRace_SendCurStatus = 0,
	sPeakRace_SendSignUp = 1,
	sPeakRace_SendFbResult = 2,
	sPeakRace_SendKKinfo = 3,
	sPeakRace_SendPromInfo = 4,
	sPeakRace_SendRankData = 5,
	sPeakRace_SendBettInfo = 7,
	sPeakRace_SendCrossKKinfo = 8,
	sPeakRace_SendCorssPromInfo = 9,
	sPeakRace_SendCrossRankData = 10,
	sPeakRace_SendCrossBettInfo = 12,
	sPeakRace_SendFbStartTime = 13,
	sPeakRace_MobaiSuccess = 14,
	

	-- WuJiCMD
	 
	sWuJi_SendStatusInfo = 0,
	sWuJi_SendWuJiMatch = 1,
	sWuJi_SendCancelWuJiMatch = 2,
	sWuJi_SendInitInfo = 3,
	sWuJi_SendResult = 4,
	sWuJi_SendChangeScore = 5,
	sWuJi_SendFlagCamp = 6,
	sWuJi_SendOneHp = 7,
	sWuJi_SendBaseInfo = 8,
	sWuJi_SendChat = 9,
	sWuJi_SendAllInfo = 10,
	sWuJi_SendRebornCd = 11,
	sWuJi_SendActorInfo = 12,

	cWuJi_ReqWuJiMatch = 1,
	cWuJi_ReqCancelWuJiMatch = 2,
	cWuji_ReqEnterFuBen = 3,
	cWuJi_ReqChat = 9,
	cWuJi_ReqAllInfo = 10,
	

	-- HeartMethodCmd
	 
	sHeartMethodCmd_SendAllInfo = 1,  --下发总数据
	sHeartMethodCmd_SendInfo = 2,  --下发单条数据
	sHeartMethodCmd_RepDecomPose = 5,  --回复一键分解

	cHeartMethodCmd_ReqLevelUp = 3,  --请求升星
	cHeartMethodCmd_ReqEquipPos = 4,  --请求装备部位
	cHeartMethodCmd_ReqDecomPose = 5,  --请求一键分解
	

	-- JadePlateCMD
	 
	sJadePlateCmd_JadePlateData = 1,

	cJadePlateCmd_UseItemUpgrate = 2,
	cJadePlateCmd_LevelUp = 3,
	

	-- FlameStampCmd
	 
	sFlameStampCmd_SendInfo = 1,  --下发总数据
	sFlameStampCmd_RepAddExp = 2,  --回应提升等级经验

	cFlameStampCmd_ReqAddExp = 2,  --请求提升等级经验
	cFlameStampCmd_ReqLearnEff = 3,  --请求提升印记效果
	cFlameStampCmd_ReqCompose = 4,  --请求合成材料
	

	-- CrossBossCmd
	 
	sCrossBossCmd_SendBossInfo = 1,
	sCrossBossCmd_belongUpdate = 2,
	sCrossBossCmd_ResurgenceInfo = 3,
	sCrossBossCmd_BossResurgence = 5,
	sCrossBossCmd_FlagRefresh = 7,
	sCrossBossCmd_UpdateFlagInfo = 8,
	sCrossBossCmd_SendActorInfo = 9,
	sCrossBossCmd_SendRewardInfo = 10,
	sCrossBossCmd_ReqShowInfo = 11,
	sCrossBossCmd_SendWinInfo = 12,

	cCrossBossCmd_ReqBossInfo = 1,
	cCrossBossCmd_BuyCd = 3,
	cCrossBossCmd_CancelBelong = 4,
	cCrossBossCmd_RequestEnter = 6,
	cCrossBossCmd_RequestCollect = 8,
	cCrossBossCmd_ReqShowInfo = 11,
	

	-- ShenShouCmd
	 
	sShenShouCmd_SendInfo = 1, --登陆下发数据
	sShenShouCmd_RepEquip = 2, --回应戴上装备
	sShenShouCmd_RepBattle = 4, --请求出战
	sShenShouCmd_RepUseItem = 5, --回应使用上限提升道具
	sShenShouCmd_SendExp = 6, --下发经验数据
	sShenShouCmd_RepLevelUpEquip = 7, --回应升级装备
	sShenShouCmd_RepSmelt = 8, --回应熔炼装备

	cShenShouCmd_ReqEquip = 2,  --请求戴上装备
	cShenShouCmd_ReqCompose = 3, --请求合成装备
	cShenShouCmd_ReqBattle = 4, --请求出战
	cShenShouCmd_ReqUseItem = 5, --请求使用上限提升道具
	cShenShouCmd_ReqLevelUpEquip = 7, --请求升级装备
	cShenShouCmd_ReqSmelt = 8, --请求熔炼装备
	

	-- HunGuCmd
	 
	sHunGuCmd_SendInfo = 1, --登陆下发数据
	sHunGuCmd_RepEquip = 2, --回应戴上装备
	sHunGuCmd_RepPosLevelUp = 3, --回应升级魂玉
	sHunGuCmd_RepEquipLevelUp = 4, --回应装备升阶
	sHunShouCmd_SweepResult = 6,
	sHunShouCmd_InfoSync = 7,
	sHunShouCmd_LeftTime = 8,

	cHunGuCmd_ReqEquip = 2,  --请求戴上装备
	cHunGuCmd_ReqPosLevelUp = 3, --请求升级魂玉
	cHunGuCmd_ReqEquipLevelUp = 4, --请求装备升阶
	cHunShouCmd_Challenge = 5,
	cHunShouCmd_Sweep = 6,
	

	-- DevilBossCmd
	 
	sDevilBossCmd_SendBossInfo = 1,
	sDevilBossCmd_belongUpdate = 2,
	sDevilBossCmd_ResurgenceInfo = 3,
	sDevilBossCmd_ReqShowInfo = 6,
	sDevilBossCmd_SendRewardInfo = 7,
	sDevilBossCmd_SendActorInfo = 8,

	cDevilBossCmd_ReqBossInfo = 1,
	cDevilBossCmd_BuyCd = 3,
	cDevilBossCmd_CancelBelong = 4,
	cDevilBossCmd_RequestEnter = 5,
	cDevilBossCmd_ReqShowInfo = 6,
	
	
	-- AuctionCmd
	 
	cAuctionCmd_ReqGoodsList = 1,
	cAuctionCmd_ReqOpenBox = 2,
	cAuctionCmd_ReqUseBox = 3,
	cAuctionCmd_ReqBid = 4,
	cAuctionCmd_ReqBuy = 5,
	cAuctionCmd_ReqRecordList = 6,

	sAuctionCmd_RepGoodsList = 1,
	sAuctionCmd_RepOpenBox = 2,
	sAuctionCmd_RepUseBox = 3,
	sAuctionCmd_RepBid = 4,
	sAuctionCmd_RepBuy = 5,
	sAuctionCmd_RepRecordList = 6,
	sAuctionCmd_Limit = 7,
	

	-- Cross3Vs3
	 
	cCross3Vs3_CreateTeam = 1,
	cCross3Vs3_OneMatch = 2,
	cCross3Vs3_DissolveTeam = 3,
	cCross3Vs3_BeginMatch = 4,
	cCross3Vs3_Invitation = 5,
	cCross3Vs3_WorldInvitation = 6,
	cCross3Vs3_AnswerInvitation = 7,
	cCross3Vs3_TickTeam = 8,
	cCross3Vs3_RequestCollect = 10,
	cCross3Vs3_CancelMatch = 16,
	cCross3Vs3_JoinTeam = 18,
	cCross3Vs3_GuildMember = 20,
	cCross3vs3_GetMetalAward = 23,
	cCross3Vs3_GetPeakAward = 24,
	cCross3Vs3_GetRankInfo = 25,
	cCross3Vs3_RequestRankInfo = 19,

	sCross3Vs3_ActorInfo = 1,
	sCross3Vs3_TeamInfo = 2,
	sCross3Vs3_Invitation = 5,
	sCross3Vs3_InvitationSuccess = 7,
	sCross3Vs3_FlagRefresh = 9,
	sCross3Vs3_UpdateFlagInfo = 10,
	sCross3Vs3_ResurgenceInfo = 11,
	sCross3Vs3_SendCountTime = 12,
	sCross3Vs3_SendFbInfo = 13,
	sCross3Vs3_SendSettleInfo = 14,
	sCross3Vs3_MatchInfo = 16,
	sCross3Vs3_UpdateIntegral = 17,
	sCross3Vs3_UpdateRankInfo = 19,
	sCross3Vs3_GuildMember = 20,
	sCross3Vs3_UpdateNotice = 21,
	sCross3Vs3_SendMySelfInfo = 22,
	sCross3Vs3_SendAwardInfo = 23,
	sCross3Vs3_SendRankInfo = 25,
	sCross3Vs3_NoticeOpen = 26,
	
}
