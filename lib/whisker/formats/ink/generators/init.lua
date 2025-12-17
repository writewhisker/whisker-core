-- whisker/formats/ink/generators/init.lua
-- Generator registry for Whisker to Ink export
-- Provides lazy-loaded generators for the export pipeline

local generators = {}

-- Module metadata
generators._whisker = {
  name = "InkGenerators",
  version = "1.0.0",
  description = "Generator registry for Ink export",
  depends = {},
  capability = "formats.ink.generators"
}

-- Lazy loader helper
local function lazy_require(name)
  local module
  return function()
    if not module then
      module = require("whisker.formats.ink.generators." .. name)
      if module.new then
        module = module.new()
      end
    end
    return module
  end
end

-- Available generators
generators.passage = lazy_require("passage")
generators.choice = lazy_require("choice")
generators.divert = lazy_require("divert")
generators.variable = lazy_require("variable")
generators.logic = lazy_require("logic")

-- Get all available generator names
function generators.list()
  return { "passage", "choice", "divert", "variable", "logic" }
end

-- Create a generator instance by name
-- @param name string - Generator name
-- @return table|nil - Generator instance or nil
function generators.create(name)
  local loader = generators[name]
  if loader and type(loader) == "function" then
    return loader()
  end
  return nil
end

return generators
