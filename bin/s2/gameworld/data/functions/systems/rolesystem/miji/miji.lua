module("miji", package.seeall)


--[[
MiJiData = {
    number openGrid	 已开启格子数
    table roleData {
        id[3]	3个角色的 秘籍id
    }[3]
 }
--]]

local p = Protocol

local function actor_log(actor, str)
	if not actor or not str then return end
	local aid = LActor.getActorId(actor)
	print("miji aid:" .. aid .. " log:" .. str)
end

local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then return nil end

	if var.MiJiData == nil then
		var.MiJiData = {}
	end
	return var.MiJiData
end

--functional callback
local function notifyData(actor)
	local npack = LDataPack.allocPacket(actor, p.CMD_MiJi, p.sMiJiCmd_InitData)
	if npack == nil then return end

	local data = getStaticData(actor)
	if data.roleData == nil then
		data.roleData = {}
	end

	LDataPack.writeShort(npack, data.openGrid or 0)
	for i=0,LActor.getRoleCount(actor) -1 do
		if data.roleData[i] == nil then
			data.roleData[i] = {}
		end
		if not data.roleData[i].lock then
			data.roleData[i].lock = {}	--锁的信息
		end

		local roleData = data.roleData[i]
		for j=1,data.openGrid or 0 do
			LDataPack.writeInt(npack, roleData[j] or 0)
			LDataPack.writeInt(npack, roleData.lock[j] or 0)
		end
	end
	LDataPack.flush(npack)
end

local function updateGrid(actor)
	local zsLevel = LActor.getZhuanShengLevel(actor)
	local vipLevel = LActor.getVipLevel(actor)

	local data = getStaticData(actor)
	local conf = MiJiGridConfig
	local ret = false

	for i = (data.openGrid or 0) + 1, #conf do
		if zsLevel >= conf[i].zsLevel or vipLevel >= conf[i].vipLevel then
			data.openGrid = i
			ret = true
		end
	end

	if ret then
		notifyData(actor)
	end
end

--event callback
local function onZSLevelChanged(actor)
	print("on zhuansheng level changed")
	updateGrid(actor)
end

local function onVipLevelChanged(actor)
	updateGrid(actor)
end

local function onOpenRole(actor)
	notifyData(actor)
end

local function onInit(actor)
	local data = getStaticData(actor)
	if data.openGrid == nil then
		data.openGrid = 0
		updateGrid(actor)
	end
	if data.roleData == nil then
		data.roleData = {}
	end
	--把数据带到c++?
	local conf
	for i=0, LActor.getRoleCount(actor) -1 do
		for grid = 1, data.openGrid do
			if data.roleData[i] and data.roleData[i][grid] ~= nil then
				conf = MiJiSkillConfig[data.roleData[i][grid]]
				if conf == nil then
					print("conf is nil : ::"..data.roleData[i][grid])
				else
					LActor.changeMiJi(actor, i, 0, data.roleData[i][grid], false,
						conf.p1 or 0, conf.p2 or 0, conf.p3 or 0,
						conf.power or 0)
				end
			end
		end
		LActor.refreshMiJi(actor, i)
		if data.roleData[i] then
			data.roleData[i].oldId = nil
			data.roleData[i].newIndex = nil
		end
	end
end

local function onLogin(actor)
	notifyData(actor)
	updateGrid(actor) -- 这个版本先加上,有些回档用户不升级没有触发
end

--netmsg callback
local function onLearnMiJi(actor, packet)
	print("on learn miji, actor:".. LActor.getActorId(actor))
	local roleid = LDataPack.readShort(packet)
	local id = LDataPack.readInt(packet)

	local data = getStaticData(actor)
	if data.openGrid == 0 then
		print("miji error datagrid:"..data.openGrid)
		return
	end
	if roleid >= LActor.getRoleCount(actor) then
		print("miji error roleid:"..roleid)
		return
	end

	local conf = MiJiSkillConfig
	if conf[id] == nil then
		print("miji config err id:"..id)
		return
	end

	if (not LActor.checkItemNum(actor, conf[id].item, 1, false)) then
		print("miji learn item not enough. actor:"..LActor.getActorId(actor))
		return
	end

	local mijiid = math.floor(id / 10) --要镶嵌的秘籍ID
	local mijiLevel = id % 10 --要镶嵌的秘籍等级
	local isFailure = false --替换等级大的时候就失败
	local isReplace = false  --true表示高等级秘籍替换相同类型的低级秘籍
	local replaceIndex = nil
	local index = nil
	local oldId = nil
	--角色数据
	if data.roleData[roleid] == nil then
		data.roleData[roleid] = {}
	end
	--获取格仔数据
	local learnedCount = 0
	local gridInfo = {}
	local roleData = data.roleData[roleid]
	for i = 1, data.openGrid do
		local gid = roleData[i] or 0
		local glevel = gid % 10

		--if math.floor(gid / 10) == mijiid and glevel >= mijiLevel then
		if id == gid then
			print("already learned miji:"..id.."  actor:"..LActor.getActorId(actor))
			return
		end

		--没有锁的话 相同类型的秘籍高级必定替换低级
		if (not roleData.lock or not roleData.lock[i]) 
			and math.floor(gid / 10) == mijiid and mijiLevel > glevel then
			isReplace = true
			replaceIndex = i
			break
		end

		learnedCount = learnedCount + 1
		table.insert(gridInfo, gid)
		--碰到空格仔就按现有的计算
		if gid <= 0 then
			break
		end
	end

	if isReplace and replaceIndex then
		oldId = roleData[replaceIndex] or 0
		roleData.oldId = roleData[replaceIndex] or 0
		roleData[replaceIndex] = id
		roleData.newIndex = replaceIndex
		index = replaceIndex
	else
		--累加概率
		local rateConf = MiJiGridConfig[learnedCount]
		local totalWeight = 0
		for i, v in ipairs(gridInfo) do
			local weight
			if v == 0 then
				weight = rateConf.spaceWeight[mijiLevel + 1] --替换空格的概率
			elseif v % 10 == 1 then
				weight = rateConf.advanceWeight[mijiLevel + 1] --替换高级的概率
			else
				weight = rateConf.normalWeight[mijiLevel + 1] --替换普通的概率
			end
			gridInfo[i] = weight
			totalWeight = totalWeight + weight
		end
		--根据概率计算出应该替换哪个格仔
		local r = math.random() * totalWeight
		index = #gridInfo
		for i, v in ipairs(gridInfo) do
			if r <= v then
				index = i
				break
			end
			r = r - v
		end

		--判断这个格仔里面,如果是比现在镶嵌的这个还要高级 或者已经锁了的 就失败
		oldId = roleData[index] or 0
		local oldLv = oldId % 10
		if oldLv <= mijiLevel and (not roleData.lock or not roleData.lock[index]) then
			--成功了
			roleData[index] = id
			roleData.oldId = oldId
			roleData.newIndex = index
			--LActor.changeMiJi(actor, roleid, oldId, id, true,
			--conf[id].p1 or 0, conf[id].p2 or 0, conf[id].p3 or 0,
			--conf[id].power or 0)
		else
			isFailure = true
		end
	end

	--实际扣除
	if (not LActor.consumeItem(actor, conf[id].item, 1, false, "learn miji")) then
		print("miji learn item not enough. actor:"..LActor.getActorId(actor))
		return
	end

	--回应客户端
	local npack = LDataPack.allocPacket(actor, p.CMD_MiJi, p.sMiJiCmd_UpdateMiji)
	if npack == nil then return end
	LDataPack.writeShort(npack, roleid)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, isFailure and oldId or id)
	LDataPack.writeByte(npack, isFailure and 1 or 0)
	LDataPack.flush(npack)
	
	print("learnmiji actor:"..LActor.getActorId(actor)..",id:"..id..",oldId:"..oldId..",index:"..index.. ",roleid:"..roleid..",isFailure:"..tostring(isFailure))
	--日志
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"learn miji", tostring(id), tostring(index), tostring(roleid), "learn", tostring(oldId), tostring(isFailure))
	--触发玩家事件
	if isFailure == false then
		actorevent.onEvent(actor, aeLearnMiJi, roleid, id)
	end
end

--客户端转盘结束,领取秘籍
local function onClientOkToLearnMiJi(actor, packet)
	local roleid = LDataPack.readShort(packet)
	local data = getStaticData(actor)
	if data.openGrid == 0 then
		print("onClientOkToLearnMiJi error datagrid:"..data.openGrid)
		return
	end
	if roleid >= LActor.getRoleCount(actor) then
		print("onClientOkToLearnMiJi error roleid:"..roleid)
		return
	end
	--角色数据
	if data.roleData[roleid] == nil then
		data.roleData[roleid] = {}
	end
	local roleData = data.roleData[roleid]
	if roleData.oldId == nil or roleData.newIndex == nil then
		print("onClientOkToLearnMiJi no have learn")
		return
	end
	local id = roleData[roleData.newIndex]
	local conf = MiJiSkillConfig
	if conf[id] == nil then
		print("onClientOkToLearnMiJi config err id:"..tostring(id))
		return
	end
	LActor.changeMiJi(actor, roleid, roleData.oldId, id, true,
		conf[id].p1 or 0, conf[id].p2 or 0, conf[id].p3 or 0,
		conf[id].power or 0)
	roleData.oldId = nil
	roleData.newIndex = nil
end

local function onTransformMiJi(actor, packet)
	local id1 = LDataPack.readInt(packet)
	local id2 = LDataPack.readInt(packet)
	local id3 = LDataPack.readInt(packet)

	local conf = MiJiSkillConfig
	if conf[id1] == nil or conf[id2] == nil or conf[id3] == nil then
		print("transform miji id error. aid:"..LActor.getActorId(actor))
		return
	end
	local costList = {}
	costList[conf[id1].item] = (costList[conf[id1].item] or 0) + 1
	costList[conf[id2].item] = (costList[conf[id2].item] or 0) + 1
	costList[conf[id3].item] = (costList[conf[id3].item] or 0) + 1

	local advanceMijiCount = (id1%10>0 and 1 or 0) + (id2%10>0 and 1 or 0) + (id3%10 > 0 and 1 or 0)

	local ret = true
	for itemId, itemCount in pairs(costList) do
		ret = ret and LActor.checkItemNum(actor, itemId, itemCount)
	end
	if ret == false then
		print("transform miji item not enough aid:"..LActor.getActorId(actor))
		return
	end
	for id, count in pairs(costList) do
		LActor.consumeItem(actor, id, count, false, "mijitransform")
	end

	local newmiji = drop.dropGroup(MiJiTransformConfig[advanceMijiCount].dropId)
	LActor.giveAwards(actor, newmiji, "mijitranseform")

	if newmiji and newmiji[1] then
		local mijiItem = newmiji[1].id
		local npack = LDataPack.allocPacket(actor, p.CMD_MiJi, p.sMiJiCmd_TransformMiJi)
		if npack == nil then return end
		LDataPack.writeInt(npack, mijiItem)
		LDataPack.flush(npack)

		System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
			"transform miji", tostring(mijiItem), string.format("%d:%d:%d",id1,id3,id3), "", "transform", "", "")
	end
	--print("newmiji:"..newmiji[1].id)
	--print("dropid:"..MiJiTransformConfig[advanceMijiCount].dropId)
end

--根据秘籍id找到格子位置
local function getGridById(actor, roleid, id)
	local data = getStaticData(actor)
	if data.openGrid == 0 or not data.roleData 
		or not data.roleData[roleid] or not data.roleData[roleid] then
		return 0
	end

	local roleData = data.roleData[roleid]
	for i = 1, data.openGrid do
		if roleData[i] == id then
			return i
		end
	end

	return 0
end

--发送加解锁结果
local function sendLockInfo(actor, roleid, id, result)
	local pack = LDataPack.allocPacket(actor, p.CMD_MiJi, p.sMiJiCmd_LockInfo)
	if not pack then return end

	LDataPack.writeInt(pack, roleid)
	LDataPack.writeInt(pack, id)
	LDataPack.writeInt(pack, result)

	LDataPack.flush(pack)
end

--加锁
local function lockGrid(actor, packet)
	local roleid = LDataPack.readInt(packet)
	local id = LDataPack.readInt(packet)

	local data = getStaticData(actor)
	if data.openGrid == 0 then
		actor_log(actor, "lockGrid datagrid:"..data.openGrid)
		return
	end
	if roleid >= LActor.getRoleCount(actor) then
		actor_log(actor, "lockGrid roleid:"..roleid)
		return
	end

	local grid = getGridById(actor, roleid, id)
	if not data.roleData[roleid] or not data.roleData[roleid][grid] then
		actor_log(actor, "lockGrid grid:"..roleid.." "..grid)
		return
	end

	local roleData = data.roleData[roleid]
	if not roleData.lock then
		roleData.lock = {}
	end

	if roleData.lock[grid] then
		actor_log(actor, "lockGrid has lock: "..roleid.." "..grid)
		return
	end

	if (not LActor.consumeItem(actor, MijiBaseConfig.lockId, 1, false, "lock miji")) then
		actor_log(actor, "lockGrid lock has not item")
		return
	end

	roleData.lock[grid] = 1

	sendLockInfo(actor, roleid, id, 1)
end

--解锁
local function unlockGrid(actor, packet)
	local roleid = LDataPack.readInt(packet)
	local id = LDataPack.readInt(packet)

	local data = getStaticData(actor)
	if data.openGrid == 0 then
		actor_log(actor, "unlockGrid datagrid:"..data.openGrid)
		return
	end
	if roleid >= LActor.getRoleCount(actor) then
		actor_log(actor, "unlockGrid roleid:"..roleid)
		return
	end

	local grid = getGridById(actor, roleid, id)
	if not data.roleData[roleid] or not data.roleData[roleid][grid] then
		actor_log(actor, "unlockGrid grid:"..roleid.." "..grid)
		return
	end

	local roleData = data.roleData[roleid]
	if not roleData.lock or not roleData.lock[grid] then
		actor_log(actor, "unlockGrid has not lock: "..roleid.." "..grid)
		return
	end

	roleData.lock[grid] = nil

	sendLockInfo(actor, roleid, id, 0)
end

actorevent.reg(aeInit, onInit)
actorevent.reg(aeUserLogin, onLogin)
actorevent.reg(aeUpdateVipInfo, onVipLevelChanged)
actorevent.reg(aeZhuansheng, onZSLevelChanged)
actorevent.reg(aeOpenRole, onOpenRole)

netmsgdispatcher.reg(p.CMD_MiJi, p.cMiJiCmd_LearnMiji, onLearnMiJi)
netmsgdispatcher.reg(p.CMD_MiJi, p.cMiJiCmd_LearnMijiOk, onClientOkToLearnMiJi)
netmsgdispatcher.reg(p.CMD_MiJi, p.cMiJiCmd_TransformMiJi, onTransformMiJi)
netmsgdispatcher.reg(p.CMD_MiJi, p.cMiJiCmd_Lock, lockGrid)
netmsgdispatcher.reg(p.CMD_MiJi, p.cMiJiCmd_Unlock, unlockGrid)


function gmSetMiji(actor, roleid, index, id)
	local data = getStaticData(actor)
	local roleData = data.roleData[roleid]
	local oldid = roleData[index]
	roleData[index] = id

	local conf = MiJiSkillConfig[id]
	if conf == nil then
		roleData[index] = nil
		LActor.changeMiJi(actor, roleid, oldid, id, true,
			0, 0, 0, 0)
	else
		LActor.changeMiJi(actor, roleid, oldid, id, true,
			conf.p1 or 0, conf.p2 or 0, conf.p3 or 0,
			conf.power or 0)
	end
--[[
	local npack = LDataPack.allocPacket(actor, p.CMD_MiJi, p.sMiJiCmd_UpdateMiji)
	if npack == nil then return end

	LDataPack.writeShort(npack, roleid)
	LDataPack.writeShort(npack, index)
	LDataPack.writeInt(npack, id)
	print("actor:"..LActor.getActorId(actor) .." learn miji:"..id.." index:"..index)


	LDataPack.flush(npack)
]]
end
