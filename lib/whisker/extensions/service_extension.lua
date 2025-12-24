--- Service Extension
-- Registers base services with the container
-- @module whisker.extensions.service_extension
-- @author Whisker Core Team
-- @license MIT

local ServiceExtension = {}

--- Register base services with the container
-- @param container Container The DI container
-- @param events EventBus The event bus instance
-- @param options table|nil Service options
function ServiceExtension.register(container, events, options)
  options = options or {}

  -- Register logger (base service - no dependencies)
  if not container:has("logger") then
    container:register("logger", function()
      return {
        level = options.log_level or "info",
        log = function(self, level, msg)
          if options.debug then
            print(string.format("[%s] %s", level:upper(), msg))
          end
        end,
        info = function(self, msg) self:log("info", msg) end,
        warn = function(self, msg) self:log("warn", msg) end,
        error = function(self, msg) self:log("error", msg) end,
        debug = function(self, msg) self:log("debug", msg) end,
      }
    end, {
      singleton = true,
      implements = "ILogger"
    })
  end
end

return ServiceExtension
