--- ChoiceScript Importer Tests
-- Tests for importing ChoiceScript format stories
-- @module tests.test_choicescript_importer

local helper = require("tests.test_helper")
local ChoiceScriptImporter = require("whisker.import.choicescript")

describe("ChoiceScriptImporter", function()
  local importer

  before_each(function()
    importer = ChoiceScriptImporter.new()
  end)

  describe("metadata", function()
    it("should have correct name and extensions", function()
      local meta = importer:metadata()
      assert.equals("choicescript", meta.name)
      assert.equals("1.0.0", meta.version)
      assert.is_true(#meta.extensions > 0)
      assert.equals(".txt", meta.extensions[1])
    end)
  end)

  describe("can_import", function()
    it("should detect ChoiceScript content with labels", function()
      local cs = [[
*label start
Hello world!
*goto end

*label end
The End.
]]
      local can, err = importer:can_import(cs)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should detect ChoiceScript content with choices", function()
      local cs = [[
*choice
  #Go north
    *goto north
  #Go south
    *goto south
]]
      local can, err = importer:can_import(cs)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should detect ChoiceScript content with variables", function()
      local cs = [[
*create strength 50
*create name "Player"
*set strength + 10
]]
      local can, err = importer:can_import(cs)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should detect title and author", function()
      local cs = [[
*title My Game
*author Jane Doe
*label start
Welcome!
]]
      local can, err = importer:can_import(cs)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should not detect non-ChoiceScript content", function()
      local html = "<html><body>Hello</body></html>"
      local can, err = importer:can_import(html)
      assert.is_false(can)
      assert.is_not_nil(err)
    end)

    it("should not detect JSON content", function()
      local json = '{"story": {}}'
      local can, err = importer:can_import(json)
      assert.is_false(can)
    end)

    it("should reject empty content", function()
      local can, err = importer:can_import("")
      assert.is_false(can)
      assert.is_not_nil(err)
    end)
  end)

  describe("detect", function()
    it("should return true for ChoiceScript content", function()
      local cs = [[
*label start
Hello!
*finish
]]
      assert.is_true(importer:detect(cs))
    end)

    it("should return false for non-ChoiceScript content", function()
      local html = "<div>Hello</div>"
      assert.is_false(importer:detect(html))
    end)
  end)

  describe("validate", function()
    it("should pass valid ChoiceScript content", function()
      local cs = [[
*label start
Hello!
*finish
]]
      local errors = importer:validate(cs)
      assert.equals(0, #errors)
    end)

    it("should fail on empty content", function()
      local errors = importer:validate("")
      assert.is_true(#errors > 0)
      local has_empty_error = false
      for _, err in ipairs(errors) do
        if err:find("Empty") then
          has_empty_error = true
          break
        end
      end
      assert.is_true(has_empty_error)
    end)
  end)

  describe("import", function()
    it("should import basic label", function()
      local cs = [[
*label start
Hello, world!
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage)
      assert.is_true(passage.content:find("Hello, world!") ~= nil)
    end)

    it("should import multiple labels", function()
      local cs = [[
*label start
Beginning.
*goto middle

*label middle
Middle part.
*goto ending

*label ending
The end.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("start"))
      assert.is_not_nil(story:get_passage("middle"))
      assert.is_not_nil(story:get_passage("ending"))
    end)

    it("should import variables", function()
      local cs = [[
*create score 0
*create name "Player"
*create hasKey false

*label start
Hello {name}!
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      assert.is_not_nil(story.variables.score)
      assert.is_not_nil(story.variables.name)
      assert.is_not_nil(story.variables.hasKey)
    end)

    it("should import temp variables", function()
      local cs = [[
*temp counter 5

*label start
Count: {counter}
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      assert.is_not_nil(story.variables.counter)
    end)

    it("should parse variable types correctly", function()
      local cs = [[
*create score 42
*create name "Player"
*create hasKey false
*create ratio 3.14

*label start
Test
]]
      local story = importer:import(cs)

      assert.equals("number", story.variables.score.type)
      assert.equals(42, story.variables.score.default)
      assert.equals("string", story.variables.name.type)
      assert.equals("Player", story.variables.name.default)
      assert.equals("boolean", story.variables.hasKey.type)
      assert.equals(false, story.variables.hasKey.default)
      assert.equals("number", story.variables.ratio.type)
    end)

    it("should convert *set commands", function()
      local cs = [[
*label start
*set score 10
*set score + 5
You have ${score} points.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("{do score = 10}") ~= nil)
      assert.is_true(passage.content:find("{do score = score %+ 5}") ~= nil)
    end)

    it("should import title and author", function()
      local cs = [[
*title Adventure Game
*author John Smith

*label start
Welcome!
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      assert.equals("Adventure Game", story.metadata.name)
      assert.equals("John Smith", story.metadata.author)
    end)

    it("should convert *finish to END link", function()
      local cs = [[
*label start
The story is over.
*finish
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("-> END") ~= nil)
    end)

    it("should convert *ending with message", function()
      local cs = [[
*label start
You win!
*ending Victory!
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("Victory!") ~= nil)
      assert.is_true(passage.content:find("-> END") ~= nil)
    end)

    it("should convert *page_break", function()
      local cs = [[
*label start
Part one.
*page_break
Part two.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("%-%-%-") ~= nil)
    end)

    it("should convert *goto to link", function()
      local cs = [[
*label start
Hello.
*goto next

*label next
World.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("-> next") ~= nil)
    end)

    it("should convert *rand to random()", function()
      local cs = [[
*label start
*rand dice 1 6
You rolled ${dice}.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("random%(1, 6%)") ~= nil)
    end)

    it("should report issues for fairmath operators", function()
      local cs = [[
*label start
*set morale %+ 10
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      assert.is_true(#report.warnings > 0)

      local has_fairmath_warning = false
      for _, warning in ipairs(report.warnings) do
        if warning.message and warning.message:find("Fairmath") then
          has_fairmath_warning = true
          break
        end
      end
      assert.is_true(has_fairmath_warning)
    end)

    it("should report issues for *goto_scene", function()
      local cs = [[
*label start
*goto_scene chapter2
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      assert.is_true(#report.warnings > 0)

      local has_scene_warning = false
      for _, warning in ipairs(report.warnings) do
        if warning.message and warning.message:find("scene") then
          has_scene_warning = true
          break
        end
      end
      assert.is_true(has_scene_warning)
    end)

    it("should set start passage correctly", function()
      local cs = [[
*label startup
This is the beginning.
*goto main

*label main
Main content.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      -- "startup" should be recognized as start passage
      assert.equals("startup", story.start_passage)
    end)

    it("should handle content without labels", function()
      local cs = [[
Hello world!
This is a simple story.
*finish
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      -- Should create implicit "start" label
      assert.is_not_nil(story:get_passage("start"))
    end)

    it("should convert variable interpolation", function()
      local cs = [[
*label start
Hello {name}, you have {score} points.
]]
      local story = importer:import(cs)

      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("%${name}") ~= nil)
      assert.is_true(passage.content:find("%${score}") ~= nil)
    end)

    it("should handle *if conditionals", function()
      local cs = [[
*label start
*if strength > 50
  You are strong!
]]
      local story = importer:import(cs)

      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("{if") ~= nil)
    end)

    it("should convert *image command", function()
      local cs = [[
*label start
*image hero.png
]]
      local story = importer:import(cs)

      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("{image hero.png}") ~= nil)
    end)

    it("should convert *sound command", function()
      local cs = [[
*label start
*sound music.mp3
]]
      local story = importer:import(cs)

      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("{audio music.mp3}") ~= nil)
    end)

    it("should handle *comment", function()
      local cs = [[
*label start
*comment This is a note
Hello!
]]
      local story = importer:import(cs)

      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("<!%-%-") ~= nil)
    end)
  end)

  describe("choice parsing", function()
    it("should import basic choices", function()
      local cs = [[
*label start
What do you do?
*choice
  #Go north
    *goto north
  #Go south
    *goto south

*label north
You went north.

*label south
You went south.
]]
      local story = importer:import(cs)

      assert.is_not_nil(story)
      local start_passage = story:get_passage("start")
      assert.is_not_nil(start_passage)
      assert.is_true(#start_passage.choices >= 2)

      -- Verify choices have correct text
      local has_north = false
      local has_south = false
      for _, choice in ipairs(start_passage.choices) do
        if choice.text == "Go north" then has_north = true end
        if choice.text == "Go south" then has_south = true end
      end
      assert.is_true(has_north)
      assert.is_true(has_south)
    end)
  end)

  describe("loss report", function()
    it("should calculate conversion quality", function()
      local cs = [[
*label start
Simple story.
]]
      importer:import(cs)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      assert.is_not_nil(report.conversion_quality)
      assert.is_true(report.conversion_quality >= 0)
      assert.is_true(report.conversion_quality <= 1)
    end)

    it("should track affected passages", function()
      local cs = [[
*label start
*goto_scene other_scene

*label next
Content.
]]
      importer:import(cs)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      local has_start = false
      for _, p in ipairs(report.affected_passages) do
        if p == "start" then
          has_start = true
          break
        end
      end
      assert.is_true(has_start)
    end)

    it("should have lower quality when there are warnings", function()
      local cs_with_issues = [[
*label start
*goto_scene scene1
*goto_scene scene2
*set morale %+ 10
]]
      importer:import(cs_with_issues)
      local report_with_issues = importer:get_loss_report()

      local importer2 = ChoiceScriptImporter.new()
      local cs_simple = [[
*label start
Simple content.
]]
      importer2:import(cs_simple)
      local report_simple = importer2:get_loss_report()

      assert.is_true(report_with_issues.conversion_quality < report_simple.conversion_quality)
    end)
  end)

  describe("edge cases", function()
    it("should handle empty label content", function()
      local cs = [[
*label start

*label next
Content here.
]]
      local story = importer:import(cs)
      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("start"))
      assert.is_not_nil(story:get_passage("next"))
    end)

    it("should handle underscores in variable names", function()
      local cs = [[
*create player_health 100
*create max_score 0

*label start
Health: {player_health}
]]
      local story = importer:import(cs)
      assert.is_not_nil(story.variables.player_health)
      assert.is_not_nil(story.variables.max_score)
    end)

    it("should handle *gosub with warning", function()
      local cs = [[
*label start
*gosub helper

*label helper
Helper content.
]]
      local story = importer:import(cs)

      local report = importer:get_loss_report()
      local has_gosub_warning = false
      for _, warning in ipairs(report.warnings) do
        if warning.message and warning.message:find("gosub") then
          has_gosub_warning = true
          break
        end
      end
      assert.is_true(has_gosub_warning)
    end)
  end)
end)
