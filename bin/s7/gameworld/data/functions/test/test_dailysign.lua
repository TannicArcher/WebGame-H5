module("test.test_dailysign" , package.seeall)
setfenv(1, test.test_dailysign)
--[[
	每日签到测试
--]]

require("dailysign.dailysign")
local checkFunc = require("test.assert_func")
local common 	= require("test.test_common")

local TEST 	 			= _G.TEST
local DailySign  		= DailySign
local numAttCheck  		= checkFunc.numAttCheck
local refAttCheck  		= checkFunc.refAttCheck
local baseAttCheck  	= checkFunc.baseAttCheck
local itemIdCheck 		= checkFunc.itemIdCheck
local numAttRangeCheck  = checkFunc.numAttRangeCheck

local dsNumAtts  = {"needactivity"}
local dsBaseAtts = {
					 "rewards_options",  "daily_nor_reward",
					 "daily_vip_reward", "gift_pet_reward"
				   }

local optNumAtts   = {"condition"}
local wardChkAtts  = {"reward"}
local wardNumAtts  = {"type", "id", "count"}

-- Comments: 检查配置表
local function test_dailysign_conf()
	Assert(DailySign ~= nil, "DailySign is nil !") 
	Assert(type(DailySign) == "table", string.format("DailySign is err table") )
	
	--基本配置检查
	numAttCheck(0, dsNumAtts, DailySign) 
	baseAttCheck(0, dsBaseAtts, DailySign)

	local opt = DailySign.rewards_options
	for opt_i, opt_v in ipairs(opt) do
		numAttCheck(opt_i,  optNumAtts,  opt_v) 
		baseAttCheck(opt_i, wardChkAtts, opt_v)
		if opt_v.reward then 
			--奖励的物品检查
			numAttCheck(opt_i,  wardNumAtts, opt_v.reward)
			if opt_v.reward.type == 0 then
				itemIdCheck(opt_i, opt_v.reward.id)
			end
		end
	end

	--宠物礼包奖励
	local gift_pet = DailySign.gift_pet_reward
	numAttCheck(0, optNumAtts, gift_pet)
	baseAttCheck(0, wardChkAtts, gift_pet)
	if gift_pet.reward then
		numAttCheck(0, wardNumAtts, gift_pet.reward) 
	end

	--普通玩家每日签到奖励
	local nor = DailySign.daily_nor_reward
	baseAttCheck(0, wardChkAtts, nor)
	if nor.reward then
		numAttCheck(0, wardNumAtts, nor.reward)
	end

	--VIP玩家每日签到奖励
	local vip = DailySign.daily_vip_reward
	baseAttCheck(0, wardChkAtts, vip)
	if vip.reward then
		numAttCheck(0, wardNumAtts, vip.reward)
	end
end

TEST("dailysign", "test_conf", test_dailysign_conf)
