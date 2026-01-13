-- spec/renderer/test_hook_rendering.lua
-- WLS 2.0 Renderer Hook Integration Tests

describe("Renderer with Hooks", function()
  local Renderer = require("lib.whisker.core.renderer")
  local HookManager = require("lib.whisker.wls2.hook_manager")
  local Passage = require("lib.whisker.story.passage")
  
  local renderer
  local hook_manager
  
  before_each(function()
    hook_manager = HookManager.new()
    renderer = Renderer.new(nil, "plain", hook_manager)
  end)
  
  describe("extract_hooks", function()
    it("extracts single hook", function()
      local text = "You see |flowers>[roses] in the garden."
      local processed, hooks = renderer:extract_hooks(text, "passage_1")
      
      -- Should contain placeholder
      assert.matches("{{HOOK:passage_1_flowers}}", processed)
      
      -- Should not contain original hook syntax
      assert.is_not.matches("|flowers>", processed)
      
      -- Should register hook
      local hook = hook_manager:get_hook("passage_1_flowers")
      assert.is_not_nil(hook)
      assert.equals("roses", hook.content)
    end)
    
    it("extracts multiple hooks", function()
      local text = "The |weather>[sun] shines on |flowers>[roses]."
      local processed = renderer:extract_hooks(text, "passage_1")
      
      assert.matches("{{HOOK:passage_1_weather}}", processed)
      assert.matches("{{HOOK:passage_1_flowers}}", processed)
      
      local weather = hook_manager:get_hook("passage_1_weather")
      local flowers = hook_manager:get_hook("passage_1_flowers")
      
      assert.is_not_nil(weather)
      assert.is_not_nil(flowers)
      assert.equals("sun", weather.content)
      assert.equals("roses", flowers.content)
    end)
    
    it("handles empty hook content", function()
      local text = "There is a |placeholder>[] here."
      local processed = renderer:extract_hooks(text, "passage_1")
      
      local hook = hook_manager:get_hook("passage_1_placeholder")
      assert.equals("", hook.content)
    end)
    
    it("handles hooks with special characters in content", function()
      local text = "|code>[if (x > 5) { return true; }]"
      local processed = renderer:extract_hooks(text, "passage_1")
      
      local hook = hook_manager:get_hook("passage_1_code")
      assert.equals("if (x > 5) { return true; }", hook.content)
    end)
    
    it("preserves text around hooks", function()
      local text = "Start |middle>[content] end"
      local processed = renderer:extract_hooks(text, "passage_1")
      
      assert.matches("Start", processed)
      assert.matches("end", processed)
      assert.matches("{{HOOK:passage_1_middle}}", processed)
    end)
  end)
  
  describe("render_hooks", function()
    it("renders visible hook", function()
      hook_manager:register_hook("passage_1", "test", "content")
      local text = "This is {{HOOK:passage_1_test}} here."
      
      local rendered = renderer:render_hooks(text, "passage_1")
      
      assert.equals("This is content here.", rendered)
    end)
    
    it("hides invisible hook", function()
      hook_manager:register_hook("passage_1", "secret", "hidden text")
      hook_manager:hide_hook("passage_1_secret")
      
      local text = "Before {{HOOK:passage_1_secret}} after."
      local rendered = renderer:render_hooks(text, "passage_1")
      
      assert.equals("Before  after.", rendered)
    end)
    
    it("renders modified hook content", function()
      hook_manager:register_hook("passage_1", "dynamic", "initial")
      hook_manager:replace_hook("passage_1_dynamic", "updated")
      
      local text = "Value: {{HOOK:passage_1_dynamic}}"
      local rendered = renderer:render_hooks(text, "passage_1")
      
      assert.equals("Value: updated", rendered)
    end)
    
    it("handles non-existent hook placeholder gracefully", function()
      local text = "{{HOOK:passage_1_nonexistent}}"
      local rendered = renderer:render_hooks(text, "passage_1")
      
      assert.equals("", rendered)
    end)
    
    it("renders multiple hooks in one line", function()
      hook_manager:register_hook("passage_1", "a", "first")
      hook_manager:register_hook("passage_1", "b", "second")
      
      local text = "{{HOOK:passage_1_a}} and {{HOOK:passage_1_b}}"
      local rendered = renderer:render_hooks(text, "passage_1")
      
      assert.equals("first and second", rendered)
    end)
  end)
  
  describe("render_passage", function()
    it("renders passage with hooks", function()
      local passage = Passage.new("test", "You see |flowers>[roses].")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      -- Hook should be rendered
      assert.matches("roses", rendered)
      assert.is_not.matches("|flowers>", rendered)
      assert.is_not.matches("{{HOOK:", rendered)
    end)
    
    it("processes hooks with expressions", function()
      local passage = Passage.new("test", "|message>[Hello $name]")
      local game_state = { name = "World" }
      
      local rendered = renderer:render_passage(passage, game_state, "passage_1")
      
      -- Expression should be evaluated within hook content
      assert.matches("Hello World", rendered)
    end)
    
    it("processes hooks with formatting", function()
      local passage = Passage.new("test", "|text>[**bold text**]")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      -- Formatting should be applied to hook content (plain platform = no tags)
      assert.matches("bold text", rendered)
    end)
    
    it("handles multiple hooks in passage", function()
      local passage = Passage.new("test", 
        "|weather>[sunny] day with |flowers>[roses]")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.matches("sunny day with roses", rendered)
    end)
    
    it("handles passage with only a hook", function()
      local passage = Passage.new("test", "|content>[Just this]")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.equals("Just this", rendered)
    end)
    
    it("handles hook at start of passage", function()
      local passage = Passage.new("test", "|start>[Begin] the story")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.matches("Begin the story", rendered)
    end)
    
    it("handles hook at end of passage", function()
      local passage = Passage.new("test", "The end |final>[.]")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.matches("The end %.", rendered)
    end)
  end)
  
  describe("rerender_passage", function()
    it("re-renders with updated hook content", function()
      local passage = Passage.new("test", "Status: |status>[Ready]")
      
      -- Initial render
      renderer:render_passage(passage, {}, "passage_1")
      
      -- Update hook
      hook_manager:replace_hook("passage_1_status", "Fighting!")
      
      -- Re-render
      local rendered = renderer:rerender_passage(passage, {}, "passage_1")
      
      assert.matches("Fighting!", rendered)
      assert.is_not.matches("Ready", rendered)
    end)
    
    it("does not re-register hooks", function()
      local passage = Passage.new("test", "|counter>[0]")
      
      renderer:render_passage(passage, {}, "passage_1")
      
      -- Modify hook
      hook_manager:replace_hook("passage_1_counter", "1")
      
      -- Re-render should use existing hook
      local rendered = renderer:rerender_passage(passage, {}, "passage_1")
      
      -- Verify hook still has modified content
      local hook = hook_manager:get_hook("passage_1_counter")
      assert.equals("1", hook.current_content)
      assert.matches("1", rendered)
    end)
    
    it("respects visibility changes", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      
      renderer:render_passage(passage, {}, "passage_1")
      hook_manager:hide_hook("passage_1_secret")
      
      local rendered = renderer:rerender_passage(passage, {}, "passage_1")
      
      assert.is_not.matches("treasure", rendered)
    end)
    
    it("handles multiple re-renders", function()
      local passage = Passage.new("test", "Count: |num>[0]")
      
      renderer:render_passage(passage, {}, "passage_1")
      
      -- Multiple updates
      hook_manager:replace_hook("passage_1_num", "1")
      local r1 = renderer:rerender_passage(passage, {}, "passage_1")
      assert.matches("1", r1)
      
      hook_manager:replace_hook("passage_1_num", "2")
      local r2 = renderer:rerender_passage(passage, {}, "passage_1")
      assert.matches("2", r2)
      
      hook_manager:replace_hook("passage_1_num", "3")
      local r3 = renderer:rerender_passage(passage, {}, "passage_1")
      assert.matches("3", r3)
    end)
  end)
  
  describe("platform rendering", function()
    it("renders correctly for console platform", function()
      local console_renderer = Renderer.new(nil, "console", hook_manager)
      local passage = Passage.new("test", "|text>[**bold**]")
      
      local rendered = console_renderer:render_passage(passage, {}, "passage_1")
      
      -- Should include ANSI codes for console
      assert.matches("\027", rendered) -- ANSI escape
      assert.matches("bold", rendered)
    end)
    
    it("renders correctly for web platform", function()
      local web_renderer = Renderer.new(nil, "web", hook_manager)
      local passage = Passage.new("test", "|text>[**bold**]")
      
      local rendered = web_renderer:render_passage(passage, {}, "passage_1")
      
      -- Should include HTML tags
      assert.matches("<strong>", rendered)
      assert.matches("bold", rendered)
    end)
    
    it("renders correctly for plain platform", function()
      local plain_renderer = Renderer.new(nil, "plain", hook_manager)
      local passage = Passage.new("test", "|text>[**bold**]")
      
      local rendered = plain_renderer:render_passage(passage, {}, "passage_1")
      
      -- Plain text, no formatting tags
      assert.equals("bold", rendered)
    end)
  end)
  
  describe("edge cases", function()
    it("handles consecutive hooks", function()
      local passage = Passage.new("test", "|a>[first]|b>[second]|c>[third]")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.matches("firstsecondthird", rendered)
    end)
    
    it("handles nested brackets in hook content", function()
      local passage = Passage.new("test", "|array>[items[0], items[1]]")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.matches("items%[0%], items%[1%]", rendered)
    end)
    
    it("handles empty passage", function()
      local passage = Passage.new("test", "")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.equals("", rendered)
    end)
    
    it("handles passage with no hooks", function()
      local passage = Passage.new("test", "Just plain text here.")
      local rendered = renderer:render_passage(passage, {}, "passage_1")
      
      assert.equals("Just plain text here.", rendered)
    end)
  end)
  
  describe("hook operations", function()
    it("handles append operation", function()
      local passage = Passage.new("test", "List: |items>[apple]")
      renderer:render_passage(passage, {}, "passage_1")
      
      hook_manager:append_hook("passage_1_items", ", banana")
      local rendered = renderer:rerender_passage(passage, {}, "passage_1")
      
      assert.matches("apple, banana", rendered)
    end)
    
    it("handles prepend operation", function()
      local passage = Passage.new("test", "Message: |text>[world]")
      renderer:render_passage(passage, {}, "passage_1")
      
      hook_manager:prepend_hook("passage_1_text", "Hello ")
      local rendered = renderer:rerender_passage(passage, {}, "passage_1")
      
      assert.matches("Hello world", rendered)
    end)
    
    it("handles show/hide operations", function()
      local passage = Passage.new("test", "Secret: |secret>[treasure]")
      renderer:render_passage(passage, {}, "passage_1")
      
      -- Hide
      hook_manager:hide_hook("passage_1_secret")
      local r1 = renderer:rerender_passage(passage, {}, "passage_1")
      assert.is_not.matches("treasure", r1)
      
      -- Show
      hook_manager:show_hook("passage_1_secret")
      local r2 = renderer:rerender_passage(passage, {}, "passage_1")
      assert.matches("treasure", r2)
    end)
  end)
end)
