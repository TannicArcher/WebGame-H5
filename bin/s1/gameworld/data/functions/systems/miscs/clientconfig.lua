module("clientconfig", package.seeall)



local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        print("get client static data err")
        return nil
    end

    if var.cliCfg == nil then
        var.cliCfg = {}
		if var.clientConfig then
			var.cliCfg[1] = {}
			var.cliCfg[1].key = 0
			var.cliCfg[1].val = var.clientConfig.p1
			
			var.cliCfg[2] = {}
			var.cliCfg[2].key = 1
			var.cliCfg[2].val = var.clientConfig.p2
		end
    end
    return var.cliCfg
end


local function onUpdateConfig(actor, packet)
    local key = LDataPack.readInt(packet)
	local val = LDataPack.readInt(packet)

    local data = getStaticData(actor)
    if data == nil then return end
	local isfind = false
	local dlen = #data
	for i = 1,dlen do
		local d = data[i]
		if d.key == key then
			d.val = val
			isfind = true
		end
	end
	if not isfind then
		data[dlen+1] = {}
		data[dlen+1].key = key
		data[dlen+1].val = val
	end
end

local function onLogin(actor)
    local data = getStaticData(actor)
    if data == nil then return end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Base, Protocol.sBaseCmd_ClientConfig)
    if npack == nil then return end
	local dlen = #data
	LDataPack.writeShort(npack, dlen)
	for i = 1,dlen do
		local d = data[i]
		LDataPack.writeInt(npack, d.key)
		LDataPack.writeInt(npack, d.val or 0)
	end
    LDataPack.flush(npack)
end

actorevent.reg(aeUserLogin, onLogin)
netmsgdispatcher.reg(Protocol.CMD_Base, Protocol.cBaseCmd_ClientConfig, onUpdateConfig)
