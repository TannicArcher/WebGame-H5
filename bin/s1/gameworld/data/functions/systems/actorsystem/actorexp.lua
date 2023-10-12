module("actorexp", package.seeall)


local LDataPack = LDataPack
local LActor    = LActor
local System    = System


require("protocol")
local SysId = Protocol.CMD_Base
local protocol = Protocol


local function onAddExp(actor, level, exp, nadd)
	local conf = ExpConfig[level]
	if conf == nil then return end

	if exp < conf.exp then
		confirmExp(actor, level, exp, nadd)
		return
	else
		if ExpConfig[level+1] ==nil then
			exp = conf.exp
			confirmExp(actor,level, exp, nadd)
			return
		else
			exp = exp - conf.exp
			level = level + 1
			onAddExp(actor, level, exp, nadd)
			onLevelUp(actor, level)
		end
	end
end

function onLevelUp(actor, level)
	LActor.onLevelUp(actor)

	actorevent.onEvent(actor, aeLevel, level)
end

function addExp(actor, nadd, log,notShowLog)
	if type(nadd) ~= "number" then return 0 end
	if nadd < 0 then return 0 end

	local old = LActor.getExp(actor)
	local exp = old + nadd

	local level = LActor.getLevel(actor)
	onAddExp(actor, level, exp, nadd)

    --log
    if notShowLog == nil or notShowLog == false then
    	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
            "add exp", tostring(nadd), tostring(old), "", log, "", "")
    end
	--print(string.format("actor:%d add exp:%d log:%s", LActor.getActorId(actor), nadd, tostring(log)))
end

function confirmExp(actor, level, exp, nadd)
	local npack = LDataPack.allocPacket(actor,  SysId, protocol.sBaseCmd_UpdateExp)
	if npack == nil then return end
	LActor.setLevel(actor, level)
	LActor.setExp(actor, exp)

	LDataPack.writeInt(npack, level)
	LDataPack.writeInt(npack, exp)
    LDataPack.writeInt(npack, nadd)
	LDataPack.flush(npack)
	--print(string.format("actor:%d, level:%d, exp:%d",LActor.getActorId(actor), level, exp) )
end

--兼容接口
LActor.addExp        = addExp

--提供给C++
--C++使用新增加的CallFunc来进行调用
_G.MyAddExp        = addExp
