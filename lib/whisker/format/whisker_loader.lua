-- src/format/whisker_loader.lua
-- Loads native Whisker JSON format files and converts them to Story objects
-- Supports v1.0 (simple variables) and v2.0 (typed variables, choice IDs)
-- Auto-migrates v1.0 to v2.0

local whisker_loader = {}

--------------------------------------------------------------------------------
-- Dependencies (lazily loaded)
--------------------------------------------------------------------------------

local _story_class = nil
local _passage_class = nil
local _choice_class = nil
local _json_codec = nil
local _compact_converter = nil

local function get_story_class()
  if not _story_class then
    local ok, mod = pcall(require, "whisker.core.story")
    if ok then _story_class = mod end
  end
  return _story_class
end

local function get_passage_class()
  if not _passage_class then
    local ok, mod = pcall(require, "whisker.core.passage")
    if ok then _passage_class = mod end
  end
  return _passage_class
end

local function get_choice_class()
  if not _choice_class then
    local ok, mod = pcall(require, "whisker.core.choice")
    if ok then _choice_class = mod end
  end
  return _choice_class
end

local function get_json_codec()
  if not _json_codec then
    local ok, mod = pcall(require, "whisker.utils.json")
    if ok then _json_codec = mod end
  end
  return _json_codec
end

local function get_compact_converter()
  if not _compact_converter then
    local ok, mod = pcall(require, "whisker.format.compact_converter")
    if ok then _compact_converter = mod end
  end
  return _compact_converter
end

--- Set dependencies via DI (optional)
-- @param deps table {story_class, passage_class, choice_class, json_codec, compact_converter}
function whisker_loader.set_dependencies(deps)
  if deps.story_class then _story_class = deps.story_class end
  if deps.passage_class then _passage_class = deps.passage_class end
  if deps.choice_class then _choice_class = deps.choice_class end
  if deps.json_codec then _json_codec = deps.json_codec end
  if deps.compact_converter then _compact_converter = deps.compact_converter end
end

--------------------------------------------------------------------------------

-- Helper: Generate choice ID
local function generate_choice_id()
    local template = "ch_xxxxxxxxxxxx"
    return string.gsub(template, "x", function()
        return string.format("%x", math.random(0, 0xf))
    end)
end

-- Helper: Check if variables are in v2.0 typed format
local function is_typed_variable(var_data)
    return type(var_data) == "table" and var_data.type ~= nil and var_data.default ~= nil
end

-- Migrate v1.0 to v2.0 format
function whisker_loader.migrate_v1_to_v2(data)
    local migrated = {}
    for k, v in pairs(data) do
        migrated[k] = v
    end

    -- Set format version to 2.0
    migrated.formatVersion = "2.0"

    -- Migrate variables from simple to typed format
    if migrated.variables then
        local typed_vars = {}
        for name, value in pairs(migrated.variables) do
            if is_typed_variable(value) then
                -- Already typed
                typed_vars[name] = value
            else
                -- Convert to typed format
                typed_vars[name] = {
                    type = type(value),
                    default = value
                }
            end
        end
        migrated.variables = typed_vars
    end

    -- Add IDs to choices in passages
    if migrated.passages then
        for i, passage in ipairs(migrated.passages) do
            if passage.choices then
                for j, choice in ipairs(passage.choices) do
                    if not choice.id then
                        choice.id = generate_choice_id()
                    end
                end
            end
        end
    end

    return migrated
end

-- Load a .whisker file and convert to Story object
function whisker_loader.load_from_file(filename)
    local file = io.open(filename, "r")
    if not file then
        return nil, "Failed to open file: " .. filename
    end

    local json_text = file:read("*all")
    file:close()

    return whisker_loader.load_from_string(json_text)
end

-- Parse Whisker JSON string and convert to Story object
function whisker_loader.load_from_string(json_text)
    local json = get_json_codec()
    local Story = get_story_class()

    if not json or not Story then
        return nil, "Required dependencies not available"
    end

    -- Parse JSON
    local data, err = json.decode(json_text)
    if not data then
        return nil, "Failed to parse JSON: " .. (err or "unknown error")
    end

    -- Validate format - check both top-level and metadata.format
    local format = data.format or (data.metadata and data.metadata.format)
    if format ~= "whisker" then
        return nil, "Invalid format: expected 'whisker', got '" .. tostring(format) .. "'"
    end

    -- Auto-migrate v1.0 to v2.0 if needed
    local format_version = data.formatVersion or "1.0"
    if format_version == "1.0" then
        data = whisker_loader.migrate_v1_to_v2(data)
    end

    -- Create Story object
    local story_config = {
        title = data.metadata and (data.metadata.title or data.metadata.name) or "Untitled Story",
        author = data.metadata and data.metadata.author or "Unknown",
        ifid = data.metadata and data.metadata.ifid or "",
        version = data.formatVersion or (data.metadata and data.metadata.version) or "1.0",
        description = data.metadata and data.metadata.description or ""
    }

    local story = Story.new(story_config)

    -- Initialize variables
    if data.variables then
        story.variables = {}
        for k, v in pairs(data.variables) do
            story.variables[k] = v
        end
    end

    -- Convert passages (must be done before setting start passage)
    if data.passages then
        -- Handle both array and object formats
        if type(data.passages) == "table" then
            -- Check if it's an array or object
            local is_array = #data.passages > 0

            if is_array then
                -- Array format
                for i, passage_data in ipairs(data.passages) do
                    local passage = whisker_loader.convert_passage(passage_data)
                    if passage then
                        story:add_passage(passage)
                    end
                end
            else
                -- Object format (passage_id -> passage_data)
                for passage_id, passage_data in pairs(data.passages) do
                    local passage = whisker_loader.convert_passage(passage_data)
                    if passage then
                        story:add_passage(passage)
                    end
                end
            end
        end
    end

    -- Set start passage (after passages are added)
    local start_passage = data.settings and data.settings.startPassage
    if start_passage and story.passages[start_passage] then
        story:set_start_passage(start_passage)
    elseif story.start_passage and story.passages[story.start_passage] then
        -- Use existing start passage if valid
        story:set_start_passage(story.start_passage)
    else
        -- Find first passage and use that
        for id, _ in pairs(story.passages) do
            story:set_start_passage(id)
            break
        end
    end

    return story, nil
end

-- Convert a Whisker passage to a Passage object
function whisker_loader.convert_passage(passage_data)
    local Passage = get_passage_class()
    local Choice = get_choice_class()

    if not Passage or not Choice then
        return nil
    end

    -- Support both formats: {id, text} and {name, content}
    -- Prefer id over name (id is the linking key, name is display name)
    local passage_id = passage_data.id or passage_data.name
    local passage_content = passage_data.text or passage_data.content

    if not passage_id then
        return nil
    end

    -- Create options table (separate from constructor call to avoid Lua quirks)
    local options_table = {
        id = passage_id,
        content = passage_content or "",
        position = passage_data.position,
        size = passage_data.size
    }

    local passage = Passage.new(options_table)

    -- Add tags
    if passage_data.tags then
        for _, tag in ipairs(passage_data.tags) do
            passage:add_tag(tag)
        end
    end

    -- Add choices - either from choices array or extract from text
    if passage_data.choices and #passage_data.choices > 0 then
        -- Use explicit choices array
        for _, choice_data in ipairs(passage_data.choices) do
            local choice_options = {
                id = choice_data.id,  -- NEW: Pass through choice ID
                text = choice_data.text,
                target = choice_data.target_passage or choice_data.target,
                condition = choice_data.condition,
                action = choice_data.action  -- NEW: Include action
            }
            local choice = Choice.new(choice_options)
            passage:add_choice(choice)
        end
    else
        -- Extract choices from the text using Whisker link syntax
        local choices = whisker_loader.extract_choices(passage_data.text or passage_data.content or "")
        for _, choice in ipairs(choices) do
            passage:add_choice(choice)
        end
    end

    return passage
end

-- Extract choices from passage text
-- Supports formats:
--   [[text->target]]
--   [[target]]
--   {{#if condition}}[[text->target]]{{/if}}
function whisker_loader.extract_choices(text)
    local Choice = get_choice_class()
    if not Choice then
        return {}
    end

    local choices = {}
    local seen_choices = {}  -- Track to avoid duplicates

    -- Match [[text->target]] or [[target]]
    for match in text:gmatch("%[%[([^%]]+)%]%]") do
        local display_text, target

        -- Check for [[text->target]] format
        if match:match("(.-)%->(.+)") then
            display_text, target = match:match("(.-)%->(.+)")
            display_text = display_text:match("^%s*(.-)%s*$")  -- trim
            target = target:match("^%s*(.-)%s*$")  -- trim
        else
            -- [[target]] format
            target = match:match("^%s*(.-)%s*$")  -- trim
            display_text = target
        end

        -- Create unique key to avoid duplicates
        local choice_key = display_text .. "|" .. target
        if not seen_choices[choice_key] then
            -- Create options table separately (avoid Lua quirks with inline tables)
            local choice_options = {
                text = display_text,
                target = target
            }
            local choice = Choice.new(choice_options)
            table.insert(choices, choice)
            seen_choices[choice_key] = true
        end
    end

    return choices
end

-- Validate a Whisker document
function whisker_loader.validate(data)
    local errors = {}

    -- Check format
    if not data.format or data.format ~= "whisker" then
        table.insert(errors, "Invalid or missing format field")
    end

    -- Check metadata
    if not data.metadata then
        table.insert(errors, "Missing metadata")
    elseif not data.metadata.title then
        table.insert(errors, "Missing title in metadata")
    end

    -- Check passages
    if not data.passages then
        table.insert(errors, "Missing passages")
    elseif type(data.passages) ~= "table" then
        table.insert(errors, "Passages must be an array")
    else
        -- Validate each passage
        local passage_ids = {}
        local passage_names = {}
        for i, passage in ipairs(data.passages) do
            -- Check for id (preferred) or name
            local passage_id = passage.id or passage.name
            if not passage_id then
                table.insert(errors, "Passage " .. i .. " missing id/name")
            elseif passage_ids[passage_id] then
                table.insert(errors, "Duplicate passage id: " .. passage_id)
            else
                passage_ids[passage_id] = true
            end

            -- Also track names for legacy support
            if passage.name then
                passage_names[passage.name] = true
            end

            -- Check for text or content
            if not passage.text and not passage.content then
                table.insert(errors, "Passage '" .. (passage_id or i) .. "' missing text/content")
            end
        end

        -- Check start passage exists (check both ids and names)
        if data.settings and data.settings.startPassage then
            if not passage_ids[data.settings.startPassage] and not passage_names[data.settings.startPassage] then
                table.insert(errors, "Start passage not found: " .. data.settings.startPassage)
            end
        end
    end

    return #errors == 0, errors
end

return whisker_loader
