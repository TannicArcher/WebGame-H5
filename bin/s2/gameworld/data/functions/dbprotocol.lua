DbCmd =
{
    DefaultCmd =
    {
        dcExecDB = 2,	--执行sql语句
    },
    EntityCmd =
    {
        dcLoadFriends        = 35,	--读取本人的好友列表（包括仇人、黑名单等）（跨服战不读取）
        dcUpdateFriend       = 36,	--更新好友的信息 = ,包括删除某个好友（包括仇人、黑名单等）
        dcDelFriend          = 37,  --删除好友信息
        dcUpdateFriendInfo   = 38,  --更新好友下线时间
        dcUpdateFriendContact = 39,	--更新联系时间

        dcLoadFbCountData = 42,     --读取每天进入副本次数数据（跨服战不读取）
        dcSaveFbCountData = 43,     --保存每天进入副本次数数据
        dcLoadMail           = 59,	--读取邮件
        dcDeleteMail         = 60,	--删除邮件
        dcUpdateMailStatus   = 61,	--更新邮件状态
        dcDeleteMailFile     = 62,	--删除邮件附件
        dcGetActorIdFromName = 63,	--获取actorId
        dcLoadAllPet         = 96, -- 加载所有宠物
        dcDeletePet          = 97, -- 删除宠物
        dcAddPet             = 98, -- 添加宠物
        dcUpdatePet          = 99, -- 更新宠物
        dcPetSkill           = 100,-- 宠物技能相关（跨服战不保存）
        dcLoadPetGotType     = 101,-- 读取宠物的历史记录（跨服战不读取）
        dcAddPetGotType      = 102,-- 增加宠物的历史记录（跨服战不保存）
        dcPetLoadEquip       = 103,-- 加载宠物装备
        dcPetSaveEquip       = 104,-- 保存宠物装备（跨服战不保存）

        dcAddEqSign          = 106,	--新增铭刻信息
        dcInheritEqSign      = 107,	--继承替换铭刻信息
        dcGetEqSignList      = 108,	--获取某装备上的铭刻信息

        dcOfflineLogout 	 = 120,	--下线时，对方不在线，写入相关数据
        dcOfflineDivorce 	 = 121,	--离婚时，对方不在线，写入相关数据
    },
    MailMgrCmd =
    {
        dcAddMail              = 1,
        dcAddMailByActorName   = 2,
        dcAddMailByAccountName = 3,
    },
    ConsiMgrCmd =
    {
        dcSaveConsignmentItem = 2,
    },
    GlobalCmd =
    {
        dcAddGmQuestion = 10,
        dcLoadGmQuestions = 11,
        dcLoadGmQuestion = 12,
        dcUpdateGmQuestion = 13,

        dcAddBug = 14,
        dcLoadGoldRank = 15,

        dcAddGameServerInfo = 16 --添加一条gameworld相关信息
    },
    TxApiCmd =
    {
        -- 充值返回
        sFeeCallBack = 1,
        -- 腾讯api返回
        sTxApiMsg = 2,
        -- 更新用户身份证号码
        --sUpdateIdentity = 4,

        -- 关闭或开启赌博系统
        --sCloseGamble = 5,

        -- 用户充值获取token
        sChargeToken = 6,
        -- 开通黄钻等获取token
        --sGetToken = 7,

        --增值序列号
        --sAddValueCard = 8,
        -- 查询增值卡
        --sQueryAddValueCard = 9,
        -- 查询元宝数量
        --sQueryYuanbaoCount = 10,
        -- 提取元宝
        --sWithdrawYuanbao = 11,
        -- 发送登陆的key
        --sLoginKey = 12,
    },

    CommonCmd = -- 通用
    {
        dcDBExec = 1,
    },
    FriendCmd = -- 好友
    {
        dcLoadFriends        = 35,  --读取本人的好友列表（包括仇人、黑名单等）（跨服战不读取）
        dcUpdateFriend       = 36,  --更新好友的信息 = ,包括删除某个好友（包括仇人、黑名单等）
        dcDelFriend          = 37,  --删除好友信息
    },
    AuctionCmd = --拍卖
    {
        dcAuctionAdd = 1,
        dcAuctionDel = 2,
        dcAuctionUpdate = 3,
    },
}