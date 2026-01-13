-- spec/parser/test_hook_parsing.lua
-- WLS 2.0 Hook Parsing Tests

describe("Parser - Hook Support", function()
  local Parser = require("lib.whisker.parser.ws_parser")
  local parser
  
  before_each(function()
    parser = Parser.new()
  end)
  
  describe("hook definitions", function()
    it("parses simple hook definition", function()
      local content = "Text with |flowers>[roses] here."
      local ast = parser:parse_passage_content(content)
      
      local hook_node = nil
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_node = node
          break
        end
      end
      
      assert.is_not_nil(hook_node)
      assert.equals("flowers", hook_node.name)
      assert.equals("roses", hook_node.content)
    end)
    
    it("parses multiple hooks in one line", function()
      local content = "|weather>[sunny] day with |flowers>[roses]"
      local ast = parser:parse_passage_content(content)
      
      local hook_count = 0
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_count = hook_count + 1
        end
      end
      
      assert.equals(2, hook_count)
    end)
    
    it("handles empty hook content", function()
      local content = "|placeholder>[]"
      local ast = parser:parse_passage_content(content)
      
      local hook_node = ast.nodes[1]
      assert.equals("hook_definition", hook_node.type)
      assert.equals("", hook_node.content)
    end)
    
    it("handles hook with special characters", function()
      local content = "|code>[if (x > 5) { return true; }]"
      local ast = parser:parse_passage_content(content)
      
      local hook_node = nil
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_node = node
          break
        end
      end
      
      assert.is_not_nil(hook_node)
      assert.equals("if (x > 5) { return true; }", hook_node.content)
    end)
    
    it("handles nested brackets in content", function()
      local content = "|array>[items[0], items[1]]"
      local ast = parser:parse_passage_content(content)
      
      local hook_node = nil
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_node = node
          break
        end
      end
      
      assert.is_not_nil(hook_node)
      assert.equals("items[0], items[1]", hook_node.content)
    end)
  end)
  
  describe("hook operations", function()
    it("parses replace operation", function()
      local content = "@replace: flowers { wilted petals }"
      local ast = parser:parse_passage_content(content)
      
      local op_node = ast.nodes[1]
      assert.equals("hook_operation", op_node.type)
      assert.equals("replace", op_node.operation)
      assert.equals("flowers", op_node.target)
      assert.equals(" wilted petals ", op_node.content)
    end)
    
    it("parses all operation types", function()
      local operations = {
        "@replace: test { new }",
        "@append: test { more }",
        "@prepend: test { before }",
        "@show: test {}",
        "@hide: test {}"
      }
      
      for _, op_str in ipairs(operations) do
        local ast = parser:parse_passage_content(op_str)
        local has_hook_op = false
        for _, node in ipairs(ast.nodes) do
          if node.type == "hook_operation" then
            has_hook_op = true
            break
          end
        end
        assert.is_true(has_hook_op, "Failed to parse: " .. op_str)
      end
    end)
    
    it("handles whitespace variations", function()
      local variations = {
        "@replace:flowers{new}",
        "@replace: flowers{new}",
        "@replace:flowers {new}",
        "@replace: flowers { new }"
      }
      
      for _, var in ipairs(variations) do
        local ast = parser:parse_passage_content(var)
        local has_hook_op = false
        for _, node in ipairs(ast.nodes) do
          if node.type == "hook_operation" then
            has_hook_op = true
            break
          end
        end
        assert.is_true(has_hook_op, "Failed to parse: " .. var)
      end
    end)
    
    it("rejects invalid operation types", function()
      local content = "@invalid: test { content }"
      local ast = parser:parse_passage_content(content)
      
      -- Should not parse as hook_operation
      local has_hook_op = false
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_operation" then
          has_hook_op = true
          break
        end
      end
      assert.is_false(has_hook_op)
    end)
  end)
  
  describe("integration with existing syntax", function()
    it("parses hooks in choice blocks", function()
      local content = [[+ [Select] {
  @replace: status { changed }
}]]
      local ast = parser:parse_passage_content(content)
      
      -- Should find hook operation inside text
      local found_hook_op = false
      local function check_nodes(nodes)
        for _, node in ipairs(nodes) do
          if node.type == "hook_operation" then
            found_hook_op = true
          elseif node.content and type(node.content) == "string" then
            -- Check if hook operation is in text content
            if node.content:match("@replace:") then
              -- Create a sub-parser to check this content
              local sub_ast = parser:parse_passage_content(node.content)
              check_nodes(sub_ast.nodes)
            end
          end
        end
      end
      check_nodes(ast.nodes)
      
      assert.is_true(found_hook_op)
    end)
    
    it("preserves hook syntax in text nodes", function()
      local content = "Story: |message>[hello] world"
      local ast = parser:parse_passage_content(content)
      
      -- Should have text, hook, text nodes (at least 2)
      assert.is_true(#ast.nodes >= 2)
      
      -- Verify we have a hook definition
      local has_hook = false
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          has_hook = true
          break
        end
      end
      assert.is_true(has_hook)
    end)
  end)
  
  describe("error handling", function()
    it("handles malformed hook definition", function()
      local content = "|broken>[unclosed"
      
      -- Should not crash
      assert.has_no.errors(function()
        parser:parse_passage_content(content)
      end)
    end)
    
    it("handles malformed hook operation", function()
      local content = "@replace: missing_brace"
      
      assert.has_no.errors(function()
        parser:parse_passage_content(content)
      end)
    end)
    
    it("handles text without hooks", function()
      local content = "This is plain text without any hooks."
      
      assert.has_no.errors(function()
        local ast = parser:parse_passage_content(content)
        assert.equals(1, #ast.nodes)
        assert.equals("text", ast.nodes[1].type)
      end)
    end)
    
    it("handles empty content", function()
      local content = ""
      
      assert.has_no.errors(function()
        local ast = parser:parse_passage_content(content)
        assert.equals(0, #ast.nodes)
      end)
    end)
  end)
  
  describe("edge cases", function()
    it("handles deeply nested brackets", function()
      local content = "|nested>[outer[middle[inner]middle]outer]"
      local ast = parser:parse_passage_content(content)
      
      local hook_node = nil
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_node = node
          break
        end
      end
      
      assert.is_not_nil(hook_node)
      assert.equals("outer[middle[inner]middle]outer", hook_node.content)
    end)
    
    it("handles hook at start of content", function()
      local content = "|first>[content] rest"
      local ast = parser:parse_passage_content(content)
      
      assert.equals("hook_definition", ast.nodes[1].type)
    end)
    
    it("handles hook at end of content", function()
      local content = "start |last>[content]"
      local ast = parser:parse_passage_content(content)
      
      local last_hook = nil
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          last_hook = node
        end
      end
      
      assert.is_not_nil(last_hook)
      assert.equals("content", last_hook.content)
    end)
    
    it("handles consecutive hooks", function()
      local content = "|first>[a]|second>[b]|third>[c]"
      local ast = parser:parse_passage_content(content)
      
      local hook_count = 0
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_count = hook_count + 1
        end
      end
      
      assert.equals(3, hook_count)
    end)
    
    it("handles hooks with newlines in content", function()
      local content = "|multiline>[line1\nline2\nline3]"
      local ast = parser:parse_passage_content(content)
      
      local hook_node = nil
      for _, node in ipairs(ast.nodes) do
        if node.type == "hook_definition" then
          hook_node = node
          break
        end
      end
      
      assert.is_not_nil(hook_node)
      assert.is_true(hook_node.content:find("\n") ~= nil)
    end)
  end)
end)
