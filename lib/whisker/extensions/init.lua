--- Extensions Module
-- Loads and registers non-kernel extensions
-- @module whisker.extensions
-- @author Whisker Core Team
-- @license MIT

local Extensions = {}

--- Load all extensions in order
-- @param container Container The DI container
-- @param events EventBus The event bus instance
function Extensions.load_all(container, events)
  -- Load extensions in dependency order
  local extension_modules = {
    "whisker.extensions.service_extension",  -- Logger and base services first
    "whisker.extensions.core_extension",     -- Core factories (story, passage, choice)
    "whisker.extensions.media_extension",    -- Media factories (audio, image, assets)
  }

  for _, ext_path in ipairs(extension_modules) do
    local ok, ext = pcall(require, ext_path)
    if ok and ext and ext.register then
      ext.register(container, events)
    end
  end

  -- Emit extensions loaded event
  if events then
    events:emit("extensions:loaded", {
      container = container,
      count = #extension_modules,
    })
  end
end

return Extensions
