module("enhancecommon", package.seeall)

local tEnhanceAttrList = {}
for _,tb in pairs(EnhanceAttrConfig) do
	tEnhanceAttrList[tb.posId] = tEnhanceAttrList[tb.posId] or {}
	tEnhanceAttrList[tb.posId][tb.level] = tb
end

function getEnhanceAttrConfig(posId, level)
	if (tEnhanceAttrList[posId]) then
		return tEnhanceAttrList[posId][level]
	end
end

function getEnhanceCostConfig(level)
	return EnhanceCostConfig[level]
end


