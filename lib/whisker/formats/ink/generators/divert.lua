-- whisker/formats/ink/generators/divert.lua
-- Generates Ink divert commands from whisker navigation

local DivertGenerator = {}
DivertGenerator.__index = DivertGenerator

-- Module metadata
DivertGenerator._whisker = {
  name = "DivertGenerator",
  version = "1.0.0",
  description = "Generates Ink divert commands from whisker navigation",
  depends = {},
  capability = "formats.ink.generators.divert"
}

-- Special targets
DivertGenerator.DONE = "done"
DivertGenerator.END = "end"

-- Create a new DivertGenerator instance
function DivertGenerator.new()
  local instance = {}
  setmetatable(instance, DivertGenerator)
  return instance
end

-- Generate an Ink divert command
-- @param target string - The target path
-- @param options table|nil - Generation options
-- @return table - Ink divert structure
function DivertGenerator:generate(target, options)
  options = options or {}

  if not target then
    return { ["->"] = self.DONE }
  end

  -- Handle special targets
  local normalized = self:_normalize_target(target)

  return { ["->"] = normalized }
end

-- Generate a tunnel divert (call with return)
-- @param target string - The tunnel target
-- @param options table|nil - Generation options
-- @return table - Ink tunnel divert structure
function DivertGenerator:generate_tunnel(target, options)
  options = options or {}

  return {
    ["->t->"] = self:_normalize_target(target)
  }
end

-- Generate a thread start
-- @param target string - The thread target
-- @param options table|nil - Generation options
-- @return table - Ink thread structure
function DivertGenerator:generate_thread(target, options)
  options = options or {}

  return {
    ["<-"] = self:_normalize_target(target)
  }
end

-- Generate a tunnel return
-- @return table - Ink tunnel return marker
function DivertGenerator:generate_tunnel_return()
  return { ["->->"] = true }
end

-- Normalize target path
-- @param target string - Raw target
-- @return string - Normalized target
function DivertGenerator:_normalize_target(target)
  if not target then
    return self.DONE
  end

  -- Handle special targets
  local lower = target:lower()
  if lower == "done" or lower == "end" then
    return lower
  end

  -- Remove any leading/trailing whitespace
  return target:match("^%s*(.-)%s*$")
end

-- Check if target is special (DONE or END)
-- @param target string - The target to check
-- @return boolean
function DivertGenerator:is_special_target(target)
  if not target then
    return false
  end
  local lower = target:lower()
  return lower == "done" or lower == "end"
end

-- Generate divert from passage link
-- @param link table|string - Link data
-- @return table - Ink divert structure
function DivertGenerator:from_link(link)
  local target
  if type(link) == "string" then
    target = link
  elseif type(link) == "table" then
    target = link.target or link.passage or link.path
  end

  return self:generate(target)
end

-- Generate conditional divert
-- @param target string - The target path
-- @param condition table - The condition
-- @return table - Conditional divert structure
function DivertGenerator:generate_conditional(target, condition)
  local result = {}

  -- Start evaluation
  table.insert(result, "ev")

  -- Add condition
  if type(condition) == "string" then
    table.insert(result, { ["VAR?"] = condition })
  end

  table.insert(result, "/ev")

  -- Add conditional divert
  table.insert(result, {
    ["->"] = self:_normalize_target(target),
    c = true -- conditional flag
  })

  return result
end

return DivertGenerator
