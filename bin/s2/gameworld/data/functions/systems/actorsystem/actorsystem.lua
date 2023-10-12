--Actor方法移植
module("systems.actorsystem.actorsys", package.seeall)
setfenv(1, systems.actorsystem.actorsys)

--combat          = require("systems.actorsystem.actorcombat")
--misc            = require("systems.actorsystem.actormisc")
--money           = require("systems.actorsystem.actormoney")
--beattime        = require("systems.actorsystem.actorbeattime")
--rep             = require("systems.actorsystem.actorrep")
--calculatehelper = require("systems.actorsystem.calculatehelper")
--actorfcm        = require("systems.actorsystem.actorfcm")
--actorinfo       = require("systems.actorsystem.actorinfo")
--actorrelive     = require("systems.actorsystem.actorrelive")

require("systems.msg.msgsystem")

require("systems.actorsystem.actorawards")
require("systems.actorsystem.actorcost")

require("systems.actorsystem.actorexp")
require("systems.actorsystem.actoressence")
require("systems.actorsystem.actorzhuansheng")
require("systems.actorsystem.actorrole")

--require("systems.actorsystem.actortimer")
require("systems.actorsystem.actorvip")
require("systems.actorsystem.morship.morship")
--require("systems.actorsystem.actordie")
require("systems.actorsystem.actorlogin")
--require("systems.actorsystem.actorlogout")
require("systems.actorsystem.knighthood")
--require("systems.actorsystem.yupei")
--require("systems.actorsystem.artifacts")
require("systems.actorsystem.sdkapi.sdkapi")

require("systems.actorsystem.train.traincommon")
require("systems.actorsystem.train.trainsystem")

require("systems.actorsystem.recharge.rechargeitem")
require("systems.actorsystem.recharge.dailyrecharge")
require("systems.actorsystem.recharge.multidayrecharge")
require("systems.actorsystem.recharge.rechargedaysawards")
--require("systems.actorsystem.recharge.chongzhi2")
require("systems.actorsystem.recharge.chargemail")

require("systems.actorsystem.monthcard")

--require("systems.actorsystem.refinesystem")

require("systems.actorsystem.specialattribute")

require("systems.actorsystem.chat")

require("systems.actorsystem.item")

require("systems.actorsystem.tianti.tianti")
require("systems.actorsystem.tianti.tiantirank")

require("systems.actorsystem.cashcow.cashcowcommon")
require("systems.actorsystem.cashcow.cashcowsystem")

require("systems.actorsystem.asynevent")
require("systems.actorsystem.ronglu")

--轮回系统
require("systems.actorsystem.actorreincarnate")

--战灵
require("systems.actorsystem.zhanling.zhanlingsystem")

--神兽系统
require("systems.actorsystem.shenshousystem")

--好友系统
require("systems.friend.friendtodb")
require("systems.friend.friendcommon")
require("systems.friend.friendoffline")
require("systems.friend.friendsystem")

--玩家特戒系统
require("systems.actorsystem.actorexring.actorexring")

--烈焰印记
require("systems.actorsystem.actorexring.flamestamp")

--合击系统
require("systems.actorsystem.togetherhit.togetherhit")
require("systems.actorsystem.togetherhit.togetherhitequipexchange")
require("systems.actorsystem.togetherhit.togetherhitpunchequip")

-- 特权月卡
require("systems.actorsystem.privilegemonthcard")