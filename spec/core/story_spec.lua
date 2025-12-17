-- spec/core/story_spec.lua
-- Unit tests for Story module

describe("Story", function()
  local Story

  before_each(function()
    package.loaded["whisker.core.story"] = nil
    Story = require("whisker.core.story")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(Story._whisker)
      assert.are.equal("Story", Story._whisker.name)
      assert.is_string(Story._whisker.version)
      assert.is_table(Story._whisker.depends)
    end)

    it("should have no dependencies", function()
      assert.are.equal(0, #Story._whisker.depends)
    end)
  end)

  describe("new", function()
    it("should create with default values", function()
      local s = Story.new()
      assert.is_table(s.metadata)
      assert.is_table(s.passages)
      assert.is_table(s.variables)
    end)

    it("should create with title option", function()
      local s = Story.new({title = "My Story"})
      assert.are.equal("My Story", s.metadata.name)
    end)

    it("should create with name option", function()
      local s = Story.new({name = "My Story"})
      assert.are.equal("My Story", s.metadata.name)
    end)

    it("should create with all metadata", function()
      local s = Story.new({
        title = "Test",
        author = "Author",
        version = "2.0.0",
        ifid = "12345"
      })
      assert.are.equal("Test", s.metadata.name)
      assert.are.equal("Author", s.metadata.author)
      assert.are.equal("2.0.0", s.metadata.version)
      assert.are.equal("12345", s.metadata.ifid)
    end)

    it("should initialize event emitter as nil", function()
      local s = Story.new()
      assert.is_nil(s._event_emitter)
    end)
  end)

  describe("metadata", function()
    it("should set and get metadata", function()
      local s = Story.new()
      s:set_metadata("custom", "value")
      assert.are.equal("value", s:get_metadata("custom"))
    end)
  end)

  describe("passages", function()
    it("should add passage", function()
      local s = Story.new()
      local p = {id = "test", name = "Test"}
      s:add_passage(p)
      assert.are.equal(p, s:get_passage("test"))
    end)

    it("should error on invalid passage", function()
      local s = Story.new()
      assert.has_error(function() s:add_passage(nil) end)
      assert.has_error(function() s:add_passage({}) end)
    end)

    it("should remove passage", function()
      local s = Story.new()
      s:add_passage({id = "test", name = "Test"})
      s:remove_passage("test")
      assert.is_nil(s:get_passage("test"))
    end)

    it("should get all passages", function()
      local s = Story.new()
      s:add_passage({id = "p1", name = "P1"})
      s:add_passage({id = "p2", name = "P2"})
      local all = s:get_all_passages()
      assert.are.equal(2, #all)
    end)
  end)

  describe("start_passage", function()
    it("should set and get start passage", function()
      local s = Story.new()
      s:add_passage({id = "start", name = "Start"})
      s:set_start_passage("start")
      assert.are.equal("start", s:get_start_passage())
    end)

    it("should error when setting non-existent start", function()
      local s = Story.new()
      assert.has_error(function() s:set_start_passage("nonexistent") end)
    end)

    it("should return first passage if no start set", function()
      local s = Story.new()
      s:add_passage({id = "first", name = "First"})
      assert.is_not_nil(s:get_start_passage())
    end)
  end)

  describe("variables", function()
    it("should set and get variable", function()
      local s = Story.new()
      s:set_variable("score", 100)
      assert.are.equal(100, s:get_variable("score"))
    end)

    it("should get variable value from typed format", function()
      local s = Story.new()
      s:set_typed_variable("health", "number", 50)
      assert.are.equal(50, s:get_variable_value("health"))
    end)

    it("should set typed variable", function()
      local s = Story.new()
      s:set_typed_variable("name", "string", "Player")
      local var = s:get_variable("name")
      assert.are.equal("string", var.type)
      assert.are.equal("Player", var.default)
    end)

    it("should migrate variables to typed format", function()
      local s = Story.new({variables = {score = 100}})
      s:migrate_variables_to_typed()
      local var = s:get_variable("score")
      assert.are.equal("number", var.type)
      assert.are.equal(100, var.default)
    end)

    it("should convert variables to simple format", function()
      local s = Story.new()
      s:set_typed_variable("score", "number", 100)
      local simple = s:variables_to_simple()
      assert.are.equal(100, simple.score)
    end)
  end)

  describe("stylesheets and scripts", function()
    it("should add stylesheet", function()
      local s = Story.new()
      s:add_stylesheet("body { color: red; }")
      assert.are.equal(1, #s.stylesheets)
    end)

    it("should add script", function()
      local s = Story.new()
      s:add_script("console.log('hello');")
      assert.are.equal(1, #s.scripts)
    end)
  end)

  describe("assets", function()
    it("should add asset", function()
      local s = Story.new()
      s:add_asset({id = "img1", type = "image"})
      assert.is_not_nil(s:get_asset("img1"))
    end)

    it("should error on invalid asset", function()
      local s = Story.new()
      assert.has_error(function() s:add_asset(nil) end)
      assert.has_error(function() s:add_asset({}) end)
    end)

    it("should remove asset", function()
      local s = Story.new()
      s:add_asset({id = "img1"})
      s:remove_asset("img1")
      assert.is_nil(s:get_asset("img1"))
    end)

    it("should list assets", function()
      local s = Story.new()
      s:add_asset({id = "img1"})
      s:add_asset({id = "img2"})
      assert.are.equal(2, #s:list_assets())
    end)

    it("should check has asset", function()
      local s = Story.new()
      s:add_asset({id = "img1"})
      assert.is_true(s:has_asset("img1"))
      assert.is_false(s:has_asset("img2"))
    end)
  end)

  describe("tags", function()
    it("should add tag", function()
      local s = Story.new()
      s:add_tag("horror")
      assert.is_true(s:has_tag("horror"))
    end)

    it("should error on empty tag", function()
      local s = Story.new()
      assert.has_error(function() s:add_tag("") end)
    end)

    it("should remove tag", function()
      local s = Story.new()
      s:add_tag("horror")
      s:remove_tag("horror")
      assert.is_false(s:has_tag("horror"))
    end)

    it("should get all tags sorted", function()
      local s = Story.new()
      s:add_tag("z-tag")
      s:add_tag("a-tag")
      local tags = s:get_all_tags()
      assert.are.equal("a-tag", tags[1])
      assert.are.equal("z-tag", tags[2])
    end)

    it("should clear tags", function()
      local s = Story.new()
      s:add_tag("horror")
      s:clear_tags()
      assert.are.equal(0, #s:get_all_tags())
    end)
  end)

  describe("settings", function()
    it("should set and get setting", function()
      local s = Story.new()
      s:set_setting("difficulty", "hard")
      assert.are.equal("hard", s:get_setting("difficulty"))
    end)

    it("should return default for missing setting", function()
      local s = Story.new()
      assert.are.equal("easy", s:get_setting("difficulty", "easy"))
    end)

    it("should check has setting", function()
      local s = Story.new()
      s:set_setting("key", "value")
      assert.is_true(s:has_setting("key"))
      assert.is_false(s:has_setting("missing"))
    end)

    it("should delete setting", function()
      local s = Story.new()
      s:set_setting("key", "value")
      assert.is_true(s:delete_setting("key"))
      assert.is_false(s:has_setting("key"))
    end)

    it("should get all settings", function()
      local s = Story.new()
      s:set_setting("a", 1)
      s:set_setting("b", 2)
      local all = s:get_all_settings()
      assert.are.equal(1, all.a)
      assert.are.equal(2, all.b)
    end)

    it("should clear settings", function()
      local s = Story.new()
      s:set_setting("key", "value")
      s:clear_settings()
      assert.is_false(s:has_setting("key"))
    end)
  end)

  describe("event emitter", function()
    it("should set and get event emitter", function()
      local s = Story.new()
      local emitter = {}
      s:set_event_emitter(emitter)
      assert.are.equal(emitter, s:get_event_emitter())
    end)

    it("should emit event on add_passage", function()
      local s = Story.new()
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:add_passage({id = "test", name = "Test"})
      assert.are.equal("story:passage_added", emitted.event)
      assert.is_true(emitted.data.is_new)
    end)

    it("should emit event on remove_passage", function()
      local s = Story.new()
      s:add_passage({id = "test", name = "Test"})
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:remove_passage("test")
      assert.are.equal("story:passage_removed", emitted.event)
      assert.are.equal("test", emitted.data.passage_id)
    end)

    it("should emit event on set_start_passage", function()
      local s = Story.new()
      s:add_passage({id = "test", name = "Test"})
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:set_start_passage("test")
      assert.are.equal("story:start_changed", emitted.event)
      assert.are.equal("test", emitted.data.new_start)
    end)

    it("should emit event on set_variable", function()
      local s = Story.new()
      local emitted = nil
      s:set_event_emitter({
        emit = function(_, event, data)
          emitted = {event = event, data = data}
        end
      })
      s:set_variable("score", 100)
      assert.are.equal("story:variable_changed", emitted.event)
      assert.are.equal("score", emitted.data.key)
      assert.are.equal(100, emitted.data.new_value)
    end)

    it("should not emit when no emitter set", function()
      local s = Story.new()
      -- Should not error even without emitter
      s:add_passage({id = "test", name = "Test"})
      s:remove_passage("test")
    end)
  end)

  describe("validate", function()
    it("should pass for valid story", function()
      local s = Story.new({title = "Test"})
      s:add_passage({id = "start", name = "Start", validate = function() return true end})
      s:set_start_passage("start")
      local valid, _ = s:validate()
      assert.is_true(valid)
    end)

    it("should fail for missing name", function()
      local s = Story.new()
      s.metadata.name = ""
      local valid, err = s:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("name"))
    end)

    it("should fail for missing start passage", function()
      local s = Story.new({title = "Test"})
      local valid, err = s:validate()
      assert.is_false(valid)
      assert.is_truthy(err:match("Start passage"))
    end)
  end)

  describe("serialize", function()
    it("should return plain table", function()
      local s = Story.new({title = "Test"})
      s:add_passage({id = "start", name = "Start"})
      local data = s:serialize()
      assert.is_table(data.metadata)
      assert.is_table(data.passages)
    end)
  end)

  describe("deserialize", function()
    it("should restore story from data", function()
      local s = Story.new()
      s:deserialize({
        metadata = {name = "Restored"},
        passages = {start = {id = "start", name = "Start"}},
        start_passage = "start"
      })
      assert.are.equal("Restored", s.metadata.name)
      assert.is_not_nil(s.passages.start)
    end)

    it("should use passage_restorer if provided", function()
      local s = Story.new()
      local restorer_called = false
      s:deserialize({
        passages = {test = {id = "test"}}
      }, function(data)
        restorer_called = true
        return data
      end)
      assert.is_true(restorer_called)
    end)
  end)

  describe("restore_metatable", function()
    it("should restore metatable to plain table", function()
      local data = {metadata = {name = "Test"}, passages = {}}
      local restored = Story.restore_metatable(data)
      assert.are.equal(Story, getmetatable(restored))
      assert.are.equal("Test", restored:get_metadata("name"))
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Story.restore_metatable(nil))
    end)

    it("should return as-is if already has metatable", function()
      local s = Story.new({title = "Test"})
      local restored = Story.restore_metatable(s)
      assert.are.equal(s, restored)
    end)
  end)

  describe("from_table", function()
    it("should create new story from table", function()
      local s = Story.from_table({
        metadata = {name = "From Table", author = "Author"}
      })
      assert.are.equal(Story, getmetatable(s))
      assert.are.equal("From Table", s.metadata.name)
    end)

    it("should return nil for nil input", function()
      assert.is_nil(Story.from_table(nil))
    end)

    it("should use passage_restorer if provided", function()
      local restorer_called = false
      local s = Story.from_table({
        passages = {test = {id = "test"}}
      }, function(data)
        restorer_called = true
        return data
      end)
      assert.is_true(restorer_called)
    end)
  end)

  describe("modularity", function()
    it("should not require any whisker modules", function()
      package.loaded["whisker.core.story"] = nil
      -- Clear potential cached requires
      package.loaded["whisker.core.passage"] = nil
      local ok, result = pcall(require, "whisker.core.story")
      assert.is_true(ok)
      assert.is_table(result)
    end)
  end)
end)
