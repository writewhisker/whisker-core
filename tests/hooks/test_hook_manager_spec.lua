-- Test suite for HookManager
-- Run with: busted spec/wls2/test_hook_manager_spec.lua

local HookManager = require("lib.whisker.wls2.hook_manager")

describe("HookManager", function()
  local manager
  
  before_each(function()
    manager = HookManager.new()
  end)
  
  describe("register_hook", function()
    it("registers a new hook with correct properties", function()
      local hook_id = manager:register_hook("passage_1", "flowers", "roses")
      
      assert.are.equal("passage_1_flowers", hook_id)
      
      local hook = manager:get_hook(hook_id)
      assert.is_not_nil(hook)
      assert.are.equal("flowers", hook.name)
      assert.are.equal("roses", hook.content)
      assert.are.equal("roses", hook.current_content)
      assert.is_true(hook.visible)
      assert.are.equal("passage_1", hook.passage_id)
      assert.are.equal(0, hook.modified_count)
    end)
    
    it("tracks passage hooks correctly", function()
      manager:register_hook("passage_1", "flowers", "roses")
      manager:register_hook("passage_1", "weather", "sunny")
      
      local hooks = manager:get_passage_hooks("passage_1")
      assert.are.equal(2, #hooks)
    end)
    
    it("creates unique IDs for hooks in different passages", function()
      local id1 = manager:register_hook("passage_1", "door", "locked")
      local id2 = manager:register_hook("passage_2", "door", "open")
      
      assert.are_not.equal(id1, id2)
    end)
  end)
  
  describe("replace_hook", function()
    it("replaces hook content", function()
      local hook_id = manager:register_hook("passage_1", "flowers", "roses")
      local success = manager:replace_hook(hook_id, "wilted petals")
      
      assert.is_true(success)
      
      local hook = manager:get_hook(hook_id)
      assert.are.equal("wilted petals", hook.current_content)
      assert.are.equal("roses", hook.content) -- Original preserved
      assert.are.equal(1, hook.modified_count)
    end)
    
    it("returns false for non-existent hook", function()
      local success, err = manager:replace_hook("nonexistent", "content")
      assert.is_false(success)
      assert.is_not_nil(err)
    end)
  end)
  
  describe("append_hook", function()
    it("appends content to hook", function()
      local hook_id = manager:register_hook("passage_1", "story", "Once upon a time")
      manager:append_hook(hook_id, ", there was a hero")
      
      local hook = manager:get_hook(hook_id)
      assert.are.equal("Once upon a time, there was a hero", hook.current_content)
      assert.are.equal(1, hook.modified_count)
    end)
    
    it("can be called multiple times", function()
      local hook_id = manager:register_hook("passage_1", "list", "apple")
      manager:append_hook(hook_id, ", banana")
      manager:append_hook(hook_id, ", orange")
      
      local hook = manager:get_hook(hook_id)
      assert.are.equal("apple, banana, orange", hook.current_content)
      assert.are.equal(2, hook.modified_count)
    end)
  end)
  
  describe("prepend_hook", function()
    it("prepends content to hook", function()
      local hook_id = manager:register_hook("passage_1", "weather", "shining")
      manager:prepend_hook(hook_id, "The sun is ")
      
      local hook = manager:get_hook(hook_id)
      assert.are.equal("The sun is shining", hook.current_content)
    end)
  end)
  
  describe("show_hook and hide_hook", function()
    it("hides visible hook", function()
      local hook_id = manager:register_hook("passage_1", "secret", "treasure")
      
      manager:hide_hook(hook_id)
      local hook = manager:get_hook(hook_id)
      assert.is_false(hook.visible)
    end)
    
    it("shows hidden hook", function()
      local hook_id = manager:register_hook("passage_1", "secret", "treasure")
      manager:hide_hook(hook_id)
      manager:show_hook(hook_id)
      
      local hook = manager:get_hook(hook_id)
      assert.is_true(hook.visible)
    end)
    
    it("does not affect content", function()
      local hook_id = manager:register_hook("passage_1", "text", "content")
      manager:hide_hook(hook_id)
      
      local hook = manager:get_hook(hook_id)
      assert.are.equal("content", hook.current_content)
    end)
  end)
  
  describe("clear_passage_hooks", function()
    it("clears all hooks for a passage", function()
      manager:register_hook("passage_1", "flowers", "roses")
      manager:register_hook("passage_1", "weather", "sunny")
      manager:register_hook("passage_2", "door", "locked")
      
      manager:clear_passage_hooks("passage_1")
      
      assert.are.equal(0, #manager:get_passage_hooks("passage_1"))
      assert.are.equal(1, #manager:get_passage_hooks("passage_2"))
    end)
    
    it("removes hooks from registry", function()
      local hook_id = manager:register_hook("passage_1", "test", "value")
      manager:clear_passage_hooks("passage_1")
      
      assert.is_nil(manager:get_hook(hook_id))
    end)
  end)
  
  describe("serialization", function()
    it("serializes and deserializes state", function()
      manager:register_hook("passage_1", "flowers", "roses")
      manager:replace_hook("passage_1_flowers", "wilted")
      
      local data = manager:serialize()
      
      local new_manager = HookManager.new()
      new_manager:deserialize(data)
      
      local hook = new_manager:get_hook("passage_1_flowers")
      assert.is_not_nil(hook)
      assert.are.equal("wilted", hook.current_content)
      assert.are.equal("roses", hook.content)
    end)
    
    it("preserves visibility state", function()
      local hook_id = manager:register_hook("passage_1", "secret", "value")
      manager:hide_hook(hook_id)
      
      local data = manager:serialize()
      local new_manager = HookManager.new()
      new_manager:deserialize(data)
      
      local hook = new_manager:get_hook(hook_id)
      assert.is_false(hook.visible)
    end)
    
    it("preserves passage associations", function()
      manager:register_hook("passage_1", "hook1", "value1")
      manager:register_hook("passage_1", "hook2", "value2")
      
      local data = manager:serialize()
      local new_manager = HookManager.new()
      new_manager:deserialize(data)
      
      local hooks = new_manager:get_passage_hooks("passage_1")
      assert.are.equal(2, #hooks)
    end)
  end)
end)
