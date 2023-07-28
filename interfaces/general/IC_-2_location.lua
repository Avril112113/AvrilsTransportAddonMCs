require("interfaces.base")

INTERFACE.viewIndex = -2
INTERFACE.viewName = "Location"

INFRASTRUCTURE_TAGS = {"station", "dock", "airstrip", "helipad", "ground"}
-- Minifier is scuffing up the names
INTERFACE_TAGS = {["pump"]=0, ["mineral"]=1}


---@type table<string, {general:boolean?,pump:boolean?,mineral:boolean?,recipe:{[1]:string,[2]:number}[]?}>
infrastructure = {}
infrastructureOrder = {}

Binnet:registerPacketReader(20, function(binnet, reader)
	infrastructure = {}
	infrastructureOrder = {}
	while #reader > 0 do
		local infraName = reader:readString()
		local infra = {}
		infrastructure[infraName] = infra
		table.insert(infrastructureOrder, infraName)
		local flags = reader:readUByte()
		for interfaceTag, i in pairs(INTERFACE_TAGS) do
			infra[interfaceTag] = flags & (1<<i) ~= 0
		end
		if flags & (1<<7) ~= 0 then
			local producibleCount = reader:readUByte()
			infra.recipe = {}
			for i=1,producibleCount do
				-- Insert over anything else to preserve order AND to keep consume and produce seperated.
				table.insert(infra.recipe, {reader:readString(), reader:readCustom(-2^24, 2^24, 0.01)})
			end
		end
	end
end)


function viewReset()
	---@type string?
	selectedInfraName = nil

	Binnet:send(20)
end

function viewTick()
	if touchData.pressed and not prevTouchData.pressed then
		if selectedInfraName == nil then
			selectedInfraName = infrastructureOrder[(touchData.pos.y+INTERFACE.scroll)//8 + (INTERFACE.scroll == 0 and 0 or 1)]
		elseif touchData.pos.x >= 75 and touchData.pos.y >= 56 then
			selectedInfraName = nil
		end
	end
end

function viewDraw()
	y = 10 - INTERFACE.scroll
	if selectedInfraName ~= nil then
		infra = infrastructure[selectedInfraName]
		screen.drawText(1, y, "~ " .. selectedInfraName)
		y = y + 8
		for interfaceTag, i in pairs(INTERFACE_TAGS) do
			if infra[interfaceTag] then
				screen.drawText(1, y, interfaceTag)
				y = y + 8
			end
		end
		if infra.recipe then
			for _, recipeItem in ipairs(infra.recipe) do
				screen.drawText(1, y, ("%+g/H %s"):format(round(recipeItem[2], 1), recipeItem[1]))
				y = y + 8
			end
		end
		screen.drawText(76, 57, "BACK")
	else
		for _, infraName in ipairs(infrastructureOrder) do
			screen.drawText(1, y, (infraName:gsub("_", " ")))
			y = y + 8
		end
	end
end


---@param value number
---@param decimals integer
function round(value, decimals)
	return tonumber(string.format("%."..(decimals//1).."f", value))
end