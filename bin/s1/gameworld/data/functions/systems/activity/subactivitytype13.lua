module("subactivitytype13", package.seeall)

local subType = 13
local curid = nil

function sendReward()
    -- if guildbattle.getOpenSize() ~= 1 then
    --     return
    -- end
    print("boss over.............." .. guildbattle.getOpenSize())

    local winGuild = guildbattlefb.getWinGuild()
    print("winGuild" .. winGuild)
    local otherGuild = {}
    local rank = guildbattlepersonalaward.gerRankingTbl()
    for i, guild_id in pairs(rank) do
        print("guild_id" .. guild_id)
        if guildbattlepersonalaward.getTotalIntegral(guild_id) > 0 then
            if guild_id ~= winGuild then
                table.insert(otherGuild, guild_id)
            end
        end
    end

    local activities = activitysystem.getTypeActivities(subType)
    for id, _ in pairs(activities) do
        print("activities id:" .. id)
        local conf = ActivityType13Config[id]
        if conf then
            sendIdReward(conf, winGuild, otherGuild)
        end
    end
end

function sendIdReward(conf, winGuild, otherGuild)
    local guild = LGuild.getGuildById(winGuild)
    if guild then
        sendWinGuildReward(guild, conf)
    end

    for _, v in pairs(otherGuild) do
        local guild = LGuild.getGuildById(v)
        if guild then
            sendOtherGuildReward(guild, conf)
        end
    end
end

function sendWinGuildReward(guild, conf)
    local leaderId = LGuild.getLeaderId(guild)
    local content = conf.reward1content
    local mailData = { head=conf.reward1title, context=content, tAwardList=conf.reward1 }
    mailsystem.sendMailById(leaderId, mailData)

    local id_list = LGuild.getMemberIdList(guild)
    local content = conf.reward2content
    local mailData = { head=conf.reward2title, context=content, tAwardList=conf.reward2 }
    for _, v in pairs(id_list) do
        if leaderId ~= v then
            mailsystem.sendMailById(v, mailData)
        end
    end
end

function sendOtherGuildReward(guild, conf)
    local id_list = LGuild.getMemberIdList(guild)
    local content = conf.reward3content
    local mailData = { head=conf.reward3title, context=content, tAwardList=conf.reward3 }
    for _, v in pairs(id_list) do
        mailsystem.sendMailById(v, mailData)
    end
end

subactivities.regConf(subType, ActivityType13Config)
-- subactivities.regInitFunc(subType, initFunc)
-- subactivities.regWriteRecordFunc(subType, writeRewardRecord)
-- subactivities.regGetRewardFunc(subType, getReward)
