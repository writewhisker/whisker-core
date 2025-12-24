--- Module Template Generator Tests
-- Tests for the new_module tool
-- @module tests.tools.new_module_spec
-- @author Whisker Core Team
-- @license MIT

describe("new_module", function()
  local generator

  setup(function()
    -- Add tools to package path
    package.path = "tools/?.lua;" .. package.path
    generator = require("new_module")
  end)

  describe("CONFIG", function()
    it("defines exit codes", function()
      assert.equal(0, generator.CONFIG.EXIT_SUCCESS)
      assert.equal(1, generator.CONFIG.EXIT_ERROR)
    end)

    it("defines directory paths", function()
      assert.equal("lib/whisker", generator.CONFIG.LIB_DIR)
      assert.equal("tests/unit", generator.CONFIG.TEST_DIR)
    end)
  end)

  describe("CATEGORIES", function()
    it("includes core categories", function()
      local found_core = false
      local found_kernel = false
      for _, c in ipairs(generator.CATEGORIES) do
        if c == "core" then found_core = true end
        if c == "kernel" then found_kernel = true end
      end
      assert.is_true(found_core)
      assert.is_true(found_kernel)
    end)
  end)

  describe("to_class_name", function()
    it("converts simple name", function()
      assert.equal("Engine", generator.to_class_name("core.engine"))
    end)

    it("converts snake_case to PascalCase", function()
      assert.equal("MyFeature", generator.to_class_name("core.my_feature"))
    end)

    it("handles multiple underscores", function()
      assert.equal("MyNewFeature", generator.to_class_name("core.my_new_feature"))
    end)

    it("handles nested path", function()
      assert.equal("Engine", generator.to_class_name("formats.ink.engine"))
    end)
  end)

  describe("to_title", function()
    it("converts simple name", function()
      assert.equal("Engine", generator.to_title("core.engine"))
    end)

    it("converts snake_case to title case", function()
      assert.equal("My Feature", generator.to_title("core.my_feature"))
    end)
  end)

  describe("is_valid_name", function()
    it("accepts lowercase names", function()
      local valid = generator.is_valid_name("engine")
      assert.is_true(valid)
    end)

    it("accepts snake_case names", function()
      local valid = generator.is_valid_name("my_feature")
      assert.is_true(valid)
    end)

    it("accepts names with numbers", function()
      local valid = generator.is_valid_name("feature2")
      assert.is_true(valid)
    end)

    it("rejects empty names", function()
      local valid, _ = generator.is_valid_name("")
      assert.is_false(valid)
    end)

    it("rejects names starting with numbers", function()
      local valid, _ = generator.is_valid_name("2feature")
      assert.is_false(valid)
    end)

    it("rejects names with uppercase", function()
      local valid, _ = generator.is_valid_name("MyFeature")
      assert.is_false(valid)
    end)

    it("rejects names with special characters", function()
      local valid, _ = generator.is_valid_name("my-feature")
      assert.is_false(valid)
    end)
  end)

  describe("is_valid_category", function()
    it("accepts valid category", function()
      assert.is_true(generator.is_valid_category("core"))
    end)

    it("rejects invalid category", function()
      assert.is_false(generator.is_valid_category("invalid"))
    end)
  end)

  describe("generate_module", function()
    it("generates module with dependencies", function()
      local content = generator.generate_module({
        class_name = "MyFeature",
        module_path = "core.my_feature",
        dependencies = { "logger", "event_bus" },
      })

      assert.is_string(content)
      assert.is_truthy(content:match("MyFeature"))
      assert.is_truthy(content:match("_dependencies"))
      assert.is_truthy(content:match("logger"))
      assert.is_truthy(content:match("event_bus"))
    end)

    it("includes create factory function", function()
      local content = generator.generate_module({
        class_name = "MyFeature",
        module_path = "core.my_feature",
        dependencies = { "logger" },
      })

      assert.is_truthy(content:match("function MyFeature.create"))
      assert.is_truthy(content:match("container:has"))
      assert.is_truthy(content:match("container:resolve"))
    end)

    it("includes new constructor", function()
      local content = generator.generate_module({
        class_name = "Test",
        module_path = "core.test",
        dependencies = {},
      })

      assert.is_truthy(content:match("function Test.new"))
    end)
  end)

  describe("generate_test", function()
    it("generates test file", function()
      local content = generator.generate_test({
        class_name = "MyFeature",
        module_path = "core.my_feature",
        dependencies = { "logger" },
      })

      assert.is_string(content)
      assert.is_truthy(content:match("describe"))
      assert.is_truthy(content:match("MyFeature"))
    end)

    it("includes mock dependencies", function()
      local content = generator.generate_test({
        class_name = "MyFeature",
        module_path = "core.my_feature",
        dependencies = { "logger", "event_bus" },
      })

      assert.is_truthy(content:match("mock_deps"))
      assert.is_truthy(content:match("logger"))
      assert.is_truthy(content:match("event_bus"))
    end)

    it("includes basic test cases", function()
      local content = generator.generate_test({
        class_name = "Test",
        module_path = "core.test",
        dependencies = {},
      })

      assert.is_truthy(content:match('describe%("new"'))
      assert.is_truthy(content:match('describe%("create"'))
    end)
  end)

  describe("main", function()
    it("shows help with --help", function()
      -- Capture stdout
      local old_print = print
      local output = {}
      _G.print = function(...)
        table.insert(output, table.concat({...}, "\t"))
      end

      local exit_code = generator.main({ "--help" })

      _G.print = old_print

      assert.equal(0, exit_code)
      assert.is_truthy(#output > 0)
    end)

    it("returns error for missing module path", function()
      -- Suppress output
      local old_stderr = io.stderr
      io.stderr = io.tmpfile()
      local old_print = print
      _G.print = function() end

      local exit_code = generator.main({})

      io.stderr = old_stderr
      _G.print = old_print

      assert.equal(1, exit_code)
    end)

    it("returns error for invalid category", function()
      local old_stderr = io.stderr
      io.stderr = io.tmpfile()

      local exit_code = generator.main({ "invalid.feature" })

      io.stderr = old_stderr

      assert.equal(1, exit_code)
    end)

    it("returns error for invalid name", function()
      local old_stderr = io.stderr
      io.stderr = io.tmpfile()

      local exit_code = generator.main({ "core.InvalidName" })

      io.stderr = old_stderr

      assert.equal(1, exit_code)
    end)
  end)
end)
