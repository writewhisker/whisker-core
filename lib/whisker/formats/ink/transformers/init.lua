-- whisker/formats/ink/transformers/init.lua
-- Transformer registry for Ink to Whisker conversion
-- Provides lazy-loaded transformers for the conversion pipeline

local transformers = {}

-- Module metadata
transformers._whisker = {
  name = "InkTransformers",
  version = "1.0.0",
  description = "Transformer registry for Ink conversion",
  depends = {},
  capability = "formats.ink.transformers"
}

-- Lazy loader helper
local function lazy_require(name)
  local module
  return function()
    if not module then
      module = require("whisker.formats.ink.transformers." .. name)
      if module.new then
        module = module.new()
      end
    end
    return module
  end
end

-- Available transformers
transformers.knot = lazy_require("knot")
transformers.stitch = lazy_require("stitch")
transformers.gather = lazy_require("gather")
transformers.choice = lazy_require("choice")
transformers.variable = lazy_require("variable")
transformers.logic = lazy_require("logic")
transformers.tunnel = lazy_require("tunnel")
transformers.thread = lazy_require("thread")

-- Get all available transformer names
function transformers.list()
  return { "knot", "stitch", "gather", "choice", "variable", "logic", "tunnel", "thread" }
end

-- Create a transformer instance by name
-- @param name string - Transformer name
-- @return table|nil - Transformer instance or nil
function transformers.create(name)
  local loader = transformers[name]
  if loader and type(loader) == "function" then
    return loader()
  end
  return nil
end

return transformers
