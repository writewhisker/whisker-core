--- Tests for Batch Conversion Command
-- @module tests.unit.cli.test_batch_command

describe("Batch Conversion Command", function()
  local BatchCommand

  setup(function()
    BatchCommand = require("whisker.cli.commands.batch")
  end)

  describe("new", function()
    it("creates batch command with dependencies", function()
      local fs = {
        read = function() return "content" end,
        write = function() return true end,
        mkdir = function() return true end
      }
      local console = {
        print = function() end,
        write = function() end,
        error = function() end
      }

      local cmd = BatchCommand.new({file_system = fs, console = console})

      assert.is_not_nil(cmd)
      assert.equals(fs, cmd._fs)
      assert.equals(console, cmd._console)
    end)

    it("creates default dependencies when not provided", function()
      local cmd = BatchCommand.new({})

      assert.is_not_nil(cmd._fs)
      assert.is_not_nil(cmd._console)
      assert.is_function(cmd._fs.read)
      assert.is_function(cmd._fs.write)
      assert.is_function(cmd._fs.mkdir)
    end)
  end)

  describe("get_name", function()
    it("returns 'batch'", function()
      local cmd = BatchCommand.new({})
      assert.equals("batch", cmd:get_name())
    end)
  end)

  describe("get_description", function()
    it("returns description string", function()
      local cmd = BatchCommand.new({})
      local desc = cmd:get_description()

      assert.is_string(desc)
      assert.matches("batch", desc:lower())
    end)
  end)

  describe("get_options", function()
    it("returns array of option definitions", function()
      local cmd = BatchCommand.new({})
      local options = cmd:get_options()

      assert.is_table(options)
      assert.is_true(#options > 0)
    end)

    it("includes required 'from' option", function()
      local cmd = BatchCommand.new({})
      local options = cmd:get_options()

      local from_opt = nil
      for _, opt in ipairs(options) do
        if opt.name == "from" then
          from_opt = opt
          break
        end
      end

      assert.is_not_nil(from_opt)
      assert.equals("f", from_opt.short)
      assert.is_true(from_opt.required)
    end)

    it("includes required 'to' option", function()
      local cmd = BatchCommand.new({})
      local options = cmd:get_options()

      local to_opt = nil
      for _, opt in ipairs(options) do
        if opt.name == "to" then
          to_opt = opt
          break
        end
      end

      assert.is_not_nil(to_opt)
      assert.equals("t", to_opt.short)
      assert.is_true(to_opt.required)
    end)

    it("includes output-dir option", function()
      local cmd = BatchCommand.new({})
      local options = cmd:get_options()

      local found = false
      for _, opt in ipairs(options) do
        if opt.name == "output-dir" then
          found = true
          break
        end
      end

      assert.is_true(found)
    end)

    it("includes dry-run flag", function()
      local cmd = BatchCommand.new({})
      local options = cmd:get_options()

      local found = false
      for _, opt in ipairs(options) do
        if opt.name == "dry-run" and opt.flag then
          found = true
          break
        end
      end

      assert.is_true(found)
    end)
  end)

  describe("get_usage", function()
    it("returns usage help string", function()
      local cmd = BatchCommand.new({})
      local usage = cmd:get_usage()

      assert.is_string(usage)
      assert.matches("whisker batch", usage)
      assert.matches("%-f", usage)
      assert.matches("%-t", usage)
    end)
  end)

  describe("get_extension", function()
    it("returns .tw for Twine formats", function()
      local cmd = BatchCommand.new({})

      assert.equals("tw", cmd:get_extension("harlowe"))
      assert.equals("tw", cmd:get_extension("sugarcube"))
      assert.equals("tw", cmd:get_extension("chapbook"))
      assert.equals("tw", cmd:get_extension("snowman"))
    end)

    it("returns .ink for ink format", function()
      local cmd = BatchCommand.new({})
      assert.equals("ink", cmd:get_extension("ink"))
    end)

    it("returns .json for json format", function()
      local cmd = BatchCommand.new({})
      assert.equals("json", cmd:get_extension("json"))
    end)

    it("returns .txt for unknown formats", function()
      local cmd = BatchCommand.new({})
      assert.equals("txt", cmd:get_extension("unknown"))
    end)
  end)

  describe("get_output_path", function()
    it("generates output path with format suffix", function()
      local cmd = BatchCommand.new({})
      local output = cmd:get_output_path("/path/to/story.tw", {
        to = "chapbook"
      })

      assert.matches("story_chapbook%.tw$", output)
    end)

    it("uses output-dir when specified", function()
      local cmd = BatchCommand.new({})
      local output = cmd:get_output_path("/input/story.tw", {
        ["output-dir"] = "/output",
        to = "sugarcube"
      })

      assert.equals("/output/story_sugarcube.tw", output)
    end)

    it("handles files without extension", function()
      local cmd = BatchCommand.new({})
      local output = cmd:get_output_path("/path/to/story", {
        to = "json"
      })

      assert.matches("story_json%.json$", output)
    end)
  end)

  describe("show_dry_run", function()
    it("prints each file and its output path", function()
      local output = {}
      local console = {
        print = function(_, text) table.insert(output, text) end,
        write = function() end,
        error = function() end
      }
      local cmd = BatchCommand.new({console = console})

      cmd:show_dry_run({"/path/file1.tw", "/path/file2.tw"}, {
        to = "chapbook"
      })

      assert.is_true(#output >= 3)  -- header + 2 files
      assert.matches("Dry run", output[2])
    end)
  end)

  describe("print_summary", function()
    it("prints batch conversion summary", function()
      local output = {}
      local console = {
        print = function(_, text) table.insert(output, text) end,
        write = function() end,
        error = function() end
      }
      local cmd = BatchCommand.new({console = console})

      local results = {
        files = {{file = "a.tw", success = true}, {file = "b.tw", success = true}},
        success = 2,
        failed = 0,
        errors = {},
        start_time = os.time() - 5,
        end_time = os.time()
      }

      cmd:print_summary(results, {})

      local all_output = table.concat(output, "\n")
      assert.matches("Summary", all_output)
      assert.matches("Total", all_output)
      assert.matches("Successful", all_output)
    end)

    it("shows errors when present", function()
      local output = {}
      local console = {
        print = function(_, text) table.insert(output, text) end,
        write = function() end,
        error = function() end
      }
      local cmd = BatchCommand.new({console = console})

      local results = {
        files = {{file = "a.tw", success = false, error = "Parse error"}},
        success = 0,
        failed = 1,
        errors = {{file = "a.tw", error = "Parse error"}},
        start_time = os.time(),
        end_time = os.time()
      }

      cmd:print_summary(results, {})

      local all_output = table.concat(output, "\n")
      assert.matches("Error", all_output)
      assert.matches("Parse error", all_output)
    end)
  end)

  describe("save_json_summary", function()
    it("writes JSON summary to file", function()
      local written_path = nil
      local written_content = nil
      local fs = {
        read = function() return "" end,
        write = function(_, path, content)
          written_path = path
          written_content = content
          return true
        end,
        mkdir = function() return true end
      }
      local console = {
        print = function() end,
        write = function() end,
        error = function() end
      }
      local cmd = BatchCommand.new({file_system = fs, console = console})

      local results = {
        files = {{file = "test.tw", success = true}},
        success = 1,
        failed = 0,
        errors = {},
        start_time = os.time(),
        end_time = os.time()
      }

      cmd:save_json_summary(results, "/output/summary.json")

      assert.equals("/output/summary.json", written_path)
      assert.is_string(written_content)
      assert.matches('"total"', written_content)
      assert.matches('"success"', written_content)
    end)
  end)

  describe("execute", function()
    it("returns 0 when no files found", function()
      local console = {
        print = function() end,
        write = function() end,
        error = function() end
      }
      local cmd = BatchCommand.new({console = console})

      -- Mock find_files to return empty
      cmd.find_files = function() return {} end

      local exit_code = cmd:execute({"/empty/dir"}, {
        from = "harlowe",
        to = "chapbook"
      })

      assert.equals(0, exit_code)
    end)

    it("returns 0 for dry-run mode", function()
      local console = {
        print = function() end,
        write = function() end,
        error = function() end
      }
      local cmd = BatchCommand.new({console = console})

      -- Mock find_files
      cmd.find_files = function() return {"/path/file1.tw"} end

      local exit_code = cmd:execute({"/test/dir"}, {
        from = "harlowe",
        to = "chapbook",
        ["dry-run"] = true
      })

      assert.equals(0, exit_code)
    end)
  end)

  describe("convert_file", function()
    it("returns error for unreadable file", function()
      local fs = {
        read = function() return nil, "File not found" end,
        write = function() return true end,
        mkdir = function() return true end
      }
      local cmd = BatchCommand.new({file_system = fs})

      local result = cmd:convert_file("/nonexistent.tw", {
        from = "harlowe",
        to = "chapbook"
      })

      assert.is_false(result.success)
      assert.matches("Cannot read", result.error)
    end)

    it("returns error for unknown source format", function()
      local fs = {
        read = function() return ":: Start\nHello" end,
        write = function() return true end,
        mkdir = function() return true end
      }
      local cmd = BatchCommand.new({file_system = fs})

      local result = cmd:convert_file("/test.tw", {
        from = "unknownformat",
        to = "chapbook"
      })

      assert.is_false(result.success)
      assert.matches("Unknown source format", result.error)
    end)
  end)

  describe("_dependencies", function()
    it("declares required dependencies", function()
      assert.is_table(BatchCommand._dependencies)
      assert.is_true(#BatchCommand._dependencies >= 2)
    end)
  end)
end)
