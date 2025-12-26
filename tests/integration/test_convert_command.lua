-- Integration Tests for Convert Command
local ConvertCommand = require("whisker.cli.commands.convert")

describe("Convert Command Integration", function()

  local test_dir = "/tmp/whisker_convert_tests"
  local original_print = print
  local output_lines = {}

  -- Capture print output
  local function capture_print()
    output_lines = {}
    _G.print = function(...)
      local args = {...}
      local line = table.concat(args, "\t")
      table.insert(output_lines, line)
    end
  end

  -- Restore print
  local function restore_print()
    _G.print = original_print
  end

  -- Helper to write test file
  local function write_test_file(filename, content)
    local path = test_dir .. "/" .. filename
    local file = io.open(path, "w")
    if file then
      file:write(content)
      file:close()
      return path
    end
    return nil
  end

  -- Helper to read file
  local function read_file(path)
    local file = io.open(path, "r")
    if file then
      local content = file:read("*all")
      file:close()
      return content
    end
    return nil
  end

  -- Helper to check if file exists
  local function file_exists(path)
    local file = io.open(path, "r")
    if file then
      file:close()
      return true
    end
    return false
  end

  setup(function()
    os.execute("mkdir -p " .. test_dir)
  end)

  teardown(function()
    restore_print()
    os.execute("rm -rf " .. test_dir)
  end)

  describe("Harlowe to SugarCube Conversion", function()
    it("should convert Harlowe story to SugarCube", function()
      local harlowe_content = [=[
:: Start
(set: $name to "Hero")
(set: $gold to 100)

Welcome, $name!
You have $gold gold.

(if: $gold > 50)[You are rich!]

[[Go to shop->Shop]]

:: Shop
Buy items here.
[[Back->Start]]
]=]

      local input_path = write_test_file("harlowe_story.tw", harlowe_content)
      local output_path = test_dir .. "/sugarcube_output.tw"

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "sugarcube",
        "--output", output_path,
        "--quiet"
      })
      restore_print()

      assert.equals(0, exit_code)
      assert.is_true(file_exists(output_path))

      local output_content = read_file(output_path)
      assert.is_not_nil(output_content)
      assert.matches("<<set %$name", output_content)
      assert.matches("<<set %$gold", output_content)
      assert.matches("<<if", output_content)
    end)
  end)

  describe("Harlowe to Chapbook Conversion", function()
    it("should convert Harlowe story to Chapbook", function()
      local harlowe_content = [=[
:: Start
(set: $name to "Hero")
(set: $gold to 100)

Welcome, $name!
]=]

      local input_path = write_test_file("harlowe_to_chapbook.tw", harlowe_content)
      local output_path = test_dir .. "/chapbook_output.tw"

      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "chapbook",
        "--output", output_path,
        "--quiet"
      })

      assert.equals(0, exit_code)
      assert.is_true(file_exists(output_path))

      local output_content = read_file(output_path)
      assert.is_not_nil(output_content)
      -- Chapbook uses vars section with --
      assert.matches("%-%-", output_content)
      -- Chapbook uses {var} instead of $var
      assert.matches("{name}", output_content)
    end)
  end)

  describe("Format Auto-Detection", function()
    it("should auto-detect Harlowe format", function()
      local harlowe_content = [=[
:: Start
(set: $x to 5)
(print: $x)
]=]

      local input_path = write_test_file("autodetect_harlowe.tw", harlowe_content)
      local output_path = test_dir .. "/autodetect_output.tw"

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--to", "sugarcube",
        "--output", output_path
      })
      restore_print()

      assert.equals(0, exit_code)

      -- Should have auto-detected harlowe
      local detected = false
      for _, line in ipairs(output_lines) do
        if line:match("Auto%-detected format: harlowe") then
          detected = true
          break
        end
      end
      assert.is_true(detected)
    end)

    it("should auto-detect SugarCube format", function()
      local sugarcube_content = [=[
:: Start
<<set $x to 5>>
<<print $x>>
]=]

      local input_path = write_test_file("autodetect_sugarcube.tw", sugarcube_content)
      local output_path = test_dir .. "/autodetect_sc_output.tw"

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--to", "harlowe",
        "--output", output_path
      })
      restore_print()

      assert.equals(0, exit_code)

      -- Should have auto-detected sugarcube
      local detected = false
      for _, line in ipairs(output_lines) do
        if line:match("Auto%-detected format: sugarcube") then
          detected = true
          break
        end
      end
      assert.is_true(detected)
    end)
  end)

  describe("Report Generation", function()
    it("should generate report with --report flag", function()
      local harlowe_content = [=[
:: Start
(set: $x to 5)
(enchant: ?hook, (text-style: "bold"))
]=]

      local input_path = write_test_file("report_test.tw", harlowe_content)
      local output_path = test_dir .. "/report_output.tw"

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "chapbook",
        "--output", output_path,
        "--report"
      })
      restore_print()

      assert.equals(0, exit_code)

      -- Should have report output
      local has_report = false
      local has_quality = false
      for _, line in ipairs(output_lines) do
        if line:match("Conversion Report:") then has_report = true end
        if line:match("Quality score:") then has_quality = true end
      end
      assert.is_true(has_report)
      assert.is_true(has_quality)
    end)

    it("should save JSON report with --json-report flag", function()
      local harlowe_content = [=[
:: Start
(set: $x to 5)
]=]

      local input_path = write_test_file("json_report_test.tw", harlowe_content)
      local output_path = test_dir .. "/json_report_output.tw"
      local report_path = test_dir .. "/report.json"

      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "sugarcube",
        "--output", output_path,
        "--json-report", report_path,
        "--quiet"
      })

      assert.equals(0, exit_code)
      assert.is_true(file_exists(report_path))

      local report_content = read_file(report_path)
      assert.is_not_nil(report_content)
      assert.matches('"source_format"', report_content)
      assert.matches('"harlowe"', report_content)
      assert.matches('"target_format"', report_content)
      assert.matches('"sugarcube"', report_content)
    end)
  end)

  describe("Error Handling", function()
    it("should fail for non-existent file", function()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        "/nonexistent/path/story.tw",
        "--from", "harlowe",
        "--to", "sugarcube"
      })

      assert.equals(1, exit_code)
    end)

    it("should fail for same source and target format", function()
      local harlowe_content = [=[
:: Start
(set: $x to 5)
]=]

      local input_path = write_test_file("same_format.tw", harlowe_content)

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "harlowe"
      })
      restore_print()

      assert.equals(1, exit_code)
    end)
  end)

  describe("Quiet Mode", function()
    it("should suppress output with --quiet flag", function()
      local harlowe_content = [=[
:: Start
(set: $x to 5)
]=]

      local input_path = write_test_file("quiet_test.tw", harlowe_content)
      local output_path = test_dir .. "/quiet_output.tw"

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "sugarcube",
        "--output", output_path,
        "--quiet"
      })
      restore_print()

      assert.equals(0, exit_code)
      -- Should have minimal output (just the Converted: line is suppressed)
      assert.equals(0, #output_lines)
    end)
  end)

end)
