module("togetherhit", package.seeall)
--合击技能系统

--[[ 数据结构
togetherHitData = {
	level = 技能等级
	zsLevel  已经公告过的合击套装等级，大于这个等级才能广播
}
]]

--获取合击系统静态变量数据
local function getVarData(actor)
	local var = LActor.getStaticVar(actor)
	if var == nil then 
		return nil
	end
	--初始化静态变量的数据
	if var.togetherHitData == nil then
		var.togetherHitData = {}
		var.togetherHitData.level = 0
	end
	return var.togetherHitData
end

--齐鸣公告
function broadcastNotice(actor, zsLevel, level, noticeId)
	local SVar = getVarData(actor)
	local totalLevel = zsLevel*1000+level
	if (SVar.zsLevel or 0) < totalLevel then
		local value = zsLevel > 0 and zsLevel or level
		noticemanager.broadCastNotice(noticeId, LActor.getName(actor) or "", tostring(value))
		SVar.zsLevel = totalLevel
	end
end

local function initAttr(actor)
	local ex_attr = LActor.getTogetherHitSkillExAttr(actor)
	if ex_attr == nil then return end
	ex_attr:Reset()
	local SVar = getVarData(actor)
	if SVar.level and SVar.level > 0 then
		--获取合击技能配置
		local THCfg = TogetherHitConfig[SVar.level]
		if not THCfg then 
			print("TogetherHit: initRoleSkill level("..SVar.level..") not have config")
			return
		end		
		for _,v in ipairs(THCfg.exAttr or {}) do
			ex_attr:Add(v.type, v.value)		
		end
		LActor.reCalcExAttr(actor)
	end
end


--初始化学习角色技能
local function initRoleSkill(actor)
	local SVar = getVarData(actor)
	if SVar.level and SVar.level > 0 then
		--获取合击技能配置
		local THCfg = TogetherHitConfig[SVar.level]
		if not THCfg then 
			print("TogetherHit: initRoleSkill level("..SVar.level..") not have config")
			return
		end
		if not THCfg.skill_id then
			print("TogetherHit: initRoleSkill not have skill_id config")
			return
		end
		local job = LActor.getJob(actor)
		local skill_id = THCfg.skill_id
		if type(skill_id) == "table" then
			skill_id = skill_id[job]
		end
		if not skill_id then
			print("TogetherHit: initRoleSkill job("..job..") not have skill_id config")
			return
		end
		LActor.AddSkill(actor, skill_id)
	end
end

--任务条件进度函数
local UpLvConditionFunc = {}
--通关波数 16
UpLvConditionFunc[16] = function(actor)
	local data = chapter.getStaticData(actor)
	return data.level or 0
end

--检查条件是否满足
local function CheckActiveUpLvCondition(actor, THCfg)
	for _,cond in ipairs(THCfg.condition) do
		local v = 0
		local func = UpLvConditionFunc[cond.t]
		if func then
			v = func(actor)
		end
		if v < cond.v then
			return false
		end
	end
	return true
end

--下发和更新升级条件进度
local function SendLvUpCondData(actor, NoticeData)
	local NoticeDataLen = table.getn(NoticeData or {})
	if NoticeDataLen <= 0 then return end --没有数据要下发
	--申请数据包,通知客户端更新条件完成进度
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_TogetherHitLvUpCond)
	if not npack then return end
	LDataPack.writeByte(npack, NoticeDataLen)
	for k,v in ipairs(NoticeData) do
		LDataPack.writeByte(npack, v.idx)
		LDataPack.writeUInt(npack, v.val)
	end
	LDataPack.flush(npack)
end

--获取玩家下一个没有死亡的角色
local function GetRoleByNotDie(actor)
	local role_count = LActor.getRoleCount(actor)
	for i = 0,role_count-1 do
		local role = LActor.getRole(actor, i)
		if not LActor.isDeath(role) then
			return role
		end
	end
	return nil
end

--下发合击技能的等级
function sendTogetherHitLv(actor)
	local SVar = getVarData(actor)--获取静态变量
	local level = SVar.level or 0
	local skill_cd = 0
	if level > 0 then
		--获取配置配置
		local NextTHCfg = TogetherHitConfig[level]
		if NextTHCfg then
			local role = LActor.getRole(actor, 0)
			if role then
				local job = LActor.getJob(actor)
				local skill_id = NextTHCfg.skill_id
				if type(skill_id) == "table" then
					skill_id = skill_id[job]
				end
				if skill_id and skill_id > 0 then
					skill_cd = LActor.GetSkillLaveCD(role, skill_id)
				end
			end
		end
	end
	--申请数据包
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_TogetherHitLv)
	if not npack then return end
	LDataPack.writeUInt(npack, level)
	LDataPack.writeUInt(npack, skill_cd)
	LDataPack.flush(npack)
end

--请求升级和激活技能
local function reqActiveUpLv(actor)
	local SVar = getVarData(actor)--获取静态变量
	local level = SVar.level or 0
	--获取下一级的配置,如果没有就是满级了
	local NextTHCfg = TogetherHitConfig[level+1]
	if not NextTHCfg then
		print("TogetherHit: reqActiveUpLv level("..level..") not have next level config, is max level")
		return
	end
	--判断条件是否满足
	if not CheckActiveUpLvCondition(actor, NextTHCfg) then
		print("TogetherHit: reqActiveUpLv level("..level..") next level Condition is not ")
		return
	end
	SVar.level = level + 1
	actorevent.onEvent(actor, aeActTogetherhit, SVar.level)
	--通知客户端更新
	sendTogetherHitLv(actor)
	if level > 0 then
		local THCfg = TogetherHitConfig[level]
		if THCfg and THCfg.skill_id then
			local job = LActor.getJob(actor)
			local skill_id = THCfg.skill_id
			if type(skill_id) == "table" then
				skill_id = skill_id[job]
			end
			if skill_id and skill_id > 0 then
				LActor.DelSkill(Actor, skill_id)
			end
		end
	end
	--学习技能
	initRoleSkill(actor)
	--初始化属性
	initAttr(actor)
end

--请求使用技能
local function reqUsedSkill(actor, packet)
	local SVar = getVarData(actor)--获取静态变量
	local level = SVar.level or 0
	if level <= 0 then return end --都还没激活技能
	--获取配置配置
	local THCfg = TogetherHitConfig[level]
	if not THCfg then
		print("TogetherHit: reqUsedSkill level("..level..") is not have config")
		return
	end
	--获取一个没有挂的角色
	local role = GetRoleByNotDie(actor)
	if not role then return end
	--判断技能CD
	local job = LActor.getJob(actor)
	local skill_id = THCfg.skill_id
	if type(skill_id) == "table" then
		skill_id = skill_id[job]
	end
	local left_cd = LActor.GetSkillLaveCD(role, skill_id)
	if left_cd > 0 then
		return
	end
	--使用技能
	LActor.useSkill(role, skill_id)
	--下发新的技能CD
	sendTogetherHitLv(actor)
end

--玩家登陆时候触发
local function onLogin(actor)
	local SVar = getVarData(actor)--获取静态变量
	if SVar.level and SVar.level > 0 then
		sendTogetherHitLv(actor)
		initRoleSkill(actor) --初始化角色技能
	end
	
	LActor.TogetherHitInfoSync(actor)
end


local function onInit(actor)
	local SVar = getVarData(actor)--获取静态变量
	if SVar.level and SVar.level > 0 then
		initRoleSkill(actor) --初始化角色技能
		initAttr(actor)
	end	
	LActor.SetTogeLv(actor, SVar.level or 0)
end

function gmSetLv(actor,level)
	local SVar = getVarData(actor)--获取静态变量
	SVar.level = level
end

function gmUsedskill(actor)
	reqUsedSkill(actor)
end

function getSkillId(actor)
	local SVar = getVarData(actor)--获取静态变量
	local level = SVar.level or 0
	local THCfg = TogetherHitConfig[level]
	if not THCfg then return 0 end

	local job = LActor.getJob(actor)
	local skill_id = THCfg.skill_id
	if type(skill_id) == "table" then
		skill_id = skill_id[job]
	end
	return skill_id or 0
end

--进入副本的时候
local function onEnterFuben(actor, fubenId, isLogin)
	local SVar = getVarData(actor)--获取静态变量
	local level = SVar.level or 0
	if level <= 0 then return end --都还没激活技能
	--获取配置配置
	local THCfg = TogetherHitConfig[level]
	if not THCfg then
		print("TogetherHit: onEnterFuben level("..level..") is not have config")
		return
	end
	--获取技能ID
	local job = LActor.getJob(actor)
	local skill_id = THCfg.skill_id
	if type(skill_id) == "table" then
		skill_id = skill_id[job]
	end
	--获取技能CD时间
	local SkillCfg = SkillsConfig[skill_id]
	if not SkillCfg then
		print("TogetherHit: onEnterFuben level("..level..") skill_id("..skill_id..") is not skill config")
		return
	end
	LActor.SetAllRoleSkillCdById(actor, skill_id, SkillCfg.cd or 0, 10)
	--下发新的技能CD
	sendTogetherHitLv(actor)
end

local function onActImba(actor, id)
	if id == TogerherHitBaseConfig.actImbaId then
		reqActiveUpLv(actor)
	end
end

local function init()
	actorevent.reg(aeInit, onInit)
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeEnterFuben, onEnterFuben)
	actorevent.reg(aeActImba, onActImba)
	netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_TogetherHitActUplv, reqActiveUpLv)
	netmsgdispatcher.reg(Protocol.CMD_Skill, Protocol.cSkillCmd_UseTogetherHit, reqUsedSkill)

end

table.insert(InitFnTable, init)

