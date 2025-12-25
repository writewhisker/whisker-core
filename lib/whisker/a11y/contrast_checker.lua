--- Contrast Checker
-- Validates color contrast ratios for accessibility
-- @module whisker.a11y.contrast_checker
-- @author Whisker Core Team
-- @license MIT

local ContrastChecker = {}
ContrastChecker._dependencies = {}
ContrastChecker.__index = ContrastChecker

-- WCAG contrast requirements
local WCAG_REQUIREMENTS = {
  AA = {normal = 4.5, large = 3},
  AAA = {normal = 7, large = 4.5},
}

--- Create a new ContrastChecker
-- @return ContrastChecker The new checker instance
function ContrastChecker.new(deps)
  deps = deps or {}
  local self = setmetatable({}, ContrastChecker)
  return self
end

--- Factory method for DI container
-- @return ContrastChecker
function ContrastChecker.create()
  return ContrastChecker.new()
end

--- Parse a hex color to RGB values
-- @param hex string Hex color (e.g., "#FF5733" or "FF5733")
-- @return number, number, number RGB values (0-255)
function ContrastChecker:parse_hex(hex)
  -- Remove # prefix if present
  hex = hex:gsub("^#", "")

  -- Handle 3-char hex
  if #hex == 3 then
    hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
  end

  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)

  return r, g, b
end

--- Parse an RGB string to values
-- @param rgb string RGB string (e.g., "rgb(255, 87, 51)")
-- @return number, number, number RGB values (0-255)
function ContrastChecker:parse_rgb(rgb)
  local r, g, b = rgb:match("rgb%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)")
  return tonumber(r), tonumber(g), tonumber(b)
end

--- Parse any color format to RGB
-- @param color string Hex or RGB color
-- @return number, number, number RGB values (0-255)
function ContrastChecker:parse_color(color)
  if color:match("^#") or color:match("^%x%x%x%x%x%x$") or color:match("^%x%x%x$") then
    return self:parse_hex(color)
  elseif color:match("^rgb") then
    return self:parse_rgb(color)
  else
    error("Unable to parse color: " .. color)
  end
end

--- Calculate relative luminance of a color
-- Based on WCAG 2.0 formula
-- @param r number Red (0-255)
-- @param g number Green (0-255)
-- @param b number Blue (0-255)
-- @return number Relative luminance (0-1)
function ContrastChecker:get_luminance(r, g, b)
  -- Convert to sRGB
  local function to_srgb(channel)
    local c = channel / 255
    if c <= 0.03928 then
      return c / 12.92
    else
      return ((c + 0.055) / 1.055) ^ 2.4
    end
  end

  local rs = to_srgb(r)
  local gs = to_srgb(g)
  local bs = to_srgb(b)

  return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs
end

--- Calculate contrast ratio between two colors
-- @param color1 string First color (hex or rgb)
-- @param color2 string Second color (hex or rgb)
-- @return number Contrast ratio (1-21)
function ContrastChecker:get_contrast_ratio(color1, color2)
  local r1, g1, b1 = self:parse_color(color1)
  local r2, g2, b2 = self:parse_color(color2)

  local lum1 = self:get_luminance(r1, g1, b1)
  local lum2 = self:get_luminance(r2, g2, b2)

  local lighter = math.max(lum1, lum2)
  local darker = math.min(lum1, lum2)

  return (lighter + 0.05) / (darker + 0.05)
end

--- Check if contrast meets WCAG requirements
-- @param foreground string Foreground color
-- @param background string Background color
-- @param level string "AA" or "AAA"
-- @param size string "normal" or "large"
-- @return boolean True if contrast passes
function ContrastChecker:meets_wcag(foreground, background, level, size)
  level = level or "AA"
  size = size or "normal"

  local ratio = self:get_contrast_ratio(foreground, background)
  local required = WCAG_REQUIREMENTS[level][size]

  return ratio >= required
end

--- Get the required contrast ratio for a WCAG level
-- @param level string "AA" or "AAA"
-- @param size string "normal" or "large"
-- @return number Required contrast ratio
function ContrastChecker:get_required_ratio(level, size)
  level = level or "AA"
  size = size or "normal"

  return WCAG_REQUIREMENTS[level][size]
end

--- Validate a color pair and return detailed result
-- @param foreground string Foreground color
-- @param background string Background color
-- @param level string "AA" or "AAA" (default: "AA")
-- @return table Validation result
function ContrastChecker:validate(foreground, background, level)
  level = level or "AA"

  local ratio = self:get_contrast_ratio(foreground, background)

  return {
    ratio = ratio,
    ratio_formatted = string.format("%.2f:1", ratio),
    passes_aa_normal = ratio >= WCAG_REQUIREMENTS.AA.normal,
    passes_aa_large = ratio >= WCAG_REQUIREMENTS.AA.large,
    passes_aaa_normal = ratio >= WCAG_REQUIREMENTS.AAA.normal,
    passes_aaa_large = ratio >= WCAG_REQUIREMENTS.AAA.large,
    foreground = foreground,
    background = background,
    level = level,
    passes = ratio >= WCAG_REQUIREMENTS[level].normal,
  }
end

--- Suggest a darker or lighter version of a color to improve contrast
-- @param color string The color to adjust
-- @param background string The background color
-- @param target_ratio number Target contrast ratio
-- @return string|nil Adjusted color or nil if not achievable
function ContrastChecker:suggest_adjustment(color, background, target_ratio)
  target_ratio = target_ratio or 4.5

  local r, g, b = self:parse_color(color)
  local bg_r, bg_g, bg_b = self:parse_color(background)
  local bg_lum = self:get_luminance(bg_r, bg_g, bg_b)

  -- Determine if we need to go lighter or darker
  local color_lum = self:get_luminance(r, g, b)
  local needs_darker = color_lum > bg_lum

  -- Binary search for the right adjustment
  for step = 1, 255 do
    local factor = needs_darker and (1 - step / 255) or (1 + step / 255)

    local new_r = math.min(255, math.max(0, math.floor(r * factor)))
    local new_g = math.min(255, math.max(0, math.floor(g * factor)))
    local new_b = math.min(255, math.max(0, math.floor(b * factor)))

    local new_color = string.format("#%02X%02X%02X", new_r, new_g, new_b)
    local ratio = self:get_contrast_ratio(new_color, background)

    if ratio >= target_ratio then
      return new_color
    end
  end

  return nil
end

--- Get CSS for high contrast mode support
-- @return string CSS rules
function ContrastChecker:get_high_contrast_css()
  return [[
@media (forced-colors: active) {
  * {
    background-image: none !important;
  }

  button,
  .choice-button,
  input,
  select,
  textarea {
    border: 2px solid currentColor;
  }

  *:focus {
    outline: 3px solid Highlight;
    outline-offset: 2px;
  }

  a {
    color: LinkText;
    text-decoration: underline;
  }
}

@media (prefers-contrast: more) {
  body {
    color: #000000;
    background: #FFFFFF;
  }

  button,
  .choice-button {
    border-width: 3px;
  }

  *:focus {
    outline-width: 4px;
    outline-offset: 4px;
  }
}

@media (prefers-contrast: less) {
  body {
    color: #333333;
    background: #F5F5F5;
  }
}
]]
end

--- Validate a list of color pairs
-- @param pairs table Array of {foreground, background, name} tables
-- @param level string WCAG level (default: "AA")
-- @return table Array of validation results
function ContrastChecker:validate_all(pairs, level)
  local results = {}

  for _, pair in ipairs(pairs) do
    local result = self:validate(pair.foreground, pair.background, level)
    result.name = pair.name
    table.insert(results, result)
  end

  return results
end

--- Get all failing contrast checks
-- @param pairs table Array of color pairs
-- @param level string WCAG level
-- @return table Array of failed validations
function ContrastChecker:get_failures(pairs, level)
  local all_results = self:validate_all(pairs, level)
  local failures = {}

  for _, result in ipairs(all_results) do
    if not result.passes then
      table.insert(failures, result)
    end
  end

  return failures
end

return ContrastChecker
