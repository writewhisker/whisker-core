-- spec/formats/ink/format_spec.lua
-- Tests for InkFormat IFormat implementation

describe("InkFormat", function()
  local InkFormat

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end
    InkFormat = require("whisker.formats.ink.format")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(InkFormat._whisker)
      assert.are.equal("InkFormat", InkFormat._whisker.name)
      assert.are.equal("IFormat", InkFormat._whisker.implements)
    end)

    it("should have format name and version", function()
      assert.are.equal("ink", InkFormat.name)
      assert.is_string(InkFormat.version)
    end)

    it("should have extensions list", function()
      assert.is_table(InkFormat.extensions)
      assert.truthy(#InkFormat.extensions > 0)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local format = InkFormat.new()
      assert.is_table(format)
    end)

    it("should accept options", function()
      local emitter = { emit = function() end }
      local format = InkFormat.new({ event_emitter = emitter })
      assert.is_table(format)
    end)
  end)

  describe("can_import", function()
    it("should return true for valid Ink JSON string", function()
      local format = InkFormat.new()
      local json_str = '{"inkVersion": 21, "root": [], "listDefs": {}}'
      assert.is_true(format:can_import(json_str))
    end)

    it("should return true for valid Ink JSON table", function()
      local format = InkFormat.new()
      local data = {
        inkVersion = 21,
        root = {},
        listDefs = {}
      }
      assert.is_true(format:can_import(data))
    end)

    it("should return true for existing .json file path", function()
      local format = InkFormat.new()
      -- This file was created in Stage 03
      assert.is_true(format:can_import("test/fixtures/ink/minimal.json"))
    end)

    it("should return false for nil", function()
      local format = InkFormat.new()
      assert.is_false(format:can_import(nil))
    end)

    it("should return false for non-Ink JSON", function()
      local format = InkFormat.new()
      local json_str = '{"name": "not ink", "content": "something"}'
      assert.is_false(format:can_import(json_str))
    end)

    it("should return false for non-existent file", function()
      local format = InkFormat.new()
      assert.is_false(format:can_import("non_existent.ink.json"))
    end)

    it("should return false for invalid types", function()
      local format = InkFormat.new()
      assert.is_false(format:can_import(123))
      assert.is_false(format:can_import(true))
    end)
  end)

  describe("import", function()
    it("should import from JSON string", function()
      local format = InkFormat.new()
      local json_str = '{"inkVersion": 21, "root": ["^Hello"], "listDefs": {}}'

      local result, err = format:import(json_str)
      assert.is_nil(err)
      assert.is_table(result)
      assert.are.equal(21, result.inkVersion)
    end)

    it("should import from table", function()
      local format = InkFormat.new()
      local data = {
        inkVersion = 21,
        root = {"^Hello"},
        listDefs = {}
      }

      local result, err = format:import(data)
      assert.is_nil(err)
      assert.is_table(result)
      assert.are.equal(21, result.inkVersion)
    end)

    it("should import from file path", function()
      local format = InkFormat.new()

      local result, err = format:import("test/fixtures/ink/minimal.json")
      assert.is_nil(err)
      assert.is_table(result)
      assert.are.equal(21, result.inkVersion)
    end)

    it("should return error for nil source", function()
      local format = InkFormat.new()

      local result, err = format:import(nil)
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should return error for invalid JSON", function()
      local format = InkFormat.new()

      local result, err = format:import("{invalid json}")
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should return error for non-Ink table", function()
      local format = InkFormat.new()

      local result, err = format:import({ name = "not ink" })
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("should emit event when emitter is set", function()
      local emitted = false
      local emitter = {
        emit = function(self, event, data)
          if event == "ink.story.loaded" then
            emitted = true
          end
        end
      }
      local format = InkFormat.new({ event_emitter = emitter })

      format:import('{"inkVersion": 21, "root": [], "listDefs": {}}')
      assert.is_true(emitted)
    end)
  end)

  describe("load", function()
    it("should load from file path", function()
      local format = InkFormat.new()

      local result, err = format:load("test/fixtures/ink/minimal.json")
      assert.is_nil(err)
      assert.is_table(result)
    end)
  end)

  describe("load_string", function()
    it("should load from string content", function()
      local format = InkFormat.new()

      local result, err = format:load_string('{"inkVersion": 21, "root": [], "listDefs": {}}')
      assert.is_nil(err)
      assert.is_table(result)
    end)
  end)

  describe("can_export", function()
    it("should return true for Ink story data", function()
      local format = InkFormat.new()
      local data = {
        inkVersion = 21,
        root = {"^Hello"}
      }

      assert.is_true(format:can_export(data))
    end)

    it("should return false for non-Ink data", function()
      local format = InkFormat.new()

      assert.is_false(format:can_export({ name = "not ink" }))
      assert.is_false(format:can_export(nil))
      assert.is_false(format:can_export("string"))
    end)
  end)

  describe("export", function()
    it("should export Ink story to JSON string", function()
      local format = InkFormat.new()
      local data = {
        inkVersion = 21,
        root = {"^Hello"},
        listDefs = {}
      }

      local result, err = format:export(data)
      assert.is_nil(err)
      assert.is_string(result)
      assert.truthy(result:match("inkVersion"))
    end)

    it("should return error for non-Ink story", function()
      local format = InkFormat.new()

      local result, err = format:export({ name = "not ink" })
      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("validate", function()
    it("should validate valid Ink data", function()
      local format = InkFormat.new()
      local data = {
        inkVersion = 21,
        root = {}
      }

      local valid, err = format:validate(data)
      assert.is_true(valid)
    end)

    it("should reject invalid Ink data", function()
      local format = InkFormat.new()

      local valid, err = format:validate({ name = "not ink" })
      assert.is_false(valid)
      assert.is_string(err)
    end)
  end)

  describe("get_metadata", function()
    it("should extract metadata", function()
      local format = InkFormat.new()
      local data = {
        inkVersion = 21,
        root = {}
      }

      local metadata = format:get_metadata(data)
      assert.is_table(metadata)
      assert.are.equal(21, metadata.ink_version)
    end)
  end)

  describe("get_version", function()
    it("should return Ink version", function()
      local format = InkFormat.new()
      local data = { inkVersion = 20 }

      assert.are.equal(20, format:get_version(data))
    end)
  end)

  describe("set_event_emitter", function()
    it("should set event emitter", function()
      local format = InkFormat.new()
      local emitter = { emit = function() end }

      format:set_event_emitter(emitter)
      -- Should not error
    end)
  end)

  describe("IFormat contract", function()
    it("should implement all required methods", function()
      local format = InkFormat.new()

      -- Required by IFormat
      assert.is_function(format.can_import)
      assert.is_function(format.import)
      assert.is_function(format.can_export)
      assert.is_function(format.export)
    end)
  end)
end)
