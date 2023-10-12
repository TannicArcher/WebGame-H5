#pragma once

//tolua_begin
//地图区域属性的定义
//完全搬战将的过来，有些未必用得到,先定义
//注意：在配置文件中，attri字段里的type对应下面的值，如aaSaft，而value根据type的值不同，会需要配置不同的值，有些是配一个整数，有些是整数列表（多个整数），有些
//有时不需要配置value
enum tagMapAreaAttribute
{
	aaNoAttri = 0,	//无意义
	aaSaft = 1,		//"世界安全区"，无参数
	aaAddBuff = 2,	//进入自动增加buff,离开后会自动删除buff,参数：[buff的个数]+N*{[buff类型][groupid][周期（秒）][次数][buff值]},
	//注：应该给区域属性的buff分配个固定的id，另外由于这里参数都是填整数类型的，buff值如果是浮点数类型的，比如0.01，就写100，即0.01的10000倍,
	//为保险起见，加的buff需要限定次数，以避免buff没正常删除的情况
	aaOfflinePratice = 3,	//推送离线修炼消息
	aaActorDenySee = 4,     //角色隐身区域, 其他玩家无法看到自己
	aaCreateMyMonster = 5,	//创建属于我的怪物, 其他玩家无法看见
	aaReloadMap = 6,//"重配地图",如果玩家在这个区域挂掉或重新上线，会转移到之前的非重配地图区域，无参数
	aaExpDouble = 7,	//"经验倍数"，，无参数，注：可能取消
	aaHorseJump = 8,	//赛马跳跃区域 参数: x1,x2,y1,y2 代表跳跃落地区域
	aaPkAddExp = 9,		//"PK胜利加经验"  [增加经验的数量],注：暂未实现
	aaPkSubLevel = 10,	//"PK失败减等级"	[等级减少的数量],注：暂未实现
	aaPkSubExp = 11,	//"PK失败减经验"	[减少的经验],注：暂未实现
	aaAutoSubHP = 12,	//"自动减HP"		[减少的HP]，注：执行的周期是1秒
	aaAutoAddHP = 13,	//"自动加HP"		[增加的HP]，注：执行的周期是1秒
	aaXiuweiRate = 14,	//"修为加成"	[加成值，整数,每20秒增加一次]
	aaCloseBuff = 15,	//关闭BUFF
	aaCampSaftRelive = 16,	//"按阵营安全复活区"		[阵营ID]
	aaDenyChangePkMode = 17,	//"禁止改变PK模式", 无参数
	aaAnswerA = 18,		//"答题答案区域A",	无参数,
	aaAnswerB = 19,		//"答题答案区域B",	无参数,
	aaNotCrossMan = 20,		//"禁止穿人",	无参数
	aaNotCrossMonster = 21,		//"禁止穿怪"，无参数
	aaDymMoveFlag = 22,		// 动态改变的行走区域 [参数1:0表示不可走，1表示可走]
	aaFish = 23,		//"禁止使用行会传送"，无参数,注：暂未实现
	aaRandRelive = 24,		//随机复活点，必须保证区域内的点都是可以行走的
	aaNotMasterTran = 25,		//"禁止使用师徒传送"，无参数,注：暂未实现
	aaRandTran = 26,		//"禁止随机传送"，无参数,注：暂未实现
	aaNoDrug = 27,			//"禁止使用药品"，无参数,注：暂未实现
	aaZyProtect = 28,			//"阵营保护区域",【被保护的阵营id】，如果有2个阵营被保护，则2个参数。
	aaNotTransfer = 29,		//"禁止定点传送"，无参数,注：暂未实现
	aaNotBeTran = 30,		//"禁止被行会传送"，无参数,注：暂未实现
	aaTriggerGuid = 31,		//"图为引导"，[图文id]
	aaNotBeMasterTran = 32,		//"禁止被师徒传送"，无参数,注：暂未实现
	aaNotSkillId = 33,		//"限制技能使用"，[技能1，技能2，技能3...],技能id
	aaNotItemId = 34,		//"限制物品使用"[物品1，物品2，物品3...]，都是指物品id
	aaNotAttri = 35,		//"限制特殊属性",注：暂未实现
	aaSceneLevel = 36,		//"进地图等级"，[等级],注：暂未实现
	aaSceneFlag = 37,		//"进地图标志"	,注：暂未实现
	aaRunNpc = 38,			//"进入触发NPC脚本",注：
	aaCity = 39,			//"城镇"，无参数,表示回城卷或者回城复活，就会回到这里
	aaNotLevelProtect = 40,			//"关闭新手保护"，无参数，现低于40级（以下）是保护状态，免受攻击，进入该区域后，这个规则失效
	aaAutoAddExp = 41,		//"自动加经验"，[经验的数量]，注：执行的周期是1秒
	aaAutoSubExp = 42,		//"自动减经验"，[经验的数量]，注：
	aaNotMount = 43,		//"限制坐骑"	，无参数，不准骑马,注：暂未实现
	aaNotHereRelive = 44,		//"禁止原地复活"，无参数,注：暂未实现
	aaNotCallMount = 45,		//"禁止召唤坐骑"，无参数,注：暂未实现
	aaSaftRelive = 46,		//"安全复活区"，即复活点，无参数,
	aaSubHPByPercent = 47,		//"按千分比减少HP"[每次减少的千分比]，注：可能取消
	aaAddHPByPercent = 48,		//"按千分比增加HP"[每次增加的千分比]，注：可能取消
	aaEndPkCanHereRelive = 49,	//"PK死亡允许原地复活"，无参数,注：暂未实现
	aaForcePkMode = 50,		//"强制攻击模式",[PK模式]，注意：只接受一个参数。0和平模式，1团队模式，2帮派模式，3阵营模式，4杀戮模式，5联盟模式
	aaNotSkillAttri = 51,		//"禁止使用任何技能属性"，无参数,注：暂未实现
	aaNotTeam = 52,			//"禁止组队"，无参数,注：暂未实现
	aaLeftTeam = 53,		//"强制离开队伍"，无参数
	aaNotAutoAddHpDrug = 54,		//"自动恢复体力类物品无效"，无参数,注：暂未实现
	aaNotAutoAddMpDrug = 55,	//"自动恢复灵力类物品无效"，无参数,注：暂未实现
	aaNotDeal = 56,			//"禁止交易"，无参数,注：暂未实现
	aaNotMeditation = 57,		//"禁止打坐"，无参数
	aaEndPkNotHereRelive = 58,	//"PK死亡后禁止原地复活"，无参数,注：暂未实现
	aaNotProtect = 59,		//"关闭保护"，无参数
	aaNotAutoBattle = 60,		//禁止自动战斗，无参数,注：暂未实现
	aaNotMatch = 61,		//禁止切磋，无参数
	aaAddRootExpByLevel = 62,			//增加灵气，参数:[灵气值][是否乘以等级]
	aaNotAddAnger = 63,	//禁止加怒气值
	aaJumpNotQg = 64,			//跳跃不消耗轻功，无参数
	aaAddExpByLevel = 65,		//根据玩家等级加经验
	aaCityRelive = 66,   //主城复活
	aaNotRelive = 67,		// 禁止复活
	aaDelBuff = 68,         //删除buff
	aaPkArea = 69,			//pk区域[PK模式],进去以后切换到一种PK模式，可以手动切换到除和平模式的以前模式
	aaNotPet = 70, //禁止召唤宠物[无参数]
	aaAttriCount,			//属性类型的数量
};
//tolua_end
