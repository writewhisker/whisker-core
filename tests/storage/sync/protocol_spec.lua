--- Tests for Storage Sync Protocol
-- @module tests.storage.sync.protocol_spec

describe("Storage Sync Protocol", function()
  local Protocol
  
  before_each(function()
    package.loaded["whisker.storage.sync.protocol"] = nil
    Protocol = require("whisker.storage.sync.protocol")
  end)
  
  describe("create_operation", function()
    it("should create a CREATE operation", function()
      local op = Protocol.create_operation(
        Protocol.OperationType.CREATE,
        "story-1",
        {title = "My Story"}
      )
      
      assert.is_not_nil(op.id)
      assert.equal(Protocol.OperationType.CREATE, op.type)
      assert.equal("story-1", op.story_id)
      assert.equal("My Story", op.data.title)
      assert.is_number(op.timestamp)
    end)
    
    it("should create an UPDATE operation", function()
      local op = Protocol.create_operation(
        Protocol.OperationType.UPDATE,
        "story-1",
        {title = "Updated Story"}
      )
      
      assert.equal(Protocol.OperationType.UPDATE, op.type)
    end)
    
    it("should include metadata", function()
      local op = Protocol.create_operation(
        Protocol.OperationType.UPDATE,
        "story-1",
        {title = "Story"},
        {device_id = "device-123"}
      )
      
      assert.equal("device-123", op.device_id)
    end)
  end)
  
  describe("detect_conflicts", function()
    it("should detect no conflicts when stories differ", function()
      local local_ops = {
        Protocol.create_operation("UPDATE", "story-1", {title = "Local"})
      }
      
      local remote_ops = {
        Protocol.create_operation("UPDATE", "story-2", {title = "Remote"})
      }
      
      local conflicts = Protocol.detect_conflicts(local_ops, remote_ops)
      assert.equal(0, #conflicts)
    end)
    
    it("should detect concurrent modification conflict", function()
      local timestamp = os.time()
      
      local local_ops = {
        {
          id = "op1",
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Local Version"},
          timestamp = timestamp,
          device_id = "device-1"
        }
      }
      
      local remote_ops = {
        {
          id = "op2",
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Remote Version"},
          timestamp = timestamp + 1, -- Within 5 seconds
          device_id = "device-2"
        }
      }
      
      local conflicts = Protocol.detect_conflicts(local_ops, remote_ops)
      assert.equal(1, #conflicts)
      assert.equal("story-1", conflicts[1].story_id)
      assert.equal("concurrent_update", conflicts[1].conflict_type)
    end)
  end)
  
  describe("resolve_conflict", function()
    local function create_conflict()
      local timestamp = os.time()
      
      return {
        story_id = "story-1",
        local_version = {
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Local", author = "Local Author"},
          timestamp = timestamp,
          device_id = "device-1"
        },
        remote_version = {
          type = Protocol.OperationType.UPDATE,
          story_id = "story-1",
          data = {title = "Remote", description = "Remote Desc"},
          timestamp = timestamp + 2,
          device_id = "device-2"
        },
        conflict_type = "concurrent_update"
      }
    end
    
    it("should resolve with last-write-wins strategy", function()
      local conflict = create_conflict()
      
      local result = Protocol.resolve_conflict(
        conflict,
        Protocol.ConflictStrategy.LAST_WRITE_WINS
      )
      
      assert.equal("remote", result.winner)
      assert.equal("Remote", result.data.title)
    end)
    
    it("should resolve with auto-merge strategy", function()
      local conflict = create_conflict()
      
      local result = Protocol.resolve_conflict(
        conflict,
        Protocol.ConflictStrategy.AUTO_MERGE
      )
      
      assert.equal("merged", result.winner)
      -- Should have both local and remote fields
      assert.equal("Local Author", result.data.author) -- From local
      assert.equal("Remote Desc", result.data.description) -- From remote
    end)
    
    it("should resolve with keep-both strategy", function()
      local conflict = create_conflict()
      
      local result = Protocol.resolve_conflict(
        conflict,
        Protocol.ConflictStrategy.KEEP_BOTH
      )
      
      assert.equal("both", result.winner)
      assert.is_not_nil(result.local_copy)
      assert.is_not_nil(result.remote_copy)
      assert.is_not_equal(result.local_copy.story_id, result.remote_copy.story_id)
    end)
    
    it("should resolve with manual strategy", function()
      local conflict = create_conflict()
      
      local custom_resolver = function(c)
        return {
          winner = "custom",
          data = {title = "Custom Resolution"}
        }
      end
      
      local result = Protocol.resolve_conflict(
        conflict,
        Protocol.ConflictStrategy.MANUAL,
        custom_resolver
      )
      
      assert.equal("custom", result.winner)
      assert.equal("Custom Resolution", result.data.title)
    end)
  end)
  
  describe("generate_delta", function()
    it("should detect created stories", function()
      local old_state = {
        ["story-1"] = {title = "Story 1"}
      }
      
      local new_state = {
        ["story-1"] = {title = "Story 1"},
        ["story-2"] = {title = "Story 2"} -- New
      }
      
      local delta = Protocol.generate_delta(old_state, new_state)
      
      assert.equal(1, #delta)
      assert.equal(Protocol.OperationType.CREATE, delta[1].type)
      assert.equal("story-2", delta[1].story_id)
    end)
    
    it("should detect updated stories", function()
      local old_state = {
        ["story-1"] = {title = "Old Title"}
      }
      
      local new_state = {
        ["story-1"] = {title = "New Title"}
      }
      
      local delta = Protocol.generate_delta(old_state, new_state)
      
      assert.equal(1, #delta)
      assert.equal(Protocol.OperationType.UPDATE, delta[1].type)
      assert.equal("story-1", delta[1].story_id)
      assert.equal("New Title", delta[1].data.title)
    end)
    
    it("should detect deleted stories", function()
      local old_state = {
        ["story-1"] = {title = "Story 1"},
        ["story-2"] = {title = "Story 2"}
      }
      
      local new_state = {
        ["story-1"] = {title = "Story 1"}
        -- story-2 deleted
      }
      
      local delta = Protocol.generate_delta(old_state, new_state)
      
      assert.equal(1, #delta)
      assert.equal(Protocol.OperationType.DELETE, delta[1].type)
      assert.equal("story-2", delta[1].story_id)
    end)
    
    it("should handle multiple changes", function()
      local old_state = {
        ["story-1"] = {title = "Story 1"},
        ["story-2"] = {title = "Old Title"}
      }
      
      local new_state = {
        ["story-2"] = {title = "New Title"}, -- Updated
        ["story-3"] = {title = "Story 3"} -- Created
        -- story-1 deleted
      }
      
      local delta = Protocol.generate_delta(old_state, new_state)
      
      assert.equal(3, #delta)
      
      -- Find operation types
      local types = {}
      for _, op in ipairs(delta) do
        types[op.type] = (types[op.type] or 0) + 1
      end
      
      assert.equal(1, types[Protocol.OperationType.CREATE])
      assert.equal(1, types[Protocol.OperationType.UPDATE])
      assert.equal(1, types[Protocol.OperationType.DELETE])
    end)
  end)
  
  describe("apply_delta", function()
    it("should apply CREATE operations", function()
      local current_state = {}
      
      local delta = {
        Protocol.create_operation(
          Protocol.OperationType.CREATE,
          "story-1",
          {title = "New Story"}
        )
      }
      
      local new_state = Protocol.apply_delta(current_state, delta)
      
      assert.is_not_nil(new_state["story-1"])
      assert.equal("New Story", new_state["story-1"].title)
    end)
    
    it("should apply UPDATE operations", function()
      local current_state = {
        ["story-1"] = {title = "Old Title"}
      }
      
      local delta = {
        Protocol.create_operation(
          Protocol.OperationType.UPDATE,
          "story-1",
          {title = "Updated Title"}
        )
      }
      
      local new_state = Protocol.apply_delta(current_state, delta)
      
      assert.equal("Updated Title", new_state["story-1"].title)
    end)
    
    it("should apply DELETE operations", function()
      local current_state = {
        ["story-1"] = {title = "Story 1"},
        ["story-2"] = {title = "Story 2"}
      }
      
      local delta = {
        Protocol.create_operation(
          Protocol.OperationType.DELETE,
          "story-1",
          nil
        )
      }
      
      local new_state = Protocol.apply_delta(current_state, delta)
      
      assert.is_nil(new_state["story-1"])
      assert.is_not_nil(new_state["story-2"])
    end)
  end)
  
  describe("version_vector", function()
    it("should create empty version vector", function()
      local vector = Protocol.create_version_vector()
      assert.is_table(vector)
    end)
    
    it("should update version vector", function()
      local vector = Protocol.create_version_vector()
      
      Protocol.update_version_vector(vector, "device-1", 5)
      Protocol.update_version_vector(vector, "device-2", 3)
      
      assert.equal(5, vector["device-1"])
      assert.equal(3, vector["device-2"])
    end)
    
    it("should compare version vectors for causality", function()
      local v1 = {["device-1"] = 5, ["device-2"] = 3}
      local v2 = {["device-1"] = 5, ["device-2"] = 3}
      
      assert.equal("equal", Protocol.compare_version_vectors(v1, v2))
    end)
    
    it("should detect v1 before v2", function()
      local v1 = {["device-1"] = 3, ["device-2"] = 2}
      local v2 = {["device-1"] = 5, ["device-2"] = 4}
      
      assert.equal("before", Protocol.compare_version_vectors(v1, v2))
    end)
    
    it("should detect v1 after v2", function()
      local v1 = {["device-1"] = 5, ["device-2"] = 4}
      local v2 = {["device-1"] = 3, ["device-2"] = 2}
      
      assert.equal("after", Protocol.compare_version_vectors(v1, v2))
    end)
    
    it("should detect concurrent modifications", function()
      local v1 = {["device-1"] = 5, ["device-2"] = 2}
      local v2 = {["device-1"] = 3, ["device-2"] = 4}
      
      assert.equal("concurrent", Protocol.compare_version_vectors(v1, v2))
    end)
  end)
end)
