--关注微信
WeixinActivity = 
{
	step = {Lang.weixinLan.weixin001,
			Lang.weixinLan.weixin002,
			Lang.weixinLan.weixin003,
									}, -- 关注的步骤

	qqQun = {467696765,479934168,254037158},

	weiXinRewards = { -- 微信礼包展示配置
			{type = 0, id = 18210, count = 1, bind = false, job = -1, sex = -1, group=0},--2级宝石
			{type = 0, id = 18611, count = 2, bind = false, job = -1, sex = -1, group=0},
			{type = 0, id = 18211, count = 5, bind = false, job = -1, sex = -1, group=0},
	},

	--规则描述
	ruleDesc = "如果您在游戏中有不明白的地方或者无法解决的问题\n请通过<font color='#1DE722'>官方论坛</font>、微博、企鹅群联系我们",

	--超链接打开的网址
	openUrl = "http://bbs.open.qq.com/forum-3824-1.html",

	--加企鹅群的网址
	joinHome = "http://jq.qq.com/?_wv=1027&k=Sw3Hs2",

	rewards = { -- 企鹅群展示奖励配置
				{type = 0, id = 18210, count = 1, bind = false, job = -1, sex = -1, group=0},
				{type = 0, id = 18602, count = 2, bind = false, job = -1, sex = -1, group=0},
				{type = 0, id = 18211, count = 5, bind = false, job = -1, sex = -1, group=0},
	},

	--微信激活码
	weixincode = {
		{
			code = "xiaoyao888",
			gifts = {
					{itemid =18210, count = 1, quality = 0, strong= 0, bind=1},
					{itemid =18611, count = 2, quality = 0, strong= 0, bind=1},
					{itemid =18211, count = 5, quality = 0, strong= 0, bind=1},
				},
		},
		{
			code = "xiaoyaonb666",
			gifts = {
					{itemid =18210, count = 1, quality = 0, strong= 0, bind=1},
					{itemid =18602, count = 2, quality = 0, strong= 0, bind=1},
					{itemid =18211, count = 5, quality = 0, strong= 0, bind=1},
				},
		},

	},
}

