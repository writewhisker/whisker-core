-- whisker-lsp/spec/json_spec.lua
-- Tests for JSON encoder/decoder

package.path = package.path .. ";./tools/whisker-lsp/?.lua;./tools/whisker-lsp/?/init.lua"

describe("JSON", function()
  local json

  before_each(function()
    json = require("lib.json")
  end)

  describe("encode", function()
    it("encodes null", function()
      assert.equals("null", json.encode(nil))
    end)

    it("encodes booleans", function()
      assert.equals("true", json.encode(true))
      assert.equals("false", json.encode(false))
    end)

    it("encodes numbers", function()
      assert.equals("42", json.encode(42))
      assert.equals("3.14", json.encode(3.14))
      assert.equals("-10", json.encode(-10))
    end)

    it("encodes strings", function()
      assert.equals('"hello"', json.encode("hello"))
      assert.equals('"hello world"', json.encode("hello world"))
    end)

    it("escapes special characters in strings", function()
      assert.equals('"hello\\nworld"', json.encode("hello\nworld"))
      assert.equals('"hello\\tworld"', json.encode("hello\tworld"))
      assert.equals('"hello\\"world"', json.encode('hello"world'))
      assert.equals('"hello\\\\world"', json.encode('hello\\world'))
    end)

    it("encodes arrays", function()
      local result = json.encode({1, 2, 3})
      -- Allow for whitespace variations
      assert.matches("%[%s*1%s*,%s*2%s*,%s*3%s*%]", result)

      local empty = json.encode({})
      assert.matches("%[%s*%]", empty)
    end)

    it("encodes objects", function()
      local result = json.encode({a = 1})
      assert.matches('"a"%s*:%s*1', result)
    end)

    it("encodes nested structures", function()
      local result = json.encode({arr = {1, 2}, obj = {x = 1}})
      assert.matches('"arr":', result)
      assert.matches('"obj":', result)
    end)
  end)

  describe("decode", function()
    it("decodes null", function()
      assert.is_nil(json.decode("null"))
    end)

    it("decodes booleans", function()
      assert.is_true(json.decode("true"))
      assert.is_false(json.decode("false"))
    end)

    it("decodes numbers", function()
      assert.equals(42, json.decode("42"))
      assert.equals(3.14, json.decode("3.14"))
      assert.equals(-10, json.decode("-10"))
      assert.equals(1e10, json.decode("1e10"))
    end)

    it("decodes strings", function()
      assert.equals("hello", json.decode('"hello"'))
      assert.equals("hello world", json.decode('"hello world"'))
    end)

    it("decodes escape sequences", function()
      assert.equals("hello\nworld", json.decode('"hello\\nworld"'))
      assert.equals("hello\tworld", json.decode('"hello\\tworld"'))
      assert.equals('hello"world', json.decode('"hello\\"world"'))
      assert.equals('hello\\world', json.decode('"hello\\\\world"'))
    end)

    it("decodes arrays", function()
      local arr = json.decode("[1, 2, 3]")
      assert.equals(3, #arr)
      assert.equals(1, arr[1])
      assert.equals(2, arr[2])
      assert.equals(3, arr[3])
    end)

    it("decodes objects", function()
      local obj = json.decode('{"a": 1, "b": 2}')
      assert.equals(1, obj.a)
      assert.equals(2, obj.b)
    end)

    it("decodes nested structures", function()
      local data = json.decode('{"arr": [1, 2], "obj": {"x": 1}}')
      assert.equals(2, #data.arr)
      assert.equals(1, data.obj.x)
    end)

    it("handles whitespace", function()
      local data = json.decode('  { "a" : 1 }  ')
      assert.equals(1, data.a)
    end)

    it("returns nil for empty input", function()
      assert.is_nil(json.decode(""))
      assert.is_nil(json.decode(nil))
    end)
  end)

  describe("roundtrip", function()
    it("preserves data through encode/decode", function()
      local data = {
        name = "test",
        count = 42,
        active = true,
        tags = {"a", "b", "c"},
        nested = {x = 1, y = 2}
      }

      local encoded = json.encode(data)
      local decoded = json.decode(encoded)

      assert.equals("test", decoded.name)
      assert.equals(42, decoded.count)
      assert.is_true(decoded.active)
      assert.equals(3, #decoded.tags)
      assert.equals(1, decoded.nested.x)
    end)
  end)
end)
