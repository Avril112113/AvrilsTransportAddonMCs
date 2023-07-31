require("interfaces.base")

INTERFACE.viewIndex = 0
INTERFACE.viewName = "Mineral"

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
	writer:writeUByte(2)  -- Filter minerals only
	writer:writeUByte(0)  -- Filter quantity > 0
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
	table.sort(storageOrder)
	pendingStoragePacket = false
end)

-- Set selected producible (due to input mineral)
Binnet:registerPacketReader(20, function(binnet, reader)
	selectedProducible = #reader > 0 and reader:readString() or nil
end)
-- Send user selected producible
Binnet:registerPacketWriter(20, function(binnet, writer)
	_ = selectedProducible and writer:writeString(selectedProducible)
end)

Binnet:registerPacketReader(21, function(binnet, reader)
	transferAmount = reader:readCustom(-2^24, 2^24, 0.01)
	transferMoney = reader:readCustom(-2^24, 2^24, 0.01)
end)

-- Send user selected producible
Binnet:registerPacketWriter(22, function(binnet, writer)
	writer:writeUByte(transferState)
end)

function viewReset()
	INTERFACE.scroll = 10  -- 1 pixel below the orange line.
	page = 0

	selectedProducible = nil
	pendingStoragePacket = false
	transferState = 0
	transferAmount = 0
	transferMoney = 0
end

function viewTick()
	local prevSelectedProducible = selectedProducible
	if selectedProducible == nil and tick % 60 == 0 and pendingStoragePacket == false and INTERFACE.location ~= "LOADING" then
		pendingStoragePacket = true
		Binnet:send(2)
	end
	if touchData.pressed and not prevTouchData.pressed then
		if selectedProducible ~= nil then
			if touchData.pos.x >= 75 and touchData.pos.y >= 56 then
				viewReset()
				transferState = 0
			else
				transferState = touchData.pos.x >= touchData.size.x/1.5 and 1 or 0  -- Last 1/3rd of the screen
			end
			Binnet:send(22)
		else
			selectedProducible = storageOrder[(touchData.pos.y + page*64) // 8]
		end
	end
	if companyName ~= prevComanyName then
		selectedProducible = nil
	elseif companyName == nil and selectedProducible ~= nil then
		selectedProducible = nil
	end

	_ = selectedProducible ~= prevSelectedProducible and Binnet:send(20)

	if tick % 180 == 0 then
		page = math.floor((page+1) % ((#storageOrder+1)/8))
	end

	if selectedProducible == nil then
		transferState = 0
	end

	prevComanyName = companyName
end

function viewDraw()
	screen.setColor(255, 255, 255, 255)
	if selectedProducible == nil then
		y = 10 - INTERFACE.scroll - page*64
		screen.drawText(1, y, ("~ %s"):format(INTERFACE.location))
		y = y + 8
		for _, producibleName in ipairs(storageOrder) do
			screen.drawText(1, y, ("%g %s"):format(round(locationStorage[producibleName], 2), producibleName:gsub("_", " ")))
			y = y + 8
		end
	else
		screen.drawText(1, 0, ("Location %s Vehicle"):format(transferState > 0 and ">>" or "--"))
		screen.drawText(1, 8, ("$%+.2f %s"):format(produciblePrices[selectedProducible] or math.huge, selectedProducible:gsub("_", " ")))
		screen.drawText(76, 57, "BACK")
		equalColor = transferMoney == 0 and 100 or 0
		screen.setColor(transferMoney < 0 and 100 or equalColor, transferMoney > 0 and 100 or equalColor, equalColor, 255)
		screen.drawText(1, 16, ("$%+.2f"):format(transferMoney))
		screen.drawText(1, 24, (" %+g"):format(round(transferAmount, 2)))
	end
end

---@param value number
---@param decimals integer
function round(value, decimals)
	return tonumber(string.format("%."..(decimals//1).."f", value))
end
