--[[
	author = 'Roson'
	time   = 05.07.2015
	name   = 事件触发助手
	ver    = 0.1
]]

module("systems.lianfu.lianfuex", package.seeall)
setfenv(1, systems.lianfu.lianfuex)

local lianfumanager = require("systems.lianfu.lianfumanager")

table.insert(InitFnTable, lianfumanager.onRunOnlineFunc)

