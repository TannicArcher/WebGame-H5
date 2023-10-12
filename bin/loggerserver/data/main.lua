-- 用于创建日志表格
local creatTableSql = 
{
	createCounter = [==[create table  if not exists `log_counter_%d%02d` ( 
                                   `logdate` datetime not null,
                                   `actorid` bigint(10)  default null,
                                   `user_level` varchar(32) default null,
                                   `counter` varchar(32) default null,
                                   `value` varchar(32) default null,
                                   `extra` varchar(128) default null,
                                   `kingdom` varchar(32) default null,
                                   `phylum` varchar(32) default null,
                                   `classfield` varchar(32) default null,
                                   `family` varchar(32) default null,
                                   `genus` varchar(32) default null,
									`serverid` int default 0,
									KEY `idx` (`logdate`,`counter`)
                                   ) engine=myisam default charset=utf8;]==],
	dropCounter = [==[drop table if exists `log_counter_%d%02d`;]==],

	createInstall = [==[create table  if not exists `log_install_%d%02d` ( 
	`logdate` datetime not null,
	`actorid` varchar(64) default null,
	`source` varchar(32) default null,
	`affiliate` varchar(32) default null,
	`creative` varchar(32) default null,
	`family` varchar(32) default null,
	`genus` varchar(32) default null,
	`from_uid` varchar(32) default null,
	`extra` varchar(32) default null,
	`serverid` int default 0,
	KEY `idx` (`logdate`)
	) engine=myisam default charset=utf8;]==],

	dropInstall = [==[drop table if exists `log_install_%d%02d`;]==],

	createDau = [==[create table  if not exists `log_dau_%d%02d` ( 
	`logdate` datetime not null,
	`actorid` varchar(64) default null,
	`source` varchar(32) default null,
	`affiliate` varchar(32) default null,
	`creative` varchar(32) default null,
	`family` varchar(32) default null,
	`genus` varchar(32) default null,
	`ip` varchar(32) default null,
	`from_uid` varchar(32) default null,
	`extra` varchar(32) default null,
	`serverid` int default 0,
	KEY `idx` (`logdate`)
	) engine=myisam default charset=utf8;]==],

	dropDau = [==[drop table if exists `log_dau_%d%02d`;]==],

	createEconomy = [==[create table  if not exists `log_economy_%d%02d` ( 
                   `logdate` datetime not null,
                   `actorid` bigint(10)  default null,
                   `currency` varchar(32) default null,
                   `amount` varchar(32) default null,
                   `value` varchar(32) default null,
                   `kingdom` varchar(32) default null,
                   `phylum` varchar(32) default null,
                   `classfield` varchar(32) default null,
                   `family` varchar(32) default null,
                   `genus` varchar(32) default null,
                   `extra` varchar(128) default null,
                   `extra2` varchar(32) default null,
				   `serverid` int default 0,
					KEY `idx` (`logdate`)
                   ) engine=myisam default charset=utf8;]==],

	dropEconomy = [==[drop table if exists `log_economy_%d%02d`;]==],
	
	createMilestone = [==[create table  if not exists `log_milestone_%d%02d` ( 
                     `logdate` datetime not null,
                     `actorid` bigint(10)  default null,
                     `milestone` varchar(32) default null,
                     `value` varchar(32) default null,
                     `extra` varchar(32) default null,
					 `serverid` int default 0,
					 KEY `idx` (`logdate`)
                     ) engine=myisam default charset=utf8;]==],

	dropMilestone = [==[drop table if exists `log_milestone_%d%02d`;]==],

	createPayment = [==[create table  if not exists `log_payment_%d%02d` ( 
	`logdate` datetime not null,
	`actorid` bigint(10)  default null,
	`ret` int default 0,
	`amount` int default 0,
	`value2` int default 0,
	`kingdom` varchar(32) default null,
	`phylum` varchar(32) default null,
	`transactionid` varchar(64) default null,
	`extra` varchar(64) default null,
	`msgtype` int default 0,
	`p1` int default 0,
	`p2` int default 0,
	`p3` int default 0,
	`p4` int default 0,
	`p5` int default 0,
	`serverid` int default 0,
	KEY `idx` (`logdate`,`transactionid`,`extra`)
	) engine=myisam default charset=utf8;]==],

	dropPayment = [==[drop table if exists `log_payment_%d%02d`;]==],
--[[
	createPaymentIndx = [==[create index log_payment_billno_%d%02d on log_payment_%d%02d
						(
						transactionid
						);
						create index log_payment_extra_%d%02d on log_payment_%d%02d
						(
						extra
						);
						]==],
]]

	creategif = [==[create table  if not exists `log_gif_%d%02d` ( 
	`logdate` datetime not null,
	`actorid` bigint(10)  default null,
	`ret` int default 0,
	`amount` int default 0,
	`value2` int default 0,
	`kingdom` varchar(32) default null,
	`phylum` varchar(32) default null,
	`transactionid` varchar(64) default null,
	`extra` varchar(64) default null,
	`msgtype` int default 0,
	`p1` int default 0,
	`p2` int default 0,
	`p3` int default 0,
	`p4` int default 0,
	`p5` int default 0,
	`serverid` int default 0,
	KEY `idx` (`logdate`)
	) engine=myisam default charset=utf8;]==],
	--creategifindx = [==[create index log_gif_billno_%d%02d on log_gif_%d%02d
	--					(
	--					transactionid
	--					);]==],

	dropgif = [==[drop table if exists `log_gif_%d%02d`;]==],

	createOnline = [==[create table if not exists `log_online_%d%02d` ( 
	`logdate` datetime not null,
	`serverid` int default 0,
	`count` int default 0,
	KEY `idx` (`logdate`)
	) engine=myisam default charset=utf8;]==],

	dropOnline = [==[drop table if exists `log_online_%d%02d`;]==],
	
	createsinglegif = [==[create table  if not exists `log_gif` (
  `logdate` datetime NOT NULL,
  `actorid` bigint(10) default NULL,
  `ret` int(11) default '0',
  `amount` int(11) default '0',
  `value2` int(11) default '0',
  `kingdom` varchar(32) default NULL,
  `phylum` varchar(32) default NULL,
  `transactionid` varchar(64) default NULL,
  `extra` varchar(64) default NULL,
  `msgtype` int(11) default '0',
  `p1` int(11) default '0',
  `p2` int(11) default '0',
  `p3` int(11) default '0',
  `p4` int(11) default '0',
  `p5` int(11) default '0',
  `serverid` int(11) default '0',
  KEY `idx` (`transactionid`, `logdate`)
  ) engine=myisam default charset=utf8;]==],

  droptesinglegif = [==[drop table if exists `log_gif`;]==],

	-- 以下是记录日志的sql
	logCounter =
	    [==[insert into log_counter_%d%02d(logdate,actorid,user_level,counter,value,extra,kingdom,phylum,classfield,family,genus,serverid) 
	       values(now(),%d,'%s','%s','%s','%s','%s','%s','%s','%s','%s','%d');]==],
	logInstall =
	       [==[insert into log_install_%d%02d(logdate,actorid,source,affiliate,creative,family,genus,from_uid,extra,serverid) 
	       values(now(),'%s','%s','%s','%s','%s','%s','%s','%s',%d);]==],

	logDau =
	       [==[insert into log_dau_%d%02d(logdate,actorid,source,affiliate,creative,family,genus,ip,from_uid,extra,serverid) 
	       values(now(),'%s','%s','%s','%s','%s','%s','%s','%s','%s',%d);]==],
	logEconomy =
	    [==[insert into log_economy_%d%02d(logdate,actorid,currency,amount,value,kingdom,phylum,classfield,family,genus,extra,extra2,serverid)
	        values(now(),%d,'%s','%s','%s','%s','%s','%s','%s','%s','%s','%s',%d');]==],
	logMilestone =
	    [==[insert into log_milestone_%d%02d(logdate,actorid,milestone,value,extra,serverid)
	        values(now(),%d,'%s','%s','%s','%d');]==],

	logPayment = [==[insert into log_payment_%d%02d(logdate, actorid, ret, amount, value2, kingdom,phylum,transactionid,
	       extra, msgtype, p1, p2, p3,p4,p5,serverid) values(now(),%d,%d,%d,%d, '%s', '%s', '%s','%s',%d,%d,%d,%d,%d,%d,%d);]==],

	logOnline = [==[insert into log_online_%d%02d(logdate, serverid, count) values(now(), %d, %d);]==],
}


function exesqlToCreateTable(db_conn, sql, p)
	local ret = logger.exeSql(db_conn, sql)
	if ret ~= 0 and p == nil then
		print("create table fail:"..sql)
	end
	return ret
end

function createTable(db_conn)
	local year, mon, day = 1,1,1
	year, mon, day = logger.getDate(year, mon, day)
	local sql
	for i = 1, 5 do
		if i ~= 1 then
			sql = string.format(creatTableSql.dropCounter, year, mon)
			exesqlToCreateTable(db_conn, sql)
			sql = string.format(creatTableSql.dropInstall, year, mon)
			exesqlToCreateTable(db_conn, sql)
			sql = string.format(creatTableSql.dropDau, year, mon)
			exesqlToCreateTable(db_conn, sql)
			sql = string.format(creatTableSql.dropEconomy, year, mon)
			exesqlToCreateTable(db_conn, sql)
			sql = string.format(creatTableSql.dropMilestone, year, mon)
			exesqlToCreateTable(db_conn, sql)
			sql = string.format(creatTableSql.dropPayment, year, mon)
			exesqlToCreateTable(db_conn, sql)
			sql = string.format(creatTableSql.dropgif, year, mon)
			exesqlToCreateTable(db_conn, sql)
		end

		sql = string.format(creatTableSql.createCounter, year, mon)
		exesqlToCreateTable(db_conn, sql)
		

		sql = string.format(creatTableSql.createPayment, year, mon)
		exesqlToCreateTable(db_conn, sql)
		--ret = exesqlToCreateTable(db_conn, sql)
		--if ret == 0 then
		--	sql = string.format(creatTableSql.createPaymentIndx, year, mon, year, mon, year, mon, year, mon)
		--	exesqlToCreateTable(db_conn, sql, false)
		--end

		sql = string.format(creatTableSql.creategif, year, mon)
		exesqlToCreateTable(db_conn, sql)
		--ret = exesqlToCreateTable(db_conn, sql)
		--if ret == 0 then
		--	sql = string.format(creatTableSql.creategifindx, year, mon, year, mon)
		--	exesqlToCreateTable(db_conn, sql, false)
		--end

		sql = string.format(creatTableSql.createDau, year, mon)
		exesqlToCreateTable(db_conn, sql)

		sql = string.format(creatTableSql.createInstall, year, mon)
		exesqlToCreateTable(db_conn, sql)

		sql = string.format(creatTableSql.createEconomy, year, mon)
		exesqlToCreateTable(db_conn, sql)

		sql = string.format(creatTableSql.createMilestone, year, mon)
		exesqlToCreateTable(db_conn, sql)

		sql = string.format(creatTableSql.createOnline, year, mon)
		exesqlToCreateTable(db_conn, sql)

		mon = mon + 1
		if (mon > 12) then
			mon = 1
			year = year + 1
		end
	end

	exesqlToCreateTable(db_conn, creatTableSql.createsinglegif)
end

function precessLog(cmd, serverid, dp, db_conn)
	if cmd == 9 then
		-- 在线人数
		local cnt = DataPack.readInt(dp)
		local tcnt = DataPack.readInt(dp)
		local year, mon, day = 1,1,1
		year, mon, day = logger.getDate(year, mon, day)
		local sql = string.format(creatTableSql.logOnline, year, mon, serverid, cnt)
		local ret = logger.exeSql(db_conn, sql)
		if (ret ~= 0) then
			print("save online count error!"..ret)
		end
		-- 发送到web服务器
		local logStr = "counter=online&data=1|" .. logger.getDateStr() .. "|" .. serverid .. "|" .. cnt .. "&extra=" ..tostring(tcnt)
		print(logStr)
		logger.sendToScribe(serverid, logStr,true,"b27252d68bb53efb175c8f6ce2d51bc2")
		-- print(logStr)
	end
end
