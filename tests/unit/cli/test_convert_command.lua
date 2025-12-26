-- Tests for Convert CLI Command
local ConvertCommand = require("whisker.cli.commands.convert")

describe("Convert Command", function()

  describe("Command Metadata", function()
    it("should have correct name", function()
      local cmd = ConvertCommand.new()
      assert.equals("convert", cmd:get_name())
    end)

    it("should have a description", function()
      local cmd = ConvertCommand.new()
      assert.is_string(cmd:get_description())
      assert.is_true(#cmd:get_description() > 0)
    end)

    it("should have options defined", function()
      local cmd = ConvertCommand.new()
      local options = cmd:get_options()
      assert.is_table(options)
      assert.is_true(#options > 0)
    end)

    it("should have required options", function()
      local cmd = ConvertCommand.new()
      local options = cmd:get_options()

      local has_from = false
      local has_to = false
      local has_output = false
      local has_report = false

      for _, opt in ipairs(options) do
        if opt.name == "from" then has_from = true end
        if opt.name == "to" then has_to = true end
        if opt.name == "output" then has_output = true end
        if opt.name == "report" then has_report = true end
      end

      assert.is_true(has_from)
      assert.is_true(has_to)
      assert.is_true(has_output)
      assert.is_true(has_report)
    end)
  end)

  describe("Format Validation", function()
    local cmd = ConvertCommand.new()

    it("should accept valid formats", function()
      assert.is_true(cmd:validate_format("harlowe"))
      assert.is_true(cmd:validate_format("sugarcube"))
      assert.is_true(cmd:validate_format("chapbook"))
      assert.is_true(cmd:validate_format("snowman"))
    end)

    it("should accept formats case-insensitively", function()
      assert.is_true(cmd:validate_format("HARLOWE"))
      assert.is_true(cmd:validate_format("SugarCube"))
      assert.is_true(cmd:validate_format("ChApBoOk"))
    end)

    it("should reject invalid formats", function()
      assert.is_false(cmd:validate_format("invalid"))
      assert.is_false(cmd:validate_format("twine"))
      assert.is_false(cmd:validate_format(""))
    end)

    it("should reject nil format", function()
      assert.is_false(cmd:validate_format(nil))
    end)
  end)

  describe("Format Detection", function()
    local cmd = ConvertCommand.new()

    it("should detect Harlowe format", function()
      local content = [=[
:: Start
(set: $name to "Hero")
(if: $gold > 0)[You have gold]
]=]
      assert.equals("harlowe", cmd:detect_format_from_content(content))
    end)

    it("should detect SugarCube format", function()
      local content = [=[
:: Start
<<set $name to "Hero">>
<<if $gold > 0>>You have gold<</if>>
]=]
      assert.equals("sugarcube", cmd:detect_format_from_content(content))
    end)

    it("should detect Chapbook format", function()
      local content = [=[
:: Start
name: "Hero"
gold: 100
--
Welcome, {name}!
]=]
      assert.equals("chapbook", cmd:detect_format_from_content(content))
    end)

    it("should detect Snowman format", function()
      local content = [=[
:: Start
<% s.name = "Hero"; %>
Welcome, <%= s.name %>!
]=]
      assert.equals("snowman", cmd:detect_format_from_content(content))
    end)

    it("should return nil for unrecognized content", function()
      local content = "Just plain text with no format markers"
      assert.is_nil(cmd:detect_format_from_content(content))
    end)
  end)

  describe("Command Execution", function()
    local cmd = ConvertCommand.new()

    it("should return 0 for --help", function()
      local exit_code = cmd:execute({"--help"})
      assert.equals(0, exit_code)
    end)

    it("should return 1 when no input file specified", function()
      local exit_code = cmd:execute({})
      assert.equals(1, exit_code)
    end)

    it("should return 1 when no target format specified", function()
      local exit_code = cmd:execute({"story.tw"})
      assert.equals(1, exit_code)
    end)

    it("should return 1 for invalid target format", function()
      local exit_code = cmd:execute({"story.tw", "--to", "invalid"})
      assert.equals(1, exit_code)
    end)

    it("should return 1 for invalid source format", function()
      local exit_code = cmd:execute({"story.tw", "--from", "invalid", "--to", "harlowe"})
      assert.equals(1, exit_code)
    end)
  end)

  describe("Help Flag", function()
    it("should support -h short flag", function()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({"-h"})
      assert.equals(0, exit_code)
    end)

    it("should support --help long flag", function()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({"--help"})
      assert.equals(0, exit_code)
    end)
  end)

end)
