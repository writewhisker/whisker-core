--- HTML Validator
-- Enhanced validation for HTML exports
-- @module whisker.export.validators.html_validator
-- @author Whisker Core Team
-- @license MIT

local HTMLValidator = {}

--- Validate HTML export bundle
-- @param bundle table Export bundle
-- @param story table Original story data
-- @return table Validation result {valid, errors, warnings}
function HTMLValidator.validate(bundle, story)
  local errors = {}
  local warnings = {}

  local html = bundle.content

  if not html or #html == 0 then
    table.insert(errors, {
      message = "HTML content is empty",
      severity = "error",
    })
    return { valid = false, errors = errors, warnings = warnings }
  end

  -- Check HTML structure
  if not html:match("<!DOCTYPE html>") then
    table.insert(warnings, {
      message = "Missing DOCTYPE declaration",
      severity = "warning",
    })
  end

  if not html:match("<html[^>]*>") then
    table.insert(errors, {
      message = "Missing <html> tag",
      severity = "error",
    })
  end

  if not html:match("<head[^>]*>") then
    table.insert(errors, {
      message = "Missing <head> tag",
      severity = "error",
    })
  end

  if not html:match("<body[^>]*>") then
    table.insert(errors, {
      message = "Missing <body> tag",
      severity = "error",
    })
  end

  if not html:match("<title>") then
    table.insert(warnings, {
      message = "Missing <title> tag",
      severity = "warning",
    })
  end

  -- Check required elements
  if not html:match("WHISKER_STORY_DATA") then
    table.insert(errors, {
      message = "Missing embedded story data",
      severity = "error",
    })
  end

  if not html:match("<script") then
    table.insert(errors, {
      message = "Missing JavaScript runtime",
      severity = "error",
    })
  end

  -- Check for viewport meta tag
  if not html:match('name="viewport"') then
    table.insert(warnings, {
      message = "Missing viewport meta tag (may affect mobile display)",
      severity = "warning",
    })
  end

  -- Check for charset
  if not html:match('charset') then
    table.insert(warnings, {
      message = "Missing charset declaration",
      severity = "warning",
    })
  end

  -- Check for broken passage references (if story provided)
  if story and story.passages then
    local passage_names = {}
    for _, passage in ipairs(story.passages) do
      passage_names[passage.name] = true
    end

    for _, passage in ipairs(story.passages) do
      local choices = passage.choices or passage.links or {}
      for _, choice in ipairs(choices) do
        local target = choice.target or choice.passage
        if target and not passage_names[target] then
          table.insert(warnings, {
            message = string.format(
              "Broken link in '%s': target '%s' does not exist",
              passage.name, target
            ),
            severity = "warning",
          })
        end
      end
    end
  end

  -- Check HTML size
  local size_kb = #html / 1024
  if size_kb > 5000 then
    table.insert(warnings, {
      message = string.format("HTML file is large (%.1f KB), consider splitting assets", size_kb),
      severity = "warning",
    })
  end

  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings,
  }
end

return HTMLValidator
