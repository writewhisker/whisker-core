--- Accessibility Utilities
-- Utility functions for accessibility features
-- @module whisker.a11y.utils
-- @author Whisker Core Team
-- @license MIT

local utils = {}

--- Generate a unique ID for accessibility elements
-- @param prefix string Optional prefix for the ID
-- @return string Unique ID
function utils.generate_id(prefix)
  prefix = prefix or "a11y"
  local random = math.random(100000, 999999)
  return string.format("%s-%d", prefix, random)
end

--- Escape HTML entities for safe output
-- @param str string The string to escape
-- @return string Escaped string
function utils.escape_html(str)
  if not str then
    return ""
  end

  local replacements = {
    ["&"] = "&amp;",
    ["<"] = "&lt;",
    [">"] = "&gt;",
    ['"'] = "&quot;",
    ["'"] = "&#39;",
  }

  return str:gsub("[&<>\"']", replacements)
end

--- Strip HTML tags from a string
-- @param str string The HTML string
-- @return string Plain text
function utils.strip_html(str)
  if not str then
    return ""
  end

  -- Remove HTML tags
  str = str:gsub("<[^>]+>", "")

  -- Decode common entities
  local entities = {
    ["&amp;"] = "&",
    ["&lt;"] = "<",
    ["&gt;"] = ">",
    ["&quot;"] = '"',
    ["&#39;"] = "'",
    ["&nbsp;"] = " ",
  }

  for entity, char in pairs(entities) do
    str = str:gsub(entity, char)
  end

  return str
end

--- Create screen reader only CSS class content
-- @return string CSS for screen reader only class
function utils.get_sr_only_css()
  return [[
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}

.sr-only-focusable:focus {
  position: static;
  width: auto;
  height: auto;
  padding: inherit;
  margin: inherit;
  overflow: visible;
  clip: auto;
  white-space: normal;
}
]]
end

--- Create focus visible CSS
-- @return string CSS for focus visibility
function utils.get_focus_visible_css()
  return [[
*:focus {
  outline: 2px solid #0066cc;
  outline-offset: 2px;
}

*:focus:not(:focus-visible) {
  outline: none;
}

*:focus-visible {
  outline: 2px solid #0066cc;
  outline-offset: 2px;
}
]]
end

--- Create skip link CSS
-- @return string CSS for skip links
function utils.get_skip_link_css()
  return [[
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  background: #000;
  color: #fff;
  padding: 8px 16px;
  text-decoration: none;
  z-index: 100;
}

.skip-link:focus {
  top: 0;
}
]]
end

--- Check if a string is likely to be decorative (not meaningful for SR)
-- @param text string The text to check
-- @return boolean True if decorative
function utils.is_decorative_text(text)
  if not text or text == "" then
    return true
  end

  -- Check for common decorative patterns
  local decorative_patterns = {
    "^[-=*_%.]+$",       -- Separators
    "^%s*$",              -- Whitespace only
    "^[%d%s]+$",          -- Numbers only
    "^[^%w]+$",           -- No alphanumeric chars
  }

  for _, pattern in ipairs(decorative_patterns) do
    if text:match(pattern) then
      return true
    end
  end

  return false
end

--- Normalize whitespace in text
-- @param text string The text to normalize
-- @return string Normalized text
function utils.normalize_whitespace(text)
  if not text then
    return ""
  end

  -- Collapse multiple spaces/newlines to single space
  text = text:gsub("%s+", " ")

  -- Trim leading/trailing whitespace
  text = text:gsub("^%s+", ""):gsub("%s+$", "")

  return text
end

--- Truncate text for announcements (avoid overly long SR output)
-- @param text string The text to truncate
-- @param max_length number Maximum length (default 200)
-- @return string Truncated text
function utils.truncate_for_announcement(text, max_length)
  max_length = max_length or 200

  if not text or #text <= max_length then
    return text or ""
  end

  -- Find a good break point
  local truncated = text:sub(1, max_length)
  local last_space = truncated:match(".*()%s")

  if last_space and last_space > max_length * 0.7 then
    truncated = text:sub(1, last_space - 1)
  end

  return truncated .. "..."
end

--- Create an aria-describedby ID reference from a message
-- @param prefix string ID prefix
-- @param message string The description message
-- @return table {id, html} The ID and hidden element HTML
function utils.create_description(prefix, message)
  local id = utils.generate_id(prefix .. "-desc")
  local html = string.format(
    '<span id="%s" class="sr-only">%s</span>',
    id,
    utils.escape_html(message)
  )

  return {
    id = id,
    html = html,
  }
end

--- Get accessibility metadata for export
-- @return table Accessibility metadata
function utils.get_accessibility_metadata()
  return {
    wcag_level = "AA",
    wcag_version = "2.1",
    tested_with = {
      "NVDA",
      "JAWS",
      "VoiceOver",
    },
    features = {
      "keyboard_navigation",
      "screen_reader_support",
      "focus_management",
      "aria_live_regions",
      "high_contrast_mode",
      "reduced_motion",
    },
  }
end

--- Check if a link text is descriptive enough
-- @param text string The link text
-- @return boolean True if descriptive
function utils.is_descriptive_link_text(text)
  if not text or #text < 3 then
    return false
  end

  local non_descriptive = {
    "click",
    "click here",
    "here",
    "link",
    "read more",
    "learn more",
    "more",
    "this",
  }

  local lower_text = text:lower():gsub("^%s+", ""):gsub("%s+$", "")

  for _, phrase in ipairs(non_descriptive) do
    if lower_text == phrase then
      return false
    end
  end

  return true
end

--- Create HTML for a live region container
-- @param id string The element ID
-- @param priority string "polite" or "assertive"
-- @return string HTML string
function utils.create_live_region_html(id, priority)
  return string.format(
    '<div id="%s" class="sr-only" aria-live="%s" aria-atomic="true"></div>',
    id,
    priority or "polite"
  )
end

return utils
