module("test.test_mount" , package.seeall)
setfenv(1, test.test_mount)

local mountsystem = require("systems.mount.mountsystem")
local actormoney = require("systems.actorsystem.actormoney")
require("mounts.mountappearance")
require("mounts.mountfeed")
require("mounts.mountlevelup")
require("protocol")

local systemId  = SystemId.enMountsSystemID
local protocol  = MountsSystemProtocol
local LActor    = LActor
local System    = System
local LDataPack = LDataPack
local LangMount = Lang.Mount

--local化配置表
local MountFeed = MountFeed
local MountLevelUp = MountLevelUp
local MountAppearance = MountAppearance
local MountSkill = MountSkill
local MountAppearanceConf = MountAppearance.appearanceCfg
local MountLevelUpConf = MountLevelUp.levelUpCfg

local GeneralMount = 0  --普通坐骑
local SpecialMount = 1  --物殊坐骑

local IsAppearance = 0 --激活的物品是普通形象
local IsSkill      = 1 --激活的物品是技能

--坐骑外观状态
local NotActive = 0
local IsActive  = 1
local Invalid   = 2 --期满
local Permanent = 3 --永久


--***********************************************
--README------------通用测试环境-----------------
--***********************************************


--***********************************************
--README------------通用测试环境-----------------
--***********************************************

-----------------------------------------BEGIN 发送坐骑信息 BEGIN-----------------------------
-- Comments: 发送坐骑信息
function handle_sendMountInfo(actor, aid, actor_name, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, aid)
	LDataPack.writeString(npack, actor_name)
	LDataPack.setPosition(npack, 0)

	local ret = mountsystem.sendMountInfo(actor, npack)
	Assert(ret ~= nil, "test_sendMountInfo, ret is null")
	Assert_eq(except, ret, "test_sendMountInfo error")

	if except == ret and ret == true then
	end
end

function test_sendMountInfo(actor)
	LActor.openSys(actor, siMount)  --开启坐骑
	--发坐骑信息给自己显示
	handle_sendMountInfo(actor, LActor.getActorId(actor), LActor.getName(actor), true)
end
-----------------------------------------END 发送坐骑信息 END--------－-------------------------


-----------------------------------------BEGIN 喂养 提升饱食度 BEGIN-----------------------------
-- Comments: 喂养 提升饱食度
function handle_enhanceHunger(actor, except)

	local _, _, old_hunger, _ = mountsystem.getMountInfo(actor)                   --原来的饱食度
	local old_food_item_cnt = LActor.getItemCount(actor, MountFeed.foodItem)      --原来背包中坐骑食料的数量

	local need_item_cnt = math.floor(old_hunger / MountFeed.foodkn) + 1
	if old_hunger > MountFeed.hungerLvl then
		need_item_cnt = MountFeed.maxNeedItemCnt
	end

	local ret = mountsystem.enhanceHunger(actor)
	Assert(ret ~= nil, "test_enhanceHunger, ret is null")
	Assert_eq(except, ret, "test_enhanceHunger error")

	local _, _, cur_hunger, _ = mountsystem.getMountInfo(actor)					 --现在的饱食度
	local cur_food_item_cnt = LActor.getItemCount(actor, MountFeed.foodItem)     --当前背包中坐骑食料的数量

	if except == ret and ret == true then
		Assert(old_food_item_cnt - cur_food_item_cnt == need_item_cnt, "test_enhanceHunger succ but bag item count change error")
		Assert(cur_hunger - old_hunger == 1, "test_enhanceHunger succ but hunger change error")
	else
		Assert_eq(old_food_item_cnt, cur_food_item_cnt, "test_enhanceHunger fail but bag item count changed")
		Assert_eq(old_hunger, cur_hunger, "test_enhanceHunger fail but hunger changed")
	end
end

function test_enhanceHunger(actor)
	LActor.openSys(actor, siMount)  --开启坐骑
	LActor.cleanBag(actor)          --清理背包

	local _, _, old_hunger, _ = mountsystem.getMountInfo(actor)
	local need_item_cnt = math.floor(old_hunger / MountFeed.foodkn) + 1
	if old_hunger > MountFeed.hungerLvl then
		need_item_cnt = MountFeed.maxNeedItemCnt
	end

	LActor.addItem(actor, MountFeed.foodItem, 0, 0, need_item_cnt, 0)
	handle_enhanceHunger(actor, true)
end
-----------------------------------------END 喂养 提升饱食度 END---------------------------------


-----------------------------------------BEGIN 提升技能 BEGIN------------------------------------
-- Comments: 提升技能
function handle_enhanceSkill(actor, skill_id, auto_buy, except)

end

function test_enhanceSkill(actor)

end
-----------------------------------------END 提升技能 END----------------------------------------


-----------------------------------------BEGIN 解锁  开启进阶功能 BEGIN---------------------------
-- Comments: 解锁  开启进阶功能
function handle_unlockStageUp(actor, except)
	local old_item_cnt = LActor.getStoreItemCount(actor,ipBag)             			--背包中物器总数量

	local reward_item_cnt = 0
 	local awardItems = MountLevelUp.awardItem
 	for _, item_info in ipairs(awardItems) do
 		reward_item_cnt = reward_item_cnt + item_info.count
 	end

	local ret = mountsystem.unlockStageUp(actor)
	Assert(ret ~= nil, "test_unlockStageUp, ret is null")
	Assert_eq(except, ret, "test_unlockStageUp error")

	local cur_item_cnt = LActor.getStoreItemCount(actor,ipBag)


	if except == ret and ret == true then
		Assert(cur_item_cnt - old_item_cnt == reward_item_cnt, "test_unlockStageUp succ but bag item count change error")
	else
		Assert_eq(cur_item_cnt, cur_item_cnt, "test_unlockStageUp fail but bag item count changed")
	end
end

function test_unlockStageUp(actor)
	LActor.openSys(actor, siMount)  --开启坐骑

	local need_hunger = MountFeed.advancedNeedHunger
	local varMount = mountsystem.initMountData(actor)
	varMount.hunger = need_hunger

	handle_unlockStageUp(actor, true)
end
-----------------------------------------END 解锁  开启进阶功能 END------------------------------

-----------------------------------------BEGIN  坐骑进阶  BEGIN----------------------------------
-- Comments: 坐骑进阶
function handle_mountStageUp(actor, auto_buy, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeByte(npack, auto_buy)
	LDataPack.setPosition(npack, 0)

	local old_level, old_level_exp , _, _ = mountsystem.getMountInfo(actor)

	local ret = mountsystem.mountStageUp(actor, npack)
	Assert(ret ~= nil, "test_mountStageUp, ret is null")
	Assert_eq(except, ret, "test_mountStageUp error")

	local cur_level, cur_level_exp, _, _ = mountsystem.getMountInfo(actor)

	if except == ret and ret == true then
		--坐骑进阶时部分经验忽略 因此是可能变化的经验为0
		if old_level == cur_level then
			Assert(cur_level_exp - old_level_exp ~= 0, "test_mountStageUp succ 1 but cur_level_exp change error")
		else
			--当己进阶时当前经验可以改变，也可能跟上阶的经验一样都为0
		end
	else
		Assert_eq(cur_level, old_level, "test_mountStageUp fail but cur_level changed")
	end
end

function test_mountStageUp(actor)
	LActor.openSys(actor, siMount)  --开启坐骑

	local curr_level, _, _, _ = mountsystem.getMountInfo(actor)
	local moneyType = MountLevelUpConf[curr_level].moneyType
	LActor.changeMoney( actor, moneyType, 5000, 1, true, "mount","", "","")       --元宝充足的情况下

 	-- 已经达到最高级
	if curr_level >= #MountLevelUpConf then
		local varMount = mountsystem.initMountData(actor)
		varMount.level = 1
		varMount.level_exp = 0
	end

	handle_mountStageUp(actor, 1, true)
end
-----------------------------------------END 坐骑进阶 END-----------------------------------------


-----------------------------------------BEGIN  化形  BEGIN----------------------------------------
-- Comments: 化形
function handle_changeling(actor, appearance_id, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, appearance_id)
	LDataPack.setPosition(npack, 0)

	local _, _, _, old_model_id = mountsystem.getMountInfo(actor)

	local ret = mountsystem.changeling(actor, npack)
	Assert(ret ~= nil, "test_changeling, ret is null")
	Assert_eq(except, ret, "test_changeling error")

	local _, _, _, cur_model_id = mountsystem.getMountInfo(actor)

	if except == ret and ret == true then
		Assert_eq(cur_model_id, appearance_id, "test_changeling succ model_id change error")
	else
		Assert_eq(cur_model_id, old_model_id, "test_changeling fail model_id changed")
	end
end

function test_changeling(actor)
	LActor.openSys(actor, siMount)       --开启坐骑

	local var = LActor.getSysVar(actor)
	if var == nil then return false end
	if var.mount == nil then var.mount = {} end
	local varMount = var.mount
	varMount.appearance = nil --清空记录  让所有形象都未激活

	for _, mount in ipairs(MountAppearanceConf) do
		local appearance_id = mount.mountId
		handle_changeling(actor, appearance_id, false)   --坐骑形象未激活无法化形 todo
	end


	for _, mount in ipairs(MountAppearanceConf) do
		local appearance_id = mount.mountId
		local _, varMountAppearance = mountsystem.initMountData(actor)
		if varMountAppearance[appearance_id] == nil then
			varMountAppearance[appearance_id] = {}
		end
		local varAppearance     = varMountAppearance[appearance_id]
		varAppearance.status    = IsActive

		handle_changeling(actor, appearance_id, true)   --坐骑形象未激活无法化形 todo
	end
end
-----------------------------------------END 化形 END----------------------------------------------


-----------------------------------------BEGIN  强化  BEGIN----------------------------------------
-- Comments: 强化
function handle_strengthen(actor, appearance_id, auto_buy, except)
	local npack = LDataPack.test_allocPack()
	LDataPack.writeInt(npack, appearance_id)
	LDataPack.writeByte(npack, auto_buy)
	LDataPack.setPosition(npack, 0)

	local _, varMountAppearance = mountsystem.initMountData(actor)
	local varAppearance     = varMountAppearance[appearance_id]
	local old_strengthen       = (varAppearance and varAppearance.strengthen) or 0
	local old_bless       = (varAppearance and varAppearance.bless) or 0

	local ret = mountsystem.strengthen(actor, npack)
	Assert(ret ~= nil, "test_strengthen, ret is null")
	if except then Assert_eq(except, ret, "test_strengthen error")  end

	local _, varMountAppearance = mountsystem.initMountData(actor)
	local varAppearance     = varMountAppearance[appearance_id]
	local cur_strengthen   = (varAppearance and varAppearance.strengthen) or 0
	local cur_bless       = (varAppearance and varAppearance.bless) or 0

	if (except == ret or except == nil) and ret == true then
		--强化等级+1
		Assert(cur_strengthen - old_strengthen == 1 , "test_strengthen succ collect change error")
	elseif except == nil and ret == false then
		--祝福值+1
		Assert(cur_bless - old_bless == 1 , "test_strengthen fail bless change error")
	end
end

function test_strengthen(actor)
	LActor.openSys(actor, siMount)  --开启坐骑

	--强化非特殊坐骑
	local appearance_id = 1
	handle_strengthen(actor, appearance_id, 0, false)


	for _, mount in ipairs(MountAppearanceConf) do
		local appearance_id = mount.mountId
		local appearance_type = mount.type

		local except = true
		if appearance_type == GeneralMount then
			except = false
			--强化非特殊坐骑 --肯定不成功
			handle_strengthen(actor, appearance_id, 0, except)
		end

		local _, varMountAppearance = mountsystem.initMountData(actor)
		local varAppearance = varMountAppearance[appearance_id]

		if varAppearance then
			local status = varAppearance.status
			if not status or status == NotActive then
				except = false
				--强化未激活坐骑外观 --肯定不成功
				handle_strengthen(actor, appearance_id, 0, except)
			end

			local strengthen = varAppearance.strengthen
			if strengthen and strengthen >= 10 then
				except = false
			    --强化等级己为最高级 --肯定不成功
				handle_strengthen(actor, appearance_id, 0, except)
			end

			--满足扣除道具
			local _, varMountAppearance = mountsystem.initMountData(actor)
			local varAppearance     = varMountAppearance[appearance_id]
			local strengthen       = (varAppearance and varAppearance.strengthen) or 0

			local need_item_id = MountAppearance.strengthCfg.needItemId
			local need_item_cnt = MountAppearance.strengthCfg.needItemCount[strengthen + 1]
			LActor.addItem(actor, need_item_id, 0, 0, need_item_cnt, 0)

			--基本满足强化的条件，但仍根据概率有成功或失败的可能
			if except == true then--只意味着前面一些判断通过
				handle_strengthen(actor, appearance_id, 0, nil)
			end
		end
	end
end
-----------------------------------------END 强化 END----------------------------------------------


-----------------------------------------BEGIN  激活特殊坐骑  BEGIN-------------------------------
-- Comments: 激活特殊坐骑
function handle_activeSpecialMount(actor, item_id, use_time, except)
	local _, varMountAppearance = mountsystem.initMountData(actor)
	local appearance_id --坐骑外观ID
	--如果激活坐骑的物品正确的话设置标志为 true
	for _, appearance in ipairs(MountAppearanceConf) do
		if item_id == appearance.openItemId then
			appearance_id = appearance.mountId
			break
		end
	end

	local varAppearance     = varMountAppearance[appearance_id]
	local old_collect       = (varAppearance and varAppearance.collect) or 0

	local ret = mountsystem.activeSpecialMount(actor, item_id, use_time)

	local _, varMountAppearance = mountsystem.initMountData(actor)
	local varAppearance     = varMountAppearance[appearance_id]
	local cur_active_status = (varAppearance and varAppearance.status) or 0
	local cur_collect       = (varAppearance and varAppearance.collect) or 0

	Assert(ret ~= nil, "test_activeSpecialMount, ret is null")
	Assert_eq(except, ret, "test_activeSpecialMount error")

	if except == ret and ret == true then
		Assert(cur_active_status == IsActive or cur_active_status == Permanent ,
			 "test_activeSpecialMount succ status change error")
		Assert(cur_collect - old_collect == 1 , "test_activeSpecialMount succ collect change error")
	end
end

function test_activeSpecialMount(actor)
	LActor.openSys(actor, siMount)  --开启坐骑

	local item_id = SpecialMountItem[1].itemId   --mountitemdatas.lua--> SpecialMountItem
	local use_time = SpecialMountItem[1].duration
	LActor.addItem(actor, item_id, 0, 0, 1, 0)

	handle_activeSpecialMount(actor, item_id, use_time, true)
end
-----------------------------------------END 激活特殊坐骑 END--------------------------------------


--opensys 0 开启坐骑系统（siMount）后才能保存到数据库

TEST("mount", "test_sendMountInfo", test_sendMountInfo)
TEST("mount", "test_enhanceHunger", test_enhanceHunger)
TEST("mount", "test_enhanceSkill", test_enhanceSkill)
TEST("mount", "test_unlockStageUp", test_unlockStageUp)
TEST("mount", "test_mountStageUp", test_mountStageUp)
TEST("mount", "test_changeling", test_changeling)
TEST("mount", "test_strengthen", test_strengthen)
TEST("mount", "test_activeSpecialMount", test_activeSpecialMount)

_G.test_sendMountInfo = test_sendMountInfo
_G.test_enhanceHunger = test_enhanceHunger
_G.test_unlockStageUp = test_unlockStageUp
_G.test_mountStageUp = test_mountStageUp
_G.test_changeling = test_changeling
_G.test_strengthen = test_strengthen
_G.test_activeSpecialMount = test_activeSpecialMount


--一键高富帅
function oneKeyGFS(actor)
	local maxBagGrid = BagConfig.max
	LActor.setIntProperty(actor, P_BAG_GRID, maxBagGrid)
	LActor.setDepotCapacity(actor, ipBag, maxBagGrid)

	LActor.changeMoney( actor, mtBindCoin, 100000, 1, true, "gfs")     --绑定仙币
	LActor.changeMoney( actor, mtCoin, 100000, 1, true, "gfs")         --仙币
	LActor.changeMoney( actor, mtBindYuanbao, 100000, 1, true, "gfs")  --绑定元宝
	LActor.changeMoney( actor, mtYuanbao, 100000, 1, true, "gfs")      --元宝
	LActor.setIntProperty(actor, P_LEVEL,100) 							   --等级
	LActor.recharge(actor, 1000000)         							   --开启仙尊等级
end

_G.oneKeyGFS = oneKeyGFS

