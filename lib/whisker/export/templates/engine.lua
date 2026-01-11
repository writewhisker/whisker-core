--- Template Engine for Exports
-- Simple but powerful template engine for rendering stories in various formats
-- Supports variables, conditionals, loops, and includes
--
-- @module whisker.export.templates.engine
-- @author Whisker Team
-- @license MIT
-- @usage
-- local Engine = require("whisker.export.templates.engine")
-- local html = Engine.render(story, "html/default")

local TemplateEngine = {}

--- Registered templates
TemplateEngine.templates = {}

--- Template cache
local template_cache = {}

--- Register a template
-- @param name string Template name (e.g., "html/default")
-- @param template string|function Template string or function
-- @usage
-- Engine.register("html/default", [[
--   <html><head><title>{{title}}</title></head>
--   <body>{{#passages}}<p>{{content}}</p>{{/passages}}</body>
--   </html>
-- ]])
function TemplateEngine.register(name, template)
  TemplateEngine.templates[name] = template
  template_cache[name] = nil  -- Clear cache
end

--- Get template by name
-- @param name string Template name
-- @return string|function|nil template Template or nil if not found
function TemplateEngine.get(name)
  return TemplateEngine.templates[name]
end

--- List all registered templates
-- @return table names Array of template names
function TemplateEngine.list()
  local names = {}
  for name in pairs(TemplateEngine.templates) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Escape HTML special characters
-- @param text string Text to escape
-- @return string escaped Escaped text
local function escape_html(text)
  if not text then return "" end
  text = tostring(text)
  text = text:gsub("&", "&amp;")
  text = text:gsub("<", "&lt;")
  text = text:gsub(">", "&gt;")
  text = text:gsub('"', "&quot;")
  text = text:gsub("'", "&#39;")
  return text
end

--- Built-in filters
TemplateEngine.filters = {
  -- Escape HTML
  escape = escape_html,
  
  -- Convert to uppercase
  upper = function(text)
    return tostring(text):upper()
  end,
  
  -- Convert to lowercase
  lower = function(text)
    return tostring(text):lower()
  end,
  
  -- Capitalize first letter
  capitalize = function(text)
    text = tostring(text)
    return text:sub(1, 1):upper() .. text:sub(2)
  end,
  
  -- Trim whitespace
  trim = function(text)
    return tostring(text):match("^%s*(.-)%s*$")
  end,
  
  -- Default value if nil/empty
  default = function(text, default_value)
    if not text or text == "" then
      return default_value
    end
    return text
  end,
  
  -- Join array with separator
  join = function(array, separator)
    separator = separator or ", "
    if type(array) == "table" then
      return table.concat(array, separator)
    end
    return tostring(array)
  end,
  
  -- Get length
  length = function(value)
    if type(value) == "table" then
      return #value
    elseif type(value) == "string" then
      return #value
    end
    return 0
  end
}

--- Register a custom filter
-- @param name string Filter name
-- @param func function Filter function(value, ...)
function TemplateEngine.register_filter(name, func)
  TemplateEngine.filters[name] = func
end

--- Resolve variable path in context
-- Supports dot notation: "metadata.title"
-- @param path string Variable path
-- @param context table Data context
-- @return any value Variable value
local function resolve_variable(path, context)
  local value = context
  
  for part in path:gmatch("[^.]+") do
    if type(value) == "table" then
      value = value[part]
    else
      return nil
    end
  end
  
  return value
end

--- Apply filter to value
-- @param value any Value to filter
-- @param filter_expr string Filter expression "filter:arg1:arg2"
-- @param context table Data context
-- @return any filtered Filtered value
local function apply_filter(value, filter_expr, context)
  local parts = {}
  for part in filter_expr:gmatch("[^:]+") do
    table.insert(parts, part)
  end
  
  local filter_name = parts[1]
  local filter_func = TemplateEngine.filters[filter_name]
  
  if not filter_func then
    return value
  end
  
  -- Collect filter arguments
  local args = {value}
  for i = 2, #parts do
    table.insert(args, parts[i])
  end
  
  return filter_func(table.unpack(args))
end

--- Render template with context
-- @param template string Template string
-- @param context table Data context
-- @return string rendered Rendered output
function TemplateEngine.render_string(template, context)
  context = context or {}
  local output = template
  
  -- Replace variables: {{variable}} or {{variable|filter}}
  output = output:gsub("{{([^}]+)}}", function(expr)
    expr = expr:match("^%s*(.-)%s*$")  -- Trim whitespace
    
    -- Check for filter
    local var_path, filter_expr = expr:match("^([^|]+)|(.+)$")
    if not var_path then
      var_path = expr
    end
    
    var_path = var_path:match("^%s*(.-)%s*$")  -- Trim
    
    local value = resolve_variable(var_path, context)
    
    -- Apply filter if present
    if filter_expr then
      value = apply_filter(value, filter_expr, context)
    end
    
    return tostring(value or "")
  end)
  
  -- Process conditionals: {{#if condition}}...{{/if}}
  output = output:gsub("{{#if%s+([^}]+)}}(.-){{/if}}", function(condition, content)
    condition = condition:match("^%s*(.-)%s*$")
    local value = resolve_variable(condition, context)
    
    -- Truthiness: non-nil, non-false, non-empty
    if value and value ~= false and value ~= "" then
      if type(value) == "table" and #value == 0 then
        return ""
      end
      return content
    end
    return ""
  end)
  
  -- Process loops: {{#each items}}...{{/each}}
  output = output:gsub("{{#each%s+([^}]+)}}(.-){{/each}}", function(array_path, content)
    array_path = array_path:match("^%s*(.-)%s*$")
    local array = resolve_variable(array_path, context)
    
    if type(array) ~= "table" then
      return ""
    end
    
    local results = {}
    for i, item in ipairs(array) do
      -- Create item context with special variables
      local item_context = {
        ["@index"] = i,
        ["@first"] = i == 1,
        ["@last"] = i == #array,
        ["@parent"] = context
      }
      
      -- Merge item properties
      if type(item) == "table" then
        for k, v in pairs(item) do
          item_context[k] = v
        end
      else
        item_context["@value"] = item
      end
      
      -- Merge parent context
      for k, v in pairs(context) do
        if not item_context[k] then
          item_context[k] = v
        end
      end
      
      -- Render iteration
      local rendered = TemplateEngine.render_string(content, item_context)
      table.insert(results, rendered)
    end
    
    return table.concat(results)
  end)
  
  return output
end

--- Render template by name with context
-- @param story table Story data
-- @param template_name string Template name
-- @param options table Additional options
-- @return string|nil rendered Rendered output
-- @return string|nil error Error message if failed
function TemplateEngine.render(story, template_name, options)
  options = options or {}
  
  -- Get template
  local template = TemplateEngine.templates[template_name]
  if not template then
    return nil, string.format("Template not found: %s", template_name)
  end
  
  -- If template is a function, call it
  if type(template) == "function" then
    local success, result = pcall(template, story, options)
    if not success then
      return nil, string.format("Template error: %s", result)
    end
    return result
  end
  
  -- Build context from story
  local context = {
    title = (story.metadata and story.metadata.title) or story.title or "Untitled",
    author = (story.metadata and story.metadata.author) or story.author,
    passages = story.passages or {},
    variables = story.variables or {},
    tags = story.tags or {},
    story = story,  -- Full story object
    options = options
  }
  
  -- Render template
  local success, result = pcall(TemplateEngine.render_string, template, context)
  if not success then
    return nil, string.format("Render error: %s", result)
  end
  
  return result
end

--- Load built-in templates
function TemplateEngine.load_builtin()
  -- HTML Default Template
  TemplateEngine.register("html/default", [[
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{{title|escape}}</title>
  <style>
    body { font-family: Georgia, serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
    h1 { color: #333; }
    .passage { margin: 30px 0; padding: 20px; border-left: 3px solid #3498db; }
    .passage-title { font-weight: bold; color: #3498db; margin-bottom: 10px; }
    .passage-content { line-height: 1.6; }
    .meta { color: #666; font-size: 0.9em; margin-top: 40px; }
  </style>
</head>
<body>
  <h1>{{title|escape}}</h1>
  {{#if author}}<p class="meta">by {{author|escape}}</p>{{/if}}
  
  {{#each passages}}
  <div class="passage">
    <div class="passage-title">{{name|escape|default:id}}</div>
    <div class="passage-content">{{content}}</div>
  </div>
  {{/each}}
  
  <div class="meta">
    Generated with Whisker • {{passages|length}} passage{{#if passages}}s{{/if}}
  </div>
</body>
</html>
]])

  -- Markdown Template
  TemplateEngine.register("markdown/default", [[
# {{title}}

{{#if author}}*by {{author}}*{{/if}}

---

{{#each passages}}
## {{name|default:id}}

{{content}}

---
{{/each}}

*Generated with Whisker • {{passages|length}} passages*
]])

  -- Plain Text Template
  TemplateEngine.register("text/default", [[
{{title|upper}}
{{#if author}}by {{author}}{{/if}}

{{#each passages}}
[{{name|default:id}}]

{{content}}

---
{{/each}}

Generated with Whisker
{{passages|length}} passages
]])
end

-- Load built-in templates on module load
TemplateEngine.load_builtin()

return TemplateEngine
