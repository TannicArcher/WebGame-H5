-- 世界BOSS配置测试
module("test.test_worldboss" , package.seeall)
setfenv(1, test.test_worldboss)
require("worldboss.worldbossconf")
local checkFunc = require("test.assert_func")
local WorldBossConf = WorldBossConf
local Item = Item
local test_worldboss_func = {}
--数字属性类型名称
local numAtts = {"id", "type", "monsterId", "level", "firstTime", "reliveTime", "sceneId", "x", "y", "liveTime", "teleportX", "teleportY", "tombstoneId"}
--引用属性类型名称
local refAtts = {"desc", "iconTip"}
--数字属性范围检测配置
local rangeAtts = {
	{ name = "type", range = {1, 2} }
}
--awards内的属性属性范围检测
local awardsRangeAtts = {
	{ name = "type", range = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 127} }
}

local function awardsAttCheck(k, awards)
	if awards == nil or #awards == 0 then
		Assert(false, string.format("err: id [%d] - awards can't not nil or count = 0.",k))
		return
	end
	for x,conf in pairs(awards) do
		local k = string.format("%s_%s_%s", k, x, "awards")
		checkFunc.numAttRangeCheck(k, awardsRangeAtts, conf)
		if conf.type == 0 then checkFunc.itemIdCheck(k, conf.id) end
		if conf.type == 127 then
			Assert(conf.id == nil and conf.count == nil, string.format("err: id [%d] - awards can't not nil or count = 0.",k))
		end
	end
	--其它的类型暂时不判定
end

test_worldboss_func.test_config = function( ... )
	-- 检查配置表中各项的参数
	local WorldBoss = WorldBoss
	for k,conf in pairs(WorldBoss) do
		Assert(conf ~= nil, string.format("err:key<%d> is nil",k))
		if conf then
			--检测id顺序
			Assert(tonumber(k) == tonumber(conf.id), string.format("err:key [%d] ~= id [%d]", k, conf.id))
			--print("检测数字各项基本配置")
			checkFunc.numAttCheck(k, numAtts,conf) 
			--print("检测属性设置是否在范围内")
			checkFunc.numAttRangeCheck(k, rangeAtts, conf)
			--print("检测引用的各项配置")
			checkFunc.refAttCheck(k, refAtts, conf)
			--print("检查awards配置")
			awardsAttCheck(k, conf.awards)
		end
	end
end

TEST("worlboss", "config", test_worldboss_func.test_config, false)


----