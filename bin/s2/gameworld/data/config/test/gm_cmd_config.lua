-- 用于自定义gm命令
GmCmdConfig =
{

	-- 示范例子。对于参数比较多的gm命令，一般都记不住参数列表，比如要make一个绑定的物品，需要这样：
	-- make 物品名字 1 0 1 其中第四个参数才是绑定，1表示绑定0是非帮（默认0），这样会比较麻烦
	-- 所以可以自定义一个gm命令比如t_makebinditem, 其就是执行@make命令，并且默认绑定的参数是1，如下：
	-- 使用时只需要 @t_makebinditem 大刀
	-- 注意：{1} 表示@t_makebinditem 大刀 中的第一个参数（即：大刀）
	t_makebinditem =
	{
		"@make {1} 1 0 1",
	},
	-- 同理，如果输入gm命令 @t_makebinditem1 大刀 99 这相当于执行 @make 大刀 99 0 1
	-- {1} {2} 分别被替换成 大刀 和 99
	t_makebinditem1 =
	{
		"@make {1} {2} 0 1",
	},

	t_gaofushuai =
	{
		"@addmoney 0 8888888",
		"@addmoney 1 8888888",
		"@addmoney 2 8888888",
		"@addmoney 3 8888888",
	},
	t_xiaoqiang =
	{
		"@intpro 13 10000000",
		"@intpro 18 10000000",
		"@intpro 10 10000000",
	},
	t_superman =
	{
		"@intpro 12 10000000",
		"@intpro 13 10000000",
		"@intpro 17 10000000",
		"@intpro 18 10000000",
		"@intpro 10 10000000",
		"@intpro 11 10000000",
		"@intpro 9 100",
		"@superman"
	},
	t_superman2 =
	{
		-- "@intpro 12 10000000",
		-- "@intpro 13 10000000",
		-- "@intpro 17 10000000",
		"@intpro 18 10000000",
		"@intpro 10 10000000",
		"@intpro 11 10000000",
		"@superman"
	},
	t_opensysall =
	{
		"@opensys 0",
		"@opensys 1",
		"@opensys 2",
		"@opensys 3",
		"@opensys 4",
		"@opensys 5",
		"@opensys 6",
		"@opensys 7",
		"@opensys 8",
		"@opensys 9",
		"@opensys 10",
		"@opensys 11",
		"@opensys 12",
		"@opensys 13",
		"@opensys 14",
		"@opensys 15",
		"@opensys 16",
		"@opensys 17",
		"@opensys 18",
		"@opensys 19",
		"@opensys 20",
		"@level 40",
	},
	t_chenjian =
	{
		"@additem 11401 1",
		"@level 80",
		"@shengwang 123456789",
		"@addmoney 1 123456798",
		"@yb 12345678",
		"@move 逍遥城",
 	},

	t_setlockpro =
	{

	},

	t_bs =
	{
		"@make 10级生命宝石 10",
		"@make 10级攻击宝石 10",
		"@make 10级物防宝石 10",
		"@make 10级法防宝石 10",
	},

	t_tuzhi =
	{
		"@make 武器升级图纸",
		"@make 项链升级图纸",
		"@make 护腕升级图纸",
		"@make 饰品升级图纸",
		"@make 戒指升级图纸",
		"@make 帽子升级图纸",
		"@make 衣服升级图纸",
		"@make 腰带升级图纸",
		"@make 裤子升级图纸",
		"@make 鞋子升级图纸",
		"@make 装备铭刻石 10",
	},

	t_xilian =
	{
		"@make 洗炼石 99",
	},

	t_zw =
	{
		"@make 紫微极玉 100",
	},

	setbianniubi = 
	{
		"@addgold 100000000",
		"@setlevel 100",
		"@addyuanbao 10000000",
		"@addrecharge 100000000",
		"@addsoul 1000000",
		"@trainaddexp 10000000",
		"@addzhuanshengexp 100000000",
		"@addtrain 100000000",
		"@setattr 4 1000000000",
		"@setattr 2 1000000000",
		"@chapter2 1000",
	},
}