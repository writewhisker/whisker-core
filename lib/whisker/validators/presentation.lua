--- WLS 1.0 Presentation Validators
-- Validates THEME, STYLE, and rich text formatting
-- @module whisker.validators.presentation

local M = {}

local error_codes = require("whisker.validators.error_codes")

--- Create a validation issue
local function create_issue(code, context, extra)
  local def = error_codes.get_error_code(code)
  if not def then
    return nil
  end

  local issue = {
    id = (extra and extra.id) or (def.name .. '_' .. os.time()),
    code = code,
    severity = def.severity,
    category = def.category,
    message = error_codes.format_message(code, context),
    description = def.description,
    context = context,
    fixable = (extra and extra.fixable) or false,
  }

  if extra then
    for k, v in pairs(extra) do
      if k ~= 'id' and k ~= 'fixable' then
        issue[k] = v
      end
    end
  end

  return issue
end

--- Valid built-in theme names
local VALID_THEMES = {
  default = true,
  dark = true,
  classic = true,
  minimal = true,
  sepia = true,
}

--- Check if a string is a valid CSS class name
local function is_valid_css_class(str)
  -- CSS class names: start with letter, hyphen, or underscore
  -- Can contain letters, numbers, hyphens, underscores
  return str and str:match('^[a-zA-Z_%-][a-zA-Z0-9_%-]*$') ~= nil
end

--- Validate THEME directive
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_theme(story)
  local issues = {}

  if not story.theme then
    return issues
  end

  local theme_name = story.theme

  -- Check if it's a valid built-in theme or custom theme
  -- Custom themes are allowed but we warn if not a known built-in
  if not VALID_THEMES[theme_name] then
    -- It's a custom theme - just info, not error
    -- Only error if the theme name is invalid format
    if not theme_name:match('^[a-zA-Z][a-zA-Z0-9_%-]*$') then
      table.insert(issues, create_issue('WLS-PRS-004', {
        themeName = theme_name,
      }, {
        id = 'invalid_theme_' .. tostring(theme_name),
      }))
    end
  end

  return issues
end

--- Validate STYLE block properties
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_styles(story)
  local issues = {}

  if not story.styles or type(story.styles) ~= 'table' then
    return issues
  end

  -- Valid CSS custom property patterns
  local valid_properties = {
    -- Color properties
    ['--bg-color'] = true,
    ['--text-color'] = true,
    ['--accent-color'] = true,
    ['--link-color'] = true,
    ['--choice-bg'] = true,
    ['--choice-hover'] = true,
    ['--error-color'] = true,
    ['--warning-color'] = true,
    ['--success-color'] = true,
    -- Typography
    ['--font-family'] = true,
    ['--font-size'] = true,
    ['--line-height'] = true,
    ['--heading-font'] = true,
    -- Spacing
    ['--passage-padding'] = true,
    ['--choice-gap'] = true,
    ['--paragraph-margin'] = true,
    -- Standard properties (non-custom)
    ['passage-font'] = true,
    ['choice-style'] = true,
  }

  for prop, _ in pairs(story.styles) do
    -- Custom properties (--name) are always allowed
    if not prop:match('^%-%-') and not valid_properties[prop] then
      table.insert(issues, create_issue('WLS-PRS-007', {
        property = prop,
      }, {
        id = 'invalid_style_prop_' .. prop:gsub('[^%w]', '_'),
      }))
    end
  end

  return issues
end

--- Validate CSS class names in content
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_css_classes(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      -- Look for .class { or [.class patterns
      for class_name in passage.content:gmatch('%.([a-zA-Z_%-][a-zA-Z0-9_%-]*)%s*{') do
        if not is_valid_css_class(class_name) then
          table.insert(issues, create_issue('WLS-PRS-002', {
            className = class_name,
          }, {
            id = 'invalid_class_' .. passage_id .. '_' .. class_name,
            passageId = passage_id,
          }))
        end
      end

      -- Look for inline class syntax [.class
      for class_name in passage.content:gmatch('%[%.([a-zA-Z_%-][a-zA-Z0-9_%-]*)%s') do
        if not is_valid_css_class(class_name) then
          table.insert(issues, create_issue('WLS-PRS-002', {
            className = class_name,
          }, {
            id = 'invalid_inline_class_' .. passage_id .. '_' .. class_name,
            passageId = passage_id,
          }))
        end
      end
    end
  end

  return issues
end

--- Validate markdown formatting (unclosed markers)
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate_markdown(story)
  local issues = {}

  if not story.passages then
    return issues
  end

  for passage_id, passage in pairs(story.passages) do
    if passage.content then
      local content = passage.content

      -- Check for unclosed bold markers
      local bold_count = 0
      for _ in content:gmatch('%*%*') do
        bold_count = bold_count + 1
      end
      if bold_count % 2 ~= 0 then
        table.insert(issues, create_issue('WLS-PRS-006', {
          marker = '**',
        }, {
          id = 'unclosed_bold_' .. passage_id,
          passageId = passage_id,
        }))
      end

      -- Check for unclosed code markers
      local code_count = 0
      for _ in content:gmatch('`') do
        code_count = code_count + 1
      end
      if code_count % 2 ~= 0 then
        table.insert(issues, create_issue('WLS-PRS-006', {
          marker = '`',
        }, {
          id = 'unclosed_code_' .. passage_id,
          passageId = passage_id,
        }))
      end

      -- Check for deeply nested blockquotes
      local max_depth = 0
      for line in content:gmatch('[^\n]+') do
        local depth = 0
        for _ in line:gmatch('^>%s*') do
          depth = depth + 1
        end
        -- Count consecutive > at start of line
        local prefix = line:match('^([>%s]+)')
        if prefix then
          depth = select(2, prefix:gsub('>', ''))
        end
        if depth > max_depth then
          max_depth = depth
        end
      end

      if max_depth > 3 then
        table.insert(issues, create_issue('WLS-PRS-008', {
          depth = max_depth,
        }, {
          id = 'deep_blockquote_' .. passage_id,
          passageId = passage_id,
        }))
      end
    end
  end

  return issues
end

--- Run all presentation validators
-- @param story table The story to validate
-- @return table Array of validation issues
function M.validate(story)
  local all_issues = {}

  local validators = {
    M.validate_theme,
    M.validate_styles,
    M.validate_css_classes,
    M.validate_markdown,
  }

  for _, validator in ipairs(validators) do
    local issues = validator(story)
    for _, issue in ipairs(issues) do
      table.insert(all_issues, issue)
    end
  end

  return all_issues
end

return M
