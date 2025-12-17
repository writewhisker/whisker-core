-- whisker/formats/ink/transformers/knot.lua
-- Knot to Passage transformer
-- Converts Ink knots to whisker-core Passage objects

local KnotTransformer = {}
KnotTransformer.__index = KnotTransformer

-- Module metadata
KnotTransformer._whisker = {
  name = "KnotTransformer",
  version = "1.0.0",
  description = "Transforms Ink knots to whisker-core Passages",
  depends = {},
  capability = "formats.ink.transformers.knot"
}

-- Create a new KnotTransformer instance
function KnotTransformer.new()
  local instance = {}
  setmetatable(instance, KnotTransformer)
  return instance
end

-- Transform a knot to a Passage
-- @param ink_story InkStory - The source Ink story
-- @param knot_path string - The knot path (e.g., "my_knot")
-- @param options table|nil - Conversion options
-- @return Passage - The converted passage
function KnotTransformer:transform(ink_story, knot_path, options)
  options = options or {}

  local Passage = require("whisker.core.passage")

  -- Get knot data from the story
  local data = ink_story:get_data()
  local root = data.root

  if not root then
    return nil
  end

  -- Find the knot in the root
  local knot_data = self:_find_knot(root, knot_path)

  -- Generate passage ID
  local passage_id = self:_generate_id(knot_path, options)

  -- Create the passage
  local passage = Passage.new({
    id = passage_id,
    name = knot_path,
    title = self:_path_to_title(knot_path),
    content = "",
    tags = {},
    metadata = {}
  })

  -- Extract content from knot
  if knot_data then
    local content, tags = self:_extract_content(knot_data)
    passage:set_content(content)

    for _, tag in ipairs(tags) do
      passage:add_tag(tag)
    end
  end

  -- Store original Ink path in metadata
  if options.preserve_ink_paths then
    passage:set_metadata("ink_path", knot_path)
  end

  return passage
end

-- Find a knot in the root structure
-- @param root table - The root container
-- @param knot_path string - The knot path
-- @return table|nil - The knot data
function KnotTransformer:_find_knot(root, knot_path)
  -- Ink JSON stores named containers as keys
  if type(root) ~= "table" then
    return nil
  end

  -- Check if root is an array with a trailing dictionary
  if root[1] ~= nil then
    -- Array format - look for trailing dictionary
    local last = root[#root]
    if type(last) == "table" and not last[1] then
      -- This is a named content dictionary
      if last[knot_path] then
        return last[knot_path]
      end
    end
  else
    -- Direct dictionary format
    if root[knot_path] then
      return root[knot_path]
    end
  end

  return nil
end

-- Generate passage ID from path
-- @param knot_path string - The knot path
-- @param options table - Conversion options
-- @return string - The passage ID
function KnotTransformer:_generate_id(knot_path, options)
  if options.generate_ids_from_paths then
    -- Use the path as-is
    return knot_path
  end
  -- Default: use path as ID
  return knot_path
end

-- Convert path to human-readable title
-- @param path string - The knot path
-- @return string - Human-readable title
function KnotTransformer:_path_to_title(path)
  -- Convert snake_case or camelCase to Title Case
  local title = path
  -- Replace underscores with spaces
  title = title:gsub("_", " ")
  -- Insert space before capitals in camelCase
  title = title:gsub("(%l)(%u)", "%1 %2")
  -- Capitalize first letter of each word
  title = title:gsub("(%a)([%w]*)", function(first, rest)
    return first:upper() .. rest:lower()
  end)
  return title
end

-- Extract content from knot data
-- @param knot_data table - The knot container
-- @return string, table - Content text and tags
function KnotTransformer:_extract_content(knot_data)
  local content_parts = {}
  local tags = {}

  if type(knot_data) ~= "table" then
    return "", {}
  end

  -- Process the knot container
  self:_process_container(knot_data, content_parts, tags)

  return table.concat(content_parts), tags
end

-- Process a container recursively
-- @param container table - The container
-- @param content_parts table - Accumulator for content
-- @param tags table - Accumulator for tags
function KnotTransformer:_process_container(container, content_parts, tags)
  if type(container) ~= "table" then
    return
  end

  for i, item in ipairs(container) do
    if type(item) == "string" then
      -- Text content (prefixed with ^) or command
      if item:sub(1, 1) == "^" then
        -- Text content
        table.insert(content_parts, item:sub(2))
      elseif item == "\n" then
        -- Newline
        table.insert(content_parts, "\n")
      end
    elseif type(item) == "table" then
      -- Could be a tag, command, or nested container
      if item["#"] then
        -- Tag
        table.insert(tags, item["#"])
      elseif item[1] ~= nil then
        -- Nested container
        self:_process_container(item, content_parts, tags)
      end
    end
  end
end

return KnotTransformer
