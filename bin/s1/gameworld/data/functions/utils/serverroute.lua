module("serverroute", package.seeall)

function loadServerRoute()
	print("loadServerRoute start ...")
	local db = System.getGameEngineGlobalDbConn()
	local ret = System.dbConnect(db)
	if not ret then
		print("loadServerRoute fail, globaldb cannot connect.")
		return
	end

	local err = System.dbQuery(db, "call loadserverroute()")
	if err ~= 0 then
		print("loadServerRoute fail, dbQuery fail.")
		return
	end

	System.resetGameRoute()

	local srvId = System.getServerId()
	local selfRoute = {}

	local row = System.dbCurrentRow(db)
	local count = System.dbGetRowCount(db)

	for i=1, count do
		local serverid = System.dbGetRow(row, 0)
		local hostname = System.dbGetRow(row, 1)
		local port = System.dbGetRow(row, 2)
		-- System.addGameRoute(tonumber(serverid), hostname or "", tonumber(port))
		System.geAddRoutes(tonumber(serverid), hostname or "", tonumber(port))
		row = System.dbNextRow(db)

		if tonumber(serverid) == srvId then
			table.insert(selfRoute, {hostname or "", tonumber(port)})
		end
	end

	System.dbResetQuery(db)
	System.dbClose(db)

	print("loadServerRoute suces ...")

	-- 保存自己的路由数据
	saveSelfRoute(selfRoute)
end

function saveSelfRoute(selfRoute)
	if selfRoute == nil or type(selfRoute) ~= "table" then
		print("serverroute.saveSelfRoute parm is not a table")
		return
	end
	if #selfRoute == 0 then
		print("serverroute.saveSelfRoute route size = 0")
		return
	end

	local sdvar = System.getDyanmicVar()
	if sdvar == nil then print("serverroute.saveSelfRoute getDyanmicVar is null") return end

	print("serverroute.saveSelfRoute count:"..#selfRoute)
	-- 记录路由数据
	sdvar.SelfRoute = {}
	sdvar.SelfRoute.count = #selfRoute
	for i, tb in ipairs(selfRoute) do
		sdvar.SelfRoute[i] = {
			host = tb[1],
			port = tb[2],
		}
		print("serverroute.saveSelfRoute host = "..tb[1]..", port = "..tb[2])
	end

	-- 像之前连接上的服务器发送自己的路由数据
	if sdvar.ConnectSrv then
		local srvId = System.getServerId()
		for i = 1, sdvar.ConnectSrv.count do
			local dstSrv = sdvar.ConnectSrv[i]
			csbase.sendRouteData(srvId, dstSrv, sdvar.SelfRoute)
		end
		sdvar.ConnectSrv = nil
	end
end

