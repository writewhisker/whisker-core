--- JsonFormat Unit Tests
-- @module tests.unit.formats.json.format_spec
-- @author Whisker Core Team

describe("JsonFormat", function()
  local JsonFormat
  local Story = require("whisker.core.story")
  local Passage = require("whisker.core.passage")
  local Choice = require("whisker.core.choice")
  local TestContainer = require("tests.helpers.test_container")

  before_each(function()
    JsonFormat = require("whisker.formats.json")
  end)

  describe("initialization", function()
    it("creates format handler without container", function()
      local format = JsonFormat.new(nil)
      assert.is_not_nil(format)
    end)

    it("creates format handler with container", function()
      local container = TestContainer.create()
      local format = JsonFormat.new(container)
      assert.is_not_nil(format)
    end)
  end)

  describe("interface methods", function()
    local format

    before_each(function()
      format = JsonFormat.new(nil)
    end)

    it("returns format name", function()
      assert.equals("json", format:get_name())
    end)

    it("returns file extensions", function()
      local exts = format:get_extensions()
      assert.is_table(exts)
      assert.is_true(#exts >= 1)
    end)

    it("returns MIME type", function()
      assert.equals("application/json", format:get_mime_type())
    end)
  end)

  describe("can_import", function()
    local format

    before_each(function()
      format = JsonFormat.new(nil)
    end)

    it("returns true for valid JSON story string", function()
      local json = '{"passages": [], "metadata": {"name": "Test"}}'
      assert.is_true(format:can_import(json))
    end)

    it("returns true for JSON with ifid", function()
      local json = '{"ifid": "12345", "name": "Test"}'
      assert.is_true(format:can_import(json))
    end)

    it("returns true for already parsed table", function()
      local data = { passages = {}, metadata = { name = "Test" } }
      assert.is_true(format:can_import(data))
    end)

    it("returns false for invalid JSON", function()
      assert.is_false(format:can_import("not json"))
    end)

    it("returns false for empty string", function()
      assert.is_false(format:can_import(""))
    end)

    it("returns false for non-story JSON", function()
      local json = '{"foo": "bar"}'
      assert.is_false(format:can_import(json))
    end)
  end)

  describe("import", function()
    local format

    before_each(function()
      format = JsonFormat.new(nil)
    end)

    it("imports simple story", function()
      local json = [[{
        "name": "Test Story",
        "author": "Test Author",
        "start": "start",
        "passages": [
          {
            "id": "start",
            "name": "Start Passage",
            "content": "Hello World"
          }
        ]
      }]]

      local story = format:import(json)

      assert.is_not_nil(story)
      assert.equals("Test Story", story.metadata.name)
      assert.equals("start", story.start_passage)
    end)

    it("imports story with choices", function()
      local json = [[{
        "name": "Test",
        "start": "start",
        "passages": [
          {
            "id": "start",
            "name": "Start",
            "content": "Choose wisely",
            "choices": [
              {"text": "Go left", "target": "left"},
              {"text": "Go right", "target": "right"}
            ]
          },
          {"id": "left", "name": "Left", "content": "You went left"},
          {"id": "right", "name": "Right", "content": "You went right"}
        ]
      }]]

      local story = format:import(json)
      local start = story:get_passage("start")

      assert.equals(2, #start:get_choices())
      assert.equals("Go left", start:get_choice(1).text)
    end)

    it("imports from table", function()
      local data = {
        name = "Table Story",
        passages = {
          { id = "p1", name = "Passage 1", content = "Content 1" }
        }
      }

      local story = format:import(data)

      assert.is_not_nil(story)
      assert.equals("Table Story", story.metadata.name)
    end)

    it("handles map-style passages", function()
      local json = [[{
        "name": "Map Story",
        "passages": {
          "start": {"name": "Start", "content": "Begin"},
          "end": {"name": "End", "content": "Finish"}
        }
      }]]

      local story = format:import(json)
      local passages = story:get_all_passages()

      assert.equals(2, #passages)
    end)

    it("errors on invalid input", function()
      assert.has_error(function()
        format:import("not valid")
      end)
    end)
  end)

  describe("can_export", function()
    local format

    before_each(function()
      format = JsonFormat.new(nil)
    end)

    it("returns true for valid story", function()
      local story = Story.create({ title = "Test" })
      story:add_passage(Passage.create({ id = "start", name = "Start" }))

      assert.is_true(format:can_export(story))
    end)

    it("returns false for nil", function()
      assert.is_false(format:can_export(nil))
    end)

    it("returns false for non-table", function()
      assert.is_false(format:can_export("not a story"))
    end)
  end)

  describe("export", function()
    local format

    before_each(function()
      format = JsonFormat.new(nil)
    end)

    it("exports simple story", function()
      local story = Story.create({ title = "Export Test" })
      local passage = Passage.create({
        id = "start",
        name = "Start",
        content = "Hello World"
      })
      story:add_passage(passage)
      story.start_passage = "start"

      local json = format:export(story)

      assert.is_string(json)
      assert.is_true(#json > 0)
      assert.is_truthy(json:find("Export Test"))
    end)

    it("exports story with choices", function()
      local story = Story.create({ title = "Choice Test" })
      local passage = Passage.create({
        id = "start",
        name = "Start",
        content = "Choose"
      })
      passage:add_choice(Choice.create({ text = "Option A", target = "a" }))
      passage:add_choice(Choice.create({ text = "Option B", target = "b" }))
      story:add_passage(passage)
      story.start_passage = "start"

      local json = format:export(story)

      assert.is_truthy(json:find("Option A"))
      assert.is_truthy(json:find("Option B"))
    end)

    it("round-trips story correctly", function()
      local original = Story.create({ title = "Round Trip" })
      local passage = Passage.create({
        id = "start",
        name = "Start Passage",
        content = "Test content"
      })
      passage:add_choice(Choice.create({ text = "Next", target = "next" }))
      original:add_passage(passage)
      original.start_passage = "start"

      local json = format:export(original)
      local imported = format:import(json)

      assert.equals("Round Trip", imported.metadata.name)
      local p = imported:get_passage("start")
      assert.equals("Test content", p.content)
      assert.equals(1, #p:get_choices())
    end)
  end)

  describe("event emission", function()
    local format, events, emitted

    before_each(function()
      local container = TestContainer.create()
      events = container:resolve("events")
      format = JsonFormat.new(container)
      emitted = {}

      events:on("format:*", function(data)
        table.insert(emitted, data)
      end)
    end)

    it("emits format:imported on import", function()
      local json = '{"passages": [], "metadata": {"name": "Test"}}'
      format:import(json)

      assert.equals(1, #emitted)
      assert.equals("json", emitted[1].format)
    end)

    it("emits format:exported on export", function()
      local story = Story.create({ title = "Test" })
      story:add_passage(Passage.create({ id = "start" }))
      format:export(story)

      assert.equals(1, #emitted)
      assert.equals("json", emitted[1].format)
    end)
  end)
end)
