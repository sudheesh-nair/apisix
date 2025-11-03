local bit = require("bit")
local openssl_rand = require("resty.openssl.rand")

local KSUID = {}

-- KSUID epoch (14e8 = 1400000000)
local KSUID_EPOCH = 1400000000

-- Base62 encoding characters
local BASE62_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

-- Generate a random 16-byte string using resty.openssl.rand
local function random_bytes()
    return openssl_rand.bytes(16)
end

-- Convert a 4-byte number to a big-endian binary string
local function int_to_bytes(num)
    return string.char(
        bit.band(bit.rshift(num, 24), 0xFF),
        bit.band(bit.rshift(num, 16), 0xFF),
        bit.band(bit.rshift(num, 8), 0xFF),
        bit.band(num, 0xFF)
    )
end

-- Base62 encode function (corrected to process bytes safely)
local function base62_encode(data)
    local bytes = {data:byte(1, #data)}
    local encoded = {} -- Use a table instead of a string
    local value = {}
    
    -- Convert binary data into Base62 directly, without large integer conversion
    for _, byte in ipairs(bytes) do
        table.insert(value, byte)
    end
    
    while #value > 0 do
        local remainder = 0
        local new_value = {}
        for i, v in ipairs(value) do
            local combined = remainder * 256 + v
            local div = math.floor(combined / 62)
            remainder = combined % 62
            if #new_value > 0 or div > 0 then
                table.insert(new_value, div)
            end
        end
        table.insert(encoded, 1, BASE62_ALPHABET:sub(remainder + 1, remainder + 1))
        value = new_value
    end
    
    -- Ensure the encoded KSUID is exactly 27 characters long
    while #encoded < 27 do
        table.insert(encoded, 1, "0")
    end
    
    return table.concat(encoded) -- Convert table to string
end

-- Generate a KSUID
function KSUID.generate()
    local timestamp = os.time() - KSUID_EPOCH
    local timestamp_bytes = int_to_bytes(timestamp)
    local random_payload = random_bytes()
    local ksuid_bytes = timestamp_bytes .. random_payload
    
    -- Ensure proper randomness in Base62 encoding
    return base62_encode(ksuid_bytes)
end

return KSUID