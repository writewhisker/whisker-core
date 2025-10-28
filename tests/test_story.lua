local helper = require("tests.test_helper")
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")
local Engine = require("whisker.core.engine")
local GameState = require("whisker.core.game_state")

describe("Story Integration", function()

  local function create_test_story()
    local story = Story.new()
    story:set_metadata("name", "Test Story")
    story:set_metadata("author", "whisker Engine")
    story:set_metadata("ifid", "TEST-001")

    local start = Passage.new("start", "start")
    start:set_content("You wake up in a mysterious room. What do you do?")

    local look = Passage.new("look_around", "look_around")
    look:set_content("The room is dimly lit. You see a door and a window.")

    local door = Passage.new("try_door", "try_door")
    door:set_content("The door is locked. Game Over.")

    local choice1 = Choice.new("Look around", "look_around")
    start:add_choice(choice1)

    local choice2 = Choice.new("Try the door", "try_door")
    start:add_choice(choice2)

    local choice3 = Choice.new("Examine the window", "try_door")
    look:add_choice(choice3)

    story:add_passage(start)
    story:add_passage(look)
    story:add_passage(door)
    story:set_start_passage("start")

    return story
  end

  describe("Story Creation", function()
    it("should create a story with metadata", function()
      local story = Story.new()
      story:set_metadata("name", "Test Story")
      story:set_metadata("author", "Test Author")

      assert.equals("Test Story", story:get_metadata("name"))
      assert.equals("Test Author", story:get_metadata("author"))
    end)

    it("should add passages to story", function()
      local story = Story.new()
      local passage = Passage.new("test", "test")
      story:add_passage(passage)

      assert.is_not_nil(story:get_passage("test"))
    end)

    it("should set start passage", function()
      local story = create_test_story()
      assert.equals("start", story:get_start_passage())
    end)
  end)

  describe("Passage Creation", function()
    it("should create passage with content", function()
      local passage = Passage.new("test", "test")
      passage:set_content("Test content")

      assert.equals("Test content", passage:get_content())
    end)

    it("should add choices to passage", function()
      local passage = Passage.new("test", "test")
      local choice = Choice.new("Test choice", "target")
      passage:add_choice(choice)

      local choices = passage:get_choices()
      assert.equals(1, #choices)
    end)
  end)

  describe("Choice Creation", function()
    it("should create choice with text and target", function()
      local choice = Choice.new("Test text", "target_passage")

      assert.equals("Test text", choice:get_text())
      assert.equals("target_passage", choice:get_target())
    end)
  end)

  describe("Engine Integration", function()
    it("should create engine with story and game state", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      assert.is_not_nil(engine)
    end)

    it("should start story and return initial content", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      local content = engine:start_story()

      assert.is_not_nil(content)
      assert.is_not_nil(content.passage)
      assert.is_not_nil(content.passage.content)
    end)

    it("should display initial passage content", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      local content = engine:start_story()

      assert.is_not_nil(content.passage.content:match("mysterious room"))
    end)

    it("should provide choices from initial passage", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      local content = engine:start_story()

      assert.is_not_nil(content.choices)
      assert.is_true(#content.choices > 0)
    end)

    it("should have correct number of choices", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      local content = engine:start_story()

      assert.equals(2, #content.choices)
    end)

    it("should have properly formatted choice text", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      local content = engine:start_story()

      assert.equals("Look around", content.choices[1]:get_text())
      assert.equals("Try the door", content.choices[2]:get_text())
    end)
  end)

  describe("Full Story Flow", function()
    it("should allow navigation through story", function()
      local story = create_test_story()
      local game_state = GameState.new()
      local engine = Engine.new(story, game_state)

      local content = engine:start_story()
      assert.is_not_nil(content)

      -- Verify we can access the story structure
      assert.is_not_nil(story:get_passage("start"))
      assert.is_not_nil(story:get_passage("look_around"))
      assert.is_not_nil(story:get_passage("try_door"))
    end)
  end)

  describe("Passage Metadata Helpers (Phase 2)", function()
    it("should set and get metadata", function()
      local passage = Passage.new("test", "test")
      passage:set_metadata("difficulty", "hard")
      passage:set_metadata("background_music", "dungeon.mp3")

      assert.equals("hard", passage:get_metadata("difficulty"))
      assert.equals("dungeon.mp3", passage:get_metadata("background_music"))
    end)

    it("should return default value when key not found", function()
      local passage = Passage.new("test", "test")

      assert.equals("normal", passage:get_metadata("difficulty", "normal"))
      assert.is_nil(passage:get_metadata("nonexistent"))
    end)

    it("should check if metadata exists", function()
      local passage = Passage.new("test", "test")
      passage:set_metadata("boss_fight", true)

      assert.is_true(passage:has_metadata("boss_fight"))
      assert.is_false(passage:has_metadata("nonexistent"))
    end)

    it("should delete metadata", function()
      local passage = Passage.new("test", "test")
      passage:set_metadata("temp", "value")

      assert.is_true(passage:has_metadata("temp"))
      local deleted = passage:delete_metadata("temp")
      assert.is_true(deleted)
      assert.is_false(passage:has_metadata("temp"))

      -- Deleting non-existent key should return false
      local deleted_again = passage:delete_metadata("temp")
      assert.is_false(deleted_again)
    end)

    it("should clear all metadata", function()
      local passage = Passage.new("test", "test")
      passage:set_metadata("key1", "value1")
      passage:set_metadata("key2", "value2")
      passage:set_metadata("key3", "value3")

      assert.is_true(passage:has_metadata("key1"))
      assert.is_true(passage:has_metadata("key2"))

      passage:clear_metadata()

      assert.is_false(passage:has_metadata("key1"))
      assert.is_false(passage:has_metadata("key2"))
      assert.is_false(passage:has_metadata("key3"))
    end)

    it("should get all metadata as copy", function()
      local passage = Passage.new("test", "test")
      passage:set_metadata("difficulty", "hard")
      passage:set_metadata("points", 100)
      passage:set_metadata("boss", true)

      local metadata = passage:get_all_metadata()

      assert.equals("hard", metadata.difficulty)
      assert.equals(100, metadata.points)
      assert.is_true(metadata.boss)

      -- Verify it's a copy (modifying returned table shouldn't affect original)
      metadata.new_key = "new_value"
      assert.is_false(passage:has_metadata("new_key"))
    end)
  end)

  describe("Choice Metadata Helpers (Phase 2)", function()
    it("should set and get metadata", function()
      local choice = Choice.new("Test", "target")
      choice:set_metadata("points", 50)
      choice:set_metadata("difficulty", "hard")
      choice:set_metadata("icon", "⚔️")

      assert.equals(50, choice:get_metadata("points"))
      assert.equals("hard", choice:get_metadata("difficulty"))
      assert.equals("⚔️", choice:get_metadata("icon"))
    end)

    it("should return default value when key not found", function()
      local choice = Choice.new("Test", "target")

      assert.equals(0, choice:get_metadata("points", 0))
      assert.equals("➡️", choice:get_metadata("icon", "➡️"))
      assert.is_nil(choice:get_metadata("nonexistent"))
    end)

    it("should check if metadata exists", function()
      local choice = Choice.new("Test", "target")
      choice:set_metadata("achievement", "first_win")

      assert.is_true(choice:has_metadata("achievement"))
      assert.is_false(choice:has_metadata("nonexistent"))
    end)

    it("should delete metadata", function()
      local choice = Choice.new("Test", "target")
      choice:set_metadata("temp", "value")

      assert.is_true(choice:has_metadata("temp"))
      local deleted = choice:delete_metadata("temp")
      assert.is_true(deleted)
      assert.is_false(choice:has_metadata("temp"))

      -- Deleting non-existent key should return false
      local deleted_again = choice:delete_metadata("temp")
      assert.is_false(deleted_again)
    end)

    it("should clear all metadata", function()
      local choice = Choice.new("Test", "target")
      choice:set_metadata("key1", "value1")
      choice:set_metadata("key2", "value2")
      choice:set_metadata("key3", "value3")

      assert.is_true(choice:has_metadata("key1"))
      assert.is_true(choice:has_metadata("key2"))

      choice:clear_metadata()

      assert.is_false(choice:has_metadata("key1"))
      assert.is_false(choice:has_metadata("key2"))
      assert.is_false(choice:has_metadata("key3"))
    end)

    it("should get all metadata as copy", function()
      local choice = Choice.new("Test", "target")
      choice:set_metadata("points", 50)
      choice:set_metadata("type", "combat")
      choice:set_metadata("risk", "high")

      local metadata = choice:get_all_metadata()

      assert.equals(50, metadata.points)
      assert.equals("combat", metadata.type)
      assert.equals("high", metadata.risk)

      -- Verify it's a copy
      metadata.new_key = "new_value"
      assert.is_false(choice:has_metadata("new_key"))
    end)
  end)

  describe("Story Asset Management (Phase 2)", function()
    it("should add and get assets", function()
      local story = Story.new()
      local asset = {
        id = "hero_image",
        name = "Hero Portrait",
        path = "assets/images/hero.png",
        mimeType = "image/png",
        size = 45678
      }

      story:add_asset(asset)
      local retrieved = story:get_asset("hero_image")

      assert.is_not_nil(retrieved)
      assert.equals("hero_image", retrieved.id)
      assert.equals("Hero Portrait", retrieved.name)
      assert.equals("assets/images/hero.png", retrieved.path)
    end)

    it("should error when adding asset without id", function()
      local story = Story.new()
      local asset = {
        name = "Invalid Asset",
        path = "assets/image.png"
      }

      assert.has_error(function()
        story:add_asset(asset)
      end, "Invalid asset: missing id")
    end)

    it("should remove assets", function()
      local story = Story.new()
      local asset = {
        id = "temp_image",
        name = "Temporary Image",
        path = "assets/temp.png",
        mimeType = "image/png",
        size = 1234
      }

      story:add_asset(asset)
      assert.is_not_nil(story:get_asset("temp_image"))

      story:remove_asset("temp_image")
      assert.is_nil(story:get_asset("temp_image"))
    end)

    it("should list all assets", function()
      local story = Story.new()

      story:add_asset({
        id = "image1",
        name = "Image 1",
        path = "assets/1.png",
        mimeType = "image/png",
        size = 1000
      })

      story:add_asset({
        id = "audio1",
        name = "Audio 1",
        path = "assets/1.mp3",
        mimeType = "audio/mpeg",
        size = 2000
      })

      story:add_asset({
        id = "video1",
        name = "Video 1",
        path = "assets/1.mp4",
        mimeType = "video/mp4",
        size = 3000
      })

      local assets = story:list_assets()
      assert.equals(3, #assets)
    end)

    it("should check if asset exists", function()
      local story = Story.new()
      story:add_asset({
        id = "test_asset",
        name = "Test",
        path = "test.png",
        mimeType = "image/png",
        size = 100
      })

      assert.is_true(story:has_asset("test_asset"))
      assert.is_false(story:has_asset("nonexistent"))
    end)

    it("should find asset references in passage content", function()
      local story = Story.new()

      story:add_asset({
        id = "hero_img",
        name = "Hero",
        path = "hero.png",
        mimeType = "image/png",
        size = 100
      })

      local passage = Passage.new("test", "test")
      passage:set_content("Here is an image: ![Hero](asset://hero_img)")
      story:add_passage(passage)

      local refs = story:get_asset_references("hero_img")
      assert.equals(1, #refs)
      assert.equals("passage_content", refs[1].type)
      assert.equals("test", refs[1].passage_id)
    end)

    it("should find asset references in on_enter_script", function()
      local story = Story.new()

      story:add_asset({
        id = "bg_music",
        name = "Background Music",
        path = "music.mp3",
        mimeType = "audio/mpeg",
        size = 5000
      })

      local passage = Passage.new("test", "test")
      passage:set_on_enter_script("playAudio('asset://bg_music')")
      story:add_passage(passage)

      local refs = story:get_asset_references("bg_music")
      assert.equals(1, #refs)
      assert.equals("on_enter_script", refs[1].type)
      assert.equals("test", refs[1].passage_id)
    end)

    it("should find asset references in on_exit_script", function()
      local story = Story.new()

      story:add_asset({
        id = "exit_sound",
        name = "Exit Sound",
        path = "exit.mp3",
        mimeType = "audio/mpeg",
        size = 1000
      })

      local passage = Passage.new("test", "test")
      passage:set_on_exit_script("playSound('asset://exit_sound')")
      story:add_passage(passage)

      local refs = story:get_asset_references("exit_sound")
      assert.equals(1, #refs)
      assert.equals("on_exit_script", refs[1].type)
      assert.equals("test", refs[1].passage_id)
    end)

    it("should find multiple references across passages", function()
      local story = Story.new()

      story:add_asset({
        id = "common_img",
        name = "Common Image",
        path = "common.png",
        mimeType = "image/png",
        size = 2000
      })

      local passage1 = Passage.new("p1", "p1")
      passage1:set_content("Image: asset://common_img")
      story:add_passage(passage1)

      local passage2 = Passage.new("p2", "p2")
      passage2:set_on_enter_script("load('asset://common_img')")
      story:add_passage(passage2)

      local passage3 = Passage.new("p3", "p3")
      passage3:set_content("Another reference: asset://common_img")
      story:add_passage(passage3)

      local refs = story:get_asset_references("common_img")
      assert.equals(3, #refs)
    end)

    it("should return empty array for unreferenced assets", function()
      local story = Story.new()

      story:add_asset({
        id = "unused",
        name = "Unused Asset",
        path = "unused.png",
        mimeType = "image/png",
        size = 100
      })

      local refs = story:get_asset_references("unused")
      assert.equals(0, #refs)
    end)

    it("should serialize assets with story", function()
      local story = Story.new()

      story:add_asset({
        id = "test_asset",
        name = "Test Asset",
        path = "test.png",
        mimeType = "image/png",
        size = 1234,
        metadata = {
          width = 100,
          height = 100
        }
      })

      local serialized = story:serialize()
      assert.is_not_nil(serialized.assets)
      assert.is_not_nil(serialized.assets.test_asset)
      assert.equals("Test Asset", serialized.assets.test_asset.name)
      assert.equals(100, serialized.assets.test_asset.metadata.width)
    end)
  end)

  describe("Story Tag Management", function()
    it("should add tags to story", function()
      local story = Story.new()
      story:add_tag("adventure")
      story:add_tag("fantasy")

      assert.is_true(story:has_tag("adventure"))
      assert.is_true(story:has_tag("fantasy"))
    end)

    it("should remove tags from story", function()
      local story = Story.new()
      story:add_tag("test")
      assert.is_true(story:has_tag("test"))

      story:remove_tag("test")
      assert.is_false(story:has_tag("test"))
    end)

    it("should get all tags sorted", function()
      local story = Story.new()
      story:add_tag("zebra")
      story:add_tag("apple")
      story:add_tag("banana")

      local tags = story:get_all_tags()
      assert.equals(3, #tags)
      assert.equals("apple", tags[1])
      assert.equals("banana", tags[2])
      assert.equals("zebra", tags[3])
    end)

    it("should clear all tags", function()
      local story = Story.new()
      story:add_tag("tag1")
      story:add_tag("tag2")

      story:clear_tags()
      local tags = story:get_all_tags()
      assert.equals(0, #tags)
    end)

    it("should error on empty tag", function()
      local story = Story.new()
      assert.has_error(function()
        story:add_tag("")
      end)
    end)

    it("should serialize tags with story", function()
      local story = Story.new()
      story:add_tag("horror")
      story:add_tag("mystery")

      local serialized = story:serialize()
      assert.is_not_nil(serialized.tags)
      assert.is_true(serialized.tags.horror)
      assert.is_true(serialized.tags.mystery)
    end)
  end)

  describe("Story Settings Management", function()
    it("should set and get settings", function()
      local story = Story.new()
      story:set_setting("difficulty", "hard")
      story:set_setting("music_volume", 0.8)

      assert.equals("hard", story:get_setting("difficulty"))
      assert.equals(0.8, story:get_setting("music_volume"))
    end)

    it("should return default value when setting not found", function()
      local story = Story.new()
      assert.equals("default", story:get_setting("missing", "default"))
      assert.equals(100, story:get_setting("points", 100))
    end)

    it("should check if setting exists", function()
      local story = Story.new()
      story:set_setting("test", true)

      assert.is_true(story:has_setting("test"))
      assert.is_false(story:has_setting("nonexistent"))
    end)

    it("should delete settings", function()
      local story = Story.new()
      story:set_setting("temp", "value")
      assert.is_true(story:has_setting("temp"))

      local deleted = story:delete_setting("temp")
      assert.is_true(deleted)
      assert.is_false(story:has_setting("temp"))

      local not_deleted = story:delete_setting("nonexistent")
      assert.is_false(not_deleted)
    end)

    it("should get all settings as copy", function()
      local story = Story.new()
      story:set_setting("key1", "value1")
      story:set_setting("key2", "value2")

      local settings = story:get_all_settings()
      assert.equals("value1", settings.key1)
      assert.equals("value2", settings.key2)

      -- Modifying copy should not affect original
      settings.key1 = "modified"
      assert.equals("value1", story:get_setting("key1"))
    end)

    it("should clear all settings", function()
      local story = Story.new()
      story:set_setting("s1", 1)
      story:set_setting("s2", 2)

      story:clear_settings()
      local settings = story:get_all_settings()
      assert.equals(0, helper.count_table(settings))
    end)

    it("should error on empty setting key", function()
      local story = Story.new()
      assert.has_error(function()
        story:set_setting("", "value")
      end)
    end)

    it("should serialize settings with story", function()
      local story = Story.new()
      story:set_setting("theme", "dark")
      story:set_setting("autoSave", true)

      local serialized = story:serialize()
      assert.is_not_nil(serialized.settings)
      assert.equals("dark", serialized.settings.theme)
      assert.equals(true, serialized.settings.autoSave)
    end)
  end)

  describe("Variable Usage Tracking", function()
    it("should find variable usage in passage content", function()
      local story = Story.new()
      story:set_variable("health", 100)

      local passage = Passage.new("p1", "p1")
      passage:set_content("Your health is $health")
      story:add_passage(passage)

      local usage = story:get_variable_usage("health")
      assert.equals(1, #usage)
      assert.equals("p1", usage[1].passage_id)
      assert.is_true(helper.array_contains(usage[1].locations, "content"))
    end)

    it("should find variable usage in scripts", function()
      local story = Story.new()
      story:set_variable("score", 0)

      local passage = Passage.new("p1", "p1")
      passage:set_on_enter_script("score = score + 10")
      passage:set_on_exit_script("print(score)")
      story:add_passage(passage)

      local usage = story:get_variable_usage("score")
      assert.equals(1, #usage)
      assert.is_true(helper.array_contains(usage[1].locations, "on_enter_script"))
      assert.is_true(helper.array_contains(usage[1].locations, "on_exit_script"))
    end)

    it("should find variable usage in choice conditions and actions", function()
      local story = Story.new()
      story:set_variable("hasKey", false)

      local passage = Passage.new("p1", "p1")
      local choice = Choice.new("Open door", "p2")
      choice:set_condition("hasKey == true")
      choice:set_action("hasKey = false")
      passage:add_choice(choice)
      story:add_passage(passage)

      local usage = story:get_variable_usage("hasKey")
      assert.equals(1, #usage)
      assert.is_true(helper.array_contains(usage[1].locations, "choice_condition"))
      assert.is_true(helper.array_contains(usage[1].locations, "choice_action"))
    end)

    it("should return empty array for unused variables", function()
      local story = Story.new()
      story:set_variable("unused", 0)

      local usage = story:get_variable_usage("unused")
      assert.equals(0, #usage)
    end)

    it("should get all variable usage", function()
      local story = Story.new()
      story:set_variable("health", 100)
      story:set_variable("mana", 50)

      local p1 = Passage.new("p1", "p1")
      p1:set_content("Health: $health")
      story:add_passage(p1)

      local p2 = Passage.new("p2", "p2")
      p2:set_content("Mana: $mana")
      story:add_passage(p2)

      local all_usage = story:get_all_variable_usage()
      assert.is_not_nil(all_usage.health)
      assert.is_not_nil(all_usage.mana)
      assert.equals(1, #all_usage.health)
      assert.equals(1, #all_usage.mana)
    end)

    it("should get list of unused variables", function()
      local story = Story.new()
      story:set_variable("used", 1)
      story:set_variable("unused1", 2)
      story:set_variable("unused2", 3)

      local passage = Passage.new("p1", "p1")
      passage:set_content("Used: $used")
      story:add_passage(passage)

      local unused = story:get_unused_variables()
      assert.equals(2, #unused)
      assert.is_true(helper.array_contains(unused, "unused1"))
      assert.is_true(helper.array_contains(unused, "unused2"))
    end)

    it("should return sorted list of unused variables", function()
      local story = Story.new()
      story:set_variable("zebra", 1)
      story:set_variable("apple", 2)
      story:set_variable("banana", 3)

      local unused = story:get_unused_variables()
      assert.equals(3, #unused)
      assert.equals("apple", unused[1])
      assert.equals("banana", unused[2])
      assert.equals("zebra", unused[3])
    end)
  end)
end)
