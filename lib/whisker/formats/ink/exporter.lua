-- whisker/formats/ink/exporter.lua
-- Exports whisker stories to Ink JSON format

local Exporter = {}
Exporter.__index = Exporter

-- Module metadata
Exporter._whisker = {
  name = "InkExporter",
  version = "1.0.0",
  description = "Exports whisker stories to Ink JSON format",
  depends = {},
  capability = "formats.ink.exporter"
}

-- Default Ink version to target
Exporter.DEFAULT_INK_VERSION = 20

-- Create a new Exporter instance
function Exporter.new(options)
  local instance = {
    options = options or {},
    generators = nil,
    ink_version = (options and options.ink_version) or Exporter.DEFAULT_INK_VERSION
  }
  setmetatable(instance, Exporter)
  instance:_load_generators()
  return instance
end

-- Load generator modules
function Exporter:_load_generators()
  self.generators = require("whisker.formats.ink.generators")
end

-- Export a whisker story to Ink JSON format
-- @param story table - The whisker story
-- @param options table|nil - Export options
-- @return table - Ink JSON structure
function Exporter:export(story, options)
  options = options or {}

  if not story then
    return nil, "Story is nil"
  end

  local ink_json = {
    inkVersion = self.ink_version,
    root = self:_build_root(story, options)
  }

  -- Add list definitions if present
  local list_defs = self:_build_list_defs(story)
  if list_defs then
    ink_json.listDefs = list_defs
  end

  return ink_json
end

-- Build the root container
-- @param story table - The whisker story
-- @param options table - Export options
-- @return table - Root container
function Exporter:_build_root(story, options)
  local root = {}
  local named = {}

  -- Get passage generator
  local passage_gen = self.generators.create("passage")

  -- Process passages
  local passages = story.passages or {}
  for id, passage in pairs(passages) do
    if passage_gen:is_knot(passage) then
      -- Top-level knot
      local knot_name = passage_gen:get_knot_name(passage)
      local container = passage_gen:generate_knot(passage, options)

      -- Add stitches that belong to this knot
      local stitches = self:_collect_stitches(passages, knot_name)
      if next(stitches) then
        -- Add trailing null for named dictionary
        container[#container + 1] = nil
        for stitch_name, stitch_passage in pairs(stitches) do
          container[stitch_name] = passage_gen:generate_stitch(stitch_passage, knot_name, options)
        end
      end

      named[knot_name] = container
    end
  end

  -- Build root array with start content
  local start = story.start or story.metadata and story.metadata.start

  if start and named[start] then
    -- Add initial divert to start
    table.insert(root, { ["->"] = start })
  end

  -- Add done marker
  table.insert(root, "done")

  -- Add trailing null for named dictionary
  root[#root + 1] = nil

  -- Attach named containers
  for name, container in pairs(named) do
    root[name] = container
  end

  return root
end

-- Collect stitches belonging to a knot
-- @param passages table - All passages
-- @param knot_name string - Parent knot name
-- @return table - Map of stitch_name -> passage
function Exporter:_collect_stitches(passages, knot_name)
  local stitches = {}
  local passage_gen = self.generators.create("passage")

  for id, passage in pairs(passages) do
    if not passage_gen:is_knot(passage) then
      local parent = passage_gen:get_knot_name(passage)
      if parent == knot_name then
        local stitch_name = passage_gen:get_stitch_name(passage)
        if stitch_name then
          stitches[stitch_name] = passage
        end
      end
    end
  end

  return stitches
end

-- Build list definitions from variables
-- @param story table - The whisker story
-- @return table|nil - List definitions or nil
function Exporter:_build_list_defs(story)
  local variables = story.variables or {}
  local list_defs = {}
  local has_lists = false

  for name, variable in pairs(variables) do
    if variable.type == "list" and variable.items then
      list_defs[name] = {}
      for i, item in ipairs(variable.items) do
        list_defs[name][item] = i
      end
      has_lists = true
    end
  end

  return has_lists and list_defs or nil
end

-- Export to JSON string
-- @param story table - The whisker story
-- @param options table|nil - Export options
-- @return string|nil, string|nil - JSON string or nil, error message
function Exporter:export_string(story, options)
  local ink_json, err = self:export(story, options)
  if not ink_json then
    return nil, err
  end

  -- Use cjson if available, otherwise simple serialization
  local ok, cjson = pcall(require, "cjson")
  if ok then
    return cjson.encode(ink_json)
  end

  -- Fallback to dkjson
  ok, cjson = pcall(require, "dkjson")
  if ok then
    return cjson.encode(ink_json)
  end

  return nil, "No JSON encoder available"
end

-- Get Ink version
-- @return number
function Exporter:get_ink_version()
  return self.ink_version
end

-- Set Ink version
-- @param version number
function Exporter:set_ink_version(version)
  self.ink_version = version
end

-- Validate story can be exported
-- @param story table - The whisker story
-- @return boolean, table|nil - Valid status, errors if invalid
function Exporter:validate(story)
  local errors = {}

  if not story then
    table.insert(errors, "Story is nil")
    return false, errors
  end

  if not story.passages or not next(story.passages) then
    table.insert(errors, "Story has no passages")
    return false, errors
  end

  return #errors == 0, #errors > 0 and errors or nil
end

return Exporter
