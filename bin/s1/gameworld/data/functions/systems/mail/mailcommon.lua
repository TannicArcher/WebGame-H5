module("mailcommon", package.seeall)

for index,config in pairs(MailIdConfig) do
	assert(config.title and type(config.title) == "string",string.format("title in line %d is error in MaidIdConfig",index))
	assert(config.content and type(config.content) == "string",string.format("content in line %d is error in MaidIdConfig",index))
    if config.attachment then
        for awardIndex,award in pairs(config.attachment) do
            assert(award.type, string.format("type is empty in line %d in MaidIdConfig",index))
            assert(award.id, string.format("type is empty in line %d in MaidIdConfig",index))
            assert(award.count, string.format("type is empty in line %d in MaidIdConfig",index))
        end
    end
end

function getConfigByMailId(mailId)
	return MailIdConfig[mailId]
end

function sendMailById(actorId, mailId, sid)
    local conf = getConfigByMailId(mailId)
    if conf then
        local mailData = {head=conf.title, context=conf.content, tAwardList=conf.attachment}
        mailsystem.sendMailById(actorId, mailData, sid)
    end
end
