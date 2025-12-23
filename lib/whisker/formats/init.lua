--- FormatLoader
-- Registers all format handlers with the DI container
-- @module whisker.formats
-- @author Whisker Core Team
-- @license MIT

local FormatLoader = {}

--- Register all format handlers with the container
-- @param container Container The DI container
function FormatLoader.register_all(container)
  local JsonFormat = require("whisker.formats.json")
  local TwineFormat = require("whisker.formats.twine")

  -- Register JSON format handler
  container:register("format.json", JsonFormat, {
    singleton = true,
    implements = "IFormat",
  })

  -- Register Twine format handler
  container:register("format.twine", TwineFormat, {
    singleton = true,
    implements = "IFormat",
  })

  -- Try to register Ink format if available
  local ok, InkFormat = pcall(require, "whisker.formats.ink")
  if ok then
    container:register("format.ink", InkFormat, {
      singleton = true,
      implements = "IFormat",
    })
  end
end

--- Register only JSON format
-- @param container Container The DI container
function FormatLoader.register_json(container)
  local JsonFormat = require("whisker.formats.json")
  container:register("format.json", JsonFormat, {
    singleton = true,
    implements = "IFormat",
  })
end

--- Register only Twine format
-- @param container Container The DI container
function FormatLoader.register_twine(container)
  local TwineFormat = require("whisker.formats.twine")
  container:register("format.twine", TwineFormat, {
    singleton = true,
    implements = "IFormat",
  })
end

--- Register only Ink format
-- @param container Container The DI container
function FormatLoader.register_ink(container)
  local InkFormat = require("whisker.formats.ink")
  container:register("format.ink", InkFormat, {
    singleton = true,
    implements = "IFormat",
  })
end

--- Detect format from source content
-- @param source string The source content
-- @param container Container The DI container
-- @return string|nil format_name The detected format name, or nil
function FormatLoader.detect_format(source, container)
  if type(source) ~= "string" or source == "" then
    return nil
  end

  -- Try each registered format
  local format_names = { "format.json", "format.twine", "format.ink" }

  for _, name in ipairs(format_names) do
    if container:has(name) then
      local format = container:resolve(name)
      if format and format.can_import and format:can_import(source) then
        return format:get_name()
      end
    end
  end

  return nil
end

--- Get a format handler by extension
-- @param extension string The file extension (e.g., ".json")
-- @param container Container The DI container
-- @return table|nil format The format handler, or nil
function FormatLoader.get_by_extension(extension, container)
  local ext = extension:lower()
  if not ext:match("^%.") then
    ext = "." .. ext
  end

  local format_names = { "format.json", "format.twine", "format.ink" }

  for _, name in ipairs(format_names) do
    if container:has(name) then
      local format = container:resolve(name)
      if format and format.get_extensions then
        local extensions = format:get_extensions()
        for _, fmt_ext in ipairs(extensions) do
          if fmt_ext:lower() == ext then
            return format
          end
        end
      end
    end
  end

  return nil
end

--- List all registered format names
-- @param container Container The DI container
-- @return table Array of format names
function FormatLoader.list_formats(container)
  local result = {}
  local format_names = { "format.json", "format.twine", "format.ink" }

  for _, name in ipairs(format_names) do
    if container:has(name) then
      local format = container:resolve(name)
      if format and format.get_name then
        table.insert(result, format:get_name())
      end
    end
  end

  return result
end

return FormatLoader
