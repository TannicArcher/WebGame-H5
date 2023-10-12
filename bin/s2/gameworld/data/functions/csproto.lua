
CrossSrvCmd =
{
	SCCheckCmd = 1,		--匹配版本号检查
	SCrossNetCmd = 2,	--跨服信息传输
	SCWujiCmd = 3, 		--无极战场
	SCPeakRaceCmd = 4,  --巅峰赛季
	SCComsumeCmd = 5,	--跨服消费
	SCQueryCmd = 6, --跨服查询角色
	SCCrossBossCmd = 7,	--跨服boss
	SCActivityCmd = 8,	--跨服活动
	SCGuildCmd = 9,--公会
	SCDevilBossCmd = 10,	--魔界入侵
	SCCross3vs3 = 11,	--跨服3v3

	--测试消息
	SFuncCmd = 255,
}


CrossSrvSubCmd =
{
	--匹配版本号检查 SCCheckCmd
	SCCheckCmd_CheckVersion = 1,
	SCCheckCmd_OpenTime = 2, --发送开服时间

	--公共跨服网络传输消息 -SCrossNetCmd
	SCrossNetCmd_TransferToServer = 1,	-- 转发给其它服
	SCrossNetCmd_TransferToActor = 2,	-- 转发给其他玩家
	SCrossNetCmd_TransferToFightServer = 3,	-- 转发给战斗服
	SCrossNetCmd_Route = 4,			-- 发送路由数据
	SCrossNetCmd_TransferMail = 6,	-- 转发邮件
	SCrossNetCmd_AnnoTips = 7, --公告提示
	SCrossNetCmd_TransferGM = 8, --发送gm命令到战斗服


	--无极战场 SCWujiCmd
	SCWujiCmd_ToMatch = 1, --玩家去匹配 游戏服=>跨服
	SCWujiCmd_ToCancelMatch = 2, --玩家取消匹配 游戏服=>跨服
	SCWujiCmd_StartPer = 3, --战场预告消息 跨服=>游戏服
	SCWujiCmd_Start = 4, --战场开始消息 跨服=>游戏服
	SCWujiCmd_Stop = 5, --战场结束消息 跨服=>游戏服
	SCWujiCmd_MatchSuccess = 6, --匹配成功 跨服=>游戏服
	SCWujiCmd_FuBenEnd = 7, --一个战场副本结束了 跨服=>游戏服

	--巅峰赛季 SCPeakRaceCmd
	SCPeakRaceCmd_SendProm16 = 1, --单服16强去跨服报名 游戏服=>跨服 {char:数组大小, array{int:玩家ID,string:名字,char:职业,char:性别}}
	SCPeakRaceCmd_NeedEnter  = 2, --通知玩家进入PK副本 跨服=>游戏服 {int:玩家ID, int:副本handle}
	SCPeakRaceCmd_EnterStatus = 3, --回应进入状态 游戏服=>跨服 {int:副本handle,int:玩家ID,char:1.能正常进入,0.不能进入}
	SCPeakRaceCmd_StatusChange = 4, --通知当前状态变化 跨服=>游戏服 {char:状态,char:是否结束}
	SCPeakRaceCmd_DataTunnel = 5, --数据通道 双服使用
	SCPeakRaceCmd_BeetErr = 6, --下注失败

	--跨服查询角色
	SCQueryCmd_SrcToCross = 1, -- 普通服发到跨服查询
	SCQueryCmd_CrossToTar = 2, -- 跨服发到目标服查询
	SCQueryCmd_TarToCross = 3, -- 目标服返回数据到跨服
	SCQueryCmd_CrossToSrc = 4, -- 跨服返回数据到普通服

	--SCComsumeCmd  跨服消费
	SCComsumeCmd_RankDataRequest = 1, 	--排行榜数据请求
	SCComsumeCmd_RankDataSync = 2, 		--排行榜数据回包
	SCComsumeCmd_RoleDataRequest = 3, 	--角色数据请求
	SCComsumeCmd_RoleDataSync = 4, 		--角色数据回包
	SCComsumeCmd_UpdateRankInfo = 5,	--更新排行榜

	--活动
	SCActivityCmd_BroadCast = 1,    --跨服广播  游戏服到跨服
	SCActivityCmd_Type2SendNum = 2, --充值限购活动,同步购买次数

	--跨服boss SCBossCmd
	SCBossCmd_RefreshBoss = 1, --boss刷新通知 跨服=>游戏服
	SCBossCmd_sendReward  = 2, --奖励发送 跨服=>游戏服
	SCBossCmd_enterFb     = 3, --进入副本公告 跨服=>游戏服
	SCBossCmd_closeFb     = 4, --关掉游戏服副本 跨服=>游戏服

	--公会跨服信息
	SCGuildCmd_Broadcast = 1, --公会消息包广播
	SCGuildCmd_CrossChat = 2, --在跨服发公会聊天

	--魔界入侵 SCDevilBossCmd
	SCDevilBossCmd_RefreshBoss = 1, --boss刷新通知 跨服=>游戏服
	SCDevilBossCmd_sendPersonReward  = 2, --个人奖励发送 跨服=>游戏服
	SCDevilBossCmd_sendGuildAuction  = 3, --帮派拍卖发送 跨服=>游戏服

	--跨服3v3
	SCCross3vs3_BeginMatch = 1,		--开始匹配 游戏服=>跨服
	SCCross3vs3_StopMatch = 2,		--停止匹配 游戏服=>跨服
	SCCross3vs3_UpdateRank = 3,		--更新队员 跨服=>游戏服
	SCCross3vs3_SaveActorFbHandle = 4,		--保存玩家跨服副本handle 跨服=>游戏服

	--测试消息
	SFuncCmd_Test = 255,
}
