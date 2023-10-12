module("guildactivity", package.seeall)

function getStartandEnd(id)
	local activity = guildActivityConfig[id]
	if not activity then return end


	local year, month, day = System.getDate()
	local startTime = System.timeEncode(year, month, day, activity.startTime.h, activity.startTime.m, activity.startTime.s)
	local endTime   = System.timeEncode(year, month, day, activity.endTime.h,   activity.endTime.m,   activity.endTime.s)
	return startTime, endTime
end

function getOpenDay(id)
	local activity = guildActivityConfig[id]
	if not activity then return 0 end

	local openDay = activity.openDay or 0
	return openDay
end
