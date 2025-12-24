--- SugarCube handler unit tests
-- Tests core SugarCube macro parsing and translation
--
-- tests/unit/twine/formats/sugarcube/handler_spec.lua

describe("SugarCubeHandler", function()
  local SugarCubeHandler

  before_each(function()
    package.loaded['whisker.twine.formats.sugarcube.handler'] = nil
    package.loaded['whisker.twine.formats.sugarcube.macro_core'] = nil
    package.loaded['whisker.twine.formats.sugarcube.expression_parser'] = nil
    SugarCubeHandler = require('whisker.twine.formats.sugarcube.handler')
  end)

  describe("initialization", function()
    it("creates a new handler instance", function()
      local handler = SugarCubeHandler.new()
      assert.is_not_nil(handler)
      assert.equals("sugarcube", handler.format_name)
    end)

    it("supports multiple SugarCube versions", function()
      local handler = SugarCubeHandler.new()
      assert.is_true(#handler.supported_versions > 0)
      assert.is_true(handler:is_version_supported("2.36"))
    end)
  end)

  describe("format detection", function()
    it("detects SugarCube format", function()
      local handler = SugarCubeHandler.new()
      local html_data = { metadata = { format = "SugarCube" } }
      assert.is_true(handler:detect(html_data))
    end)

    it("detects SugarCube with version suffix", function()
      local handler = SugarCubeHandler.new()
      local html_data = { metadata = { format = "SugarCube-2.36.1" } }
      assert.is_true(handler:detect(html_data))
    end)

    it("rejects non-SugarCube format", function()
      local handler = SugarCubeHandler.new()
      local html_data = { metadata = { format = "Harlowe" } }
      assert.is_false(handler:detect(html_data))
    end)
  end)

  describe("<<set>> macro", function()
    it("parses set with 'to' keyword", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<set $gold to 100>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("gold", ast[1].variable)
      assert.equals("literal", ast[1].value.type)
      assert.equals(100, ast[1].value.value)
    end)

    it("parses set with equals sign", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<set $health = 50>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("health", ast[1].variable)
    end)

    it("parses set with string value", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<set $name to "Alice">>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("name", ast[1].variable)
      assert.equals("string", ast[1].value.literal_type)
      assert.equals("Alice", ast[1].value.value)
    end)

    it("parses compound assignment +=", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<set $gold += 10>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("gold", ast[1].variable)
      -- Value should be $gold + 10
      assert.equals("binary_op", ast[1].value.type)
    end)

    it("parses increment ++", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<set $count++>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("count", ast[1].variable)
    end)

    it("parses temporary variable with _", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<set _temp to 5>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("temp", ast[1].variable)
    end)
  end)

  describe("<<unset>> macro", function()
    it("parses unset variable", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<unset $flag>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("unset", ast[1].type)
      assert.equals("flag", ast[1].variable)
    end)
  end)

  describe("<<if>> macro", function()
    it("parses simple if conditional", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $gold > 50>>Rich!<</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.is_not_nil(ast[1].condition)
      assert.is_not_nil(ast[1].body)
    end)

    it("parses if with comparison operators", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $health >= 100>>Full health<</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.equals("binary_op", ast[1].condition.type)
      assert.equals(">=", ast[1].condition.operator)
    end)

    it("parses if with SugarCube aliases", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $name is 'Alice'>>Hello Alice<</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.equals("==", ast[1].condition.operator)
    end)

    it("parses if with else", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $gold > 50>>Rich<<else>>Poor<</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.is_not_nil(ast[1].else_body)
    end)

    it("parses if with elseif", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $health > 75>>Great<<elseif $health > 25>>OK<<else>>Bad<</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.is_not_nil(ast[1].elsif_clauses)
    end)

    it("parses logical AND condition", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $hasKey and $doorLocked>>Unlock<</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.equals("logical_op", ast[1].condition.type)
      assert.equals("and", ast[1].condition.operator)
    end)
  end)

  describe("<<link>> macro", function()
    it("parses simple link", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<link "Click me">><</link>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Click me", ast[1].text)
    end)

    it("parses link with destination", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<link "Go north" "Forest">><</link>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Go north", ast[1].text)
      assert.equals("Forest", ast[1].destination)
    end)

    it("parses link with body content", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<link "Open">><<set $opened to true>><</link>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.is_true(#ast[1].body > 0)
    end)
  end)

  describe("<<button>> macro", function()
    it("parses button like link", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<button "Click">><</button>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("button", ast[1].style)
    end)
  end)

  describe("<<goto>> macro", function()
    it("parses goto with string destination", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<goto "Next Room">>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("goto", ast[1].type)
      assert.equals("Next Room", ast[1].destination)
    end)

    it("parses goto with bracket syntax", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<goto [[Dungeon]]>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("goto", ast[1].type)
      assert.equals("Dungeon", ast[1].destination)
    end)
  end)

  describe("wiki-style links", function()
    it("parses simple wiki link", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "[[Next Room]]" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Next Room", ast[1].text)
      assert.equals("Next Room", ast[1].destination)
    end)

    it("parses wiki link with arrow", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "[[Go north->Forest]]" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Go north", ast[1].text)
      assert.equals("Forest", ast[1].destination)
    end)

    it("parses wiki link with back arrow", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "[[Forest<-Go north]]" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Go north", ast[1].text)
      assert.equals("Forest", ast[1].destination)
    end)
  end)

  describe("text parsing", function()
    it("preserves plain text", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "Hello, world!" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("text", ast[1].type)
      assert.equals("Hello, world!", ast[1].content)
    end)

    it("handles mixed content", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "You have <<print $gold>> gold." }
      local ast = handler:parse_passage(passage)

      -- Should have: text, print, text
      assert.equals(3, #ast)
      assert.equals("text", ast[1].type)
      assert.equals("print", ast[2].type)
      assert.equals("text", ast[3].type)
    end)
  end)

  describe("nested macros", function()
    it("parses nested if inside link", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = '<<link "Action">><<if $ready>>Go!<</if>><</link>>' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      -- Body should contain the nested if
      assert.is_true(#ast[1].body > 0)
    end)

    it("handles multiple nested ifs", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<if $a>>A<<if $b>>B<</if>><</if>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
    end)
  end)

  describe("unsupported macros", function()
    it("creates warning for unknown macro", function()
      local handler = SugarCubeHandler.new()
      local passage = { content = "<<unknownmacro>>" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("warning", ast[1].type)
      assert.is_true(ast[1].message:find("Unsupported") ~= nil)
    end)
  end)
end)
