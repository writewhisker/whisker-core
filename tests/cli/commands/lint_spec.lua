--- Tests for lint command

describe("Lint Command", function()
  local LintCommand
  
  setup(function()
    LintCommand = require("whisker.cli.commands.lint")
  end)
  
  it("should parse arguments", function()
    local config = LintCommand._parse_args({"story.json"})
    assert.equal("story.json", config.story_path)
  end)
  
  it("should have help", function()
    assert.has_no_errors(function() LintCommand.help() end)
  end)
end)
