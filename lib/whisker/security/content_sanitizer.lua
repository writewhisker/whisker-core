--- Content Sanitizer
-- HTML sanitization for XSS prevention using allowlist approach
-- @module whisker.security.content_sanitizer
-- @author Whisker Core Team
-- @license MIT

local HTMLParser = require("whisker.security.html_parser")

local ContentSanitizer = {}

--- Allowed HTML tags (allowlist)
ContentSanitizer.ALLOWED_TAGS = {
  -- Text formatting
  "p", "br", "hr",
  "strong", "b",
  "em", "i",
  "u", "s", "strike", "del", "ins",
  "sub", "sup",
  "small", "big",
  "mark", "abbr", "dfn",
  "code", "pre", "kbd", "samp", "var",
  "q", "blockquote", "cite",

  -- Headings
  "h1", "h2", "h3", "h4", "h5", "h6",

  -- Lists
  "ul", "ol", "li",
  "dl", "dt", "dd",

  -- Structure
  "div", "span",
  "article", "section", "aside", "header", "footer", "main", "nav",

  -- Tables
  "table", "thead", "tbody", "tfoot",
  "tr", "th", "td",
  "caption", "colgroup", "col",

  -- Links and media
  "a",
  "img",
  "figure", "figcaption",
  "picture", "source",
  "audio", "video", "track",

  -- Ruby annotations
  "ruby", "rt", "rp",

  -- Other
  "details", "summary",
  "time", "address",
  "wbr",
}

--- Global allowed attributes (for all tags)
ContentSanitizer.GLOBAL_ATTRIBUTES = {
  "id",
  "class",
  "title",
  "lang",
  "dir",
  "hidden",
  "tabindex",
  -- Data attributes handled separately
  -- ARIA attributes handled separately
}

--- Tag-specific allowed attributes
ContentSanitizer.TAG_ATTRIBUTES = {
  a = {"href", "target", "rel", "download", "hreflang", "type"},
  img = {"src", "alt", "width", "height", "loading", "decoding", "srcset", "sizes"},
  audio = {"src", "controls", "autoplay", "loop", "muted", "preload"},
  video = {"src", "controls", "autoplay", "loop", "muted", "preload", "width", "height", "poster"},
  source = {"src", "srcset", "media", "sizes", "type"},
  track = {"src", "kind", "srclang", "label", "default"},
  blockquote = {"cite"},
  q = {"cite"},
  time = {"datetime"},
  abbr = {"title"},
  dfn = {"title"},
  table = {"border", "cellpadding", "cellspacing"},
  th = {"colspan", "rowspan", "scope", "headers"},
  td = {"colspan", "rowspan", "headers"},
  col = {"span"},
  colgroup = {"span"},
  ol = {"start", "type", "reversed"},
  li = {"value"},
  details = {"open"},
  meter = {"value", "min", "max", "low", "high", "optimum"},
  progress = {"value", "max"},
}

--- Dangerous tags to always remove
ContentSanitizer.DANGEROUS_TAGS = {
  "script",
  "style",
  "iframe",
  "frame",
  "frameset",
  "object",
  "embed",
  "applet",
  "form",
  "input",
  "button",
  "select",
  "textarea",
  "link",
  "meta",
  "base",
  "noscript",
  "template",
  "slot",
  "math",  -- Can contain script
  "svg",   -- Can contain script
  "title",
}

--- Dangerous attribute patterns (event handlers, javascript URLs)
ContentSanitizer.DANGEROUS_ATTRIBUTE_PATTERNS = {
  "^on%w+$",           -- Event handlers: onclick, onerror, etc.
  "^formaction$",      -- Form actions
  "^action$",          -- Form actions
  "^background$",      -- Background images (can load external content)
  "^dynsrc$",          -- IE-specific dynamic source
  "^lowsrc$",          -- Low-resolution source
  "^xmlns",            -- XML namespaces (can enable SVG/MathML)
}

--- Dangerous URL schemes
ContentSanitizer.DANGEROUS_SCHEMES = {
  "javascript:",
  "vbscript:",
  "data:text/html",
  "data:application",
}

--- Safe URL schemes
ContentSanitizer.SAFE_SCHEMES = {
  "http:",
  "https:",
  "mailto:",
  "tel:",
  "#",  -- Fragment identifier
  "/",  -- Relative paths
}

--- Security logger (injected)
local _logger = nil

--- Set security logger
-- @param logger table Logger instance
function ContentSanitizer.set_logger(logger)
  _logger = logger
end

--- Log security event
local function log_event(event_type, details)
  if _logger and _logger.log_security_event then
    _logger.log_security_event(event_type, details)
  end
end

--- Build lookup tables for O(1) access
local _allowed_tags_set = nil
local _dangerous_tags_set = nil
local _global_attrs_set = nil

local function ensure_lookups()
  if _allowed_tags_set then
    return
  end

  _allowed_tags_set = {}
  for _, tag in ipairs(ContentSanitizer.ALLOWED_TAGS) do
    _allowed_tags_set[tag] = true
  end

  _dangerous_tags_set = {}
  for _, tag in ipairs(ContentSanitizer.DANGEROUS_TAGS) do
    _dangerous_tags_set[tag] = true
  end

  _global_attrs_set = {}
  for _, attr in ipairs(ContentSanitizer.GLOBAL_ATTRIBUTES) do
    _global_attrs_set[attr] = true
  end
end

--- Check if tag is allowed
-- @param tag string Tag name (lowercase)
-- @return boolean
function ContentSanitizer.is_tag_allowed(tag)
  ensure_lookups()
  return _allowed_tags_set[tag] == true
end

--- Check if tag is dangerous
-- @param tag string Tag name (lowercase)
-- @return boolean
function ContentSanitizer.is_tag_dangerous(tag)
  ensure_lookups()
  return _dangerous_tags_set[tag] == true
end

--- Check if attribute is allowed for tag
-- @param tag string Tag name
-- @param attr string Attribute name
-- @return boolean
function ContentSanitizer.is_attribute_allowed(tag, attr)
  ensure_lookups()

  attr = attr:lower()

  -- Check global attributes
  if _global_attrs_set[attr] then
    return true
  end

  -- Check data-* attributes
  if attr:match("^data%-[a-z0-9%-]+$") then
    return true
  end

  -- Check aria-* attributes
  if attr:match("^aria%-[a-z]+$") then
    return true
  end

  -- Check role attribute
  if attr == "role" then
    return true
  end

  -- Check tag-specific attributes
  local tag_attrs = ContentSanitizer.TAG_ATTRIBUTES[tag]
  if tag_attrs then
    for _, allowed_attr in ipairs(tag_attrs) do
      if attr == allowed_attr then
        return true
      end
    end
  end

  return false
end

--- Check if attribute is dangerous
-- @param attr string Attribute name
-- @return boolean
function ContentSanitizer.is_attribute_dangerous(attr)
  attr = attr:lower()

  for _, pattern in ipairs(ContentSanitizer.DANGEROUS_ATTRIBUTE_PATTERNS) do
    if attr:match(pattern) then
      return true
    end
  end

  return false
end

--- Check if URL is safe
-- @param url string URL to check
-- @return boolean
function ContentSanitizer.is_url_safe(url)
  if not url or url == "" then
    return true
  end

  url = url:lower():gsub("^%s+", ""):gsub("%s+$", "")

  -- Decode entities for checking
  url = HTMLParser.decode_entities(url)

  -- Check for dangerous schemes
  for _, scheme in ipairs(ContentSanitizer.DANGEROUS_SCHEMES) do
    if url:sub(1, #scheme) == scheme then
      return false
    end
  end

  -- Check for javascript: with various encodings
  if url:match("^%s*j%s*a%s*v%s*a%s*s%s*c%s*r%s*i%s*p%s*t%s*:") then
    return false
  end

  -- Check for data: with text/html
  if url:match("^data:") and not url:match("^data:image/") then
    return false
  end

  return true
end

--- Sanitize a single attribute value
-- @param tag string Tag name
-- @param attr string Attribute name
-- @param value any Attribute value
-- @return any|nil Sanitized value or nil if should be removed
function ContentSanitizer.sanitize_attribute_value(tag, attr, value)
  if value == true then
    return true  -- Boolean attribute
  end

  if type(value) ~= "string" then
    return nil
  end

  -- URL attributes need special handling
  local url_attrs = {
    href = true, src = true, cite = true, action = true,
    formaction = true, poster = true, background = true,
    srcset = true,
  }

  if url_attrs[attr] then
    if not ContentSanitizer.is_url_safe(value) then
      log_event("DANGEROUS_ATTRIBUTE_REMOVED", {
        tag = tag,
        attribute = attr,
        reason = "dangerous_url",
      })
      return nil
    end
  end

  -- srcset needs special handling
  if attr == "srcset" then
    -- Validate each URL in srcset
    local parts = {}
    for part in value:gmatch("[^,]+") do
      local url = part:match("^%s*(%S+)")
      if url and ContentSanitizer.is_url_safe(url) then
        table.insert(parts, part)
      end
    end
    if #parts == 0 then
      return nil
    end
    return table.concat(parts, ", ")
  end

  -- style attribute - strip it entirely for now (would need CSS sanitizer)
  if attr == "style" then
    return nil
  end

  return value
end

--- Sanitize element node
-- @param node table Element node
-- @return table|nil Sanitized node or nil if should be removed
function ContentSanitizer.sanitize_element(node)
  local tag = node.tag:lower()

  -- Remove dangerous tags entirely
  if ContentSanitizer.is_tag_dangerous(tag) then
    log_event("DANGEROUS_TAG_REMOVED", {
      tag = tag,
    })
    return nil
  end

  -- If tag not allowed, convert to span or remove
  if not ContentSanitizer.is_tag_allowed(tag) then
    -- Convert unknown tags to span, keeping content
    node.tag = "span"
    node.attributes = {
      class = "sanitized-" .. tag,
    }
    log_event("XSS_BLOCKED", {
      original_tag = tag,
      action = "converted_to_span",
    })
  end

  -- Sanitize attributes
  local safe_attrs = {}

  for attr, value in pairs(node.attributes) do
    attr = attr:lower()

    -- Check if attribute is dangerous
    if ContentSanitizer.is_attribute_dangerous(attr) then
      log_event("DANGEROUS_ATTRIBUTE_REMOVED", {
        tag = node.tag,
        attribute = attr,
        reason = "dangerous_pattern",
      })
    elseif ContentSanitizer.is_attribute_allowed(node.tag, attr) then
      local safe_value = ContentSanitizer.sanitize_attribute_value(node.tag, attr, value)
      if safe_value ~= nil then
        safe_attrs[attr] = safe_value
      end
    else
      log_event("DANGEROUS_ATTRIBUTE_REMOVED", {
        tag = node.tag,
        attribute = attr,
        reason = "not_in_allowlist",
      })
    end
  end

  node.attributes = safe_attrs

  -- Sanitize children
  local safe_children = {}
  for _, child in ipairs(node.children) do
    local safe_child = ContentSanitizer.sanitize_node(child)
    if safe_child then
      table.insert(safe_children, safe_child)
    end
  end
  node.children = safe_children

  return node
end

--- Sanitize any node
-- @param node table DOM node
-- @return table|nil Sanitized node or nil if should be removed
function ContentSanitizer.sanitize_node(node)
  if node.type == HTMLParser.NODE_TYPES.TEXT then
    return node
  elseif node.type == HTMLParser.NODE_TYPES.COMMENT then
    -- Remove comments (can contain conditional IE hacks)
    return nil
  elseif node.type == HTMLParser.NODE_TYPES.ELEMENT then
    return ContentSanitizer.sanitize_element(node)
  elseif node.type == "root" then
    local safe_children = {}
    for _, child in ipairs(node.children) do
      local safe_child = ContentSanitizer.sanitize_node(child)
      if safe_child then
        table.insert(safe_children, safe_child)
      end
    end
    node.children = safe_children
    return node
  end

  return node
end

--- Sanitize HTML string
-- @param html string HTML content
-- @return string Sanitized HTML
function ContentSanitizer.sanitize(html)
  if not html or html == "" then
    return ""
  end

  -- Parse HTML
  local dom = HTMLParser.parse(html)

  -- Sanitize DOM
  local safe_dom = ContentSanitizer.sanitize_node(dom)

  -- Serialize back to HTML
  return HTMLParser.serialize(safe_dom)
end

--- Sanitize plain text (escape HTML entities)
-- @param text string Plain text
-- @return string Escaped text safe for HTML insertion
function ContentSanitizer.escape_text(text)
  return HTMLParser.encode_entities(text)
end

--- Strip all HTML tags
-- @param html string HTML content
-- @return string Plain text content
function ContentSanitizer.strip_tags(html)
  if not html or html == "" then
    return ""
  end

  local dom = HTMLParser.parse(html)
  local parts = {}

  local function extract_text(node)
    if node.type == HTMLParser.NODE_TYPES.TEXT then
      table.insert(parts, node.content)
    elseif node.children then
      for _, child in ipairs(node.children) do
        extract_text(child)
      end
    end
  end

  extract_text(dom)
  return table.concat(parts)
end

--- Add target="_blank" and rel="noopener" to external links
-- @param html string HTML content
-- @return string HTML with safe external links
function ContentSanitizer.secure_links(html)
  local dom = HTMLParser.parse(html)

  HTMLParser.walk(dom, function(node)
    if node.type == HTMLParser.NODE_TYPES.ELEMENT and node.tag == "a" then
      local href = node.attributes.href
      if href and href:match("^https?://") then
        node.attributes.target = "_blank"
        node.attributes.rel = "noopener noreferrer"
      end
    end
  end)

  return HTMLParser.serialize(dom)
end

--- Validate that HTML is safe (without modifying)
-- @param html string HTML content
-- @return boolean safe
-- @return table|nil issues Array of issue descriptions
function ContentSanitizer.validate(html)
  local issues = {}
  local dom = HTMLParser.parse(html)

  HTMLParser.walk(dom, function(node)
    if node.type == HTMLParser.NODE_TYPES.ELEMENT then
      if ContentSanitizer.is_tag_dangerous(node.tag) then
        table.insert(issues, "Dangerous tag: " .. node.tag)
      elseif not ContentSanitizer.is_tag_allowed(node.tag) then
        table.insert(issues, "Unknown tag: " .. node.tag)
      end

      for attr, value in pairs(node.attributes) do
        if ContentSanitizer.is_attribute_dangerous(attr) then
          table.insert(issues, "Dangerous attribute: " .. attr)
        elseif type(value) == "string" and not ContentSanitizer.is_url_safe(value) then
          table.insert(issues, "Dangerous URL in " .. attr .. ": " .. value:sub(1, 50))
        end
      end
    end
  end)

  return #issues == 0, issues
end

return ContentSanitizer
