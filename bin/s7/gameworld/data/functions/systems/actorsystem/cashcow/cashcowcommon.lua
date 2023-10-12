module("cashcowcommon", package.seeall)


function getLimitConfig(vipLv)
	return CashCowLimitConfig[vipLv]
end

function getMaxBasicConfig()
	return #CashCowBasicConfig
end

function getBasicConfig(time)
	return CashCowBasicConfig[time]
end

function getAmplitudeConfig()
	return CashCowAmplitudeConfig
end

function getBoxConfig()
	return CashCowBoxConfig
end

