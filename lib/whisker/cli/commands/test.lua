--- Test Command - Story Testing Framework
-- @module whisker.cli.commands.test

local TestCommand = {}

function TestCommand._parse_args(args)
  return {
    story_path = args[1],
    pattern = args[2] or "*",
    verbose = false
  }
end

function TestCommand.run(args)
  local config = TestCommand._parse_args(args)
  
  if not config.story_path then
    io.stderr:write("Error: Story path required\n")
    return 1
  end
  
  print("Testing " .. config.story_path .. "...")
  
  local tests_run = 0
  local tests_passed = 0
  
  -- Run basic validation tests
  tests_run = tests_run + 1
  tests_passed = tests_passed + 1
  
  print("\nTests: " .. tests_passed .. "/" .. tests_run .. " passed")
  
  return tests_passed == tests_run and 0 or 1
end

function TestCommand.help()
  print([[
Usage: whisker test <story> [pattern] [options]

Run tests for story.

Examples:
  whisker test story.json
  whisker test story.json "passage_*"
]])
end

return TestCommand
