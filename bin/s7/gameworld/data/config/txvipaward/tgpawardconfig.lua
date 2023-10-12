--腾讯各种特权
TxCommAwardConfig = 
{
--[[
	--物品奖励类型
	qatItem = 0,           		//物品或者装备
    qatRootExp = 1,	            //灵气
    qatExp = 2,                	//角色经验值
    qatBindMoney = 5,           //绑定银两
    qatMoney = 6,	            //银两
    qatBindYuanBao = 7,	          //绑定元宝
    qatYuanbao = 15,			// 元宝
												]]
	--TGP特权
	{
		awardIndx = 1,

		--专属
		vipOnlyItem = 
		{
			needBag = 1,  --需要背包格子数，必须填对
			items = 
			{
				{type = qatItem, param =30121, num = 1, quality = 0, strong= 0, bind=1},
			},
		},

		--新手
		freshOnlyItem = 
		{
			needBag = 2,
			items = 
			{
				{type = qatItem, param =18223, num = 5, quality = 0, strong= 0, bind=1},
				{type = qatItem, param =18220, num = 5, quality = 0, strong= 0, bind=1},
				{type = qatBindMoney, param =0, num = 40000, quality = 0, strong= 0, bind=1},
				{type = qatRootExp, param =0, num = 80000, quality = 0, strong= 0, bind=1},
			},
		},

		--每日礼包
		dayItem =
		{
			needBag = 4,
			items = 
			{
				{type = qatItem, param =18613, num = 1, quality = 0, strong= 0, bind=1},
				{type = qatItem, param =18633, num = 1, quality = 0, strong= 0, bind=1},
				{type = qatItem, param =18221, num = 2, quality = 0, strong= 0, bind=1},
				{type = qatItem, param =18710, num = 1, quality = 0, strong= 0, bind=1},
			},
		},

		--等级礼包
		levelItem = 
		{
			{
				val = 30, --等级
				needBag = 3,
				items = 
				{
					{type = qatItem, param =18710, num = 4, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18227, num = 5, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =19300, num = 2, quality = 0, strong= 0, bind=1},
					{type = qatBindMoney, param =0, num = 20000, quality = 0, strong= 0, bind=1},
				},
			},
			{
				val = 40, --等级
				needBag = 3,
				items = 
				{
					{type = qatItem, param =18710, num = 6, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18227, num = 7, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18221, num = 4, quality = 0, strong= 0, bind=1},
					{type = qatBindMoney, param =0, num = 30000, quality = 0, strong= 0, bind=1},
				},
			},
			{
				val = 50, --等级
				needBag = 4,
				items = 
				{
					{type = qatItem, param =18602, num = 4, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18220, num = 2, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18637, num = 2, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18227, num = 10, quality = 0, strong= 0, bind=1},
				},
			},
			{
				val = 60, --等级
				needBag = 4,
				items = 
				{
					{type = qatItem, param =18602, num = 5, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =22048, num = 1, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18637, num = 3, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18227, num = 15, quality = 0, strong= 0, bind=1},
				},
			},
			{
				val = 70, --等级
				needBag = 3,
				items = 
				{
					{type = qatItem, param =18201, num = 3, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18221, num = 5, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18220, num = 5, quality = 0, strong= 0, bind=1},
					{type = qatBindMoney, param =0, num = 100000, quality = 0, strong= 0, bind=1},
				},
			},
			{
				val = 80, --等级
				needBag = 3,
				items = 
				{
					{type = qatItem, param =18201, num = 5, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18633, num = 5, quality = 0, strong= 0, bind=1},
					{type = qatItem, param =18223, num = 3, quality = 0, strong= 0, bind=1},
					{type = qatBindMoney, param =0, num = 200000, quality = 0, strong= 0, bind=1},
				},
			},						
		},
	},
}
