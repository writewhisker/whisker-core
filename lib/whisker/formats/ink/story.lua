-- whisker/formats/ink/story.lua
-- InkStory wrapper around tinta Story for metadata extraction and introspection

local InkStory = {}
InkStory.__index = InkStory

-- Module metadata for container auto-registration
InkStory._whisker = {
  name = "InkStory",
  version = "1.0.0",
  description = "Ink story wrapper for metadata extraction and introspection",
  depends = {},
  capability = "formats.ink.story"
}

-- Create a new InkStory wrapper
-- @param story_data table - Parsed Ink JSON data (table with inkVersion, root, listDefs)
-- @return InkStory
function InkStory.new(story_data)
  if not story_data then
    error("InkStory requires story_data")
  end

  local instance = {
    _data = story_data,
    _tinta_story = nil,  -- Lazy-loaded tinta Story instance
    _metadata_cache = nil,
    _knots_cache = nil,
    _variables_cache = nil,
    _externals_cache = nil
  }
  setmetatable(instance, InkStory)
  return instance
end

-- Get the raw story data
-- @return table
function InkStory:get_data()
  return self._data
end

-- Get the Ink version
-- @return number
function InkStory:get_ink_version()
  return self._data.inkVersion
end

-- Get list definitions
-- @return table
function InkStory:get_list_defs()
  return self._data.listDefs or {}
end

-- Get the underlying tinta Story instance (creates if needed)
-- @return Story - tinta Story instance
function InkStory:get_tinta_story()
  if not self._tinta_story then
    local tinta = require("whisker.vendor.tinta")
    self._tinta_story = tinta.create_story(self._data)
  end
  return self._tinta_story
end

-- Check if tinta story has been instantiated
-- @return boolean
function InkStory:has_tinta_story()
  return self._tinta_story ~= nil
end

-- Extract metadata from global tags
-- Tags like "# title: My Story" become {title = "My Story"}
-- In compiled Ink JSON, tags appear as {"#": "tag content"}
-- @return table
function InkStory:get_metadata()
  if self._metadata_cache then
    return self._metadata_cache
  end

  local metadata = {
    title = nil,
    author = nil,
    tags = {}
  }

  -- Helper to process a tag string
  local function process_tag(tag_str)
    local tag = tag_str:match("^%s*(.-)%s*$")  -- Trim whitespace
    if tag and tag ~= "" then
      -- Check for key:value format
      local key, value = tag:match("^(%w+):%s*(.+)$")
      if key and value then
        metadata[key:lower()] = value
      else
        table.insert(metadata.tags, tag)
      end
    end
  end

  -- Global tags are in the first element of root if it's an array
  local root = self._data.root
  if type(root) == "table" and #root > 0 then
    -- First element might be an array with tags
    local first = root[1]
    if type(first) == "table" then
      for _, item in ipairs(first) do
        -- String format: "# tag content"
        if type(item) == "string" and item:sub(1, 1) == "#" then
          process_tag(item:sub(2))
        -- Object format: {"#": "tag content"}
        elseif type(item) == "table" and item["#"] then
          process_tag(item["#"])
        end
      end
    end
  end

  self._metadata_cache = metadata
  return metadata
end

-- Get story title from metadata
-- @return string|nil
function InkStory:get_title()
  local meta = self:get_metadata()
  return meta.title
end

-- Get story author from metadata
-- @return string|nil
function InkStory:get_author()
  local meta = self:get_metadata()
  return meta.author
end

-- Get global tags (non-metadata tags)
-- @return table
function InkStory:get_global_tags()
  local meta = self:get_metadata()
  return meta.tags
end

-- Enumerate all knots in the story
-- @return table - Array of knot names
function InkStory:get_knots()
  if self._knots_cache then
    return self._knots_cache
  end

  local knots = {}
  local root = self._data.root

  -- Look for named content in the last element of root (the named content dictionary)
  if type(root) == "table" and #root > 0 then
    local last = root[#root]
    if type(last) == "table" then
      for name, content in pairs(last) do
        -- Skip special names like "#n" (internal naming)
        -- Skip "global decl" (variable declarations)
        if type(name) == "string"
           and not name:match("^#")
           and name ~= "global decl"
           and type(content) == "table" then
          table.insert(knots, name)
        end
      end
    end
  end

  -- Sort for consistent ordering
  table.sort(knots)

  self._knots_cache = knots
  return knots
end

-- Get stitches within a knot
-- @param knot_name string - Name of the knot
-- @return table - Array of stitch names
function InkStory:get_stitches(knot_name)
  local stitches = {}
  local root = self._data.root

  if type(root) == "table" and #root > 0 then
    local last = root[#root]
    if type(last) == "table" and last[knot_name] then
      local knot_content = last[knot_name]
      -- Stitches are in the named content dictionary at the end of knot content
      if type(knot_content) == "table" and #knot_content > 0 then
        local knot_named = knot_content[#knot_content]
        if type(knot_named) == "table" then
          for name, content in pairs(knot_named) do
            if type(name) == "string"
               and not name:match("^#")
               and type(content) == "table" then
              table.insert(stitches, name)
            end
          end
        end
      end
    end
  end

  -- Sort for consistent ordering
  table.sort(stitches)
  return stitches
end

-- Get all knots with their stitches
-- @return table - Map of knot_name -> array of stitch names
function InkStory:get_structure()
  local structure = {}
  local knots = self:get_knots()

  for _, knot_name in ipairs(knots) do
    structure[knot_name] = self:get_stitches(knot_name)
  end

  return structure
end

-- List global variables with their default values
-- @return table - Map of variable_name -> {type, default_value}
function InkStory:get_global_variables()
  if self._variables_cache then
    return self._variables_cache
  end

  local variables = {}
  local root = self._data.root

  if type(root) == "table" and #root > 0 then
    local last = root[#root]
    if type(last) == "table" and last["global decl"] then
      local global_decl = last["global decl"]
      -- Parse the global declarations
      -- Format: "ev", {"VAR=": "name"}, value, "/ev", ...
      local i = 1
      while i <= #global_decl do
        local item = global_decl[i]
        if type(item) == "table" and item["VAR="] then
          local var_name = item["VAR="]
          -- Look for the value (could be next item or nested)
          local j = i + 1
          local value = nil
          local value_type = "unknown"

          while j <= #global_decl do
            local next_item = global_decl[j]
            if next_item == "/ev" then
              break
            elseif next_item == "str" then
              -- String value follows
              j = j + 1
              if global_decl[j] and type(global_decl[j]) == "string" then
                value = global_decl[j]:gsub("^%^", "")
                value_type = "string"
              end
            elseif type(next_item) == "number" then
              value = next_item
              value_type = math.floor(next_item) == next_item and "int" or "float"
            elseif type(next_item) == "boolean" then
              value = next_item
              value_type = "bool"
            elseif type(next_item) == "table" and next_item["^->"] then
              -- Divert target value (skip)
            end
            j = j + 1
          end

          if var_name then
            variables[var_name] = {
              type = value_type,
              default = value
            }
          end
        end
        i = i + 1
      end
    end
  end

  self._variables_cache = variables
  return variables
end

-- Check if the story has a specific variable
-- @param name string - Variable name
-- @return boolean
function InkStory:has_variable(name)
  local vars = self:get_global_variables()
  return vars[name] ~= nil
end

-- List external function declarations
-- @return table - Array of external function names
function InkStory:get_external_functions()
  if self._externals_cache then
    return self._externals_cache
  end

  -- External functions are tracked in the tinta story's _externals
  -- But we can also look for "x()" pattern in the compiled JSON
  -- For now, we'll use tinta's tracking after story instantiation
  local externals = {}

  -- Try to extract from story data if possible
  -- External function calls appear as {"x()": "funcName", "exArgs": n}
  local function scan_for_externals(obj, found)
    if type(obj) ~= "table" then return end

    if obj["x()"] then
      found[obj["x()"]] = true
    end

    for k, v in pairs(obj) do
      if type(v) == "table" then
        scan_for_externals(v, found)
      end
    end
  end

  local found = {}
  scan_for_externals(self._data, found)

  for name in pairs(found) do
    table.insert(externals, name)
  end

  -- Sort for consistent ordering
  table.sort(externals)

  self._externals_cache = externals
  return externals
end

-- Check if the story has external function declarations
-- @return boolean
function InkStory:has_externals()
  local externals = self:get_external_functions()
  return #externals > 0
end

-- Clear all caches (useful after modifying data)
function InkStory:clear_cache()
  self._metadata_cache = nil
  self._knots_cache = nil
  self._variables_cache = nil
  self._externals_cache = nil
  self._tinta_story = nil
end

-- Create InkStory from file path
-- @param path string - Path to ink.json file
-- @return InkStory|nil, string|nil - InkStory instance or nil with error
function InkStory.from_file(path)
  local JsonLoader = require("whisker.formats.ink.json_loader")
  local loader = JsonLoader.new()

  local data, err = loader:load_file(path)
  if not data then
    return nil, err
  end

  return InkStory.new(data)
end

-- Create InkStory from JSON string
-- @param json_str string - JSON string content
-- @return InkStory|nil, string|nil - InkStory instance or nil with error
function InkStory.from_string(json_str)
  local JsonLoader = require("whisker.formats.ink.json_loader")
  local loader = JsonLoader.new()

  local data, err = loader:load_string(json_str)
  if not data then
    return nil, err
  end

  return InkStory.new(data)
end

return InkStory
