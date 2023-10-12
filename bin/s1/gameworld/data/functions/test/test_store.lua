module("test.test_store" , package.seeall)
setfenv(1, test.test_store)


local checkFunc = require("test.assert_func")

local numAttCheck  		= checkFunc.numAttCheck
local refAttCheck  		= checkFunc.refAttCheck
local baseAttCheck  	= checkFunc.baseAttCheck
local numAttRangeCheck  = checkFunc.numAttRangeCheck

local RefreshStore = RefreshStore

local itemKey = {"id", "sex", "count", "weekDay", "openServerDay"}

--检查配置表
function test_store_config(actor)
	Assert(RefreshStore ~= nil, "RefreshStore is nil !") 
	local config = RefreshStore[1]
	local items = RefreshStore[1].items
	Assert(items ~= nil, "items is nil !")
	Assert(type(items) == "table", "items is not table")
	for _, item in ipairs(items) do 
		baseAttCheck(item.id,itemKey, item)
	end
	
end

TEST("store", "config", test_store_config)
