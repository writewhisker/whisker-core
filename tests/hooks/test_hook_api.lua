-- spec/api/test_hook_api.lua
-- Tests for whisker.hook API namespace

describe("Hook API", function()
  local Engine = require("lib.whisker.core.engine")
  local Story = require("lib.whisker.story.story")
  local Passage = require("lib.whisker.story.passage")
  
  local engine
  local story
  local interpreter
  
  before_each(function()
    story = Story.new()
    engine = Engine.new()
    engine:init(story, {platform = "plain"})
    interpreter = engine.lua_interpreter
  end)
  
  -- ========================================================================
  -- Test Suite 1: whisker.hook.visible
  -- ========================================================================
  
  describe("whisker.hook.visible", function()
    it("returns true for visible hook", function()
      local passage = Passage.new("test", "Item: |item>[key]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.visible('item')")
      assert.is_true(result)
    end)
    
    it("returns false for hidden hook", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "secret")
      
      local result = interpreter:eval("return whisker.hook.visible('secret')")
      assert.is_false(result)
    end)
    
    it("returns false for non-existent hook", function()
      local passage = Passage.new("test", "No hooks")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.visible('missing')")
      assert.is_false(result)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 2: whisker.hook.contains
  -- ========================================================================
  
  describe("whisker.hook.contains", function()
    it("returns true when text is found", function()
      local passage = Passage.new("test", "HP: |hp>[100]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.contains('hp', '100')")
      assert.is_true(result)
    end)
    
    it("returns false when text is not found", function()
      local passage = Passage.new("test", "HP: |hp>[100]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.contains('hp', '50')")
      assert.is_false(result)
    end)
    
    it("returns false for hidden hook", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "secret")
      
      local result = interpreter:eval("return whisker.hook.contains('secret', 'treasure')")
      assert.is_false(result)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 3: whisker.hook.get
  -- ========================================================================
  
  describe("whisker.hook.get", function()
    it("returns hook content", function()
      local passage = Passage.new("test", "Message: |msg>[Hello]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.get('msg')")
      assert.equals("Hello", result)
    end)
    
    it("returns nil for hidden hook", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "secret")
      
      local result = interpreter:eval("return whisker.hook.get('secret')")
      assert.is_nil(result)
    end)
    
    it("returns updated content after operation", function()
      local passage = Passage.new("test", "Value: |val>[initial]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("replace", "val", "updated")
      
      local result = interpreter:eval("return whisker.hook.get('val')")
      assert.equals("updated", result)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 4: whisker.hook.exists
  -- ========================================================================
  
  describe("whisker.hook.exists", function()
    it("returns true for existing hook", function()
      local passage = Passage.new("test", "Item: |item>[key]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.exists('item')")
      assert.is_true(result)
    end)
    
    it("returns true even for hidden hook", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "secret")
      
      local result = interpreter:eval("return whisker.hook.exists('secret')")
      assert.is_true(result)
    end)
    
    it("returns false for non-existent hook", function()
      local passage = Passage.new("test", "No hooks")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.exists('missing')")
      assert.is_false(result)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 5: whisker.hook.hidden
  -- ========================================================================
  
  describe("whisker.hook.hidden", function()
    it("returns false for visible hook", function()
      local passage = Passage.new("test", "Item: |item>[key]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.hidden('item')")
      assert.is_false(result)
    end)
    
    it("returns true for hidden hook", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "secret")
      
      local result = interpreter:eval("return whisker.hook.hidden('secret')")
      assert.is_true(result)
    end)
    
    it("returns false for non-existent hook", function()
      local passage = Passage.new("test", "No hooks")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.hidden('missing')")
      assert.is_false(result)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 6: whisker.hook.number
  -- ========================================================================
  
  describe("whisker.hook.number", function()
    it("converts hook content to number", function()
      local passage = Passage.new("test", "HP: |hp>[85]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.number('hp')")
      assert.equals(85, result)
    end)
    
    it("returns nil for non-numeric content", function()
      local passage = Passage.new("test", "Text: |text>[hello]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.number('text')")
      assert.is_nil(result)
    end)
    
    it("returns nil for hidden hook", function()
      local passage = Passage.new("test", "HP: |hp>[100]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "hp")
      
      local result = interpreter:eval("return whisker.hook.number('hp')")
      assert.is_nil(result)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 7: Integration Tests
  -- ========================================================================
  
  describe("integration", function()
    it("works in conditional expressions", function()
      local passage = Passage.new("test", "HP: |hp>[50]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local result = interpreter:eval("return whisker.hook.number('hp') > 30")
      assert.is_true(result)
      
      result = interpreter:eval("return whisker.hook.number('hp') > 60")
      assert.is_false(result)
    end)
    
    it("works with multiple hooks", function()
      local passage = Passage.new("test", "HP: |hp>[100] MP: |mp>[50]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local hp = interpreter:eval("return whisker.hook.number('hp')")
      local mp = interpreter:eval("return whisker.hook.number('mp')")
      
      assert.equals(100, hp)
      assert.equals(50, mp)
    end)
    
    it("reflects hook modifications", function()
      local passage = Passage.new("test", "Counter: |count>[0]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      engine:execute_hook_operation("replace", "count", "5")
      local result = interpreter:eval("return whisker.hook.number('count')")
      assert.equals(5, result)
      
      engine:execute_hook_operation("replace", "count", "10")
      result = interpreter:eval("return whisker.hook.number('count')")
      assert.equals(10, result)
    end)
  end)
end)
