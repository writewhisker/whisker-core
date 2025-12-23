--- Test Container
-- Creates isolated test environments with mock dependencies
-- @module tests.helpers.test_container
-- @author Whisker Core Team

local Container = require("whisker.kernel.container")
local EventBus = require("whisker.kernel.events")

local TestContainer = {}

--- Create a new test container with mock dependencies
-- @param options table|nil Configuration options
-- @return Container A configured test container
function TestContainer.create(options)
  options = options or {}

  local container = Container.new()

  -- Create and register mock event bus
  local events = EventBus.new()
  container:register("events", events, {singleton = true})

  -- Create and register mock logger
  local logger = {
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
  container:register("logger", logger, {singleton = true})

  -- Register custom services if provided
  if options.services then
    for name, service in pairs(options.services) do
      container:register(name, service, {singleton = true, override = true})
    end
  end

  return container
end

--- Create a test container with all default services
-- @return Container A fully configured test container
function TestContainer.create_full()
  local container = TestContainer.create()

  -- Add mock state service
  local state = {
    _data = {},
    get = function(self, key) return self._data[key] end,
    set = function(self, key, value) self._data[key] = value end,
    has = function(self, key) return self._data[key] ~= nil end,
    delete = function(self, key) self._data[key] = nil end,
    clear = function(self) self._data = {} end,
    snapshot = function(self)
      local snap = {}
      for k, v in pairs(self._data) do snap[k] = v end
      return snap
    end,
    restore = function(self, snap)
      self._data = {}
      for k, v in pairs(snap) do self._data[k] = v end
    end,
    keys = function(self)
      local result = {}
      for k in pairs(self._data) do table.insert(result, k) end
      return result
    end,
  }
  container:register("state", state, {singleton = true})

  -- Add mock variables service
  local variables = {
    _vars = {},
    _events = container:resolve("events"),
    get = function(self, name) return self._vars[name] end,
    set = function(self, name, value)
      local old = self._vars[name]
      self._vars[name] = value
      self._events:emit("variable:changed", {
        name = name,
        old_value = old,
        new_value = value,
      })
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
  container:register("variables", variables, {singleton = true})

  -- Add mock history service
  local history = {
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
  container:register("history", history, {singleton = true})

  return container
end

return TestContainer
