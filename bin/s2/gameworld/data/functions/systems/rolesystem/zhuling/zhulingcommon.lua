module("zhulingcommon", package.seeall)

local tZhulingAttrList = {}
for _,tb in pairs(ZhulingAttrConfig) do
	tZhulingAttrList[tb.posId] = tZhulingAttrList[tb.posId] or {}
	tZhulingAttrList[tb.posId][tb.level] = tb
end

function getZhulingAttrConfig(posId, level)
	if (tZhulingAttrList[posId]) then
		return tZhulingAttrList[posId][level]
	end
end

function getZhulingCostConfig(level)
	return ZhulingCostConfig[level]
end
