local socket = require('socket')

local connect_port = 3333
local ssh_sock = assert(socket.connect('127.0.0.1', ssh_port))
ssh_sock:settimeout(0)

print("Connected server...............")

local idx = 0

while true do
	local send_data = "Client send data:"..tostring(idx)
	idx = idx + 1

	ssh_sock:send(data)

	
end