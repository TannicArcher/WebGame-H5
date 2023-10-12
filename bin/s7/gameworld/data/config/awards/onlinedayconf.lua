--奖励配置表
--当前开奖励需求不大的时候把这个模块独立出来可便于扩展
--奖励行为将会是个量非常大的需求 开物品不仅开金钱物品 还可能开出其它点数奖励
--从扩展性和可维护性的角度看 有必要把这个配置独立出来
--rewardtype	奖励类型 1 物品 2 金钱 ... 其余可自定义
--[[
	 --奖励类型--
	//物品或者装备	rewardtype: 1
	//修为	rewardtype: 5
	//角色经验值	rewardtype: 6
	//帮派贡献值	rewardtype: 3
	//阵营贡献	rewardtype: 4
	//绑定银两 rewardtype: 2
	//银两	rewardtype: 2
	//绑定元宝	rewardtype: 2
	//称谓	rewardtype: 8	itemid: 称号ID
	//技能	rewardtype: 9	itemid：技能ID  amount：技能等级
	//战魂	rewardtype: 10
	//成就点	rewardtype: 11
	//声望	rewardtype: 12
--]]
--type		奖励内容的类型  目前只用作金钱类型
--amount	奖励数量 物品数量  或者  金额
--itemid	奖励的物品数量  如果奖励monster的话还可以用作monster id
--奖励ID	目前对应NormalItemDatas的PresentItems的rewardsID 可扩展为机动配置索引
OnlineDayConf = {
	{
		id = 1,				--序号
		timeOffset = 60,	--单位是秒
		awards =
		{
			{
				level = 30,	--领取该奖励的最低等级
				--相关的奖励配置
				awards =
				{
					{rewardtype = qatBindMoney, type = 0, amount = 20000, itemid = 0, quality=0, strong=0, bind=1},
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18227, quality=0, strong=0, bind=1},
				}
			},
			--{
				--level = 60,	--领取该奖励的最低等级
				--相关的奖励配置
				--awards =
				--{
				--	{rewardtype = qatBindMoney, type = 0, amount = 10000, itemid = 0, quality=0, strong=0, bind=1},
				--}
			--},
		}
	},
	{
		id = 2,				--序号
		timeOffset = 240,	--单位是秒
		awards =
		{
			{
				level = 30,
				--相关的奖励配置
				awards =
				{
					{rewardtype = qatBindMoney, type = 0, amount = 20000, itemid = 0, quality=0, strong=0, bind=1},
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18220, quality=0, strong=0, bind=1},
				}
			},
		}
	},
	{
		id = 3,				--序号
		timeOffset = 300,	--单位是秒
		awards =
		{
			{
				level = 30,
				--相关的奖励配置
				awards =
				{
					{rewardtype = qatBindMoney, type = 0, amount = 20000, itemid = 0, quality=0, strong=0, bind=1},
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18221, quality=0, strong=0, bind=1},
				}
			},
		}
	},
	{
		id = 4,				--序号
		timeOffset = 600,	--单位是秒
		awards =
		{
			{
				level = 30,
				--相关的奖励配置
				awards =
				{
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18633, quality=0, strong=0, bind=1},
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18222, quality=0, strong=0, bind=1},
				}
			},
		}
	},
	{
		id = 5,				--序号
		timeOffset = 2400,	--单位是秒
		awards =
		{
			{
				level = 30,
				--相关的奖励配置
				awards =
				{
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18613, quality=0, strong=0, bind=1},
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18222, quality=0, strong=0, bind=1},
				}
			},
		}
	},
	{
		id = 6,				--序号
		timeOffset = 3600,	--单位是秒
		awards =
		{
			{
				level = 30,
				--相关的奖励配置
				awards =
				{
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18614, quality=0, strong=0, bind=1},
					{rewardtype = qatItem, type = 0, amount = 1, itemid = 18710, quality=0, strong=0, bind=1},
				}
			},
		}
	},
}