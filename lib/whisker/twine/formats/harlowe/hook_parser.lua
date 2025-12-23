--- Named hook parser for Harlowe
-- Handles: |hookName>[content]
--
-- lib/whisker/twine/formats/harlowe/hook_parser.lua

local HookParser = {}

local ASTBuilder = require('whisker.twine.ast_builder')

--------------------------------------------------------------------------------
-- Named Hook Detection and Parsing
--------------------------------------------------------------------------------

--- Parse named hooks from passage content
---@param content string Passage text
---@return table Array of { name, start_pos, end_pos, content }
function HookParser.find_named_hooks(content)
  local hooks = {}
  local pos = 1

  while pos <= #content do
    -- Look for |hookName> pattern
    local hook_start, hook_name_end = content:find("|[%w_]+>", pos)

    if not hook_start then
      break
    end

    -- Extract hook name
    local hook_name = content:match("|([%w_]+)>", hook_start)
    local hook_content_start = hook_name_end + 1

    -- Find matching [content]
    if content:sub(hook_content_start, hook_content_start) == "[" then
      local hook_end = HookParser._find_matching_bracket(content, hook_content_start)

      if hook_end then
        table.insert(hooks, {
          name = hook_name,
          start_pos = hook_start,
          end_pos = hook_end,
          content_start = hook_content_start + 1,
          content_end = hook_end - 1,
          content = content:sub(hook_content_start + 1, hook_end - 1)
        })

        pos = hook_end + 1
      else
        pos = hook_content_start + 1
      end
    else
      pos = hook_content_start
    end
  end

  return hooks
end

--- Find matching closing bracket accounting for nesting
---@param content string Content to search
---@param start_pos number Position of opening bracket
---@return number|nil Position of closing bracket
function HookParser._find_matching_bracket(content, start_pos)
  local depth = 0
  local in_string = false
  local string_char = nil

  for i = start_pos, #content do
    local char = content:sub(i, i)
    local prev_char = i > 1 and content:sub(i - 1, i - 1) or ""

    -- Handle string literals
    if (char == '"' or char == "'") and prev_char ~= "\\" then
      if not in_string then
        in_string = true
        string_char = char
      elseif char == string_char then
        in_string = false
        string_char = nil
      end
    elseif not in_string then
      if char == "[" then
        depth = depth + 1
      elseif char == "]" then
        depth = depth - 1
        if depth == 0 then
          return i
        end
      end
    end
  end

  return nil
end

--- Parse all named hooks in content and return AST nodes
---@param content string Passage content
---@return table Array of named hook AST nodes
function HookParser.parse_hooks(content)
  local hooks = HookParser.find_named_hooks(content)
  local nodes = {}

  for _, hook in ipairs(hooks) do
    local node = ASTBuilder.create_named_hook(
      hook.name,
      { ASTBuilder.create_text(hook.content) },
      false -- not hidden by default
    )
    table.insert(nodes, node)
  end

  return nodes
end

--------------------------------------------------------------------------------
-- Hook Manipulation
--------------------------------------------------------------------------------

--- Replace named hook content
---@param content string Original content
---@param hook_name string Hook to replace
---@param new_content string New content for hook
---@return string Updated content
function HookParser.replace_hook(content, hook_name, new_content)
  local hooks = HookParser.find_named_hooks(content)

  for _, hook in ipairs(hooks) do
    if hook.name == hook_name then
      local before = content:sub(1, hook.start_pos - 1)
      local after = content:sub(hook.end_pos + 1)
      return before .. new_content .. after
    end
  end

  return content -- Hook not found
end

--- Append content to a named hook
---@param content string Original content
---@param hook_name string Hook to append to
---@param append_content string Content to append
---@return string Updated content
function HookParser.append_to_hook(content, hook_name, append_content)
  local hooks = HookParser.find_named_hooks(content)

  for _, hook in ipairs(hooks) do
    if hook.name == hook_name then
      local before = content:sub(1, hook.content_end)
      local after = content:sub(hook.content_end + 1)
      return before .. append_content .. after
    end
  end

  return content -- Hook not found
end

--- Prepend content to a named hook
---@param content string Original content
---@param hook_name string Hook to prepend to
---@param prepend_content string Content to prepend
---@return string Updated content
function HookParser.prepend_to_hook(content, hook_name, prepend_content)
  local hooks = HookParser.find_named_hooks(content)

  for _, hook in ipairs(hooks) do
    if hook.name == hook_name then
      local before = content:sub(1, hook.content_start - 1)
      local after = content:sub(hook.content_start)
      return before .. prepend_content .. after
    end
  end

  return content -- Hook not found
end

--- Get hook content by name
---@param content string Passage content
---@param hook_name string Hook name to find
---@return string|nil Hook content or nil if not found
function HookParser.get_hook_content(content, hook_name)
  local hooks = HookParser.find_named_hooks(content)

  for _, hook in ipairs(hooks) do
    if hook.name == hook_name then
      return hook.content
    end
  end

  return nil
end

--------------------------------------------------------------------------------
-- Content Extraction
--------------------------------------------------------------------------------

--- Remove all named hooks from content, returning clean text
---@param content string Passage content
---@return string Content with hooks removed
---@return table Array of extracted hook definitions
function HookParser.extract_hooks(content)
  local hooks = HookParser.find_named_hooks(content)
  local extracted = {}
  local result = content

  -- Process in reverse order to maintain positions
  for i = #hooks, 1, -1 do
    local hook = hooks[i]
    table.insert(extracted, 1, {
      name = hook.name,
      content = hook.content
    })

    -- Remove the hook from content
    result = result:sub(1, hook.start_pos - 1) .. result:sub(hook.end_pos + 1)
  end

  return result, extracted
end

--- Check if content contains named hooks
---@param content string Passage content
---@return boolean True if named hooks are present
function HookParser.has_named_hooks(content)
  return content:match("|[%w_]+>%[") ~= nil
end

--------------------------------------------------------------------------------
-- Hidden Hook Support
--------------------------------------------------------------------------------

--- Parse hidden hooks (|hookName)[content] vs visible |hookName>[content]
-- In Harlowe, |name)[content] creates a hidden hook, |name>[content] creates visible
---@param content string Passage content
---@return table Array of hooks with visibility info
function HookParser.find_all_hooks(content)
  local hooks = {}
  local pos = 1

  while pos <= #content do
    -- Look for |hookName pattern (either > or ) follows)
    local hook_start = content:find("|[%w_]+[>%)]", pos)

    if not hook_start then
      break
    end

    -- Get the full match to determine visibility
    local match_end = content:find("[>%)]", hook_start + 1)
    local hook_pattern = content:sub(hook_start, match_end)
    local hook_name = hook_pattern:match("|([%w_]+)")
    local visibility_char = hook_pattern:sub(-1)
    local is_hidden = visibility_char == ")"

    local hook_content_start = match_end + 1

    -- Find matching [content]
    if content:sub(hook_content_start, hook_content_start) == "[" then
      local hook_end = HookParser._find_matching_bracket(content, hook_content_start)

      if hook_end then
        table.insert(hooks, {
          name = hook_name,
          hidden = is_hidden,
          start_pos = hook_start,
          end_pos = hook_end,
          content = content:sub(hook_content_start + 1, hook_end - 1)
        })

        pos = hook_end + 1
      else
        pos = hook_content_start + 1
      end
    else
      pos = hook_content_start
    end
  end

  return hooks
end

return HookParser
