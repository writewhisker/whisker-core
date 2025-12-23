--- Export Configuration
-- Configuration system for export settings
-- @module whisker.export.configuration
-- @author Whisker Core Team
-- @license MIT

local ExportUtils = require("whisker.export.utils")

local Configuration = {}

--- Load configuration with cascade
-- @param project_root string Project root directory
-- @param cli_args table CLI arguments to overlay
-- @return table Merged configuration
function Configuration.load(project_root, cli_args)
  project_root = project_root or "."
  cli_args = cli_args or {}

  -- Level 1: Built-in defaults
  local config = Configuration.defaults()

  -- Level 2: Project configuration file
  local project_config_path = project_root .. "/whisker.export.lua"
  local project_config = Configuration.load_file(project_config_path)
  if project_config then
    Configuration.merge(config, project_config)
  end

  -- Level 3: Environment variables
  Configuration.merge_env(config)

  -- Level 4: CLI arguments (highest priority)
  Configuration.merge(config, cli_args)

  return config
end

--- Built-in default configuration
-- @return table Default configuration
function Configuration.defaults()
  return {
    -- HTML format defaults
    html = {
      template = "default",
      minify = false,
      inline_assets = true,
      target_browsers = ">0.5%, not dead",
    },

    -- Ink format defaults
    ink = {
      ink_version = 20,
      validate_schema = true,
      pretty = false,
    },

    -- Text format defaults
    text = {
      line_width = 70,
      include_metadata = true,
      include_choices = true,
    },

    -- General defaults
    general = {
      output_dir = "dist",
      verbose = false,
    },
  }
end

--- Load configuration from Lua file
-- @param path string Path to config file
-- @return table|nil Configuration or nil if not found
function Configuration.load_file(path)
  local content = ExportUtils.read_file(path)
  if not content then
    return nil
  end

  -- Execute Lua config file in sandbox
  local chunk, err = loadstring(content, path)
  if not chunk then
    error("Configuration syntax error in " .. path .. ": " .. tostring(err))
  end

  -- Create sandbox environment
  local env = {}
  setmetatable(env, { __index = _G })

  if setfenv then
    -- Lua 5.1
    setfenv(chunk, env)
  end

  local ok, result = pcall(chunk)
  if not ok then
    error("Configuration error in " .. path .. ": " .. tostring(result))
  end

  -- Return the table returned by the file, or check for 'export' key
  if type(result) == "table" then
    return result
  elseif env.export then
    return env.export
  else
    return env
  end
end

--- Merge environment variables into config
-- @param config table Configuration to update
function Configuration.merge_env(config)
  -- HTML options
  if os.getenv("WHISKER_MINIFY") == "true" then
    config.html.minify = true
  end

  if os.getenv("WHISKER_TEMPLATE") then
    config.html.template = os.getenv("WHISKER_TEMPLATE")
  end

  if os.getenv("WHISKER_INLINE") == "false" then
    config.html.inline_assets = false
  end

  -- Ink options
  if os.getenv("WHISKER_INK_PRETTY") == "true" then
    config.ink.pretty = true
  end

  -- General options
  if os.getenv("WHISKER_OUTPUT_DIR") then
    config.general.output_dir = os.getenv("WHISKER_OUTPUT_DIR")
  end

  if os.getenv("WHISKER_VERBOSE") == "true" then
    config.general.verbose = true
  end
end

--- Deep merge two configuration tables
-- @param base table Base configuration
-- @param overrides table Override values
function Configuration.merge(base, overrides)
  if not overrides then return end

  for k, v in pairs(overrides) do
    if type(v) == "table" and type(base[k]) == "table" then
      Configuration.merge(base[k], v)
    else
      base[k] = v
    end
  end
end

--- Get format-specific configuration
-- @param config table Full configuration
-- @param format string Format name (html, ink, text)
-- @return table Format-specific config
function Configuration.get_format_config(config, format)
  return config[format] or {}
end

--- Validate configuration
-- @param config table Configuration to validate
-- @return boolean Valid
-- @return table Array of error messages
function Configuration.validate(config)
  local errors = {}

  -- Validate HTML config
  if config.html then
    if config.html.template then
      local valid_templates = { "default", "minimal", "accessible" }
      local is_builtin = false
      for _, t in ipairs(valid_templates) do
        if config.html.template == t then
          is_builtin = true
          break
        end
      end
      -- If not builtin, it should be a file path (we don't validate existence here)
    end
  end

  -- Validate Ink config
  if config.ink then
    if config.ink.ink_version and type(config.ink.ink_version) ~= "number" then
      table.insert(errors, "ink.ink_version must be a number")
    end
  end

  -- Validate Text config
  if config.text then
    if config.text.line_width and type(config.text.line_width) ~= "number" then
      table.insert(errors, "text.line_width must be a number")
    end
    if config.text.line_width and config.text.line_width < 20 then
      table.insert(errors, "text.line_width must be at least 20")
    end
  end

  return #errors == 0, errors
end

--- Create a sample configuration file content
-- @return string Sample config file
function Configuration.sample_config()
  return [[-- whisker.export.lua
-- Export configuration for whisker-core project
-- Copy this file to your project root and customize

return {
  -- HTML export settings
  html = {
    template = "default",    -- "default", "minimal", "accessible", or path to custom template
    minify = false,          -- Minify HTML, CSS, and JavaScript
    inline_assets = true,    -- Embed assets in HTML (vs external files)
    -- asset_path = "./assets", -- Path to asset directory
  },

  -- Ink JSON export settings
  ink = {
    ink_version = 20,        -- Ink format version
    validate_schema = true,  -- Validate output against schema
    pretty = false,          -- Pretty-print JSON
  },

  -- Text transcript export settings
  text = {
    line_width = 70,         -- Maximum line width
    include_metadata = true, -- Include title, author, timestamps
    include_choices = true,  -- Include choice listings
  },

  -- General settings
  general = {
    output_dir = "dist",     -- Default output directory
    verbose = false,         -- Verbose output
  },
}
]]
end

return Configuration
