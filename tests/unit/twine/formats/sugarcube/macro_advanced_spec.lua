--- SugarCube advanced macro unit tests
-- Tests advanced macro parsing: for, switch, widget, script, etc.
--
-- tests/unit/twine/formats/sugarcube/macro_advanced_spec.lua

describe("SugarCubeHandler Advanced Macros", function()
  local SugarCubeHandler

  before_each(function()
    package.loaded['whisker.twine.formats.sugarcube.handler'] = nil
    package.loaded['whisker.twine.formats.sugarcube.macro_core'] = nil
    package.loaded['whisker.twine.formats.sugarcube.macro_advanced'] = nil
    package.loaded['whisker.twine.formats.sugarcube.expression_parser'] = nil
    package.loaded['whisker.twine.formats.sugarcube.js_translator'] = nil
    SugarCubeHandler = require('whisker.twine.formats.sugarcube.handler')
  end)

  describe("<<for>> macro", function()
    it("parses C-style for loop", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<for $i = 0; $i < 5; $i++>>Count: $i<</for>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("for_range", ast[1].type)
      assert.equals("i", ast[1].variable)
    end)

    it("parses range for loop", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<for $item range $inventory>>Item: $item<</for>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("for_loop", ast[1].type)
      assert.equals("item", ast[1].variable)
    end)

    it("parses key-value range for loop", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<for $key, $value range $player>>$key: $value<</for>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("for_pairs", ast[1].type)
      assert.equals("key", ast[1].key_variable)
      assert.equals("value", ast[1].value_variable)
    end)

    it("parses temporary variable range", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<for _item range $items>>$_item<</for>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("for_loop", ast[1].type)
      assert.equals("item", ast[1].variable)
    end)
  end)

  describe("<<switch>> macro", function()
    it("parses simple switch with cases", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<switch $choice>><<case "a">>A!<<case "b">>B!<</switch>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("switch", ast[1].type)
      assert.equals(2, #ast[1].cases)
    end)

    it("parses switch with default", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<switch $x>><<case 1>>One<<default>>Other<</switch>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("switch", ast[1].type)
      assert.is_not_nil(ast[1].default_case)
    end)

    it("parses case with multiple values", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<switch $choice>><<case "a" "b" "c">>ABC!<</switch>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals(1, #ast[1].cases)
      assert.equals(3, #ast[1].cases[1].values)
    end)
  end)

  describe("<<widget>> macro", function()
    it("parses widget definition", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<widget "showHealth">>Health: $health<</widget>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("widget_definition", ast[1].type)
      assert.equals("showHealth", ast[1].name)
      assert.is_true(#ast[1].body > 0)
    end)
  end)

  describe("<<script>> macro", function()
    it("translates simple JavaScript", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<script>>State.variables.gold = 100;<</script>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("script_block", ast[1].type)
      assert.is_not_nil(ast[1].code)
    end)

    it("handles Math functions", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<script>>var x = Math.floor(Math.random() * 10);<</script>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      -- Should translate or warn
      assert.is_true(ast[1].type == "script_block" or ast[1].type == "warning")
    end)
  end)

  describe("<<run>> macro", function()
    it("translates simple run expression", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<run State.variables.gold = 50>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      -- Should translate or warn
      assert.is_true(ast[1].type == "run_expression" or ast[1].type == "warning")
    end)
  end)

  describe("<<nobr>> macro", function()
    it("removes line breaks from content", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<nobr>>Line 1\nLine 2\nLine 3<</nobr>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("nobr_block", ast[1].type)
    end)
  end)

  describe("<<->> and <<=>> macros", function()
    it("parses print shorthand", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<- $name>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("print", ast[1].type)
      assert.equals(false, ast[1].html_encode)
    end)

    it("parses HTML-encoded print", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<= $name>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("print", ast[1].type)
      assert.equals(true, ast[1].html_encode)
    end)
  end)

  describe("<<timed>> macro", function()
    it("parses timed content", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<timed 2s>>Delayed text<</timed>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("timed_content", ast[1].type)
      assert.equals(2, ast[1].delay)
    end)

    it("parses milliseconds", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<timed 500ms>>Fast<</timed>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals(0.5, ast[1].delay)
    end)
  end)

  describe("<<repeat>> macro", function()
    it("parses repeat content", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<repeat 1s>>Tick<</repeat>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("repeat_content", ast[1].type)
      assert.equals(1, ast[1].interval)
    end)
  end)

  describe("<<stop>> macro", function()
    it("parses stop macro", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<stop>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("stop_repeat", ast[1].type)
    end)
  end)

  describe("<<capture>> macro", function()
    it("parses capture with variables", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<capture $i $j>>Content<</capture>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("capture_block", ast[1].type)
    end)
  end)

  describe("<<type>> macro", function()
    it("parses typewriter effect", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<type 40>>Typing...<</type>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("typewriter_effect", ast[1].type)
    end)
  end)
end)

describe("JSTranslator", function()
  local JSTranslator

  before_each(function()
    package.loaded['whisker.twine.formats.sugarcube.js_translator'] = nil
    JSTranslator = require('whisker.twine.formats.sugarcube.js_translator')
  end)

  describe("translate_expression", function()
    it("translates State.variables to variable name", function()
      local lua, warnings = JSTranslator.translate_expression("State.variables.gold")
      assert.equals("gold", lua)
    end)

    it("translates Math.random", function()
      local lua, warnings = JSTranslator.translate_expression("Math.random()")
      assert.equals("math.random()", lua)
    end)

    it("translates Math.floor", function()
      local lua, warnings = JSTranslator.translate_expression("Math.floor(x)")
      assert.equals("math.floor(x)", lua)
    end)

    it("passes through numbers", function()
      local lua, warnings = JSTranslator.translate_expression("42")
      assert.equals("42", lua)
    end)

    it("passes through strings", function()
      local lua, warnings = JSTranslator.translate_expression('"hello"')
      assert.equals('"hello"', lua)
    end)
  end)

  describe("translate_block", function()
    it("translates variable assignment", function()
      local lua, warnings = JSTranslator.translate_block("State.variables.gold = 100;")
      assert.is_not_nil(lua)
      assert.is_true(lua:find("gold = 100") ~= nil)
    end)

    it("translates if statements", function()
      local lua, warnings = JSTranslator.translate_block("if ($gold > 50) {")
      assert.is_not_nil(lua)
      assert.is_true(lua:find("if") ~= nil)
      assert.is_true(lua:find("then") ~= nil)
    end)

    it("translates JavaScript comments", function()
      local lua, warnings = JSTranslator.translate_block("// comment")
      assert.is_not_nil(lua)
      assert.is_true(lua:find("--") ~= nil)
    end)
  end)
end)

describe("SpecialPassages", function()
  local SpecialPassages

  before_each(function()
    package.loaded['whisker.twine.formats.sugarcube.special_passages'] = nil
    SpecialPassages = require('whisker.twine.formats.sugarcube.special_passages')
  end)

  describe("is_special", function()
    it("recognizes StoryInit", function()
      assert.is_true(SpecialPassages.is_special("StoryInit"))
    end)

    it("recognizes PassageHeader", function()
      assert.is_true(SpecialPassages.is_special("PassageHeader"))
    end)

    it("recognizes PassageFooter", function()
      assert.is_true(SpecialPassages.is_special("PassageFooter"))
    end)

    it("returns false for regular passages", function()
      assert.is_false(SpecialPassages.is_special("Start"))
      assert.is_false(SpecialPassages.is_special("MyPassage"))
    end)
  end)

  describe("get_hook_type", function()
    it("maps StoryInit to story_init", function()
      assert.equals("story_init", SpecialPassages.get_hook_type("StoryInit"))
    end)

    it("maps PassageHeader to passage_header", function()
      assert.equals("passage_header", SpecialPassages.get_hook_type("PassageHeader"))
    end)

    it("returns nil for regular passages", function()
      assert.is_nil(SpecialPassages.get_hook_type("Start"))
    end)
  end)
end)
