-- spec/engine/test_hook_operations.lua
-- Integration tests for Engine Hook Operations

describe("Engine Hook Operations", function()
  local Engine = require("lib.whisker.core.engine")
  local Story = require("lib.whisker.story.story")
  local Passage = require("lib.whisker.story.passage")
  
  local engine
  local story
  
  before_each(function()
    story = Story.new()
    engine = Engine.new()
    engine:init(story, {platform = "plain"})
  end)
  
  -- ========================================================================
  -- Test Suite 1: Hook Lifecycle
  -- ========================================================================
  
  describe("hook lifecycle", function()
    it("registers hooks on passage render", function()
      local passage = Passage.new("start", "You see |flowers>[roses].")
      story:add_passage(passage)
      
      engine:navigate_to_passage("start")
      
      local hook = engine.hook_manager:get_hook("start_flowers")
      assert.is_not_nil(hook)
      assert.equals("roses", hook.content)
    end)
    
    it("clears hooks on passage navigation", function()
      local p1 = Passage.new("room1", "Room 1 has |item>[key].")
      local p2 = Passage.new("room2", "Room 2 has |item>[sword].")
      story:add_passage(p1)
      story:add_passage(p2)
      
      engine:navigate_to_passage("room1")
      local hook1 = engine.hook_manager:get_hook("room1_item")
      assert.is_not_nil(hook1)
      
      engine:navigate_to_passage("room2")
      local hook1_after = engine.hook_manager:get_hook("room1_item")
      local hook2 = engine.hook_manager:get_hook("room2_item")
      
      assert.is_nil(hook1_after) -- Old hook cleared
      assert.is_not_nil(hook2) -- New hook registered
    end)
    
    it("preserves hooks during re-render", function()
      local passage = Passage.new("start", "Status: |status>[Ready]")
      story:add_passage(passage)
      
      engine:navigate_to_passage("start")
      engine:execute_hook_operation("replace", "status", "Fighting!")
      
      local hook = engine.hook_manager:get_hook("start_status")
      assert.equals("Fighting!", hook.current_content)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 2: Operation Execution
  -- ========================================================================
  
  describe("execute_hook_operation", function()
    it("executes replace operation", function()
      local passage = Passage.new("test", "HP: |hp>[100]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered, err = engine:execute_hook_operation("replace", "hp", "85")
      
      assert.is_nil(err)
      assert.matches("85", rendered)
      assert.is_not.matches("100", rendered)
    end)
    
    it("executes append operation", function()
      local passage = Passage.new("test", "Items: |items>[sword]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered = engine:execute_hook_operation("append", "items", ", shield")
      
      assert.matches("sword, shield", rendered)
    end)
    
    it("executes prepend operation", function()
      local passage = Passage.new("test", "Message: |msg>[world]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered = engine:execute_hook_operation("prepend", "msg", "Hello ")
      
      assert.matches("Hello world", rendered)
    end)
    
    it("executes show operation", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      engine.hook_manager:hide_hook("test_secret")
      local r1 = engine.renderer:rerender_passage(passage, {}, "test")
      assert.is_not.matches("treasure", r1)
      
      local rendered = engine:execute_hook_operation("show", "secret")
      assert.matches("treasure", rendered)
    end)
    
    it("executes hide operation", function()
      local passage = Passage.new("test", "Visible: |item>[key]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered = engine:execute_hook_operation("hide", "item")
      assert.is_not.matches("key", rendered)
    end)
    
    it("returns error for non-existent hook", function()
      local passage = Passage.new("test", "No hooks here")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered, err = engine:execute_hook_operation("replace", "missing", "value")
      
      assert.is_nil(rendered)
      assert.is_not_nil(err)
      assert.matches("not found", err)
    end)
    
    it("returns error for invalid operation", function()
      local passage = Passage.new("test", "Test |hook>[content]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered, err = engine:execute_hook_operation("invalid", "hook", "value")
      
      assert.is_nil(rendered)
      assert.matches("Unknown operation", err)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 3: Choice Integration
  -- ========================================================================
  
  describe("choice integration", function()
    it("parses hook operations from choice text", function()
      local choice_text = "@replace: status { Fighting! } Go to battle"
      local ops = engine:parse_hook_operations(choice_text)
      
      assert.equals(1, #ops)
      assert.equals("replace", ops[1].operation)
      assert.equals("status", ops[1].target)
      assert.equals(" Fighting! ", ops[1].content)
    end)
    
    it("parses multiple operations", function()
      local choice_text = "@replace: hp { 50 } @hide: armor { } Attack"
      local ops = engine:parse_hook_operations(choice_text)
      
      assert.equals(2, #ops)
      assert.equals("replace", ops[1].operation)
      assert.equals("hide", ops[2].operation)
    end)
    
    it("executes hook operations on choice selection", function()
      local passage = Passage.new("battle", [[
You are fighting. HP: |hp>[100]
+ [@replace: hp { 85 } Take damage] -> battle
]])
      story:add_passage(passage)
      engine:navigate_to_passage("battle")
      
      -- Simulate choice selection
      local rendered = engine:execute_choice(1)
      
      assert.matches("85", rendered)
      assert.is_not.matches("100", rendered)
    end)
    
    it("executes multiple operations in choice", function()
      local passage = Passage.new("loot", [[
Chest: |chest>[closed]
Items: |items>[empty]
+ [@replace: chest { open } @replace: items { gold, sword }] -> loot
]])
      story:add_passage(passage)
      engine:navigate_to_passage("loot")
      
      local rendered = engine:execute_choice(1)
      
      assert.matches("open", rendered)
      assert.matches("gold, sword", rendered)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 4: State Management
  -- ========================================================================
  
  describe("state management", function()
    it("serializes hook state", function()
      local passage = Passage.new("test", "Value: |val>[initial]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("replace", "val", "modified")
      
      local state = engine:serialize_state()
      
      assert.is_not_nil(state.hooks)
      assert.is_not_nil(state.hooks.hooks)
    end)
    
    it("deserializes hook state", function()
      local passage = Passage.new("test", "Value: |val>[initial]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("replace", "val", "modified")
      
      local state = engine:serialize_state()
      
      -- Create new engine and restore
      local engine2 = Engine.new()
      engine2:init(story, {platform = "plain"})
      engine2:deserialize_state(state)
      
      local hook = engine2.hook_manager:get_hook("test_val")
      assert.equals("modified", hook.current_content)
    end)
    
    it("preserves hook visibility in save/load", function()
      local passage = Passage.new("test", "Secret: |secret>[hidden]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      engine:execute_hook_operation("hide", "secret")
      
      local state = engine:serialize_state()
      local engine2 = Engine.new()
      engine2:init(story, {platform = "plain"})
      engine2:deserialize_state(state)
      
      local hook = engine2.hook_manager:get_hook("test_secret")
      assert.is_false(hook.visible)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 5: Edge Cases
  -- ========================================================================
  
  describe("edge cases", function()
    it("handles rapid successive operations", function()
      local passage = Passage.new("test", "Counter: |count>[0]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      engine:execute_hook_operation("replace", "count", "1")
      engine:execute_hook_operation("replace", "count", "2")
      engine:execute_hook_operation("replace", "count", "3")
      
      local hook = engine.hook_manager:get_hook("test_count")
      assert.equals("3", hook.current_content)
    end)
    
    it("handles operations with special characters", function()
      local passage = Passage.new("test", "Code: |code>[x]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered = engine:execute_hook_operation("replace", "code", "if (x > 5) { return true; }")
      assert.matches("if %(x > 5%)", rendered)
    end)
    
    it("handles empty content operations", function()
      local passage = Passage.new("test", "Text: |text>[something]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local rendered = engine:execute_hook_operation("replace", "text", "")
      assert.equals("Text: ", rendered)
    end)
    
    it("handles passage with many hooks", function()
      local content = ""
      for i = 1, 50 do
        content = content .. "|hook" .. i .. ">[value" .. i .. "] "
      end
      
      local passage = Passage.new("test", content)
      story:add_passage(passage)
      
      local rendered = engine:navigate_to_passage("test")
      
      -- All hooks should render
      for i = 1, 50 do
        assert.matches("value" .. i, rendered)
      end
    end)
  end)
end)
