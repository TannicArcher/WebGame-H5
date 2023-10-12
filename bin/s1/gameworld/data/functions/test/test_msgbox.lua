--消息盒子系统测试
module("test.test_msgbox" , package.seeall)
setfenv(1, test.test_msgbox)

local LDataPack = LDataPack
local LActor    = LActor
local Fuben     = Fuben
local System    = System
local LuaHelp   = LuaHelp

local msgBox  = require("systems.messagebox.messagebox")


--***********************************************
--README--------------消息测试-------------------
--***********************************************

-- 测试获取标识ID是否正常
local function test_getList(actor)
	local x1 = msgBox.getMId()
	local x2 = msgBox.getMId()
	Assert((x1 < x2) and (x2 - x1 == 1), "stepId haven some err.")
end

-- -- 添加一个按钮触发
-- local function test_setMsgBox(actor, hNpc, actorId, sTitle, sBtn1, sBtn2, sBtn3 , nTimeOut, msgType, sTip, nIcon, timeoutEvent, closeBtn)
-- 	--补充错误参数
-- 	-- print("!!!!!====1")
-- 	-- print(sBtn1)
-- 	-- print("!!!!!====2")
-- 	-- print(sBtn2)
-- 	-- print("!!!!!====3")
-- 	-- print(sBtn3)
-- 	msgBox.setMsgBox(actor, hNpc, actorId, sTitle, sBtn1, sBtn2, sBtn3 , nTimeOut, msgType, sTip, nIcon, timeoutEvent, closeBtn)
-- end

local function getPack(actor, hNpc, idx, msgId)
	local pack = LDataPack.test_allocPack()
	LDataPack.writeData(pack, 3,
		dtUint64, hNpc,
		dtUint, idx,
		dtInt, msgId)
	-- print("getPack")
	LDataPack.setPosition(pack, 0)
	return pack
end

local function test_setMsgBox(actor)
	local msgId = msgBox.setMsgBox(actor,0,0,Lang.Talk.t10072,Lang.Talk.t10070 .. "/telportScene,3,8,13," .. Lang.EntityName.n20,nil, nil, 5000,0,"",0,1,1)
	coroutine.yield()
	local pack = getPack(actor, 0, 1, msgId)
	msgBox.messageBoxResult(actor, pack)
	-- print("bingo")
end

-- _G.setmsg = test_setMsgBox

TEST("msgbox", "getlist",  test_getList, true)

TEST("msgbox", "setmsg",  test_setMsgBox,true)


