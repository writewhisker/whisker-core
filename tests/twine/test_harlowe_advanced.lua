--- Tests for Harlowe advanced macro translation
-- Tests for: for, live, event, a, dm, named hooks, possessive syntax
--
-- tests/twine/test_harlowe_advanced.lua

-- Add lib to path for requires
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local HarloweHandler = require('whisker.twine.formats.harlowe.handler')
local MacroAdvanced = require('whisker.twine.formats.harlowe.macro_advanced')
local HookParser = require('whisker.twine.formats.harlowe.hook_parser')
local ASTBuilder = require('whisker.twine.ast_builder')

describe("Harlowe Advanced Macros", function()
  local handler

  before_each(function()
    handler = HarloweHandler.new()
  end)

  --------------------------------------------------------------------------------
  -- AC3.1: (for: each _var, ...$array) translates to for-loop AST
  --------------------------------------------------------------------------------
  describe("for loop macro", function()
    it("should translate for loop with spread syntax", function()
      local passage = { content = "(for: each _item, ...$inventory)[You have _item.]" }
      local ast = handler:parse_passage(passage)

      assert.is_not_nil(ast)
      assert.is_true(#ast >= 1)
      assert.equals("for_loop", ast[1].type)
      assert.equals("item", ast[1].variable)
      assert.is_not_nil(ast[1].collection)
      assert.equals("variable", ast[1].collection.type)
      assert.equals("inventory", ast[1].collection.name)
      assert.is_not_nil(ast[1].body)
    end)

    it("should handle for loop translation directly", function()
      local args = {{ type = "expression", value = "each _item, ...$items" }}
      local result = MacroAdvanced.translate_for(args, "Body content")

      assert.equals("for_loop", result.type)
      assert.equals("item", result.variable)
      assert.equals("items", result.collection.name)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.2: (a: item1, item2) creates array literal
  --------------------------------------------------------------------------------
  describe("array creation macro", function()
    it("should create array from (a:) macro", function()
      local passage = { content = "(set: $items to (a: 'sword', 'shield', 'potion'))" }
      local ast = handler:parse_passage(passage)

      assert.is_not_nil(ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("items", ast[1].variable)
    end)

    it("should translate array macro directly", function()
      local args = {
        { type = "string", value = "sword" },
        { type = "string", value = "shield" },
        { type = "string", value = "potion" }
      }
      local result = MacroAdvanced.translate_array(args, nil)

      assert.equals("array_literal", result.type)
      assert.equals(3, #result.items)
      assert.equals("sword", result.items[1].value)
      assert.equals("shield", result.items[2].value)
      assert.equals("potion", result.items[3].value)
    end)

    it("should handle empty array", function()
      local args = {}
      local result = MacroAdvanced.translate_array(args, nil)

      assert.equals("array_literal", result.type)
      assert.equals(0, #result.items)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.3: (dm: "key", value) creates datamap/table literal
  --------------------------------------------------------------------------------
  describe("datamap creation macro", function()
    it("should create datamap from (dm:) macro", function()
      local passage = { content = '(set: $player to (dm: "name", "Alice", "hp", 100))' }
      local ast = handler:parse_passage(passage)

      assert.is_not_nil(ast)
      assert.equals("assignment", ast[1].type)
    end)

    it("should translate datamap macro directly", function()
      local args = {
        { type = "string", value = "name" },
        { type = "string", value = "Alice" },
        { type = "string", value = "hp" },
        { type = "number", value = 100 }
      }
      local result = MacroAdvanced.translate_datamap(args, nil)

      assert.equals("table_literal", result.type)
      assert.equals(2, #result.pairs)
      assert.equals("name", result.pairs[1].key)
      assert.equals("Alice", result.pairs[1].value.value)
      assert.equals("hp", result.pairs[2].key)
      assert.equals(100, result.pairs[2].value.value)
    end)

    it("should error on odd number of arguments", function()
      local args = {
        { type = "string", value = "name" },
        { type = "string", value = "Alice" },
        { type = "string", value = "hp" }
      }
      local result = MacroAdvanced.translate_datamap(args, nil)

      assert.equals("error", result.type)
      assert.is_truthy(result.message:match("even number"))
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.4: (live: interval) creates live update node with warning
  --------------------------------------------------------------------------------
  describe("live update macro", function()
    it("should translate live macro with warning", function()
      local args = {{ type = "expression", value = "1s" }}
      local result = MacroAdvanced.translate_live(args, "Current time display")

      assert.equals("live_update", result.type)
      assert.equals(1, result.interval)
      assert.is_not_nil(result.warning)
      assert.is_truthy(result.warning:match("text mode"))
    end)

    it("should parse milliseconds", function()
      local args = {{ type = "expression", value = "500ms" }}
      local result = MacroAdvanced.translate_live(args, "Fast update")

      assert.equals(0.5, result.interval)
    end)

    it("should parse minutes", function()
      local args = {{ type = "expression", value = "2m" }}
      local result = MacroAdvanced.translate_live(args, "Slow update")

      assert.equals(120, result.interval)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.5: (event: when condition) creates event listener
  --------------------------------------------------------------------------------
  describe("event listener macro", function()
    it("should translate event macro", function()
      local args = {{ type = "expression", value = "when $health <= 0" }}
      local result = MacroAdvanced.translate_event(args, "(goto: 'Game Over')")

      assert.equals("event_listener", result.type)
      assert.is_not_nil(result.condition)
      assert.is_not_nil(result.warning)
    end)

    it("should parse condition correctly", function()
      local args = {{ type = "expression", value = "when $score > 100" }}
      local result = MacroAdvanced.translate_event(args, "You win!")

      assert.is_not_nil(result.condition)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.6: Possessive syntax $var's length parses correctly
  --------------------------------------------------------------------------------
  describe("possessive syntax - length", function()
    it("should parse length property", function()
      local expr = "$items's length"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.is_not_nil(ast)
      assert.equals("length_of", ast.type)
      assert.equals("variable", ast.target.type)
      assert.equals("items", ast.target.name)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.7: Possessive syntax $array's 1st converts to 0-indexed access
  --------------------------------------------------------------------------------
  describe("possessive syntax - ordinal", function()
    it("should parse 1st element (0-indexed)", function()
      local expr = "$items's 1st"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.is_not_nil(ast)
      assert.equals("array_access", ast.type)
      assert.equals("items", ast.target.name)
      assert.equals(0, ast.index.value) -- 0-indexed
    end)

    it("should parse 2nd element", function()
      local expr = "$items's 2nd"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.equals(1, ast.index.value) -- 0-indexed
    end)

    it("should parse 3rd element", function()
      local expr = "$items's 3rd"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.equals(2, ast.index.value) -- 0-indexed
    end)

    it("should parse nth elements", function()
      local expr = "$items's 10th"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.equals(9, ast.index.value) -- 0-indexed
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.8: Possessive syntax $map's key accesses property
  --------------------------------------------------------------------------------
  describe("possessive syntax - property", function()
    it("should parse property access", function()
      local expr = "$player's name"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.is_not_nil(ast)
      assert.equals("property_access", ast.type)
      assert.equals("player", ast.target.name)
      assert.equals("name", ast.property)
    end)

    it("should parse health property", function()
      local expr = "$player's health"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.equals("health", ast.property)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.9: Named hooks |hookName>[content] parse correctly
  --------------------------------------------------------------------------------
  describe("named hooks parsing", function()
    it("should find named hooks", function()
      local content = "|message>[You see a door.]"
      local hooks = HookParser.find_named_hooks(content)

      assert.equals(1, #hooks)
      assert.equals("message", hooks[1].name)
      assert.equals("You see a door.", hooks[1].content)
    end)

    it("should find multiple hooks", function()
      local content = "|first>[Content 1] Some text |second>[Content 2]"
      local hooks = HookParser.find_named_hooks(content)

      assert.equals(2, #hooks)
      assert.equals("first", hooks[1].name)
      assert.equals("second", hooks[2].name)
    end)

    it("should handle nested brackets", function()
      local content = "|outer>[Some [nested] content]"
      local hooks = HookParser.find_named_hooks(content)

      assert.equals(1, #hooks)
      assert.equals("Some [nested] content", hooks[1].content)
    end)

    it("should extract hooks from passage", function()
      local passage = { content = "|status>[Health: 100] Welcome to the game!" }
      local ast = handler:parse_passage(passage)

      -- Should have both the hook and the text
      assert.is_true(#ast >= 1)
    end)
  end)

  --------------------------------------------------------------------------------
  -- AC3.10: (replace:), (append:), (prepend:) hook commands translate
  --------------------------------------------------------------------------------
  describe("hook manipulation macros", function()
    it("should translate replace macro", function()
      local passage = { content = "(replace: ?message)[New text]" }
      local ast = handler:parse_passage(passage)

      assert.equals("hook_update", ast[1].type)
      assert.equals("replace", ast[1].operation)
      assert.equals("message", ast[1].hook_name)
    end)

    it("should translate append macro", function()
      local passage = { content = "(append: ?status)[ (Poisoned!)]" }
      local ast = handler:parse_passage(passage)

      assert.equals("hook_update", ast[1].type)
      assert.equals("append", ast[1].operation)
      assert.equals("status", ast[1].hook_name)
    end)

    it("should translate prepend macro", function()
      local passage = { content = "(prepend: ?header)[Important: ]" }
      local ast = handler:parse_passage(passage)

      assert.equals("hook_update", ast[1].type)
      assert.equals("prepend", ast[1].operation)
      assert.equals("header", ast[1].hook_name)
    end)
  end)

  --------------------------------------------------------------------------------
  -- Additional tests for edge cases
  --------------------------------------------------------------------------------
  describe("edge cases", function()
    it("should handle either macro with spread", function()
      local args = {{ type = "expression", value = "...$items" }}
      local result = MacroAdvanced.translate_either(args, nil)

      assert.equals("random_choice", result.type)
      assert.equals("variable", result.collection.type)
      assert.equals("items", result.collection.name)
    end)

    it("should handle either macro with individual items", function()
      local args = {
        { type = "string", value = "red" },
        { type = "string", value = "blue" },
        { type = "string", value = "green" }
      }
      local result = MacroAdvanced.translate_either(args, nil)

      assert.equals("random_choice", result.type)
      assert.equals("array_literal", result.collection.type)
      assert.equals(3, #result.collection.items)
    end)

    it("should handle random number macro", function()
      local args = {
        { type = "number", value = 1 },
        { type = "number", value = 10 }
      }
      local result = MacroAdvanced.translate_random(args, nil)

      assert.equals("random_number", result.type)
      assert.equals(1, result.min.value)
      assert.equals(10, result.max.value)
    end)

    it("should handle show and hide macros", function()
      local show_args = {{ type = "expression", value = "?secret" }}
      local hide_args = {{ type = "expression", value = "?secret" }}

      local show_result = MacroAdvanced.translate_show(show_args, nil)
      local hide_result = MacroAdvanced.translate_hide(hide_args, nil)

      assert.equals("hook_visibility", show_result.type)
      assert.equals("show", show_result.operation)
      assert.equals("hook_visibility", hide_result.type)
      assert.equals("hide", hide_result.operation)
    end)

    it("should parse keys and values properties", function()
      local keys_expr = "$player's keys"
      local values_expr = "$player's values"

      local keys_ast = MacroAdvanced.parse_possessive(keys_expr)
      local values_ast = MacroAdvanced.parse_possessive(values_expr)

      assert.equals("datamap_keys", keys_ast.type)
      assert.equals("datamap_values", values_ast.type)
    end)

    it("should parse last element", function()
      local expr = "$items's last"
      local ast = MacroAdvanced.parse_possessive(expr)

      assert.equals("array_last", ast.type)
    end)
  end)

  --------------------------------------------------------------------------------
  -- Integration tests
  --------------------------------------------------------------------------------
  describe("integration", function()
    it("should parse complex passage with multiple features", function()
      local passage = { content = [=[
(set: $inventory to (a: "sword", "shield"))
(for: each _item, ...$inventory)[
  You have a _item.
]
|status>[Health: 100]
(link: "Take potion")[(append: ?status)[ Healed!]]
]=] }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 2)
    end)

    it("should handle chained macros", function()
      local passage = { content = "(set: $x to 5)(if: $x > 3)[Success](set: $x to 10)" }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 3)
      assert.equals("assignment", ast[1].type)
      assert.equals("conditional", ast[2].type)
      assert.equals("assignment", ast[3].type)
    end)
  end)
end)
