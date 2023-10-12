module("msgsystem", package.seeall)
-- setfenv(1, systems.msg.msgsystem)
--[[
	离线消息系统
--]]

-- require("protocol")
-- require("utils.net.netmsgdispatcher")
local netmsgdispatcher = netmsgdispatcher
--local actorevent       = require("actorevent.actorevent")
--local actormoney       = require("systems.actorsystem.actormoney")

-- local SystemId 			 = SystemId
-- local enMsgSystemID	 	 = SystemId.enMsgSystemID
-- local eMsgSystemCode 	 = eMsgSystemCode
local System   			 = System
local LActor   			 = LActor

local LDataPack   = LDataPack
local writeByte   = LDataPack.writeByte
local writeWord   = LDataPack.writeWord
local writeInt    = LDataPack.writeInt
local writeInt64  = LDataPack.writeInt64
local writeString = LDataPack.writeString
local writeData   = LDataPack.writeData

local readByte    = LDataPack.readByte
local readWord 	  = LDataPack.readWord
local readInt  	  = LDataPack.readInt
local readString  = LDataPack.readString
local readData    = LDataPack.readData

-- local sendTipmsg 	 = LActor.sendTipmsg
-- local ScriptTips 	 = Lang.ScriptTips

---------------- BEGIN 离线消息类型枚举 BEGIN ----------------
local mtMessageCount = 1024
---------------- END   离线消息类型枚举 END   ----------------


---------------- BEGIN 自定义离线消息号枚举 BEGIN ----------------
offlineFriendMsg = 1025 -- 给离线好友留言
---------------- END   自定义离线消息号枚举 END   ----------------

-- Comments: 增加玩家离线消息
function recOffMsg(actor, beg_idx, end_idx)
	if not actor or not beg_idx or not end_idx then return end

	if beg_idx < 0 then return end
	if beg_idx >= end_idx then return end

	local cnt = LActor.getOffMsgCnt(actor)
	if end_idx > cnt then return end

	local index = beg_idx
	--索引从0开始，要减1
	local time = end_idx - beg_idx - 1

	-- print("msgsystem time is :" .. time)
	for idx = index,time do
		local msgid, offmsg = LActor.getOffMsg(actor, index)
		-- print("msgsystem for :" .. index .. msgid)
		if msgid ~= nil and offmsg ~= nil then
			local msgtype = readWord(offmsg)
			-- print("msgsystem msgtype :" .. index .. msgtype)
			if msgtype ~= nil then
				if msgtype > mtMessageCount then
					-- print("msgsystem mtMessageCount :" .. index .. msgtype)
					ret = handleMsg(actor, index, msgtype,offmsg)
					if ret then
						-- 成功从数据库中删除测试消息
						if index >= 0 then
							LActor.deleteOffMsg(actor, index)
						end
					else
						--失败就跳过
						index = index + 1
					end

				elseif msgtype < mtMessageCount then
					-- sendOffMsg(actor, msgid , offmsg)
				end
			end
		end
	end
	-- print("msgsystem end_idx is :" .. end_idx)
	-- for idx = end_idx - 1,beg_idx,-1 do
	-- 	local msgid, offmsg = LActor.getOffMsg(actor, idx)
	-- 	-- print("msgsystem for :" .. idx .. msgid)
	-- 	if msgid ~= nil and offmsg ~= nil then
	-- 		local msgtype = readWord(offmsg)
	-- 		-- print("msgsystem msgtype :" .. idx .. msgtype)
	-- 		if msgtype ~= nil then
	-- 			if msgtype > mtMessageCount then
	-- 				-- print("msgsystem mtMessageCount :" .. idx .. msgtype)
	-- 				handleMsg(actor, idx, msgtype,offmsg)
	-- 			elseif msgtype < mtMessageCount then
	-- 				-- sendOffMsg(actor, msgid , offmsg)
	-- 			end
	-- 		end
	-- 	end
	-- end
end


----------------  BEGIN   消息注册处理   BEGIN  ----------------

local handles = {}

-- Comments: 注册消息处理
function regHandle( msgtype, func )
	if not msgtype or not func or type(func) ~= "function" then return end
	handles[msgtype] = func
end

-- Comments: 处理离线消息
function handleMsg( actor, msg_idx, msgtype, offmsg )
	if not actor or not msg_idx or not offmsg then return false end
	local func = handles[msgtype]
	if not func then return false end

	LDataPack.setPosition(offmsg, 0)
	local ret = func(actor, offmsg)

	--返回true删除
	return ret
end

----------------  BEGIN   消息注册处理   BEGIN  ----------------

-- C++调用 
_G.recOffMsg = recOffMsg



