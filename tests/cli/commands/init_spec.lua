--- Tests for init command

describe("Init Command", function()
  local InitCommand
  
  setup(function()
    InitCommand = require("whisker.cli.commands.init")
  end)
  
  it("should parse arguments", function()
    local config = InitCommand._parse_args({"my-story", "--template", "tutorial"})
    assert.equal("my-story", config.name)
    assert.equal("tutorial", config.template)
  end)
  
  it("should have help", function()
    assert.has_no_errors(function() InitCommand.help() end)
  end)
end)
