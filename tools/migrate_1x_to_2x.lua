#!/usr/bin/env lua
--- WLS 1.x to 2.0 Migration Tool
-- Migrates stories from WLS 1.x format to WLS 2.0 format.
--
-- @module tools.migrate_1x_to_2x
-- @author Whisker Team
-- @license MIT

local M = {}

-- Dependencies for DI pattern
M._dependencies = {}

--- Migration change types
M.CHANGE_TYPES = {
  RENAME = "rename",
  SYNTAX = "syntax",
  RESERVED_WORD = "reserved_word",
  DEPRECATION = "deprecation",
}

--- Reserved words in WLS 2.0 that must be renamed
M.RESERVED_WORDS = {
  "thread",
  "await",
  "spawn",
  "sync",
  "channel",
  "timer",
  "effect",
  "audio",
  "external",
}

--- Deprecated patterns that need attention
M.DEPRECATED_PATTERNS = {
  { pattern = "<%s*script%s*>", description = "Legacy <script> blocks deprecated in 2.0" },
  { pattern = "{{#if%s", description = "Legacy {{#if}} blocks, use @if directive instead" },
  { pattern = "{{#each%s", description = "Legacy {{#each}} blocks, use @list directive instead" },
}

--- Migrate reserved word variable names
-- @tparam string content Source content
-- @tparam table changes Changes table to append to
-- @treturn string Modified content
local function migrate_reserved_words(content, changes)
  local result = content

  for _, word in ipairs(M.RESERVED_WORDS) do
    -- Pattern: $word at word boundary (followed by non-word char or end of string)
    -- Also handle ${word} syntax
    local patterns = {
      { find = "%$" .. word .. "([^%w_])", replace = "$_" .. word .. "%1" },
      { find = "%$" .. word .. "$", replace = "$_" .. word },  -- End of string
      { find = "%${" .. word .. "}", replace = "${_" .. word .. "}" },
      { find = '"%$' .. word .. '"', replace = '"$_' .. word .. '"' },
    }

    for _, p in ipairs(patterns) do
      local before = result
      result = result:gsub(p.find, p.replace)
      if result ~= before then
        local count = 0
        for _ in before:gmatch(p.find) do
          count = count + 1
        end
        table.insert(changes, {
          type = M.CHANGE_TYPES.RESERVED_WORD,
          line = 0,  -- Line numbers are approximations
          original = "$" .. word,
          replacement = "$_" .. word,
          reason = string.format("'%s' is reserved in WLS 2.0", word),
          count = count,
        })
      end
    end
  end

  return result
end

--- Check for deprecated patterns and add warnings
-- @tparam string content Source content
-- @tparam table warnings Warnings table to append to
local function check_deprecated_patterns(content, warnings)
  for _, deprecated in ipairs(M.DEPRECATED_PATTERNS) do
    if content:match(deprecated.pattern) then
      local count = 0
      for _ in content:gmatch(deprecated.pattern) do
        count = count + 1
      end
      table.insert(warnings, {
        message = deprecated.description,
        count = count,
      })
    end
  end
end

--- Check for tunnel usage that might interact with threads
-- @tparam string content Source content
-- @tparam table warnings Warnings table to append to
local function check_tunnel_interactions(content, warnings)
  -- Check for tunnel syntax: ->-> (consecutive) or -> -> (with space)
  -- Use explicit patterns to avoid false positives with regular links
  local has_tunnel = false

  -- Pattern 1: ->-> (no space)
  if content:find("%-%>%-%>") then
    has_tunnel = true
  end

  -- Pattern 2: -> -> (with spaces)
  if content:find("%-%>%s+%-%>") then
    has_tunnel = true
  end

  if has_tunnel then
    table.insert(warnings, {
      message = "Story uses tunnels (->->) - review thread interactions carefully",
      severity = "review",
    })
  end
end

--- Check for complex conditional structures
-- @tparam string content Source content
-- @tparam table warnings Warnings table to append to
local function check_complex_conditions(content, warnings)
  -- Count nested conditionals
  local if_count = 0
  for _ in content:gmatch("@if%s") do
    if_count = if_count + 1
  end
  for _ in content:gmatch("{%%if%s") do
    if_count = if_count + 1
  end

  if if_count > 20 then
    table.insert(warnings, {
      message = string.format("Story has %d conditionals - consider using LIST state machines in 2.0", if_count),
      severity = "suggestion",
    })
  end
end

--- Migrate directive syntax from 1.x to 2.0
-- @tparam string content Source content
-- @tparam table changes Changes table to append to
-- @treturn string Modified content
local function migrate_directive_syntax(content, changes)
  local result = content

  -- WLS 1.x used {%directive%}, 2.0 uses @directive
  -- Example: {%note%} -> @note
  local directive_pattern = "{%%(%w+)%%}"
  for directive in content:gmatch(directive_pattern) do
    local old = "{%" .. directive .. "%}"
    local new = "@" .. directive
    result = result:gsub("{%%" .. directive .. "%%}", "@" .. directive)
    table.insert(changes, {
      type = M.CHANGE_TYPES.SYNTAX,
      line = 0,
      original = old,
      replacement = new,
      reason = "Directive syntax updated to @ prefix in WLS 2.0",
    })
  end

  return result
end

--- Migrate passage header syntax
-- @tparam string content Source content
-- @tparam table changes Changes table to append to
-- @treturn string Modified content
local function migrate_passage_headers(content, changes)
  local result = content

  -- WLS 1.x allowed tags in brackets after passage name
  -- WLS 2.0 uses @tag directive
  -- Example: :: PassageName [tag1 tag2] -> :: PassageName\n@tags tag1 tag2

  local header_pattern = "^::([^\n%[]+)%[([^%]]+)%]"
  local modified = false

  result = result:gsub("(::)([^\n%[]+)%[([^%]]+)%]\n", function(prefix, name, tags)
    modified = true
    -- Trim whitespace from name
    name = name:match("^%s*(.-)%s*$")
    return prefix .. " " .. name .. "\n@tags " .. tags .. "\n"
  end)

  if modified then
    table.insert(changes, {
      type = M.CHANGE_TYPES.SYNTAX,
      line = 0,
      original = ":: PassageName [tags]",
      replacement = ":: PassageName\\n@tags tags",
      reason = "Passage tags moved to @tags directive in WLS 2.0",
    })
  end

  return result
end

--- Perform full migration
-- @tparam string source Source content
-- @treturn table Migration result {content, changes, warnings}
function M.migrate(source)
  local changes = {}
  local warnings = {}
  local content = source

  -- Step 1: Migrate reserved words
  content = migrate_reserved_words(content, changes)

  -- Step 2: Migrate directive syntax
  content = migrate_directive_syntax(content, changes)

  -- Step 3: Migrate passage headers
  content = migrate_passage_headers(content, changes)

  -- Step 4: Check for deprecated patterns
  check_deprecated_patterns(content, warnings)

  -- Step 5: Check for tunnel interactions
  check_tunnel_interactions(content, warnings)

  -- Step 6: Check for complex conditions
  check_complex_conditions(content, warnings)

  -- Add WLS 2.0 header comment if changes were made
  if #changes > 0 then
    local header = "// Migrated to WLS 2.0 using migrate_1x_to_2x.lua\n"
    if not content:match("^// Migrated to WLS 2%.0") then
      content = header .. content
    end
  end

  return {
    content = content,
    changes = changes,
    warnings = warnings,
    original_length = #source,
    migrated_length = #content,
  }
end

--- Read a file
-- @tparam string path File path
-- @treturn string|nil Content or nil
-- @treturn string|nil Error message if failed
local function read_file(path)
  local file, err = io.open(path, "r")
  if not file then
    return nil, err
  end
  local content = file:read("*a")
  file:close()
  return content
end

--- Write a file
-- @tparam string path File path
-- @tparam string content Content to write
-- @treturn boolean Success
-- @treturn string|nil Error message if failed
local function write_file(path, content)
  local file, err = io.open(path, "w")
  if not file then
    return false, err
  end
  file:write(content)
  file:close()
  return true
end

--- Generate migration report
-- @tparam table result Migration result
-- @treturn string Report text
function M.generate_report(result)
  local lines = {}

  table.insert(lines, "WLS 1.x to 2.0 Migration Report")
  table.insert(lines, string.rep("=", 40))
  table.insert(lines, "")

  table.insert(lines, string.format("Original size: %d characters", result.original_length))
  table.insert(lines, string.format("Migrated size: %d characters", result.migrated_length))
  table.insert(lines, "")

  if #result.changes > 0 then
    table.insert(lines, string.format("Changes: %d", #result.changes))
    table.insert(lines, string.rep("-", 40))
    for _, change in ipairs(result.changes) do
      local count_str = change.count and string.format(" (%dx)", change.count) or ""
      table.insert(lines, string.format("  [%s] %s -> %s%s",
        change.type,
        change.original,
        change.replacement,
        count_str
      ))
      table.insert(lines, string.format("         %s", change.reason))
    end
    table.insert(lines, "")
  else
    table.insert(lines, "No changes required.")
    table.insert(lines, "")
  end

  if #result.warnings > 0 then
    table.insert(lines, string.format("Warnings: %d", #result.warnings))
    table.insert(lines, string.rep("-", 40))
    for _, warning in ipairs(result.warnings) do
      local count_str = warning.count and string.format(" (%d occurrences)", warning.count) or ""
      local severity = warning.severity or "warning"
      table.insert(lines, string.format("  [%s] %s%s", severity, warning.message, count_str))
    end
    table.insert(lines, "")
  end

  if #result.changes == 0 and #result.warnings == 0 then
    table.insert(lines, "Story is already WLS 2.0 compatible!")
  elseif #result.changes > 0 and #result.warnings == 0 then
    table.insert(lines, "Migration complete - no manual review required.")
  else
    table.insert(lines, "Migration complete - please review warnings above.")
  end

  return table.concat(lines, "\n")
end

--- CLI entry point
function M.main(args)
  args = args or arg

  if not args or #args < 1 then
    print("Usage: lua migrate_1x_to_2x.lua <input.ws> [output.ws]")
    print("")
    print("Migrates a WLS 1.x story file to WLS 2.0 format.")
    print("")
    print("Options:")
    print("  input.ws    Input story file (required)")
    print("  output.ws   Output file (default: input.2x.ws)")
    print("")
    print("Example:")
    print("  lua migrate_1x_to_2x.lua story.ws")
    print("  lua migrate_1x_to_2x.lua story.ws story-v2.ws")
    return 1
  end

  local input_path = args[1]
  local output_path = args[2] or input_path:gsub("%.ws$", ".2x.ws")

  -- Handle case where input doesn't end in .ws
  if output_path == input_path then
    output_path = input_path .. ".2x"
  end

  -- Read input file
  local source, err = read_file(input_path)
  if not source then
    print("Error reading file: " .. tostring(err))
    return 2
  end

  -- Perform migration
  local result = M.migrate(source)

  -- Generate and print report
  local report = M.generate_report(result)
  print(report)
  print("")

  -- Write output file
  local success, write_err = write_file(output_path, result.content)
  if not success then
    print("Error writing file: " .. tostring(write_err))
    return 2
  end

  print(string.format("Written to: %s", output_path))
  return 0
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("migrate_1x_to_2x%.lua$") then
  os.exit(M.main(arg))
end

return M
