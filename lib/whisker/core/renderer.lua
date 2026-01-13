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
-- @param interpreter - Script interpreter (optional)
-- @param platform string - Platform type (console, web, plain)
-- @param hook_manager HookManager - Hook manager instance (optional)
function Renderer.new(interpreter, platform, hook_manager)
  local self = setmetatable({}, Renderer)
  self.interpreter = interpreter
  self.platform = platform or "plain"
  self.tags = platform_tags[self.platform] or platform_tags.plain
  self.hook_manager = hook_manager or HookManager.new()
  return self
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
  
  -- Simple variable interpolation $varname
  if game_state then
    processed = processed:gsub("%$(%w+)", function(var_name)
      return tostring(game_state[var_name] or "")
    end)
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

-- Apply text wrapping (stub for now)
-- @param text string - Text to wrap
-- @return wrapped_text string - Wrapped text
function Renderer:apply_wrapping(text)
  -- For now, just return text as-is
  -- In a real implementation, this would handle line wrapping
  return text
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
