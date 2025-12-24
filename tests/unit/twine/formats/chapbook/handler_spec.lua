--- Chapbook handler unit tests
-- Tests Chapbook modifier, insert, and variable parsing
--
-- tests/unit/twine/formats/chapbook/handler_spec.lua

describe("ChapbookHandler", function()
  local ChapbookHandler

  before_each(function()
    package.loaded['whisker.twine.formats.chapbook.handler'] = nil
    package.loaded['whisker.twine.formats.chapbook.modifier_parser'] = nil
    package.loaded['whisker.twine.formats.chapbook.insert_parser'] = nil
    package.loaded['whisker.twine.formats.chapbook.variable_parser'] = nil
    package.loaded['whisker.twine.formats.chapbook.expression_parser'] = nil
    ChapbookHandler = require('whisker.twine.formats.chapbook.handler')
  end)

  describe("initialization", function()
    it("creates a new handler instance", function()
      local handler = ChapbookHandler.new()
      assert.is_not_nil(handler)
      assert.equals("chapbook", handler.format_name)
    end)

    it("supports Chapbook versions", function()
      local handler = ChapbookHandler.new()
      assert.is_true(#handler.supported_versions > 0)
      assert.is_true(handler:is_version_supported("1.2"))
    end)
  end)

  describe("format detection", function()
    it("detects Chapbook format", function()
      local handler = ChapbookHandler.new()
      local html_data = { metadata = { format = "Chapbook" } }
      assert.is_true(handler:detect(html_data))
    end)

    it("detects Chapbook with version", function()
      local handler = ChapbookHandler.new()
      local html_data = { metadata = { format = "Chapbook-1.2.3" } }
      assert.is_true(handler:detect(html_data))
    end)

    it("rejects non-Chapbook format", function()
      local handler = ChapbookHandler.new()
      local html_data = { metadata = { format = "SugarCube" } }
      assert.is_false(handler:detect(html_data))
    end)
  end)

  describe("variable assignment", function()
    it("parses simple assignment", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "health: 100" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("health", ast[1].variable)
      assert.equals(100, ast[1].value.value)
    end)

    it("parses string assignment", function()
      local handler = ChapbookHandler.new()
      local passage = { content = 'name: "Alice"' }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("name", ast[1].variable)
      assert.equals("Alice", ast[1].value.value)
    end)

    it("parses array assignment", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "items: ['sword', 'shield']" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals("array_literal", ast[1].value.type)
    end)

    it("parses boolean assignment", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "isReady: true" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("assignment", ast[1].type)
      assert.equals(true, ast[1].value.value)
    end)
  end)

  describe("[if] modifier", function()
    it("parses simple if", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[if health > 50]\nYou feel great." }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.is_not_nil(ast[1].condition)
    end)

    it("parses if with comparison", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[if gold >= 100]\nRich!" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.equals(">=", ast[1].condition.operator)
    end)

    it("parses if with variable check", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[if hasKey]\nYou can open the door." }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
    end)
  end)

  describe("[unless] modifier", function()
    it("parses unless as negated if", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[unless doorOpen]\nThe door is locked." }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("conditional", ast[1].type)
      assert.equals("not", ast[1].condition.operator)
    end)
  end)

  describe("[after] modifier", function()
    it("parses after with seconds", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[after 2s]\nDelayed text" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("delayed_content", ast[1].type)
      assert.equals(2, ast[1].delay)
    end)

    it("parses after with milliseconds", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[after 500ms]\nFast" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("delayed_content", ast[1].type)
      assert.equals(0.5, ast[1].delay)
    end)
  end)

  describe("[continue] modifier", function()
    it("parses continue prompt", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[continue]\nPress to continue" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("continue_prompt", ast[1].type)
    end)
  end)

  describe("[align] modifier", function()
    it("parses center alignment", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[align center]\nCentered text" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("aligned_text", ast[1].type)
      assert.equals("center", ast[1].alignment)
    end)
  end)

  describe("[note] modifier", function()
    it("parses note", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[note]\nThis is a note" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("note", ast[1].type)
    end)
  end)

  describe("inserts", function()
    it("parses simple insert", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "Hello, {name}!" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("interpolated_text", ast[1].type)
      assert.equals(3, #ast[1].parts)
    end)

    it("parses insert with default", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "{name, default: 'Stranger'}" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("insert_with_default", ast[1].type)
      assert.equals("name", ast[1].variable)
    end)

    it("parses random function", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "Your roll is {random(1, 6)}" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("interpolated_text", ast[1].type)
      -- Should contain random_range
      local found = false
      for _, part in ipairs(ast[1].parts or {}) do
        if part.type == "random_range" then
          found = true
        end
      end
      assert.is_true(found)
    end)

    it("parses either function", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "{either('a', 'b', 'c')}" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("random_choice", ast[1].type)
    end)
  end)

  describe("wiki links", function()
    it("parses simple link", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[[Next Room]]" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Next Room", ast[1].text)
      assert.equals("Next Room", ast[1].destination)
    end)

    it("parses link with arrow", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[[Go north->Forest]]" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Go north", ast[1].text)
      assert.equals("Forest", ast[1].destination)
    end)

    it("parses link with back arrow", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "[[Forest<-Go north]]" }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("choice", ast[1].type)
      assert.equals("Go north", ast[1].text)
      assert.equals("Forest", ast[1].destination)
    end)

    it("parses text with embedded link", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "You can [[go north]] or stay." }
      local ast = handler:parse_passage(passage)

      assert.is_true(#ast >= 1)
    end)
  end)

  describe("plain text", function()
    it("preserves markdown", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "This is **bold** and *italic*." }
      local ast = handler:parse_passage(passage)

      assert.equals(1, #ast)
      assert.equals("text", ast[1].type)
      assert.is_true(ast[1].content:find("%*%*bold%*%*") ~= nil)
    end)
  end)

  describe("mixed content", function()
    it("parses passage with multiple elements", function()
      local handler = ChapbookHandler.new()
      local passage = { content = "name: 'Hero'\n\n[if hasWeapon]\nYou have a weapon.\n\n[[Continue->Next]]" }
      local ast = handler:parse_passage(passage)

      -- Should have assignment, conditional, and link
      local has_assignment = false
      local has_conditional = false
      local has_choice = false

      for _, node in ipairs(ast) do
        if node.type == "assignment" then has_assignment = true end
        if node.type == "conditional" then has_conditional = true end
        if node.type == "choice" then has_choice = true end
      end

      assert.is_true(has_assignment)
      assert.is_true(has_conditional)
      assert.is_true(has_choice)
    end)
  end)
end)
