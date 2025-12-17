-- whisker/formats/ink/transformers/gather.lua
-- Gather point transformer
-- Converts Ink gather points to whisker-core Passage objects

local GatherTransformer = {}
GatherTransformer.__index = GatherTransformer

-- Module metadata
GatherTransformer._whisker = {
  name = "GatherTransformer",
  version = "1.0.0",
  description = "Transforms Ink gather points to whisker-core Passages",
  depends = {},
  capability = "formats.ink.transformers.gather"
}

-- Counter for generating anonymous gather IDs
local anonymous_counter = 0

-- Create a new GatherTransformer instance
function GatherTransformer.new()
  local instance = {}
  setmetatable(instance, GatherTransformer)
  return instance
end

-- Transform a gather point to a Passage
-- @param ink_story InkStory - The source Ink story
-- @param parent_path string - The parent path (knot or knot.stitch)
-- @param gather_name string|nil - The gather label (nil for anonymous)
-- @param gather_data table - The gather content
-- @param options table|nil - Conversion options
-- @return Passage - The converted passage
function GatherTransformer:transform(ink_story, parent_path, gather_name, gather_data, options)
  options = options or {}

  local Passage = require("whisker.core.passage")

  -- Generate ID for gather point
  local passage_id
  if gather_name then
    passage_id = parent_path .. "." .. gather_name
  else
    anonymous_counter = anonymous_counter + 1
    passage_id = parent_path .. "._gather_" .. anonymous_counter
  end

  -- Create the passage
  local passage = Passage.new({
    id = passage_id,
    name = gather_name or ("gather_" .. anonymous_counter),
    title = gather_name and self:_path_to_title(gather_name) or "Gather Point",
    content = "",
    tags = {},
    metadata = {}
  })

  -- Extract content from gather
  if gather_data then
    local content, tags = self:_extract_content(gather_data)
    passage:set_content(content)

    for _, tag in ipairs(tags) do
      passage:add_tag(tag)
    end
  end

  -- Store metadata
  passage:set_metadata("parent_path", parent_path)
  passage:set_metadata("is_gather", true)
  if not gather_name then
    passage:set_metadata("is_anonymous", true)
  end
  if options.preserve_ink_paths then
    passage:set_metadata("ink_path", passage_id)
  end

  return passage
end

-- Convert name to human-readable title
function GatherTransformer:_path_to_title(name)
  local title = name
  title = title:gsub("_", " ")
  title = title:gsub("(%l)(%u)", "%1 %2")
  title = title:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end)
  return title
end

-- Extract content from gather data
function GatherTransformer:_extract_content(gather_data)
  local content_parts = {}
  local tags = {}

  if type(gather_data) ~= "table" then
    return "", {}
  end

  self:_process_container(gather_data, content_parts, tags)

  return table.concat(content_parts), tags
end

-- Process a container recursively
function GatherTransformer:_process_container(container, content_parts, tags)
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

-- Reset the anonymous counter (useful for testing)
function GatherTransformer.reset_counter()
  anonymous_counter = 0
end

return GatherTransformer
