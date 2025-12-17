-- spec/formats/ink/json_loader_spec.lua
-- Tests for Ink JSON loader

describe("InkJsonLoader", function()
  local JsonLoader

  before_each(function()
    package.loaded["whisker.formats.ink.json_loader"] = nil
    JsonLoader = require("whisker.formats.ink.json_loader")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(JsonLoader._whisker)
      assert.are.equal("InkJsonLoader", JsonLoader._whisker.name)
      assert.is_string(JsonLoader._whisker.version)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local loader = JsonLoader.new()
      assert.is_table(loader)
    end)
  end)

  describe("load_string", function()
    it("should load valid Ink JSON", function()
      local loader = JsonLoader.new()
      local json_str = [[{
        "inkVersion": 21,
        "root": ["^Hello", "\n", "done"],
        "listDefs": {}
      }]]

      local result, err = loader:load_string(json_str)
      assert.is_nil(err)
      assert.is_table(result)
      assert.are.equal(21, result.inkVersion)
    end)

    it("should return error for empty string", function()
      local loader = JsonLoader.new()
      local result, err = loader:load_string("")

      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("empty"))
    end)

    it("should return error for invalid JSON", function()
      local loader = JsonLoader.new()
      local result, err = loader:load_string("{invalid json}")

      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("parse") or err:match("error"))
    end)

    it("should return error for non-string input", function()
      local loader = JsonLoader.new()
      local result, err = loader:load_string(123)

      assert.is_nil(result)
      assert.is_string(err)
    end)
  end)

  describe("load_file", function()
    it("should load minimal.json fixture", function()
      local loader = JsonLoader.new()
      local result, err = loader:load_file("test/fixtures/ink/minimal.json")

      assert.is_nil(err)
      assert.is_table(result)
      assert.are.equal(21, result.inkVersion)
      assert.is_table(result.root)
    end)

    it("should return error for non-existent file", function()
      local loader = JsonLoader.new()
      local result, err = loader:load_file("non_existent_file.json")

      assert.is_nil(result)
      assert.is_string(err)
      assert.truthy(err:match("open") or err:match("file"))
    end)
  end)

  describe("validate", function()
    it("should accept valid Ink structure", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 21,
        root = {"^Hello"},
        listDefs = {}
      }

      local valid, err = loader:validate(data)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should reject missing inkVersion", function()
      local loader = JsonLoader.new()
      local data = {
        root = {"^Hello"}
      }

      local valid, err = loader:validate(data)
      assert.is_false(valid)
      assert.truthy(err:match("inkVersion"))
    end)

    it("should reject missing root", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 21
      }

      local valid, err = loader:validate(data)
      assert.is_false(valid)
      assert.truthy(err:match("root"))
    end)

    it("should reject old Ink versions", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 10,
        root = {"^Hello"}
      }

      local valid, err = loader:validate(data)
      assert.is_false(valid)
      assert.truthy(err:match("version") or err:match("Unsupported"))
    end)

    it("should accept version 19", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 19,
        root = {"^Hello"}
      }

      local valid, err = loader:validate(data)
      assert.is_true(valid)
    end)

    it("should accept version 20", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 20,
        root = {"^Hello"}
      }

      local valid, err = loader:validate(data)
      assert.is_true(valid)
    end)

    it("should reject non-table input", function()
      local loader = JsonLoader.new()

      local valid, err = loader:validate("not a table")
      assert.is_false(valid)
      assert.truthy(err:match("table"))
    end)
  end)

  describe("get_version", function()
    it("should return Ink version", function()
      local loader = JsonLoader.new()
      local data = { inkVersion = 21 }

      assert.are.equal(21, loader:get_version(data))
    end)

    it("should return nil for invalid data", function()
      local loader = JsonLoader.new()

      assert.is_nil(loader:get_version("not a table"))
      assert.is_nil(loader:get_version(nil))
    end)
  end)

  describe("is_ink_json", function()
    it("should return true for valid Ink JSON table", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 21,
        root = {"^Hello"}
      }

      assert.is_true(loader:is_ink_json(data))
    end)

    it("should return true for valid Ink JSON string", function()
      local loader = JsonLoader.new()
      local json_str = '{"inkVersion": 21, "root": []}'

      assert.is_true(loader:is_ink_json(json_str))
    end)

    it("should return false for non-Ink JSON", function()
      local loader = JsonLoader.new()
      local data = {
        name = "not ink",
        content = "something"
      }

      assert.is_false(loader:is_ink_json(data))
    end)

    it("should return false for invalid JSON string", function()
      local loader = JsonLoader.new()

      assert.is_false(loader:is_ink_json("{invalid}"))
    end)

    it("should return false for non-table types", function()
      local loader = JsonLoader.new()

      assert.is_false(loader:is_ink_json(123))
      assert.is_false(loader:is_ink_json(nil))
    end)
  end)

  describe("get_metadata", function()
    it("should extract ink_version", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 21,
        root = {}
      }

      local meta = loader:get_metadata(data)
      assert.are.equal(21, meta.ink_version)
    end)

    it("should detect list definitions", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 21,
        root = {},
        listDefs = {
          Colors = { red = 1, green = 2 },
          Sizes = { small = 1, large = 2 }
        }
      }

      local meta = loader:get_metadata(data)
      assert.is_true(meta.has_lists)
      assert.are.equal(2, meta.list_count)
    end)

    it("should extract global tags", function()
      local loader = JsonLoader.new()
      local data = {
        inkVersion = 21,
        root = {
          "#title: My Story",
          "#author: Test Author",
          "^Hello"
        }
      }

      local meta = loader:get_metadata(data)
      assert.is_table(meta.global_tags)
      assert.are.equal(2, #meta.global_tags)
      assert.are.equal("My Story", meta.title)
      assert.are.equal("Test Author", meta.author)
    end)

    it("should handle missing data gracefully", function()
      local loader = JsonLoader.new()

      local meta = loader:get_metadata(nil)
      assert.is_table(meta)

      meta = loader:get_metadata("not a table")
      assert.is_table(meta)
    end)
  end)
end)
