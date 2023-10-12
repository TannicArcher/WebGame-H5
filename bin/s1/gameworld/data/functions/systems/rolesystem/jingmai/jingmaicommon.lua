module("jingmaicommon", package.seeall)

function getLevelConfig(level)
	return JingMaiLevelConfig[level]
end

function getStageConfig(stage)
	return JingMaiStageConfig[stage]
end


function checkNeedStageUp(stage, level)
	local config = getLevelConfig(level)
	if (not config) then
		return false
	end

	local levelPerStage = JingMaiCommonConfig.levelPerStage
	if (level%levelPerStage == 0 and level ~= 0 and level/levelPerStage > stage) then
		return true
	end
	return false
end
