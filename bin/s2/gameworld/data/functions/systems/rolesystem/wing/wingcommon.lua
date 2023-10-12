--处理一些仅需要配置就能完成的操作
module("wingcommon", package.seeall)

function getWingLevelConfig(level)
	return WingLevelConfig[level]
end

function getWingStarConfig(star)
	return WingStarConfig[star]
end

function getExpTimes(trainType, level)
	local config = getWingLevelConfig(level)
	if (not config) then
		return 1
	end

	local timesConfig = {}
	--if (trainType == normalType) then
	--	timesConfig = config.normalRate
	--else
		timesConfig = config.specialRate
	--end
	local totalRate = 0
	for _,tb in ipairs(timesConfig) do 
		totalRate = totalRate + tb.rate
	end
	if totalRate == 0 then
		return 0
	end
	local nCurRate = math.random(1,totalRate)
	local nRate = 0
	for _,tb in ipairs(timesConfig) do
		nRate = nRate + tb.rate
		if (nRate >= nCurRate) then
			return tb.times
		end
	end
	return 0
end

--[[
function checkNeedLevelUp(level, star)
	local starConfig = getWingStarConfig(star)
	if (not starConfig) then
		return false
	end

	local starPerLevel = WingCommonConfig.starPerLevel
	if (star%starPerLevel == 0 and star ~= 0 and star/starPerLevel > level) then
		return true
	end
	return false
end
]]

function isMaxLv(star)
	if (star >= #WingLevelConfig) then
		return true
	end
	return false
end
