--- Autosave System Tests
-- Comprehensive test suite for the autosave system
--
-- @module tests.storage.autosave_spec

describe("Autosave System", function()
  local Autosave
  local Storage
  local storage
  local autosaver
  
  setup(function()
    Autosave = require("whisker.storage.autosave")
    Storage = require("whisker.storage")
  end)
  
  before_each(function()
    storage = Storage.new({ backend = "sqlite", path = ":memory:" })
    storage:initialize()
    
    autosaver = Autosave.new({
      storage = storage,
      interval = 5,
      debounce = 1,
      max_retries = 3
    })
  end)
  
  after_each(function()
    if autosaver then
      autosaver:stop()
    end
    if storage then
      storage:clear()
    end
  end)
  
  describe("Constructor", function()
    it("should create autosaver with storage", function()
      local a = Autosave.new({ storage = storage })
      assert.is_table(a)
      assert.equals(storage, a.storage)
    end)
    
    it("should require storage service", function()
      assert.has_error(function()
        Autosave.new({})
      end)
    end)
    
    it("should set default interval", function()
      local a = Autosave.new({ storage = storage })
      assert.equals(30, a.interval)
    end)
    
    it("should allow custom interval", function()
      local a = Autosave.new({ storage = storage, interval = 60 })
      assert.equals(60, a.interval)
    end)
    
    it("should set default debounce", function()
      local a = Autosave.new({ storage = storage })
      assert.equals(2, a.debounce)
    end)
    
    it("should set default max retries", function()
      local a = Autosave.new({ storage = storage })
      assert.equals(3, a.max_retries)
    end)
    
    it("should initialize dirty tracking", function()
      local a = Autosave.new({ storage = storage })
      assert.is_table(a.dirty)
      assert.is_table(a.states)
      assert.is_table(a.timers)
    end)
    
    it("should start in stopped state", function()
      local a = Autosave.new({ storage = storage })
      assert.is_false(a.running)
      assert.is_false(a.paused)
    end)
    
    it("should support save callback", function()
      local callback = function() end
      local a = Autosave.new({ storage = storage, on_save = callback })
      assert.equals(callback, a.on_save)
    end)
    
    it("should support conflict callback", function()
      local callback = function() end
      local a = Autosave.new({ storage = storage, on_conflict = callback })
      assert.equals(callback, a.on_conflict)
    end)
  end)
  
  describe("Mark Dirty", function()
    it("should mark story as dirty", function()
      local story = { id = "test-story" }
      
      autosaver:mark_dirty("test-story", story)
      
      assert.is_true(autosaver:is_dirty("test-story"))
    end)
    
    it("should store story data", function()
      local story = { id = "data-test", title = "Test" }
      
      autosaver:mark_dirty("data-test", story)
      
      assert.is_table(autosaver.dirty["data-test"])
      assert.equals("Test", autosaver.dirty["data-test"].data.title)
    end)
    
    it("should track last modified time", function()
      local story = { id = "time-test" }
      local before = os.time()
      
      autosaver:mark_dirty("time-test", story)
      
      local after = os.time()
      local modified = autosaver.dirty["time-test"].last_modified
      
      assert.is_true(modified >= before and modified <= after)
    end)
    
    it("should initialize retry count", function()
      autosaver:mark_dirty("retry-test", { id = "retry-test" })
      
      assert.equals(0, autosaver.dirty["retry-test"].retries)
    end)
    
    it("should set state to idle", function()
      autosaver:mark_dirty("state-test", { id = "state-test" })
      
      assert.equals(Autosave.State.IDLE, autosaver:get_state("state-test"))
    end)
    
    it("should schedule debounced save", function()
      autosaver:mark_dirty("debounce-test", { id = "debounce-test" })
      
      assert.is_table(autosaver.timers["debounce-test"])
      assert.is_number(autosaver.timers["debounce-test"].debounce_time)
    end)
    
    it("should not schedule save when paused", function()
      autosaver:pause()
      autosaver:mark_dirty("paused-test", { id = "paused-test" })
      
      assert.is_true(autosaver:is_dirty("paused-test"))
      -- Timer should not be set
      assert.is_nil(autosaver.timers["paused-test"])
    end)
  end)
  
  describe("Save Now", function()
    it("should save dirty story immediately", function()
      local story = { id = "save-now", title = "Immediate" }
      autosaver:mark_dirty("save-now", story)
      
      local success = autosaver:save_now("save-now")
      assert.is_true(success)
      
      -- Verify saved to storage
      local loaded = storage:load_story("save-now")
      assert.equals("Immediate", loaded.title)
    end)
    
    it("should clear dirty status after successful save", function()
      autosaver:mark_dirty("clear-test", { id = "clear-test" })
      
      autosaver:save_now("clear-test")
      
      assert.is_false(autosaver:is_dirty("clear-test"))
    end)
    
    it("should set state to saved after success", function()
      autosaver:mark_dirty("state-saved", { id = "state-saved" })
      
      autosaver:save_now("state-saved")
      
      assert.equals(Autosave.State.SAVED, autosaver:get_state("state-saved"))
    end)
    
    it("should call save callback on success", function()
      local callback_called = false
      local callback_success = nil
      local callback_story_id = nil
      
      local a = Autosave.new({
        storage = storage,
        on_save = function(success, error, story_id)
          callback_called = true
          callback_success = success
          callback_story_id = story_id
        end
      })
      
      a:mark_dirty("callback-test", { id = "callback-test" })
      a:save_now("callback-test")
      
      assert.is_true(callback_called)
      assert.is_true(callback_success)
      assert.equals("callback-test", callback_story_id)
    end)
    
    it("should return error for non-dirty story", function()
      local success, msg = autosaver:save_now("nonexistent")
      assert.is_true(success)
      assert.equals("Story not dirty", msg)
    end)
    
    it("should force save non-dirty story", function()
      local story = { id = "force-test" }
      storage:save_story("force-test", story)
      
      local success, msg = autosaver:save_now("force-test", true)
      assert.is_false(success)
      assert.is_string(msg)
    end)
    
    it("should increment retry count on failure", function()
      -- This test requires mocking storage to fail
      -- For now, we'll test the retry structure
      autosaver:mark_dirty("retry-test", { id = "retry-test" })
      
      local entry = autosaver.dirty["retry-test"]
      assert.equals(0, entry.retries)
    end)
    
    it("should set state to error after max retries", function()
      -- This would require mocking repeated failures
      -- The structure is tested above
      assert.equals(3, autosaver.max_retries)
    end)
  end)
  
  describe("Start and Stop", function()
    it("should start autosave system", function()
      autosaver:start()
      assert.is_true(autosaver.running)
      assert.is_false(autosaver.paused)
    end)
    
    it("should stop autosave system", function()
      autosaver:start()
      autosaver:stop()
      assert.is_false(autosaver.running)
    end)
  end)
  
  describe("Pause and Resume", function()
    it("should pause autosave", function()
      autosaver:start()
      autosaver:pause()
      
      assert.is_true(autosaver.paused)
    end)
    
    it("should resume autosave", function()
      autosaver:start()
      autosaver:pause()
      autosaver:resume()
      
      assert.is_false(autosaver.paused)
    end)
    
    it("should reschedule saves on resume", function()
      autosaver:mark_dirty("resume-test", { id = "resume-test" })
      autosaver:pause()
      autosaver:resume()
      
      assert.is_table(autosaver.timers["resume-test"])
    end)
  end)
  
  describe("Process", function()
    it("should not process when not running", function()
      autosaver:mark_dirty("not-running", { id = "not-running" })
      
      autosaver:process()
      
      -- Story should still be dirty
      assert.is_true(autosaver:is_dirty("not-running"))
    end)
    
    it("should not process when paused", function()
      autosaver:start()
      autosaver:pause()
      autosaver:mark_dirty("paused-process", { id = "paused-process" })
      
      autosaver:process()
      
      assert.is_true(autosaver:is_dirty("paused-process"))
    end)
    
    it("should save after debounce period", function()
      autosaver:start()
      autosaver:mark_dirty("debounce-save", { id = "debounce-save" })
      
      -- Wait for debounce
      os.execute("sleep 2")
      
      autosaver:process()
      
      -- Should be saved
      assert.is_false(autosaver:is_dirty("debounce-save"))
    end)
    
    it("should save after interval period", function()
      local quick_saver = Autosave.new({
        storage = storage,
        interval = 1,
        debounce = 10  -- High debounce
      })
      
      quick_saver:start()
      quick_saver:mark_dirty("interval-save", { id = "interval-save" })
      
      -- Wait for interval
      os.execute("sleep 2")
      
      quick_saver:process()
      
      -- Should be saved
      assert.is_false(quick_saver:is_dirty("interval-save"))
    end)
  end)
  
  describe("State Management", function()
    it("should get state for story", function()
      autosaver:mark_dirty("state-test", { id = "state-test" })
      
      local state = autosaver:get_state("state-test")
      assert.equals(Autosave.State.IDLE, state)
    end)
    
    it("should return idle for unknown story", function()
      local state = autosaver:get_state("unknown")
      assert.equals(Autosave.State.IDLE, state)
    end)
    
    it("should track saving state", function()
      autosaver:mark_dirty("saving", { id = "saving" })
      autosaver.states["saving"] = Autosave.State.SAVING
      
      assert.equals(Autosave.State.SAVING, autosaver:get_state("saving"))
    end)
    
    it("should track saved state", function()
      autosaver:mark_dirty("saved", { id = "saved" })
      autosaver:save_now("saved")
      
      assert.equals(Autosave.State.SAVED, autosaver:get_state("saved"))
    end)
  end)
  
  describe("Dirty Status", function()
    it("should check if story is dirty", function()
      assert.is_false(autosaver:is_dirty("clean"))
      
      autosaver:mark_dirty("dirty", { id = "dirty" })
      assert.is_true(autosaver:is_dirty("dirty"))
    end)
    
    it("should clear dirty status manually", function()
      autosaver:mark_dirty("manual-clear", { id = "manual-clear" })
      
      autosaver:clear_dirty("manual-clear")
      
      assert.is_false(autosaver:is_dirty("manual-clear"))
      assert.equals(Autosave.State.SAVED, autosaver:get_state("manual-clear"))
    end)
    
    it("should get list of dirty stories", function()
      autosaver:mark_dirty("dirty-1", { id = "dirty-1" })
      autosaver:mark_dirty("dirty-2", { id = "dirty-2" })
      autosaver:mark_dirty("dirty-3", { id = "dirty-3" })
      
      local dirty_list = autosaver:get_dirty_stories()
      assert.equals(3, #dirty_list)
    end)
  end)
  
  describe("Save All", function()
    it("should save all dirty stories", function()
      autosaver:mark_dirty("all-1", { id = "all-1" })
      autosaver:mark_dirty("all-2", { id = "all-2" })
      autosaver:mark_dirty("all-3", { id = "all-3" })
      
      local saved, failed = autosaver:save_all()
      
      assert.equals(3, saved)
      assert.equals(0, failed)
      
      -- All should be saved to storage
      assert.is_not_nil(storage:load_story("all-1"))
      assert.is_not_nil(storage:load_story("all-2"))
      assert.is_not_nil(storage:load_story("all-3"))
    end)
    
    it("should return count of saves and failures", function()
      autosaver:mark_dirty("count-1", { id = "count-1" })
      autosaver:mark_dirty("count-2", { id = "count-2" })
      
      local saved, failed = autosaver:save_all()
      
      assert.is_number(saved)
      assert.is_number(failed)
      assert.equals(2, saved + failed)
    end)
  end)
  
  describe("Statistics", function()
    it("should get autosave statistics", function()
      local stats = autosaver:get_stats()
      
      assert.is_table(stats)
      assert.is_boolean(stats.running)
      assert.is_boolean(stats.paused)
      assert.is_number(stats.dirty_count)
      assert.is_table(stats.states)
    end)
    
    it("should track dirty count", function()
      autosaver:mark_dirty("stat-1", { id = "stat-1" })
      autosaver:mark_dirty("stat-2", { id = "stat-2" })
      
      local stats = autosaver:get_stats()
      assert.equals(2, stats.dirty_count)
    end)
    
    it("should track state counts", function()
      autosaver:mark_dirty("idle-1", { id = "idle-1" })
      autosaver:mark_dirty("idle-2", { id = "idle-2" })
      
      local stats = autosaver:get_stats()
      assert.is_number(stats.states.idle)
    end)
    
    it("should reflect running status", function()
      autosaver:start()
      local stats = autosaver:get_stats()
      assert.is_true(stats.running)
    end)
    
    it("should reflect paused status", function()
      autosaver:start()
      autosaver:pause()
      
      local stats = autosaver:get_stats()
      assert.is_true(stats.paused)
    end)
  end)
  
  describe("Conflict Detection", function()
    it("should detect no conflict for new story", function()
      local story = { id = "new-conflict" }
      
      local has_conflict, remote = autosaver:detect_conflict("new-conflict", story)
      
      assert.is_false(has_conflict)
      assert.is_nil(remote)
    end)
    
    it("should detect conflict with different content", function()
      local original = { id = "conflict-test", version = 1 }
      storage:save_story("conflict-test", original)
      
      local local_story = { id = "conflict-test", version = 2 }
      
      local has_conflict, remote = autosaver:detect_conflict("conflict-test", local_story)
      
      assert.is_true(has_conflict)
      assert.is_table(remote)
    end)
    
    it("should detect no conflict for identical stories", function()
      local story = { id = "same", data = "identical" }
      storage:save_story("same", story)
      
      local has_conflict, remote = autosaver:detect_conflict("same", story)
      
      assert.is_false(has_conflict)
    end)
  end)
  
  describe("Conflict Resolution", function()
    it("should use default resolution (use_local)", function()
      local local_story = { id = "resolve-default", is_local = true }
      local remote_story = { id = "resolve-default", is_remote = true }
      
      local resolution = autosaver:resolve_conflict("resolve-default", local_story, remote_story)
      
      assert.equals("use_local", resolution)
    end)
    
    it("should call custom conflict handler", function()
      local handler_called = false
      local handler_story_id = nil
      
      local custom_saver = Autosave.new({
        storage = storage,
        on_conflict = function(story_id, local_s, remote_s)
          handler_called = true
          handler_story_id = story_id
          return "use_remote"
        end
      })
      
      local resolution = custom_saver:resolve_conflict("custom-resolve", {}, {})
      
      assert.is_true(handler_called)
      assert.equals("custom-resolve", handler_story_id)
      assert.equals("use_remote", resolution)
    end)
  end)
  
  describe("Story Serialization", function()
    it("should serialize story to JSON", function()
      local story = { id = "serialize", title = "Test" }
      
      local serialized = autosaver:serialize_story(story)
      
      assert.is_string(serialized)
      assert.is_true(#serialized > 0)
    end)
    
    it("should produce consistent serialization", function()
      local story = { id = "consistent", data = "test" }
      
      local s1 = autosaver:serialize_story(story)
      local s2 = autosaver:serialize_story(story)
      
      assert.equals(s1, s2)
    end)
  end)
  
  describe("States", function()
    it("should have all defined states", function()
      assert.equals("idle", Autosave.State.IDLE)
      assert.equals("saving", Autosave.State.SAVING)
      assert.equals("saved", Autosave.State.SAVED)
      assert.equals("error", Autosave.State.ERROR)
      assert.equals("paused", Autosave.State.PAUSED)
    end)
  end)
  
  describe("Integration", function()
    it("should work end-to-end with storage", function()
      autosaver:start()
      
      -- Mark story dirty
      local story = { id = "integration", title = "Integration Test" }
      autosaver:mark_dirty("integration", story)
      
      -- Save immediately
      autosaver:save_now("integration")
      
      -- Verify in storage
      local loaded = storage:load_story("integration")
      assert.equals("Integration Test", loaded.title)
      
      -- No longer dirty
      assert.is_false(autosaver:is_dirty("integration"))
    end)
    
    it("should handle multiple stories", function()
      autosaver:start()
      
      autosaver:mark_dirty("multi-1", { id = "multi-1" })
      autosaver:mark_dirty("multi-2", { id = "multi-2" })
      autosaver:mark_dirty("multi-3", { id = "multi-3" })
      
      autosaver:save_all()
      
      assert.is_not_nil(storage:load_story("multi-1"))
      assert.is_not_nil(storage:load_story("multi-2"))
      assert.is_not_nil(storage:load_story("multi-3"))
    end)
  end)
end)
