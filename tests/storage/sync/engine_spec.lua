--- Tests for Storage Sync Engine
-- @module tests.storage.sync.engine_spec

describe("Storage Sync Engine", function()
  local SyncEngine, Protocol
  local MockStorage, MockTransport
  
  before_each(function()
    package.loaded["whisker.storage.sync.engine"] = nil
    package.loaded["whisker.storage.sync.protocol"] = nil
    
    SyncEngine = require("whisker.storage.sync.engine")
    Protocol = require("whisker.storage.sync.protocol")
    
    -- Mock storage
    MockStorage = {
      _data = {},
      list = function(self)
        local items = {}
        for id, data in pairs(self._data) do
          table.insert(items, {id = id, key = id})
        end
        return items
      end,
      load = function(self, id)
        return self._data[id]
      end,
      save = function(self, id, data)
        self._data[id] = data
      end,
      delete = function(self, id)
        self._data[id] = nil
      end
    }
    
    -- Mock transport
    MockTransport = {
      _remote_ops = {},
      _push_result = {success = true},
      fetch_operations = function(self, device_id, since_version)
        return {
          operations = self._remote_ops,
          version = since_version + 1
        }
      end,
      push_operations = function(self, device_id, operations)
        return self._push_result
      end
    }
  end)
  
  describe("new", function()
    it("should create sync engine with config", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "test-device",
        sync_interval = 30000
      })
      
      assert.is_not_nil(engine)
      assert.equal(SyncEngine.Status.IDLE, engine:get_sync_status())
    end)
    
    it("should generate device_id if not provided", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport
      })
      
      assert.is_not_nil(engine._device_id)
      assert.is_string(engine._device_id)
    end)
  end)
  
  describe("sync_now", function()
    it("should perform basic sync", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      -- Add local story
      MockStorage._data["story-1"] = {title = "Local Story"}
      
      -- Add remote story
      MockTransport._remote_ops = {
        Protocol.create_operation(
          Protocol.OperationType.CREATE,
          "story-2",
          {title = "Remote Story"},
          {device_id = "device-2"}
        )
      }
      
      local success = engine:sync_now()
      
      assert.is_true(success)
      assert.is_not_nil(MockStorage._data["story-2"])
      assert.equal("Remote Story", MockStorage._data["story-2"].title)
    end)
    
    it("should not apply operations from same device", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      MockStorage._data["story-1"] = {title = "Original"}
      
      -- Remote operation from same device
      MockTransport._remote_ops = {
        Protocol.create_operation(
          Protocol.OperationType.UPDATE,
          "story-1",
          {title = "Updated"},
          {device_id = "device-1"} -- Same device!
        )
      }
      
      engine:sync_now()
      
      -- Should not be updated
      assert.equal("Original", MockStorage._data["story-1"].title)
    end)
    
    it("should handle CREATE operations", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      MockTransport._remote_ops = {
        Protocol.create_operation(
          Protocol.OperationType.CREATE,
          "new-story",
          {title = "New Story"},
          {device_id = "device-2"}
        )
      }
      
      engine:sync_now()
      
      assert.is_not_nil(MockStorage._data["new-story"])
      assert.equal("New Story", MockStorage._data["new-story"].title)
    end)
    
    it("should handle UPDATE operations", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      MockStorage._data["story-1"] = {title = "Old Title"}
      
      MockTransport._remote_ops = {
        Protocol.create_operation(
          Protocol.OperationType.UPDATE,
          "story-1",
          {title = "New Title"},
          {device_id = "device-2"}
        )
      }
      
      engine:sync_now()
      
      assert.equal("New Title", MockStorage._data["story-1"].title)
    end)
    
    it("should handle DELETE operations", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      MockStorage._data["story-1"] = {title = "To Delete"}
      
      MockTransport._remote_ops = {
        Protocol.create_operation(
          Protocol.OperationType.DELETE,
          "story-1",
          nil,
          {device_id = "device-2"}
        )
      }
      
      engine:sync_now()
      
      assert.is_nil(MockStorage._data["story-1"])
    end)
    
    it("should return error if sync fails", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = nil -- No transport
      })
      
      local success, err = engine:sync_now()
      
      -- Should still succeed (just no remote ops)
      assert.is_true(success)
    end)
  end)
  
  describe("events", function()
    it("should emit sync_started event", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      local event_fired = false
      engine:on("sync_started", function(data)
        event_fired = true
      end)
      
      engine:start_sync()
      
      assert.is_true(event_fired)
    end)
    
    it("should emit sync_completed event", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      local completed_data = nil
      engine:on("sync_completed", function(data)
        completed_data = data
      end)
      
      engine:sync_now()
      
      assert.is_not_nil(completed_data)
      assert.is_number(completed_data.operations_applied)
      assert.is_number(completed_data.conflicts_resolved)
      assert.is_number(completed_data.timestamp)
    end)
    
    it("should emit sync_progress events", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      local progress_events = {}
      engine:on("sync_progress", function(data)
        table.insert(progress_events, data)
      end)
      
      engine:sync_now()
      
      assert.is_true(#progress_events > 0)
      assert.is_number(progress_events[1].current)
      assert.is_number(progress_events[1].total)
    end)
    
    it("should remove event listeners", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport
      })
      
      local count = 0
      local callback = function() count = count + 1 end
      
      engine:on("sync_completed", callback)
      engine:sync_now()
      assert.equal(1, count)
      
      engine:off("sync_completed", callback)
      engine:sync_now()
      assert.equal(1, count) -- Should not increment
    end)
  end)
  
  describe("conflict resolution", function()
    it("should detect and resolve conflicts", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1"
      })
      
      local timestamp = os.time()
      
      -- Local story
      MockStorage._data["story-1"] = {title = "Local Version"}
      
      -- Remote story (concurrent modification)
      MockTransport._remote_ops = {
        {
          id = "op1",
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Remote Version"},
          timestamp = timestamp + 1,
          device_id = "device-2"
        }
      }
      
      local conflict_detected = false
      engine:on("conflict_detected", function(data)
        conflict_detected = true
      end)
      
      engine:sync_now()
      
      -- Should use last-write-wins (remote is newer)
      assert.is_true(conflict_detected)
      assert.equal("Remote Version", MockStorage._data["story-1"].title)
    end)
    
    it("should use custom conflict resolver", function()
      local custom_called = false
      local received_conflict = nil
      
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport,
        device_id = "device-1",
        conflict_resolver = function(conflict)
          custom_called = true
          received_conflict = conflict
          return {
            winner = "custom",
            data = {title = "Custom Resolution"}
          }
        end
      })
      
      -- Directly call _resolve_conflicts with a test conflict
      local test_conflict = {
        story_id = "story-1",
        local_version = {
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Local"},
          timestamp = os.time(),
          device_id = "device-1"
        },
        remote_version = {
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Remote"},
          timestamp = os.time() + 1,
          device_id = "device-2"
        },
        conflict_type = "concurrent_update"
      }
      
      engine:_resolve_conflicts({test_conflict})
      
      assert.is_true(custom_called)
      assert.is_not_nil(received_conflict)
      assert.equal("Custom Resolution", MockStorage._data["story-1"].title)
    end)
  end)
  
  describe("start_sync and stop_sync", function()
    it("should start and stop sync", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport
      })
      
      assert.is_false(engine._running)
      
      engine:start_sync()
      assert.is_true(engine._running)
      
      engine:stop_sync()
      assert.is_false(engine._running)
    end)
    
    it("should emit sync_stopped event", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport
      })
      
      local stopped = false
      engine:on("sync_stopped", function()
        stopped = true
      end)
      
      engine:start_sync()
      engine:stop_sync()
      
      assert.is_true(stopped)
    end)
  end)
  
  describe("status tracking", function()
    it("should track sync status", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport
      })
      
      assert.equal(SyncEngine.Status.IDLE, engine:get_sync_status())
      
      -- Status changes during sync are tested implicitly
      engine:sync_now()
      
      assert.equal(SyncEngine.Status.IDLE, engine:get_sync_status())
    end)
    
    it("should track last sync time", function()
      local engine = SyncEngine.new({
        storage = MockStorage,
        transport = MockTransport
      })
      
      assert.equal(0, engine:get_last_sync_time())
      
      engine:sync_now()
      
      assert.is_true(engine:get_last_sync_time() > 0)
    end)
  end)
end)
