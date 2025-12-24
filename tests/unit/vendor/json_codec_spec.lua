--- JSON Codec Unit Tests
-- Tests for JsonCodec implementation
-- @module tests.unit.vendor.json_codec_spec
-- @author Whisker Core Team
-- @license MIT

describe("JsonCodec", function()
  local JsonCodec = require("whisker.vendor.codecs.json_codec")
  local codec

  before_each(function()
    codec = JsonCodec.new()
  end)

  describe("new", function()
    it("creates a new instance", function()
      assert.is_table(codec)
      assert.is_not_nil(codec.encode)
      assert.is_not_nil(codec.decode)
    end)

    it("detects available JSON library", function()
      local lib_name = codec:get_library_name()
      assert.is_string(lib_name)
      assert.is_not.equal(lib_name, "none")
    end)

    it("accepts optional logger dependency", function()
      local mock_logger = { debug = function() end, info = function() end }
      local codec_with_logger = JsonCodec.new({ logger = mock_logger })
      assert.is_table(codec_with_logger)
      assert.equal(mock_logger, codec_with_logger.log)
    end)
  end)

  describe("create", function()
    it("creates instance via container pattern", function()
      local mock_container = {
        has = function(_, name)
          return name == "logger"
        end,
        resolve = function(_, name)
          if name == "logger" then
            return { debug = function() end }
          end
        end,
      }
      local instance = JsonCodec.create(mock_container)
      assert.is_table(instance)
    end)

    it("works without container", function()
      local instance = JsonCodec.create(nil)
      assert.is_table(instance)
    end)
  end)

  describe("encode", function()
    it("encodes simple table to JSON", function()
      local data = { name = "test", value = 42 }
      local result, err = codec:encode(data)
      assert.is_nil(err)
      assert.is_string(result)
      assert.is_truthy(result:find('"name"'))
      assert.is_truthy(result:find('"test"'))
      assert.is_truthy(result:find("42"))
    end)

    it("encodes array", function()
      local data = { 1, 2, 3, 4, 5 }
      local result, err = codec:encode(data)
      assert.is_nil(err)
      assert.is_string(result)
      assert.is_truthy(result:find("%["))
      assert.is_truthy(result:find("%]"))
    end)

    it("encodes nested structures", function()
      local data = {
        level1 = {
          level2 = {
            value = "deep",
          },
        },
      }
      local result, err = codec:encode(data)
      assert.is_nil(err)
      assert.is_string(result)
      assert.is_truthy(result:find('"level1"'))
      assert.is_truthy(result:find('"level2"'))
      assert.is_truthy(result:find('"deep"'))
    end)

    it("encodes boolean values", function()
      local data = { flag_true = true, flag_false = false }
      local result, err = codec:encode(data)
      assert.is_nil(err)
      assert.is_truthy(result:find("true"))
      assert.is_truthy(result:find("false"))
    end)

    it("encodes number values", function()
      local data = { int = 42, float = 3.14, negative = -100 }
      local result, err = codec:encode(data)
      assert.is_nil(err)
      assert.is_truthy(result:find("42"))
      assert.is_truthy(result:find("3.14"))
      assert.is_truthy(result:find("-100"))
    end)

    it("encodes empty table", function()
      local result, err = codec:encode({})
      assert.is_nil(err)
      assert.is_string(result)
    end)

    it("encodes string value", function()
      local result, err = codec:encode("hello")
      assert.is_nil(err)
      assert.equal('"hello"', result)
    end)
  end)

  describe("decode", function()
    it("decodes JSON object", function()
      local json = '{"name":"test","value":42}'
      local result, err = codec:decode(json)
      assert.is_nil(err)
      assert.is_table(result)
      assert.equal("test", result.name)
      assert.equal(42, result.value)
    end)

    it("decodes JSON array", function()
      local json = "[1,2,3,4,5]"
      local result, err = codec:decode(json)
      assert.is_nil(err)
      assert.is_table(result)
      assert.equal(5, #result)
      assert.equal(1, result[1])
      assert.equal(5, result[5])
    end)

    it("decodes nested structures", function()
      local json = '{"level1":{"level2":{"value":"deep"}}}'
      local result, err = codec:decode(json)
      assert.is_nil(err)
      assert.equal("deep", result.level1.level2.value)
    end)

    it("decodes boolean values", function()
      local json = '{"flag_true":true,"flag_false":false}'
      local result, err = codec:decode(json)
      assert.is_nil(err)
      assert.is_true(result.flag_true)
      assert.is_false(result.flag_false)
    end)

    it("decodes null as nil or special value", function()
      local json = '{"value":null}'
      local result, err = codec:decode(json)
      assert.is_nil(err)
      -- null handling varies by library
      assert.is_table(result)
    end)

    it("returns error for invalid JSON", function()
      local json = "{invalid json"
      local result, err = codec:decode(json)
      assert.is_nil(result)
      assert.is_string(err)
    end)

    it("returns error for non-string input", function()
      local result, err = codec:decode(123)
      assert.is_nil(result)
      assert.is_string(err)
      assert.is_truthy(err:find("Expected string"))
    end)
  end)

  describe("roundtrip", function()
    it("preserves data through encode/decode cycle", function()
      local original = {
        string_val = "hello world",
        number_val = 42,
        float_val = 3.14159,
        bool_true = true,
        bool_false = false,
        array = { 1, 2, 3 },
        nested = {
          key = "value",
        },
      }

      local json, err1 = codec:encode(original)
      assert.is_nil(err1)

      local decoded, err2 = codec:decode(json)
      assert.is_nil(err2)

      assert.equal(original.string_val, decoded.string_val)
      assert.equal(original.number_val, decoded.number_val)
      assert.is_near(original.float_val, decoded.float_val, 0.00001)
      assert.equal(original.bool_true, decoded.bool_true)
      assert.equal(original.bool_false, decoded.bool_false)
      assert.equal(3, #decoded.array)
      assert.equal("value", decoded.nested.key)
    end)
  end)

  describe("get_library_name", function()
    it("returns library name string", function()
      local name = codec:get_library_name()
      assert.is_string(name)
      -- Should be one of the known libraries
      local valid_names = { cjson = true, ["cjson.safe"] = true, dkjson = true, json = true }
      assert.is_truthy(valid_names[name], "Unknown library: " .. name)
    end)
  end)

  describe("supports", function()
    it("returns boolean for feature queries", function()
      local result = codec:supports("pretty")
      assert.is_boolean(result)
    end)

    it("reports null_handling support", function()
      local result = codec:supports("null_handling")
      assert.is_true(result)
    end)

    it("returns false for unknown features", function()
      local result = codec:supports("unknown_feature_xyz")
      assert.is_false(result)
    end)
  end)

  describe("null", function()
    it("returns a null value", function()
      local null_val = codec:null()
      -- May be nil or a special value depending on library
      -- Just check it doesn't error
    end)
  end)

  describe("get_raw_library", function()
    it("returns the underlying library", function()
      local lib = codec:get_raw_library()
      assert.is_table(lib)
      assert.is_function(lib.encode)
      assert.is_function(lib.decode)
    end)
  end)

  describe("IJsonCodec interface compliance", function()
    local IJsonCodec = require("whisker.interfaces.vendor").IJsonCodec

    it("implements encode", function()
      assert.is_function(codec.encode)
    end)

    it("implements decode", function()
      assert.is_function(codec.decode)
    end)

    it("implements get_library_name", function()
      assert.is_function(codec.get_library_name)
    end)

    it("implements supports", function()
      assert.is_function(codec.supports)
    end)

    it("implements null", function()
      assert.is_function(codec.null)
    end)
  end)
end)
