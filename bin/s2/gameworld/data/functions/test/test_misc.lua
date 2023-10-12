module("test.test_misc", package.seeall)
setfenv(1, test.test_misc)

local luaex = require("utils.luaex")
local lua_string_split = luaex.lua_string_split

function test_LDatapack(actor)
	local p = LDataPack.allocPacket(actor)
	if p == nil then 
		print("test_LDatapack:p is nil")
	else 
		print("test_LDatapack:p is not nil")
	end
end

function changeModel(actor, modelId)
	LActor.setIntProperty(actor, P_MODELID, modelId)
	print("changeModel")
end

function changeHair(actor, modelId)
	LActor.setIntProperty(actor, P_HAIR_MODEL, modelId)
	print("changeHair")
end

function test_fightvalue(actor)
	local fightvaluesys = require("systems.fightvalue.fightvalue")
	local actorId = LActor.getActorId(actor)
	local pack = LDataPack.allocPacket(actor, SystemId.enCommonSystemID, CommonSystemProtocol.cFightValue)
	if not pack then return end
	LDataPack.writeInt(pack, actorId)
	LDataPack.setPosition(pack, 0)

	fightvaluesys.test_fightvalue(actor, pack)
end

function test_sql(actor)
	sql = "delete from serveridlist"
	System.sendExecSqlToDb(sql)
end

function tt(actor)
	local name System.getMonsterNameById(56)
end

function ss(actor)
	local sceneHandle = LActor.getSceneHandle(actor)
	Fuben.setSceneAreaAttri(sceneHandle, 1, 22, "0")
end

-- 缃戜笂鏉ョ殑浠ｇ爜
local function split(str, split_char)
	local sub_str_tab = {};
	while (true) do
		local pos = string.find(str, split_char);
		if (not pos) then
			sub_str_tab[#sub_str_tab + 1] = str;
			break;
		end
		local sub_str = string.sub(str, 1, pos - 1);
		sub_str_tab[#sub_str_tab + 1] = sub_str;
		str = string.sub(str, pos + 1, #str);
	end

	return sub_str_tab;
end

function test_split_string()
	local test = 
	{
		"fd.dee.bb",
		"ff.eee.123",
		"122.ee.***.%%"
	}
	for _,s in ipairs(test) do
		local list1 = split(s, "%.")
		local list2 = lua_string_split(s, ".")
		Assert_eq(#list1, #list2, "test_split_string len error")
		for i,v in ipairs(list1) do
			Assert_eq(v, list2[i], "test_split_string err")
		end
	end
end

_G.changeModel = changeModel
_G.changeHair = changeHair
_G.test_sql = test_sql
_G.tt = tt
_G.ss = ss
-- _G.test_split_string = test_split_string
TEST("misc", "split", test_split_string, false)

