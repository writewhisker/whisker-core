-- whisker-lsp/spec/navigation_enhanced_spec.lua
-- Tests for enhanced find references (GAP-054)

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("Navigation Enhanced References", function()
  local Navigation
  local Document

  before_each(function()
    Navigation = require("whisker.lsp.navigation")
    Document = require("whisker.lsp.document")
  end)

  local function create_provider(content)
    local docs = Document.new()
    local uri = "file:///test.ws"
    docs:open(uri, content, 1)
    local provider = Navigation.new({ documents = docs })
    return provider, docs, uri
  end

  describe("find_passage_references", function()
    it("finds passage definition", function()
      local provider, docs, uri = create_provider(":: Combat\nFight!\n")

      local refs = provider:find_passage_references(uri, "Combat")

      assert.is_true(#refs >= 1)
      local found_def = false
      for _, ref in ipairs(refs) do
        if ref.range.start.line == 0 then
          found_def = true
          break
        end
      end
      assert.is_true(found_def)
    end)

    it("finds passage navigation links", function()
      local provider, docs, uri = create_provider(":: Start\n-> Combat\n\n:: Combat\nFight!\n")

      local refs = provider:find_passage_references(uri, "Combat")

      assert.is_true(#refs >= 2)
      -- Should include both definition and link
    end)

    it("finds passage in visited() calls", function()
      local provider, docs, uri = create_provider(':: Start\n{visited("Combat")} Been there!\n\n:: Combat\nFight!\n')

      local refs = provider:find_passage_references(uri, "Combat")

      assert.is_true(#refs >= 2)
    end)

    it("finds multiple references on same line", function()
      local provider, docs, uri = create_provider(":: Start\n-> Combat\n-> Combat\n\n:: Combat\nFight!\n")

      local refs = provider:find_passage_references(uri, "Combat")

      assert.is_true(#refs >= 3)
    end)
  end)

  describe("find_variable_references", function()
    it("finds VAR declaration", function()
      local provider, docs, uri = create_provider("VAR health = 100\n")

      local refs = provider:find_variable_references(uri, "health")

      assert.is_true(#refs >= 1)
    end)

    it("finds $var interpolations", function()
      local provider, docs, uri = create_provider("VAR health = 100\nYou have $health HP.\n")

      local refs = provider:find_variable_references(uri, "health")

      assert.is_true(#refs >= 2)
    end)

    it("finds multiple variable usages", function()
      local provider, docs, uri = create_provider("VAR health = 100\n$health\n$health\n$health\n")

      local refs = provider:find_variable_references(uri, "health")

      assert.is_true(#refs >= 4)
    end)
  end)

  describe("find_function_references", function()
    it("finds function definition", function()
      local provider, docs, uri = create_provider("FUNCTION greet\n  return \"Hello\"\nEND\n")

      local refs = provider:find_function_references(uri, "greet")

      assert.is_true(#refs >= 1)
    end)

    it("finds function calls", function()
      local provider, docs, uri = create_provider("FUNCTION greet\n  return \"Hello\"\nEND\n\n:: Start\n{greet()}\n")

      local refs = provider:find_function_references(uri, "greet")

      assert.is_true(#refs >= 2)
    end)

    it("finds multiple function calls", function()
      local provider, docs, uri = create_provider("FUNCTION add(a, b)\n  return a + b\nEND\n\n:: Start\n{add(1, 2)}\n{add(3, 4)}\n")

      local refs = provider:find_function_references(uri, "add")

      assert.is_true(#refs >= 3)
    end)
  end)

  describe("find_hook_references", function()
    it("finds hook definitions and references", function()
      local provider, docs, uri = create_provider(":: Start\n|hook>This is hooked|hook>\n")

      local refs = provider:find_hook_references(uri, "hook")

      assert.is_true(#refs >= 1)
    end)
  end)

  describe("symbol type detection", function()
    it("detects passage from definition line", function()
      local docs = Document.new()
      local uri = "file:///test.ws"
      docs:open(uri, ":: MyPassage\nContent\n", 1)
      local provider = Navigation.new({ documents = docs })
      local doc = docs:get(uri)

      local symbol_type = provider:determine_symbol_type(doc, 0, 5, "MyPassage")

      assert.equals("passage", symbol_type)
    end)

    it("detects passage from navigation", function()
      local docs = Document.new()
      local uri = "file:///test.ws"
      docs:open(uri, ":: Start\n-> Target\n", 1)
      local provider = Navigation.new({ documents = docs })
      local doc = docs:get(uri)

      local symbol_type = provider:determine_symbol_type(doc, 1, 5, "Target")

      assert.equals("passage", symbol_type)
    end)

    it("detects function from definition", function()
      local docs = Document.new()
      local uri = "file:///test.ws"
      docs:open(uri, "FUNCTION myFunc\n  return 1\nEND\n", 1)
      local provider = Navigation.new({ documents = docs })
      local doc = docs:get(uri)

      local symbol_type = provider:determine_symbol_type(doc, 0, 10, "myFunc")

      assert.equals("function", symbol_type)
    end)

    it("detects variable from interpolation", function()
      local docs = Document.new()
      local uri = "file:///test.ws"
      docs:open(uri, "You have $gold coins.\n", 1)
      local provider = Navigation.new({ documents = docs })
      local doc = docs:get(uri)

      local symbol_type = provider:determine_symbol_type(doc, 0, 12, "gold")

      assert.equals("variable", symbol_type)
    end)
  end)
end)
