require("interfaces.base")

INTERFACE.viewIndex = -1
INTERFACE.viewName = "Test 2"


local sentTick = 0
local pongTicks = 0

Binnet:registerPacketWriter(3, function (binnet, reader)
	-- debug.log("SW-MC Sending ping.")
	sentTick = tick
end)
Binnet:registerPacketReader(3, function (binnet, reader, packetId)
	pongTicks = tick - sentTick
	packetPong = true
end)


function viewReset()
end

function viewTick()
	if touchData.aPressed and not prevTouchData.aPressed then
		Binnet:send(3)
	end
	if tick % 30 == 0 then
		packetPong = false
	end
end

function viewDraw()
	screen.drawText(1, 11, ("Ping: %0.f ticks"):format(pongTicks))
	if packetPong then
		screen.setColor(0, 255, 0)
	else
		screen.setColor(255, 0, 0)
	end
	screen.drawRectF(10, 20, 50, 30)
end
