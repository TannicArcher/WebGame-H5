require("systems.instance.instanceevent")
require("utils.utils")
local section = require("systems.instance.play.section_play")
require("systems.instance.play.display") --旧系统中的显示信息模块
require("systems.instance.other.bossinfo")

--section = systems.instance.play.section_play

instanceConfig = InstanceConfig --那边副本配置叫这个名
instance = {
	id = 0,
	type=0,
	handle = nil,
	config = nil,

	scene_list = {},	--这里存创建后的handle

	is_end = false,		--是否结束
	is_win = false,     --是否胜利
	end_time	= 0, 	--逻辑结束时间i
	destroy_time = 0,	--销毁时间
	start_time	= {},	--逻辑开始时间 [0] 对应副本本身， 其他对应场景的
	all_afk_time = nil,	--创建时没有默认塞玩家进来的肯定按固定时间算

	actor_list	= {},	--副本玩家列表 actorId:{afk_time, statistics}
						--afk_time不为0则为掉线， statistics统计信息 --暂时没用
						--rewards 奖励缓存

	kill_monster_cnt = {},	--一共杀死的怪物的数量

	monster_group_record = {}, 	-- 按组刷出的怪记录刷新批次对应的组号，杀死数，总数 index->{gid, kill, total}
	monster_group_map = {}, 	-- 记录怪物组号索引 handle->index
	delay_monsters = {}, --延迟召唤的怪物 time:{[index]=mon}
	monster_group_kill_cnt = {},  --记录死亡组数
    events = {}, -- 事件列表
    eventsIndex = {}, -- 为了保证事件按配置顺序执行，做个索引
	time_events = {},	-- 时间相关条件事件列表
	custem_timer = {},  -- 自定义时间触发器
	delay_actions = {},	--time->{event1,event2,event3}

	display_info = {},    --显示信息: 波数，剩余怪数等
	statistics_index = {}, --统计信息类型索引

    activity_id = 0,
	--drop_list = {},		--物品掉落统计
	--award_list = {},	--奖励统计
	--money_list = {},	--掉落钱统计
	--rewards = {}  掉落奖励，始终不确定到底有没有
	data = {},   --自定义数据，统一放在data里
    --boss_info = {} --bossinfo module使用数据
}

--********************************************************************************--
--外部可以用的接口，也可以通过ins对象直接访问成员
--********************************************************************************--

--获取玩家列表,不包含离线的。 或者直接用ins.actor_list
function instance:getActorList()
	local actor_list = {}
	for k,v in pairs(self.actor_list) do
		if v.afk_time == nil then
			table.insert(actor_list, LActor.getActorById(k))
		end
	end
	return actor_list
end

function instance:getHandle()
    return self.handle
end

function instance:getType()
    return self.type
end

function instance:getFid()
    return self.id
end

function instance:getSceneIndex(scenehandle)
    for i=1,#self.scene_list do
        if self.scene_list[i] == scenehandle then
            return i
        end
    end
    return nil
end

--统计信息接口
function instance:addStatistics(actor, ctype, value)
	--if not self.statistics_index[ctype] then return end
	--insdisplay.addStatistics(self, actor, ctype, value)
end

function instance:getStatisticsInfo(actor)
	if actor == nil then return nil end
	local aid = LActor.getActorId(actor)
	if self.actor_list[aid] == nil then return nil end
	if self.actor_list[aid].statistics == nil then
		self.actor_list[aid].statistics = {}
	end
	return self.actor_list[aid].statistics
end


--****************************************************************************************--
--[[内部逻辑开始
事件机制备忘:
多种类型条件为了支持与或非合并成条件组，为了提高判断效率，做以下处理
1，条件中有时间的事件处理：在副本初始化后单独放到time_events列表中，
    每次循环时检测，可以考虑进一步做time定时器触发后再检测,不过用定时器的话，考虑不同场景的
    独立时间计算，定时器的计时时间不确定，初始化的工作非常麻烦，所以暂时不做
2. 条件中默认是达成状态（比如全否条件和无条件）的事件处理：在副本初始化后单独放进default_events中，
每次循环时检测,并将条件不成立的设置为deactive

其他条件判断的机制:
    1触发相应的条件时检测所有active的事件，有状态变化的事件再去检测事件的条件组是否达成。
    2达成条件的事件执行一次行为组，然后将重复计数器递增，判断是否有loop次数，有的话，重置条件组
    没有loop次数的设置为deactive。
    3事件触发激活的事件，active后重置所有条件和repeated计数器
因为有激活事件的行为，所以执行过的事件不能从列表中清除，只能通过设置active标记来处理
循环事件没有间隔，间隔可以通过type0的时间来处理，复杂条件需要通过激活事件来组合完成！
--]]
--****************************************************************************************--
function instance:new()
	local o = utils.table_clone(self)	--里面的表格默认是引用的instance的，要拷贝或写构造函数
	setmetatable(o, {__index = self});
	--setmetatable(o, self)
	--self.__index = self
	return o;
end

function instance:init(fid, handle, scenelist)
	print("instance init fid:"..fid.. " handle:"..handle)
	local config = instanceConfig[fid]
	if config == nil then 
		print("Init instance failed. id: "..fid)
		return false
	end
	self.id = fid
	self.handle = handle
	self.type = config.type
	self.config = config
	--self.target = config.target

    --复制配置
	self.events = utils.table_clone(config.events)
	--做个索引
	for i,_ in pairs(self.events) do
		table.insert(self.eventsIndex, i)
	end
	table.sort(self.eventsIndex)
    --print("ordered events count:"..#self.events)
    --初始化私有配置
    if self:initEvents() == false then
        print("events init failed")
        return false
    end
    --print("time events:"..#self.time_events)

	--创建场景
	if #scenelist ~= #config.scenes then
		print("init failed scenes count not square "..(#scenelist).." "..(#config.scenes))
		return false
	end

	--初始化默认胜利条件
	self:initWinEvent()

	for i=1, #scenelist do
		self.scene_list[i] = Fuben.getSceneHandlebyPtr(scenelist[i])
	end

	local now_t = System.getNowTime()
	self.start_time[0] = now_t
	if self.config.totalTime and self.config.totalTime > 0 then
		self.end_time = now_t + self.config.totalTime
	end

	if self.config.statistics then
		for _,v in self.config.statistics do
			self.statistics_index[v] = true
		end
	end

	insevent.onInitFuben(self)
	--print("init ins success")
	return true
end

function instance:setEnd()
	self.is_end = true
	Fuben.setEnd(self.handle)
end

function instance:isEnd()
	return self.is_end
end

function instance:initWinEvent()
	--[[local target = self.config.target
	if type == 1 then
		--杀死指定目标
		for _,v in ipairs(target) do
			table.insert(self.monster_events, {type=4,scene = target.scene or 1, count=1,id=v, event=1}}
		end
	elseif type == 2 then
		table.insert(self.monster_events, {type=3, scene = target.scene or 1, event = 1})
	elseif type == 3 then
	elseif type == 4 then
	end
	--]]
end

function instance:onStart(actor)
	local now_t = System.getNowTime()

	local scenehandle = LActor.getSceneHandle(actor)
	local sceneindex = self:getSceneIndex(scenehandle)
	if sceneindex and self.start_time[sceneindex] == nil then
		self.start_time[sceneindex] = now_t
	end
end

function instance:onEnter(actor, isLogin)
	print("instance:onEnter aid:"..LActor.getActorId(actor)..",fbId:"..(self.id)..",isLogin:"..tostring(isLogin))
	--if self.type == 0 then return end 	--0为普通场景
	--创建玩家信息或者清除离线时间
	self:onStart(actor)	-- 在客户端处理前先自己调用
	self:runOne(System.getNowTime()) --在进入的时候;调用一次runOne,处理0延迟的一些东西
	local actorId = LActor.getActorId(actor)
	if self.actor_list[actorId] == nil then
		self.actor_list[actorId] = {}
	else
		self.actor_list[actorId].afk_time = nil
	end
	self.all_afk_time = nil
	
	if self.config.isSaveBlood ~= 1 then 
		LActor.recover(actor)
	end
	--通知奖励信息
	self:notifyRewards(actor)
	insevent.onEnter(self, actor, isLogin)
	insdisplay.notifyDisplay(self, actor)

	--发送进度消息
	--log
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
		"fuben", tostring(self.id), tostring(self.handle), tostring(isLogin), "enter", "", "")
end
-----------------------------奖励相关--------------------------------
function instance:setRewards(actor, rewards)
	local aid = LActor.getActorId(actor)
	self.actor_list[aid].rewards = rewards
	--经验一开始就发
	if rewards then
		for _,v in ipairs(rewards) do
			if v.type == AwardType_Numeric and v.id == NumericType_Exp then
				LActor.addExp(actor, v.count, "chapter fb win")
				v.ng = true
			end
		end
	end	
end

function instance:notifyRewards(actor)
	if not self.is_end then return end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Fuben, Protocol.sFubenCmd_FubenResult)
	if npack == nil then return end

	LDataPack.writeByte(npack, self.is_win and 1 or 0)
	LDataPack.writeShort(npack, self.config.type or 0)
	local actorinfo = self.actor_list[LActor.getActorId(actor)]
	if actorinfo.rewards == nil then actorinfo.rewards = {} end
	LDataPack.writeShort(npack, #actorinfo.rewards)
	for _, v in ipairs(actorinfo.rewards) do
		LDataPack.writeInt(npack, v.type or 0)
		LDataPack.writeInt(npack, v.id or 0)
		LDataPack.writeInt(npack, v.count or 0)
	end
	LDataPack.flush(npack)
end
-----------------------------奖励相关--------------------------------

function instance:win()
	--已经结束的副本不再触发
	if self.is_end then return end
	self:setEnd()
	self.is_win = true
	
	local closeTime = self.config.closeTime or 0
	if self.all_afk_time then closeTime = 0 end
	
	self.destroy_time = System.getNowTime() + closeTime
	
	print("instance:win, fbId:"..(self.id)..", handle:"..tostring(self.handle)..", destroy_time:"..self.destroy_time..", closeTime:"..closeTime)
	--Fuben.killAllMonster(self.handle)
	--发送进度消息
    bossinfo.onTimer(self, System.getNowTime(), true)
	insevent.onWin(self)
end
function instance:lose()
	--已经结束的副本不再触发
	if self.is_end then return end
	self:setEnd()

	local closeTime = self.config.closeTime or 0
	if self.all_afk_time then closeTime = 0 end

	self.destroy_time = System.getNowTime() + closeTime
	
	print("instance:lose, fbId:"..(self.id)..", handle:"..tostring(self.handle)..", destroy_time:"..self.destroy_time..", closeTime:"..closeTime)
	--发送进度消息
	insevent.onLose(self)
end

function instance:release()
	print("instance:release, fbId:"..(self.id)..", handle:"..tostring(self.handle))
	instancesystem.releaseInstance(self.handle)
end

function instance:runOne(now_t)
	--print("run instance.........hdl: "..tostring(self.handle).. "time:"..now_t)
	--正常回收副本
	if self.destroy_time > 0 and now_t > self.destroy_time then
		--回收副本
		self:release()
		return
	end
	
	--副本结束后,并且所有人都离开了副本,并且标记为需要回收, 就提前回收副本
	if self.is_end and self.all_afk_time and self.destroy_time > 0 then
		--回收副本
		self:release()
		return
	end

	--检查离线玩家是否超时
	if self.config.remainTime and self.config.remainTime > 0 then
		if self.all_afk_time and now_t - self.config.remainTime > self.all_afk_time then
			--回收副本
			self:lose()
			self:release()
			return
		end
	end

	if self.end_time > 0 and now_t > self.end_time then
		if not self.is_end then
			--超时失败
			self:lose()
			--让所有怪消失掉
			for _,sceneHdl in pairs(self.scene_list) do
				Fuben.clearAllMonster(sceneHdl)
			end
		end
		return
	end

	if self.is_end then return end

	--时间条件检测
    for _, event in ipairs(self.time_events) do
	    self:tryEvent(event, self.checkTimeTriggerCondition, now_t)
    end

	--自定义定时器检测
	for id, time in pairs(self.custem_timer) do
		if now_t > time then
            self:tryConditions(self.checkCustemTimerTriggerCondition, id)
			self.custem_timer[id] = nil
		end
	end
	--延迟event列表
	for time,actions in pairs(self.delay_actions) do
		if now_t > time then
			for _,action in pairs(actions) do
				self:realDoAction(action)
			end
			self.delay_actions[time] = nil
		end	
	end
	--延迟招怪列表
	for time,monsters in pairs(self.delay_monsters) do
		if now_t > time then
			for gidx,mon in pairs(monsters) do
				self:refreshMonsters(mon, gidx)
			end
			self.delay_monsters[time] = nil
		end
	end
end

function instance:checkAfk()
    --local count = 0
	for _, info in pairs(self.actor_list) do
		if info.afk_time == nil then
			return
        end
    --    count = count + 1
    end
    --if count == 0 and not self.config.isPublic then
    --    self.lose()
    --end

	self.all_afk_time = System.getNowTime()
end

--通过进入副本触发的离开之前副本，正常退出或其他功能拉出会调用
function instance:onExit(actor)
    local actorId = LActor.getActorId(actor)
    self.actor_list[actorId] = nil

    self:checkAfk()
--发送结算结果信息?
    insevent.onExit(self, actor)
    print("instance:onExit, aid:"..actorId..",fbId:"..(self.id)..", handle:"..tostring(self.handle))
	
    --log
    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
	    "fuben", tostring(self.id), tostring(self.handle), "", "exit", "", "")
end

--通过c++ 离开场景触发，暂时只会离线一种情况
function instance:onOffline(actor)
    local actorId = LActor.getActorId(actor)
    local info = self.actor_list[actorId]
    if info then --退出副本触发的，列表已经为空
		info.afk_time = System.getNowTime()
		self:checkAfk()
		insevent.onOffline(self, actor)
		if self.is_end then
			local actorinfo = self.actor_list[LActor.getActorId(actor)]
			if actorinfo and (actorinfo.rewards == nil or #(actorinfo.rewards) <= 0) then
				LActor.exitFuben(actor)
			end
		end
		print("instance:onOffline, aid:"..actorId..",fbId"..(self.id))
	end
    --log
    System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)),
	    "fuben", tostring(self.id), tostring(self.handle), "", "offline", "", "")
end

function instance:onEntityDie(et, killer)
	local entype = LActor.getEntityType(et)	
	if entype == EntityType_Actor then
		self:onActorDie(et, killer)
	elseif entype == EntityType_Monster then
		self:onMonsterDie(et, killer)
	--elseif entype == enGatherMonster then	--采集物走采集系统了，在那边处理的
	--	self:onGather(et, killer)
	elseif entype == EntityType_CloneRole then 
		self:onCloneRoleDie(et,killerHdl)
	elseif entype == EntityType_Role then
		self:onRoleDie(et,killer)
	end
	print("instance:onEntityDie, entype:"..entype..",eid:"..LActor.getId(et)..", fbId:"..(self.id))
end

function instance:onCloneRoleDie(et,killerHdl)
	insevent.onCloneRoleDie(self, et, killerHdl)
end

function instance:onMonsterDie(mon, killerHdl)
	--todo test delete
	--Fuben.createDrop(self.scene_list[1], 0, 0, mon, math.random(0,1), 1, 30 + System.getNowTime())

	--print("-------------------------on monster die--------------------")
	--处理其他模块以fid注册的回调函数 会用到当前波次的状态，所以先执行
	insevent.onMonsterDie(self, mon, killerHdl)
	--处理副本内事件
	local scenehandle = LActor.getSceneHandle(mon)
	local sceneIndex = self:getSceneIndex(scenehandle)
	self.kill_monster_cnt[sceneIndex] = (self.kill_monster_cnt[sceneIndex] or 0) + 1
	--self.kill_monster_cnt[0] = (self.kill_monster_cnt[0] or 0) + 1 --副本本身

	local group_index = self.monster_group_map[LActor.getHandle(mon)]
	--index->{gid, kill, total}
	-- 处理怪物组
	local group_id
	if group_index then
		local record = self.monster_group_record[group_index]
		if record ~= nil then 
			record.kill = record.kill + 1
			if record.kill == record.total then
				group_id = record.gid	
				self.monster_group_record[group_index] = nil --清理的话，group_index没变
				self.monster_group_kill_cnt[sceneIndex] = (self.monster_group_kill_cnt[sceneIndex] or 0) + 1
			end
		end
	end
	self:checkMonsterKillEvent(mon, group_id)
end

function instance:onRoleDie(role, killer_hdl)
	insevent.onRoleDie(self,role,killer_hdl)
end

function instance:onActorDie(actor, killerHdl)
	--处理其他模块回调函数
	insevent.onActorDie(self, actor, killerHdl)
    --现在不考虑，需要根据条件定义需记录数据
    self:tryConditions(self.checkActorDieCondition)
end

function instance:onMonsterCreate(mon)
    --动态属性放在c++还是lua呢？
    print("instance:onMonsterCreate: monster_id:"..Fuben.getMonsterId(mon)..",fbId:"..(self.id))
    insevent.onMonsterCreate(self, mon)

    --test
	--LActor.setIntProperty(mon, P_SPEED, LActor.getIntProperty(mon, P_SPEED)*5)
end

function instance:onSectionTrigger(sect, scenePtr)
    local sceneindex = self:getSceneIndex(Fuben.getSceneHandleByPtr(scenePtr))
    if sceneindex ~= nil then
        print("instance on section trigger "..(sect+1)..",fbId:"..(self.id)..",scene:"..sceneindex)
        self:tryConditions(self.checkSectionTrigger, sect, sceneindex)
    end
end

--设置自定义变量
function instance:onSetCustomVariable(name, value)
	self[name] = value
	self:onChangeCustomVariable(name, value)
end

--获取自定义变量
function instance:onGetCustomVariable(name)
	return self[name] or 0
end

--自定义变量条件
function instance:onChangeCustomVariable(name, value)
	insevent.onVariantChange(self, name, value)
	self:tryConditions(self.checkCustemVariableCondition, name, value)
end

--*********************************************************************************--
--条件相关接口
--*********************************************************************************--

--返回是否有改动
function instance:checkTimeTriggerCondition(condition, now_t)
    if condition.finish == true then return false end
    if condition.type ~= 0 then return false end
    local scene = condition.scene or 1
    if self.start_time[scene] and ((now_t - self.start_time[scene]) >= (condition.time + condition.increment)) then
        condition.finish = true
        return true
    end
    return false
end

--返回是否有改动
function instance:checkCustemTimerTriggerCondition(condition, id)
    if condition.finish == true then return false end
    if condition.type == 6 and condition.id == id then
        condition.finish = true
        return true
    end
    return false
end

--返回是否有改动
function instance:checkActorDieCondition(condition)
    if condition.finish == true then return false end
   if condition.type == 5 then
       condition.diecnt = (condition.diecnt or 0) + 1
       if condition.diecnt >= (condition.count or 1)then
           condition.finish = true
           return true
       end
   end
   return false
end


--检查分段触发
function instance:checkSectionTrigger(condition, sect, scene_index)
    if condition.finish == true then return false end
    if condition.type ~= 7  then return false end
    if (condition.scene or 1) == scene_index  and condition.id == sect + 1 then
        condition.finish = true
        return true
    end
    return false;
end

--检查怪物事件接口
function instance:checkMonsterKillCondition(condition, mon_id, scene_index, all_killed, gid)
	if condition.finish == true then return false end
	if (condition.scene or 1) ~= scene_index then return false end

	if condition.type == 2 then
		condition.cnt = (condition.cnt or 0) + 1
		if condition.count <= condition.cnt then
			condition.finish = true
			return true
		end
	elseif condition.type == 3 and all_killed then
		condition.finish = true
		return true
	elseif condition.type == 4 then
		if condition.id == mon_id then
			condition.killcnt = (condition.killcnt or 0) + 1
			if condition.count <= condition.killcnt then
				condition.finish = true
				return true
			end
		end
	elseif gid and condition.type == 1 and condition.id == gid then
		condition.finish = true
		return true
	end
	return false
end

function instance:checkCustemVariableCondition(condition, name, value)
	if condition.finish == true then return false end
	if condition.type == 8 then
		if condition.name == name and (condition.value == nil or condition.value == value) then
			condition.finish = true
			return true
		end
	end
	return false
end

--返回发现时间条件
function instance:initTimeCondition(condition)
    if condition.type == 0 then
        condition.increment = 0
        condition.finish = false
        return true
    end
    return false
end

--返回否，foreach中多个条件的结果用or获得，所以最终用false判断
function instance:findAllNotCondition(condition)
    if condition.flag == "not" then
        return false
    end
    return true
end

function instance:initEvents()
    for i, event in pairs(self.events) do
        --时间处理优化
        if self:forEachCondition(event.conditions, self.initTimeCondition) == true then
            table.insert(self.time_events, event)
        end
        --全否条件处理优化
        if self:forEachCondition(event.conditions, self.findAllNotCondition) == false then
            print("init failed, invalid conditions in event: ".. i)
            return false
        end
        self:initEvent(event)
    end
    return true
end

function instance:initEvent(event)
    event.repeated = 0
    self:forEachCondition(event.conditions, self.resetConditionFunc)
end

function instance:resetConditionFunc(condition)
    if condition.flag == "not" then return end
    condition.finish = false
    if condition.type == 0 then
	    local s = self.start_time[condition.scene or 1]
	    if s == nil then
		    condition.increment = 0
	    else
		    condition.increment = System.getNowTime() - s
	    end
    elseif condition.type == 2 then
        condition.cnt = 0
    elseif condition.type == 4 then
        condition.killcnt = 0
    elseif condition.type == 5 then
        condition.diecnt = 0
    end
end


function instance:checkMonsterKillEvent(mon, gid)
	local mon_id = Fuben.getMonsterId(mon)	
	local sceneHdl = LActor.getSceneHandle(mon)
	local scene_index = self:getSceneIndex(sceneHdl)
	local isAllKilled = Fuben.isKillAllMonster(sceneHdl)

    self:tryConditions(self.checkMonsterKillCondition, mon_id, scene_index, isAllKilled, gid)
end

function instance:refreshMonsterGroup(gid)
	--print("instance do action 3 . gid:"..gid)
	if self.config.monsterGroup == nil then return end
	local monsters = self.config.monsterGroup[gid]
	if monsters == nil then return end

	local gidx = #self.monster_group_record + 1

	self.monster_group_record[gidx] = {}
	local record = self.monster_group_record[gidx]
	record.gid = gid
	record.kill = 0

	local now, count = System.getNowTime(), 0
	for _,mon in ipairs(monsters) do
		if mon.delay and mon.delay > 0 then
			local t = now + mon.delay
			if self.delay_monsters[t] == nil  then self.delay_monsters[t] = {} end
			self.delay_monsters[t][gidx] = mon
		else
			self:refreshMonsters(mon, gidx)
		end
		count = count + (mon.count or 1)
	end
	record.total = count
end

function instance:refreshMonsters(mon, gidx)
	local px, py, count = mon.posX or 0, mon.posY or 0, 0
	for i=1,(mon.count or 1) do
		if mon.rangeX or mon.rangeY then
			px = mon.posX + System.getRandomNumber((mon.rangeX or 0)+1)
			py = mon.posY + System.getRandomNumber((mon.rangeY or 0)+1)
		end

		local monster = Fuben.createMonster(self.scene_list[mon.scene or 1], mon.monId, px, py, mon.liveTime or 0)
		if monster then
			self.monster_group_map[LActor.getHandle(monster)] = gidx
		else
			print("create monster failed. ins:"..self.id.." gid:"..self.monster_group_record[gidx].gid)
		end
	end
	return count
end

function instance:checkConditions(conditions)
    if conditions.flag == "or" then
        local ret = false
        for _, condition in ipairs(conditions) do
            ret = ret or self:checkConditions(condition)
        end
        return ret
    elseif conditions.flag == "and" then
        local ret = true
        for _, condition in ipairs(conditions) do
            ret = ret and self:checkConditions(condition)
        end
        return ret
    elseif conditions.flag == "is" or conditions.flag == nil then
        if conditions.finish == true then
            return true
        else
            return false
        end
    elseif conditions.flag == "not" then
        if (conditions.finish == false or conditions.finish == nil) then
            return true
        else
            return false
        end
    else
        return false
    end
end

function instance:tryEvent(event, func, ...)
	if event.conditions ~= nil then
		if event.active == nil or event.active == true then
			if self:forEachCondition(event.conditions, func, ...) == true then --状态有变化
				if self:checkConditions(event.conditions) == true then   --验证条件集合
					self:doActions(event.actions)   --执行行为列表
					event.repeated = (event.repeated or 0) + 1
					if event.loop ~= 0 and event.repeated >= (event.loop or 1) then
						event.active = false
					else
						self:forEachCondition(event.conditions, self.resetConditionFunc)
					end
				end
			end
		end
	end
end

function instance:tryConditions(func, ...)
    if self.is_end then return end
    for _, i in ipairs(self.eventsIndex) do
		self:tryEvent(self.events[i], func, ...)
    end
end

function instance:forEachCondition(conditions, func, ...)
   if conditions.flag == "or" or conditions.flag == "and" then
       local ret = false
       for _, condition in ipairs(conditions) do
           ret = ret or self:forEachCondition(condition, func, ...)
       end
       return ret
   else
       return func(self, conditions, ...)
   end
end


--**************************************************************--
--事件相关
--**************************************************************--
function instance:doActions(actions)
    for _, action in ipairs(actions) do
        self:doAction(action)
    end
end

function instance:doAction(action)
	print("instance:doAction, type:"..action.type..",fbId:"..(self.id)..",handle:"..self.handle)
	if action.delay == nil or action.delay == 0 then
		self:realDoAction(action)
	else
		local time = System.getNowTime() + action.delay
		self.delay_actions[time] = self.delay_actions[time] or {}
		table.insert(self.delay_actions[time], action)
	end
end

-- action处理函数
local actionfunctions = {}
actionfunctions[1] = function(self, action)
	self:win()	
end
actionfunctions[2] = function(self, action)
	self:lose()	
end
actionfunctions[3] = function(self, action)
	self:refreshMonsterGroup(action.id)
end
actionfunctions[4] = function(self, action)
	--todo 发消息告诉客户端进入哪个屏
	local sceneidx = action.scene or 1
	local sceneHdl = self.scene_list[sceneidx]
	if sceneHdl == nil then return end
	section.SetSectionPass(sceneHdl, action.id - 1)
	print("===========set sect pass: scene:"..tostring(sceneidx).." sect:"..tostring(action.id).."============")
end
actionfunctions[5] = function(self, action)
	--insdisplay.setDisplay(self, action)
end
actionfunctions[6] = function(self, action)
	self.custem_timer[action.id] = System.getNowTime() + (action.time or 0)
	print("===========fb action 6: set timer id: param:"..tostring(action.id).." time:"..tostring(action.time).."============")
end
actionfunctions[7] = function(self, action)
	if action.id == nil then return end

	self.custem_timer[action.id] = nil
	print("===========fb action 7: delete timer id:"..tostring(action.id).."============")
end

actionfunctions[8] = function(self, action)
	local sceneidx = action.scene or 1
	local sceneHdl = self.scene_list[sceneidx]
	if sceneHdl == nil then return end
	if action.kill == true then
		Fuben.killAllMonster(sceneHdl)
	else
		Fuben.clearAllMonster(sceneHdl)--, action.id or 0)
	end
end

actionfunctions[9] = function(self, action)
	print("on action 9")
    if action.id == nil then return end
    local event = self.events[action.id]
    if event == nil or event.active == true then return end --这里有待考虑
    event.active = true
    self:initEvent(event)
    print("active event:"..action.id)
end

actionfunctions[10] = function(self, action)
	if action.groups == nil then return end
	local r = math.random(0,99)
	for group, rate in pairs(action.groups) do
		if r < rate then
			self:refreshMonsterGroup(group)
			return
		end
		r = r - rate
	end
end

actionfunctions[11] = function(self, action)
	if action.drops == nil then return end
	local rate = math.random(0, 99)
	for _, drop in ipairs(action.drops) do
		if rate < drop.rate then
			local sceneidx = action.scene or 1
			local sceneHdl = self.scene_list[sceneidx]
			dropsys.createDropById(sceneHdl, drop.id, action.x, action.y)
		end
	end
end

actionfunctions[12] = function(self, action)
	if action.name == nil then return end
	if self[action.name] == nil then self[action.name] = 0 end
	if action.method=="change" then
		self[action.name] = self[action.name] + (action.value or 1)
	elseif action.method == "set" then
		self[action.name] = (action.value or 1)
	else
		self[action.name] = self[action.name] + 1
	end
	self:onChangeCustomVariable(action.name, self[action.name])
end

actionfunctions[13] = function(self, action)
	if action.events == nil then return end
	local r = math.random(0,99)
	for id, rate in pairs(action.events) do
		if r < rate then
			local event = self.events[id]
			if event == nil or event.active == true then return end --这里有待考虑
			event.active = true
			self:initEvent(event)
			print("active event:"..id)
			return
		end
		r = r - rate
	end
end

actionfunctions[14] = function(self, action)
	if action.name == nil then 
		print("instance action.name is nil")
		return 
	end
	insevent.callCustomFunc(self, action.name)
end

actionfunctions[15] = function(self, action)
	if action.rewards == nil then 
		print("instance fbId:"..(self.id)..", action.rewards is nil")
		return 
	end
	for actorId,v in pairs(self.actor_list) do
		if v.afk_time == nil then
			local actor = LActor.getActorById(actorId)
			LActor.giveAwards(actor, action.rewards, "fuben action_15 :"..self.id)
		end
	end
end

function instance:realDoAction(action)
	eventfunc = actionfunctions[action.type]
	if eventfunc ~= nil then
		eventfunc(self, action)
	end
end


--**************************************************************--
--其他接口
--**************************************************************--
--[[local actorreward = require("systems.actorsystem.actorrep")
local actormoney = require("systems.actorsystem.actormoney")
function instance:onUseSkill(actor, index)
	if self.config.skills == nil then return false end

	local skill = self.config.skills[index]
	if skill == nil then return false end
	--检查消耗
	if skill.consume ~= nil then
		if not actorreward.costRes(skill.consume.type, skill.consume.id or 0, skill.consume.count or 1, "FBSkillConsume") then
			if not actormoney.consumeMoney(actor, mtYuanbao, -skill.yb, 1, true, "FBSkillConsume", "YBConsume") then
				print("扣除消耗或元宝失败,无法使用副本技能")
				return false
			end
		end
	end
	--释放
	LActor.useSkill(actor, skill.id, 0, 0, false, 1)
	print("使用副本技能:"..skill.id)
	return true
end
--]]
