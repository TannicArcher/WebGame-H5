module("test.test_jobsystem", package.seeall)
setfenv(1, test.test_jobsystem)

local jobsys = require("systems.jobsystem.jobsystem")
require("protocol")

local systemId = SystemId.enCommonSystemID
local protocol = CommonSystemProtocol

function test_transfer(actor, job)
	local pack = LDataPack.test_allocPack()
	if not pack then return end

	LDataPack.writeByte(pack , job)
	LDataPack.setPosition(pack, 0)

	jobsys.transferJob(actor, pack)
end

_G.test_transfer = test_transfer
