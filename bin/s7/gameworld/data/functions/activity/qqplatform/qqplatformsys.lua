--[[
	author  = 'Roson'
	time    = 09.23.2015
	name    = 运营活动系统
	ver     = 0.1
]]

module("activity.qqplatform.qqplatformsys" , package.seeall)
setfenv(1, activity.qqplatform.qqplatformsys)

require("activity.qqplatform.smashingeggs")
require("activity.qqplatform.rechargebase")
require("activity.qqplatform.ljczbase")
require("activity.qqplatform.onlinebase")
require("activity.qqplatform.qudongrensheng")
require("activity.qqplatform.rabbit")
require("activity.qqplatform.liveness")
require("activity.qqplatform.limitbuy")
require("activity.qqplatform.xyybbase")
require("activity.qqplatform.exchangeitems")
require("activity.qqplatform.loginaward")
require("activity.qqplatform.huangcheng")
require("activity.qqplatform.anheiactor")
require("activity.qqplatform.anheiserver")
require("activity.qqplatform.leijixiaofei")
require("activity.qqplatform.girlservice")
require("activity.qqplatform.turntable")
require("activity.qqplatform.cangbaoge")

---------------FIX-----------------
require("activity.fixqqplatform.fixqqplatformsys")

