-- 世界BOSSNPC配置测试

module("test.test_worldboss_npc" , package.seeall)
setfenv(1, test.test_worldboss_npc)
-- require("worldboss.worldbossconf")
-- local checkFunc = require("test.assert_func")
-- local WorldBossConf = WorldBossConf
local wbase = require("systems.worldboss.wbase")
local Item = Item

local NPC_MOD_ID = 620002
local NPC_NAME = "测试"

local function test_create_npc(actor)
	-- local pScene = LActor.getScenePtr(actor)
	-- if not pScene then return end
	local x, y = LActor.getEntityPosition(actor)
	-- local hScene = LActor.getSceneHandle(actor)
	local sceneId = LActor.getSceneId(actor)
	System.createnpc(NPC_NAME, "", sceneId, x, y, NPC_MOD_ID, 65)
end

local function test_remove_npc(actor)
	local sceneId = LActor.getSceneId(actor)
	local x, y = LActor.getEntityPosition(actor)
	wbase.clearNpc(sceneId, {modelId = NPC_MOD_ID})
end

TEST("worldboss", "createnpc", test_create_npc, false)
TEST("worldboss", "delnpc", test_remove_npc, false)

-- _G.createnpc = test_create_npc
-- _G.delnpc = test_remove_npc





