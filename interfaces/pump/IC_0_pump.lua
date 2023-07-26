require("interfaces.base")

INTERFACE.viewIndex = 0
INTERFACE.viewName = "Pump"

---@type table<string,number>
produciblePrices = {}
---@type table<string,number>
locationStorage = {}
---@type string[]
storageOrder = {}

-- UPDATE_COMPANY
Binnet:registerPacketReader(1, function(binnet, reader)
	if #reader <= 0 then
		companyName = nil
	else
		companyName = reader:readString()
	end
end)
-- UPDATE_LOCATION_STORAGE
Binnet:registerPacketWriter(2, function (binnet, writer)
	writer:writeUByte(1)  -- Filter fluids only
	writer:writeUByte(0)  -- Only show fluids we have any of
end)
Binnet:registerPacketReader(2, function(binnet, reader)
	locationStorage = {}
	storageOrder = {}
	while #reader > 0 do
		producibleName = reader:readString()
		if locationStorage[producibleName] == nil then
			table.insert(storageOrder, producibleName)
		end
		locationStorage[producibleName] = reader:readCustom(-2^24, 2^24, 0.01)
	end
	pendingStoragePacket = false
end)

-- Pumping into location
Binnet:registerPacketReader(20, function(binnet, reader)
	selectedProducible = #reader > 0 and reader:readString() or nil
end)
-- Selected producible to pump out of location
Binnet:registerPacketWriter(20, function(binnet, writer)
	_ = selectedProducible and writer:writeString(selectedProducible)
end)

Binnet:registerPacketReader(21, function(binnet, reader)
	pumpAmount = reader:readCustom(-2^24, 2^24, 0.01)
	pumpMoney = reader:readCustom(-2^24, 2^24, 0.01)
end)

function viewReset()
	INTERFACE.scroll = 10  -- 1 pixel below the orange line.
	page = 0

	companyName = nil
	selectedProducible = nil
	pendingStoragePacket = false
	pumpingState = -1  -- Default pump into location, so we can detect what fluid the player is pumping.
	pumpAmount = 0
	pumpMoney = 0
end

function viewTick()
	if selectedProducible == nil and tick % 60 == 0 and pendingStoragePacket == false and INTERFACE.location ~= "LOADING" then
		pendingStoragePacket = true
		Binnet:send(2)
	end
	if touchData.pressed and not prevTouchData.pressed then
		if selectedProducible ~= nil then
			if touchData.pos.x >= 75 and touchData.pos.y >= 24 then
				viewReset()
				pumpingState = -1
			else
				pumpingState = touchData.pos.x // (touchData.size.x/3) - 1
			end
		else
			selectedProducible = storageOrder[(touchData.pos.y + page*32) // 8]
			pumpingState = selectedProducible ~= nil and 0 or 1
			Binnet:send(20)
		end
	end
	if companyName ~= prevComanyName then
		selectedProducible = nil
		Binnet:send(20)
	end

	if tick % 180 == 0 then
		page = math.floor((page+1) % ((#storageOrder+1)/4))
	end

	if selectedProducible == nil then
		pumpingState = -1
	end

	output.setBool(1, pumpingState < 0)  -- Into location storage
	output.setBool(2, pumpingState > 0)  -- Out of location storage
	output.setBool(3, selectedProducible == nil)

	prevComanyName = companyName
end

function viewDraw()
	screen.setColor(255, 255, 255, 255)
	if selectedProducible == nil then
		y = 10 - INTERFACE.scroll - page*32
		screen.drawText(1, y, ("~ %s"):format(INTERFACE.location))
		y = y + 8
		for _, producibleName in ipairs(storageOrder) do
			screen.drawText(1, y, ("%.2fl %s"):format(locationStorage[producibleName], producibleName))
			y = y + 8
		end
	else
		screen.drawText(1, 0, ("Location %s Vehicle"):format(pumpingState < 0 and "<<" or pumpingState > 0 and ">>" or "--"))
		screen.drawText(1, 8, ("$%+.2f/l %s"):format(produciblePrices[selectedProducible] or math.huge, selectedProducible))
		screen.drawText(76, 25, "BACK")
		pumpEqualColor = pumpMoney == 0 and 100 or 0
		screen.setColor(pumpMoney < 0 and 100 or pumpEqualColor, pumpMoney > 0 and 100 or pumpEqualColor, pumpEqualColor, 255)
		screen.drawText(1, 16, ("$%+.2f"):format(pumpMoney))
		screen.drawText(1, 24, (" %+.2f/l"):format(pumpAmount))
	end
end
