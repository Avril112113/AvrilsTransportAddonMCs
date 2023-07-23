---@alias byte integer


---@param from string
---@param to string
---@param ... number|string
---@return number|string ...
function iostream_packunpack(from, to, ...)
	return string.unpack(to, string.pack(from, ...))
end

-- Inlined at use location.
-- ---@param value number
-- ---@param quantum number
-- function iostream_ceil(value, quantum)
--     local quant, frac = math.modf(value/quantum)
--     return quantum * (quant + (frac > 0 and 1 or 0))
-- end


---@class IOStream
---@field [integer] byte
IOStream = {}
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
	local valueDecoded = iostream_packunpack(string.rep("B", byteCount) .. string.rep("x", 8-byteCount), "J", table.unpack(self:readUBytes(byteCount)))
	-- return iostream_ceil(valueDecoded*precision + min, decimals)
    local quant, frac = math.modf((valueDecoded*precision + min)/decimals)
    return decimals * (quant + (frac > 0 and 1 or 0))
end
---@param min number
---@param max number
---@param decimals number  # Represented as `0.01`
function IOStream.writeCustom(self, value, min, max, decimals)
	-- https://github.com/martindevans/StormPack/blob/master/Stormpack/PackSpec.cs#L53
	local range = max-min
	local bitCount = math.ceil(math.log(range/decimals, 2))
	local precision = (2 ^ -bitCount) * range
	local bytes = {iostream_packunpack("J", string.rep("B", math.ceil(bitCount/8)), math.floor((value-min)/precision))}
	---@cast bytes number[]
	for i=1,#bytes-1 do  -- Last byte isn't a byte, from string.unpack
		self:writeUByte(bytes[i])
	end
end

---@return string
function IOStream.readString(self)
	local size = self:readUByte()
	---@diagnostic disable-next-line: return-type-mismatch
	return (iostream_packunpack(string.rep("B", size), "c"..size, table.unpack(self:readUBytes(size))))
end
---@param s string
function IOStream.writeString(self, s)
	self:writeUByte(#s)
	local bytes = {iostream_packunpack("c"..#s, string.rep("B", #s), s)}
	table.remove(bytes, #bytes)
	for i, byte in ipairs(bytes) do
		---@cast byte -string
		self:writeUByte(byte)
	end
end
