--- Mock Factory
-- Factory functions for creating mock objects
-- @module tests.mocks.mock_factory
-- @author Whisker Core Team

local MockState = require("tests.mocks.mock_state")
local MockEngine = require("tests.mocks.mock_engine")
local MockPlugin = require("tests.mocks.mock_plugin")
local Spy = require("tests.mocks.spy")

local MockFactory = {}

--- Create a mock state service
-- @param initial_data table|nil Initial state data
-- @return MockState A mock state instance
function MockFactory.create_state(initial_data)
  return MockState.new(initial_data)
end

--- Create a mock engine
-- @return MockEngine A mock engine instance
function MockFactory.create_engine()
  return MockEngine.new()
end

--- Create a mock plugin
-- @param options table|nil Plugin options
-- @return MockPlugin A mock plugin instance
function MockFactory.create_plugin(options)
  return MockPlugin.new(options)
end

--- Create a mock event bus
-- @return table A mock event bus
function MockFactory.create_event_bus()
  local EventBus = require("whisker.kernel.events")
  return EventBus.new()
end

--- Create a mock logger
-- @return table A mock logger with tracking
function MockFactory.create_logger()
  return {
    logs = {},
    log = function(self, level, msg)
      table.insert(self.logs, {level = level, message = msg})
    end,
    info = function(self, msg) self:log("info", msg) end,
    warn = function(self, msg) self:log("warn", msg) end,
    error = function(self, msg) self:log("error", msg) end,
    debug = function(self, msg) self:log("debug", msg) end,
    clear = function(self) self.logs = {} end,
    get_logs = function(self, level)
      if not level then return self.logs end
      local filtered = {}
      for _, log in ipairs(self.logs) do
        if log.level == level then
          table.insert(filtered, log)
        end
      end
      return filtered
    end,
  }
end

--- Create a mock variables service
-- @param events table The event bus for emitting changes
-- @return table A mock variables service
function MockFactory.create_variables(events)
  return {
    _vars = {},
    _events = events,
    get = function(self, name) return self._vars[name] end,
    set = function(self, name, value)
      local old = self._vars[name]
      self._vars[name] = value
      if self._events then
        self._events:emit("variable:changed", {
          name = name,
          old_value = old,
          new_value = value,
        })
      end
    end,
    has = function(self, name) return self._vars[name] ~= nil end,
    delete = function(self, name) self._vars[name] = nil end,
    clear = function(self) self._vars = {} end,
    get_all = function(self)
      local result = {}
      for k, v in pairs(self._vars) do result[k] = v end
      return result
    end,
  }
end

--- Create a mock history service
-- @return table A mock history service
function MockFactory.create_history()
  return {
    _entries = {},
    push = function(self, entry)
      table.insert(self._entries, entry)
    end,
    pop = function(self)
      return table.remove(self._entries)
    end,
    peek = function(self)
      return self._entries[#self._entries]
    end,
    depth = function(self)
      return #self._entries
    end,
    can_go_back = function(self)
      return #self._entries > 1
    end,
    go_back = function(self)
      if #self._entries > 1 then
        table.remove(self._entries)
        return self._entries[#self._entries]
      end
      return nil
    end,
    get_all = function(self)
      local result = {}
      for i, entry in ipairs(self._entries) do
        result[i] = entry
      end
      return result
    end,
    clear = function(self)
      self._entries = {}
    end,
  }
end

--- Create a mock persistence service
-- @return table A mock persistence service
function MockFactory.create_persistence()
  return {
    _storage = {},
    _metadata = {},
    save = function(self, slot, metadata)
      self._storage[slot] = {saved = true}
      self._metadata[slot] = metadata
      return true
    end,
    load = function(self, slot)
      return self._storage[slot] ~= nil
    end,
    delete = function(self, slot)
      local existed = self._storage[slot] ~= nil
      self._storage[slot] = nil
      self._metadata[slot] = nil
      return existed
    end,
    list_saves = function(self)
      local result = {}
      for slot in pairs(self._storage) do
        table.insert(result, slot)
      end
      return result
    end,
    get_metadata = function(self, slot)
      return self._metadata[slot]
    end,
  }
end

--- Create a spy
-- @param fn function|nil Optional function to wrap
-- @return function The spy function
-- @return table The call tracker
function MockFactory.spy(fn)
  return Spy.create(fn)
end

--- Create a stub
-- @param value any The value to return
-- @return function The stub function
-- @return table The call tracker
function MockFactory.stub(value)
  return Spy.stub(value)
end

return MockFactory
