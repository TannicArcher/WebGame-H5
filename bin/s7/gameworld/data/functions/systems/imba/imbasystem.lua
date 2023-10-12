--[[
	local tab = {
	act = {
		[组ID]=1  1表示已激活的神器
	},
	get = {
		[组ID] = bit,  位移表示可以激活的碎片
	},
	[组ID] = bit 位移表示已激活的碎片
}

]]


module("imbasystem",package.seeall) --神器系统

local ImbaConf = ImbaConf
local ImbaJigsawConf = ImbaJigsawConf

local function getImbaData(actor)
	local var = LActor.getStaticVar(actor) 
	if var == nil then return nil end
	if var.imbaData == nil then
		var.imbaData = {}
	end
	if var.imbaData.act == nil then var.imbaData.act = {} end
	if var.imbaData.get == nil then var.imbaData.get = {} end
	return var.imbaData
end

--判断指定神器id是否激活
function checkActive(actor, id)
	local data = getImbaData(actor)
	if data.act[id] then return true end

	return false
end

local function addImbaAttr(actor)
	local attr = nil
	local attrList = {}
	local exattrs = nil
	local exattrList = {}
	local data = getImbaData(actor)


	local groupId = 0
	local jigsawId = 0
	--local activeCnt = 0
	local bitSet = 0
	local totalpower = 0
	LActor.clearImbaActId(actor)
	for i,subConf in pairs(ImbaConf) do
		--activeCnt = 0
		groupId = subConf.id
		for i=1,subConf.count do
			bitSet = data[groupId]
			if bitSet and System.bitOPMask(bitSet, i - 1) then
				--activeCnt = activeCnt + 1
				jigsawId = groupId+i
				attrs = ImbaJigsawConf[jigsawId].attrs
				if attrs then
					for _,tb in pairs(attrs) do
						attrList[tb.type] = attrList[tb.type] or 0
						attrList[tb.type] = attrList[tb.type] + tb.value
					end
				end
			end
		end
		--if subConf.exattrs and activeCnt >= subConf.count then
		if data.act[groupId] then
			for _,tb in pairs(subConf.attrs or {}) do
				attrList[tb.type] = attrList[tb.type] or 0
				attrList[tb.type] = attrList[tb.type] + tb.value
			end
			for _,tb in pairs(subConf.exattrs or {}) do
				exattrList[tb.type] = exattrList[tb.type] or 0
				exattrList[tb.type] = exattrList[tb.type] + tb.value
			end
			LActor.addImbaActId(actor, groupId)
			--totalpower = totalpower + subConf.power
		end
	end		

	for type,value in pairs(attrList) do
		LActor.addImbaAttr(actor, type, value)
	end
	for type,value in pairs(exattrList) do
		LActor.addImbaExattr(actor, type, value)
	end

	-- print("totalpower-------------",totalpower)
	-- table.print(exattrList)
	--local attr = LActor.getImbaAttr(actor)
	--attr:SetExtraPower(totalpower)
end

function updateAttr(actor)
	LActor.clearImbaAttr(actor)

	addImbaAttr(actor)

	LActor.reCalcAttr(actor)

	LActor.reCalcExAttr(actor)
	
	specialattribute.updateAttribute(actor)
end

function updateAttributes(actor, sysType)
	local data = getImbaData(actor)
	for i,subConf in pairs(ImbaConf) do
		local groupId = subConf.id
		if data.act[groupId] then
			for _,v in ipairs(subConf.specialAttr or {}) do
				specialattribute.add(actor,v.type,v.value,sysType)
			end
		end
	end	
end

local function initImba(actor)
	updateAttr(actor)
end

local function syncImbaData(actor)
	local count = 0
	local jigsawTb = {}
	local data = getImbaData(actor)
	for jigsawId,subConf in pairs(ImbaConf) do
		groupId = subConf.id
		if data[groupId] ~= nil or data.get[groupId] ~= nil then
			jigsawTb[groupId] = data[groupId] or 0
			count = count + 1
		end
	end

	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Artifacts, Protocol.sArtifactsCmd_SyncImbaData)
	if pack == nil then return end
	LDataPack.writeShort(pack, count)
	for k,v in pairs(jigsawTb) do
		LDataPack.writeInt(pack, k)
		LDataPack.writeInt(pack, v)
		LDataPack.writeByte(pack, data.act[k] or 0)
		if not data.act[k] then
			LDataPack.writeInt(pack, data.get[k] or 0)
		end

	end
	LDataPack.flush(pack)
end

local function sendUpdateImbaData(actor, groupId, getbit, actbit)
	--通知前端
	local pack = LDataPack.allocPacket(actor, Protocol.CMD_Artifacts, Protocol.sArtifactsCmd_UpdateImbaData)
	if pack == nil then return end
	LDataPack.writeInt(pack, groupId)
	LDataPack.writeInt(pack, getbit)
	LDataPack.writeInt(pack, actbit)
	LDataPack.flush(pack)
end

function updateImbaData(actor, newjigsawId)
	if not ImbaJigsawConf[newjigsawId] then return end
	local var = getImbaData(actor)
	if var.get == nil then var.get = {} end
	local data = var.get
	
	local groupId = math.floor(newjigsawId/10)*10
	local groupIdx = math.floor(newjigsawId%10)
	
	if data[groupId] == nil then data[groupId] = 0 end
	data[groupId] = System.bitOpSetMask(data[groupId], groupIdx-1, true)

	sendUpdateImbaData(actor, groupId, data[groupId], var[groupId] or 0)
end

function activeItem(actor, id)
	if ImbaJigsawConf[id] then
		updateImbaData(actor,id)
		return true
	end
	return false
end

_G.imbaActiveItem = activeItem

local function doActImbaItem(actor, newjigsawId)
	if not ImbaJigsawConf[newjigsawId] then return end
	local var = getImbaData(actor)
	if var.get == nil then var.get = {} end

	local get = var.get	--已经获得的神器碎片
	local data = var --已经激活了的神器碎片
	local groupId = math.floor(newjigsawId/10)*10
	local groupIdx = math.floor(newjigsawId%10)
	if data[groupId] == nil then data[groupId] = 0 end
	if System.bitOPMask(data[groupId], groupIdx-1) then
		print("imbasystem.doActImbaItem:already active:"..tostring(newjigsawId))
		return
	end

	if get[groupId] == nil then get[groupId] = 0 end
	if not System.bitOPMask(get[groupId], groupIdx-1) then
		print("imbasystem.doActImbaItem:not enough item:"..tostring(newjigsawId))
		return
	end

	--激活碎片
	data[groupId] = System.bitOpSetMask(data[groupId], groupIdx-1, true)
	updateAttr(actor)

	sendUpdateImbaData(actor,groupId, get[groupId], data[groupId])
	actorevent.onEvent(actor, aeActImbaItem, newjigsawId)
end

local function onLogin(actor)
	if actor == nil then return end
	syncImbaData(actor)
end

local function doActImba(actor, index)
	local cfg = ImbaConf[index]
	if not cfg then
		print("doActImba: index:"..tostring(index)..", is not config")
		return
	end
	local data = getImbaData(actor)
	if data.act[cfg.id] then --已经激活过了
		print("doActImba: index:"..tostring(index)..", is acted")
		return
	end
	for i=1,cfg.count do
		bitSet = data[cfg.id]
		if not bitSet or not System.bitOPMask(bitSet, i - 1) then
			print("doActImba: index:"..tostring(index)..", is not active item:"..tostring(cfg.id+i))
			return
		end
	end

	data.get[cfg.id] = nil
	data.act[cfg.id] = 1
	updateAttr(actor)
	syncImbaData(actor)
	actorevent.onEvent(actor, aeActImba, cfg.id)
end

local function ActImba(actor, packet)
	local index = LDataPack.readInt(packet)
	doActImba(actor, index)
end

local function ActImbaItem(actor, packet)
	local id = LDataPack.readInt(packet)
	doActImbaItem(actor, id)
end

local function init()
	actorevent.reg(aeInit,initImba)
	actorevent.reg(aeUserLogin, onLogin)
	netmsgdispatcher.reg(Protocol.CMD_Artifacts, Protocol.cArtifactsCmd_ActImba, ActImba)
	netmsgdispatcher.reg(Protocol.CMD_Artifacts, Protocol.cArtifactsCmd_ActImbaItem, ActImbaItem)
end

table.insert(InitFnTable, init)

function gm_imba(actor, arg)
	doActImba(actor, tonumber(arg[1]))
end

function gm_imbaItem(actor, arg)
	doActImbaItem(actor, tonumber(arg[1]))
end
