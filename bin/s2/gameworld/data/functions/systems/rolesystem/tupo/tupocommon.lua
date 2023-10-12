module("tupocommon", package.seeall)

local tTupoAttrList = {}
for _,tb in pairs(TupoAttrConfig) do
	tTupoAttrList[tb.posId] = tTupoAttrList[tb.posId] or {}
	tTupoAttrList[tb.posId][tb.level] = tb
end

function getTupoAttrConfig(posId, level)
	if (tTupoAttrList[posId]) then
		return tTupoAttrList[posId][level]
	end
end

function getTupoCostConfig(level)
	return TupoCostConfig[level]
end
