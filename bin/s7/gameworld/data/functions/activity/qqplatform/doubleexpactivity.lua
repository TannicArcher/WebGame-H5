module("activity.qqplatform.doubleexpactivity", package.seeall)
setfenv(1, activity.qqplatform.doubleexpactivity)

require("activity.operationsconf")
local operations = require("systems.activity.operations")

local subActId = SubActConf.DOUBLE_EXP

local ActivityConfig = operations.getSubActivitys(subActId)

function getActivityExpRate()
	local rate = 0
	for actId, conf in pairs(ActivityConfig) do
		if operations.isInTime(actId) then
			rate = rate + conf.config.rate
		end
	end
	return rate
end
