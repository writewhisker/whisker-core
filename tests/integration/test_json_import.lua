-- Integration Tests for JSON Import/Export
local ConvertCommand = require("whisker.cli.commands.convert")
local json = require("whisker.utils.json")

describe("JSON Import/Export Integration", function()

  local test_dir = "/tmp/whisker_json_tests"
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

  describe("Harlowe to JSON", function()
    it("should convert Harlowe to JSON format", function()
      local harlowe_content = [=[
:: Start
(set: $name to "Hero")
Welcome!

:: End
Goodbye!
]=]

      local input_path = write_test_file("harlowe_to_json.tw", harlowe_content)
      local output_path = test_dir .. "/output.json"

      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "harlowe",
        "--to", "json",
        "--output", output_path,
        "--quiet"
      })

      assert.equals(0, exit_code)
      assert.is_true(file_exists(output_path))

      local output_content = read_file(output_path)
      assert.is_not_nil(output_content)

      -- Verify it's valid JSON
      local parsed = json.decode(output_content)
      assert.is_not_nil(parsed)
      assert.equals("harlowe", parsed.format)
      assert.is_table(parsed.passages)
      assert.equals(2, #parsed.passages)
    end)
  end)

  describe("JSON to Harlowe", function()
    it("should convert JSON to Harlowe format", function()
      local json_story = json.encode({
        name = "Test Story",
        format = "harlowe",
        passages = {
          {name = "Start", content = "(set: $x to 5)\nHello!", tags = {}},
          {name = "End", content = "Goodbye!", tags = {}}
        }
      })

      local input_path = write_test_file("input.json", json_story)
      local output_path = test_dir .. "/harlowe_output.tw"

      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "json",
        "--to", "harlowe",
        "--output", output_path,
        "--quiet"
      })

      assert.equals(0, exit_code)
      assert.is_true(file_exists(output_path))

      local output_content = read_file(output_path)
      assert.is_not_nil(output_content)
      assert.matches(":: Start", output_content)
      assert.matches(":: End", output_content)
    end)
  end)

  describe("JSON to SugarCube", function()
    it("should convert JSON (Harlowe format) to SugarCube", function()
      local json_story = json.encode({
        name = "Test Story",
        format = "harlowe",
        passages = {
          {name = "Start", content = "(set: $x to 5)\nHello!", tags = {}}
        }
      })

      local input_path = write_test_file("json_to_sc.json", json_story)
      local output_path = test_dir .. "/sugarcube_output.tw"

      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "json",
        "--to", "sugarcube",
        "--output", output_path,
        "--quiet"
      })

      assert.equals(0, exit_code)
      assert.is_true(file_exists(output_path))

      local output_content = read_file(output_path)
      assert.is_not_nil(output_content)
      -- Should have SugarCube syntax
      assert.matches("<<set", output_content)
    end)
  end)

  describe("JSON Auto-Detection", function()
    it("should auto-detect JSON format", function()
      local json_story = json.encode({
        name = "Auto-Detect Test",
        format = "harlowe",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      })

      local input_path = write_test_file("autodetect.json", json_story)
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

      -- Should have auto-detected json
      local detected = false
      for _, line in ipairs(output_lines) do
        if line:match("Auto%-detected format: json") then
          detected = true
          break
        end
      end
      assert.is_true(detected)
    end)
  end)

  describe("Round Trip", function()
    it("should preserve data through Harlowe -> JSON -> Harlowe", function()
      local harlowe_content = [=[
:: Start
(set: $name to "Hero")
Welcome, $name!

:: Shop
Buy items here.
]=]

      local input_path = write_test_file("roundtrip_start.tw", harlowe_content)
      local json_path = test_dir .. "/roundtrip.json"
      local output_path = test_dir .. "/roundtrip_end.tw"

      -- Step 1: Harlowe -> JSON
      local cmd1 = ConvertCommand.new()
      local exit1 = cmd1:execute({
        input_path,
        "--from", "harlowe",
        "--to", "json",
        "--output", json_path,
        "--quiet"
      })
      assert.equals(0, exit1)

      -- Step 2: JSON -> Harlowe
      local cmd2 = ConvertCommand.new()
      local exit2 = cmd2:execute({
        json_path,
        "--from", "json",
        "--to", "harlowe",
        "--output", output_path,
        "--quiet"
      })
      assert.equals(0, exit2)

      -- Verify round trip preserved structure
      local output_content = read_file(output_path)
      assert.matches(":: Start", output_content)
      assert.matches(":: Shop", output_content)
      assert.matches("%(set:", output_content)
    end)
  end)

  describe("Error Handling", function()
    it("should fail for invalid JSON", function()
      local input_path = write_test_file("invalid.json", "not valid json {")

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "json",
        "--to", "harlowe"
      })
      restore_print()

      assert.equals(1, exit_code)
    end)

    it("should fail for JSON missing required fields", function()
      local json_content = json.encode({
        -- missing name and passages
        something = "else"
      })

      local input_path = write_test_file("missing_fields.json", json_content)

      capture_print()
      local cmd = ConvertCommand.new()
      local exit_code = cmd:execute({
        input_path,
        "--from", "json",
        "--to", "harlowe"
      })
      restore_print()

      assert.equals(1, exit_code)
    end)
  end)

end)
