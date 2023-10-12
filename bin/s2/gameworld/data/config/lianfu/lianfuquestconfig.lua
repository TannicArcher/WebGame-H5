--连服任务
LianfuQuestConf = {
	openday = 5,	--开连服第xx天0点开启连服任务
	sceneId = 20,	--王城场景id
	level = 50, --等级限制
	toPosx = 78, toPosy = 48, --传送进来的位置
	xiaoyaochengId = 7, posX = 17, posY = 20,	--在王城内传送去逍遥城
	quicklyExpend = 10,	--立即完成 消耗的绑定元宝数量
	finishAllQuestId = 7030,	--完成所有的连服任务 的任务id
	tasks = 
	{
		{
			--任务id, 目标id(怪物id)，个数， 任务类型（0采集，1打怪	）
			--exp经验奖励，awards物品奖励
			questId = 1, monsterId = 342, amount = 40, type = 1,
			awards =
			{
				--type 用一般的任务奖励类型
				{type = 0, id = 18740, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 2, monsterId = 346, amount = 40, type = 0,
			awards =
			{
				{type = 0, id = 18730, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 3, monsterId = 344, amount = 40, type = 1,
			awards =
			{
				{type = 0, id = 18740, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 4, monsterId = 345, amount = 40, type = 1,
			awards =
			{
				{type = 0, id = 18730, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 5, monsterId = 339, amount = 40, type = 1,
			awards = 
			{
				{type = 0, id = 18740, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 6, monsterId = 343, amount = 40, type = 1,
			awards =
			{
				{type = 0, id = 18730, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 7, monsterId = 338, amount = 40, type = 1,
			awards =
			{
				{type = 0, id = 18740, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		
		{
			questId = 8, monsterId = 340, amount = 40, type = 1,
			awards =
			{
				{type = 0, id = 18730, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 12000, quality = 0, strong= 0, bind=1},
			},
		},
		{
			questId = 9, monsterId = 341, amount = 40, type = 1,
			awards =
			{
				{type = 0, id = 18740, count = 1, quality = 0, strong= 0, bind=1},
				{type = 2, id = 18220, count = 24000, quality = 0, strong= 0, bind=1},
			},
		},
	},
}