--[[
	Version: 0.1
	Limit of 256 read packet handlers.
	Limit of 256 write packet handlers.
	Packets can't span across multiple ticks, yet.
	There is a huge lack of error checking, invalid packet ids will cause issues.
	MAKE SURE that the readers from here match up to the writers, in order, from the other.
]]


---@alias byte integer
---@alias byte3float number


---@param value number
---@param quantum number
function ceil(value, quantum)
    local quant, frac = math.modf(value/quantum)
    return quantum * (quant + (frac > 0 and 1 or 0))
end

---@param from string
---@param to string
---@param ... number|string
---@return number|string ...
local function packunpack(from, to, ...)
	return string.unpack(to, string.pack(from, ...))
end

---@param a byte
---@param b byte
---@param c byte
---@return byte3float
local function encode(a, b, c)
	---@diagnostic disable-next-line: return-type-mismatch
	return (packunpack("BBBB", "<f", a, b, c, 1))
	-- return (string.unpack("<f", string.pack("BBBB", a, b, c, 1)))
end

---@param f byte3float
---@return byte, byte, byte
local function decode(f)
	local a, b, c = packunpack("<f", "BBBB", f)
	-- local a, b, c = string.unpack("BBBB", string.pack("<f", f))
	---@diagnostic disable-next-line: return-type-mismatch, missing-return-value
	return a or 0, b or 0, c or 0
end


---@class IOStream
local IOStream = {}
---@param bytes byte[]?
---@return IOStream
function IOStream.new(bytes)
	return shallowCopy(IOStream, bytes or {})
end

---@param stream IOStream|IOStream
function IOStream.writeStream(self, stream)
	table.move(stream, 1, #stream, #self+1, self)
end

---@return byte
function IOStream.peekUByte(self)
	return self[1]
end
---@param count integer
---@return byte[]
function IOStream.readUBytes(self, count)
	local bytes = table.move(self, 1, count, 1, {})
	for i=1,count do
		table.remove(self, 1)
	end
	return bytes
end
---@return byte
function IOStream.readUByte(self)
	return table.remove(self, 1)
end
---@param ubyte byte
function IOStream.writeUByte(self, ubyte)
	return table.insert(self, ubyte)
end

---@param min number
---@param max number
---@param decimals number  # Represented as `0.01`
function IOStream.readCustom(self, min, max, decimals)
	-- https://github.com/martindevans/StormPack/blob/master/Stormpack/PackSpec.cs#L53
	local range = max-min
	local bitCount = math.ceil(math.log(range/decimals, 2))
	local precision = (2 ^ -bitCount) * range
	local byteCount = math.ceil(bitCount/8)
	local valueDecoded = packunpack(string.rep("B", byteCount) .. string.rep("x", 8-byteCount), "J", table.unpack(self:readUBytes(byteCount)))
	return ceil(valueDecoded*precision + min, decimals)
end
---@param min number
---@param max number
---@param decimals number  # Represented as `0.01`
function IOStream.writeCustom(self, value, min, max, decimals)
	-- https://github.com/martindevans/StormPack/blob/master/Stormpack/PackSpec.cs#L53
	local range = max-min
	local bitCount = math.ceil(math.log(range/decimals, 2))
	local precision = (2 ^ -bitCount) * range
	local bytes = {packunpack("J", string.rep("B", math.ceil(bitCount/8)), math.floor((value-min)/precision))}
	---@cast bytes number[]
	for i=1,#bytes-1 do  -- Last byte isn't a byte, from string.unpack
		self:writeUByte(bytes[i])
	end
end

---@return string
function IOStream.readString(self)
	local size = self:readUByte()
	---@diagnostic disable-next-line: return-type-mismatch
	return (packunpack(string.rep("B", size), "c"..size, table.unpack(self:readUBytes(size))))
end
---@param s string
function IOStream.writeString(self, s)
	self:writeUByte(#s)
	local bytes = {packunpack("c"..#s, string.rep("B", #s), s)}
	table.remove(bytes, #bytes)
	for i, byte in ipairs(bytes) do
		---@cast byte -string
		self:writeUByte(byte)
	end
end

---@alias PacketReadHandlerFunc fun(binnet:Binnet, reader:IOStream): ...
---@alias PacketWriteHandlerFunc fun(binnet:Binnet, writer:IOStream, ...)


-- NOTE: ALL binnets share readers/writers!
---@class Binnet
Binnet = {
	---@type PacketReadHandlerFunc[]
	packetReaders={},
	---@type PacketWriteHandlerFunc[]
	packetWriters={},

	inStream=IOStream.new(),
	outStream=IOStream.new(),
	---@type IOStream[]
	outPackets={},
}

---@return Binnet
function Binnet.new(self)
	self = shallowCopy(self, {})
	self.outPackets = {}
	return self
end

---@param handler PacketReadHandlerFunc
function Binnet.registerPacketReader(self, handler)
	table.insert(self.packetReaders, handler)
end

---@param handler PacketWriteHandlerFunc
---@return integer packetWriterId
function Binnet.registerPacketWriter(self, handler)
	table.insert(self.packetWriters, handler)
	return #self.packetWriters
end

---@param packetWriterId integer
---@param ... any
function Binnet.send(self, packetWriterId, ...)
	local packetHandler = self.packetWriters[packetWriterId]
	local writer = IOStream.new()
	writer:writeUByte(0)
	writer:writeUByte(packetWriterId)
	packetHandler(self, writer, ...)
	writer[1] = #writer  -- Hacky way around writers only being append only. Not fixing due to char count.
	table.insert(self.outPackets, writer)
end

function Binnet.setLastUrgent(self)
	table.insert(self.outPackets, 1, table.remove(self.outPackets, #self.outPackets))
end

---@param values number[]
---@return integer byteCount, integer packetCount
function Binnet.process(self, values)
	for _, v in ipairs(values) do
		local a, b, c = decode(v)
		table.insert(self.inStream, a)
		table.insert(self.inStream, b)
		table.insert(self.inStream, c)
	end

	local totalByteCount, packetCount = 0, 0
	while true do
		local byteCount = self.inStream:peekUByte()
		if byteCount == 0 then
			self.inStream:readUByte()
		elseif byteCount == nil then
			break
		elseif #self.inStream >= byteCount then
			local reader = IOStream.new(self.inStream:readUBytes(byteCount))
			reader:readUByte()  -- We already peeked the byte count.
			local packetId = reader:readUByte()
			local packetHandler = self.packetReaders[packetId]
			if packetHandler == nil then
				log_error("No packet handler with id " .. tostring(packetId))
			else
				packetHandler(self, reader)
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
			local writer = table.remove(self.outPackets, 1)
			if writer == nil then
				break
			end
			self.outStream:writeStream(writer)
		end
		for i=1,math.min(#self.outStream,maxByteCount-#valuesBytes) do
			table.insert(valuesBytes, table.remove(self.outStream, 1))
		end
	end

	local values = {}
	for i=1,#valuesBytes,3 do
		table.insert(values, encode(valuesBytes[i], valuesBytes[i+1] or 0, valuesBytes[i+2] or 0))
	end

	return values
end
