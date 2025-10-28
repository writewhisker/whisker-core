-- whisker Format Specification
-- Defines the JSON schema for whisker story files
-- Version 2.0
--
-- v2.0 Changes (backward compatible):
-- - Typed Variables: Variables can now have explicit types
--   v1.0: variables = { health = 100 }
--   v2.0: variables = { health = { type = "number", default = 100 } }
-- - Choice IDs: Choices now have unique identifiers
--   v2.0: choices = { { id = "ch_xxx", text = "Go", target = "room" } }
-- - Auto-migration: v1.0 files automatically upgrade to v2.0 on load

-- Lua 5.1/5.2+ compatibility for load()
local function load_compat(code, chunkname, mode, env)
    local func, err
    if _VERSION == "Lua 5.1" then
        -- Lua 5.1 uses loadstring for strings
        func, err = loadstring(code, chunkname)
        if func and env then
            setfenv(func, env)
        end
    else
        -- Lua 5.2+ can use load directly
        func, err = load(code, chunkname, mode, env)
    end
    return func, err
end

local whiskerFormat = {}

-- Format version
whiskerFormat.VERSION = "2.0"  -- Updated from 1.0 to 2.0
whiskerFormat.FORMAT_NAME = "whisker"

-- Legacy version for compatibility
whiskerFormat.LEGACY_VERSION = "1.0"

-- Create a new whisker format document
function whiskerFormat.create_document(title, author)
    return {
        format = whiskerFormat.FORMAT_NAME,
        formatVersion = whiskerFormat.VERSION,
        metadata = {
            title = title or "Untitled Story",
            author = author or "Unknown",
            created = os.date("%Y-%m-%dT%H:%M:%S"),
            modified = os.date("%Y-%m-%dT%H:%M:%S"),
            ifid = whiskerFormat.generate_ifid(),
            description = "",
            tags = {}
        },
        settings = {
            startPassage = "Start",
            theme = "default",
            scriptingLanguage = "lua",
            undoLimit = 50,
            autoSave = true
        },
        passages = {},
        variables = {},
        scripts = {},
        stylesheets = {},
        assets = {}
    }
end

-- Generate IFID (Interactive Fiction ID)
function whiskerFormat.generate_ifid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format("%X", v)
    end)
end

-- Create a passage structure
function whiskerFormat.create_passage(pid, name, text)
    return {
        pid = pid or whiskerFormat.generate_pid(),
        name = name or "Untitled Passage",
        text = text or "",
        tags = {},
        position = {x = 0, y = 0},
        size = {width = 100, height = 100},
        metadata = {
            created = os.date("%Y-%m-%dT%H:%M:%S"),
            modified = os.date("%Y-%m-%dT%H:%M:%S")
        }
    }
end

-- Generate Passage ID
function whiskerFormat.generate_pid()
    return string.format("p%d", math.random(100000, 999999))
end

-- Create a choice/link structure
function whiskerFormat.create_choice(text, target, condition)
    return {
        text = text,
        target = target,
        condition = condition,
        once = false,
        tags = {}
    }
end

-- Validate whisker document
function whiskerFormat.validate(document)
    local errors = {}

    -- Check format
    if document.format ~= whiskerFormat.FORMAT_NAME then
        table.insert(errors, "Invalid format: " .. tostring(document.format))
    end

    -- Check required fields
    if not document.metadata then
        table.insert(errors, "Missing metadata")
    else
        if not document.metadata.title then
            table.insert(errors, "Missing title in metadata")
        end
    end

    if not document.passages then
        table.insert(errors, "Missing passages")
    else
        -- Validate passages
        local passage_names = {}
        for _, passage in ipairs(document.passages) do
            -- Check for duplicate names
            if passage_names[passage.name] then
                table.insert(errors, "Duplicate passage name: " .. passage.name)
            end
            passage_names[passage.name] = true

            -- Validate passage structure
            if not passage.pid then
                table.insert(errors, "Passage missing pid: " .. passage.name)
            end
            if not passage.text then
                table.insert(errors, "Passage missing text: " .. passage.name)
            end
        end

        -- Check start passage exists
        if document.settings and document.settings.startPassage then
            if not passage_names[document.settings.startPassage] then
                table.insert(errors, "Start passage not found: " .. document.settings.startPassage)
            end
        end
    end

    return #errors == 0, errors
end

-- Export document to JSON string
function whiskerFormat.to_json(document)
    -- Simple JSON serialization
    -- In production, use a proper JSON library
    local function serialize_value(val, indent)
        local t = type(val)
        indent = indent or 0
        local spaces = string.rep("  ", indent)

        if t == "nil" then
            return "null"
        elseif t == "boolean" then
            return tostring(val)
        elseif t == "number" then
            return tostring(val)
        elseif t == "string" then
            -- Escape special characters
            local escaped = val:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
            return '"' .. escaped .. '"'
        elseif t == "table" then
            -- Check if array or object
            local is_array = true
            local max_index = 0
            for k, v in pairs(val) do
                if type(k) ~= "number" then
                    is_array = false
                    break
                end
                max_index = math.max(max_index, k)
            end

            if is_array and max_index == #val then
                -- Array
                local items = {}
                for i, v in ipairs(val) do
                    table.insert(items, serialize_value(v, indent + 1))
                end
                if #items == 0 then
                    return "[]"
                end
                return "[\n" .. spaces .. "  " .. table.concat(items, ",\n" .. spaces .. "  ") .. "\n" .. spaces .. "]"
            else
                -- Object
                local items = {}
                for k, v in pairs(val) do
                    local key = serialize_value(tostring(k), 0)
                    local value = serialize_value(v, indent + 1)
                    table.insert(items, key .. ": " .. value)
                end
                if #items == 0 then
                    return "{}"
                end
                table.sort(items)
                return "{\n" .. spaces .. "  " .. table.concat(items, ",\n" .. spaces .. "  ") .. "\n" .. spaces .. "}"
            end
        else
            return '"' .. tostring(val) .. '"'
        end
    end

    return serialize_value(document, 0)
end

-- Parse JSON string to document
function whiskerFormat.from_json(json_string)
    -- This is a simplified parser
    -- In production, use a proper JSON library like dkjson or cjson

    -- Attempt to use load (with appropriate safety measures)
    local function json_decode(str)
        -- Convert JSON to Lua table syntax
        str = str:gsub("null", "nil")
        str = str:gsub(": *true", ": true")
        str = str:gsub(": *false", ": false")

        -- This is NOT safe for production - just for demonstration
        -- Use a proper JSON library in real code
        local func, err = load_compat("return " .. str, "json_decode", "t", nil)
        if not func then
            return nil, "JSON parse error: " .. err
        end

        local success, result = pcall(func)
        if not success then
            return nil, "JSON execution error: " .. result
        end

        return result
    end

    local document, err = json_decode(json_string)
    if not document then
        return nil, err
    end

    -- Validate the parsed document
    local valid, errors = whiskerFormat.validate(document)
    if not valid then
        return nil, "Validation failed: " .. table.concat(errors, "; ")
    end

    return document, nil
end

-- Convert passage text to extract links
function whiskerFormat.extract_links(text)
    local links = {}

    -- Match [[link]] or [[text|target]]
    for match in text:gmatch("%[%[([^%]]+)%]%]") do
        local display, target = match:match("([^|]+)|([^|]+)")
        if not target then
            target = match
            display = match
        end

        table.insert(links, {
            display = display:match("^%s*(.-)%s*$"), -- trim whitespace
            target = target:match("^%s*(.-)%s*$")
        })
    end

    -- Match ->target format
    for target in text:gmatch("->%s*([%w_]+)") do
        table.insert(links, {
            display = target,
            target = target
        })
    end

    return links
end

-- Find all broken links in document
function whiskerFormat.find_broken_links(document)
    local broken_links = {}
    local passage_names = {}

    -- Build passage name set
    for _, passage in ipairs(document.passages or {}) do
        passage_names[passage.name] = true
    end

    -- Check each passage for links
    for _, passage in ipairs(document.passages or {}) do
        local links = whiskerFormat.extract_links(passage.text)

        for _, link in ipairs(links) do
            if not passage_names[link.target] then
                table.insert(broken_links, {
                    source = passage.name,
                    target = link.target,
                    display = link.display
                })
            end
        end
    end

    return broken_links
end

-- Get document statistics
function whiskerFormat.get_statistics(document)
    local stats = {
        passages = #(document.passages or {}),
        words = 0,
        characters = 0,
        links = 0,
        broken_links = 0,
        orphaned_passages = 0
    }

    -- Count words and characters
    for _, passage in ipairs(document.passages or {}) do
        local text = passage.text or ""
        stats.words = stats.words + select(2, text:gsub("%S+", ""))
        stats.characters = stats.characters + #text
    end

    -- Count links and broken links
    local broken = whiskerFormat.find_broken_links(document)
    stats.broken_links = #broken

    -- Count total links
    for _, passage in ipairs(document.passages or {}) do
        local links = whiskerFormat.extract_links(passage.text)
        stats.links = stats.links + #links
    end

    return stats
end

-- Schema definition (for reference)
whiskerFormat.SCHEMA = {
    type = "object",
    required = {"format", "formatVersion", "metadata", "passages"},
    properties = {
        format = {type = "string", const = "whisker"},
        formatVersion = {type = "string"},
        metadata = {
            type = "object",
            required = {"title", "ifid"},
            properties = {
                title = {type = "string"},
                author = {type = "string"},
                created = {type = "string", format = "date-time"},
                modified = {type = "string", format = "date-time"},
                ifid = {type = "string", pattern = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"},
                description = {type = "string"},
                tags = {type = "array", items = {type = "string"}}
            }
        },
        settings = {
            type = "object",
            properties = {
                startPassage = {type = "string"},
                theme = {type = "string"},
                scriptingLanguage = {type = "string"},
                undoLimit = {type = "number"},
                autoSave = {type = "boolean"}
            }
        },
        passages = {
            type = "array",
            items = {
                type = "object",
                required = {"pid", "name", "text"},
                properties = {
                    pid = {type = "string"},
                    name = {type = "string"},
                    text = {type = "string"},
                    tags = {type = "array", items = {type = "string"}},
                    position = {
                        type = "object",
                        properties = {
                            x = {type = "number"},
                            y = {type = "number"}
                        }
                    },
                    size = {
                        type = "object",
                        properties = {
                            width = {type = "number"},
                            height = {type = "number"}
                        }
                    }
                }
            }
        },
        variables = {
            type = "object",
            -- v2.0: Supports both simple (v1.0) and typed (v2.0) format
            patternProperties = {
                [".*"] = {
                    oneOf = {
                        -- Simple format (v1.0 - backward compatible)
                        {type = {"string", "number", "boolean"}},
                        -- Typed format (v2.0 - preferred)
                        {
                            type = "object",
                            required = {"type", "default"},
                            properties = {
                                type = {type = "string", enum = {"string", "number", "boolean", "table", "array"}},
                                default = {type = {"string", "number", "boolean", "object", "array"}}
                            }
                        }
                    }
                }
            }
        },
        scripts = {type = "array"},
        stylesheets = {type = "array"},
        assets = {type = "array"}
    }
}

return whiskerFormat