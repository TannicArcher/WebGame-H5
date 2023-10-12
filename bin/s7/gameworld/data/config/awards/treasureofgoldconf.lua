--[[
	author = 'Roson'
	time   = 8.21.2015
	name   = 聚宝成金配置
	ver    = 0.1
]]

TreasureOfGoldConf =
{
	minLevel = 40,
	timeConf =
	{
		beginTime = {2015, 8, 21, 0, 0, 0},
		endTime = {2018,12, 31, 23, 23, 23},
	},

	reAddCount = 1,	--每日增加次数
	maxCount = 7,	--累积最大次数

	srcYBCount = 50,	--每次需要扣除的元宝(不含绑定)数量

	retMoneyType = mtBindYuanbao,

	ruleDesc = Lang.openserver.treasureofgold001,

	tarConf =
	{
		--{rate = 概率（10000）, cnt = 倍数, broadcast = 是否广播},
		{rate = 3000, cnt = 3,},
		{rate = 5000, cnt = 4,},
		{rate = 2000, cnt = 5, broadcast = true},
	}
}
