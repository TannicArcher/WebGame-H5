TimerConfig=
{
	--脚本用到的定时执行的一些逻辑的配置
	--比如定时发公告，定时执行脚本
	--openSrv 表示是否根据开服第几天判断，比如 openSrv = 1, day = 7, 表示开服后第七天，默认 openSrv是0,取值只有(0,1)
	--hfSrv 表示是否根据开服第几天判断，比如 hfSrv = 1, day = 7, 表示合服后第七天，默认 hfSrv是0,取值只有(0,1)
	--month 表示月份，{}表示匹配所有,其他有效范围是[1,12],比如1月3月执行用{1,3},不配置表示不是每个月执行的
	--day 表示一个月的哪天有效，{}表示匹配所有,其他有效范围是[1,31]，1日和3日用{1,3}
	--week 就是一个星期的哪几天有效，{}表示匹配所有，其他有效范围是[0,6]注意周日是0，1表示周1,比如周1和周日执行就是{1,0}
	--hour 表示那个时间点,{}表示匹配所有，其他有效范围是[0,23]，比如1点和3点,5点执行就是{1,3,5}
	--minute 表示是哪个分钟，{}空表示所有，那么每分钟都将执行,{0,1,2}表示0,1,2分执行，有效范围[0,59]
	--func表示在该npc身上执行的函数，支持带参数的，单数一,分隔，比如TestBroadCast,1,2,"ss"之类的
	--params 表示执行函数时带的参数
	-- txt : 公告文字
	-- 注意 func 和txt 2个可以同时配置(表示既发广播，也执行函数)，或者只配置其中一个

	-- 这个是配置开服第几天几点执行的操作,openSrv填1,另外只有day和hour填，其他时间如month不用填
	-- 比如这个表示开服第7天的22点执行函数
	-- 这个不要随便改，如果修改，同时要修改对应的脚本

	{ week = {0,1,3,5}, hour = 0, minute = 0, func= "RefreshGuildBoss"}, -- 关闭公会boss
	{ week = {1,3,5}, hour = 19, minute = 57, func= "CampBattleAdvance"}, -- 开启阵营战预告
	{ week = {1,3,5}, hour = 20, minute = 0, func= "CampBattleOpen"}, -- 开启阵营战
	{ week = {2,4}, hour = 19, minute = 57, func= "PassionPointAdvance"}, -- 开启激情泡点预告
	{ week = {2,4}, hour = 20, minute = 0, func= "PassionPointOpen"}, -- 开启激情泡点
	{ week={1},hour=10,minute =0,func= "OpenTianti", params = {true}}, -- 开启天梯
	{ week={0},hour=22,minute =30,func= "CloseTianti"}, -- 关闭天梯 
	{ hour=0,minute=5,func="ChangePrestigeExpData"},--凌晨回收威望
	{ week={1},hour=0,minute =0,func= "ResetFuwenTreasure"}, -- 重置符文寻宝累计次数 
	{ week={1},hour=0,minute =0,func= "ResetHeirloomTreasure"}, -- 重置传世寻宝累计次数 
	{ hour={0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23}, minute=0, func= "WorldBossOnHour"}, -- 世界boss的定点检测
	{ hour=19,minute=20,func="newWorldBossPerStart", params = {600}},--新世界boss活动开启10分钟前
	{ hour=19,minute=30,func="newWorldBossStart"},--新世界boss活动开启
	{ hour= 20, minute = 30, func = "DevilBossOpen"}, --开始魔界入侵
	{ hfSrv=1,day=1, hour=20,minute=30, func="createCityBoss", params = {1}}, --合服第1天刷主城BOSS
	{ hfSrv=1,day=2, hour=20,minute=30, func="createCityBoss", params = {2}}, --合服第2天刷主城BOSS
	{ hfSrv=1,day=4, hour=20,minute=30, func="createCityBoss", params = {3}}, --合服第4天刷主城BOSS
	{ hfSrv=1,day=6, hour=20,minute=30, func="createCityBoss", params = {4}}, --合服第6天刷主城BOSS

	{ hour= 0, minute = 0, func = "CSCumsumeRankNewday"} ,    --跨服消费榜活动跨天
	{ week={0},hour=23,minute=0,func="TeamFuBenRest"} ,    --组队副本刷新
	{ week={1},hour=0,minute=0,func="PeakRaceSendLikeRankReward"} ,    --组队副本刷新
	-- { hour=19, minute = 57, func= "openGuildBattleTips"} , --每天20点开启决战沙城玩法前三分钟提示
	-- { hour=20, minute = 0, func= "openGuildBattle"} , --每天20点开启决战沙城玩法


	{hour={11, 21}, minute=55, func="NoticeOpenCrossArena", params = {300}}, 	--开启跨服竞技场预告 params预告剩余时间
	{hour={12, 22}, minute=0, func="OpenCrossArenaFb", params = {1800}}, 	--开启跨服竞技场  params 活动时间
	{day = 1,hour=0, minute=0, func="ResetCrossArenaRankingList"}, 	--重置跨服竞技场的排行榜
}
