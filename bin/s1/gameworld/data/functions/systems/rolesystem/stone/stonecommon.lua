module("stonecommon", package.seeall)

local posLevelConfig = {}
for _,tb in pairs(StoneLevelConfig) do
	posLevelConfig[tb.posId] = posLevelConfig[tb.posId] or {}
	posLevelConfig[tb.posId][tb.level] = tb
end

function getPosLevelConfig(pos, level)
	if (not posLevelConfig[pos]) then return end

	return posLevelConfig[pos][level]
end

function getLevelCostConfig(level)
	return StoneLevelCostConfig[level]
end
