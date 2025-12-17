-- whisker/formats/ink/generators/passage.lua
-- Generates Ink containers from whisker passages

local PassageGenerator = {}
PassageGenerator.__index = PassageGenerator

-- Module metadata
PassageGenerator._whisker = {
  name = "PassageGenerator",
  version = "1.0.0",
  description = "Generates Ink containers from whisker passages",
  depends = {},
  capability = "formats.ink.generators.passage"
}

-- Create a new PassageGenerator instance
function PassageGenerator.new()
  local instance = {}
  setmetatable(instance, PassageGenerator)
  return instance
end

-- Generate an Ink container from a passage
-- @param passage table - The whisker passage
-- @param options table|nil - Generation options
-- @return table - Ink container structure
function PassageGenerator:generate(passage, options)
  options = options or {}

  local container = {}

  -- Add text content
  if passage.content then
    self:_add_content(container, passage.content)
  end

  if passage.text then
    self:_add_content(container, passage.text)
  end

  -- Add end marker for simple passages
  if not passage.choices and not passage.next and not passage.divert then
    table.insert(container, "end")
  end

  -- Add named children dictionary if needed
  if options.include_metadata then
    container[#container + 1] = nil -- trailing null for named dict
  end

  return container
end

-- Add content to container
-- @param container table - The container being built
-- @param content string|table - Content to add
function PassageGenerator:_add_content(container, content)
  if type(content) == "string" then
    -- Add text with ^ prefix for Ink JSON format
    table.insert(container, "^" .. content)
    table.insert(container, "\n")
  elseif type(content) == "table" then
    for _, item in ipairs(content) do
      if type(item) == "string" then
        table.insert(container, "^" .. item)
        table.insert(container, "\n")
      end
    end
  end
end

-- Generate a knot container (top-level passage)
-- @param passage table - The whisker passage
-- @param options table|nil - Generation options
-- @return table - Ink knot container
function PassageGenerator:generate_knot(passage, options)
  local container = self:generate(passage, options)
  return container
end

-- Generate a stitch container (nested passage)
-- @param passage table - The whisker passage
-- @param parent_id string - Parent knot ID
-- @param options table|nil - Generation options
-- @return table - Ink stitch container
function PassageGenerator:generate_stitch(passage, parent_id, options)
  local container = self:generate(passage, options)
  return container
end

-- Check if passage should be a knot (top-level)
-- @param passage table - The whisker passage
-- @return boolean
function PassageGenerator:is_knot(passage)
  if passage.metadata then
    if passage.metadata.type == "knot" then
      return true
    end
    if passage.metadata.parent then
      return false
    end
  end

  -- No dots in ID means it's a top-level knot
  local id = passage.id or ""
  return not id:match("%.")
end

-- Extract knot name from passage ID
-- @param passage table - The whisker passage
-- @return string - Knot name
function PassageGenerator:get_knot_name(passage)
  local id = passage.id or "unnamed"

  -- If it's a stitch (has dot), return just the knot part
  if id:match("%.") then
    return id:match("^([^.]+)")
  end

  return id
end

-- Extract stitch name from passage ID
-- @param passage table - The whisker passage
-- @return string|nil - Stitch name or nil if it's a knot
function PassageGenerator:get_stitch_name(passage)
  local id = passage.id or ""

  if id:match("%.") then
    return id:match("%.(.+)$")
  end

  return nil
end

-- Generate passage metadata for Ink
-- @param passage table - The whisker passage
-- @return table|nil - Metadata or nil
function PassageGenerator:generate_metadata(passage)
  if not passage.tags and not passage.metadata then
    return nil
  end

  local meta = {}

  -- Add tags
  if passage.tags then
    for _, tag in ipairs(passage.tags) do
      table.insert(meta, "#" .. tag)
    end
  end

  return #meta > 0 and meta or nil
end

return PassageGenerator
