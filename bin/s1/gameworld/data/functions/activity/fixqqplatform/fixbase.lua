--[[
	author  = 'Roson'
	time    = 09.22.2015
	name    = 修复基本包
	ver     = 0.1
]]

module("activity.fixqqplatform.fixbase" , package.seeall)
setfenv(1, activity.fixqqplatform.fixbase)

function getFixVar(actor)
	local var = LActor.getStaticVar(actor)
	if not var then return end
	if var.fixplat == nil then var.fixplat = {} end

	return var.fixplat
end


