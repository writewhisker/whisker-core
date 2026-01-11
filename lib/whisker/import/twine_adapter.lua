--- Twine Story Format Adapter
-- Imports Twine HTML story files (Harlowe, SugarCube, Chapbook formats)
-- Integrates with parser framework
--
-- @module whisker.import.twine_adapter
-- @author Whisker Team
-- @license MIT

local TwineAdapter = {}

TwineAdapter.name = "twine"
TwineAdapter.formats = {"html", "twee"}

--- Detect if data is a Twine story
-- @param data string File content
-- @return boolean is_twine True if Twine format detected
function TwineAdapter.detect(data)
  -- Check for Twine HTML markers
  if data:match("<tw%-storydata") or data:match("<tw%-passagedata") then
    return true
  end
  
  -- Check for Twee format
  if data:match("::") and data:match("::StoryData") then
    return true
  end
  
  return false
end

--- Extract attribute from HTML tag
-- @param tag string HTML tag
-- @param attr string Attribute name
-- @return string|nil value Attribute value
local function get_attribute(tag, attr)
  local pattern = attr .. '="([^"]*)"'
  return tag:match(pattern)
end

--- Parse Twine HTML format
-- @param data string HTML content
-- @param options table Parse options
-- @return table ir Intermediate representation
function TwineAdapter.parse(data, options)
  options = options or {}
  
  local ir = {
    format = "twine",
    version = nil,
    metadata = {
      title = "Untitled",
      author = nil,
      ifid = nil
    },
    passages = {},
    variables = {},
    scripts = {},
    stylesheets = {},
    tags = {},
    custom = {}
  }
  
  -- Extract story data
  local storydata = data:match("<tw%-storydata[^>]*>")
  if storydata then
    ir.metadata.title = get_attribute(storydata, "name") or "Untitled"
    ir.metadata.ifid = get_attribute(storydata, "ifid")
    ir.custom.format = get_attribute(storydata, "format")
    ir.custom.format_version = get_attribute(storydata, "format%-version")
    ir.custom.start = get_attribute(storydata, "startnode")
  end
  
  -- Extract passages
  local passage_pattern = "<tw%-passagedata([^>]*)>(.-)</tw%-passagedata>"
  for passage_tag, passage_content in data:gmatch(passage_pattern) do
    local passage = {
      id = get_attribute(passage_tag, "pid") or get_attribute(passage_tag, "name"),
      name = get_attribute(passage_tag, "name"),
      tags = {},
      content = passage_content,
      position = { x = 0, y = 0 },
      size = { width = 100, height = 100 },
      metadata = {}
    }
    
    -- Extract tags
    local tags_str = get_attribute(passage_tag, "tags")
    if tags_str and tags_str ~= "" then
      for tag in tags_str:gmatch("[^%s]+") do
        table.insert(passage.tags, tag)
      end
    end
    
    -- Extract position
    local pos_str = get_attribute(passage_tag, "position")
    if pos_str then
      local x, y = pos_str:match("([%d%.]+),([%d%.]+)")
      if x and y then
        passage.position.x = tonumber(x) or 0
        passage.position.y = tonumber(y) or 0
      end
    end
    
    -- Extract size
    local size_str = get_attribute(passage_tag, "size")
    if size_str then
      local w, h = size_str:match("([%d%.]+),([%d%.]+)")
      if w and h then
        passage.size.width = tonumber(w) or 100
        passage.size.height = tonumber(h) or 100
      end
    end
    
    -- Decode HTML entities in content
    passage.content = passage.content:gsub("&lt;", "<")
    passage.content = passage.content:gsub("&gt;", ">")
    passage.content = passage.content:gsub("&quot;", '"')
    passage.content = passage.content:gsub("&apos;", "'")
    passage.content = passage.content:gsub("&amp;", "&")
    
    table.insert(ir.passages, passage)
  end
  
  -- Extract scripts (if any)
  local script_pattern = "<script[^>]*>(.-)</script>"
  for script in data:gmatch(script_pattern) do
    table.insert(ir.scripts, script)
  end
  
  -- Extract stylesheets (if any)
  local style_pattern = "<style[^>]*>(.-)</style>"
  for style in data:gmatch(style_pattern) do
    table.insert(ir.stylesheets, style)
  end
  
  return ir
end

--- Validate Twine intermediate representation
-- @param ir table Intermediate representation
-- @return table result Validation result
function TwineAdapter.validate(ir)
  local errors = {}
  local warnings = {}
  
  -- Check for passages
  if not ir.passages or #ir.passages == 0 then
    table.insert(errors, "Story has no passages")
  end
  
  -- Check for start passage
  local has_start = false
  for _, passage in ipairs(ir.passages or {}) do
    if passage.id == ir.custom.start or passage.name == "Start" then
      has_start = true
      break
    end
  end
  
  if not has_start and #(ir.passages or {}) > 0 then
    table.insert(warnings, "No start passage found, will use first passage")
  end
  
  -- Check for duplicate passage names
  local names = {}
  for _, passage in ipairs(ir.passages or {}) do
    if names[passage.name] then
      table.insert(errors, string.format("Duplicate passage name: %s", passage.name))
    end
    names[passage.name] = true
  end
  
  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings
  }
end

--- Extract links from Twine passage content
-- Supports common Twine link formats:
-- [[Link Text]]
-- [[Link Text->Destination]]
-- [[Link Text|Destination]]
-- @param content string Passage content
-- @return table links Array of link info
local function extract_links(content)
  local links = {}
  
  -- Pattern 1: [[Link Text->Destination]]
  for text, dest in content:gmatch("%[%[([^%]|>]+)%->([^%]]+)%]%]") do
    table.insert(links, {
      text = text,
      target = dest,
      type = "arrow"
    })
  end
  
  -- Pattern 2: [[Link Text|Destination]]
  for text, dest in content:gmatch("%[%[([^%]|>]+)|([^%]]+)%]%]") do
    table.insert(links, {
      text = text,
      target = dest,
      type = "pipe"
    })
  end
  
  -- Pattern 3: [[Destination]]
  for dest in content:gmatch("%[%[([^%]|>]+)%]%]") do
    -- Skip if already matched by patterns above
    local already_matched = false
    for _, link in ipairs(links) do
      if link.target == dest or link.text == dest then
        already_matched = true
        break
      end
    end
    
    if not already_matched then
      table.insert(links, {
        text = dest,
        target = dest,
        type = "simple"
      })
    end
  end
  
  return links
end

--- Transform intermediate representation to whisker story
-- @param ir table Intermediate representation
-- @return table story Whisker story object
function TwineAdapter.transform(ir)
  local story = {
    id = ir.metadata.ifid or string.format("twine-%d", os.time()),
    title = ir.metadata.title,
    metadata = {
      title = ir.metadata.title,
      author = ir.metadata.author,
      ifid = ir.metadata.ifid,
      format = "twine",
      original_format = ir.custom.format
    },
    passages = {},
    variables = ir.variables or {},
    tags = ir.tags or {}
  }
  
  -- Determine start passage
  local start_id = ir.custom.start
  if not start_id and #ir.passages > 0 then
    -- Find passage named "Start"
    for _, passage in ipairs(ir.passages) do
      if passage.name == "Start" or passage.name == "start" then
        start_id = passage.id
        break
      end
    end
    
    -- Default to first passage
    if not start_id then
      start_id = ir.passages[1].id
    end
  end
  
  story.start_passage = start_id
  
  -- Transform passages
  for _, ir_passage in ipairs(ir.passages) do
    local passage = {
      id = ir_passage.id or ir_passage.name,
      name = ir_passage.name,
      content = ir_passage.content,
      tags = ir_passage.tags or {},
      position = ir_passage.position,
      size = ir_passage.size,
      choices = {},
      metadata = ir_passage.metadata or {}
    }
    
    -- Extract links as choices
    local links = extract_links(ir_passage.content)
    for _, link in ipairs(links) do
      table.insert(passage.choices, {
        text = link.text,
        target = link.target,
        condition = nil  -- Could be extracted from content later
      })
    end
    
    table.insert(story.passages, passage)
  end
  
  return story
end

return TwineAdapter
