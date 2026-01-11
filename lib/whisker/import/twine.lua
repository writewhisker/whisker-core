--[[
  Twine HTML Import Adapter
  
  Imports Twine 2 HTML stories into whisker-core format.
  
  Supports:
  - Twine 2 HTML archives
  - Multiple story formats (Harlowe, SugarCube, Snowman)
  - Passage extraction
  - Link parsing
  - Metadata extraction
  
  Usage:
    local TwineImporter = require("whisker.import.twine")
    local importer = TwineImporter.new()
    local story = importer:import_from_file("story.html")
]]

local Story = require("whisker.core.story")

local TwineImporter = {}
TwineImporter.__index = TwineImporter

--[[
  Create a new Twine importer instance
  
  @param options table Optional configuration
  @return TwineImporter New importer instance
]]
function TwineImporter.new(options)
  options = options or {}
  
  local self = setmetatable({
    options = options,
    warnings = {},
    stats = {
      passages_imported = 0,
      links_found = 0,
      warnings = 0
    }
  }, TwineImporter)
  
  return self
end

--[[
  Import Twine story from HTML file
  
  @param filepath string Path to Twine HTML file
  @return Story|nil Imported story
  @return string|nil Error message
]]
function TwineImporter:import_from_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return nil, "Could not open file: " .. filepath
  end
  
  local html = file:read("*all")
  file:close()
  
  return self:import_from_html(html)
end

--[[
  Import Twine story from HTML string
  
  @param html string Twine HTML content
  @return Story|nil Imported story
  @return string|nil Error message
]]
function TwineImporter:import_from_html(html)
  -- Reset stats
  self.warnings = {}
  self.stats = {
    passages_imported = 0,
    links_found = 0,
    warnings = 0
  }
  
  -- Extract story data
  local story_data = self:extract_story_data(html)
  if not story_data then
    return nil, "Could not extract story data from HTML"
  end
  
  -- Extract passages
  local passages = self:extract_passages(html, story_data)
  if not passages or #passages == 0 then
    return nil, "No passages found in story"
  end
  
  -- Build story object
  local story = Story.from_table({
    metadata = {
      id = story_data.ifid or self:generate_id(),
      title = story_data.name or "Imported Twine Story",
      author = story_data.creator or "Unknown",
      description = story_data.description or "",
      tags = {},
      imported_from = "twine",
      original_format = story_data.format
    },
    passages = passages,
    start_passage = story_data.startnode or passages[1].id
  })
  
  return story, nil
end

--[[
  Extract story metadata from HTML
  
  @param html string HTML content
  @return table|nil Story metadata
]]
function TwineImporter:extract_story_data(html)
  local data = {}
  
  -- Extract from tw-storydata tag
  local storydata = html:match('<tw%-storydata([^>]*)>')
  if storydata then
    data.name = storydata:match('name="([^"]*)"') or
                 storydata:match("name='([^']*)'")
    data.startnode = storydata:match('startnode="([^"]*)"') or
                      storydata:match("startnode='([^']*)'")
    data.creator = storydata:match('creator="([^"]*)"') or
                    storydata:match("creator='([^']*)'")
    data.ifid = storydata:match('ifid="([^"]*)"') or
                 storydata:match("ifid='([^']*)'")
    data.format = storydata:match('format="([^"]*)"') or
                   storydata:match("format='([^']*)'")
  end
  
  -- Fallback: Extract from title tag
  if not data.name then
    data.name = html:match('<title>([^<]*)</title>')
  end
  
  return data
end

--[[
  Extract passages from HTML
  
  @param html string HTML content
  @param story_data table Story metadata
  @return table Array of passage objects
]]
function TwineImporter:extract_passages(html, story_data)
  local passages = {}
  
  -- Find all tw-passagedata tags
  for passage_html in html:gmatch('<tw%-passagedata([^>]*)>(.-)</tw%-passagedata>') do
    local passage = self:parse_passage(passage_html)
    if passage then
      table.insert(passages, passage)
      self.stats.passages_imported = self.stats.passages_imported + 1
    end
  end
  
  return passages
end

--[[
  Parse a single passage
  
  @param passage_html string Passage HTML content
  @return table|nil Passage object
]]
function TwineImporter:parse_passage(passage_html)
  -- Extract attributes
  local attrs, content = passage_html:match('([^>]*)(.*)')
  
  local pid = attrs:match('pid="([^"]*)"') or attrs:match("pid='([^']*)'")
  local name = attrs:match('name="([^"]*)"') or attrs:match("name='([^']*)'")
  local tags = attrs:match('tags="([^"]*)"') or attrs:match("tags='([^']*)'")
  
  if not name then
    self:add_warning("Passage without name found, skipping")
    return nil
  end
  
  -- Clean passage ID (use name as ID, sanitized)
  local passage_id = self:sanitize_id(name)
  
  -- Decode HTML entities in content
  content = self:decode_html_entities(content)
  
  -- Extract links and convert to choices
  local choices, clean_text = self:extract_links(content, passage_id)
  
  -- Parse tags
  local tag_list = {}
  if tags and tags ~= "" then
    for tag in tags:gmatch('[^%s]+') do
      table.insert(tag_list, tag)
    end
  end
  
  return {
    id = passage_id,
    text = clean_text,
    choices = choices,
    tags = tag_list,
    original_name = name,
    twine_pid = pid
  }
end

--[[
  Extract links from passage text and convert to choices
  
  @param text string Passage text
  @param passage_id string Current passage ID
  @return table Array of choices
  @return string Text with links removed
]]
function TwineImporter:extract_links(text, passage_id)
  local choices = {}
  local clean_text = text
  
  -- Pattern for [[Link]] or [[Display|Target]]
  local link_pattern = '%[%[([^%]]+)%]%]'
  
  for link in text:gmatch(link_pattern) do
    local display, target
    
    if link:match('|') then
      -- [[Display|Target]] format
      display, target = link:match('([^|]+)|([^|]+)')
    elseif link:match('->') then
      -- [[Display->Target]] format (SugarCube)
      display, target = link:match('([^%-]+)->(.+)')
    else
      -- [[Target]] format
      display = link
      target = link
    end
    
    if display and target then
      display = self:trim(display)
      target = self:trim(target)
      
      table.insert(choices, {
        text = display,
        target = self:sanitize_id(target)
      })
      
      self.stats.links_found = self.stats.links_found + 1
    end
  end
  
  -- Remove links from text
  clean_text = clean_text:gsub(link_pattern, '')
  
  -- Clean up extra whitespace
  clean_text = self:trim(clean_text)
  
  return choices, clean_text
end

--[[
  Sanitize passage name to valid ID
  
  @param name string Passage name
  @return string Sanitized ID
]]
function TwineImporter:sanitize_id(name)
  -- Convert to lowercase
  local id = name:lower()
  
  -- Replace spaces and special chars with underscores
  id = id:gsub('[^a-z0-9_]', '_')
  
  -- Remove consecutive underscores
  id = id:gsub('_+', '_')
  
  -- Remove leading/trailing underscores
  id = id:gsub('^_+', ''):gsub('_+$', '')
  
  -- Ensure not empty
  if id == '' then
    id = 'passage_' .. math.random(10000)
  end
  
  return id
end

--[[
  Decode HTML entities
  
  @param text string Text with HTML entities
  @return string Decoded text
]]
function TwineImporter:decode_html_entities(text)
  local entities = {
    ['&lt;'] = '<',
    ['&gt;'] = '>',
    ['&amp;'] = '&',
    ['&quot;'] = '"',
    ['&#39;'] = "'",
    ['&apos;'] = "'",
    ['&nbsp;'] = ' '
  }
  
  for entity, char in pairs(entities) do
    text = text:gsub(entity, char)
  end
  
  -- Decode numeric entities
  text = text:gsub('&#(%d+);', function(n)
    return string.char(tonumber(n))
  end)
  
  return text
end

--[[
  Trim whitespace from string
  
  @param s string String to trim
  @return string Trimmed string
]]
function TwineImporter:trim(s)
  return s:match('^%s*(.-)%s*$')
end

--[[
  Generate random ID
  
  @return string Random ID
]]
function TwineImporter:generate_id()
  return string.format('story_%d_%d', os.time(), math.random(10000))
end

--[[
  Add warning message
  
  @param message string Warning message
]]
function TwineImporter:add_warning(message)
  table.insert(self.warnings, message)
  self.stats.warnings = self.stats.warnings + 1
end

--[[
  Get import statistics
  
  @return table Statistics
]]
function TwineImporter:get_stats()
  return {
    passages_imported = self.stats.passages_imported,
    links_found = self.stats.links_found,
    warnings = self.stats.warnings,
    warning_messages = self.warnings
  }
end

return TwineImporter
