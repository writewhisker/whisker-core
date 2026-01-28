-- whisker-lsp/spec/code_actions_spec.lua
-- Tests for LSP code actions

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("CodeActions", function()
  local CodeActions
  local Document

  before_each(function()
    CodeActions = require("whisker.lsp.code_actions")
    Document = require("whisker.lsp.document")
  end)

  local function create_provider(content)
    local docs = Document.new()
    local uri = "file:///test.ws"
    docs:open(uri, content, 1)
    local provider = CodeActions.new({ documents = docs })
    return provider, docs, uri
  end

  describe("diagnostic quick fixes", function()
    it("creates passage for broken link", function()
      local provider, docs, uri = create_provider(":: Start\n-> Missing\n")

      local actions = provider:get_actions(uri, {
        start = { line = 1, character = 3 },
        ["end"] = { line = 1, character = 10 }
      }, {
        diagnostics = {
          {
            range = {
              start = { line = 1, character = 3 },
              ["end"] = { line = 1, character = 10 }
            },
            message = "Broken link: passage 'Missing' not found"
          }
        }
      })

      assert.is_true(#actions > 0)

      local found_create = false
      for _, action in ipairs(actions) do
        if action.title:match("Create passage") then
          found_create = true
          assert.equals("quickfix", action.kind)
          assert.is_not_nil(action.edit)
          break
        end
      end
      assert.is_true(found_create)
    end)

    it("creates variable declaration for undefined variable", function()
      local provider, docs, uri = create_provider(":: Start\nYou have $gold coins.\n")

      local actions = provider:get_actions(uri, {
        start = { line = 1, character = 9 },
        ["end"] = { line = 1, character = 14 }
      }, {
        diagnostics = {
          {
            range = {
              start = { line = 1, character = 9 },
              ["end"] = { line = 1, character = 14 }
            },
            message = "Variable '$gold' may not be defined"
          }
        }
      })

      assert.is_true(#actions > 0)

      local found_declare = false
      for _, action in ipairs(actions) do
        if action.title:match("Declare variable") then
          found_declare = true
          assert.equals("quickfix", action.kind)
          break
        end
      end
      assert.is_true(found_declare)
    end)
  end)

  describe("refactoring actions", function()
    it("offers extract to passage for multi-line selection", function()
      local provider, docs, uri = create_provider(":: Start\nLine 1\nLine 2\nLine 3\n")

      local actions = provider:get_actions(uri, {
        start = { line = 1, character = 0 },
        ["end"] = { line = 3, character = 6 }
      }, { diagnostics = {} })

      local found_extract = false
      for _, action in ipairs(actions) do
        if action.title:match("Extract to new passage") then
          found_extract = true
          assert.equals("refactor.extract", action.kind)
          break
        end
      end
      assert.is_true(found_extract)
    end)

    it("does not offer extract for single line selection", function()
      local provider, docs, uri = create_provider(":: Start\nSingle line\n")

      local actions = provider:get_actions(uri, {
        start = { line = 1, character = 0 },
        ["end"] = { line = 1, character = 11 }
      }, { diagnostics = {} })

      local found_extract = false
      for _, action in ipairs(actions) do
        if action.title:match("Extract to new passage") then
          found_extract = true
          break
        end
      end
      assert.is_false(found_extract)
    end)
  end)

  describe("source actions", function()
    it("offers generate IFID when not present", function()
      local provider, docs, uri = create_provider(":: Start\nHello world\n")

      local actions = provider:get_actions(uri, {
        start = { line = 0, character = 0 },
        ["end"] = { line = 0, character = 0 }
      }, { diagnostics = {} })

      local found_ifid = false
      for _, action in ipairs(actions) do
        if action.title:match("Generate IFID") then
          found_ifid = true
          assert.equals("source", action.kind)
          break
        end
      end
      assert.is_true(found_ifid)
    end)

    it("does not offer generate IFID when present", function()
      local provider, docs, uri = create_provider("@ifid: 12345678-1234-1234-1234-123456789012\n:: Start\nHello\n")

      local actions = provider:get_actions(uri, {
        start = { line = 0, character = 0 },
        ["end"] = { line = 0, character = 0 }
      }, { diagnostics = {} })

      local found_ifid = false
      for _, action in ipairs(actions) do
        if action.title:match("Generate IFID") then
          found_ifid = true
          break
        end
      end
      assert.is_false(found_ifid)
    end)
  end)
end)
