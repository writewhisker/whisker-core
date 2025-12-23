--- State Operations Benchmarks
-- Benchmarks for game state management
-- @module whisker.benchmarks.state_operations
-- @author Whisker Core Team
-- @license MIT

local BenchmarkSuite = require("whisker.benchmarks.suite")

local suite = BenchmarkSuite.new("State Operations")

-- Test data
local small_state, large_state

local function setup_states()
  -- Small state (10 variables)
  small_state = {
    variables = {},
    history = {},
  }
  for i = 1, 10 do
    small_state.variables["var_" .. i] = i * 10
  end

  -- Large state (1000 variables)
  large_state = {
    variables = {},
    history = {},
    inventory = {},
    flags = {},
  }
  for i = 1, 1000 do
    large_state.variables["var_" .. i] = i * 10
  end
  for i = 1, 100 do
    large_state.inventory["item_" .. i] = { count = i, quality = i % 10 }
  end
  for i = 1, 500 do
    large_state.flags["flag_" .. i] = (i % 2 == 0)
  end
  for i = 1, 50 do
    table.insert(large_state.history, "passage_" .. i)
  end
end

setup_states()

-- Benchmark: Get variable (small state)
suite:register("get_variable_small", function()
  return small_state.variables["var_5"]
end, {
  iterations = 50000,
  description = "Get variable from 10-variable state",
})

-- Benchmark: Set variable (small state)
suite:register("set_variable_small", function()
  small_state.variables["var_5"] = small_state.variables["var_5"] + 1
end, {
  iterations = 50000,
  description = "Set variable in 10-variable state",
})

-- Benchmark: Get variable (large state)
suite:register("get_variable_large", function()
  return large_state.variables["var_500"]
end, {
  iterations = 50000,
  description = "Get variable from 1000-variable state",
})

-- Benchmark: Set variable (large state)
suite:register("set_variable_large", function()
  large_state.variables["var_500"] = large_state.variables["var_500"] + 1
end, {
  iterations = 50000,
  description = "Set variable in 1000-variable state",
})

-- Benchmark: Check flag
suite:register("check_flag", function()
  return large_state.flags["flag_250"]
end, {
  iterations = 50000,
  description = "Check boolean flag",
})

-- Benchmark: Toggle flag
suite:register("toggle_flag", function()
  large_state.flags["flag_250"] = not large_state.flags["flag_250"]
end, {
  iterations = 50000,
  description = "Toggle boolean flag",
})

-- Benchmark: Add to history
local temp_history = {}
suite:register("add_history", function()
  table.insert(temp_history, "passage_new")
  if #temp_history > 100 then
    temp_history = {}
  end
end, {
  iterations = 10000,
  description = "Add passage to history",
})

-- Benchmark: Check history
suite:register("check_history", function()
  for _, entry in ipairs(large_state.history) do
    if entry == "passage_25" then
      return true
    end
  end
  return false
end, {
  iterations = 10000,
  description = "Check if passage in history (50 entries)",
})

-- Benchmark: Inventory lookup
suite:register("inventory_lookup", function()
  return large_state.inventory["item_50"]
end, {
  iterations = 50000,
  description = "Look up inventory item",
})

-- Benchmark: Inventory add
local temp_inventory = {}
suite:register("inventory_add", function()
  local item = "new_item_" .. (#temp_inventory + 1)
  temp_inventory[item] = { count = 1, quality = 5 }
  if #temp_inventory > 100 then
    temp_inventory = {}
  end
end, {
  iterations = 10000,
  description = "Add item to inventory",
})

-- Benchmark: State deep copy (small)
suite:register("state_copy_small", function()
  local copy = {}
  copy.variables = {}
  for k, v in pairs(small_state.variables) do
    copy.variables[k] = v
  end
  return copy
end, {
  iterations = 5000,
  description = "Deep copy small state",
})

-- Benchmark: State deep copy (large)
local function deep_copy(t)
  local copy = {}
  for k, v in pairs(t) do
    if type(v) == "table" then
      copy[k] = deep_copy(v)
    else
      copy[k] = v
    end
  end
  return copy
end

suite:register("state_copy_large", function()
  return deep_copy(large_state)
end, {
  iterations = 100,
  description = "Deep copy large state (1000+ variables)",
})

-- Benchmark: State serialization
suite:register("state_serialize", function()
  local parts = {}
  for k, v in pairs(small_state.variables) do
    table.insert(parts, k .. "=" .. tostring(v))
  end
  return table.concat(parts, ",")
end, {
  iterations = 5000,
  description = "Serialize small state to string",
})

-- Benchmark: Conditional evaluation
suite:register("condition_simple", function()
  local x = large_state.variables["var_100"]
  return x > 50
end, {
  iterations = 50000,
  description = "Simple numeric comparison",
})

suite:register("condition_complex", function()
  local x = large_state.variables["var_100"]
  local y = large_state.variables["var_200"]
  local flag = large_state.flags["flag_100"]
  return x > 50 and y < 3000 and flag
end, {
  iterations = 50000,
  description = "Complex conditional with multiple operands",
})

return suite
