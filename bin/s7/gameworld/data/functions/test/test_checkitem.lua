module("test.test_checkitem" , package.seeall)
setfenv(1, test.test_checkitem)

local actorevent = require("actorevent.actorevent")

--[[
用户上下线的时候检查物品的数据是否一致
--]]

local function getUserData()
	local st = System.getStaticVar()
	local itemdata = st.test_itemdata

	if itemdata == nil then
		st.test_itemdata = {}
		itemdata = st.test_itemdata
	end
	return itemdata
end

-- 用上线的时候读取上次下线时保存的数据
local function onEnterGame(actor, pos)
	local itemdata = getUserData()

	local c1 = Item.getCrc16(actor, pos)
	local key = string.format("%d_%d", LActor.getActorId(actor), pos)
	local lastcrc = itemdata[key]
	if lastcrc then
		Assert(c1 == lastcrc, "actor item data invail!"..pos)
	end
end

_G.OnCheckUserItem = onEnterGame

-- 下线的时候保存数据
local function onLogout(actor, pos)
	local itemdata = getUserData()

	local key = string.format("%d_%d", LActor.getActorId(actor), pos)
	itemdata[key] = Item.getCrc16(actor, pos)
end

_G.OnSaveUserItemCheckData = onLogout
