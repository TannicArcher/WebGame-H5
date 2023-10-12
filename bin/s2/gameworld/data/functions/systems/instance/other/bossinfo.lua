--副本内boss信息
module("bossinfo", package.seeall)

--[[
boss_info = {
    damagelist = {
        [actorid] = {name, damage}
     },
     damagerank = {
        {id, name,damage}[]
     }
     id,
     hp,
     src_hdl,
     tar_hdl,
     need_update,
 }
--]]
local p = Protocol

function getDdamageRank(ins)
	onTimer(ins,System.getNowTime(), true)
	return ins.boss_info.damagerank
end

local function onDamage(ins, selfid, curhp, damage, attacker)
    if ins.boss_info == nil then ins.boss_info = {} end
    if ins.boss_info.damagelist == nil then ins.boss_info.damagelist = {} end
    local actor = LActor.getActor(attacker)
    if actor and damage > 0 then
		local info = ins.boss_info.damagelist[LActor.getActorId(actor)]
		if info == nil then
			ins.boss_info.damagelist[LActor.getActorId(actor)] = {name = LActor.getName(actor), damage = damage}
		else
			info.damage = info.damage + damage
		end
	end
    ins.boss_info.hp = curhp
    ins.boss_info.id = selfid
    ins.boss_info.need_update = true

    if curhp <= 0 or damage < 0 then
        onTimer(ins, System.getNowTime(), true)
    end
end

local function sortDamage(boss_info)
    if boss_info == nil then return end
    if boss_info.damagelist == nil then return end
    boss_info.damagerank = {}
    for aid, v in pairs(boss_info.damagelist) do
        table.insert(boss_info.damagerank, {id=aid,name=v.name,damage=v.damage})
    end
    table.sort(boss_info.damagerank, function(a,b)
        return a.damage > b.damage
    end)

end

local function onChangeTarget(ins, src_hdl, tarHdl)
    if ins.boss_info == nil then ins.boss_info = {} end
    ins.boss_info.src_hdl = src_hdl
    ins.boss_info.tar_hdl = tarHdl
    ins.boss_info.need_update = true
	onTimer(ins,System.getNowTime(),true)
end

--c++回调接口

_G.onBossDamage = function(fbhdl, selfid, curhp, damage, attacker)
	-- print("--- on boss damage ---")
    local ins = instancesystem.getInsByHdl(fbhdl)
    if ins then
        onDamage(ins, selfid, curhp, damage, attacker)
    end
end

_G.onBossRecover = function(fbhdl, mon, maxhp)
	local ins = instancesystem.getInsByHdl(fbhdl)
    if not ins then return end
    if ins.boss_info == nil then return end
    if ins.boss_info.id == nil then return end
    ins.boss_info.hp = maxhp
end

_G.onBossChangeTarget = function(fbhdl, src_hdl, tarHdl)
    local ins = instancesystem.getInsByHdl(fbhdl)
    if ins then
        onChangeTarget(ins, src_hdl, tarHdl)
    end
end

function onMonsterCreate(ins, monster)
	if LActor.isBoss(monster) then
		if ins.boss_info == nil then ins.boss_info = {} end
		if ins.boss_info.damagelist == nil then ins.boss_info.damagelist = {} end
		ins.boss_info.hp = tonumber(LActor.getHp(monster))
		ins.boss_info.id = LActor.getId(monster)
		ins.boss_info.need_update = true
	end
end

--instance回调接口
local function notify(ins, actor)
    local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sBossCmd_BossInfo)
    if npack == nil then return end

    local info = ins.boss_info
    LDataPack.writeInt(npack, info.id)
    LDataPack.writeDouble(npack, info.hp)
    LDataPack.writeInt64(npack, info.src_hdl or 0)
    -- print("info.src_hdl:"..info.src_hdl)
    LDataPack.writeInt64(npack, info.tar_hdl or 0)
    if info.damagerank == nil then
        LDataPack.writeShort(npack, 0)
    else
        LDataPack.writeShort(npack, #info.damagerank)
        for i=1,#info.damagerank do
            LDataPack.writeInt(npack, info.damagerank[i].id)
            LDataPack.writeString(npack, info.damagerank[i].name)
            LDataPack.writeDouble(npack, info.damagerank[i].damage)
        end
    end
    LDataPack.flush(npack)
end

function onEnter(ins, actor)
    if ins.boss_info == nil then return end
    if ins.boss_info.id == nil then return end
	
    notify(ins, actor)
end

function onTimer(ins, now_t, force)
	if ins.boss_info == nil then return end
	if ins.boss_info.id == nil then return end
	if not ins.boss_info.need_update then return end
	if not force and ((ins.boss_info.timer or 0) > now_t) then return end
	ins.boss_info.timer = now_t + 3 --3秒执行一次
	sortDamage(ins.boss_info)
	local actors = ins:getActorList()
	for _, actor in ipairs(actors) do
	   notify(ins, actor)
	end

	ins.boss_info.need_update = false
end

--发送攻击列表给归属者
local function sendAttackedListToBelong(actor)
	if not actor then return end
	--通知归属者,当前攻击归属者的玩家列表
	local actors = Fuben.getAllActor(LActor.getFubenHandle(actor))
	if actors ~= nil then
		local handles = {}
		local count = 0
		for i = 1,#actors do 
			if LActor.getCamp(actors[i]) == WorldBossCampType_Attack then
				handles[LActor.getHandle(LActor.getActor(actors[i]))] = 1
				count = count + 1
			end
		end
		local npack = LDataPack.allocPacket(actor, p.CMD_Boss, p.sWorldBoss_UpdateAttackedListInfo)
		if nil == npack then return end
		LDataPack.writeUInt(npack, count)
		for k,v in pairs(handles) do
			LDataPack.writeDouble(npack, k)
		end
		LDataPack.flush(npack)
	end
end
_G.sendAttackedListToBelong = sendAttackedListToBelong
