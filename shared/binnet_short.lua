--[[
	Version: 0.1 (Shorter version)
	Limit of 256 read packet handlers.
	Limit of 256 write packet handlers.
	Packets can't span across multiple ticks, yet.
	There is a huge lack of error checking, invalid packet ids will cause issues.
	MAKE SURE that the readers from here match up to the writers, in order, from the other.

	Shorter version:
		Packets are not seperated in the output stream, so no high priority packets.
]]


---@param a byte
---@param b byte
---@param c byte
---@return number
function binnet_encode(a, b, c)
	---@diagnostic disable-next-line: return-type-mismatch
	return (iostream_packunpack("BBBB", "<f", a, b, c, 1))
	-- return (string.unpack("<f", string.pack("BBBB", a, b, c, 1)))
end

---@param f number
---@return byte, byte, byte
function binnet_decode(f)
	local a, b, c = iostream_packunpack("<f", "BBBB", f)
	-- local a, b, c = string.unpack("BBBB", string.pack("<f", f))
	---@diagnostic disable-next-line: return-type-mismatch, missing-return-value
	return a or 0, b or 0, c or 0
end


---@alias PacketReadHandlerFunc fun(binnet:Binnet, reader:IOStream, packetId:integer)
---@alias PacketWriteHandlerFunc fun(binnet:Binnet, writer:IOStream, ...)


-- NOTE: ALL binnets share readers/writers!
---@class Binnet
---@field inStream IOStream
---@field outStream IOStream
Binnet = {
	---@type PacketReadHandlerFunc[]
	packetReaders={},
	---@type PacketWriteHandlerFunc[]
	packetWriters={},
}

---@return Binnet
function Binnet.new(self)
	self = shallowCopy(self, {})
	self.packetReaders = shallowCopy(self.packetReaders, {})
	self.packetWriters = shallowCopy(self.packetWriters, {})
	self.inStream = IOStream.new()
	self.outStream = IOStream.new()
	return self
end

---@param handler PacketReadHandlerFunc
---@param packetId integer # Range: 0-255
function Binnet.registerPacketReader(self, packetId, handler)
	self.packetReaders[packetId] = handler
end

---@param handler PacketWriteHandlerFunc
---@param packetId integer # Range: 0-255
---@return integer packetWriterId
function Binnet.registerPacketWriter(self, packetId, handler)
	self.packetWriters[packetId] = handler
	return packetId
end

---@param packetWriterId integer
---@param ... any
function Binnet.send(self, packetWriterId, ...)
	local writer = IOStream.new()
	writer:writeUByte(0)
	writer:writeUByte(packetWriterId)
	_ = self.packetWriters[packetWriterId] and self.packetWriters[packetWriterId](self, writer, ...)
	writer[1] = #writer  -- Hacky way around writers only being append only. Not fixing due to char count.
	self.outStream:writeStream(writer)
end

---@param values number[]
---@return integer byteCount, integer packetCount
function Binnet.process(self, values)
	for _, v in ipairs(values) do
		local a, b, c = binnet_decode(v)
		table.insert(self.inStream, a)
		table.insert(self.inStream, b)
		table.insert(self.inStream, c)
	end

	local totalByteCount, packetCount = 0, 0
	while true do
		local byteCount = self.inStream[1]
		if byteCount == 0 then
			self.inStream:readUByte()
		elseif byteCount == nil then
			break
		elseif #self.inStream >= byteCount then
			local reader = IOStream.new(self.inStream:readUBytes(byteCount))
			reader:readUByte()  -- We already peeked the byte count.
			local packetId = reader:readUByte()
			local packetHandler = self.packetReaders[packetId]
			if packetHandler then
				packetHandler(self, reader, packetId)
			end
			totalByteCount = totalByteCount + byteCount
			packetCount = packetCount + 1
		else
			break
		end
	end
	return totalByteCount, packetCount
end

---@param valueCount integer # The amount of values we can send out.
---@return number[]
function Binnet.write(self, valueCount)
	local maxByteCount = valueCount*3
	local valuesBytes = {}
	while #valuesBytes < maxByteCount do
		if #self.outStream <= 0 then
			break
		end
		for i=1,math.min(#self.outStream,maxByteCount-#valuesBytes) do
			table.insert(valuesBytes, table.remove(self.outStream, 1))
		end
	end

	local values = {}
	for i=1,#valuesBytes,3 do
		table.insert(values, binnet_encode(valuesBytes[i], valuesBytes[i+1] or 0, valuesBytes[i+2] or 0))
	end

	return values
end
