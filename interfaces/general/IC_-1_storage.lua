require("interfaces.base")

INTERFACE.viewIndex = -1
INTERFACE.viewName = "Storage"


---@type table<string,number>
locationStorage = {}
---@type string[]
storageOrder = {}

-- UPDATE_LOCATION_STORAGE
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


function viewReset()
	pendingStoragePacket = false
	INTERFACE.scroll = 0
end

function viewTick()
	if tick % 60 == 0 and pendingStoragePacket == false and INTERFACE.location ~= "LOADING" then
		pendingStoragePacket = true
		Binnet:send(2)
	end

	if tick % 180 == 0 then
		local pagePixels = 8*8
		INTERFACE.scroll = (INTERFACE.scroll/pagePixels + 1) % math.ceil((#storageOrder+1) / 8) * pagePixels
	end
end

function viewDraw()
	screen.setColor(255, 255, 255, 255)
	y = 10 - INTERFACE.scroll
	for _, producibleName in ipairs(storageOrder) do
		screen.drawText(1, y, ("%s %.2fl"):format(producibleName, locationStorage[producibleName]))
		y = y + 8
	end
end
