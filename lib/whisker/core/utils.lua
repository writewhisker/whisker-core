-- lib/whisker/core/utils.lua
-- WLS 1.0 Core Utility Functions
-- Provides WLS-compliant helpers including truthiness evaluation

local Utils = {}

--- Check if a value is truthy according to WLS specification
-- WLS truthiness differs from Lua: 0 and "" are falsy
-- @param value any The value to check
-- @return boolean True if the value is truthy
function Utils.is_truthy(value)
    -- Standard Lua falsy values
    if value == nil or value == false then
        return false
    end

    -- WLS-specific falsy values
    if type(value) == "number" and value == 0 then
        return false
    end

    if type(value) == "string" and value == "" then
        return false
    end

    -- Everything else is truthy (including empty tables, functions, etc.)
    return true
end

--- Check if a value is falsy according to WLS specification
-- Inverse of is_truthy
-- @param value any The value to check
-- @return boolean True if the value is falsy
function Utils.is_falsy(value)
    return not Utils.is_truthy(value)
end

--- Convert a value to boolean using WLS truthiness rules
-- @param value any The value to convert
-- @return boolean The boolean equivalent
function Utils.to_boolean(value)
    return Utils.is_truthy(value)
end

--- Safe string conversion with nil handling
-- @param value any The value to convert
-- @return string The string representation
function Utils.safe_tostring(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

--- Deep clone a table
-- @param original table The table to clone
-- @return table A deep copy of the table
function Utils.deep_clone(original)
    if type(original) ~= "table" then
        return original
    end

    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = Utils.deep_clone(v)
        else
            copy[k] = v
        end
    end

    return copy
end

--- Trim whitespace from beginning and end of string
-- @param str string The string to trim
-- @return string The trimmed string
function Utils.trim(str)
    if type(str) ~= "string" then
        return str
    end
    return str:match("^%s*(.-)%s*$")
end

--- Check if a table contains a value
-- @param tbl table The table to search
-- @param value any The value to find
-- @return boolean True if found
function Utils.contains(tbl, value)
    if type(tbl) ~= "table" then
        return false
    end
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

--- Merge two tables (shallow)
-- @param base table The base table
-- @param overlay table The table to merge on top
-- @return table A new merged table
function Utils.merge(base, overlay)
    local result = {}
    for k, v in pairs(base or {}) do
        result[k] = v
    end
    for k, v in pairs(overlay or {}) do
        result[k] = v
    end
    return result
end

return Utils
