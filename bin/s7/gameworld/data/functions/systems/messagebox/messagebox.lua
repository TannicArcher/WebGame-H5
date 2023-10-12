--消息盒子系统
module("systems.messagebox.messagebox", package.seeall)
setfenv(1, systems.messagebox.messagebox)

local LDataPack = LDataPack
local LActor    = LActor
local System    = System

local actorevent = require("actorevent.actorevent")
local netmsgdispatcher = require("utils.net.netmsgdispatcher")

local sysId    = SystemId.enDefaultEntitySystemID
local protocol = defaultSystemProtocol

local getActorId = LActor.getActorId

local MAX_BUTTON_COUNT = 3	--最大按钮数量

_G.messageboxId = _G.messageboxId or 0

_G.msgBoxData = _G.msgBoxData or {}
local msgBoxData = _G.msgBoxData

function getMId()
	--返回的mId必大于0
	_G.messageboxId = _G.messageboxId + 1
	return _G.messageboxId
end

local function getMsgBoxList(actor)
	if not actor then return end
	local actorId = getActorId(actor)
	if actorId == 0 then return end
	msgBoxData[actorId] = msgBoxData[actorId] or {}
	return msgBoxData[actorId]
end

--actor
--TODO messageBoxResult
--执行NPC脚本
function messageBoxResult(actor, pack)
	local hNpc, idx, msgId = LDataPack.readData(pack, 3, dtUint64, dtUint, dtInt)
	if not idx or not msgId or not hNpc or msgId < 0 then return end

	local LActor = LActor
	local list   = getMsgBoxList(actor)
	if not list then return end

	local item = list[msgId]

	if hNpc == 0 then hNpc = LActor.getHandle(System.getGlobalNpc()) end
	if not item or not item.npc or item.npc ~= hNpc then return end

	local npcEty = LActor.getEntity(item.npc)
	--TODO 后期可能可以移植
	LActor.npcTalk(actor, npcEty, item.fn[idx])
	list[msgId] = nil --清空
end

--actor
--TODO messageBox
function setMsgBox(actor, hNpc, actorId, sTitle, sBtn1, sBtn2, sBtn3 , nTimeOut, msgType, sTip, nIcon, timeoutEvent, closeBtn)
	if not actor then return end
	if actorId == 0 then
		actorId = LActor.getActorId(actor)
	end
	--local actorId = LActor.getActorId(actor)
	local sFnName = {}
	if sBtn1 then table.insert(sFnName, sBtn1) end
	if sBtn2 then table.insert(sFnName, sBtn2) end
	if sBtn3 then table.insert(sFnName, sBtn3) end

	return addAndSendMessageBox(actor, hNpc, actorId, sTitle, sFnName, nTimeOut, msgType, sTip, nIcon, timeoutEvent, closeBtn)
end

--解析传参
function setFnParams(fn, btnName, key, str)
	--if not fn then return 1 end
	--README sFnName包含了按钮要显示的文字，以及点击后要执行的函数名，中间用 “/”隔开，比如"确定/commonAcceptMissions,1"
	--其中“确定”是客户端要显示的按钮的文字，commonAcceptMissions,1是要执行的脚本函数和参数
	--TODO 由于纯粹LUA完成，后续修改为可以直接传参会更简单
	-- print(str)
	local idx = string.find(str, "/")
	local strLen = string.len(str)
	if not idx or idx == strLen then return -1 end
	--找出需要执行的方法和参数
	fn[key] = string.sub(str, idx + 1)
	btnName[key] = string.sub(str, 1, idx - 1)
end

--actor
--TODO AddAndSendMessageBox
-- * sFnName 按钮名称
function addAndSendMessageBox(actor, hNpc, actorId, sTitle, sFnName, nTimeOut, msgType, sTip, icon, timeOutEvent, closeBtn)
	if not sTitle or
		not sFnName or
		#sFnName > MAX_BUTTON_COUNT then
		print("AddAndSendMessageBox Param Error!")
		return -1 end
	if not actor then return -2 end

	if actorId == 0 then
		actorId = LActor.getActorId(actor)
	end
	local list = getMsgBoxList(actor)
	if not list then return -2 end

	if hNpc == 0 then hNpc = LActor.getHandle(System.getGlobalNpc()) end
	local item = {}
	item.msgId    = getMId()
	item.npc      = hNpc
	item.actorId  = actorId
	item.btnCount = #sFnName
	item.fn       = {}	--方法和参数
	item.btnName  = {}	--按钮名字
	for k,btnStr in pairs(sFnName) do
		local ret = setFnParams(item.fn, item.btnName, k, btnStr)
		if ret then return ret end
	end
	list[item.msgId] = item

	local pack = LDataPack.allocPacket(actor, sysId, protocol.sMessageBox)
	if not pack then return end
	LDataPack.writeData(pack, 3,
		dtUint64, hNpc,
		dtString, sTitle,
		dtChar, #sFnName)

	for _,bName in pairs(item.btnName) do
		LDataPack.writeString(pack, bName)
	end

	LDataPack.writeUInt(pack, nTimeOut or 0)
	LDataPack.writeInt(pack, item.msgId) --msgId
	LDataPack.writeChar(pack, msgType or 0)
	LDataPack.writeString(pack, sTip or "")
	LDataPack.writeShort(pack, icon or 0)
	LDataPack.writeInt(pack, timeOutEvent or 0)
	LDataPack.writeChar(pack, closeBtn or 0)
	LDataPack.flush(pack)
	return item.msgId
end

--actor
--TODO removeMyMessageBox
function removeMyMessageBox(actor)
	if not actor then return end
	local actorId = LActor.getActorId(actor)
	if actorId == 0 then return end
	msgBoxData[actorId] = nil
end

--注册协议(0, 6)
netmsgdispatcher.reg(sysId, protocol.cMessageBox, messageBoxResult)
--用户登出事件
actorevent.reg(aeUserLogout, removeMyMessageBox)

-- * 兼容接口
LActor.messageBox = setMsgBox

