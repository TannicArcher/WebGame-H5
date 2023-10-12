module("base.mergeserver.merge", package.seeall)
setfenv(1, base.mergeserver.merge)

local fishact = require("systems.fish.championship")
local localwb = require("systems.worldboss.localworldboss")
local wbbase = require("systems.worldboss.wbase")
local elite = require("systems.worldboss.localelite")

function mergeClear()
	--清理钓鱼大赛数据
	fishact.clearAllRanking()
	--清空世界boss数据
	localwb.clearBossKillResult()
	wbbase.clearData()
	--清空精英boss数据
	elite.clearLocalLiteData()
end
