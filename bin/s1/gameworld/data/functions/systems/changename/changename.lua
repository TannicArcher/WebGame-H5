module("changename", package.seeall)

function ChangeUserName(sysarg, packet)
    local conf = RenamedCardConf

    local var = LActor.getStaticVar( sysarg )
    if var == nil then return end
    if var.ChangeNameCD == nil then
        var.ChangeNameCD = 0
    end

    local now_t = System.getNowTime()
    if (now_t - var.ChangeNameCD) < conf.timeCD then
        -- LActor.sendTipmsg( sysarg, Lang.ScriptTips.cn002, ttMessage )
        local npack = LDataPack.allocPacket(sysarg, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
        if npack == nil then return end
        LDataPack.writeChar(npack, (-1))
        LDataPack.flush(npack)
        return

    end

    local name = LDataPack.readString(packet)
    if name == nil then return end
    name = LActorMgr.lowerCaseNameStr(name)
    local rawName = LActor.getName(sysarg)
    if rawName == name then
        local npack = LDataPack.allocPacket(sysarg, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
        if npack == nil then return end
        LDataPack.writeChar(npack, (-6))
        LDataPack.flush(npack)
        return
    end
    local nameLen = System.getStrLenUtf8(name)
    if nameLen <= 1 or nameLen > 6 or not LActorMgr.checkNameStr(name) then
        local npack = LDataPack.allocPacket(sysarg, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
        if npack == nil then return end
        LDataPack.writeChar(npack, (-12))
        LDataPack.flush(npack)
        return
    end

    -- local needItem = Item.getItemById(sysarg, conf.needItemId, 1)
    -- if needItem == nil then
    --     needItem = Item.getItemById(sysarg, conf.needItemId, 0)
    --     if needItem == nil then
    --         LActor.sendTipmsg( sysarg, Lang.ScriptTips.cn001, ttMessage )
    --         return
    --     end
    -- end

    if not (LActor.checkItemNum(sysarg, conf.needItemId, 1, false)) then
        return
    end

    LActor.changeName(sysarg, name)
end

--改名后需要修改排行榜里面的玩家名的排行榜，这些排行榜的格式需要把玩家名放在最前面才行，要不会出错
local rankListNames = 
{
    "skirmishrank",
    "tiantirank",
    "challengerank",
    "chapterrank",
}

--改名
OnSetUserName = function(sysarg, res, name, rawName, way)
    way = way or 0

    if name == nil or rawName == nil then return end
    local conf = RenamedCardConf

    if res == 0 then
        -- local needItem = nil
        if way ~= 1 then
            -- needItem = Item.getItemById(sysarg, conf.needItemId, 1)
            -- if needItem == nil then
            --     needItem = Item.getItemById(sysarg, conf.needItemId, 0)
            --     if needItem == nil then
            --         LActor.sendTipmsg( sysarg, Lang.ScriptTips.cn001, ttMessage )
            --         return
            --     end
            -- end
            if not (LActor.checkItemNum(sysarg, conf.needItemId, 1, false)) then
                return
            end
        end
        local var = LActor.getStaticVar( sysarg )
        if var == nil then return end
        if way == 1 or (LActor.checkItemNum(sysarg, conf.needItemId, 1, false)) then      --删除一个物品

        	if way ~= 1 then
        		LActor.costItem(sysarg, conf.needItemId, 1,"change name cost normal item")
        	end

            local aId = LActor.getActorId(sysarg)
            LActor.setEntityName(sysarg, name)
            -- LActor.friendStatusChange(sysarg)

            if way ~= 1 then -- 修复bug的情况下不改变CD
                var.ChangeNameCD = System.getNowTime()
            end

            --log
            local logStr = string.format("%s_%s", rawName, name)
            System.logCounter(LActor.getActorId(sysarg), LActor.getAccountName(sysarg), tostring(LActor.getLevel(sysarg)), "changeName", logStr, "", "", "", "", "", "", lfDB)

            --========================================
            --publicboss.actorChangeName(sysarg, name)
            --otherboss1.actorChangeName(sysarg, name)
			worldboss.actorChangeName(sysarg, name)
            guildfuben.ChangeNameOnGuildfb(sysarg, name)
			godweaponfuben.actorChangeName(sysarg, name)
            local rName
            local rank
            local item 
            for i=1, #rankListNames do
                rName = rankListNames[i]
                rank = Ranking.getRanking(rName)
                if rank then
                    item = Ranking.getItemPtrFromId(rank, aId)
                    if item then
                        Ranking.setSub(item, 0, name)
                    end
                end
            end

            --========================================
            local npack = LDataPack.allocPacket(sysarg, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
            if npack == nil then return end
            LDataPack.writeChar(npack, 0)
            LDataPack.flush(npack)

        end
    else
        local npack = LDataPack.allocPacket(sysarg, Protocol.CMD_Base, Protocol.sBaseCmd_ChangeName)
        if npack == nil then return end
        LDataPack.writeChar(npack, res)
        LDataPack.flush(npack)
        return

    end

end

netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_ChangeName, ChangeUserName) -- 使用改名卡改名
actorevent.reg(aeChangeName, OnSetUserName)
