--[[
	author = 'Roson'
	time   = 11.04.2014
	name   = 多倍挂机系统
	ver    = 0.1
]]
module("systems.superexptime.superexptimesys" , package.seeall)
setfenv(1, systems.superexptime.superexptimesys)

sbase     = require("systems.superexptime.sbase")
mainevent = require("systems.superexptime.mainevent")
expmonmgr = require("systems.superexptime.expmonmgr")
hangupmgr = require("systems.superexptime.hangupmgr")
combo     = require("systems.superexptime.combo")
loot      = require("systems.superexptime.loot")

