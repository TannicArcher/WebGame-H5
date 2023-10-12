--藏宝阁大冒险
module("richmansystem", package.seeall)

--[[动作定义
1.获取奖励
  param:{{type=0,id=1,count=1},...}, 多个中随机一个
  exparam:{[圈数]={type=0,id=1,count=1},...},在指定圈,固定的奖励
2.全盘随机奖励(随机命运)
  param:{{type=0,id=1,count=1},...}, 多个中随机一个
  exparam: 为空
3.传送门
  param: 10, 传送到的格仔位置
  exparam: 为空
4.奖励骰子
  param: 1,骰子个数
  exparam:为空
]]
local ActionType = {
	GetAward = 1,
	AllRandAward = 2,
	MoveTo = 3,
	GetTouzi = 4,
}

--[[玩家数据定义
data={
	diceNum = 0 --骰子的个数
	gridData = { --格仔随机数据保存
		[格仔位置]=随机奖励索引,-1表示踩中过
	},
	curIdx = 1,当前所在的格子,记住:缺省值是 1
	round=0,--已经跑完第几圈,第一次是从0开始计数
	randAward = {grid=格仔位置,idx=第几个奖励} --如果当圈踩中了类型2
	roundAward = 0, --按位存储的圈数奖励索引是否领取
}
]]
--获取静态数据
local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if nil == data then return nil end
	if nil == data.richmansystem then data.richmansystem = {} end
	return data.richmansystem
end

--外部改变骰子数量的接口
function changeTouZi(actor, num)
	local var = getData(actor)
	var.diceNum = (var.diceNum or 0) + num
	
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_UpdateTouzi)
	--踩中随机奖励
	LDataPack.writeShort(npack, var.diceNum)
	LDataPack.writeShort(npack, var.round or 0) --第几圈
	LDataPack.writeInt(npack, var.roundAward or 0)
	LDataPack.flush(npack)
end
_G.changeTouZi = changeTouZi

--刷新格仔随机数据
local function refreshGridData(actor)
	local var = getData(actor)
	var.gridData = {}
	for index,cfg in ipairs(RichManGridConfig) do
		if cfg.action == ActionType.GetAward then
			var.gridData[index] = math.random(1,#(cfg.param))
		end
	end
	var.randAward = nil
end

local actionFunc = {}
actionFunc[ActionType.GetAward] = function(actor, var, cfg)
	if var.gridData[var.curIdx or 1] == -1 then
		return
	end
	local award = nil
	if cfg.exparam and cfg.exparam[var.round or 0] then --先判断当前圈是否要特殊奖励
		award = cfg.exparam[var.round or 0]
	elseif var.randAward then--其次判断是否需要全盘奖励
		award = RichManGridConfig[var.randAward.grid].param[var.randAward.idx]
	else
		award = cfg.param[var.gridData[var.curIdx or 1]]
	end
	LActor.giveAwards(actor, {award} , "richman")
	var.gridData[var.curIdx or 1] = -1
end

actionFunc[ActionType.AllRandAward] = function(actor, var, cfg)
	if var.gridData[var.curIdx or 1] == -1 then
		return
	end
	--如果原先已经有随机奖励的
	if var.randAward then
		local award = RichManGridConfig[var.randAward.grid].param[var.randAward.idx]
		LActor.giveAwards(actor, {award} , "richman")
		return
	end
	local idx = math.random(1, #(cfg.param))
	if not var.randAward then var.randAward = {} end
	var.randAward.grid = var.curIdx
	var.randAward.idx = idx
	var.gridData[var.curIdx or 1] = -1
	--通知随机奖励
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_AllRand)
	--踩中随机奖励
	LDataPack.writeShort(npack, var.randAward and var.randAward.grid or 0)
	LDataPack.writeByte(npack, var.randAward and var.randAward.idx or 0)
	LDataPack.flush(npack)	
end

actionFunc[ActionType.MoveTo] = function(actor, var, cfg)
	var.curIdx = tonumber(cfg.param)
end

actionFunc[ActionType.GetTouzi] = function(actor, var, cfg)
	if var.gridData[var.curIdx or 1] == -1 then
		return
	end
	changeTouZi(actor, tonumber(cfg.param))
	var.gridData[var.curIdx or 1] = -1
end

--执行当前格子动作
local function DoAction(actor)
	local var = getData(actor)
	--获取当前格子的配置
	local cfg = RichManGridConfig[var.curIdx or 1]
	if not cfg then
		print(LActor.getActorId(actor).." richmansystem.DoAction not cfg, id:"..tostring(var.curIdx or 1))
		return
	end
	--动作函数
	local func = actionFunc[cfg.action]
	if not func then
		print(LActor.getActorId(actor).." richmansystem.DoAction not action, action:"..tostring(cfg.action))
		return
	end
	return func(actor, var, cfg)
end

--请求获取棋盘数据
local function reqGetInfo(actor, packet)
	local var = getData(actor)
	if not var.gridData then 
	--第一次为nil,需要初始化
		refreshGridData(actor)
	end
	
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_Info)
	LDataPack.writeShort(npack, var.diceNum or 0) --骰子的个数
	LDataPack.writeShort(npack, var.curIdx or 1) --当前所在位置
	LDataPack.writeShort(npack, var.round or 0) --第几圈
	LDataPack.writeInt(npack, var.roundAward or 0)
	--踩中随机奖励
	LDataPack.writeShort(npack, var.randAward and var.randAward.grid or 0)
	LDataPack.writeByte(npack, var.randAward and var.randAward.idx or 0)
	--棋盘的数据
	LDataPack.writeShort(npack, #RichManGridConfig)
	for index,cfg in ipairs(RichManGridConfig) do
		LDataPack.writeShort(npack, var.gridData[index] or 0)
	end
	LDataPack.flush(npack)
end

--请求摇骰子
local function reqTurnStep(actor, packet)
	local var = getData(actor)
	--检测消耗
	if (var.diceNum or 0) <= 0 then
		--消耗元宝
		if RichManBaseConfig.dicePrice > LActor.getCurrency(actor, NumericType_YuanBao) then
			print(LActor.getActorId(actor).." richmansystem.reqTurnStep yuanbao insufficient")
			return
		end
		LActor.changeYuanBao(actor, 0-(RichManBaseConfig.dicePrice), "richman")
	else
		--消耗骰子
		changeTouZi(actor, -1)
	end
	--摇动个骰子
	local rand = math.random(1,6)
	--计算当前走到的格仔
	var.curIdx = (var.curIdx or 1) + rand
	--判断是否跨过起点
	local isAs = 0
	if var.curIdx > #(RichManGridConfig) then
		--跨圈了; 要刷新格仔数据
		refreshGridData(actor)
		--圈数加一
		var.round = (var.round or 0) + 1
		actorevent.onEvent(actor, aeRichManCircle, 1)
		--更新最新的位置
		var.curIdx = var.curIdx - #(RichManGridConfig)
		--跨圈,送骰子
		changeTouZi(actor, RichManBaseConfig.kqDice or 0)
		--下发最新数据
		reqGetInfo(actor, nil)
		isAs = 1
	end
	--触发到这个点的动作
	DoAction(actor)
	--回应客户端
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_TurnStep)
	LDataPack.writeByte(npack, isAs) --是否跨越过起点
	LDataPack.writeShort(npack, var.curIdx or 1) --当前所在位置
	LDataPack.writeByte(npack, rand) --摇到的点数
	LDataPack.flush(npack)
end

--请求领取圈数奖励
local function reqGetRoundAward(actor, packet)
	local idx = LDataPack.readByte(packet)
	--获取配置
	local cfg = RichManRoundAwardConfig[idx]
	if not cfg then
		print(LActor.getActorId(actor).." richmansystem.reqGetRoundAward cfg is nil, idx:"..idx)
		return
	end
	local var = getData(actor)
	--判断圈数是否满足
	if (cfg.round or 0) > (var.round or 0) then
		print(LActor.getActorId(actor).." richmansystem.reqGetRoundAward cfg.round:"..tostring(cfg.round).." > var.round:"..tostring(var.round))
		return
	end
	--判断是否已经领取
	if System.bitOPMask(var.roundAward or 0, idx) then
		print(LActor.getActorId(actor).." richmansystem.reqGetRoundAward is received, idx:"..idx)
		return
	end
	--获得奖励
	LActor.giveAwards(actor, cfg.award, "richman round")
	--标记为已领取
	var.roundAward = System.bitOpSetMask((var.roundAward or 0), idx, true)
	--回应客户端
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_RoundAward)
	LDataPack.writeByte(npack, idx)
	LDataPack.writeInt(npack, var.roundAward)
	LDataPack.flush(npack)
end

--检测所有未领的奖励,通过邮件发送
local function checkAllNotReceivedAwardToMail(actor)
	local var = getData(actor)
	local awards = {}
	for idx, cfg in pairs(RichManRoundAwardConfig) do
		if not System.bitOPMask(var.roundAward or 0, idx) and (cfg.round or 0) <= (var.round or 0) then
			for _,v in ipairs(cfg.award) do
				table.insert(awards, v)
			end
		end
	end
	if #awards <= 0 then return end
	--发送邮件
	local mailData = {
		head=RichManBaseConfig.mailHead, 
		context=RichManBaseConfig.mailContent,
		tAwardList=awards
	}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

--登陆的时候
local function onLogin(actor)
	local var = getData(actor)
	if not var.gridData then 
	--第一次为nil,需要初始化
		refreshGridData(actor)
	end
	changeTouZi(actor, 0)
end

--新的一天回调
local function onNewDay(actor)
	local var = getData(actor)
	checkAllNotReceivedAwardToMail(actor)
	refreshGridData(actor) --隔天全部初始化
	var.roundAward = nil
	var.round = nil
	var.curIdx = nil
	var.diceNum = RichManBaseConfig.diceNum
end

--初始化全局数据
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	
	netmsgdispatcher.reg(Protocol.CMD_RichMan, Protocol.cRichManCmd_ReqGetInfo, reqGetInfo) --请求获取棋盘数据
	netmsgdispatcher.reg(Protocol.CMD_RichMan, Protocol.cRichManCmd_ReqTurnStep, reqTurnStep) --请求摇骰子
	netmsgdispatcher.reg(Protocol.CMD_RichMan, Protocol.cRichManCmd_ReqGetRoundAward, reqGetRoundAward) --请求领取圈数奖励
end

table.insert(InitFnTable, initGlobalData)

--rich
function gmHandle(actor, arg)
	local param = arg[1]
	if param == "add" then
		changeTouZi(actor, 1)
	else
		reqTurnStep(actor, nil)
	end
end

