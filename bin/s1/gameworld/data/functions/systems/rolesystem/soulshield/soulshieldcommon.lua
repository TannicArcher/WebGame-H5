module("soulshieldcommon", package.seeall)
--local starPerLevel = 10

function getOpenLv(type)
	if type == ssLoongSoul then
		return LoongSoulBaseConfig.openlv
	end
	return 0
end

function getLevelConfig(type, level)
	if (type == ssLoongSoul) then
		return LoongSoulConfig[level]
	elseif(type == ssShield) then
		return ShieldConfig[level]
	elseif(type == ssXueyu) then
		return XueyuConfig[level]
	end

	return nil
end

function getStageConfig(type, stage)
	
	if (type == ssLoongSoul) then
		return LoongSoulStageConfig[stage]
	elseif(type == ssShield) then
		return ShieldStageConfig[stage]
	elseif(type == ssXueyu) then
		return XueyuStageConfig[stage]
	end
	return nil
end




function isMaxlvel(type,level)
	local conf = nil
	if (type == ssLoongSoul) then
		conf = LoongSoulConfig
	elseif(type == ssShield) then
		conf = ShieldConfig
	elseif(type == ssXueyu) then
		conf = XueyuConfig
	end

	if conf then
		if (level >= #conf) then return true end
	end
	return false
end



function checkNeedStageUp(type,level,stage)
	local starConfig = getLevelConfig(type,level)
	if (not starConfig) then
		return false
	end

	local stageConfig = getStageConfig(type,stage+1)
	if (not stageConfig) then
		return false
	end

	local starPerLevel = 10--soulshieldcommon.starPerLevel
	if (level%starPerLevel == 0 and level/starPerLevel > stage) then
		return true
	end
	return false
end

