-- tests/unit/i18n/formats_spec.lua
-- Unit tests for translation file formats (Stage 3)

describe("Format Registry", function()
  local Formats

  before_each(function()
    package.loaded["whisker.i18n.formats"] = nil
    package.loaded["whisker.i18n.formats.json"] = nil
    package.loaded["whisker.i18n.formats.yaml"] = nil
    package.loaded["whisker.i18n.formats.lua"] = nil
    Formats = require("whisker.i18n.formats")
  end)

  describe("detect()", function()
    it("detects YAML files (.yml)", function()
      assert.equals("yml", Formats.detect("translations.yml"))
      assert.equals("yml", Formats.detect("/path/to/locales/en.yml"))
    end)

    it("detects YAML files (.yaml)", function()
      assert.equals("yaml", Formats.detect("translations.yaml"))
      assert.equals("yaml", Formats.detect("/path/to/locales/en.yaml"))
    end)

    it("detects JSON files", function()
      assert.equals("json", Formats.detect("translations.json"))
      assert.equals("json", Formats.detect("/path/to/locales/en.json"))
    end)

    it("detects Lua files", function()
      assert.equals("lua", Formats.detect("translations.lua"))
      assert.equals("lua", Formats.detect("/path/to/locales/en.lua"))
    end)

    it("returns nil for unknown extensions", function()
      assert.is_nil(Formats.detect("translations.txt"))
      assert.is_nil(Formats.detect("translations.xml"))
      assert.is_nil(Formats.detect("translations"))
    end)

    it("returns nil for nil input", function()
      assert.is_nil(Formats.detect(nil))
    end)
  end)

  describe("getSupportedFormats()", function()
    it("returns list of supported formats", function()
      local formats = Formats.getSupportedFormats()
      assert.is_table(formats)
      assert.is_true(#formats >= 3)
    end)
  end)

  describe("isSupported()", function()
    it("returns true for supported formats", function()
      assert.is_true(Formats.isSupported("yml"))
      assert.is_true(Formats.isSupported("yaml"))
      assert.is_true(Formats.isSupported("json"))
      assert.is_true(Formats.isSupported("lua"))
    end)

    it("returns false for unsupported formats", function()
      assert.is_false(Formats.isSupported("txt"))
      assert.is_false(Formats.isSupported("xml"))
    end)
  end)

  describe("getHandler()", function()
    it("returns handler for yml", function()
      local handler = Formats.getHandler("yml")
      assert.is_not_nil(handler)
      assert.is_function(handler.load)
    end)

    it("returns handler for json", function()
      local handler = Formats.getHandler("json")
      assert.is_not_nil(handler)
      assert.is_function(handler.load)
    end)

    it("returns handler for lua", function()
      local handler = Formats.getHandler("lua")
      assert.is_not_nil(handler)
      assert.is_function(handler.load)
    end)
  end)
end)

describe("JSON Format", function()
  local JsonFormat

  before_each(function()
    package.loaded["whisker.i18n.formats.json"] = nil
    JsonFormat = require("whisker.i18n.formats.json")
  end)

  describe("parse()", function()
    it("parses simple object", function()
      local data = JsonFormat.parse('{"greeting": "Hello"}')
      assert.equals("Hello", data.greeting)
    end)

    it("parses nested objects", function()
      local data = JsonFormat.parse('{"items": {"sword": "a sword", "shield": "a shield"}}')
      assert.equals("a sword", data.items.sword)
      assert.equals("a shield", data.items.shield)
    end)

    it("parses arrays", function()
      local data = JsonFormat.parse('{"list": [1, 2, 3]}')
      assert.equals(1, data.list[1])
      assert.equals(2, data.list[2])
      assert.equals(3, data.list[3])
    end)

    it("parses numbers", function()
      local data = JsonFormat.parse('{"int": 42, "float": 3.14, "neg": -10, "exp": 1e5}')
      assert.equals(42, data.int)
      assert.equals(3.14, data.float)
      assert.equals(-10, data.neg)
      assert.equals(100000, data.exp)
    end)

    it("parses booleans", function()
      local data = JsonFormat.parse('{"yes": true, "no": false}')
      assert.is_true(data.yes)
      assert.is_false(data.no)
    end)

    it("parses null", function()
      local data = JsonFormat.parse('{"empty": null}')
      assert.is_nil(data.empty)
    end)

    it("handles escaped characters in strings", function()
      local data = JsonFormat.parse('{"text": "line1\\nline2\\ttab"}')
      assert.equals("line1\nline2\ttab", data.text)
    end)

    it("handles unicode escapes", function()
      local data = JsonFormat.parse('{"text": "\\u0041\\u0042\\u0043"}')
      assert.equals("ABC", data.text)
    end)

    it("errors on invalid JSON", function()
      assert.has_error(function()
        JsonFormat.parse('{invalid}')
      end)
    end)

    it("errors on trailing comma", function()
      assert.has_error(function()
        JsonFormat.parse('{"a": 1,}')
      end)
    end)

    it("strips BOM", function()
      local data = JsonFormat.parse('\xEF\xBB\xBF{"greeting": "Hello"}')
      assert.equals("Hello", data.greeting)
    end)
  end)

  describe("validate()", function()
    it("accepts valid object", function()
      JsonFormat.validate({ greeting = "Hello" }, "test")
    end)

    it("rejects array at root", function()
      -- Create array-like table
      local arr = { "a", "b", "c" }
      assert.has_error(function()
        JsonFormat.validate(arr, "test")
      end)
    end)

    it("rejects non-table root", function()
      assert.has_error(function()
        JsonFormat.validate("string", "test")
      end)
    end)
  end)

  describe("load()", function()
    local testFile = "/tmp/test_i18n.json"

    after_each(function()
      os.remove(testFile)
    end)

    it("loads valid JSON file", function()
      local file = io.open(testFile, "w")
      file:write('{"greeting": "Hello", "items": {"sword": "a sword"}}')
      file:close()

      local data = JsonFormat.load(testFile)
      assert.equals("Hello", data.greeting)
      assert.equals("a sword", data.items.sword)
    end)

    it("errors on missing file", function()
      assert.has_error(function()
        JsonFormat.load("/nonexistent/file.json")
      end)
    end)

    it("strips BOM from file", function()
      local file = io.open(testFile, "w")
      file:write('\xEF\xBB\xBF{"greeting": "Hello"}')
      file:close()

      local data = JsonFormat.load(testFile)
      assert.equals("Hello", data.greeting)
    end)
  end)

  describe("loadString()", function()
    it("loads JSON from string", function()
      local data = JsonFormat.loadString('{"greeting": "Hello"}')
      assert.equals("Hello", data.greeting)
    end)
  end)

  describe("encode()", function()
    it("encodes simple object", function()
      local json = JsonFormat.encode({ greeting = "Hello" })
      assert.is_string(json)
      assert.truthy(json:match('"greeting"'))
      assert.truthy(json:match('"Hello"'))
    end)

    it("encodes nested objects", function()
      local json = JsonFormat.encode({ items = { sword = "a sword" } })
      assert.truthy(json:match('"items"'))
      assert.truthy(json:match('"sword"'))
    end)

    it("encodes arrays", function()
      local json = JsonFormat.encode({ list = { 1, 2, 3 } })
      assert.truthy(json:match('%[1,2,3%]') or json:match('%[1, 2, 3%]'))
    end)

    it("encodes with pretty print", function()
      local json = JsonFormat.encode({ greeting = "Hello" }, true)
      assert.truthy(json:match("\n"))
    end)

    it("escapes special characters", function()
      local json = JsonFormat.encode({ text = "line1\nline2" })
      assert.truthy(json:match("\\n"))
    end)
  end)

  describe("save()", function()
    local testFile = "/tmp/test_i18n_save.json"

    after_each(function()
      os.remove(testFile)
    end)

    it("saves JSON file", function()
      JsonFormat.save(testFile, { greeting = "Hello" })

      local file = io.open(testFile, "r")
      local content = file:read("*all")
      file:close()

      assert.truthy(content:match("greeting"))
      assert.truthy(content:match("Hello"))
    end)

    it("round-trips correctly", function()
      local original = {
        greeting = "Hello",
        nested = { key = "value" },
        number = 42
      }
      JsonFormat.save(testFile, original)
      local loaded = JsonFormat.load(testFile)

      assert.equals("Hello", loaded.greeting)
      assert.equals("value", loaded.nested.key)
      assert.equals(42, loaded.number)
    end)
  end)
end)

describe("YAML Format", function()
  local YamlFormat

  before_each(function()
    package.loaded["whisker.i18n.formats.yaml"] = nil
    YamlFormat = require("whisker.i18n.formats.yaml")
  end)

  describe("parse()", function()
    it("parses simple key-value", function()
      local data = YamlFormat.parse("greeting: Hello")
      assert.equals("Hello", data.greeting)
    end)

    it("parses multiple key-values", function()
      local data = YamlFormat.parse("greeting: Hello\nfarewell: Goodbye")
      assert.equals("Hello", data.greeting)
      assert.equals("Goodbye", data.farewell)
    end)

    it("parses nested structure", function()
      local yaml = [[
items:
  sword: a sword
  shield: a shield
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("a sword", data.items.sword)
      assert.equals("a shield", data.items.shield)
    end)

    it("parses deeply nested structure", function()
      local yaml = [[
level1:
  level2:
    level3:
      key: deep value
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("deep value", data.level1.level2.level3.key)
    end)

    it("parses quoted strings", function()
      local yaml = [[
single: 'single quoted'
double: "double quoted"
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("single quoted", data.single)
      assert.equals("double quoted", data.double)
    end)

    it("handles escape sequences in double quotes", function()
      local data = YamlFormat.parse('text: "line1\\nline2"')
      assert.equals("line1\nline2", data.text)
    end)

    it("parses booleans", function()
      local yaml = [[
yes_val: yes
no_val: no
true_val: true
false_val: false
]]
      local data = YamlFormat.parse(yaml)
      assert.is_true(data.yes_val)
      assert.is_false(data.no_val)
      assert.is_true(data.true_val)
      assert.is_false(data.false_val)
    end)

    it("parses numbers", function()
      local yaml = [[
integer: 42
float: 3.14
negative: -10
]]
      local data = YamlFormat.parse(yaml)
      assert.equals(42, data.integer)
      assert.equals(3.14, data.float)
      assert.equals(-10, data.negative)
    end)

    it("parses null", function()
      local yaml = [[
empty: null
tilde: ~
]]
      local data = YamlFormat.parse(yaml)
      assert.is_nil(data.empty)
      assert.is_nil(data.tilde)
    end)

    it("skips comments", function()
      local yaml = [[
# This is a comment
greeting: Hello  # inline comment
# Another comment
farewell: Goodbye
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("Hello", data.greeting)
      assert.equals("Goodbye", data.farewell)
    end)

    it("skips empty lines", function()
      local yaml = [[
greeting: Hello

farewell: Goodbye
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("Hello", data.greeting)
      assert.equals("Goodbye", data.farewell)
    end)

    it("strips BOM", function()
      local data = YamlFormat.parse("\xEF\xBB\xBFgreeting: Hello")
      assert.equals("Hello", data.greeting)
    end)

    it("handles keys with dots", function()
      local yaml = [[
simple.key: value
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("value", data["simple.key"])
    end)

    it("handles keys with hyphens", function()
      local yaml = [[
my-key: value
]]
      local data = YamlFormat.parse(yaml)
      assert.equals("value", data["my-key"])
    end)
  end)

  describe("validate()", function()
    it("accepts valid structure", function()
      YamlFormat.validate({ greeting = "Hello" }, "test")
    end)

    it("rejects non-table root", function()
      assert.has_error(function()
        YamlFormat.validate("string", "test")
      end)
    end)
  end)

  describe("load()", function()
    local testFile = "/tmp/test_i18n.yml"

    after_each(function()
      os.remove(testFile)
    end)

    it("loads valid YAML file", function()
      local file = io.open(testFile, "w")
      file:write("greeting: Hello\nitems:\n  sword: a sword")
      file:close()

      local data = YamlFormat.load(testFile)
      assert.equals("Hello", data.greeting)
      assert.equals("a sword", data.items.sword)
    end)

    it("errors on missing file", function()
      assert.has_error(function()
        YamlFormat.load("/nonexistent/file.yml")
      end)
    end)
  end)

  describe("loadString()", function()
    it("loads YAML from string", function()
      local data = YamlFormat.loadString("greeting: Hello")
      assert.equals("Hello", data.greeting)
    end)
  end)

  describe("encode()", function()
    it("encodes simple structure", function()
      local yaml = YamlFormat.encode({ greeting = "Hello" })
      assert.truthy(yaml:match("greeting: Hello"))
    end)

    it("encodes nested structure", function()
      local yaml = YamlFormat.encode({ items = { sword = "a sword" } })
      assert.truthy(yaml:match("items:"))
      assert.truthy(yaml:match("sword: a sword"))
    end)

    it("quotes strings that need it", function()
      local yaml = YamlFormat.encode({ text = "has: colon" })
      assert.truthy(yaml:match('"has: colon"'))
    end)
  end)

  describe("save()", function()
    local testFile = "/tmp/test_i18n_save.yml"

    after_each(function()
      os.remove(testFile)
    end)

    it("saves YAML file", function()
      YamlFormat.save(testFile, { greeting = "Hello" })

      local file = io.open(testFile, "r")
      local content = file:read("*all")
      file:close()

      assert.truthy(content:match("greeting"))
      assert.truthy(content:match("Hello"))
    end)

    it("round-trips correctly", function()
      local original = {
        greeting = "Hello",
        nested = { key = "value" }
      }
      YamlFormat.save(testFile, original)
      local loaded = YamlFormat.load(testFile)

      assert.equals("Hello", loaded.greeting)
      assert.equals("value", loaded.nested.key)
    end)
  end)
end)

describe("Lua Format", function()
  local LuaFormat

  before_each(function()
    package.loaded["whisker.i18n.formats.lua"] = nil
    LuaFormat = require("whisker.i18n.formats.lua")
  end)

  describe("load()", function()
    local testFile = "/tmp/test_i18n.lua"

    after_each(function()
      os.remove(testFile)
    end)

    it("loads simple Lua table", function()
      local file = io.open(testFile, "w")
      file:write('return {greeting = "Hello"}')
      file:close()

      local data = LuaFormat.load(testFile)
      assert.equals("Hello", data.greeting)
    end)

    it("loads nested Lua table", function()
      local file = io.open(testFile, "w")
      file:write('return {items = {sword = "a sword", shield = "a shield"}}')
      file:close()

      local data = LuaFormat.load(testFile)
      assert.equals("a sword", data.items.sword)
      assert.equals("a shield", data.items.shield)
    end)

    it("loads with quoted keys", function()
      local file = io.open(testFile, "w")
      file:write('return {["key-with-dash"] = "value", ["key.with.dot"] = "value2"}')
      file:close()

      local data = LuaFormat.load(testFile)
      assert.equals("value", data["key-with-dash"])
      assert.equals("value2", data["key.with.dot"])
    end)

    it("errors on missing file", function()
      assert.has_error(function()
        LuaFormat.load("/nonexistent/file.lua")
      end)
    end)

    it("errors when not returning table", function()
      local file = io.open(testFile, "w")
      file:write('return "not a table"')
      file:close()

      assert.has_error(function()
        LuaFormat.load(testFile)
      end)
    end)

    it("restricts dangerous functions", function()
      local file = io.open(testFile, "w")
      file:write('os.execute("echo test"); return {}')
      file:close()

      assert.has_error(function()
        LuaFormat.load(testFile)
      end)
    end)
  end)

  describe("loadString()", function()
    it("loads Lua from string", function()
      local data = LuaFormat.loadString('return {greeting = "Hello"}')
      assert.equals("Hello", data.greeting)
    end)

    it("restricts dangerous functions", function()
      assert.has_error(function()
        LuaFormat.loadString('io.open("/etc/passwd"); return {}')
      end)
    end)
  end)

  describe("validate()", function()
    it("accepts valid structure", function()
      LuaFormat.validate({ greeting = "Hello" }, "test")
    end)

    it("detects circular references", function()
      local data = { a = {} }
      data.a.b = data

      assert.has_error(function()
        LuaFormat.validate(data, "test")
      end)
    end)
  end)

  describe("serialize()", function()
    it("serializes simple table", function()
      local lua = LuaFormat.serialize({ greeting = "Hello" })
      assert.truthy(lua:match("return"))
      assert.truthy(lua:match("greeting"))
      assert.truthy(lua:match('"Hello"'))
    end)

    it("serializes nested table", function()
      local lua = LuaFormat.serialize({ items = { sword = "a sword" } })
      assert.truthy(lua:match("items"))
      assert.truthy(lua:match("sword"))
    end)

    it("handles special keys", function()
      local lua = LuaFormat.serialize({ ["key-with-dash"] = "value" })
      assert.truthy(lua:match('%["key%-with%-dash"%]'))
    end)

    it("serializes with pretty print", function()
      local lua = LuaFormat.serialize({ greeting = "Hello" }, { pretty = true })
      assert.truthy(lua:match("\n"))
    end)
  end)

  describe("save()", function()
    local testFile = "/tmp/test_i18n_save.lua"

    after_each(function()
      os.remove(testFile)
    end)

    it("saves Lua file", function()
      LuaFormat.save(testFile, { greeting = "Hello" })

      local file = io.open(testFile, "r")
      local content = file:read("*all")
      file:close()

      assert.truthy(content:match("return"))
      assert.truthy(content:match("greeting"))
    end)

    it("round-trips correctly", function()
      local original = {
        greeting = "Hello",
        nested = { key = "value" },
        number = 42
      }
      LuaFormat.save(testFile, original)
      local loaded = LuaFormat.load(testFile)

      assert.equals("Hello", loaded.greeting)
      assert.equals("value", loaded.nested.key)
      assert.equals(42, loaded.number)
    end)
  end)
end)

describe("Format Integration", function()
  local Formats
  local testDir = "/tmp/test_i18n_formats"

  before_each(function()
    package.loaded["whisker.i18n.formats"] = nil
    package.loaded["whisker.i18n.formats.json"] = nil
    package.loaded["whisker.i18n.formats.yaml"] = nil
    package.loaded["whisker.i18n.formats.lua"] = nil
    Formats = require("whisker.i18n.formats")

    os.execute("mkdir -p " .. testDir)
  end)

  after_each(function()
    os.execute("rm -rf " .. testDir)
  end)

  describe("loadFile()", function()
    it("loads JSON file with auto-detection", function()
      local filepath = testDir .. "/test.json"
      local file = io.open(filepath, "w")
      file:write('{"greeting": "Hello"}')
      file:close()

      local data, format = Formats.loadFile(filepath)
      assert.equals("json", format)
      assert.equals("Hello", data.greeting)
    end)

    it("loads YAML file with auto-detection", function()
      local filepath = testDir .. "/test.yml"
      local file = io.open(filepath, "w")
      file:write("greeting: Hello")
      file:close()

      local data, format = Formats.loadFile(filepath)
      assert.equals("yml", format)
      assert.equals("Hello", data.greeting)
    end)

    it("loads Lua file with auto-detection", function()
      local filepath = testDir .. "/test.lua"
      local file = io.open(filepath, "w")
      file:write('return {greeting = "Hello"}')
      file:close()

      local data, format = Formats.loadFile(filepath)
      assert.equals("lua", format)
      assert.equals("Hello", data.greeting)
    end)

    it("returns error for unknown format", function()
      local data, err = Formats.loadFile("/path/to/file.txt")
      assert.is_nil(data)
      assert.truthy(err:match("Cannot detect format"))
    end)
  end)
end)
