module("traincommon", package.seeall)

function getLevelConfig(level)
	return TrainLevelConfig[level]
end

function getStageConfig(stage)
	return TrainStageConfig[stage]
end
