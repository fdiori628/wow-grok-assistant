-- Pixel codec for WoWGrokAssistant. Pure Lua, no WoW APIs.
-- Based on the design used by wow-ai and WowGrok.
--
-- Frame bytes:
--   [0xC7 0x1A] [id hi, id lo] [len hi, len lo] [payload: len bytes] [fletcher s1, s2]
-- Checksum covers id..payload.
-- Bytes packed MSB-first into 3-bit cells.
-- Each cell is drawn with R/G/B fully on or off (bit2=R, bit1=G, bit0=B).

WoWGrok_Codec = {}
local C = WoWGrok_Codec

C.MAGIC1, C.MAGIC2 = 0xC7, 0x1A
C.BITS = 3
C.MAX_PAYLOAD = 6000

function C.Fletcher16(bytes, from, to)
	local s1, s2 = 0, 0
	for i = from, to do
		s1 = (s1 + bytes[i]) % 255
		s2 = (s2 + s1) % 255
	end
	return s1, s2
end

-- Returns array of cell values (0..7) and byte count, or nil, error.
function C.Encode(id, payload)
	payload = payload or ""
	local len = #payload
	if len > C.MAX_PAYLOAD then
		return nil, "Message too long for pixel strip (max " .. C.MAX_PAYLOAD .. " bytes)"
	end
	local bytes = {
		C.MAGIC1, C.MAGIC2,
		math.floor(id / 256) % 256, id % 256,
		math.floor(len / 256) % 256, len % 256,
	}
	for i = 1, len do
		bytes[#bytes + 1] = payload:byte(i)
	end
	local s1, s2 = C.Fletcher16(bytes, 3, 6 + len)
	bytes[#bytes + 1] = s1
	bytes[#bytes + 1] = s2

	local cells = {}
	local acc, nbits = 0, 0
	for i = 1, #bytes do
		acc = acc * 256 + bytes[i]
		nbits = nbits + 8
		while nbits >= 3 do
			local shift = nbits - 3
			local div = 2 ^ shift
			cells[#cells + 1] = math.floor(acc / div) % 8
			nbits = shift
			acc = acc % div
		end
	end
	if nbits > 0 then
		cells[#cells + 1] = (acc * 2 ^ (3 - nbits)) % 8
	end
	return cells, #bytes
end

function C.CellColor(v)
	local r = math.floor(v / 4) % 2
	local g = math.floor(v / 2) % 2
	local b = v % 2
	return r, g, b
end
