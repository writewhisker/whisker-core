-- whisker/formats/ink/transformers/stitch.lua
-- Stitch to Passage transformer
-- Converts Ink stitches to whisker-core Passage objects

local StitchTransformer = {}
StitchTransformer.__index = StitchTransformer

-- Module metadata
StitchTransformer._whisker = {
  name = "StitchTransformer",
  version = "1.0.0",
  description = "Transforms Ink stitches to whisker-core Passages",
  depends = {},
  capability = "formats.ink.transformers.stitch"
}

-- Create a new StitchTransformer instance
function StitchTransformer.new()
  local instance = {}
  setmetatable(instance, StitchTransformer)
  return instance
end

-- Transform a stitch to a Passage
-- @param ink_story InkStory - The source Ink story
-- @param knot_path string - The parent knot path
-- @param stitch_name string - The stitch name
-- @param stitch_data table - The stitch container data
-- @param options table|nil - Conversion options
-- @return Passage - The converted passage
function StitchTransformer:transform(ink_story, knot_path, stitch_name, stitch_data, options)
  options = options or {}

  local Passage = require("whisker.core.passage")

  -- Generate passage ID with dot notation
  local passage_id = knot_path .. "." .. stitch_name

  -- Create the passage
  local passage = Passage.new({
    id = passage_id,
    name = stitch_name,
    title = self:_path_to_title(stitch_name),
    content = "",
    tags = {},
    metadata = {}
  })

  -- Extract content from stitch
  if stitch_data then
    local content, tags = self:_extract_content(stitch_data)
    passage:set_content(content)

    for _, tag in ipairs(tags) do
      passage:add_tag(tag)
    end
  end

  -- Store parent reference and original path in metadata
  passage:set_metadata("parent_knot", knot_path)
  if options.preserve_ink_paths then
    passage:set_metadata("ink_path", passage_id)
  end

  return passage
end

-- Convert path to human-readable title
-- @param path string - The stitch name
-- @return string - Human-readable title
function StitchTransformer:_path_to_title(path)
  local title = path
  title = title:gsub("_", " ")
  title = title:gsub("(%l)(%u)", "%1 %2")
  title = title:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end)
  return title
end

-- Extract content from stitch data
-- @param stitch_data table - The stitch container
-- @return string, table - Content text and tags
function StitchTransformer:_extract_content(stitch_data)
  local content_parts = {}
  local tags = {}

  if type(stitch_data) ~= "table" then
    return "", {}
  end

  self:_process_container(stitch_data, content_parts, tags)

  return table.concat(content_parts), tags
end

-- Process a container recursively
-- @param container table - The container
-- @param content_parts table - Accumulator for content
-- @param tags table - Accumulator for tags
function StitchTransformer:_process_container(container, content_parts, tags)
  if type(container) ~= "table" then
    return
  end

  for i, item in ipairs(container) do
    if type(item) == "string" then
      if item:sub(1, 1) == "^" then
        table.insert(content_parts, item:sub(2))
      elseif item == "\n" then
        table.insert(content_parts, "\n")
      end
    elseif type(item) == "table" then
      if item["#"] then
        table.insert(tags, item["#"])
      elseif item[1] ~= nil then
        self:_process_container(item, content_parts, tags)
      end
    end
  end
end

-- Find stitches within a knot container
-- @param knot_data table - The knot container
-- @return table - Map of stitch_name -> stitch_data
function StitchTransformer:find_stitches(knot_data)
  local stitches = {}

  if type(knot_data) ~= "table" then
    return stitches
  end

  -- Look for the trailing named content dictionary
  local last = knot_data[#knot_data]
  if type(last) == "table" and not last[1] then
    -- This is a named content dictionary
    for name, data in pairs(last) do
      -- Skip special keys and check for valid stitch data
      if type(data) == "table" and data[1] ~= nil then
        stitches[name] = data
      end
    end
  end

  return stitches
end

return StitchTransformer
