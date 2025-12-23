--- Format template and engine code provider
-- Provides format-specific templates and engine embedding
--
-- lib/whisker/twine/export/format_template_provider.lua

local FormatTemplateProvider = {}

--------------------------------------------------------------------------------
-- Engine Code
--------------------------------------------------------------------------------

--- Get format engine code (placeholder for now)
---@param format string Format name
---@return string JavaScript engine code
function FormatTemplateProvider.get_engine_code(format)
  -- Placeholder: minimal engine for testing
  -- Full engines would be 50-200kb JavaScript files

  local engines = {
    harlowe = FormatTemplateProvider._harlowe_placeholder,
    sugarcube = FormatTemplateProvider._sugarcube_placeholder,
    chapbook = FormatTemplateProvider._chapbook_placeholder,
    snowman = FormatTemplateProvider._snowman_placeholder
  }

  local engine_fn = engines[format:lower()]
  if engine_fn then
    return engine_fn()
  end

  return ""
end

--------------------------------------------------------------------------------
-- Format-Specific Templates
--------------------------------------------------------------------------------

--- Get format-specific HTML wrapper
---@param format string Format name
---@return table Template with head and body parts
function FormatTemplateProvider.get_html_template(format)
  local templates = {
    harlowe = {
      head = "",
      body_attrs = "",
      body_prefix = "",
      body_suffix = ""
    },
    sugarcube = {
      head = "",
      body_attrs = "",
      body_prefix = '<div id="passages"></div>',
      body_suffix = ""
    },
    chapbook = {
      head = "",
      body_attrs = "",
      body_prefix = "",
      body_suffix = ""
    },
    snowman = {
      head = "",
      body_attrs = "",
      body_prefix = "",
      body_suffix = ""
    }
  }

  return templates[format:lower()] or templates.harlowe
end

--------------------------------------------------------------------------------
-- Placeholder Engines
--------------------------------------------------------------------------------

--- Harlowe minimal engine
---@return string Placeholder JavaScript
function FormatTemplateProvider._harlowe_placeholder()
  return [[
/* Harlowe engine placeholder */
window.Harlowe = {
  version: "3.3.8",

  init: function() {
    console.log("Harlowe placeholder engine loaded");
    // Full Harlowe engine would go here
  }
};

window.addEventListener('DOMContentLoaded', function() {
  window.Harlowe.init();
});
]]
end

--- SugarCube minimal engine
---@return string Placeholder JavaScript
function FormatTemplateProvider._sugarcube_placeholder()
  return [[
/* SugarCube engine placeholder */
window.SugarCube = {
  version: "2.36.1",

  State: {
    variables: {}
  },

  init: function() {
    console.log("SugarCube placeholder engine loaded");
    // Full SugarCube engine would go here
  }
};

window.addEventListener('DOMContentLoaded', function() {
  window.SugarCube.init();
});
]]
end

--- Chapbook minimal engine
---@return string Placeholder JavaScript
function FormatTemplateProvider._chapbook_placeholder()
  return [[
/* Chapbook engine placeholder */
window.Chapbook = {
  version: "1.2.3",

  init: function() {
    console.log("Chapbook placeholder engine loaded");
    // Full Chapbook engine would go here
  }
};

window.addEventListener('DOMContentLoaded', function() {
  window.Chapbook.init();
});
]]
end

--- Snowman minimal engine
---@return string Placeholder JavaScript
function FormatTemplateProvider._snowman_placeholder()
  return [[
/* Snowman engine placeholder */
window.story = {
  passages: {},

  show: function(passageName) {
    console.log("Navigating to:", passageName);
  },

  init: function() {
    console.log("Snowman placeholder engine loaded");
  }
};

var s = {};  // Story state object

window.addEventListener('DOMContentLoaded', function() {
  window.story.init();
});
]]
end

--------------------------------------------------------------------------------
-- Format Detection
--------------------------------------------------------------------------------

--- Check if format is supported
---@param format string Format name
---@return boolean True if supported
function FormatTemplateProvider.is_supported(format)
  local supported = { "harlowe", "sugarcube", "chapbook", "snowman" }
  for _, f in ipairs(supported) do
    if f == format:lower() then
      return true
    end
  end
  return false
end

--- Get list of supported formats
---@return table Array of format names
function FormatTemplateProvider.get_supported_formats()
  return { "harlowe", "sugarcube", "chapbook", "snowman" }
end

return FormatTemplateProvider
