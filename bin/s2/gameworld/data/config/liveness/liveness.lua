--活跃度奖励配置
ActivityAward = {
	openLevel = 20, --开启等级
	targets = {		--活跃目标
	  -- 完成日常任务10次
		{
			id = 0,		--id，从0开始递增
			desc = Lang.Misc.m000500,	--活跃目标描述，用语言包,客户端用
			times = 10,	--需要达成的次数
			point = 5,	--奖励的活跃度
			click = 1,  --该项目是否可点击，即是否可寻路或可打开相应界面，0为不可以，1为可以
		},

	  -- 完成帮派任务1次 
		{
			id = 1,		--id，从0开始递增
			desc = Lang.Misc.m000501,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
      -- 帮派摇骰子1次
		{
			id = 2,		--id，从0开始递增
			desc = Lang.Misc.m000502,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
      -- 喂养帮派神兽1次
		{
			id = 3,		--id，从0开始递增
			desc = Lang.Misc.m000503,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
      -- 赠送鲜花1次
		{
			id = 4,		--id，从0开始递增
			desc = Lang.Misc.m000504,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
	  --探索秘藏1次 
		{
			id = 5,		--id，从0开始递增
			desc = Lang.Misc.m000505,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
      -- 武神台挑战5次
		{
			id = 6,		--id，从0开始递增
			desc = Lang.Misc.m000506,	--活跃目标描述，用语言包,客户端用
			times = 5,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
      --[[ 进行鞭尸1次
		{
			id = 7,		--id，从0开始递增
			desc = Lang.Misc.m000507,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 0,
		},]]
		
		-- 护送美女3次
		{
			id = 8,		--id，从0开始递增
			desc = Lang.Misc.m000508,	--活跃目标描述，用语言包,客户端用
			times = 3,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
		-- 进行钓鱼5次，该项目需要寻路到自定地点才能开始钓鱼
		{
			id = 9,		--id，从0开始递增
			desc = Lang.Misc.m000509,	--活跃目标描述，用语言包,客户端用
			times = 5,	--需要达成的次数
			point = 5,	--奖励的活跃度
			click = 1,
		    mappoint = {Lang.Misc.mt00001,53,86},   --逍遥城，自动寻路坐标，格式{地图名称，X坐标，Y坐标}
		},
		
      -- 参加万妖遗迹1次
		{
			id = 10,		--id，从0开始递增
			desc = Lang.Misc.m000510,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},

      --[[挑战八卦副本1次
		{
			id = 11,		--id，从0开始递增
			desc = Lang.Misc.m000511,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},]]

      -- 挑战缘定三生副本1次
		{
			id = 13,		--id，从0开始递增
			desc = Lang.Misc.m000513,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度 
			click = 1,
		},

		-- 挑战琴棋书画副本1次
		{
			id = 17,		--id，从0开始递增
			desc = Lang.Misc.m000517,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},
		
      -- 挑战四灵血阵副本1次
		{
			id = 12,		--id，从0开始递增
			desc = Lang.Misc.m000512,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度
			click = 1,
		},

      -- 挑战营救小伙伴副本1次
		{
			id = 16,		--id，从0开始递增
			desc = Lang.Misc.m000516,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度 
			click = 1,
		},

      -- 挑战血战长空副本1次
		{
			id = 14,		--id，从0开始递增
			desc = Lang.Misc.m000514,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 20,	--奖励的活跃度 
			click = 1,
		},

      -- 挑战逍遥宝库副本1次
		{
			id = 15,		--id，从0开始递增
			desc = Lang.Misc.m000515,	--活跃目标描述，用语言包,客户端用
			times = 1,	--需要达成的次数
			point = 10,	--奖励的活跃度 
			click = 1,
		},
	
		--其它目标按上面的配置
		
	},
	rewardList=
	{
		{
		  needActice = 50, --领奖需要的活跃度
		  --奖励的列表
		  awardList=          
		  {
		 	 {type = 0, id = 18221, count = 1,  bind = 1, job = -1, sex = -1, group=0},
		  },
		},
		{
		  needActice = 100, --领奖需要的活跃度
		  --奖励的列表
		  awardList=          
		  {
		  	{type = 0, id = 18633, count = 1,  bind = 1, job = -1, sex = -1, group=0},
		  },
		},
		{
		  needActice = 150, --领奖需要的活跃度
		  --奖励的列表
		  awardList=          
		  {
			  {type = 0, id = 18222, count = 1,  bind = 1, job = -1, sex = -1, group=0},
		  },
		},
		{
		  needActice = 200, --领奖需要的活跃度
		  --奖励的列表
		  awardList=          
		  {
			  {type = 0, id = 18710, count = 1,  bind = 1, job = -1, sex = -1, group=0},
			  {type = 0, id = 18292, count = 1,  bind = 1, job = -1, sex = -1, group=0},
		  },
		},
		{
		  needActice = 275, --领奖需要的活跃度
		  --奖励的列表
		  awardList=          
		  {
			  {type = 7, id = 0, count = 10,  bind = 1, job = -1, sex = -1, group=0},
			  {type = 0, id = 18602, count = 1,  bind = 1, job = -1, sex = -1, group=0},
		  },
		},						
	},
}