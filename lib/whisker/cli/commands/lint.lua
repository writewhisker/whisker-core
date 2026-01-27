--- Lint Command - Code Quality Checker
-- @module whisker.cli.commands.lint
-- WLS 1.0 GAP-059: Uses standardized CLI formatter

local Formatter = require("lib.whisker.cli.formatter")

local LintCommand = {}

local RULES = {
  ["dead-ends"] = {
    name = "Dead End Detection",
    check = function(story)
      -- Check for passages with no outgoing links
      local issues = {}
      if story and story.passages then
        for name, passage in pairs(story.passages) do
          local has_link = false
          if passage.choices and #passage.choices > 0 then
            has_link = true
          end
          if passage.content and passage.content:match("%-%>%s*%w+") then
            has_link = true
          end
          -- Check for special ending markers
          if passage.content and (
            passage.content:match("THE END") or
            passage.content:match("<%- return") or
            passage.content:match("END$")
          ) then
            has_link = true  -- Intentional ending
          end
          if not has_link and name ~= "END" then
            table.insert(issues, {
              code = "WLS-STR-002",
              message = "Dead end passage: " .. name,
              severity = "warning",
              passage_id = name,
              suggestion = "Add choices, a link, or mark as intentional ending"
            })
          end
        end
      end
      return issues
    end
  },
  ["orphans"] = {
    name = "Orphan Passages",
    check = function(story)
      -- Check for passages not reachable from start
      local issues = {}
      if story and story.passages then
        local referenced = { [story.start_passage_name or "Start"] = true }

        -- Collect all referenced passages
        for name, passage in pairs(story.passages) do
          if passage.choices then
            for _, choice in ipairs(passage.choices) do
              if choice.target then
                referenced[choice.target] = true
              end
            end
          end
          if passage.content then
            for target in passage.content:gmatch("%-%>%s*(%w+)") do
              referenced[target] = true
            end
          end
        end

        -- Find unreferenced passages
        for name, _ in pairs(story.passages) do
          if not referenced[name] and name ~= story.start_passage_name then
            table.insert(issues, {
              code = "WLS-STR-003",
              message = "Orphan passage: " .. name,
              severity = "warning",
              passage_id = name,
              suggestion = "Add a link to this passage or remove if unused"
            })
          end
        end
      end
      return issues
    end
  },
  ["links"] = {
    name = "Invalid Links",
    check = function(story)
      -- Check for links to non-existent passages
      local issues = {}
      if story and story.passages then
        for name, passage in pairs(story.passages) do
          if passage.choices then
            for _, choice in ipairs(passage.choices) do
              if choice.target and not story.passages[choice.target] then
                if choice.target ~= "END" and choice.target ~= "RESTART" and choice.target ~= "BACK" then
                  table.insert(issues, {
                    code = "WLS-REF-001",
                    message = "Invalid link to: " .. choice.target,
                    severity = "error",
                    passage_id = name,
                    location = choice.location,
                    suggestion = "Create passage '" .. choice.target .. "' or fix the link"
                  })
                end
              end
            end
          end
        end
      end
      return issues
    end
  }
}

function LintCommand._parse_args(args)
  local config = {
    story_path = nil,
    fix = false,
    verbose = false,
    format = "plain",
    colors = true
  }

  local i = 1
  while i <= #args do
    local arg = args[i]
    if arg == "--fix" then
      config.fix = true
    elseif arg == "--verbose" or arg == "-v" then
      config.verbose = true
    elseif arg == "--format" then
      i = i + 1
      config.format = args[i]
    elseif arg == "--json" then
      config.format = "json"
      config.colors = false
    elseif arg == "--compact" then
      config.format = "compact"
    elseif arg == "--no-color" then
      config.colors = false
    elseif not arg:match("^%-") and not config.story_path then
      config.story_path = arg
    end
    i = i + 1
  end

  return config
end

function LintCommand.run(args)
  local config = LintCommand._parse_args(args)
  local formatter = Formatter.new({
    format = config.format,
    colors = config.colors,
    verbose = config.verbose
  })

  if not config.story_path then
    print(formatter:error("Story path required"))
    return 1
  end

  print(formatter:progress("Linting " .. config.story_path .. "..."))

  -- Try to load and parse the story
  local story = nil
  local WSParser = require("lib.whisker.parser.ws_parser")

  local file = io.open(config.story_path, "r")
  if not file then
    print(formatter:error("Cannot open file: " .. config.story_path))
    return 1
  end

  local content = file:read("*a")
  file:close()

  local parser = WSParser.new()
  local result = parser:parse(content)

  if not result.success then
    print(formatter:error("Parse error in story file"))
    if result.errors then
      for _, err in ipairs(result.errors) do
        local diag = type(err) == "table" and err or { message = tostring(err), severity = "error", code = "PARSE" }
        print(formatter:format_diagnostic(diag))
      end
    end
    return 1
  end

  story = result.story

  -- Collect all diagnostics
  local all_diagnostics = {}
  local error_count = 0
  local warning_count = 0

  for rule_id, rule in pairs(RULES) do
    local issues = rule.check(story)
    for _, issue in ipairs(issues) do
      table.insert(all_diagnostics, issue)
      if issue.severity == "error" then
        error_count = error_count + 1
      else
        warning_count = warning_count + 1
      end
    end
  end

  -- Add any warnings from the parser
  if result.warnings then
    for _, warn in ipairs(result.warnings) do
      local diag = type(warn) == "table" and warn or { message = tostring(warn), severity = "warning", code = "PARSE" }
      table.insert(all_diagnostics, diag)
      warning_count = warning_count + 1
    end
  end

  -- Output diagnostics
  if #all_diagnostics > 0 then
    print(formatter:format_diagnostics(all_diagnostics))
  end

  -- Print summary
  print("")
  print(formatter:format_summary(error_count, warning_count))

  return error_count == 0 and 0 or 1
end

function LintCommand.help()
  print([[
Usage: whisker lint <story> [options]

Check story for quality issues.

Options:
  --fix         Attempt to fix issues automatically (not all issues fixable)
  --verbose, -v Show more details
  --format FMT  Output format: plain, json, compact (default: plain)
  --json        Shorthand for --format json --no-color
  --compact     Shorthand for --format compact
  --no-color    Disable colored output

Rules:
  - Dead end detection (passages with no outgoing links)
  - Orphan passage detection (unreachable passages)
  - Invalid link detection (links to non-existent passages)

Examples:
  whisker lint story.ws
  whisker lint story.ws --verbose
  whisker lint story.ws --json
]])
end

return LintCommand
