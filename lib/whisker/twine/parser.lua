--- Twine story parser
-- Parses Twine HTML files and converts them to WhiskerScript stories
--
-- lib/whisker/twine/parser.lua

local TwineParser = {}

--------------------------------------------------------------------------------
-- Format Handler Loading
--------------------------------------------------------------------------------

local handlers = {
  harlowe = nil,
  sugarcube = nil,
  chapbook = nil,
  snowman = nil
}

--- Load format handlers lazily
local function get_handler(format)
  local format_lower = format:lower()

  if not handlers[format_lower] then
    local success, handler_module = pcall(function()
      return require('whisker.twine.formats.' .. format_lower .. '.handler')
    end)

    if success then
      handlers[format_lower] = handler_module.new()
    end
  end

  return handlers[format_lower]
end

--------------------------------------------------------------------------------
-- HTML Parsing
--------------------------------------------------------------------------------

--- Parse tw-storydata element from HTML
---@param html string Raw HTML content
---@return table|nil, string Parsed story data or nil with error
local function parse_html(html)
  if not html or html == "" then
    return nil, "Empty HTML content"
  end

  -- Find tw-storydata element
  local storydata_start = html:find("<tw%-storydata")
  if not storydata_start then
    return nil, "No tw-storydata element found"
  end

  -- Extract attributes from tw-storydata
  local attrs_end = html:find(">", storydata_start)
  if not attrs_end then
    return nil, "Malformed tw-storydata element"
  end

  local attrs_text = html:sub(storydata_start, attrs_end)

  -- Parse metadata
  local metadata = {
    name = attrs_text:match('name="([^"]*)"') or "Untitled",
    startnode = tonumber(attrs_text:match('startnode="([^"]*)"') or "1"),
    ifid = attrs_text:match('ifid="([^"]*)"'),
    format = attrs_text:match('format="([^"]*)"') or "Harlowe",
    format_version = attrs_text:match('format%-version="([^"]*)"'),
    creator = attrs_text:match('creator="([^"]*)"'),
    creator_version = attrs_text:match('creator%-version="([^"]*)"')
  }

  -- Extract passages
  local passages = {}
  local css = ""
  local javascript = ""

  -- Parse CSS
  local css_match = html:match('<style[^>]*type="text/twine%-css"[^>]*>(.-)</style>')
  if css_match then
    css = css_match
  end

  -- Parse JavaScript
  local js_match = html:match('<script[^>]*type="text/twine%-javascript"[^>]*>(.-)</script>')
  if js_match then
    javascript = js_match
  end

  -- Parse passages
  for passage_html in html:gmatch("<tw%-passagedata[^>]*>.-</tw%-passagedata>") do
    local passage = parse_passage(passage_html)
    if passage then
      table.insert(passages, passage)
    end
  end

  return {
    metadata = metadata,
    passages = passages,
    css = css,
    javascript = javascript
  }
end

--- Parse single tw-passagedata element
---@param passage_html string Passage HTML
---@return table|nil Parsed passage
function parse_passage(passage_html)
  -- Extract attributes
  local pid = passage_html:match('pid="([^"]*)"')
  local name = passage_html:match('name="([^"]*)"')
  local tags_str = passage_html:match('tags="([^"]*)"')
  local position = passage_html:match('position="([^"]*)"')

  -- Extract content
  local content = passage_html:match("<tw%-passagedata[^>]*>(.-)</tw%-passagedata>")

  -- Unescape HTML entities
  if content then
    content = unescape_html(content)
  end

  -- Parse tags
  local tags = {}
  if tags_str and tags_str ~= "" then
    for tag in tags_str:gmatch("[^%s]+") do
      table.insert(tags, tag)
    end
  end

  -- Parse position
  local x, y = 100, 100
  if position then
    x, y = position:match("(%d+),(%d+)")
    x = tonumber(x) or 100
    y = tonumber(y) or 100
  end

  return {
    pid = tonumber(pid),
    name = name,
    tags = tags,
    position = { x = x, y = y },
    content = content
  }
end

--- Unescape HTML entities
---@param text string HTML-escaped text
---@return string Unescaped text
function unescape_html(text)
  if not text then return "" end

  return text
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&amp;", "&")
    :gsub("&quot;", '"')
    :gsub("&apos;", "'")
    :gsub("&#(%d+);", function(n) return string.char(tonumber(n)) end)
    :gsub("&#x(%x+);", function(n) return string.char(tonumber(n, 16)) end)
end

--------------------------------------------------------------------------------
-- Main Parser
--------------------------------------------------------------------------------

--- Parse Twine HTML file
---@param html string Raw HTML content
---@return table|nil, string Story object or nil with error
function TwineParser.parse(html)
  -- Parse HTML structure
  local html_data, err = parse_html(html)
  if not html_data then
    return nil, err
  end

  -- Detect format
  local format = html_data.metadata.format:lower()
  local handler = get_handler(format)

  if not handler then
    return nil, "Unsupported format: " .. format
  end

  -- Parse each passage with format-specific handler
  local parsed_passages = {}
  local warnings = {}

  for _, passage in ipairs(html_data.passages) do
    local ast = handler:parse_passage(passage)

    table.insert(parsed_passages, {
      pid = passage.pid,
      name = passage.name,
      tags = passage.tags,
      position = passage.position,
      content = passage.content,
      text = passage.content,
      ast = ast
    })
  end

  return {
    metadata = html_data.metadata,
    passages = parsed_passages,
    css = html_data.css,
    javascript = html_data.javascript,
    warnings = warnings
  }
end

--- Get detected format from HTML
---@param html string Raw HTML content
---@return string|nil Format name or nil
function TwineParser.detect_format(html)
  if not html then return nil end

  local format = html:match('format="([^"]*)"')
  if format then
    return format:lower()
  end

  return nil
end

--- Check if HTML is a valid Twine file
---@param html string Raw HTML content
---@return boolean True if valid Twine HTML
function TwineParser.is_twine_html(html)
  return html and html:find("<tw%-storydata") ~= nil
end

return TwineParser
