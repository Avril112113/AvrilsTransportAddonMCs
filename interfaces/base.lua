-- require("LifeBoatAPI")
-- require("ExtraConsts")
-- require("LBShortend")
-- require("Debug")

require("helpers")
require("shared.iostream")
require("shared.binnet_short")


VIEW_MIN = property.getNumber("View Min")
VIEW_MAX = property.getNumber("View Max")
VIEW_COUNT = VIEW_MAX - VIEW_MIN + 1


Binnet = Binnet:new()
-- UPDATE_INTERFACE
Binnet:registerPacketReader(0, function(binnet, reader)
	INTERFACE.location = reader:readString()
end)


INTERFACE = {
    location="LOADING",
	viewIndex=0,
	scroll=0,
}

__loaded = false
__enabled = false
function onTick()
	touchData = {
		size = {x=input.getNumber(1), y=input.getNumber(2)},
		pressed = input.getBool(1),
		-- bPressed = input.getBool(2),
		pos = {x=input.getNumber(3), y=input.getNumber(4)},
		-- bPos = {x=input.getNumber(5), y=input.getNumber(6)},
	}

	__newEnabled = input.getNumber(10) ~= 0
	if not __newEnabled and __enabled or not __loaded then
		output.setNumber(1, 0)
		output.setNumber(2, 0)
		output.setNumber(3, 0)

		__loaded = true

		prevConfirmBtn = false
		tick = 0

		prevTouchData = touchData

		viewReset()
	end
	__enabled = __newEnabled
	if not __enabled then
		return
	end

	viewIndex = input.getNumber(32)
	if INTERFACE.viewIndex == 0 then
		viewIndexOut = (((viewIndexOut or 0) + (input.getNumber(8) - input.getNumber(7)) - VIEW_MIN) % VIEW_COUNT) + VIEW_MIN
	end

	confirmBtn = input.getNumber(9) ~= 0

	__binnetInput = {}
	for i=1,9 do
		__binnetInput[i] = input.getNumber(10+i)
	end
	Binnet:process(__binnetInput)

	if INTERFACE.viewIndex == viewIndex then
		viewTick()
	end

	-- ---@diagnostic disable-next-line: undefined-global
	-- output.setBool(1, ticketBlink and (tick % 60 > 30))

	__binnetOutput = Binnet:write(3)
	output.setNumber(1, __binnetOutput[1] or 0)
	output.setNumber(2, __binnetOutput[2] or 0)
	output.setNumber(3, __binnetOutput[3] or 0)

	output.setNumber(32, viewIndexOut)

	tick = tick + 1
	prevConfirmBtn = confirmBtn
	prevTouchData = touchData
end

function onDraw()
	if INTERFACE.viewIndex == viewIndex then
		w, h = screen.getWidth(), screen.getHeight()
		screen.setColor(255, 100, 0)
		screen.drawRect(0, 0 - INTERFACE.scroll, w-1, 8)
		screen.drawRect(53, 0 - INTERFACE.scroll, 0, 8)
		screen.setColor(180, 180, 180)
		screen.drawText(2, 2 - INTERFACE.scroll, INTERFACE.location:gsub("_", " "):sub(1, 10))
		screen.drawText(55, 2 - INTERFACE.scroll, INTERFACE.viewName)

		viewDraw()
	end
end
