-- spec/threads/test_hook_threads.lua
-- Tests for thread hook integration

describe("Thread Hook Integration", function()
  local ThreadScheduler = require("lib.whisker.threads.thread_scheduler")
  local Engine = require("lib.whisker.core.engine")
  local Story = require("lib.whisker.story.story")
  local Passage = require("lib.whisker.story.passage")
  
  local scheduler
  local engine
  local story
  
  before_each(function()
    story = Story.new()
    engine = Engine.new()
    engine:init(story, {platform = "plain"})
    scheduler = ThreadScheduler.new(engine)
  end)
  
  -- ========================================================================
  -- Test Suite 1: Hook Operation Parsing
  -- ========================================================================
  
  describe("parse_hook_operations", function()
    it("parses single hook operation", function()
      local content = "@replace: hp { 50 }"
      local ops = scheduler:parse_hook_operations(content)
      
      assert.equals(1, #ops)
      assert.equals("replace", ops[1].operation)
      assert.equals("hp", ops[1].target)
      assert.equals(" 50 ", ops[1].content)
    end)
    
    it("parses multiple hook operations", function()
      local content = "@replace: hp { 50 } some text @hide: secret { }"
      local ops = scheduler:parse_hook_operations(content)
      
      assert.equals(2, #ops)
      assert.equals("replace", ops[1].operation)
      assert.equals("hp", ops[1].target)
      assert.equals("hide", ops[2].operation)
      assert.equals("secret", ops[2].target)
    end)
    
    it("handles all operation types", function()
      local content = "@replace: a { 1 } @append: b { 2 } @prepend: c { 3 } @show: d { } @hide: e { }"
      local ops = scheduler:parse_hook_operations(content)
      
      assert.equals(5, #ops)
      assert.equals("replace", ops[1].operation)
      assert.equals("append", ops[2].operation)
      assert.equals("prepend", ops[3].operation)
      assert.equals("show", ops[4].operation)
      assert.equals("hide", ops[5].operation)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 2: Thread Execution
  -- ========================================================================
  
  describe("execute_thread_step", function()
    it("executes hook operations in thread step", function()
      local passage = Passage.new("test", "HP: |hp>[100]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      -- Create and execute thread
      local thread = {
        name = "HealthRegen",
        interval = 1,
        current_step = 1,
        content = {"@replace: hp { 95 }"}
      }
      
      scheduler:execute_thread_step(thread)
      
      local hook = engine.hook_manager:get_hook("test_hp")
      assert.equals("95", hook.current_content)
    end)
    
    it("handles multiple operations in one thread", function()
      local passage = Passage.new("test", "HP: |hp>[100] Status: |status>[OK]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      local content = "@replace: hp { 85 } @replace: status { Hurt }"
      local thread = {
        content = {content},
        current_step = 1
      }
      
      scheduler:execute_thread_step(thread)
      
      local hp = engine.hook_manager:get_hook("test_hp")
      local status = engine.hook_manager:get_hook("test_status")
      
      assert.equals("85", hp.current_content)
      assert.equals(" Hurt ", status.current_content)
    end)
    
    it("handles show and hide operations", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      -- Hide the hook
      local thread = {
        content = {"@hide: secret { }"},
        current_step = 1
      }
      scheduler:execute_thread_step(thread)
      
      local hook = engine.hook_manager:get_hook("test_secret")
      assert.is_false(hook.visible)
      
      -- Show it again
      thread.content[1] = "@show: secret { }"
      scheduler:execute_thread_step(thread)
      
      assert.is_true(hook.visible)
    end)
  end)
  
  -- ========================================================================
  -- Test Suite 3: Thread Management
  -- ========================================================================
  
  describe("thread management", function()
    it("registers threads", function()
      scheduler:register_thread("test", 1.0, {"step1", "step2"})
      
      assert.is_not_nil(scheduler.threads["test"])
      assert.equals("test", scheduler.threads["test"].name)
      assert.equals(1.0, scheduler.threads["test"].interval)
    end)
    
    it("updates threads based on time", function()
      local passage = Passage.new("test", "Counter: |count>[0]")
      story:add_passage(passage)
      engine:navigate_to_passage("test")
      
      scheduler:register_thread("counter", 1.0, {
        "@replace: count { 1 }",
        "@replace: count { 2 }"
      })
      
      -- First update (should execute step 1)
      scheduler:update(1.0)
      local hook = engine.hook_manager:get_hook("test_count")
      assert.equals("1", hook.current_content)
      
      -- Second update (should execute step 2)
      scheduler:update(1.0)
      assert.equals("2", hook.current_content)
    end)
    
    it("clears all threads", function()
      scheduler:register_thread("test1", 1.0, {"step1"})
      scheduler:register_thread("test2", 1.0, {"step1"})
      
      assert.is_not_nil(scheduler.threads["test1"])
      assert.is_not_nil(scheduler.threads["test2"])
      
      scheduler:clear()
      
      assert.is_nil(scheduler.threads["test1"])
      assert.is_nil(scheduler.threads["test2"])
    end)
  end)
end)
