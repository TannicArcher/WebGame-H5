--神兵养成
module("godweaponbase", package.seeall)

--[[
godweapon=
{
	exp = 0,
	job = nil,
	taskId = nil,
	status = nil,
	value = nil,
	taskRecord = {
		[taskId] = {status = nil,value = nil,}
	},
	weapon = {
		[1] = {exp, level},
		[2] = {exp, level},
		[3] = {exp, level},
	}
}
]]

local p = Protocol
local function getActorVar(actor)
	if not actor then return end

	local var = LActor.getStaticVar(actor)
	if not var then return end

	if not var.godweapon then
		var.godweapon = {};

		var.godweapon.exp = 0	--经验
		var.godweapon.weapon = {}	--3个神兵的信息
	end

	return var.godweapon;
end

function onSendExpInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, p.CMD_GodWeapon, p.sGodWeaponCmd_UpdateExpInfo)
	if not pack then return end
	LDataPack.writeInt(pack, var.exp)
	LDataPack.flush(pack)
end

function getGodWeaponCount(actor)
	local var = getActorVar(actor)
	if not var then return 0 end

	local jobVar = var.weapon

	local count = 0
	for i = 1, GodWeaponBaseConfig.godWeaponCount do
		if jobVar[i] then
			count = count + 1
		end
	end

	return count
end

function onSendInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local jobVar = var.weapon
	local pack = LDataPack.allocPacket(actor, p.CMD_GodWeapon, p.sGodWeaponCmd_UpdateAllInfo)
	if not pack then return end

	local writeInt = LDataPack.writeInt
	local writeData = LDataPack.writeData

	LDataPack.writeInt(pack, getGodWeaponCount(actor))
	local GodWeaponLineConfig = GodWeaponLineConfig
	for i = 1, GodWeaponBaseConfig.godWeaponCount do
		if jobVar[i] then
			local data = jobVar[i]
			writeData(pack, 4, dtInt, i, dtInt, data.level or 0, dtInt, data.exp or 0, dtInt, data.left or 0)

			--技能信息
			if not data.skill then
				writeInt(pack, 0)
			else
				local skillTmp = {}
				local skillCount = 0
				for skillIdx, _ in pairs(GodWeaponLineConfig[i]) do
					if data.skill[skillIdx] then
						skillTmp[skillIdx] = data.skill[skillIdx]
						skillCount = skillCount + 1
					end
				end

				writeInt(pack, skillCount)
				for skillIdx, skillValue in pairs(skillTmp) do
					writeData(pack, 2, dtInt, skillIdx, dtInt, skillValue)
				end
			end

			--圣物信息
			if not data.item then
				writeInt(pack, 0)
			else
				local itemTmp = {}
				local itemCount = 0
				for i = 1, GodWeaponBaseConfig.weaponItemCount do
					if data.item[i] then
						itemTmp[i] = data.item[i]
						itemCount = itemCount + 1
					end
				end

				writeInt(pack, itemCount)
				for pos, itemId in pairs(itemTmp) do
					writeData(pack, 2, dtInt, pos, dtInt, itemId)
				end
			end
		end
	end
	LDataPack.flush(pack)
end

--增加经验
function addGodWeaponExp(actor, exp, log)
	local var = getActorVar(actor)
	if not var then return end

	var.exp = var.exp + exp

	onSendExpInfo(actor)

	local expLog = string.format("%s_%s", var.exp, exp)
	System.logCounter(LActor.getActorId(actor), LActor.getAccountName(actor), tostring(LActor.getLevel(actor)), "godweapon", expLog, log or "")
end

function checkOpen(actor)
	if System.getOpenServerDay() < GodWeaponBaseConfig.openDay
		or LActor.getZhuanShengLevel(actor) < GodWeaponBaseConfig.zhuanshengLevel then
		print("godweapon.checkOpen false, actorId:"..tostring(LActor.getActorId(actor)))
		return false
	end

	return true
end

--升级
function levelUp(actor, packet)
	local job = LDataPack.readInt(packet)

	if not checkOpen(actor) then return end
	if job < 1 or job > GodWeaponBaseConfig.godWeaponCount then return end

	local var = getActorVar(actor)
	if not var or not var.weapon[job] then return end

	local jobVar = var.weapon[job]
	local oldLevel = jobVar.level or 0
	if not GodWeaponLevelConfig[oldLevel] then
		print("godweapon error not has this level config "..oldLevel)
		-- LActor.sendTipmsg(actor, "没有这个等级配置 "..oldLevel)
		return
	end

	local conf = GodWeaponLevelConfig[oldLevel]
	if var.exp < conf.everyExp then
		print("godweapon not enough exp ")
		-- LActor.sendTipmsg(actor, "不够经验")
		return
	end

	var.exp = var.exp - conf.everyExp
	jobVar.exp = (jobVar.exp or 0) + conf.everyExp
	if jobVar.exp >= conf.exp then
		if not GodWeaponLevelConfig[oldLevel + 1] then
			print("godweapon.levelUp conf nil, level:"..tostring(oldLevel + 1))
			return
		end

		jobVar.exp = jobVar.exp - conf.exp
		jobVar.level = oldLevel + 1
		if 0 == jobVar.level % GodWeaponBaseConfig.needLevel then
			jobVar.left = (jobVar.left or 0) + 1	--剩余可使用的技能点数
		end

		updateAttr(actor)
	end

	onSendExpInfo(actor)
	onSendInfo(actor)
end

--更新属性
function updateAttr(actor)
	local attr = LActor.getGodWeaponAttr(actor)
	attr:Reset()

	local exAttr = LActor.getGodWeaponExAttr(actor)
	exAttr:Reset()

	local var = getActorVar(actor)
	if not var then return end

	LActor.clearGodWeaponActId(actor)
	LActor.clearGodWeaponPower(actor)

	local skillList = {}
	local isPeak = false
	local totalLevel = 0
	local GodWeaponLevelConfig = GodWeaponLevelConfig
	for i = 1, GodWeaponBaseConfig.godWeaponCount do
		local learnSkillList = {}
		local passiveSkillList = {}
		local power = 0
		if var.weapon[i] then
			local data = var.weapon[i]
			totalLevel = totalLevel + (data.level or 0)
			--基本神兵属性
			if GodWeaponLevelConfig[data.level or 0] then
				local levelConf = GodWeaponLevelConfig[data.level or 0]
				local levelAttrConf = levelConf.attr1
				if i == 2 then
					levelAttrConf = levelConf.attr2
				elseif i == 3 then
					levelAttrConf = levelConf.attr3
				end
				for _, attrConf in pairs(levelAttrConf or {}) do
					--attrList[attrConf.type] = (attrList[attrConf.type] or 0) + attrConf.value
					attr:Add(attrConf.type, attrConf.value)
				end
			end

			local godSkillConfig = GodWeaponLineConfig[i]
			if data.skill then
				--技能属性
				for skillIdx, v in pairs(godSkillConfig) do
					local skillLevel = data.skill[skillIdx]
					if skillLevel then
						for _, attrConf in pairs(v.attr or {}) do
							attr:Add(attrConf.type, attrConf.value * skillLevel)
						end

						for _, attrConf in pairs(v.exattr or {}) do
							exAttr:Add(attrConf.type, attrConf.value * skillLevel)
						end

						if v.skill then
							if not skillList[v.skill] then skillList[v.skill] = {} end
							skillList[v.skill][skillIdx] = (skillList[v.skill][skillIdx] or 0) + skillLevel
						end

						if v.newskill then learnSkillList[v.newskill] = (learnSkillList[v.newskill] or 0) + skillLevel end

						if v.passiveskill then passiveSkillList[v.passiveskill] = (passiveSkillList[v.passiveskill] or 0) + skillLevel end

						if v.exPower then power = power + (v.exPower*skillLevel) end

						--是否开启了巅峰
						if skillIdx == #godSkillConfig and not isPeak then isPeak = true end
					end
				end
			end
			if data.item then
				--圣物属性
				local GodweaponItemConfig = GodweaponItemConfig
				for i = 1, GodWeaponBaseConfig.weaponItemCount do
					if data.item[i] then
						local conf = GodweaponItemConfig[data.item[i]]
						for _, skillIdx in pairs(conf.skill or {}) do
							for _, attrConf in pairs(godSkillConfig[skillIdx].attr or {}) do
								attr:Add(attrConf.type, attrConf.value)
							end

							for _, attrConf in pairs(godSkillConfig[skillIdx].exattr or {}) do
								exAttr:Add(attrConf.type, attrConf.value)
							end


							local cfg = godSkillConfig[skillIdx]
							if cfg.skill then
								if not skillList[cfg.skill] then skillList[cfg.skill] = {} end
								skillList[cfg.skill][skillIdx] = (skillList[cfg.skill][skillIdx] or 0) + 1
							end

							if cfg.passiveskill then passiveSkillList[cfg.passiveskill] = (passiveSkillList[cfg.passiveskill] or 0) + 1 end

							if cfg.newskill then learnSkillList[cfg.newskill] = (learnSkillList[cfg.newskill] or 0) + 1 end

							if cfg.exPower then power = power + cfg.exPower end

							--是否开启了巅峰
							if skillIdx == #godSkillConfig and not isPeak then isPeak = true end
						end

						for _, attrConf in pairs(conf.attr or {}) do
							--attrList[attrConf.type] = (attrList[attrConf.type] or 0) + attrConf.value
							attr:Add(attrConf.type, attrConf.value)
						end
					end
				end
			end
		end
		--学习新技能
		for k, v in pairs(learnSkillList or {}) do
			local role = LActor.GetRoleByJob(actor, i)
			if role then
				--不管有没有学了，删了再说
				LActor.DelSkillById(role, k)
			    --再学
			    LActor.AddSkill(role, k*1000+v)
			end
		end

		--学习新被动技能
		for k, v in pairs(passiveSkillList or {}) do
			local role = LActor.GetRoleByJob(actor, i)
			if role then
				--不管有没有学了，删了再说
				LActor.DelPassiveSkillById(role, k)
			    --再学
			    LActor.AddPassiveSkill(role, k*1000+v)
			end
		end

		--保存额外战力
		LActor.setGodWeaponPower(actor, i, power)
	end

	--保存巅峰信息
	if isPeak then LActor.setGodWeaponPeak(actor, 1) end

	--保存神兵总等级
	LActor.setGodWeaponLevel(actor, totalLevel)

	--原有技能的提升
	for skill, data in pairs(skillList) do
		for idx, level in pairs(data) do LActor.addGodWeaponActId(actor, skill, idx*1000 + level) end
	end

	LActor.reCalcAttr(actor)
	LActor.reCalcExAttr(actor)
end

--点亮技能
function pointSkill(actor, packet)
	local weaponIdx, skillIdx = LDataPack.readData(packet, 2, dtInt, dtInt)

	if not checkOpen(actor) then return end
	if not GodWeaponLineConfig[weaponIdx] or not GodWeaponLineConfig[weaponIdx][skillIdx] then
		return
	end

	local config = GodWeaponLineConfig[weaponIdx][skillIdx]
	local var = getActorVar(actor)
	if not var or not var.weapon or not var.weapon[weaponIdx] then return end

	local jobVar = var.weapon[weaponIdx]
	if not jobVar.skill then
		jobVar.skill = {}	--skill[skillIdx] = 等级
	end

	local skillVar = jobVar.skill;
	local oldSkillLevel = skillVar[skillIdx] or 0;
	if oldSkillLevel >= config.upLevel then
		print("godweapon error is the max level, level:"..oldSkillLevel)
		-- LActor.sendTipmsg(actor, "已达到升级的最大等级")
		return
	end

	if not jobVar.left or jobVar.left <= 0 then
		print("godweapon not has left skill count ")
		-- LActor.sendTipmsg(actor, "没有可使用的技能点数")
		return
	end

	--前置条件
	if config.condition then
		for id, value in pairs(config.condition) do
			if (jobVar.skill[id] or 0) < value then
				print("godweapon error, the condition is not accord, count:"..tostring(jobVar.skill[id]))
				-- LActor.sendTipmsg(actor, "前置条件不符合 "..id)
				return
			end
		end
	end

	jobVar.left = jobVar.left - 1
	jobVar.skill[skillIdx] = oldSkillLevel + 1

	onSendInfo(actor)
	updateAttr(actor)
end

--镶嵌圣物
function fitGodItem(actor, packet)
	local job, pos, itemId = LDataPack.readData(packet, 3, dtInt, dtInt, dtInt)

	if not checkOpen(actor) then return end
	if job < 1 or job > GodWeaponBaseConfig.godWeaponCount then return end
	if pos < 1 or pos > GodWeaponBaseConfig.weaponItemCount then return end

	if not GodweaponItemConfig[itemId] then print("godweapon.fitGodItem:conf nil, id :"..tostring(itemId)) return end
	if LActor.getItemCount(actor, itemId) < 1 then print("godweapon.fitGodItem:not enough count") return end

	local itemConfig = GodweaponItemConfig[itemId]

	if itemConfig.job and itemConfig.job ~= 0 and itemConfig.job ~= job then
		print("godweapon.fitGodItem:job not same, job:"..tostring(job))
		return
	end

	local var = getActorVar(actor)
	if not var or not var.weapon[job] then return end

	local jobVar = var.weapon[job]
	if not jobVar.item then
		jobVar.item = {}	--已装备的圣物id
	end

	if itemConfig.onlyOne then
		local hasInsertCount = 0
		for i = 1, GodWeaponBaseConfig.weaponItemCount do
			if jobVar.item[i] and jobVar.item[i] == itemId then
				hasInsertCount = hasInsertCount + 1
			end
		end
		if hasInsertCount >= itemConfig.onlyOne then
			print("godweapon error, this item is the onlyOne "..itemId)
			-- LActor.sendTipmsg(actor, "唯一标识  "..itemId)
			return
		end
	end

	--返还已穿戴的装备
	if jobVar.item[pos] then LActor.giveItem(actor, jobVar.item[pos], 1, "GodItem unequip") end

	LActor.costItem(actor, itemId, 1, "godweapon")
	jobVar.item[pos] = itemId

	onSendInfo(actor)
	updateAttr(actor)
end

--神兵任务
local function onSendTaskInfo(actor)
	local var = getActorVar(actor)
	if not var then return end

	local pack = LDataPack.allocPacket(actor, p.CMD_GodWeapon, p.sGodWeaponCmd_TaskInfo)
	if not pack then return end

	LDataPack.writeData(pack, 5,
			dtInt, getGodWeaponCount(actor) + 1,
			dtInt, var.job or 0,
			dtInt, var.taskId or 0,
			dtInt, var.value or 0,
			dtInt, var.status or 0)

	LDataPack.flush(pack)
end

--接任务
local function acceptTask(actor, packet)
	local job = LDataPack.readInt(packet)

	if not LActor.GetRoleByJob(actor, job) then
		-- LActor.sendTipmsg(actor, "你没有开启这个角色")
		return
	end

	local var = getActorVar(actor)
	if not var then return end

	if var.taskId or var.job then
		--已经接了任务的
		return
	end

	if var.weapon[job] then
		--这个神兵已经开启了
		return
	end

	var.job = job 	--当前正在进行的任务 职业
	var.taskId = 1 	--当前正在进行的任务 idx
	var.value = 0 	--当前任务进度
	var.status = taskcommon.statusType.emDoing	--当前任务状态

	onSendTaskInfo(actor)
end

--完成任务
local function finishTask(actor)
	local var = getActorVar(actor)
	if not var or not var.job or not var.taskId then return end

	local GodWeaponTaskConfig = GodWeaponTaskConfig

	local nowId = var.taskId
	local job = var.job
	if not GodWeaponTaskConfig[job][nowId + 1] then
		if var.status == taskcommon.statusType.emHaveAward then
			--激活
			var.weapon[job] = {}
			var.weapon[job].exp = 0
			var.weapon[job].level = 1

			var.job = nil
			var.taskId = nil
			var.status = nil
			var.value = nil
			var.taskRecord = nil

			onSendInfo(actor)
		else
			--完成任务状态
			var.status = taskcommon.statusType.emHaveAward
		end
	else
		--下一个任务
		var.taskId = nowId + 1
		if nil ~= var.taskRecord and nil ~= var.taskRecord[var.taskId] then
			--有记录
			var.value = var.taskRecord[var.taskId].value
			var.status = var.taskRecord[var.taskId].status
			var.taskRecord[var.taskId] = nil  --顺手消除记录
		else
			var.value = 0
			var.status = taskcommon.statusType.emDoing
		end
	end

	onSendTaskInfo(actor)
end

--重置技能
local function resetSkill(actor, weaponIdx)
	local actorId = LActor.getActorId(actor)

	if not checkOpen(actor) then return end

	--钱够不够
	if LActor.getCurrency(actor, NumericType_YuanBao) < GodWeaponBaseConfig.skillResetCost then
		print("godweaponbase.resetSkill:refresh money not enough, actorId:"..tostring(actorId))
		return
	end

	LActor.changeCurrency(actor, NumericType_YuanBao, -GodWeaponBaseConfig.skillResetCost, "resetgodweaponskill")

	--返回技能点
	local var = getActorVar(actor)
	if var.weapon and var.weapon[weaponIdx] and var.weapon[weaponIdx].skill then
		local data = var.weapon[weaponIdx].skill
		local count = 0
		local godSkillConfig = GodWeaponLineConfig[weaponIdx]
		for skillIdx, v in pairs(godSkillConfig or {}) do
			if data[skillIdx] then count = count + data[skillIdx] end
		end

		var.weapon[weaponIdx].left = (var.weapon[weaponIdx].left or 0) + count
		var.weapon[weaponIdx].skill = nil
	end


	onSendInfo(actor)
	updateAttr(actor)
end

local function onResetSkill(actor, packet)
	local weaponIdx = LDataPack.readInt(packet)
	resetSkill(actor, weaponIdx)
end

--增加任务进度
function addGodweaponTaskTarget(actor, taskType, param)
	local var = getActorVar(actor)
	if not var or not var.job or not var.taskId then return end

	local gwCount = getGodWeaponCount(actor) + 1
	local gwConfig = GodWeaponTaskConfig[gwCount]
	for i = var.taskId, #gwConfig do
		local config = gwConfig[i]
		if i == var.taskId then
			--当前任务
			if config.type == taskType and param == config.param and var.value < config.target then
				if System.getRandomNumber(10000) < config.rate then
					var.value = var.value + 1

					if config.itemName[var.job] then
						LActor.sendTipmsg(actor, string.format(config.tips, config.itemName[var.job]), ttHearsay)
					end
					if var.value >= config.target then
						var.status = taskcommon.statusType.emCanAward
					end
					onSendTaskInfo(actor)  --只有当前任务数据有变动才需要更新信息
				end
			end
		elseif config.record == 1 then
			--非当前任务且需要提前记录
			if config.type == taskType and param == config.param then
				if System.getRandomNumber(10000) < config.rate then
					if not var.taskRecord then var.taskRecord = {} end
					if not var.taskRecord[i] then
						var.taskRecord[i] = {
							value = 0,
							status = taskcommon.statusType.emDoing
						}
					end
					if var.taskRecord[i].value < config.target then
						var.taskRecord[i].value = var.taskRecord[i].value + 1
						if config.itemName[var.job] then
							LActor.sendTipmsg(actor, string.format(config.tips, config.itemName[var.job]), ttHearsay)
						end
						if var.taskRecord[i].value >= config.target then
							var.taskRecord[i].status = taskcommon.statusType.emCanAward
						end
					end
				end
			end
		end
	end
end

function onLogin(actor)
	onSendInfo(actor)
	onSendExpInfo(actor)
	onSendTaskInfo(actor)
end

--旧服，有些玩家已经达到了开启等级的，所以要全部初始化好，把所有的神兵都开启
function onLoginInitOldData(actor)
	local var = getActorVar(actor)
	if not var or var.checkOld then return end

	var.checkOld = 1

	if not checkOpen(actor) then
		return
	end

	for i = 1, GodWeaponBaseConfig.godWeaponCount do
		if not var.weapon[i] then
			var.weapon[i] = {}
			var.weapon[i].exp = 0
			var.weapon[i].level = 1
		end
	end
end

netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_SkillLevelUp, pointSkill)
netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_FitGodItem, fitGodItem)
netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_WeaponLevelUp, levelUp)
netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_AcceptTask, acceptTask)
netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_FinishTask, finishTask)
netmsgdispatcher.reg(p.CMD_GodWeapon, p.cGodWeaponCmd_ResetSkill, onResetSkill)

actorevent.reg(aeInit, updateAttr)
actorevent.reg(aeInit, onLoginInitOldData)
actorevent.reg(aeUserLogin, onLogin)


local gmsystem    = require("systems.gm.gmsystem")
local gmCmdHandlers = gmsystem.gmCmdHandlers
gmCmdHandlers.godweapon = function(actor, args)
	local a = tonumber(args[1])
	if a == 1 then
		addGodWeaponExp(actor, tonumber(args[2]))
	elseif a == 2 then
		LActor.addGodWeaponActId(actor, 14, 13001)
	elseif a == 3 then
		local job = tonumber(args[2])

		if job < 1 or job > GodWeaponBaseConfig.godWeaponCount then return end

		local var = getActorVar(actor)

		if not var.weapon[job] then
			var.weapon[job] = {}
		end

		local jobVar = var.weapon[job]
		jobVar.left = (jobVar.left or 0) + tonumber(args[3])	--剩余可使用的技能点数

		updateAttr(actor)
	elseif a == 4 then
		LActor.addGodWeaponActId(actor, 14, 13001)
		LActor.AddSkill(role, k*1000+v)
	elseif a == 5 then
		local var = getActorVar(actor)
		if not var or not var.job or not var.taskId then return end

		local gwCount = getGodWeaponCount(actor) + 1
		local config = GodWeaponTaskConfig[gwCount][var.taskId]

		addGodweaponTaskTarget(actor, config.type, config.param)
	elseif a == 6 then
		acceptTask(actor, tonumber(args[2]))
	elseif a == 7 then
		finishTask(actor)
	elseif a == 8 then
		--激活
		local var = getActorVar(actor)
		if not var then return end
		local job = tonumber(args[2])
		if not job or var.weapon[job] then return end

		var.weapon[job] = {}
		var.weapon[job].exp = 0
		var.weapon[job].level = 1

		var.job = nil
		var.taskId = nil
		var.status = nil
		var.value = nil

		onSendInfo(actor)
		onSendTaskInfo(actor)
	elseif a == 9 then
		resetSkill(actor, tonumber(args[2]))
	end

	return true
end





