module("systems.instance.play.areaev", package.seeall)
setfenv(1, systems.instance.play.areaev)




function AreaEvDeal(evid, sceneid, x, y, actor)

	print("!!!!!!!!!!!!", evid, sceneid, x, y, actor)	
end

_G.onAreaEvDeal = AreaEvDeal

