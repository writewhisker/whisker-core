-- lib/whisker/core/renderer.lua
-- WLS 2.0 Renderer with Hook Support

local HookManager = require("lib.whisker.wls2.hook_manager")

local Renderer = {}
Renderer.__index = Renderer

-- Platform-specific formatting tags
local platform_tags = {
  plain = {
    bold_start = "",
    bold_end = "",
    italic_start = "",
    italic_end = "",
    underline_start = "",
    underline_end = ""
  },
  console = {
    bold_start = "\027[1m",
    bold_end = "\027[22m",
    italic_start = "\027[3m",
    italic_end = "\027[23m",
    underline_start = "\027[4m",
    underline_end = "\027[24m"
  },
  web = {
    bold_start = "<strong>",
    bold_end = "</strong>",
    italic_start = "<em>",
    italic_end = "</em>",
    underline_start = "<u>",
    underline_end = "</u>"
  }
}

-- Constructor
-- Supports two API patterns:
-- 1. New API: Renderer.new(platform, options_table)
--    Options: max_line_width, enable_wrapping, enable_formatting
-- 2. Legacy API: Renderer.new(interpreter, platform, hook_manager)
-- @param first_arg - Platform string (new API) or interpreter (legacy API)
-- @param second_arg - Options table (new API) or platform string (legacy API)
-- @param third_arg - Hook manager (legacy API only)
function Renderer.new(first_arg, second_arg, third_arg)
  local self = setmetatable({}, Renderer)

  -- Detect which API is being used
  if type(first_arg) == "string" and (second_arg == nil or type(second_arg) == "table") then
    -- New API: Renderer.new(platform, options)
    self.platform = first_arg
    local options = second_arg or {}
    self.max_line_width = options.max_line_width
    self.enable_wrapping = options.enable_wrapping
    self.enable_formatting = options.enable_formatting
    self.interpreter = nil
    self.hook_manager = HookManager.new()
  else
    -- Legacy API: Renderer.new(interpreter, platform, hook_manager)
    self.interpreter = first_arg
    self.platform = second_arg or "plain"
    self.hook_manager = third_arg or HookManager.new()
  end

  self.tags = platform_tags[self.platform] or platform_tags.plain
  return self
end

-- Set interpreter after construction
-- @param interpreter - Script interpreter
function Renderer:set_interpreter(interpreter)
  self.interpreter = interpreter
end

-- Render text to plain format, stripping all formatting markers
-- @param text string - Text with formatting markers
-- @param game_state table - Current game state (for variable evaluation)
-- @return string - Plain text with formatting stripped
function Renderer:render_plain(text, game_state)
  local plain = text

  -- Strip bold markers: **text**
  plain = plain:gsub("%*%*(.-)%*%*", "%1")

  -- Strip italic markers: *text*
  plain = plain:gsub("%*(.-)%*", "%1")

  -- Strip underline markers: __text__
  plain = plain:gsub("__(.-)__", "%1")

  return plain
end

-- Extract hooks from text and register them
-- @param text string - The raw passage content
-- @param passage_id string - Current passage identifier
-- @return processed_text string - Text with hooks replaced by placeholders
-- @return hooks table - Map of extracted hook IDs
function Renderer:extract_hooks(text, passage_id)
  local processed = text
  local hooks = {}
  
  -- Pattern: |hookName>[content]
  -- Handle nested brackets by counting bracket depth
  local pos = 1
  while pos <= #text do
    local hook_start, hook_name_end, hook_name = text:find("|(%w+)>%[", pos)
    
    if hook_start then
      -- Found hook start, now extract content with bracket counting
      local bracket_depth = 1
      local content_start = hook_name_end + 1
      local content_pos = content_start
      
      while content_pos <= #text and bracket_depth > 0 do
        local char = text:sub(content_pos, content_pos)
        if char == "[" then
          bracket_depth = bracket_depth + 1
        elseif char == "]" then
          bracket_depth = bracket_depth - 1
        end
        content_pos = content_pos + 1
      end
      
      if bracket_depth == 0 then
        -- Successfully matched hook
        local content = text:sub(content_start, content_pos - 2)
        
        -- Register hook with manager
        local hook_id = self.hook_manager:register_hook(passage_id, hook_name, content)
        hooks[hook_id] = true
        
        -- Build result with placeholder
        processed = text:sub(1, hook_start - 1) .. 
                   "{{HOOK:" .. hook_id .. "}}" ..
                   text:sub(content_pos)
        
        -- Update text for next iteration
        text = processed
        pos = hook_start + #("{{HOOK:" .. hook_id .. "}}")
      else
        pos = content_pos
      end
    else
      break
    end
  end
  
  return processed, hooks
end

-- Render hooks by replacing placeholders with current content
-- @param text string - Text with hook placeholders
-- @param passage_id string - Passage identifier for hook lookups
-- @param game_state table - Current game state for expression evaluation
-- @return rendered_text string - Text with placeholders replaced
function Renderer:render_hooks(text, passage_id, game_state)
  local rendered = text
  
  -- Pattern: {{HOOK:hook_id}}
  rendered = rendered:gsub("{{HOOK:([^}]+)}}", function(hook_id)
    local hook = self.hook_manager:get_hook(hook_id)
    
    -- Only render if hook exists and is visible
    if hook and hook.visible then
      local content = hook.current_content
      
      -- Apply expressions to hook content
      content = self:evaluate_expressions(content, game_state)
      
      -- Apply formatting to hook content
      content = self:apply_formatting(content)
      
      return content
    end
    
    -- Return empty string for hidden or non-existent hooks
    return ""
  end)
  
  return rendered
end

-- Evaluate expressions in text
-- @param text string - Text with expressions
-- @param game_state table - Current game state
-- @return processed_text string - Text with expressions evaluated
function Renderer:evaluate_expressions(text, game_state)
  local processed = text

  if game_state then
    -- Handle escaped $ (replace temporarily with unique marker)
    -- Use string.char(1) (SOH) as delimiter for Lua 5.1/LuaJIT compatibility
    -- Null bytes (\0) cause issues with pattern matching in older Lua versions
    local MARKER = string.char(1) .. "ESCAPED_DOLLAR" .. string.char(1)
    processed = processed:gsub("\\%$", MARKER)

    -- Handle {{variable}} syntax (allows underscores in variable names)
    processed = processed:gsub("{{([%w_]+)}}", function(var_name)
      local value
      if game_state.get then
        value = game_state:get(var_name)
      else
        value = game_state[var_name]
      end
      return tostring(value or "")
    end)

    -- Handle ${expression} syntax (evaluate Lua expressions)
    -- Use load (Lua 5.2+) or loadstring (Lua 5.1)
    local load_fn = load or loadstring
    processed = processed:gsub("%${([^}]+)}", function(expr)
      -- Try to evaluate the expression
      local chunk = load_fn("return " .. expr)
      if chunk then
        -- Set up environment with game state variables
        local env = {}
        setmetatable(env, {__index = function(_, k)
          if game_state.get then
            return game_state:get(k)
          else
            return game_state[k]
          end
        end})
        -- Handle both Lua 5.1 and 5.2+ environments
        if setfenv then
          setfenv(chunk, env)
        else
          -- Lua 5.2+ doesn't have setfenv, need to use debug.setupvalue
          debug.setupvalue(chunk, 1, env)
        end
        local ok, result = pcall(chunk)
        if ok then
          return tostring(result)
        end
      end
      return "${" .. expr .. "}"
    end)

    -- Handle $_varname for temp variables
    processed = processed:gsub("%$_([%w_]+)", function(var_name)
      local value
      if game_state.get_temp then
        value = game_state:get_temp(var_name)
      end
      if value ~= nil then
        return tostring(value)
      end
      return "$_" .. var_name  -- Leave undefined as-is
    end)

    -- Simple variable interpolation $varname
    processed = processed:gsub("%$([%w_]+)", function(var_name)
      local value
      if game_state.get then
        value = game_state:get(var_name)
      else
        value = game_state[var_name]
      end
      if value ~= nil then
        return tostring(value)
      end
      return "$" .. var_name  -- Leave undefined as-is
    end)

    -- Restore escaped $ signs
    processed = processed:gsub(MARKER, "$")
  end

  return processed
end

-- Apply formatting to text
-- @param text string - Text with formatting markers
-- @return formatted_text string - Text with platform-specific formatting
function Renderer:apply_formatting(text)
  local formatted = text
  
  -- Bold: **text**
  formatted = formatted:gsub("%*%*(.-)%*%*", function(content)
    return self.tags.bold_start .. content .. self.tags.bold_end
  end)
  
  -- Italic: *text*
  formatted = formatted:gsub("%*(.-)%*", function(content)
    return self.tags.italic_start .. content .. self.tags.italic_end
  end)
  
  -- Underline: __text__
  formatted = formatted:gsub("__(.-)__", function(content)
    return self.tags.underline_start .. content .. self.tags.underline_end
  end)
  
  return formatted
end

-- Apply text wrapping
-- @param text string - Text to wrap
-- @return wrapped_text string - Wrapped text
function Renderer:apply_wrapping(text)
  -- Only wrap if wrapping is enabled and max_line_width is set
  if not self.enable_wrapping or not self.max_line_width then
    return text
  end

  local max_width = self.max_line_width
  local result = {}
  local current_line = ""

  -- Split text into words
  for word in text:gmatch("%S+") do
    if current_line == "" then
      current_line = word
    elseif #current_line + 1 + #word <= max_width then
      current_line = current_line .. " " .. word
    else
      table.insert(result, current_line)
      current_line = word
    end
  end

  -- Add remaining line
  if current_line ~= "" then
    table.insert(result, current_line)
  end

  return table.concat(result, "\n")
end

-- Render passage with full pipeline including hooks
-- @param passage Passage - The passage object to render
-- @param game_state table - Current game state
-- @param passage_id string - Passage identifier
-- @return rendered_text string - Final rendered output
function Renderer:render_passage(passage, game_state, passage_id)
  local content = passage.content
  
  -- Phase 1: Extract hooks and register them
  local processed, hooks = self:extract_hooks(content, passage_id)
  
  -- Phase 2: Evaluate expressions in main text (not in hooks yet)
  processed = self:evaluate_expressions(processed, game_state)
  
  -- Phase 3: Apply formatting to main text (not in hooks yet)
  processed = self:apply_formatting(processed)
  
  -- Phase 4: Render hooks (replace placeholders with processed hook content)
  -- This applies expressions and formatting to hook content
  processed = self:render_hooks(processed, passage_id, game_state)
  
  -- Phase 5: Apply wrapping if needed
  processed = self:apply_wrapping(processed)
  
  return processed
end

-- Re-render passage after hook operations (skip hook extraction)
-- @param passage Passage - The passage object
-- @param game_state table - Current game state
-- @param passage_id string - Passage identifier
-- @return rendered_text string - Updated rendered output
function Renderer:rerender_passage(passage, game_state, passage_id)
  local content = passage.content
  
  -- Replace hook definitions with placeholders directly
  -- (hooks already registered, don't register again)
  -- Use bracket counting for nested brackets
  local pos = 1
  local result = ""
  
  while pos <= #content do
    local hook_start, hook_name_end, hook_name = content:find("|(%w+)>%[", pos)
    
    if hook_start then
      -- Add text before hook
      result = result .. content:sub(pos, hook_start - 1)
      
      -- Find matching closing bracket
      local bracket_depth = 1
      local content_start = hook_name_end + 1
      local content_pos = content_start
      
      while content_pos <= #content and bracket_depth > 0 do
        local char = content:sub(content_pos, content_pos)
        if char == "[" then
          bracket_depth = bracket_depth + 1
        elseif char == "]" then
          bracket_depth = bracket_depth - 1
        end
        content_pos = content_pos + 1
      end
      
      if bracket_depth == 0 then
        -- Add placeholder
        local hook_id = passage_id .. "_" .. hook_name
        result = result .. "{{HOOK:" .. hook_id .. "}}"
        pos = content_pos
      else
        -- Malformed hook, just skip
        result = result .. content:sub(hook_start, content_pos - 1)
        pos = content_pos
      end
    else
      -- No more hooks, add rest of content
      result = result .. content:sub(pos)
      break
    end
  end
  
  content = result
  
  -- Apply standard rendering phases
  content = self:evaluate_expressions(content, game_state)
  content = self:apply_formatting(content)
  content = self:render_hooks(content, passage_id, game_state)
  content = self:apply_wrapping(content)
  
  return content
end

return Renderer
