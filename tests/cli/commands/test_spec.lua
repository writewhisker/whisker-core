--- Tests for test command

describe("Test Command", function()
  local TestCommand
  
  setup(function()
    TestCommand = require("whisker.cli.commands.test")
  end)
  
  it("should parse arguments", function()
    local config = TestCommand._parse_args({"story.json"})
    assert.equal("story.json", config.story_path)
  end)
  
  it("should have help", function()
    assert.has_no_errors(function() TestCommand.help() end)
  end)
end)
