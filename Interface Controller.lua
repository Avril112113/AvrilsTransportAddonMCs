-- require("LifeBoatAPI")
-- require("ExtraConsts")
-- require("LBShortend")
-- require("Debug")

require("helpers")
require("shared.binnet")

viewIndex = 2
VIEW_START_Y = 9
VIEWS = {
	{
		name = "Commuter",
		draw = function(self)
		end,
		update = function(self)
		end,
	},
	{
		name = "Company",
		draw = function(self)
			local y = VIEW_START_Y + 2
			screen.drawText(1, y, "Name: " .. companyData.name)
			y = y + 7
			screen.drawText(1, y, ("Money: $%.2f"):format(companyData.money))
			y = y + 7
			screen.drawText(1, y, "Licences:")
			y = y + 7
			for licence, _ in pairs(companyData.licences) do
				screen.drawText(6, y, licence)
				y = y + 7
			end
		end,
		update = function(self)
		end,
	},
	{
		name = "Trading",
		draw = function(self)
		end,
		update = function(self)
		end,
	},
	{
		name = "Freight",
		draw = function(self)
		end,
		update = function(self)
		end,
	},
}


-- BINNET_PACKET_LOADED = Binnet:registerPacketWriter(function(binnet, writer)
-- end)

-- UPDATE_INTERFACE
Binnet:registerPacketReader(function(binnet, reader)
	interfaceLocationName = reader:readString()
end)
-- UPDATE_COMPANY
Binnet:registerPacketReader(function(binnet, reader)
	if #reader <= 0 then
		if companyData ~= EMPTY_COMPANY_DATA then
			viewIndex = 2
		end
		companyData = EMPTY_COMPANY_DATA
		return
	end
	local name = reader:readString()
	if companyData.name ~= name then
		viewIndex = 2
	end
	companyData = {
		name=name,
		money=reader:readCustom(-(2^24), 2^24, 0.01),
		licences={},
	}
	for i=1,reader:readUByte() do
		companyData.licences[reader:readString()] = true
	end
end)

---@class CompanyData
EMPTY_COMPANY_DATA = {
	name="NO_COMPANY",
	money=9999999.99,
	---@type table<string, true>
	licences={},
}

__loaded = false
enabled = false
function onTick()
	local newEnabled = input.getNumber(10) ~= 0
	if not newEnabled and enabled or not __loaded then
		output.setNumber(1, 0)
		output.setNumber(2, 0)
		output.setNumber(3, 0)

		__loaded = true

		binnet = Binnet:new()

		commuterData = {}
		companyData = EMPTY_COMPANY_DATA
		tradingData = {}
		freightData = {}

		viewIndex = 2

		prevPageLeft = false
		prevPageRight = false
		prevConfirmBtn = false
		loaded = false
		tick = 0
	end
	enabled = newEnabled
	if not enabled then
		return
	end

	touchData = {
		size = {x=input.getNumber(1), y=input.getNumber(2)},
		aPressed = input.getBool(1),
		bPressed = input.getBool(2),
		aPos = {x=input.getNumber(3), y=input.getNumber(4)},
		bPos = {x=input.getNumber(5), y=input.getNumber(6)},
	}

	pageLeft = input.getNumber(7) ~= 0
	pageRight = input.getNumber(8) ~= 0
	confirmBtn = input.getNumber(9) ~= 0

	viewAdjust = pageLeft and not prevPageLeft and -1 or pageRight and not prevPageRight and 1 or 0
	viewIndex = ((viewIndex-1+viewAdjust) % #VIEWS) + 1

	binnetInput = {}
	for i=1,9 do
		binnetInput[i] = input.getNumber(10+i)
	end
	binnet:process(binnetInput)

	local view = VIEWS[viewIndex]
	view:update()

	ticketBlink = false

	output.setBool(1, ticketBlink and (tick % 60 > 30))

	binnetOutput = binnet:write(3)
	output.setNumber(1, binnetOutput[1] or 0)
	output.setNumber(2, binnetOutput[2] or 0)
	output.setNumber(3, binnetOutput[3] or 0)

	tick = tick + 1
	prevPageLeft = pageLeft
	prevPageRight = pageRight
	prevConfirmBtn = confirmBtn
end

function onDraw()
	if not enabled or not __loaded then
		return
	end

	local w, h = screen.getWidth(), screen.getHeight()

	local view = VIEWS[viewIndex]

	screen.setColor(255, 100, 0, 255)
	screen.drawRect(0, 0, w-1, 8)
	screen.drawRect(53, 0, 0, 8)

	screen.setColor(180, 180, 180, 255)
	screen.drawText(2, 2, (interfaceLocationName or "Loading"):gsub("_", " "):sub(1, 10))
	-- TODO: Consider another form, so we have more space for location name
	screen.drawText(55, 2, view.name)

	view:draw()
end
