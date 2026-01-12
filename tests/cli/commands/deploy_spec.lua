--- Tests for deploy command

describe("Deploy Command", function()
  local DeployCommand
  
  setup(function()
    DeployCommand = require("whisker.cli.commands.deploy")
  end)
  
  it("should parse arguments", function()
    local config = DeployCommand._parse_args({"story.json", "html"})
    assert.equal("story.json", config.story_path)
    assert.equal("html", config.platform)
  end)
  
  it("should have help", function()
    assert.has_no_errors(function() DeployCommand.help() end)
  end)
end)
