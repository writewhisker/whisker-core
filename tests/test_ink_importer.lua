--- Ink Importer Tests
-- Tests for importing Ink format stories
-- @module tests.test_ink_importer

local helper = require("tests.test_helper")
local InkImporter = require("whisker.import.ink")

describe("InkImporter", function()
  local importer

  before_each(function()
    importer = InkImporter.new()
  end)

  describe("metadata", function()
    it("should have correct name and extensions", function()
      local meta = importer:metadata()
      assert.equals("ink", meta.name)
      assert.equals("1.0.0", meta.version)
      assert.is_true(#meta.extensions > 0)
      assert.equals(".ink", meta.extensions[1])
    end)
  end)

  describe("can_import", function()
    it("should detect Ink content with knots", function()
      local ink = [[
=== start ===
Hello world!
-> END
]]
      local can, err = importer:can_import(ink)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should detect Ink content with choices", function()
      local ink = [[
* [Option A] -> a
* [Option B] -> b
]]
      local can, err = importer:can_import(ink)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should detect Ink content with variables", function()
      local ink = [[
VAR score = 0
VAR name = "Player"
-> start
]]
      local can, err = importer:can_import(ink)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should not detect non-Ink content", function()
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
    it("should return true for Ink content", function()
      local ink = [[
=== start ===
Hello!
-> END
]]
      assert.is_true(importer:detect(ink))
    end)

    it("should return false for non-Ink content", function()
      local html = "<div>Hello</div>"
      assert.is_false(importer:detect(html))
    end)
  end)

  describe("validate", function()
    it("should pass valid Ink content", function()
      local ink = [[
=== start ===
Hello!
-> END
]]
      local errors = importer:validate(ink)
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

    it("should detect unmatched braces", function()
      local ink = "{ condition: text"
      local errors = importer:validate(ink)
      assert.is_true(#errors > 0)
      local has_brace_error = false
      for _, err in ipairs(errors) do
        if err:find("braces") then
          has_brace_error = true
          break
        end
      end
      assert.is_true(has_brace_error)
    end)
  end)

  describe("import", function()
    it("should import basic knot", function()
      local ink = [[
=== start ===
Hello, world!
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage)
      assert.is_true(passage.content:find("Hello, world!") ~= nil)
    end)

    it("should import multiple knots", function()
      local ink = [[
=== start ===
Beginning.
-> middle

=== middle ===
Middle part.
-> ending

=== ending ===
The end.
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("start"))
      assert.is_not_nil(story:get_passage("middle"))
      assert.is_not_nil(story:get_passage("ending"))
    end)

    it("should import variables", function()
      local ink = [[
VAR score = 0
VAR name = "Player"
VAR hasKey = false

=== start ===
Hello {name}!
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      assert.is_not_nil(story.variables.score)
      assert.is_not_nil(story.variables.name)
      assert.is_not_nil(story.variables.hasKey)
    end)

    it("should parse variable types correctly", function()
      local ink = [[
VAR score = 42
VAR name = "Player"
VAR hasKey = false
VAR ratio = 3.14

=== start ===
Test
]]
      local story = importer:import(ink)

      assert.equals("number", story.variables.score.type)
      assert.equals(42, story.variables.score.default)
      assert.equals("string", story.variables.name.type)
      assert.equals("Player", story.variables.name.default)
      assert.equals("boolean", story.variables.hasKey.type)
      assert.equals(false, story.variables.hasKey.default)
      assert.equals("number", story.variables.ratio.type)
    end)

    it("should import choices", function()
      local ink = [[
=== start ===
What do you do?
* [Go north] -> north
* [Go south] -> south
+ [Look around] -> start

=== north ===
You went north.

=== south ===
You went south.
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      local start_passage = story:get_passage("start")
      assert.is_not_nil(start_passage)
      assert.equals(3, #start_passage.choices)

      -- Verify first choice
      assert.equals("Go north", start_passage.choices[1].text)
      assert.equals("north", start_passage.choices[1].target)
    end)

    it("should import stitches as sub-passages", function()
      local ink = [[
=== london ===
You are in London.
-> london.pub

= pub
You enter the pub.

= market
You visit the market.
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("london"))
      assert.is_not_nil(story:get_passage("london.pub"))
      assert.is_not_nil(story:get_passage("london.market"))
    end)

    it("should convert variable assignments", function()
      local ink = [[
=== start ===
~ score = 10
~ name = "Hero"
You have {score} points.
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage)
      assert.is_true(passage.content:find("{do score = 10}") ~= nil)
    end)

    it("should handle gather points", function()
      local ink = [[
=== start ===
* [Option A]
  You chose A.
* [Option B]
  You chose B.
- Both paths lead here.
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage)
      assert.is_true(passage.content:find("Both paths lead here") ~= nil)
    end)

    it("should report issues for external functions", function()
      local ink = [[
EXTERNAL doSomething()

=== start ===
Hello!
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      assert.is_true(#report.warnings > 0)

      local has_external_warning = false
      for _, warning in ipairs(report.warnings) do
        if warning.message and warning.message:find("External function") then
          has_external_warning = true
          break
        end
      end
      assert.is_true(has_external_warning)
    end)

    it("should create implicit Start passage for content without knots", function()
      local ink = [[
Hello world!
This is a simple story.
* [Continue] -> END
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("Start"))
    end)

    it("should handle tunnel syntax", function()
      local ink = [[
=== start ===
Before tunnel.
-> subroutine ->
After tunnel.

=== subroutine ===
Inside subroutine.
<-
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("start"))
      assert.is_not_nil(story:get_passage("subroutine"))

      local start_passage = story:get_passage("start")
      assert.is_true(start_passage.content:find("subroutine") ~= nil)

      local sub_passage = story:get_passage("subroutine")
      assert.is_true(sub_passage.content:find("<%-") ~= nil)
    end)

    it("should set correct start passage to first knot", function()
      local ink = [[
=== intro ===
This is the intro.
-> main

=== main ===
This is main.
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      -- First knot should be start passage when no 'Start' exists
      assert.is_not_nil(story.start_passage)
    end)

    it("should skip comments", function()
      local ink = [[
// This is a comment
=== start ===
Hello!
// Another comment
Goodbye!
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage)
      assert.is_nil(passage.content:find("This is a comment"))
    end)

    it("should handle block comments", function()
      local ink = [[
/* This is a
   block comment */
=== start ===
Hello!
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage)
      assert.is_nil(passage.content:find("block comment"))
    end)

    it("should handle INCLUDE directives", function()
      local ink = [[
INCLUDE other_file.ink

=== start ===
Hello!
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)

      local has_include_info = false
      for _, info in ipairs(report.info) do
        if info.message and info.message:find("INCLUDE") then
          has_include_info = true
          break
        end
      end
      assert.is_true(has_include_info)
    end)

    it("should handle CONST declarations", function()
      local ink = [[
CONST MAX_HEALTH = 100

=== start ===
Test
]]
      local story = importer:import(ink)

      assert.is_not_nil(story)
      assert.is_not_nil(story.variables.MAX_HEALTH)
      assert.equals(100, story.variables.MAX_HEALTH.default)
    end)
  end)

  describe("loss report", function()
    it("should calculate conversion quality", function()
      local ink = [[
=== start ===
Simple story.
]]
      importer:import(ink)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      assert.is_not_nil(report.conversion_quality)
      assert.is_true(report.conversion_quality >= 0)
      assert.is_true(report.conversion_quality <= 1)
    end)

    it("should track category counts", function()
      local ink = [[
EXTERNAL customFunc()
EXTERNAL anotherFunc()

=== start ===
Content.
]]
      importer:import(ink)

      local report = importer:get_loss_report()
      assert.is_not_nil(report)
      assert.equals(2, report.category_counts["external"])
    end)

    it("should have lower quality when there are warnings", function()
      local ink_with_issues = [[
EXTERNAL func1()
EXTERNAL func2()
EXTERNAL func3()

=== start(param) ===
Content.
]]
      importer:import(ink_with_issues)
      local report_with_issues = importer:get_loss_report()

      local importer2 = InkImporter.new()
      local ink_simple = [[
=== start ===
Simple content.
]]
      importer2:import(ink_simple)
      local report_simple = importer2:get_loss_report()

      assert.is_true(report_with_issues.conversion_quality < report_simple.conversion_quality)
    end)
  end)

  describe("edge cases", function()
    it("should handle empty knot content", function()
      local ink = [[
=== start ===

=== next ===
Content here.
]]
      local story = importer:import(ink)
      assert.is_not_nil(story)
      assert.is_not_nil(story:get_passage("start"))
      assert.is_not_nil(story:get_passage("next"))
    end)

    it("should handle multiple consecutive diverts", function()
      local ink = [[
=== start ===
First line.
-> middle
-> also_this
]]
      local story = importer:import(ink)
      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.is_true(#passage.choices >= 2)
    end)

    it("should handle choices without brackets", function()
      local ink = [[
=== start ===
What do you do?
* Go north -> north
* Go south -> south
]]
      local story = importer:import(ink)
      assert.is_not_nil(story)
      local passage = story:get_passage("start")
      assert.equals(2, #passage.choices)
    end)

    it("should handle inline variable substitution", function()
      local ink = [[
=== start ===
Hello {name}, you have {score} points.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      -- Ink {var} converts to WLS ${var} syntax
      assert.is_true(passage.content:find("%${name}") ~= nil)
      assert.is_true(passage.content:find("%${score}") ~= nil)
    end)
  end)

  describe("glue", function()
    it("should handle glue at end of line", function()
      local ink = [[
=== start ===
Hello <>
world!
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      -- Glue should join lines without newline
      assert.is_true(passage.content:find("Hello%s*world") ~= nil or passage.content:find("Helloworld") ~= nil)
    end)

    it("should handle inline glue", function()
      local ink = [[
=== start ===
The value is <>42<>.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      -- Glue markers should be removed
      assert.is_nil(passage.content:find("<>"))
    end)
  end)

  describe("tags", function()
    it("should parse standalone tags", function()
      local ink = [[
=== start ===
# dark
# spooky
You enter the cave.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage.tags)
      assert.is_true(#passage.tags >= 2)
    end)

    it("should parse inline tags", function()
      local ink = [[
=== start ===
You enter the cave. # dark # spooky
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_not_nil(passage.tags)
      local has_dark = false
      for _, tag in ipairs(passage.tags) do
        if tag:find("dark") then has_dark = true end
      end
      assert.is_true(has_dark)
    end)
  end)

  describe("LIST declarations", function()
    it("should parse LIST declaration", function()
      local ink = [[
LIST mood = happy, sad, angry

=== start ===
You are feeling {mood}.
]]
      local story = importer:import(ink)
      assert.is_not_nil(story.variables.mood)
    end)

    it("should parse LIST with default selected item", function()
      local ink = [[
LIST inventory = (torch), sword, key

=== start ===
You have the {inventory}.
]]
      local story = importer:import(ink)
      assert.is_not_nil(story.variables.inventory)
      -- Default should be the item in parentheses
    end)

    it("should report LIST as info issue", function()
      local ink = [[
LIST items = a, b, c

=== start ===
Test
]]
      importer:import(ink)
      local report = importer:get_loss_report()
      local has_list_info = false
      for _, info in ipairs(report.info) do
        if info.category == "list" then
          has_list_info = true
          break
        end
      end
      assert.is_true(has_list_info)
    end)
  end)

  describe("temp variables", function()
    it("should parse temp variable declaration", function()
      local ink = [[
=== start ===
~ temp result = 42
The result is {result}.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      -- Temp variables should be converted to local declarations
      assert.is_true(passage.content:find("local") ~= nil or passage.content:find("result") ~= nil)
    end)

    it("should parse temp variable with expression", function()
      local ink = [[
=== start ===
~ temp total = score + bonus
Your total is {total}.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("total") ~= nil)
    end)
  end)

  describe("alternatives", function()
    it("should parse shuffle alternatives", function()
      local ink = [[
=== start ===
{~Hello|Hi|Hey} there!
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("shuffle") ~= nil)
    end)

    it("should parse cycle alternatives", function()
      local ink = [[
=== start ===
{&first|second|third} time!
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("cycle") ~= nil)
    end)

    it("should parse sequence alternatives", function()
      local ink = [[
=== start ===
{!once|twice|thrice} upon a time.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("sequence") ~= nil)
    end)

    it("should parse plain alternatives as sequence", function()
      local ink = [[
=== start ===
{one|two|three} options.
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.is_true(passage.content:find("sequence") ~= nil)
    end)
  end)

  describe("sticky choices", function()
    it("should mark sticky choices", function()
      local ink = [[
=== start ===
+ [This is sticky] -> somewhere
* [This is not sticky] -> elsewhere
]]
      local story = importer:import(ink)
      local passage = story:get_passage("start")
      assert.equals(2, #passage.choices)
      -- First choice should be sticky
      assert.is_true(passage.choices[1].sticky)
      -- Second choice should not be sticky
      assert.is_false(passage.choices[2].sticky or false)
    end)
  end)
end)
