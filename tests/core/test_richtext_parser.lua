-- tests/core/test_richtext_parser.lua
-- Tests for WLS 2.0 Rich Text Parser

local ws_parser = require("whisker.parser.ws_parser")

describe("Rich Text Parsing", function()
  local parser

  before_each(function()
    parser = ws_parser.new()
  end)

  describe("Bold", function()
    it("should parse **text** as bold", function()
      local result = parser:parse_passage_content("**bold text**")
      assert.is_not_nil(result)
      assert.equals("passage_content", result.type)
      assert.equals(1, #result.nodes)
      assert.equals("formatted_text", result.nodes[1].type)
      assert.equals("bold", result.nodes[1].format)
      assert.equals("bold text", result.nodes[1].content)
    end)

    it("should handle multiple bold segments", function()
      local result = parser:parse_passage_content("**first** and **second**")
      assert.is_not_nil(result)
      -- Should have bold, text, bold
      local bold_count = 0
      for _, node in ipairs(result.nodes) do
        if node.type == "formatted_text" and node.format == "bold" then
          bold_count = bold_count + 1
        end
      end
      assert.equals(2, bold_count)
    end)
  end)

  describe("Italic", function()
    it("should parse *text* as italic", function()
      local result = parser:parse_passage_content("*italic text*")
      assert.is_not_nil(result)
      assert.equals(1, #result.nodes)
      assert.equals("formatted_text", result.nodes[1].type)
      assert.equals("italic", result.nodes[1].format)
      assert.equals("italic text", result.nodes[1].content)
    end)

    it("should not confuse bold and italic", function()
      local result = parser:parse_passage_content("**bold** and *italic*")
      assert.is_not_nil(result)
      local has_bold = false
      local has_italic = false
      for _, node in ipairs(result.nodes) do
        if node.type == "formatted_text" then
          if node.format == "bold" then has_bold = true end
          if node.format == "italic" then has_italic = true end
        end
      end
      assert.is_true(has_bold)
      assert.is_true(has_italic)
    end)
  end)

  describe("Strikethrough", function()
    it("should parse ~~text~~ as strikethrough", function()
      local result = parser:parse_passage_content("~~strikethrough~~")
      assert.is_not_nil(result)
      assert.equals(1, #result.nodes)
      assert.equals("formatted_text", result.nodes[1].type)
      assert.equals("strikethrough", result.nodes[1].format)
      assert.equals("strikethrough", result.nodes[1].content)
    end)
  end)

  describe("Inline Code", function()
    it("should parse `code` as inline code", function()
      local result = parser:parse_passage_content("`inline code`")
      assert.is_not_nil(result)
      assert.equals(1, #result.nodes)
      assert.equals("formatted_text", result.nodes[1].type)
      assert.equals("code", result.nodes[1].format)
      assert.equals("inline code", result.nodes[1].content)
    end)

    it("should preserve special characters in code", function()
      local result = parser:parse_passage_content("`**not bold**`")
      assert.is_not_nil(result)
      assert.equals("formatted_text", result.nodes[1].type)
      assert.equals("code", result.nodes[1].format)
      assert.equals("**not bold**", result.nodes[1].content)
    end)
  end)

  describe("Code Blocks", function()
    it("should parse code fence", function()
      local result = parser:parse_passage_content("```\ncode here\n```")
      assert.is_not_nil(result)
      local code_block = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "formatted_text" and node.format == "code" then
          code_block = node
          break
        end
      end
      assert.is_not_nil(code_block)
    end)

    it("should capture language specifier", function()
      local result = parser:parse_passage_content("```lua\nlocal x = 1\n```")
      assert.is_not_nil(result)
      local code_block = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "formatted_text" and node.format == "code" then
          code_block = node
          break
        end
      end
      assert.is_not_nil(code_block)
      assert.equals("lua", code_block.language)
    end)
  end)

  describe("Blockquotes", function()
    it("should parse > as blockquote", function()
      local result = parser:parse_passage_content("> Quote text")
      assert.is_not_nil(result)
      local blockquote = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "blockquote" then
          blockquote = node
          break
        end
      end
      assert.is_not_nil(blockquote)
      assert.equals(1, blockquote.depth)
    end)

    it("should parse nested blockquotes", function()
      local result = parser:parse_passage_content(">> Nested quote")
      assert.is_not_nil(result)
      local blockquote = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "blockquote" then
          blockquote = node
          break
        end
      end
      assert.is_not_nil(blockquote)
      assert.equals(2, blockquote.depth)
    end)
  end)

  describe("Lists", function()
    describe("Unordered Lists", function()
      it("should parse - item as unordered list", function()
        local result = parser:parse_passage_content("- List item")
        assert.is_not_nil(result)
        local list_item = nil
        for _, node in ipairs(result.nodes) do
          if node.type == "list_item" then
            list_item = node
            break
          end
        end
        assert.is_not_nil(list_item)
        assert.is_false(list_item.ordered)
      end)

      it("should parse * item as unordered list", function()
        local result = parser:parse_passage_content("* Star item")
        assert.is_not_nil(result)
        local list_item = nil
        for _, node in ipairs(result.nodes) do
          if node.type == "list_item" then
            list_item = node
            break
          end
        end
        assert.is_not_nil(list_item)
        assert.is_false(list_item.ordered)
      end)
    end)

    describe("Ordered Lists", function()
      it("should parse 1. item as ordered list", function()
        local result = parser:parse_passage_content("1. First item")
        assert.is_not_nil(result)
        local list_item = nil
        for _, node in ipairs(result.nodes) do
          if node.type == "list_item" then
            list_item = node
            break
          end
        end
        assert.is_not_nil(list_item)
        assert.is_true(list_item.ordered)
      end)
    end)
  end)

  describe("Horizontal Rules", function()
    it("should parse --- as horizontal rule", function()
      local result = parser:parse_passage_content("---")
      assert.is_not_nil(result)
      local hr = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "horizontal_rule" then
          hr = node
          break
        end
      end
      assert.is_not_nil(hr)
    end)

    it("should parse *** as horizontal rule", function()
      local result = parser:parse_passage_content("***")
      assert.is_not_nil(result)
      local hr = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "horizontal_rule" then
          hr = node
          break
        end
      end
      assert.is_not_nil(hr)
    end)

    it("should parse longer rules", function()
      local result = parser:parse_passage_content("----------")
      assert.is_not_nil(result)
      local hr = nil
      for _, node in ipairs(result.nodes) do
        if node.type == "horizontal_rule" then
          hr = node
          break
        end
      end
      assert.is_not_nil(hr)
    end)
  end)

  describe("Mixed Content", function()
    it("should handle text before and after formatting", function()
      local result = parser:parse_passage_content("before **bold** after")
      assert.is_not_nil(result)
      assert.is_true(#result.nodes >= 3)
    end)
  end)
end)
