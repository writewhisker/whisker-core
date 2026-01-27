-- lib/whisker/utils/uuid.lua
-- UUID v4 generation for IFID (Interactive Fiction ID)
-- Implements GAP-021: IFID Generation

local UUID = {}

--- Generate a random UUID v4
---@return string UUID in standard format (uppercase)
function UUID.v4()
    -- Get random bytes
    local random_bytes = {}
    for i = 1, 16 do
        random_bytes[i] = math.random(0, 255)
    end

    -- Set version (4) in byte 7: clear top 4 bits, set to 0100
    random_bytes[7] = (random_bytes[7] % 16) + 64  -- 0100xxxx

    -- Set variant (RFC 4122) in byte 9: clear top 2 bits, set to 10
    random_bytes[9] = (random_bytes[9] % 64) + 128  -- 10xxxxxx

    -- Format as UUID string
    local hex = {}
    for i, byte in ipairs(random_bytes) do
        hex[i] = string.format("%02X", byte)
    end

    return string.format(
        "%s%s%s%s-%s%s-%s%s-%s%s-%s%s%s%s%s%s",
        hex[1], hex[2], hex[3], hex[4],
        hex[5], hex[6],
        hex[7], hex[8],
        hex[9], hex[10],
        hex[11], hex[12], hex[13], hex[14], hex[15], hex[16]
    )
end

--- Check if a string is a valid UUID format
---@param str string
---@return boolean
function UUID.is_valid(str)
    if not str or type(str) ~= "string" then
        return false
    end

    -- Check format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (36 chars)
    if #str ~= 36 then
        return false
    end

    -- Check pattern with correct dash positions
    local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
    return str:upper():match(pattern) ~= nil
end

--- Check if a string is a valid UUID v4
---@param str string
---@return boolean
function UUID.is_valid_v4(str)
    if not UUID.is_valid(str) then
        return false
    end

    local upper = str:upper()

    -- Check version (4) at position 15
    if upper:sub(15, 15) ~= "4" then
        return false
    end

    -- Check variant (8, 9, A, or B) at position 20
    local variant = upper:sub(20, 20)
    if not variant:match("[89AB]") then
        return false
    end

    return true
end

--- Normalize a UUID to uppercase
---@param uuid string
---@return string|nil
function UUID.normalize(uuid)
    if not uuid then
        return nil
    end
    return uuid:upper()
end

--- Parse a UUID string into its components
---@param uuid string
---@return table|nil { time_low, time_mid, time_hi_version, clock_seq, node }
function UUID.parse(uuid)
    if not UUID.is_valid(uuid) then
        return nil
    end

    local upper = uuid:upper()
    return {
        time_low = upper:sub(1, 8),
        time_mid = upper:sub(10, 13),
        time_hi_version = upper:sub(15, 18),
        clock_seq = upper:sub(20, 23),
        node = upper:sub(25, 36)
    }
end

--- Generate a nil UUID (all zeros)
---@return string
function UUID.nil_uuid()
    return "00000000-0000-0000-0000-000000000000"
end

--- Check if a UUID is the nil UUID
---@param uuid string
---@return boolean
function UUID.is_nil(uuid)
    if not uuid then
        return false
    end
    return uuid:upper() == "00000000-0000-0000-0000-000000000000"
end

return UUID
