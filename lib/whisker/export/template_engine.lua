--- Template Engine
-- Simple template engine with variable substitution and partials
-- @module whisker.export.template_engine
-- @author Whisker Core Team
-- @license MIT

local TemplateEngine = {}
TemplateEngine._dependencies = {}
TemplateEngine.__index = TemplateEngine

--- Create a new template engine instance
-- @return TemplateEngine A new template engine
function TemplateEngine.new(deps)
  deps = deps or {}
  local self = setmetatable({}, TemplateEngine)
  self._templates = {}
  self._partials = {}
  self._helpers = {}
  return self
end

--- Register a template
-- @param name string Template name
-- @param template_string string Template content
function TemplateEngine:register(name, template_string)
  self._templates[name] = template_string
end

--- Get a registered template
-- @param name string Template name
-- @return string|nil Template content or nil
function TemplateEngine:get(name)
  return self._templates[name]
end

--- Register a partial (reusable fragment)
-- @param name string Partial name
-- @param partial_string string Partial content
function TemplateEngine:register_partial(name, partial_string)
  self._partials[name] = partial_string
end

--- Get a registered partial
-- @param name string Partial name
-- @return string|nil Partial content or nil
function TemplateEngine:get_partial(name)
  return self._partials[name]
end

--- Register a helper function
-- @param name string Helper name
-- @param fn function Helper function(value) -> string
function TemplateEngine:register_helper(name, fn)
  self._helpers[name] = fn
end

--- Render a registered template with data
-- @param template_name string Name of registered template
-- @param data table Data to render with
-- @return string Rendered template
function TemplateEngine:render(template_name, data)
  local template = self._templates[template_name]
  if not template then
    error("Template not found: " .. template_name)
  end

  return self:render_string(template, data)
end

--- Render a template string with data
-- @param template_string string Template content
-- @param data table Data to render with
-- @return string Rendered template
function TemplateEngine:render_string(template_string, data)
  data = data or {}
  local result = template_string

  -- Render conditionals first: {{#if condition}}...{{/if}}
  result = self:render_conditionals(result, data)

  -- Render partials: {{> partial_name}}
  result = result:gsub("{{>%s*([%w_%-]+)%s*}}", function(partial_name)
    local partial = self._partials[partial_name]
    if not partial then
      return "<!-- partial '" .. partial_name .. "' not found -->"
    end
    return self:render_string(partial, data)
  end)

  -- Render helper calls: {{helper_name argument}}
  result = result:gsub("{{%s*([%w_]+)%s+([^}]+)%s*}}", function(helper_name, argument)
    local helper = self._helpers[helper_name]
    if not helper then
      return "<!-- helper '" .. helper_name .. "' not found -->"
    end

    -- Try to get value from data, or use argument as literal
    local arg_value = self:get_nested_value(data, argument:match("^%s*(.-)%s*$"))
    if arg_value == nil then
      arg_value = argument:match("^%s*(.-)%s*$")
    end

    local ok, helper_result = pcall(helper, arg_value)
    if ok then
      return tostring(helper_result or "")
    else
      return "<!-- helper error: " .. tostring(helper_result) .. " -->"
    end
  end)

  -- Render triple-brace variables (unescaped): {{{variable}}}
  result = result:gsub("{{{%s*([%w_.]+)%s*}}}", function(var_name)
    local value = self:get_nested_value(data, var_name)
    return tostring(value or "")
  end)

  -- Render double-brace variables: {{variable}}
  result = result:gsub("{{%s*([%w_.]+)%s*}}", function(var_name)
    local value = self:get_nested_value(data, var_name)
    return tostring(value or "")
  end)

  return result
end

--- Render conditional blocks
-- @param template string Template with conditionals
-- @param data table Data for evaluation
-- @return string Template with conditionals resolved
function TemplateEngine:render_conditionals(template, data)
  local result = template

  -- Process conditionals by handling innermost first
  local changed = true
  local max_iterations = 100  -- Prevent infinite loops
  local iteration = 0

  while changed and iteration < max_iterations do
    changed = false
    iteration = iteration + 1

    -- Match {{#if condition}}...{{else}}...{{/if}}
    local new_result = result:gsub("{{#if%s+([^}]+)}}(.-){{else}}(.-){{/if}}", function(condition, if_content, else_content)
      changed = true
      local cond_value = self:get_nested_value(data, condition:match("^%s*(.-)%s*$"))
      local is_truthy = cond_value ~= nil and cond_value ~= false and cond_value ~= ""

      if is_truthy then
        return if_content
      else
        return else_content
      end
    end)

    if new_result ~= result then
      result = new_result
    else
      -- Match {{#if condition}}...{{/if}} without else
      result = result:gsub("{{#if%s+([^}]+)}}(.-){{/if}}", function(condition, content)
        changed = true
        local cond_value = self:get_nested_value(data, condition:match("^%s*(.-)%s*$"))
        local is_truthy = cond_value ~= nil and cond_value ~= false and cond_value ~= ""

        if is_truthy then
          return content
        else
          return ""
        end
      end)
    end
  end

  return result
end

--- Get nested value from data (e.g., "story.title")
-- @param data table Data object
-- @param path string Dot-separated path
-- @return any Value at path or nil
function TemplateEngine:get_nested_value(data, path)
  if not data or not path then
    return nil
  end

  local value = data
  for part in path:gmatch("[^.]+") do
    if type(value) ~= "table" then
      return nil
    end
    value = value[part]
  end

  return value
end

--- Check if a template is registered
-- @param name string Template name
-- @return boolean True if template exists
function TemplateEngine:has_template(name)
  return self._templates[name] ~= nil
end

--- Check if a partial is registered
-- @param name string Partial name
-- @return boolean True if partial exists
function TemplateEngine:has_partial(name)
  return self._partials[name] ~= nil
end

--- Get all registered template names
-- @return table Array of template names
function TemplateEngine:get_template_names()
  local names = {}
  for name in pairs(self._templates) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Get all registered partial names
-- @return table Array of partial names
function TemplateEngine:get_partial_names()
  local names = {}
  for name in pairs(self._partials) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Clear all templates, partials, and helpers
function TemplateEngine:clear()
  self._templates = {}
  self._partials = {}
  self._helpers = {}
end

return TemplateEngine
