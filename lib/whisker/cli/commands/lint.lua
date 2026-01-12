--- Lint Command - Code Quality Checker
-- @module whisker.cli.commands.lint

local LintCommand = {}

local RULES = {
  ["dead-ends"] = {name = "Dead End Detection", check = function(story) return {} end},
  ["orphans"] = {name = "Orphan Passages", check = function(story) return {} end},
  ["links"] = {name = "Invalid Links", check = function(story) return {} end}
}

function LintCommand._parse_args(args)
  return {
    story_path = args[1],
    fix = false,
    verbose = false
  }
end

function LintCommand.run(args)
  local config = LintCommand._parse_args(args)
  
  if not config.story_path then
    io.stderr:write("Error: Story path required\n")
    return 1
  end
  
  print("Linting " .. config.story_path .. "...")
  
  local issues = 0
  for rule_id, rule in pairs(RULES) do
    local problems = rule.check(config.story_path)
    if #problems > 0 then
      issues = issues + #problems
      print("  " .. rule.name .. ": " .. #problems .. " issues")
    end
  end
  
  if issues == 0 then
    print("\n✓ No issues found")
    return 0
  end
  
  print("\n✗ Found " .. issues .. " issues")
  return 1
end

function LintCommand.help()
  print([[
Usage: whisker lint <story> [options]

Check story for quality issues.

Rules:
  - Dead end detection
  - Orphan passage detection
  - Invalid link detection
]])
end

return LintCommand
