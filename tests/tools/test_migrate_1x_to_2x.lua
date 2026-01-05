--- Tests for WLS 1.x to 2.0 Migration Tool
-- @module tests.tools.test_migrate_1x_to_2x

describe("WLS 1.x to 2.0 Migration Tool", function()
  local migrate_tool

  setup(function()
    migrate_tool = require("tools.migrate_1x_to_2x")
  end)

  describe("reserved word migration", function()
    it("renames $thread to $_thread", function()
      local source = [[
:: Start
The $thread is important.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$_thread", result.content)
      assert.is_true(#result.changes > 0)
    end)

    it("renames $await to $_await", function()
      local source = [[
:: Start
We $await the result.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$_await", result.content)
    end)

    it("renames $spawn to $_spawn", function()
      local source = [[
:: Start
Let's $spawn a process.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$_spawn", result.content)
    end)

    it("renames $sync to $_sync", function()
      local source = [[
:: Start
Keep $sync with the others.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$_sync", result.content)
    end)

    it("renames $channel to $_channel", function()
      local source = [[
:: Start
Use the $channel properly.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$_channel", result.content)
    end)

    it("renames ${thread} to ${_thread}", function()
      local source = [[
:: Start
Value is ${thread}.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("${_thread}", result.content)
    end)

    it("does not rename partial matches", function()
      local source = [[
:: Start
The $threaded system works.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$threaded", result.content)
      assert.equals(0, #result.changes)
    end)

    it("handles multiple reserved words", function()
      local source = [[
:: Start
The $thread and $spawn and $await.
]]
      local result = migrate_tool.migrate(source)
      assert.matches("$_thread", result.content)
      assert.matches("$_spawn", result.content)
      assert.matches("$_await", result.content)
      assert.is_true(#result.changes >= 3)
    end)
  end)

  describe("tunnel detection", function()
    it("warns about tunnel usage", function()
      local source = [[
:: Start
+ [Enter tunnel] ->-> TunnelPassage
]]
      local result = migrate_tool.migrate(source)
      local has_tunnel_warning = false
      for _, warning in ipairs(result.warnings) do
        if warning.message:match("tunnel") then
          has_tunnel_warning = true
          break
        end
      end
      assert.is_true(has_tunnel_warning)
    end)

    it("does not warn when no tunnels", function()
      local source = [[
:: Start
+ [Go somewhere] -> Somewhere
]]
      local result = migrate_tool.migrate(source)
      local has_tunnel_warning = false
      for _, warning in ipairs(result.warnings) do
        if warning.message:match("tunnel") then
          has_tunnel_warning = true
          break
        end
      end
      assert.is_false(has_tunnel_warning)
    end)
  end)

  describe("deprecated pattern detection", function()
    it("warns about legacy script blocks", function()
      local source = [[
:: Start
<script>
  x = 1
</script>
]]
      local result = migrate_tool.migrate(source)
      local has_warning = false
      for _, warning in ipairs(result.warnings) do
        if warning.message:match("script") then
          has_warning = true
          break
        end
      end
      assert.is_true(has_warning)
    end)

    it("warns about legacy if blocks", function()
      local source = [[
:: Start
{{#if condition}}
  Text
{{/if}}
]]
      local result = migrate_tool.migrate(source)
      local has_warning = false
      for _, warning in ipairs(result.warnings) do
        if warning.message:match("#if") then
          has_warning = true
          break
        end
      end
      assert.is_true(has_warning)
    end)

    it("warns about legacy each blocks", function()
      local source = [[
:: Start
{{#each items}}
  Item
{{/each}}
]]
      local result = migrate_tool.migrate(source)
      local has_warning = false
      for _, warning in ipairs(result.warnings) do
        if warning.message:match("#each") then
          has_warning = true
          break
        end
      end
      assert.is_true(has_warning)
    end)
  end)

  describe("migration result structure", function()
    it("returns content field", function()
      local source = ":: Start\nHello"
      local result = migrate_tool.migrate(source)
      assert.is_string(result.content)
    end)

    it("returns changes array", function()
      local source = ":: Start\nHello"
      local result = migrate_tool.migrate(source)
      assert.is_table(result.changes)
    end)

    it("returns warnings array", function()
      local source = ":: Start\nHello"
      local result = migrate_tool.migrate(source)
      assert.is_table(result.warnings)
    end)

    it("returns original and migrated lengths", function()
      local source = ":: Start\nHello"
      local result = migrate_tool.migrate(source)
      assert.is_number(result.original_length)
      assert.is_number(result.migrated_length)
    end)

    it("records change details", function()
      local source = ":: Start\n$thread"
      local result = migrate_tool.migrate(source)
      assert.is_true(#result.changes > 0)
      local change = result.changes[1]
      assert.is_string(change.type)
      assert.is_string(change.original)
      assert.is_string(change.replacement)
      assert.is_string(change.reason)
    end)
  end)

  describe("no-op migration", function()
    it("preserves content when no changes needed", function()
      local source = [[
:: Start
This is a simple story.

+ [Continue] -> Next

:: Next
The end.
]]
      local result = migrate_tool.migrate(source)
      assert.equals(0, #result.changes)
      -- Content should be preserved (minus possible whitespace differences)
      assert.matches("This is a simple story", result.content)
      assert.matches("Continue", result.content)
      assert.matches("The end", result.content)
    end)
  end)

  describe("header comment", function()
    it("adds migration header when changes made", function()
      local source = ":: Start\n$thread"
      local result = migrate_tool.migrate(source)
      assert.matches("Migrated to WLS 2%.0", result.content)
    end)

    it("does not add header when no changes", function()
      local source = ":: Start\nHello"
      local result = migrate_tool.migrate(source)
      assert.is_nil(result.content:match("Migrated to WLS 2%.0"))
    end)

    it("does not duplicate header", function()
      local source = "// Migrated to WLS 2.0\n:: Start\n$thread"
      local result = migrate_tool.migrate(source)
      -- Should only have one header
      local _, count = result.content:gsub("Migrated to WLS 2%.0", "")
      assert.equals(1, count)
    end)
  end)

  describe("report generation", function()
    it("generates a report string", function()
      local source = ":: Start\n$thread"
      local result = migrate_tool.migrate(source)
      local report = migrate_tool.generate_report(result)
      assert.is_string(report)
    end)

    it("includes change count in report", function()
      local source = ":: Start\n$thread $spawn"
      local result = migrate_tool.migrate(source)
      local report = migrate_tool.generate_report(result)
      assert.matches("Changes:", report)
    end)

    it("includes warnings in report", function()
      local source = ":: Start\n->->\n"
      local result = migrate_tool.migrate(source)
      local report = migrate_tool.generate_report(result)
      assert.matches("Warnings:", report)
    end)

    it("reports WLS 2.0 compatible when no changes", function()
      local source = ":: Start\nHello"
      local result = migrate_tool.migrate(source)
      local report = migrate_tool.generate_report(result)
      assert.matches("compatible", report)
    end)
  end)

  describe("change types", function()
    it("exports CHANGE_TYPES constants", function()
      assert.equals("rename", migrate_tool.CHANGE_TYPES.RENAME)
      assert.equals("syntax", migrate_tool.CHANGE_TYPES.SYNTAX)
      assert.equals("reserved_word", migrate_tool.CHANGE_TYPES.RESERVED_WORD)
      assert.equals("deprecation", migrate_tool.CHANGE_TYPES.DEPRECATION)
    end)
  end)

  describe("reserved words list", function()
    it("includes all 2.0 reserved words", function()
      local expected = {"thread", "await", "spawn", "sync", "channel", "timer", "effect", "audio", "external"}
      for _, word in ipairs(expected) do
        local found = false
        for _, reserved in ipairs(migrate_tool.RESERVED_WORDS) do
          if reserved == word then
            found = true
            break
          end
        end
        assert.is_true(found, "Missing reserved word: " .. word)
      end
    end)
  end)

  describe("complex migration scenarios", function()
    it("handles story with multiple issues", function()
      local source = [[
:: Start
The $thread is here.
We $await results.
<script>
  x = 1
</script>
+ [Tunnel] ->-> Somewhere
]]
      local result = migrate_tool.migrate(source)

      -- Should have changes for reserved words
      assert.is_true(#result.changes >= 2)

      -- Should have warnings for script and tunnel
      assert.is_true(#result.warnings >= 2)

      -- Content should be migrated
      assert.matches("$_thread", result.content)
      assert.matches("$_await", result.content)
    end)

    it("preserves story structure", function()
      local source = [[
:: Start
Hello world.

+ [Option 1] -> One
+ [Option 2] -> Two

:: One
You chose one.
+ [Back] -> Start

:: Two
You chose two with $thread.
+ [Back] -> Start
]]
      local result = migrate_tool.migrate(source)

      -- All passages should be present
      assert.matches(":: Start", result.content)
      assert.matches(":: One", result.content)
      assert.matches(":: Two", result.content)

      -- Choices should be preserved
      assert.matches("%+ %[Option 1%]", result.content)
      assert.matches("%+ %[Option 2%]", result.content)

      -- Reserved word should be migrated
      assert.matches("$_thread", result.content)
    end)
  end)
end)
