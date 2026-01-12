--- Tests for Sync State Manager
-- @module tests.storage.sync.state_manager_spec

describe("SyncStateManager", function()
  local SyncStateManager
  local MockStorage
  
  before_each(function()
    -- Reset module
    package.loaded["whisker.storage.sync.state_manager"] = nil
    SyncStateManager = require("whisker.storage.sync.state_manager")
    
    -- Create mock storage backend
    MockStorage = {
      data = {},
      backend = {
        load = function(self, key)
          return MockStorage.data[key]
        end,
        save = function(self, key, data, metadata)
          MockStorage.data[key] = data
          return true
        end,
        exists = function(self, key)
          return MockStorage.data[key] ~= nil
        end
      }
    }
  end)
  
  describe("initialization", function()
    it("should create new state manager", function()
      local mgr = SyncStateManager.new(MockStorage)
      assert.is_not_nil(mgr)
    end)
    
    it("should generate device ID on creation", function()
      local mgr = SyncStateManager.new(MockStorage)
      local device_id = mgr:get_device_id()
      
      assert.is_not_nil(device_id)
      assert.is_string(device_id)
      assert.matches("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$", device_id)
    end)
    
    it("should persist device ID across instances", function()
      local mgr1 = SyncStateManager.new(MockStorage)
      local id1 = mgr1:get_device_id()
      
      -- Create new instance with same storage
      local mgr2 = SyncStateManager.new(MockStorage)
      local id2 = mgr2:get_device_id()
      
      assert.equal(id1, id2)
    end)
    
    it("should load existing state", function()
      -- Pre-populate state
      MockStorage.data["_whisker_sync_state"] = {
        device_id = "test-device-123",
        last_sync_time = 1000,
        version_vector = {["device-1"] = 5},
        pending_operations = {},
        sync_status = "idle",
        last_error = nil,
        stats = {
          total_syncs = 10,
          last_sync_duration_ms = 500,
          conflicts_resolved = 2,
          bandwidth_sent_bytes = 1024,
          bandwidth_received_bytes = 2048
        }
      }
      
      local mgr = SyncStateManager.new(MockStorage)
      
      assert.equal("test-device-123", mgr:get_device_id())
      assert.equal(1000, mgr:get_last_sync_time())
      assert.equal(5, mgr:get_device_version("device-1"))
      
      local stats = mgr:get_stats()
      assert.equal(10, stats.total_syncs)
    end)
  end)
  
  describe("sync status", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should default to idle status", function()
      assert.equal("idle", mgr:get_sync_status())
    end)
    
    it("should update sync status", function()
      mgr:set_sync_status("syncing")
      assert.equal("syncing", mgr:get_sync_status())
      assert.is_true(mgr:is_syncing())
    end)
    
    it("should track syncing state", function()
      assert.is_false(mgr:is_syncing())
      
      mgr:set_sync_status("syncing")
      assert.is_true(mgr:is_syncing())
      
      mgr:set_sync_status("idle")
      assert.is_false(mgr:is_syncing())
    end)
    
    it("should track error state", function()
      assert.is_false(mgr:has_error())
      
      mgr:record_error("Test error")
      assert.is_true(mgr:has_error())
      assert.equal("error", mgr:get_sync_status())
    end)
  end)
  
  describe("last sync time", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should update last sync time", function()
      local timestamp = os.time()
      mgr:update_last_sync_time(timestamp)
      
      assert.equal(timestamp, mgr:get_last_sync_time())
    end)
    
    it("should calculate time since last sync", function()
      local past = os.time() - 100
      mgr:update_last_sync_time(past)
      
      local elapsed = mgr:get_time_since_last_sync()
      assert.is_true(elapsed >= 100 and elapsed <= 105)
    end)
    
    it("should return -1 for never synced", function()
      assert.equal(-1, mgr:get_time_since_last_sync())
    end)
  end)
  
  describe("version vectors", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should update version vector", function()
      mgr:update_version_vector("device-1", 5)
      mgr:update_version_vector("device-2", 3)
      
      assert.equal(5, mgr:get_device_version("device-1"))
      assert.equal(3, mgr:get_device_version("device-2"))
    end)
    
    it("should return 0 for unknown device", function()
      assert.equal(0, mgr:get_device_version("unknown"))
    end)
    
    it("should get full version vector", function()
      mgr:update_version_vector("device-1", 5)
      mgr:update_version_vector("device-2", 3)
      
      local vv = mgr:get_version_vector()
      assert.equal(5, vv["device-1"])
      assert.equal(3, vv["device-2"])
    end)
    
    it("should batch update version vectors", function()
      mgr:update_version_vector_batch({
        ["device-1"] = 10,
        ["device-2"] = 20,
        ["device-3"] = 30
      })
      
      assert.equal(10, mgr:get_device_version("device-1"))
      assert.equal(20, mgr:get_device_version("device-2"))
      assert.equal(30, mgr:get_device_version("device-3"))
    end)
  end)
  
  describe("pending operations", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should queue operation", function()
      local op = {
        type = "UPDATE",
        story_id = "story-1",
        timestamp = os.time(),
        data = {title = "Test"}
      }
      
      mgr:queue_operation(op)
      
      local pending = mgr:get_pending_operations()
      assert.equal(1, #pending)
      assert.equal("UPDATE", pending[1].type)
      assert.equal("story-1", pending[1].story_id)
    end)
    
    it("should queue multiple operations", function()
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      mgr:queue_operation({type = "UPDATE", story_id = "s2", timestamp = 2})
      mgr:queue_operation({type = "DELETE", story_id = "s3", timestamp = 3})
      
      local pending = mgr:get_pending_operations()
      assert.equal(3, #pending)
    end)
    
    it("should get pending count", function()
      assert.equal(0, mgr:get_pending_count())
      
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      assert.equal(1, mgr:get_pending_count())
      
      mgr:queue_operation({type = "UPDATE", story_id = "s2", timestamp = 2})
      assert.equal(2, mgr:get_pending_count())
    end)
    
    it("should remove pending operation by index", function()
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      mgr:queue_operation({type = "UPDATE", story_id = "s2", timestamp = 2})
      mgr:queue_operation({type = "DELETE", story_id = "s3", timestamp = 3})
      
      mgr:remove_pending_operation(2)
      
      local pending = mgr:get_pending_operations()
      assert.equal(2, #pending)
      assert.equal("CREATE", pending[1].type)
      assert.equal("DELETE", pending[2].type)
    end)
    
    it("should remove pending operation by match", function()
      local op1 = {type = "CREATE", story_id = "s1", timestamp = 1}
      local op2 = {type = "UPDATE", story_id = "s2", timestamp = 2}
      
      mgr:queue_operation(op1)
      mgr:queue_operation(op2)
      
      mgr:remove_pending_operation_by_match(op1)
      
      local pending = mgr:get_pending_operations()
      assert.equal(1, #pending)
      assert.equal("UPDATE", pending[1].type)
    end)
    
    it("should clear all pending operations", function()
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      mgr:queue_operation({type = "UPDATE", story_id = "s2", timestamp = 2})
      
      assert.equal(2, mgr:get_pending_count())
      
      mgr:clear_pending_operations()
      
      assert.equal(0, mgr:get_pending_count())
    end)
    
    it("should batch queue operations", function()
      local ops = {
        {type = "CREATE", story_id = "s1", timestamp = 1},
        {type = "UPDATE", story_id = "s2", timestamp = 2},
        {type = "DELETE", story_id = "s3", timestamp = 3}
      }
      
      mgr:queue_operations_batch(ops)
      
      assert.equal(3, mgr:get_pending_count())
    end)
  end)
  
  describe("statistics", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should start with zero stats", function()
      local stats = mgr:get_stats()
      
      assert.equal(0, stats.total_syncs)
      assert.equal(0, stats.last_sync_duration_ms)
      assert.equal(0, stats.conflicts_resolved)
      assert.equal(0, stats.bandwidth_sent_bytes)
      assert.equal(0, stats.bandwidth_received_bytes)
    end)
    
    it("should record sync completion", function()
      mgr:record_sync(500, 10, 2)
      
      local stats = mgr:get_stats()
      assert.equal(1, stats.total_syncs)
      assert.equal(500, stats.last_sync_duration_ms)
      assert.equal(2, stats.conflicts_resolved)
    end)
    
    it("should accumulate sync stats", function()
      mgr:record_sync(100, 5, 1)
      mgr:record_sync(200, 10, 2)
      mgr:record_sync(300, 15, 1)
      
      local stats = mgr:get_stats()
      assert.equal(3, stats.total_syncs)
      assert.equal(300, stats.last_sync_duration_ms)  -- Last duration
      assert.equal(4, stats.conflicts_resolved)  -- Accumulated
    end)
    
    it("should record bandwidth usage", function()
      mgr:record_bandwidth(1024, 2048)
      
      local stats = mgr:get_stats()
      assert.equal(1024, stats.bandwidth_sent_bytes)
      assert.equal(2048, stats.bandwidth_received_bytes)
    end)
    
    it("should accumulate bandwidth", function()
      mgr:record_bandwidth(1000, 2000)
      mgr:record_bandwidth(500, 1000)
      
      local stats = mgr:get_stats()
      assert.equal(1500, stats.bandwidth_sent_bytes)
      assert.equal(3000, stats.bandwidth_received_bytes)
    end)
    
    it("should reset stats", function()
      mgr:record_sync(500, 10, 2)
      mgr:record_bandwidth(1024, 2048)
      
      mgr:reset_stats()
      
      local stats = mgr:get_stats()
      assert.equal(0, stats.total_syncs)
      assert.equal(0, stats.bandwidth_sent_bytes)
    end)
  end)
  
  describe("error tracking", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should record error", function()
      mgr:record_error("Network timeout")
      
      local error = mgr:get_last_error()
      assert.is_not_nil(error)
      assert.equal("Network timeout", error.message)
      assert.is_number(error.timestamp)
    end)
    
    it("should set error status on error", function()
      mgr:record_error("Test error")
      
      assert.equal("error", mgr:get_sync_status())
      assert.is_true(mgr:has_error())
    end)
    
    it("should clear error", function()
      mgr:record_error("Test error")
      assert.is_not_nil(mgr:get_last_error())
      
      mgr:clear_error()
      
      assert.is_nil(mgr:get_last_error())
      assert.equal("idle", mgr:get_sync_status())
    end)
    
    it("should return nil when no error", function()
      assert.is_nil(mgr:get_last_error())
    end)
  end)
  
  describe("state management", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should load and save state", function()
      local state = mgr:load_state()
      
      assert.is_table(state)
      assert.is_not_nil(state.device_id)
      assert.is_table(state.version_vector)
      assert.is_table(state.pending_operations)
    end)
    
    it("should save modified state", function()
      local state = mgr:load_state()
      state.version_vector["device-1"] = 10
      
      mgr:save_state(state)
      
      assert.equal(10, mgr:get_device_version("device-1"))
    end)
    
    it("should get full state", function()
      mgr:update_version_vector("device-1", 5)
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      
      local full_state = mgr:get_full_state()
      
      assert.is_not_nil(full_state.device_id)
      assert.equal(5, full_state.version_vector["device-1"])
      assert.equal(1, #full_state.pending_operations)
    end)
    
    it("should reset state but preserve device ID", function()
      local device_id = mgr:get_device_id()
      
      mgr:update_version_vector("device-1", 5)
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      mgr:record_sync(100, 5, 1)
      
      mgr:reset()
      
      -- Device ID preserved
      assert.equal(device_id, mgr:get_device_id())
      
      -- Everything else reset
      assert.equal(0, mgr:get_device_version("device-1"))
      assert.equal(0, mgr:get_pending_count())
      local stats = mgr:get_stats()
      assert.equal(0, stats.total_syncs)
    end)
    
    it("should persist state across operations", function()
      mgr:update_version_vector("device-1", 5)
      
      -- Create new instance
      local mgr2 = SyncStateManager.new(MockStorage)
      
      assert.equal(5, mgr2:get_device_version("device-1"))
    end)
  end)
  
  describe("deep copy", function()
    local mgr
    
    before_each(function()
      mgr = SyncStateManager.new(MockStorage)
    end)
    
    it("should return independent copy of state", function()
      mgr:update_version_vector("device-1", 5)
      
      local state1 = mgr:load_state()
      state1.version_vector["device-1"] = 10
      
      local state2 = mgr:load_state()
      assert.equal(5, state2.version_vector["device-1"])
    end)
    
    it("should return independent copy of pending operations", function()
      mgr:queue_operation({type = "CREATE", story_id = "s1", timestamp = 1})
      
      local pending1 = mgr:get_pending_operations()
      pending1[1].type = "MODIFIED"
      
      local pending2 = mgr:get_pending_operations()
      assert.equal("CREATE", pending2[1].type)
    end)
  end)
end)
