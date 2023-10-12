PlatFormConf =
{
	--平台标签
	["union-10029"] =
	{

		openLevel = 20,
		dayIndex = {7,15,21,28}, --累计登陆天数
		--专属奖励
		onceAward =
				{
					--type = 1 表示物品，param表示物品id，num表示数量
					--type=2时，表示金钱奖励，param为0是绑定金币，1是非绑金币，2是绑定元宝，3是元宝
					{type = 1, param = 30108, num = 1, bind = 1, quality = 0},
				},

		--每日奖励
		dayAward =
				{
					--type = 1 表示物品，param表示物品id,num表示数量
					--type=2时，表示金钱奖励，param为0是绑定金币，1是非绑金币，2是绑定元宝，3是元宝
					{type = 1, param = 18221, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18633, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18260, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18261, num = 1, bind = 1, quality = 0},
				},

		--累计登陆
		loopAward =
		{
			[7] =
				{
					--type = 1 表示物品，param表示物品id,num表示数量
					--type=2时，表示金钱奖励，param为0是绑定金币，1是非绑金币，2是绑定元宝，3是元宝
					{type = 1, param = 18611, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18710, num = 2, bind = 1, quality = 0},
					{type = 1, param = 18602, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18211, num = 1, bind = 1, quality = 0},
				},
			[15] =
				{
					--type = 1 表示物品，param表示物品id,num表示数量
					--type=2时，表示金钱奖励，param为0是绑定金币，1是非绑金币，2是绑定元宝，3是元宝
					{type = 1, param = 18611, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18710, num = 2, bind = 1, quality = 0},
					{type = 1, param = 18201, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18212, num = 1, bind = 1, quality = 0},
				},
			[21] =
				{
					--type = 1 表示物品，param表示物品id,num表示数量
					--type=2时，表示金钱奖励，param为0是绑定金币，1是非绑金币，2是绑定元宝，3是元宝
					{type = 1, param = 18611, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18602, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18201, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18211, num = 3, bind = 1, quality = 0},
				},
			[28] =
				{
					--type = 1 表示物品，param表示物品id,num表示数量
					--type=2时，表示金钱奖励，param为0是绑定金币，1是非绑金币，2是绑定元宝，3是元宝
					{type = 1, param = 18611, num = 1, bind = 1, quality = 0},
					{type = 1, param = 18602, num = 2, bind = 1, quality = 0},
					{type = 1, param = 18201, num = 2, bind = 1, quality = 0},
					{type = 1, param = 18211, num = 5, bind = 1, quality = 0},
				},
		},

		desc1 = Lang.platform.platform001,
		desc2 = Lang.platform.platform002,

	}
}
