--- Core Plugin
-- Provides shared utilities for other built-in plugins
-- @module plugins.builtin.core
-- @author whisker-core
-- @license MIT

local core = {}

--- Deep copy a table
-- @param tbl table Table to copy
-- @param seen table|nil Internal tracking for circular refs
-- @return any Copy of input (or input if not table)
function core.deep_copy(tbl, seen)
  if type(tbl) ~= "table" then
    return tbl
  end

  seen = seen or {}
  if seen[tbl] then
    return seen[tbl]  -- Handle circular reference
  end

  local copy = {}
  seen[tbl] = copy

  for k, v in pairs(tbl) do
    if type(v) == "table" then
      copy[k] = core.deep_copy(v, seen)
    else
      copy[k] = v
    end
  end

  local mt = getmetatable(tbl)
  if mt then
    setmetatable(copy, mt)
  end

  return copy
end

--- Shallow merge tables (source into target)
-- @param target table Target table
-- @param source table Source table
-- @return table Modified target
function core.merge(target, source)
  if not source then
    return target
  end

  for k, v in pairs(source) do
    target[k] = v
  end

  return target
end

--- Deep merge tables (source into target)
-- @param target table Target table
-- @param source table Source table
-- @return table Modified target
function core.deep_merge(target, source)
  if not source then
    return target
  end

  for k, v in pairs(source) do
    if type(v) == "table" and type(target[k]) == "table" then
      core.deep_merge(target[k], v)
    else
      target[k] = v
    end
  end

  return target
end

--- Check if array contains value
-- @param tbl table Array to search
-- @param value any Value to find
-- @return boolean True if found
function core.contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

--- Find index of value in array
-- @param tbl table Array to search
-- @param value any Value to find
-- @return number|nil Index or nil if not found
function core.index_of(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      return i
    end
  end
  return nil
end

--- Map function over array
-- @param tbl table Input array
-- @param fn function Mapping function(value, index) -> new_value
-- @return table New array with mapped values
function core.map(tbl, fn)
  local result = {}
  for i, v in ipairs(tbl) do
    result[i] = fn(v, i)
  end
  return result
end

--- Filter array by predicate
-- @param tbl table Input array
-- @param predicate function Filter function(value) -> boolean
-- @return table New array with filtered values
function core.filter(tbl, predicate)
  local result = {}
  for _, v in ipairs(tbl) do
    if predicate(v) then
      table.insert(result, v)
    end
  end
  return result
end

--- Reduce array to single value
-- @param tbl table Input array
-- @param fn function Reducer function(accumulator, value) -> new_accumulator
-- @param initial any Initial accumulator value
-- @return any Final accumulated value
function core.reduce(tbl, fn, initial)
  local acc = initial
  for _, v in ipairs(tbl) do
    acc = fn(acc, v)
  end
  return acc
end

--- Get array of table keys
-- @param tbl table Input table
-- @return table Array of keys
function core.keys(tbl)
  local result = {}
  for k in pairs(tbl) do
    table.insert(result, k)
  end
  return result
end

--- Get array of table values
-- @param tbl table Input table
-- @return table Array of values
function core.values(tbl)
  local result = {}
  for _, v in pairs(tbl) do
    table.insert(result, v)
  end
  return result
end

--- Get length of table (including non-numeric keys)
-- @param tbl table Input table
-- @return number Number of key-value pairs
function core.size(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

--- Check if table is empty
-- @param tbl table Input table
-- @return boolean True if empty
function core.is_empty(tbl)
  return next(tbl) == nil
end

--- Clamp number between min and max
-- @param value number Value to clamp
-- @param min number Minimum value
-- @param max number Maximum value
-- @return number Clamped value
function core.clamp(value, min, max)
  if value < min then
    return min
  elseif value > max then
    return max
  end
  return value
end

--- Linear interpolation
-- @param a number Start value
-- @param b number End value
-- @param t number Interpolation factor (0-1)
-- @return number Interpolated value
function core.lerp(a, b, t)
  return a + (b - a) * t
end

--- Create a debounced version of a function
-- @param fn function Function to debounce
-- @param wait_time number Wait time in seconds
-- @return function Debounced function
function core.debounce(fn, wait_time)
  local last_call = 0

  return function(...)
    local now = os.time()
    if now - last_call >= wait_time then
      last_call = now
      return fn(...)
    end
  end
end

--- Create an event emitter
-- @return table Emitter with on(), off(), emit() methods
function core.create_emitter()
  local listeners = {}

  return {
    on = function(event, callback)
      if not listeners[event] then
        listeners[event] = {}
      end
      table.insert(listeners[event], callback)
      return callback  -- Return for removal
    end,

    off = function(event, callback)
      if not listeners[event] then
        return false
      end
      for i, cb in ipairs(listeners[event]) do
        if cb == callback then
          table.remove(listeners[event], i)
          return true
        end
      end
      return false
    end,

    emit = function(event, ...)
      if not listeners[event] then
        return
      end
      for _, callback in ipairs(listeners[event]) do
        callback(...)
      end
    end,

    clear = function(event)
      if event then
        listeners[event] = nil
      else
        listeners = {}
      end
    end,
  }
end

--- Format string with named placeholders
-- @param template string Template with {name} placeholders
-- @param values table Map of name -> value
-- @return string Formatted string
function core.format(template, values)
  return (template:gsub("{([^}]+)}", function(key)
    return tostring(values[key] or "")
  end))
end

-- Plugin definition
return {
  name = "core",
  version = "1.0.0",
  _trusted = true,

  author = "whisker-core",
  description = "Core utilities for built-in plugins",
  license = "MIT",

  -- No dependencies (core is the base)
  dependencies = {},

  -- Capabilities (documented even though trusted)
  capabilities = {},

  -- Public API
  api = core,

  -- Lifecycle hooks
  on_init = function(ctx)
    ctx.log.debug("Core plugin initialized")
  end,

  on_enable = function(ctx)
    ctx.log.debug("Core plugin enabled")
  end,

  on_disable = function(ctx)
    ctx.log.debug("Core plugin disabled")
  end,
}
