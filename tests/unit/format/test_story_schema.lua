-- Tests for Story Schema
local StorySchema = require("whisker.format.schemas.story_schema")

describe("Story Schema", function()
  local schema

  setup(function()
    schema = StorySchema.new()
  end)

  describe("Schema Version", function()
    it("should have a version defined", function()
      assert.is_string(StorySchema.SCHEMA_VERSION)
      assert.matches("%d+%.%d+%.%d+", StorySchema.SCHEMA_VERSION)
    end)
  end)

  describe("Validation", function()
    it("should validate a minimal valid story", function()
      local story = {
        name = "My Story",
        passages = {
          {name = "Start", content = "Hello, world!"}
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_true(valid)
      assert.equals(0, #errors)
    end)

    it("should require name field", function()
      local story = {
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
      assert.is_true(#errors > 0)
    end)

    it("should require passages field", function()
      local story = {
        name = "My Story"
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
      assert.is_true(#errors > 0)
    end)

    it("should require passages to be an array", function()
      local story = {
        name = "My Story",
        passages = "not an array"
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
    end)

    it("should validate passage name", function()
      local story = {
        name = "My Story",
        passages = {
          {content = "No name field"}
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
    end)

    it("should validate passage content", function()
      local story = {
        name = "My Story",
        passages = {
          {name = "Start"} -- missing content
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
    end)

    it("should accept valid format", function()
      local story = {
        name = "My Story",
        format = "harlowe",
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local valid, _ = schema:validate(story)
      assert.is_true(valid)
    end)

    it("should reject invalid format", function()
      local story = {
        name = "My Story",
        format = "invalid_format",
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
    end)

    it("should validate optional fields correctly", function()
      local story = {
        name = "My Story",
        format = "sugarcube",
        ifid = "12345678-1234-1234-1234-123456789012",
        start = "Beginning",
        zoom = 1.5,
        tags = {"adventure", "fantasy"},
        metadata = {author = "Test Author"},
        passages = {
          {
            name = "Beginning",
            content = "Story content",
            tags = {"intro"},
            position = {x = 100, y = 200},
            size = {width = 150, height = 100}
          }
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_true(valid)
      assert.equals(0, #errors)
    end)

    it("should validate passage position", function()
      local story = {
        name = "My Story",
        passages = {
          {
            name = "Start",
            content = "Hello",
            position = {x = "not a number", y = 100}
          }
        }
      }

      local valid, errors = schema:validate(story)
      assert.is_false(valid)
    end)
  end)

  describe("Defaults", function()
    it("should apply defaults to missing fields", function()
      local story = {
        name = "My Story",
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local result = schema:apply_defaults(story)

      assert.equals("harlowe", result.format)
      assert.equals("Start", result.start)
      assert.equals(1.0, result.zoom)
    end)

    it("should not override existing values", function()
      local story = {
        name = "My Story",
        format = "sugarcube",
        start = "Intro",
        zoom = 2.0,
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local result = schema:apply_defaults(story)

      assert.equals("sugarcube", result.format)
      assert.equals("Intro", result.start)
      assert.equals(2.0, result.zoom)
    end)

    it("should add empty tags to passages if missing", function()
      local story = {
        name = "My Story",
        passages = {
          {name = "Start", content = "Hello"}
        }
      }

      local result = schema:apply_defaults(story)

      assert.is_table(result.passages[1].tags)
      assert.equals(0, #result.passages[1].tags)
    end)
  end)

  describe("Empty Story Creation", function()
    it("should create a valid empty story", function()
      local story = schema:create_empty_story("New Story")

      local valid, errors = schema:validate(story)
      assert.is_true(valid)
      assert.equals("New Story", story.name)
      assert.equals(1, #story.passages)
      assert.equals("Start", story.passages[1].name)
    end)

    it("should use default name if not provided", function()
      local story = schema:create_empty_story()

      assert.equals("Untitled Story", story.name)
    end)

    it("should include metadata", function()
      local story = schema:create_empty_story("Test")

      assert.is_table(story.metadata)
      assert.is_not_nil(story.metadata.created)
      assert.equals(StorySchema.SCHEMA_VERSION, story.metadata.schemaVersion)
    end)
  end)

  describe("JSON Schema", function()
    it("should generate a JSON schema object", function()
      local json_schema = schema:get_json_schema()

      assert.is_table(json_schema)
      assert.equals("Whisker Story Schema", json_schema.title)
      assert.equals("object", json_schema.type)
      assert.is_table(json_schema.required)
      assert.is_table(json_schema.properties)
    end)

    it("should include required fields in schema", function()
      local json_schema = schema:get_json_schema()

      local has_name = false
      local has_passages = false
      for _, field in ipairs(json_schema.required) do
        if field == "name" then has_name = true end
        if field == "passages" then has_passages = true end
      end

      assert.is_true(has_name)
      assert.is_true(has_passages)
    end)

    it("should export schema as JSON string", function()
      local json_str = schema:to_json()

      assert.is_string(json_str)
      assert.matches('"title"', json_str)
      assert.matches('"Whisker Story Schema"', json_str)
    end)
  end)

  describe("Valid Formats", function()
    it("should list all valid formats", function()
      assert.is_true(StorySchema.VALID_FORMATS.harlowe)
      assert.is_true(StorySchema.VALID_FORMATS.sugarcube)
      assert.is_true(StorySchema.VALID_FORMATS.chapbook)
      assert.is_true(StorySchema.VALID_FORMATS.snowman)
    end)

    it("should reject unknown formats", function()
      assert.is_nil(StorySchema.VALID_FORMATS.unknown)
    end)
  end)

end)
