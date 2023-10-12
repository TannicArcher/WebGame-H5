module("caikuangscene", package.seeall)

--[[
保存在系统的信息
	{
	 sceneId  场景索引
	 fubenHdl 副本handle
	 	sceneData = {
			pos   位置
			actorId  玩家id
			name     玩家名字
			kuangId  矿id
			startTime 矿开始时间
			endTime   矿结束时间
			power     战斗力
			guildName 公会名
			attackerList = {
				actorid  攻击者
			}
	 	}
	}

	beAttackList
	{
		actorId  正在被攻击的玩家
	}
-- ]]

--场景索引跟房间号不是同一回事，房间号指的是key值

local systemId = Protocol.CMD_Kuang
local BaseConf = CaiKuangConfig
local kuangLevelConf = KuangYuanConfig

--采矿事件
local caikuangEvent = {
	attackStatus = 1,  -- 攻击状态
	finish = 2,     -- 矿采完了
	add = 3,       --新增矿
	SceneIndexChange = 4, --场景索引变化
	addAttacker = 5,      --新增掠夺者
	updateInfo = 6,   --更新玩家信息
}


local allscene = nil

local function getSystemVarData()
	local var = System.getStaticVar()
	if nil == var.caikuang then var.caikuang = {} end
	return var.caikuang
end

--获取玩家矿所在的场景handle和场景索引和矿位置
local function getKuangFubenHdl(actor)
	local actorId = LActor.getActorId(actor)

	for i= 1, #allscene do
		local data = allscene[i]
		for k=1, #(data.sceneData or {}) do
			local info = data.sceneData[k]
			if actorId == info.actorId then return data.fubenHdl, data.sceneId, k end
		end
	end

	return 0, 0, 0
end

--根据场景索引获取场景信息
local function getSceneInfo(sceneId)
	for i=1, #allscene do
		if sceneId == allscene[i].sceneId then return i, allscene[i] end
	end

	return 0, nil
end

--检测要掠夺的玩家是否正在被攻击
local function checkIsAttacked(tactorId)
	for k, id in pairs(allscene.beAttackList or {}) do
		if id == tactorId then return true end
	end

	return false
end

--场景事件广播
local function sceneBroadcast(var, eventId, pos, args)
	if not var then return end
	local npack = LDataPack.allocBroadcastPacket(systemId, Protocol.sKuang_UpdateSceneData)
	LDataPack.writeShort(npack, pos)
	LDataPack.writeShort(npack, eventId)

	if caikuangEvent.attackStatus == eventId then  --攻击状态变化公告
		LDataPack.writeByte(npack, unpack(args) and 1 or 0)
	elseif caikuangEvent.add == eventId then  --新增矿通告
		local info = var.sceneData[pos]
		if info then
			if not info.endTime then
				info.endTime = (info.startTime + kuangLevelConf[info.kuangId].needTime)
			end

			LDataPack.writeByte(npack, info.pos)
			LDataPack.writeInt(npack, info.actorId)
			LDataPack.writeString(npack, info.name)
			LDataPack.writeInt(npack, info.power)
			LDataPack.writeString(npack, info.guildName)
			LDataPack.writeByte(npack, info.kuangId)
			LDataPack.writeInt(npack, info.startTime)
			LDataPack.writeInt(npack, info.endTime)
			LDataPack.writeByte(npack, 0)
			LDataPack.writeByte(npack, 0)
		end
	elseif caikuangEvent.SceneIndexChange == eventId then  --场景索引变化通告
		LDataPack.writeShort(npack, pos)
		LDataPack.writeShort(npack, allscene[pos-1] and pos-1 or 0)
		LDataPack.writeShort(npack, allscene[pos+1] and pos+1 or 0)
	elseif caikuangEvent.addAttacker == eventId then  --新增掠夺者通告
		LDataPack.writeInt(npack, unpack(args))
	elseif caikuangEvent.updateInfo == eventId then  --玩家信息更新
		local info = var.sceneData[pos]
		if info then
			if not info.endTime then
				info.endTime = (info.startTime + kuangLevelConf[info.kuangId].needTime)
			end

			LDataPack.writeByte(npack, info.pos)
			LDataPack.writeInt(npack, info.actorId)
			LDataPack.writeString(npack, info.name)
			LDataPack.writeInt(npack, info.power)
			LDataPack.writeString(npack, info.guildName)
			LDataPack.writeByte(npack, info.kuangId)
			LDataPack.writeInt(npack, info.startTime)
			LDataPack.writeInt(npack, info.endTime)
			LDataPack.writeByte(npack, checkIsAttacked(info.actorId) and 1 or 0)

			LDataPack.writeByte(npack, #(info.attackerList or {}))
	    	for k=1, #(info.attackerList or {}) do LDataPack.writeInt(npack, info.attackerList[k]) end
	    end
	end

	Fuben.sendData(var.fubenHdl, npack)
end

--增加正在被攻击的玩家
local function addBeAttacker(tactorId)
	if nil == allscene.beAttackList then allscene.beAttackList = {} end

	for k, id in pairs(allscene.beAttackList or {}) do
		if id == tactorId then return end
	end

	table.insert(allscene.beAttackList, tactorId)
end

--移除正在被攻击的玩家
function removeBeAttacker(tactorId)
	for k, id in pairs(allscene.beAttackList or {}) do
		if id == tactorId then table.remove(allscene.beAttackList or {}, k) end
	end
end

--获取场景索引号
local function initSceneId()
	local list = {}
	for i= 1, #(allscene or {}) do table.insert(list, allscene[i].sceneId) end

	if nil == next(list) then return 1 end

	table.sort(list)

	--这种遍历效率较低，但实际情况下没问题，除非同时有几百个房间，但这种情况游戏就发大财了
	for i=1, list[#list] do
		local isFind = false
		for k, v in pairs(list) do
			if v == i then isFind = true break end
		end

		if not isFind then return i end
	end

	return #list+1
end

--创建新副本
local function createNewScene()
	local fbHdl = Fuben.createFuBen(BaseConf.fubenId)
	if 0 == fbHdl then print("caikuangscene.createNewScene:fbHdl is 0") return 0 end
	local id = #allscene+1

	allscene[id] = {}
	allscene[id].fubenHdl = fbHdl
	allscene[id].sceneId = initSceneId()

	local ins = instancesystem.getInsByHdl(fbHdl)
	if ins then ins.data.sceneId = allscene[id].sceneId end

	print("caikuangscene.createNewScene:create a new room, id:"..tostring(id)..", sceneId:"..tostring(ins.data.sceneId))

	--通知
	sceneBroadcast(allscene[id-1], caikuangEvent.SceneIndexChange, id-1)

	return fbHdl
end

--获取矿数没满的场景handle
local function getVaildFubenHdl()
	for i= 1, (#allscene or {}) do
		local data = allscene[i]
		local count = 0
		for k=1, #(data.sceneData or {}) do
			local info = data.sceneData[k]
			if 0 ~= info.actorId and not caikuangsystem.kuangIsFinish(info.kuangId or 0, info.endTime or 0) then
				count = count + 1
			end
		end

		if BaseConf.maxKuangCount > count then return data.fubenHdl end
	end

	return 0
end

--获取可以进入的副本handle
function getValidFubenHandle(actor, isFinish)
	local hdl = 0

	--矿没结束就进入所在场景
	if not isFinish then hdl = getKuangFubenHdl(actor) end

	--还有没有多余位置
	if 0 == hdl then hdl = getVaildFubenHdl() end

	--第一个进入的需要创建新房间
	if 0 == hdl then hdl = createNewScene() end

	return hdl
end

function sendSceneInfo(actor, sceneId)
    local npack = LDataPack.allocPacket(actor, systemId, Protocol.sKuang_SceneData)

    local id, data = getSceneInfo(sceneId)

    LDataPack.writeShort(npack, id)
    LDataPack.writeShort(npack, allscene[id-1] and id-1 or 0)
    LDataPack.writeShort(npack, allscene[id+1] and id+1 or 0)

    --先保存当前位置，后面再插入数据
	local oldPos = LDataPack.getPosition(npack)
	LDataPack.writeShort(npack, 0)

    local count = 0
    if data then
    	for i=1, #(data.sceneData or {}) do
    		local info = data.sceneData[i]
    		local isFinish = caikuangsystem.kuangIsFinish(info.kuangId, info.endTime)
    		if info and 0 ~= info.actorId and not isFinish then
    			if not info.endTime then
					info.endTime = (info.startTime + kuangLevelConf[info.kuangId].needTime)
				end
    			LDataPack.writeByte(npack, info.pos)
    			LDataPack.writeInt(npack, info.actorId)
    			LDataPack.writeString(npack, info.name)
    			LDataPack.writeInt(npack, info.power)
    			LDataPack.writeString(npack, info.guildName)
    			LDataPack.writeByte(npack, info.kuangId)
    			LDataPack.writeInt(npack, info.startTime)
    			LDataPack.writeInt(npack, info.endTime)
    			LDataPack.writeByte(npack, checkIsAttacked(info.actorId) and 1 or 0)

    			LDataPack.writeByte(npack, #info.attackerList)
    			for k=1, #info.attackerList do LDataPack.writeInt(npack, info.attackerList[k]) end

    			count = count + 1
    		end
    	end
    end

    local newPos = LDataPack.getPosition(npack)

    --往前面插入数据
	LDataPack.setPosition(npack, oldPos)
	LDataPack.writeShort(npack, count)
	LDataPack.setPosition(npack, newPos)

    LDataPack.flush(npack)
end

--获得场景内的矿数目
function getKuangCount(sceneId)
	local id, data = getSceneInfo(sceneId)

	local count = 0
	if data then
		for i=1, #(data.sceneData or {}) do
			local info = data.sceneData[i]
			local isFinish = caikuangsystem.kuangIsFinish(info.kuangId, info.endTime)
			if not isFinish then count = count + 1 end
		end
	end

	return count
end

--清空矿信息
local function clearKuangInfo(data)
	data.actorId = 0
	data.name = ""
	data.kuangId = 0
	data.startTime = 0
	data.endTime = 0
	data.pos = 0
	data.power = 0
	data.guildName = ""
	data.attackerList = {}
end

--初始化矿信息
local function setKuangInfo(actor, var, scenedata, pos)
	local actorId = LActor.getActorId(actor)
	scenedata.actorId = actorId
	scenedata.name = LActor.getActorName(actorId)
	scenedata.kuangId = var.kuangId
	scenedata.startTime = var.startTime
	scenedata.endTime = var.endTime
	scenedata.pos = pos
	scenedata.power = LActor.getActorPower(actorId)
	scenedata.guildName = ""
	scenedata.attackerList = {}

	local guild = LActor.getGuildPtr(actor)
	if not guild then return end

	scenedata.guildName = LGuild.getGuildName(guild)
end

--更新矿信息
function updateKuangInfo(actor, var)
	local hdl, sceneId, pos = getKuangFubenHdl(actor)
	if 0 == hdl then return end

	local info = getActorKuangInfo(LActor.getActorId(actor), sceneId)
	if not info then return end

	local actorId = LActor.getActorId(actor)

	--战力更新
	info.power = LActor.getActorPower(actorId)

	--广播
	local id, data = getSceneInfo(sceneId)
	sceneBroadcast(data, caikuangEvent.updateInfo, pos)
end

--获取玩家矿信息
function getActorKuangInfo(actorId, sceneId)
	local id, data = getSceneInfo(sceneId)
	if not data then return nil end

	for i=1, #(data.sceneData or {}) do
		local info = data.sceneData[i]
		if info.actorId == actorId then return info end
	end

	return nil
end

--增加一个矿
function addKuang(actor, var)
	local id, data = getSceneInfo(var.sceneId)
	if nil == data.sceneData then data.sceneData = {} end
	local info = data.sceneData
	local pos = 0

	for i=1, #(info or {}) do
		local isFinish = caikuangsystem.kuangIsFinish(info[i].kuangId, info[i].endTime)
		if isFinish then
			pos = i
			break
		end
	end

	if 0 == pos then
		pos = #info+1
		info[pos] = {}
	end

	setKuangInfo(actor, var, info[pos], pos)

	--广播
	sceneBroadcast(data, caikuangEvent.add, pos)

	--所有房间的矿都满了就KF
	if 0 == getVaildFubenHdl() then createNewScene() end
end

--通知矿消失
function kuangEnd(actor)
	local hdl, sceneId, pos = getKuangFubenHdl(actor)
	local id, data = getSceneInfo(sceneId)

	local info = getActorKuangInfo(LActor.getActorId(actor), sceneId)
	if not info then return end
	clearKuangInfo(info)

	--广播
	sceneBroadcast(data, caikuangEvent.finish, pos)
end

--通知矿攻击状态变化
function kuangAttackStatus(actorId, tactorId, sceneId, isAttack, result)
	local info = getActorKuangInfo(tactorId, sceneId)
	if not info then return nil end
	local id, data = getSceneInfo(sceneId)

	if isAttack then
		addBeAttacker(tactorId)
	else
		removeBeAttacker(tactorId)
	end

	--广播
	sceneBroadcast(data, caikuangEvent.attackStatus, info.pos, {isAttack})

	--掠夺胜利需要保存掠夺者的id
	if 1 == (result or 0) then addAttacker(actorId, info, sceneId) end
end

--新增掠夺者
function addAttacker(tactorId, info, sceneId)
	--如果打完前被掠夺的矿已经结束了，就不处理了
	if true == caikuangsystem.kuangIsFinish(info.kuangId, info.endTime) then return end

	if nil == info.attackerList then info.attackerList = {} end
	table.insert(info.attackerList, tactorId)

	local id, data = getSceneInfo(sceneId)

	--广播
	sceneBroadcast(data, caikuangEvent.addAttacker, info.pos, {tactorId})
end

--是否可以攻击该玩家
function checkCanBeAttacked(actorId, tActorId, sceneId)
	local info = getActorKuangInfo(tActorId, sceneId)
	if not info then return false end

	--被掠夺次数是否已满
	if BaseConf.maxBeRobCount <= #(info.attackerList or {}) then
		print("caikuangscene.checkCanBeAttacked:maxBeRobCount limit, tactorId:"..tostring(tActorId)..", actorId:"..tostring(actorId))
		return false
	end

	--是否正在被攻击
	if true == checkIsAttacked(tActorId) then
		print("caikuangscene.checkCanBeAttacked:checkIsAttacked is true, tactorId:"..tostring(tActorId)..", actorId:"..tostring(actorId))
		return false
	end

	--矿是否结束了
	if caikuangsystem.kuangIsFinish(info.kuangId, info.endTime) then
		print("caikuangscene.checkCanBeAttacked:kuangIsFinish is true, tactorId:"..tostring(tActorId)..", actorId:"..tostring(actorId))
		return false
	end

	return true
end

--根据方向获取可进入场景的handle
function getNextHandle(sceneId, direction)
	local id, data = getSceneInfo(sceneId)

	if 0 == direction then
		if not allscene[id-1] then
			print("caikuangscene.getNextHandle: allscene[id-1] is nil, id:"..tostring(id)..", sceneId:"..tostring(sceneId)..", size:"..tostring(#allscene))
			return 0
		end

		return allscene[id-1].fubenHdl
	end

	if not allscene[id+1] then
		print("caikuangscene.getNextHandle: allscene[id+1] is nil, id:"..tostring(id)..", sceneId:"..tostring(sceneId)..", size:"..tostring(#allscene))
		return 0
	end

	return allscene[id+1].fubenHdl
end

local function isAllKuangFinish(id)
	for k, v in pairs(allscene[id].sceneData or {}) do
		local isFinish = caikuangsystem.kuangIsFinish(v.kuangId, v.endTime)
		if not isFinish then return false end
	end

	return true
end

--清除多余的房间
local function onClear()
	--print("caikuangscene.pre room size is:"..tostring(#allscene))
	local isClear = false
	for i=#(allscene or {}), 1, -1 do
		local actors = Fuben.getAllActor(allscene[i].fubenHdl)
		if not actors and isAllKuangFinish(i) then
			local ins = instancesystem.getInsByHdl(allscene[i].fubenHdl)
			ins:setEnd()
			ins:release()

			allscene[i] = allscene[#allscene]
			print("caikuangscene.max size is:"..tostring(#(allscene or {})))

			--删除最后一个房间
			table.remove(allscene, #allscene)

			isClear = true

			print("caikuangscene.room size is:"..tostring(#allscene))
			print("caikuangscene.release fubenHdl success, id:"..tostring(i))
		end
	end

	--通知玩家场景id变更
	if isClear then
		--这个处理是当所有房间都满矿了，需要保留一个房间，如果都满矿了，玩家又不去新房间采矿，就会出现该房间每分钟被回收后又创建~~~
		if 0 < #allscene then
			if 0 == getVaildFubenHdl() then createNewScene() end
		end

		for i=#(allscene or {}), 1, -1 do sceneBroadcast(allscene[i], caikuangEvent.SceneIndexChange, i) end
	end
end

function initData()
	allscene = getSystemVarData()
	--清空攻击者列表
	allscene.beAttackList = nil
end

--初始化副本handle，因为副本handle在服务器关闭后会释放，所以需要初始化
local function InitFubenHandle()
	allscene = getSystemVarData()
	for i= 1, #allscene do
		if 0 ~= allscene[i].fubenHdl then
			local fubenHdl = Fuben.createFuBen(BaseConf.fubenId)
			if 0 == fubenHdl then print("caikuangscene.InitFubenHandle:fubenHdl is 0") return end

			allscene[i].fubenHdl = fubenHdl
			local ins = instancesystem.getInsByHdl(fubenHdl)
			if ins then ins.data.sceneId = allscene[i].sceneId end
		end
	end
end

engineevent.regGameTimer(onClear)
engineevent.regGameStartEvent(InitFubenHandle)

function clearKuang(id)
	if 1 == id then
		local var = System.getStaticVar()
		var.caikuang = {}
		var.caikuang = nil
		allscene = getSystemVarData()
	end

	if 2 == id then print("kuang room size:"..tostring(#allscene)) end

	if 3 == id then
		gFile = io.open("kuangInfo.txt" ,"w");
		gFile:write(utils.t2s(allscene or {}))
		gFile:close()
	end

	if 4 == id then getNextHandle(1, 1) end
end
