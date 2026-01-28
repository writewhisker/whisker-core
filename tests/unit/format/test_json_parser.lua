-- Tests for JSON Story Parser
local JsonParser = require("whisker.format.parsers.json")
local json = require("whisker.utils.json")

describe("JSON Parser", function()

  describe("Parsing", function()
    it("should parse valid JSON story", function()
      local json_content = json.encode({
        name = "Test Story",
        format = "harlowe",
        passages = {
          {name = "Start", content = "(set: $x to 5)\nHello!"}
        }
      })

      local story, err = JsonParser.parse(json_content)

      assert.is_nil(err)
      assert.is_not_nil(story)
      assert.equals("Test Story", story.name)
      assert.equals("harlowe", story.format)
      assert.equals(1, #story.passages)
    end)

    it("should return error for invalid JSON", function()
      local story, err = JsonParser.parse("not valid json {")

      assert.is_nil(story)
      assert.is_not_nil(err)
      assert.matches("JSON parse error", err)
    end)

    it("should return error for invalid story structure", function()
      local json_content = json.encode({
        -- missing name
        passages = "not an array"
      })

      local story, err = JsonParser.parse(json_content)

      assert.is_nil(story)
      assert.is_not_nil(err)
      assert.matches("Validation error", err)
    end)

    it("should skip validation when requested", function()
      local json_content = json.encode({
        -- invalid structure, but validation disabled
        something = "random"
      })

      local story, err = JsonParser.parse(json_content, {validate = false})

      -- Should parse without validation error
      assert.is_not_nil(story)
    end)
  end)

  describe("Normalization", function()
    it("should normalize story with defaults", function()
      local raw_story = {
        name = "My Story",
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local normalized = JsonParser.normalize_story(raw_story)

      assert.equals("harlowe", normalized.format)
      assert.equals("Start", normalized.start)
      assert.equals(1.0, normalized.zoom)
      assert.is_table(normalized.tags)
      assert.is_table(normalized.metadata)
    end)

    it("should preserve existing values", function()
      local raw_story = {
        name = "My Story",
        format = "sugarcube",
        start = "Intro",
        zoom = 2.0,
        passages = {
          {name = "Intro", content = "Welcome"}
        }
      }

      local normalized = JsonParser.normalize_story(raw_story)

      assert.equals("sugarcube", normalized.format)
      assert.equals("Intro", normalized.start)
      assert.equals(2.0, normalized.zoom)
    end)

    it("should normalize passage fields", function()
      local raw_story = {
        name = "My Story",
        passages = {
          {
            name = "Start",
            content = "Hello",
            position = {x = 100, y = 200},
            size = {width = 150}
          }
        }
      }

      local normalized = JsonParser.normalize_story(raw_story)

      assert.is_table(normalized.passages[1].tags)
      assert.equals(100, normalized.passages[1].position.x)
      assert.equals(200, normalized.passages[1].position.y)
      assert.equals(150, normalized.passages[1].size.width)
      assert.equals(100, normalized.passages[1].size.height) -- default
    end)
  end)

  describe("JSON Detection", function()
    it("should detect valid JSON", function()
      local json_content = json.encode({key = "value"})

      assert.is_true(JsonParser.is_json(json_content))
    end)

    it("should reject invalid JSON", function()
      assert.is_false(JsonParser.is_json("not json"))
      assert.is_false(JsonParser.is_json("{broken"))
    end)

    it("should detect JSON story structure", function()
      local json_content = json.encode({
        name = "Story",
        passages = {}
      })

      assert.is_true(JsonParser.is_json_story(json_content))
    end)

    it("should reject non-story JSON", function()
      local json_content = json.encode({
        something = "else",
        data = {1, 2, 3}
      })

      assert.is_false(JsonParser.is_json_story(json_content))
    end)
  end)

  describe("JSON Export", function()
    it("should export story to JSON", function()
      local story = {
        name = "Export Test",
        format = "harlowe",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str, err = JsonParser.to_json(story)

      assert.is_nil(err)
      assert.is_string(json_str)
      assert.matches('"name"', json_str)
      assert.matches('"Export Test"', json_str)
    end)

    it("should add schema version to export", function()
      local story = {
        name = "Export Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str, err = JsonParser.to_json(story)

      assert.is_nil(err)
      assert.matches('"schemaVersion"', json_str)
    end)

    it("should add export timestamp", function()
      local story = {
        name = "Export Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str, err = JsonParser.to_json(story)

      assert.is_nil(err)
      assert.matches('"exported"', json_str)
    end)

    it("should support pretty printing", function()
      local story = {
        name = "Export Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str = JsonParser.to_json(story, {pretty = true})

      -- Pretty printed JSON has newlines
      assert.matches("\n", json_str)
    end)

    it("should validate before export by default", function()
      local invalid_story = {
        -- missing required fields
        something = "random"
      }

      local json_str, err = JsonParser.to_json(invalid_story)

      assert.is_nil(json_str)
      assert.is_not_nil(err)
      assert.matches("Validation error", err)
    end)

    it("should skip validation when requested", function()
      local invalid_story = {
        something = "random"
      }

      local json_str, err = JsonParser.to_json(invalid_story, {validate = false})

      assert.is_not_nil(json_str)
      assert.is_nil(err)
    end)
  end)

  describe("Twee Conversion", function()
    it("should convert story to Twee format", function()
      local story = {
        name = "My Story",
        format = "harlowe",
        ifid = "12345678-1234-1234-1234-123456789012",
        start = "Start",
        passages = {
          {name = "Start", content = "(set: $x to 5)\nHello!", tags = {}},
          {name = "End", content = "Goodbye!", tags = {"ending"}}
        }
      }

      local twee = JsonParser.to_twee(story)

      assert.matches(":: Start", twee)
      assert.matches(":: End %[ending%]", twee)
      assert.matches("%(set:", twee)
      assert.matches("Goodbye!", twee)
    end)

    it("should include StoryData passage for metadata", function()
      local story = {
        name = "My Story",
        format = "harlowe",
        ifid = "12345678-1234-1234-1234-123456789012",
        start = "Start",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local twee = JsonParser.to_twee(story)

      assert.matches(":: StoryData", twee)
    end)

    it("should convert Twee to JSON story object", function()
      local twee_content = [=[
:: Start
(set: $name to "Hero")
Welcome!

:: Shop
Buy items here.
]=]

      local story = JsonParser.from_twee(twee_content, "harlowe")

      assert.is_not_nil(story)
      assert.is_table(story.passages)
      assert.equals(2, #story.passages)
      assert.equals("Start", story.passages[1].name)
      assert.equals("harlowe", story.format)
    end)
  end)

  describe("Round Trip", function()
    it("should maintain data through JSON round trip", function()
      local original = {
        name = "Round Trip Test",
        format = "sugarcube",
        start = "Begin",
        passages = {
          {
            name = "Begin",
            content = "<<set $x to 5>>\nHello!",
            tags = {"start"}
          },
          {
            name = "End",
            content = "Goodbye!",
            tags = {"ending"}
          }
        }
      }

      -- Export to JSON
      local json_str, err1 = JsonParser.to_json(original)
      assert.is_nil(err1)

      -- Parse back
      local parsed, err2 = JsonParser.parse(json_str)
      assert.is_nil(err2)

      -- Verify key data is preserved
      assert.equals(original.name, parsed.name)
      assert.equals(original.format, parsed.format)
      assert.equals(original.start, parsed.start)
      assert.equals(#original.passages, #parsed.passages)
      assert.equals(original.passages[1].name, parsed.passages[1].name)
      assert.equals(original.passages[1].content, parsed.passages[1].content)
    end)
  end)

  -- GAP-010: JSON Format Version
  describe("Format Version (GAP-010)", function()
    it("should include format_version at top level in export", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str = JsonParser.to_json(story)
      assert.is_not_nil(json_str)
      assert.matches('"format_version"', json_str)
      assert.matches('"1%.0%.0"', json_str)
    end)

    it("should accept matching format version on import", function()
      local json_str = json.encode({
        format_version = "1.0.0",
        name = "Test",
        passages = {
          {name = "Start", content = "Hello"}
        }
      })

      local story, err = JsonParser.parse(json_str)
      assert.is_not_nil(story)
      assert.is_nil(err)
    end)

    it("should warn about newer minor version", function()
      local warned = false
      local json_str = json.encode({
        format_version = "1.1.0",
        name = "Test",
        passages = {
          {name = "Start", content = "Hello"}
        }
      })

      local story = JsonParser.parse(json_str, {
        on_warning = function(msg)
          warned = true
          assert.matches("newer", msg)
        end
      })

      assert.is_not_nil(story)
      assert.is_true(warned)
    end)

    it("should reject incompatible major version in strict mode", function()
      local json_str = json.encode({
        format_version = "2.0.0",
        name = "Test",
        passages = {
          {name = "Start", content = "Hello"}
        }
      })

      local story, err = JsonParser.parse(json_str, { strict_version = true })
      assert.is_nil(story)
      assert.is_not_nil(err)
      assert.matches("newer than supported", err)
    end)

    it("should check version compatibility correctly", function()
      -- Same version is compatible
      local compat1, warn1 = JsonParser.check_version_compatibility("1.0.0", "1.0.0")
      assert.is_true(compat1)
      assert.is_nil(warn1)

      -- Older version is compatible
      local compat2, warn2 = JsonParser.check_version_compatibility("0.9.0", "1.0.0")
      assert.is_true(compat2)
      assert.is_nil(warn2)

      -- Newer minor version is compatible with warning
      local compat3, warn3 = JsonParser.check_version_compatibility("1.1.0", "1.0.0")
      assert.is_true(compat3)
      assert.is_not_nil(warn3)

      -- Newer major version is incompatible
      local compat4, warn4 = JsonParser.check_version_compatibility("2.0.0", "1.0.0")
      assert.is_false(compat4)
      assert.is_not_nil(warn4)
    end)
  end)

  -- GAP-011: JSON WLS Field
  describe("WLS Field (GAP-011)", function()
    it("should include wls field in export", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str = JsonParser.to_json(story)
      assert.is_not_nil(json_str)
      assert.matches('"wls"', json_str)
      assert.matches('"1%.0%.0"', json_str)
    end)

    it("should use story-declared wls version in export", function()
      local story = {
        name = "Test",
        wls_version = "1.1.0",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str = JsonParser.to_json(story)
      local decoded = json.decode(json_str)
      assert.equals("1.1.0", decoded.wls)
    end)

    it("should preserve wls version in parsed story", function()
      local json_str = json.encode({
        wls = "1.0.0",
        name = "Test",
        passages = {
          {name = "Start", content = "Hello"}
        }
      })

      local story = JsonParser.parse(json_str)
      assert.equals("1.0.0", story.wls_version)
    end)

    it("should warn about unsupported wls major version", function()
      local warned = false
      local json_str = json.encode({
        wls = "2.0.0",
        name = "Test",
        passages = {
          {name = "Start", content = "Hello"}
        }
      })

      JsonParser.parse(json_str, {
        on_warning = function(msg)
          warned = true
        end
      })

      assert.is_true(warned)
    end)

    it("should include exporter field in metadata", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local json_str = JsonParser.to_json(story)
      assert.matches('"exporter"', json_str)
      assert.matches('"whisker%-core%-lua"', json_str)
    end)
  end)

end)
