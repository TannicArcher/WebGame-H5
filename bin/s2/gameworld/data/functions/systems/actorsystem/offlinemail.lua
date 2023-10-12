module("offlinemail", package.seeall)



-- local function onLogin(actor) 
-- 	local aId = LActor.getActorId(actor)

-- 	local sqlStr = "select `head`,`context`,`file0_type`,`file0_id`,`file0_num` from offlinemails where actorid='%d';"
-- 	local sql = string.format(sqlStr, aId)
-- 	local db = LActorMgr.getDbConn()
-- 	local err = System.dbQuery(db, sql)
-- 	if err ~= 0 then
-- 		print("onLogin select offlinemails error:" .. err)
-- 		return
-- 	end
-- 	local count = System.dbGetRowCount(db)
-- 	local data = {}
-- 	local tbl
-- 	if count > 0 then
-- 		local row = System.dbCurrentRow(db)
-- 		for i=1, count do
-- 			data[i] = {}
-- 			tbl = data[i]
-- 			tbl.head = System.dbGetRow(row, 0)
-- 			tbl.context = System.dbGetRow(row, 1)
-- 			tbl.type = tonumber(System.dbGetRow(row, 2))
-- 			tbl.id =tonumber(System.dbGetRow(row, 3))
-- 			tbl.count = tonumber(System.dbGetRow(row, 4))
-- 			row = System.dbNextRow(db)
-- 		end
-- 	end

-- 	System.dbResetQuery(db)

-- 	for k,v in ipairs(data) do
-- 		local dMail = {}
-- 		dMail.head = v.head
-- 		dMail.context = v.context
-- 		dMail.tAwardList = {}
-- 		dMail.tAwardList[1] = {}
-- 		tbl = dMail.tAwardList[1]
-- 		tbl.type = v.type
-- 		tbl.id = v.id
-- 		tbl.count = v.count

-- 		mailsystem.sendMailById(aId, dMail)
-- 	end
-- end

-- actorevent.reg(aeUserLogin, onLogin)



-- delimiter $$ 
-- CREATE PROCEDURE loadofflinemails()
-- begin
--     select `actorid`, `head`,`context`,`file0_type`,`file0_id`,`file0_num` from offlinemails;
-- end$$ 
-- delimiter ;


function gameStar()
	if not System.isCommSrv() then return end
	print("offlinemails.gameStar: begin")
	local db = System.createActorsDbConn()
	local err = System.dbQuery(db, "select `actorid`, `head`,`context`,`file0_type`,`file0_id`,`file0_num` from offlinemails;")
	if err ~= 0 then
		print("gameStar select offlinemails error:" .. err)
		return
	end
	local count = System.dbGetRowCount(db)
	local data = {}
	local tbl
	if count > 0 then
		local row = System.dbCurrentRow(db)
		for i=1, count do
			data[i] = {}
			tbl = data[i]
			tbl.aId = tonumber(System.dbGetRow(row, 0))
			tbl.head = System.dbGetRow(row, 1)
			tbl.context = System.dbGetRow(row, 2)
			tbl.type = tonumber(System.dbGetRow(row, 3))
			tbl.id =tonumber(System.dbGetRow(row, 4))
			tbl.count = tonumber(System.dbGetRow(row, 5))
			row = System.dbNextRow(db)
			print("offlinemails.gameStar:  read db" .. utils.t2s(tbl))
		end
	end
	System.dbResetQuery(db)

	err = System.dbExe(db, "delete from offlinemails;")
	System.dbClose(db)
	System.delActorsDbConn(db)
	if err ~= 0 then
		return
	end

	for k,v in ipairs(data) do
		local dMail = {}
		dMail.head = v.head
		dMail.context = v.context
		dMail.tAwardList = {}
		dMail.tAwardList[1] = {}
		tbl = dMail.tAwardList[1]
		tbl.type = v.type
		tbl.id = v.id
		tbl.count = v.count

		mailsystem.sendMailById(v.aId, dMail)
		print("offlinemails.gameStar:  send mail " .. v.aId)
	end
	print("offlinemails.gameStar: end")
end
engineevent.regGameStartEvent(gameStar)





