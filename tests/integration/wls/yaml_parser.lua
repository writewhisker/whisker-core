-- tests/integration/wls/yaml_parser.lua
-- Enhanced YAML parser for WLS test corpus
-- Supports arrays, multi-line literals, and nested structures

local M = {}

--- Strip UTF-8 BOM from content
local function stripBOM(content)
    if content:sub(1, 3) == "\xEF\xBB\xBF" then
        return content:sub(4)
    end
    return content
end

--- Count leading spaces
local function countIndent(line)
    local spaces = line:match("^( *)")
    return #spaces
end

--- Trim whitespace
local function trim(str)
    if not str then return "" end
    return str:match("^%s*(.-)%s*$")
end

--- Parse scalar value
local function parseScalar(value)
    if value == nil or value == "" then
        return nil
    end

    value = trim(value)

    -- Handle quoted strings
    if value:match('^"') then
        local inner = value:match('^"(.-)"$')
        if inner then
            inner = inner:gsub('\\n', '\n')
                         :gsub('\\r', '\r')
                         :gsub('\\t', '\t')
                         :gsub('\\"', '"')
                         :gsub('\\\\', '\\')
            return inner
        end
        return value
    elseif value:match("^'") then
        local inner = value:match("^'(.-)'$")
        if inner then
            return inner:gsub("''", "'")
        end
        return value
    end

    -- Handle special values
    local lower = value:lower()
    if lower == "null" or lower == "~" or value == "" then
        return nil
    elseif lower == "true" or lower == "yes" then
        return true
    elseif lower == "false" or lower == "no" then
        return false
    end

    -- Handle numbers
    local num = tonumber(value)
    if num then
        return num
    end

    return value
end

--- Parse YAML content with array support
function M.parse(content)
    content = stripBOM(content)

    -- Normalize line endings
    content = content:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Split into lines
    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
        table.insert(lines, line)
    end

    -- Remove trailing empty line
    if #lines > 0 and lines[#lines] == "" then
        table.remove(lines)
    end

    local lineNum = 1

    -- Check if this is the start of a literal block (|)
    local function isLiteralBlock(value)
        return value and (value:match("^|%s*$") or value:match("^|%-?%s*$"))
    end

    -- Parse a literal block (multi-line string with |)
    local function parseLiteralBlock(baseIndent)
        local literalLines = {}
        local contentIndent = nil

        while lineNum <= #lines do
            local line = lines[lineNum]

            -- Empty lines are included
            if line:match("^%s*$") then
                table.insert(literalLines, "")
                lineNum = lineNum + 1
            else
                local indent = countIndent(line)
                if indent <= baseIndent then
                    -- End of literal block
                    break
                end

                -- Determine content indent from first non-empty line
                if not contentIndent then
                    contentIndent = indent
                end

                -- Remove the content indentation
                local content_line = line:sub(contentIndent + 1)
                table.insert(literalLines, content_line or "")
                lineNum = lineNum + 1
            end
        end

        -- Join lines and trim trailing newlines
        local text = table.concat(literalLines, "\n")
        text = text:gsub("\n+$", "")
        return text
    end

    -- Forward declaration
    local parseValue

    -- Parse a value (can be scalar, mapping, or array)
    parseValue = function(valueStr, keyIndent)
        -- Check for literal block
        if isLiteralBlock(valueStr) then
            return parseLiteralBlock(keyIndent)
        end

        -- Check for inline value
        if valueStr and valueStr ~= "" then
            return parseScalar(valueStr)
        end

        -- Look ahead to determine if array or mapping
        if lineNum > #lines then
            return nil
        end

        -- Skip empty lines and comments
        while lineNum <= #lines do
            local line = lines[lineNum]
            if line:match("^%s*$") or line:match("^%s*#") then
                lineNum = lineNum + 1
            else
                break
            end
        end

        if lineNum > #lines then
            return nil
        end

        local nextLine = lines[lineNum]
        local nextIndent = countIndent(nextLine)

        if nextIndent <= keyIndent then
            return nil
        end

        -- Check if this is an array
        if nextLine:match("^" .. string.rep(" ", nextIndent) .. "%- ") then
            -- Parse array
            local arr = {}
            local arrayIndent = nextIndent

            while lineNum <= #lines do
                local line = lines[lineNum]

                -- Skip empty and comment lines
                if line:match("^%s*$") or line:match("^%s*#") then
                    lineNum = lineNum + 1
                else
                    local indent = countIndent(line)

                    if indent < arrayIndent then
                        break
                    end

                    -- Check for array item
                    local itemMatch = line:match("^" .. string.rep(" ", arrayIndent) .. "%- (.*)$")
                    if itemMatch then
                        lineNum = lineNum + 1

                        -- Check if item has inline content
                        local itemKey, itemValue = itemMatch:match("^([%w_%.%-]+)%s*:%s*(.*)$")

                        if itemKey then
                            -- This is a mapping item
                            local item = {}
                            local itemIndent = arrayIndent + 2  -- After "- "

                            if itemValue and itemValue ~= "" then
                                if isLiteralBlock(itemValue) then
                                    item[itemKey] = parseLiteralBlock(arrayIndent)
                                else
                                    item[itemKey] = parseScalar(itemValue)
                                end
                            else
                                item[itemKey] = parseValue("", itemIndent + #itemKey + 2)
                            end

                            -- Continue parsing this item's properties
                            while lineNum <= #lines do
                                local propLine = lines[lineNum]

                                if propLine:match("^%s*$") or propLine:match("^%s*#") then
                                    lineNum = lineNum + 1
                                else
                                    local propIndent = countIndent(propLine)

                                    -- Check if we're still in this item
                                    if propIndent <= arrayIndent then
                                        break
                                    end

                                    -- Check for new array item at same level
                                    if propLine:match("^" .. string.rep(" ", arrayIndent) .. "%- ") then
                                        break
                                    end

                                    local propKey, propValue = propLine:match("^%s*([%w_%.%-]+)%s*:%s*(.*)$")
                                    if propKey then
                                        lineNum = lineNum + 1
                                        if isLiteralBlock(propValue) then
                                            item[propKey] = parseLiteralBlock(propIndent)
                                        elseif propValue and propValue ~= "" then
                                            item[propKey] = parseScalar(propValue)
                                        else
                                            item[propKey] = parseValue("", propIndent)
                                        end
                                    else
                                        lineNum = lineNum + 1
                                    end
                                end
                            end

                            table.insert(arr, item)
                        else
                            -- Simple value
                            table.insert(arr, parseScalar(itemMatch))
                        end
                    else
                        break
                    end
                end
            end

            return arr
        else
            -- Parse mapping
            local mapping = {}
            local mappingIndent = nextIndent

            while lineNum <= #lines do
                local line = lines[lineNum]

                if line:match("^%s*$") or line:match("^%s*#") then
                    lineNum = lineNum + 1
                else
                    local indent = countIndent(line)

                    if indent < mappingIndent then
                        break
                    end

                    if indent == mappingIndent then
                        local key, value = line:match("^%s*([%w_%.%-]+)%s*:%s*(.*)$")
                        if key then
                            lineNum = lineNum + 1
                            mapping[key] = parseValue(value, indent)
                        else
                            lineNum = lineNum + 1
                        end
                    else
                        lineNum = lineNum + 1
                    end
                end
            end

            return mapping
        end
    end

    -- Start parsing
    local result = {}

    while lineNum <= #lines do
        local line = lines[lineNum]

        if line:match("^%s*$") or line:match("^%s*#") or line:match("^%-%-%-") then
            lineNum = lineNum + 1
        else
            local indent = countIndent(line)
            local key, value = line:match("^%s*([%w_%.%-]+)%s*:%s*(.*)$")

            if key then
                lineNum = lineNum + 1
                result[key] = parseValue(value, indent)
            else
                lineNum = lineNum + 1
            end
        end
    end

    return result
end

--- Load YAML from file
function M.load(filepath)
    local file, err = io.open(filepath, "r")
    if not file then
        error("Cannot open file: " .. filepath .. " (" .. (err or "unknown error") .. ")")
    end

    local content = file:read("*a")
    file:close()

    return M.parse(content)
end

return M
