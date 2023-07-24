require("helpers")
require("shared.iostream")
require("shared.binnet")


local writeBinnet

---@type PacketReadHandlerFunc
local function packetReader(binnet, reader, packetId)
	-- debug.log(("SW-MC Got packet %.0f with %.0f bytes."):format(packetId, #reader))
	writeBinnet:send(packetId, reader)
end

---@type PacketWriteHandlerFunc
local function packetWriter(binnet, writer, reader)
	-- debug.log(("SW-MC Echoing %.0f bytes."):format(#reader))
	writer:writeStream(reader)
end

for i=0,255 do
	Binnet:registerPacketReader(i, packetReader)
	Binnet:registerPacketWriter(i, packetWriter)
end


writeBinnet = Binnet:new()

---@type table<integer,Binnet>
local readBinnets = {}
for i=1,32,3 do
	readBinnets[i] = Binnet:new()
end

local enabled = false
function onTick()
	local newEnabled = input.getBool(1)
	if newEnabled ~= enabled then
		output.setNumber(1, 0)
		output.setNumber(2, 0)
		output.setNumber(3, 0)
	end
	enabled = newEnabled
	if not enabled then
		return
	end

	for i=1,32,3 do
		local readBinnet = readBinnets[i]
		local binnetInput = {}
		for j=1,3 do
			binnetInput[j] = input.getNumber(i+j-1)
		end
		readBinnet:process(binnetInput)
	end

	local binnetOutput = writeBinnet:write(3)
	output.setNumber(1, binnetOutput[1] or 0)
	output.setNumber(2, binnetOutput[2] or 0)
	output.setNumber(3, binnetOutput[3] or 0)
end
