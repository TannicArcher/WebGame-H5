module("systems.actordie.crossdie" , package.seeall)
setfenv(1, systems.actordie.crossdie)

local actordie = require("systems.actordie.actordie")
require("protocol")
require("misc.relivecdtime")

local CrossSet = CrossSet
local systemId = SystemId.miscsSystem
local protocol = MiscsSystemProtocol
--todo 暂时使用旧方法实现死亡处理,之后如果有渡劫系统重新优化
function onCrossDie(actor)
	local fubenId = LActor.getFubenId(actor)
	local fuben, crosspos
	--todo 这里可以不使用循环查询
	for i, info in ipairs(CrossSet)  do
		if fubenId == info.fbId then
			crosspos = i
			fuben = LActor.getFubenPrt(actor)
			break
		end
	end

	if not fuben then return end
	local fubenHandle = Fuben.getFubenHandle(fuben)
	-- 记录渡劫失败
	local var = LActor.getStaticVar(actor)
	if var then
		var.crossfailed = 1
		local allcount = LActor.GetCrossStarCount(actor)
		local jingjie = allcount / 9
		local jieduan = allcount % 9
		jingjie = math.floor(jingjie)

		System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor),
			tostring(LActor.getLevel(actor)), "dujie", "", "", "fight", "fail",
			tostring(jingjie),
			tostring(jieduan), "", lfBI)

	end
	local hscene = Fuben.getSceneHandleById(CrossSet[crosspos].scene, fubenHandle)
	Fuben.clearAllMonster(hscene)
	local pack = LDataPack.allocPacket(actor, systemId, protocol.sDuJieFail)  --申请一个数据包
	if pack == nil then return end
	LDataPack.flush(pack)
end

function initCrossDie()
	for _, info in ipairs(CrossSet) do
		actordie.regByFuben(info.fbId, onCrossDie)
	end
end

table.insert(InitFnTable, initCrossDie)


