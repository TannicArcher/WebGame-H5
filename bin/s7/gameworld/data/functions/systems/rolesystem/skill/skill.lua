module("skill", package.seeall)


local upconf = SkillsUpgradeConfig

local function onUpgradeSkillCount(actor, roleid, count)
	actorevent.onEvent(actor, aeUpgradeSkillCount, roleid, count)
end

local function onUpgradeSkillLevel(actor, roleid, index, lv)
	actorevent.onEvent(actor, aeSkillLevelup, roleid, index, lv)
end

local function upgradeSkill(actor, roleid, index)
	-- 最多5个技能
	if index < 0 or index > 4 then return end

	local level = LActor.getRoleSkillLevel(actor, roleid, index)
	local actorLevel = LActor.getLevel(actor)
    if actorLevel > ZHUAN_SHENG_BASE_LEVEL then actorLevel = ZHUAN_SHENG_BASE_LEVEL end
    actorLevel = actorLevel + LActor.getZhuanShengLevel(actor) * 10
	local gold = LActor.getCurrency(actor, NumericType_Gold)
	if level == 0 then
		if SkillsOpenConfig[index+1] == nil or SkillsOpenConfig[index+1].level > actorLevel then
			return
		end
    end
    --转生等级每1级相当于10级
	if level >= actorLevel then
		print("skill.upgradeSkill level:"..level.." >= actorlevel:"..actorLevel)
		return
	end
	if level > 0 and upconf[level].cost  > gold then
		print("skill.upgradeSkill cost:"..upconf[level].cost.." > gold:"..gold)
		return
	end
	if level > 0 then
		LActor.changeGold(actor, -upconf[level].cost, "upgradeskill")
	end
	LActor.log(actor, "skill.upgradeSkill", "mark1", roleid, index)
	LActor.upgradeSkill(actor, roleid, index)

    --激活不触发
    if level > 0 then
        onUpgradeSkillCount(actor, roleid, 1)
        LActor.log(actor, "skill.upgradeSkill", "mark2", roleid, index, level+1)
        onUpgradeSkillLevel(actor, roleid, index, level+1)
    end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_UpdateSkill)
	LDataPack.writeShort(npack, roleid)
	LDataPack.writeShort(npack, index)
	LDataPack.writeShort(npack, level+1)
	LDataPack.flush(npack)
end

local function onReqUpgradeSkill(actor, packet)
	local roleid = LDataPack.readShort(packet)
	local index = LDataPack.readShort(packet)
	print(string.format("on upgrade skill, r:%d, s:%d", roleid, index))

	upgradeSkill(actor, roleid, index)
end

function SingleSkill(actor,index,minlevel,actorlevel,skills)
	local cost = 0
	local count = 0
	local gold = LActor.getCurrency(actor, NumericType_Gold)
	while minlevel < actorlevel do
		--for i=1,#skills do
			local levelcost = upconf[minlevel].cost
			if skills[index + 1] == minlevel then
				if cost + levelcost <= gold then
					cost = cost + levelcost
					skills[index + 1] = minlevel + 1
					count = count + 1
				else
					break
				end
			end
		--end
		minlevel = minlevel + 1
	end
	return cost,skills,count
end

function WholeSkill(actor,minlevel,actorlevel,skills)
	
	for _, v in ipairs(skills) do
		if minlevel > v or minlevel == 0 then
			minlevel = v
		end
	end
	local cost = 0
	local count = 0
	local gold = LActor.getCurrency(actor, NumericType_Gold)
	while minlevel < actorlevel do
		for i=1,#skills do
			local levelcost = upconf[minlevel].cost
			if skills[i] == minlevel then
				if cost + levelcost <= gold then
					cost = cost + levelcost
					skills[i] = minlevel + 1
					count = count + 1
				else
					break
				end
			end
		end
		minlevel = minlevel + 1
	end
	return cost,skills,count
end

local function onReqUpgradeAll(actor, packet)
	local lvltype = LDataPack.readShort(packet)
	local roleid = LDataPack.readShort(packet)
	local index = LDataPack.readShort(packet)
	local roledata = LActor.getRoleData(actor, roleid)
	if roledata == nil then return end
	local skillLvs = roledata.skills.skill_level
	
	local actorlevel = LActor.getLevel(actor)
    if actorlevel > ZHUAN_SHENG_BASE_LEVEL then actorlevel = ZHUAN_SHENG_BASE_LEVEL end
    actorlevel = actorlevel + LActor.getZhuanShengLevel(actor) * 10
	local skills = {}
	for i=0,4 do
		if skillLvs[i] > 0 then
			table.insert(skills, skillLvs[i])
		end
	end

	if index >= #skills or index < 0 then
		print("skill.onReqUpgradeAll index("..index..") is error")
		return
	end



	local cost = 0
	local minlevel = 0
	if (lvltype == 0) then
		minlevel = skills[index + 1]
		cost,skills,count = SingleSkill(actor,index,minlevel,actorlevel,skills)
	elseif(lvltype == 1) then
		cost,skills,count = WholeSkill(actor,minlevel,actorlevel,skills)
	end

	if cost == 0 then
		print("skill.onReqUpgradeAll cost == 0 minlevel:"..minlevel..",lvltype:"..lvltype)
		return
	end
	
	onUpgradeSkillCount(actor, roleid, count)
	LActor.changeGold(actor, -cost, "upgradeskill all")

	for index, lv in ipairs(skills) do
		LActor.log(actor, "skill.onReqUpgradeAll", "mark1", roleid, index-1, lv)
		LActor.upgradeSkill(actor, roleid, index-1, lv)

		onUpgradeSkillLevel(actor, roleid, index-1, lv)
	end

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.cSkillCmd_UpgradeSkillALL)
	LDataPack.writeShort(npack, roleid)
	LDataPack.writeShort(npack, skillLvs[0])
	LDataPack.writeShort(npack, skillLvs[1])
	LDataPack.writeShort(npack, skillLvs[2])
	LDataPack.writeShort(npack, skillLvs[3])
	LDataPack.writeShort(npack, skillLvs[4])
	LDataPack.flush(npack)
end

--actor event
local function onLevelup(actor, level)
    for index=0,4 do
        if SkillsOpenConfig[index+1] and SkillsOpenConfig[index+1].level == level then
            local c = LActor.getRoleCount(actor)
            for roleid=0,c-1 do
            	LActor.log(actor, "skill.onLevelup", "mark1", roleid, index)
                LActor.upgradeSkill(actor, roleid, index)
                --激活技能不触发任务回调
                --只判断当前的等级，不做复杂判断了
                --通知客户端
                local npack = LDataPack.allocPacket(actor, Protocol.CMD_Skill, Protocol.sSkillCmd_UpdateSkill)
                LDataPack.writeShort(npack, roleid)
                LDataPack.writeShort(npack, index)
                LDataPack.writeShort(npack, LActor.getRoleSkillLevel(actor, roleid, index))
                LDataPack.flush(npack)
            end
        end
    end
end

local function onOpenRole(actor, count)
    local level = LActor.getLevel(actor)

    --尝试激活其他技能
    for i=1,4 do
       if SkillsOpenConfig[i+1] and SkillsOpenConfig[i+1].level
               and SkillsOpenConfig[i+1].level <= level then

           --原来这个接口没有同步消息给前端，所以换了一个接口
           --LActor.upgradeSkill(actor, count -1, i)
           upgradeSkill(actor, count, i)
       end
    end
end

function newRoleSkillInit(roleId)

end

actorevent.reg(aeLevel, onLevelup)
actorevent.reg(aeOpenRole, onOpenRole)


local p = Protocol
netmsgdispatcher.reg(p.CMD_Skill, p.cSkillCmd_UpgradeSkill, onReqUpgradeSkill)
netmsgdispatcher.reg(p.CMD_Skill, p.cSkillCmd_UpgradeSkillALL, onReqUpgradeAll)
