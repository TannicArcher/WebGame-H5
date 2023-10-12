module("test.test_roots" , package.seeall)
setfenv(1, test.test_roots)
--[[
	灵根系统测试
--]]

require("roots.roots")
local checkFunc = require("test.assert_func")
local common 	= require("test.test_common")

local TEST 	 			= _G.TEST
local Roots  			= Roots
local numAttCheck  		= checkFunc.numAttCheck
local refAttCheck  		= checkFunc.refAttCheck
local baseAttCheck  	= checkFunc.baseAttCheck
local numAttRangeCheck  = checkFunc.numAttRangeCheck

local maxlevel = 20	 --等级上限
local maxroot  = 8	 --灵根上限

local levelRefAtts  = {"name"}

local rootNumAtts  	= {"coin", "expr",}
local rootBaseAtts  = {"name", "attri"}

local attsNumAtts   = {"type", "value"}
local attsNumRange 	= {
						{ name = "type",  min = 0, max = 101 },
						{ name = "value", min = 1, max = 65535 },
					  }
					  
-- Comments: 检查配置表
local function test_roots_conf()
	--等级数目校验
	Assert(Roots ~= nil, "Roots is nil !") 
	Assert_eq(#Roots, maxlevel, string.format("lv is not eq %d", maxlevel) )

	for lv_k, lv in ipairs(Roots) do
		refAttCheck(lv_k, levelRefAtts, lv)
		
		--根数目校验
		local roots = lv.root
		Assert(type(roots) == "table", string.format("lv %d root is err", lv_k) )
		Assert_eq(#roots, maxroot, string.format("lv %d root is not eq %d", lv_k, maxroot) )

		for _, root in ipairs(roots) do
			numAttCheck(lv_k, rootNumAtts, root) 
			baseAttCheck(lv_k, rootBaseAtts, root)

			numAttCheck(lv_k, attsNumAtts,  root.attri) 
			numAttRangeCheck(lv_k, attsNumRange, root.attri)
		end
	end
end

TEST("roots", "test_conf", test_roots_conf)

