-- whisker/formats/ink/init.lua
-- Ink format module entry point

local ink = {}

-- Lazy-load submodules
local function lazy_require(name)
  local module
  return function()
    if not module then
      module = require("whisker.formats.ink." .. name)
    end
    return module
  end
end

-- Module loaders
ink.JsonLoader = lazy_require("json_loader")
ink.Format = lazy_require("format")
ink.Story = lazy_require("story")

-- Get the format handler instance
function ink.get_format()
  return ink.Format().new()
end

-- Module metadata
ink._whisker = {
  name = "InkFormat",
  version = "1.0.0",
  description = "Ink narrative format support for whisker-core",
  depends = {},
  capability = "formats.ink"
}

return ink
