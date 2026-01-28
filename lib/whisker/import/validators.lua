--- Import Validators
-- Validation and auto-fix for imported stories
--
-- @module whisker.import.validators
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Validators = require("whisker.import.validators")
-- local report = Validators.validate(story, { auto_fix = true })

local Validators = {}

--- Validation severity levels
Validators.Severity = {
  CRITICAL = "critical",  -- Must fix
  ERROR = "error",        -- Should fix
  WARNING = "warning",    -- May fix
  INFO = "info"           -- Informational
}

--- Validate imported story
-- @param story table Story data
-- @param options table Validation options
-- @param options.auto_fix boolean Auto-fix issues (default: false)
-- @param options.strict boolean Strict mode - no auto-fix (default: false)
-- @return table report Validation report
function Validators.validate(story, options)
  options = options or {}
  
  local report = {
    valid = true,
    issues = {},
    fixed = {},
    story = story
  }
  
  -- Run all validators
  Validators.check_required_fields(story, report, options)
  Validators.check_passages(story, report, options)
  Validators.check_links(story, report, options)
  Validators.check_variables(story, report, options)
  Validators.check_metadata(story, report, options)
  Validators.check_encoding(story, report, options)
  Validators.check_ids(story, report, options)
  
  -- Determine overall validity
  for _, issue in ipairs(report.issues) do
    if issue.severity == Validators.Severity.CRITICAL or 
       issue.severity == Validators.Severity.ERROR then
      report.valid = false
      break
    end
  end
  
  return report
end

--- Add issue to report
-- @param report table Validation report
-- @param severity string Issue severity
-- @param message string Issue message
-- @param location string Location of issue
-- @param suggestion string|nil Suggestion for fix
local function add_issue(report, severity, message, location, suggestion)
  table.insert(report.issues, {
    severity = severity,
    message = message,
    location = location or "unknown",
    suggestion = suggestion
  })
end

--- Record fix applied
-- @param report table Validation report
-- @param description string Fix description
local function record_fix(report, description)
  table.insert(report.fixed, description)
end

--- Check required fields
function Validators.check_required_fields(story, report, options)
  if not story.passages then
    add_issue(report, Validators.Severity.CRITICAL,
      "Story missing passages array",
      "story.passages",
      "Add passages array to story")
    
    if options.auto_fix and not options.strict then
      story.passages = {}
      record_fix(report, "Created empty passages array")
    end
  end
  
  if not story.metadata then
    add_issue(report, Validators.Severity.ERROR,
      "Story missing metadata",
      "story.metadata",
      "Add metadata with at least a title")
    
    if options.auto_fix and not options.strict then
      story.metadata = { title = "Untitled" }
      record_fix(report, "Created default metadata")
    end
  end
end

--- Check passages for issues
function Validators.check_passages(story, report, options)
  if not story.passages or type(story.passages) ~= "table" then
    return
  end
  
  if #story.passages == 0 then
    add_issue(report, Validators.Severity.CRITICAL,
      "Story has no passages",
      "story.passages",
      "Import must have at least one passage")
    return
  end
  
  for i, passage in ipairs(story.passages) do
    local location = string.format("passages[%d]", i)
    
    -- Check for required passage fields
    if not passage.id and not passage.name then
      add_issue(report, Validators.Severity.CRITICAL,
        "Passage missing both id and name",
        location,
        "Passage must have id or name")
      
      if options.auto_fix and not options.strict then
        passage.id = string.format("passage-%d", i)
        passage.name = passage.id
        record_fix(report, string.format("Generated ID for passage %d", i))
      end
    elseif not passage.id then
      -- Has name but no ID
      if options.auto_fix and not options.strict then
        passage.id = passage.name
        record_fix(report, string.format("Set passage ID from name: %s", passage.name))
      end
    elseif not passage.name then
      -- Has ID but no name
      if options.auto_fix and not options.strict then
        passage.name = passage.id
        record_fix(report, string.format("Set passage name from ID: %s", passage.id))
      end
    end
    
    -- Check content
    if not passage.content or passage.content == "" then
      add_issue(report, Validators.Severity.WARNING,
        string.format("Passage '%s' has no content", passage.id or i),
        location .. ".content",
        "Add content or remove empty passage")
    end
    
    -- Check for invalid characters in ID
    if passage.id and passage.id:match("[^%w%-_]") then
      add_issue(report, Validators.Severity.WARNING,
        string.format("Passage ID '%s' contains special characters", passage.id),
        location .. ".id",
        "Use only alphanumeric, dash, and underscore")
    end
  end
end

--- Check links and connections
function Validators.check_links(story, report, options)
  if not story.passages then
    return
  end
  
  -- Build map of passage IDs
  local passage_map = {}
  for _, passage in ipairs(story.passages) do
    if passage.id then
      passage_map[passage.id] = passage
    end
    if passage.name and passage.name ~= passage.id then
      passage_map[passage.name] = passage
    end
  end
  
  -- Check each passage's links
  for i, passage in ipairs(story.passages) do
    repeat
      if not passage.choices then
        break
      end

      for j, choice in ipairs(passage.choices) do
        local location = string.format("passages[%d].choices[%d]", i, j)

        if not choice.target then
          add_issue(report, Validators.Severity.ERROR,
            string.format("Choice in passage '%s' has no target", passage.id or i),
            location,
            "Add target passage ID or remove choice")
        elseif not passage_map[choice.target] then
          add_issue(report, Validators.Severity.ERROR,
            string.format("Broken link: '%s' -> '%s'", passage.id or i, choice.target),
            location,
            "Create missing passage or fix target")

          if options.auto_fix and not options.strict then
            -- Create placeholder passage
            local placeholder = {
              id = choice.target,
              name = choice.target,
              content = string.format("(Placeholder for '%s')", choice.target),
              tags = {"placeholder", "auto-generated"}
            }
            table.insert(story.passages, placeholder)
            passage_map[choice.target] = placeholder
            record_fix(report, string.format("Created placeholder passage for '%s'", choice.target))
          end
        end
      end
    until true
  end
end

--- Check variables
function Validators.check_variables(story, report, options)
  if not story.variables then
    return
  end
  
  for name, value in pairs(story.variables) do
    local location = string.format("variables['%s']", name)
    
    -- Check for invalid variable names
    if not name:match("^[%a_][%w_]*$") then
      add_issue(report, Validators.Severity.WARNING,
        string.format("Variable name '%s' is not a valid identifier", name),
        location,
        "Use only letters, numbers, and underscores (start with letter)")
    end
    
    -- Check for reserved names
    local reserved = {"if", "then", "else", "end", "function", "local", "return"}
    for _, keyword in ipairs(reserved) do
      if name == keyword then
        add_issue(report, Validators.Severity.ERROR,
          string.format("Variable name '%s' is a reserved keyword", name),
          location,
          "Rename to avoid conflict")
        break
      end
    end
  end
end

--- Check metadata
function Validators.check_metadata(story, report, options)
  if not story.metadata then
    return
  end
  
  -- Check title
  if not story.metadata.title or story.metadata.title == "" then
    add_issue(report, Validators.Severity.WARNING,
      "Story has no title",
      "metadata.title",
      "Add a descriptive title")
    
    if options.auto_fix and not options.strict then
      story.metadata.title = "Untitled Story"
      record_fix(report, "Set default title")
    end
  end
  
  -- Check for very long title
  if story.metadata.title and #story.metadata.title > 100 then
    add_issue(report, Validators.Severity.WARNING,
      "Story title is very long (>100 characters)",
      "metadata.title",
      "Consider shortening the title")
  end
end

--- Check character encoding
function Validators.check_encoding(story, report, options)
  -- Check for common encoding issues in passages
  if not story.passages then
    return
  end
  
  for i, passage in ipairs(story.passages) do
    repeat
      if not passage.content then
        break
      end

      local location = string.format("passages[%d].content", i)

      -- Check for null bytes
      if passage.content:match("\0") then
        add_issue(report, Validators.Severity.ERROR,
          string.format("Passage '%s' contains null bytes", passage.id or i),
          location,
          "Remove null bytes from content")

        if options.auto_fix and not options.strict then
          passage.content = passage.content:gsub("\0", "")
          record_fix(report, string.format("Removed null bytes from passage '%s'", passage.id or i))
        end
      end

      -- Check for invalid UTF-8 (simple check)
      -- Note: This is a basic check, proper UTF-8 validation is more complex
      -- Use string.char for Lua 5.1/LuaJIT compatibility (no \xNN syntax)
      local invalid_utf8_pattern = "[" .. string.char(0x80) .. "-" .. string.char(0xFF) .. "][" .. string.char(0x00) .. "-" .. string.char(0x7F) .. "]"
      if passage.content:match(invalid_utf8_pattern) then
        add_issue(report, Validators.Severity.WARNING,
          string.format("Passage '%s' may have encoding issues", passage.id or i),
          location,
          "Check character encoding (should be UTF-8)")
      end
    until true
  end
end

--- Check for duplicate IDs
function Validators.check_ids(story, report, options)
  if not story.passages then
    return
  end
  
  local seen_ids = {}
  local duplicates = {}
  
  for i, passage in ipairs(story.passages) do
    if passage.id then
      if seen_ids[passage.id] then
        table.insert(duplicates, {
          id = passage.id,
          index = i,
          first_index = seen_ids[passage.id]
        })
      else
        seen_ids[passage.id] = i
      end
    end
  end
  
  for _, dup in ipairs(duplicates) do
    local location = string.format("passages[%d].id", dup.index)
    add_issue(report, Validators.Severity.CRITICAL,
      string.format("Duplicate passage ID: '%s' (also at index %d)", dup.id, dup.first_index),
      location,
      "Make passage IDs unique")
    
    if options.auto_fix and not options.strict then
      local new_id = string.format("%s-%d", dup.id, dup.index)
      story.passages[dup.index].id = new_id
      record_fix(report, string.format("Renamed duplicate ID '%s' to '%s'", dup.id, new_id))
    end
  end
end

--- Sanitize content
-- Remove potentially harmful content
-- @param content string Content to sanitize
-- @return string sanitized Sanitized content
function Validators.sanitize_content(content)
  if not content then
    return ""
  end
  
  -- Remove script tags
  content = content:gsub("<script[^>]*>.-</script>", "")
  
  -- Remove null bytes
  content = content:gsub("\0", "")
  
  -- Normalize whitespace
  content = content:gsub("\r\n", "\n")
  content = content:gsub("\r", "\n")
  
  return content
end

--- Generate validation summary
-- @param report table Validation report
-- @return string summary Human-readable summary
function Validators.get_summary(report)
  local lines = {}
  
  -- Count issues by severity
  local counts = {
    critical = 0,
    error = 0,
    warning = 0,
    info = 0
  }
  
  for _, issue in ipairs(report.issues) do
    counts[issue.severity] = (counts[issue.severity] or 0) + 1
  end
  
  -- Build summary
  table.insert(lines, string.format("Validation %s", report.valid and "PASSED" or "FAILED"))
  table.insert(lines, string.format("  Critical: %d", counts.critical))
  table.insert(lines, string.format("  Errors: %d", counts.error))
  table.insert(lines, string.format("  Warnings: %d", counts.warning))
  table.insert(lines, string.format("  Info: %d", counts.info))
  
  if #report.fixed > 0 then
    table.insert(lines, string.format("  Auto-fixed: %d", #report.fixed))
  end
  
  return table.concat(lines, "\n")
end

return Validators
