-- lib/whisker/parser/ws_parser.lua
-- WLS 2.0 Parser with Hook and Rich Text Support

local WSParser = {}
WSParser.__index = WSParser

-- Hook operation types
local VALID_HOOK_OPERATIONS = {
  replace = true,
  append = true,
  prepend = true,
  show = true,
  hide = true
}

function WSParser.new()
  local instance = {
    content = "",
    position = 1
  }
  setmetatable(instance, WSParser)
  return instance
end

-- Main parsing entry point
function WSParser:parse_passage_content(content)
  self.content = content
  self.position = 1

  local ast = { type = "passage_content", nodes = {} }

  while self.position <= #content do
    -- Try to match hook definition
    local hook_def = self:parse_hook_definition()
    if hook_def then
      table.insert(ast.nodes, hook_def)
      goto continue
    end

    -- Try to match hook operation
    local hook_op = self:parse_hook_operation()
    if hook_op then
      table.insert(ast.nodes, hook_op)
      goto continue
    end

    -- Try to match rich text elements
    local rich_text = self:parse_rich_text()
    if rich_text then
      table.insert(ast.nodes, rich_text)
      goto continue
    end

    -- Try to parse text (everything else)
    local text_node = self:parse_text()
    if text_node then
      table.insert(ast.nodes, text_node)
      goto continue
    end

    -- Advance position to avoid infinite loop
    self.position = self.position + 1

    ::continue::
  end

  return ast
end

-- Parse rich text elements
function WSParser:parse_rich_text()
  local remaining = self.content:sub(self.position)

  -- Try horizontal rule first (line-based)
  local hr = self:parse_horizontal_rule()
  if hr then return hr end

  -- Try blockquote (line-based)
  local blockquote = self:parse_blockquote()
  if blockquote then return blockquote end

  -- Try list items (line-based)
  local list = self:parse_list()
  if list then return list end

  -- Try code fence (multi-line)
  local code_block = self:parse_code_fence()
  if code_block then return code_block end

  -- Try media elements
  local media = self:parse_media()
  if media then return media end

  -- Try inline formatting (bold must be before italic due to ** vs *)
  local bold = self:parse_bold()
  if bold then return bold end

  local strikethrough = self:parse_strikethrough()
  if strikethrough then return strikethrough end

  local inline_code = self:parse_inline_code()
  if inline_code then return inline_code end

  local italic = self:parse_italic()
  if italic then return italic end

  return nil
end

-- Parse media elements
function WSParser:parse_media()
  -- Try markdown image
  local image = self:parse_markdown_image()
  if image then return image end

  -- Try directive-based media
  local directive = self:parse_media_directive()
  if directive then return directive end

  return nil
end

-- Parse markdown image: ![alt](src)
function WSParser:parse_markdown_image()
  local remaining = self.content:sub(self.position)

  -- Look for ![ pattern
  if not remaining:match("^!%[") then
    return nil
  end

  -- Parse ![alt](src)
  local alt, src = remaining:match("^!%[(.-)%]%((.-)%)")
  if not alt or not src then
    return nil
  end

  local start_pos = self.position
  local full_match = remaining:match("^!%[.-%]%(.-%)")
  self.position = self.position + #full_match

  -- Parse optional title from src
  local title = nil
  local clean_src = src
  local src_part, title_part = src:match('^(.-)%s+"(.-)"$')
  if src_part and title_part then
    clean_src = src_part
    title = title_part
  end

  return {
    type = "image",
    alt = alt,
    src = clean_src:match("^%s*(.-)%s*$"), -- trim
    title = title,
    position = start_pos
  }
end

-- Parse directive-based media: @image(src), @video(src), @embed(url)
function WSParser:parse_media_directive()
  local remaining = self.content:sub(self.position)

  -- Look for @image, @video, or @embed pattern
  local directive, src = remaining:match("^@(image)%((.-)%)")
  if not directive then
    directive, src = remaining:match("^@(video)%((.-)%)")
  end
  if not directive then
    directive, src = remaining:match("^@(embed)%((.-)%)")
  end

  if not directive or not src then
    return nil
  end

  local start_pos = self.position
  local full_match = remaining:match("^@%w+%(.-%)")
  self.position = self.position + #full_match

  -- Remove quotes if present
  local clean_src = src:match('^"(.-)"$') or src:match("^'(.-)'$") or src
  clean_src = clean_src:match("^%s*(.-)%s*$") -- trim

  return {
    type = directive,
    src = clean_src,
    position = start_pos
  }
end

-- Parse bold text (**text**)
function WSParser:parse_bold()
  local remaining = self.content:sub(self.position)

  -- Look for ** pattern
  if not remaining:match("^%*%*") then
    return nil
  end

  -- Find matching closing **
  local content = remaining:match("^%*%*(.-)%*%*")
  if not content then
    return nil
  end

  local start_pos = self.position
  self.position = self.position + #content + 4  -- +4 for ** on each side

  return {
    type = "formatted_text",
    format = "bold",
    content = content,
    position = start_pos
  }
end

-- Parse italic text (*text*)
function WSParser:parse_italic()
  local remaining = self.content:sub(self.position)

  -- Look for single * (but not **)
  if not remaining:match("^%*[^%*]") then
    return nil
  end

  -- Find matching closing *
  local content = remaining:match("^%*([^%*]-)%*")
  if not content then
    return nil
  end

  local start_pos = self.position
  self.position = self.position + #content + 2  -- +2 for * on each side

  return {
    type = "formatted_text",
    format = "italic",
    content = content,
    position = start_pos
  }
end

-- Parse strikethrough text (~~text~~)
function WSParser:parse_strikethrough()
  local remaining = self.content:sub(self.position)

  -- Look for ~~ pattern
  if not remaining:match("^~~") then
    return nil
  end

  -- Find matching closing ~~
  local content = remaining:match("^~~(.-)~~")
  if not content then
    return nil
  end

  local start_pos = self.position
  self.position = self.position + #content + 4  -- +4 for ~~ on each side

  return {
    type = "formatted_text",
    format = "strikethrough",
    content = content,
    position = start_pos
  }
end

-- Parse inline code (`code`)
function WSParser:parse_inline_code()
  local remaining = self.content:sub(self.position)

  -- Look for ` pattern (but not ```)
  if not remaining:match("^`[^`]") then
    return nil
  end

  -- Find matching closing `
  local content = remaining:match("^`([^`]+)`")
  if not content then
    return nil
  end

  local start_pos = self.position
  self.position = self.position + #content + 2  -- +2 for ` on each side

  return {
    type = "formatted_text",
    format = "code",
    content = content,
    position = start_pos
  }
end

-- Parse code fence (```code```)
function WSParser:parse_code_fence()
  local remaining = self.content:sub(self.position)

  -- Look for ``` pattern
  if not remaining:match("^```") then
    return nil
  end

  -- Extract language and code
  local lang, code = remaining:match("^```(%w*)%s*\n(.-)\n```")
  if not code then
    -- Try without newline for single-line code blocks
    lang, code = remaining:match("^```(%w*)%s*(.-)\n?```")
  end

  if not code then
    return nil
  end

  local start_pos = self.position
  local full_match = remaining:match("^```%w*%s*\n?.-\n?```")
  self.position = self.position + #full_match

  return {
    type = "formatted_text",
    format = "code",
    language = lang ~= "" and lang or nil,
    content = code,
    position = start_pos
  }
end

-- Parse blockquote (> text)
function WSParser:parse_blockquote()
  local remaining = self.content:sub(self.position)

  -- Only match at line start
  if self.position > 1 then
    local prev_char = self.content:sub(self.position - 1, self.position - 1)
    if prev_char ~= "\n" and prev_char ~= "" then
      return nil
    end
  end

  -- Look for > pattern
  local markers, content = remaining:match("^(>+)%s*([^\n]*)")
  if not markers then
    return nil
  end

  local start_pos = self.position
  local depth = #markers
  self.position = self.position + #markers + (content and #content or 0)

  -- Skip trailing whitespace
  if self.content:sub(self.position, self.position) == " " then
    self.position = self.position + 1
  end

  return {
    type = "blockquote",
    depth = depth,
    content = content or "",
    position = start_pos
  }
end

-- Parse list items (- item or 1. item)
function WSParser:parse_list()
  local remaining = self.content:sub(self.position)

  -- Only match at line start
  if self.position > 1 then
    local prev_char = self.content:sub(self.position - 1, self.position - 1)
    if prev_char ~= "\n" and prev_char ~= "" then
      return nil
    end
  end

  -- Try unordered list (- item, * item, + item)
  local marker, content = remaining:match("^([%-%*%+])%s+([^\n]*)")
  if marker then
    local start_pos = self.position
    self.position = self.position + 1 + 1 + #content  -- marker + space + content

    return {
      type = "list_item",
      ordered = false,
      marker = marker,
      content = content,
      position = start_pos
    }
  end

  -- Try ordered list (1. item)
  marker, content = remaining:match("^(%d+%.)%s+([^\n]*)")
  if marker then
    local start_pos = self.position
    self.position = self.position + #marker + 1 + #content  -- marker + space + content

    return {
      type = "list_item",
      ordered = true,
      marker = marker,
      content = content,
      position = start_pos
    }
  end

  return nil
end

-- Parse horizontal rule (---)
function WSParser:parse_horizontal_rule()
  local remaining = self.content:sub(self.position)

  -- Only match at line start
  if self.position > 1 then
    local prev_char = self.content:sub(self.position - 1, self.position - 1)
    if prev_char ~= "\n" and prev_char ~= "" then
      return nil
    end
  end

  -- Look for --- or *** or ___ (3+ chars)
  local hr = remaining:match("^(%-%-%-+)%s*\n?") or
             remaining:match("^(%*%*%*+)%s*\n?") or
             remaining:match("^(___+)%s*\n?")

  if not hr then
    return nil
  end

  local start_pos = self.position
  self.position = self.position + #hr

  return {
    type = "horizontal_rule",
    position = start_pos
  }
end

-- Parse hook definition: |hookName>[content]
function WSParser:parse_hook_definition()
  local start_pos = self.position
  local remaining = self.content:sub(self.position)
  
  -- Try to match the hook definition pattern
  local hook_name, content_start = remaining:match("^|(%w+)>%[")
  
  if not hook_name then
    return nil
  end
  
  -- Move position past the opening pattern
  local prefix_len = #hook_name + 3  -- | + name + > + [
  self.position = self.position + prefix_len
  
  -- Extract hook content handling nested brackets
  local hook_content, end_pos = self:extract_hook_content()
  
  return {
    type = "hook_definition",
    name = hook_name,
    content = hook_content,
    position = start_pos
  }
end

-- Parse hook operation: @operation: target { content }
function WSParser:parse_hook_operation()
  local start_pos = self.position
  local remaining = self.content:sub(self.position)
  
  -- Match hook operation pattern
  local operation, target, op_content = remaining:match("^@(%w+):%s*(%w+)%s*{(.-)}%s*")
  
  if not operation then
    return nil
  end
  
  -- Validate operation type
  if not VALID_HOOK_OPERATIONS[operation] then
    return nil, string.format("Invalid hook operation: %s", operation)
  end
  
  -- Calculate how much to advance
  local pattern_match = remaining:match("^@%w+:%s*%w+%s*{.-}%s*")
  self.position = self.position + #pattern_match
  
  return {
    type = "hook_operation",
    operation = operation,
    target = target,
    content = op_content,
    position = start_pos
  }
end

-- Extract hook content handling nested brackets
function WSParser:extract_hook_content()
  local bracket_count = 1
  local chars = {}
  
  while self.position <= #self.content and bracket_count > 0 do
    local char = self.content:sub(self.position, self.position)
    
    if char == "[" then
      bracket_count = bracket_count + 1
      table.insert(chars, char)
      self.position = self.position + 1
    elseif char == "]" then
      bracket_count = bracket_count - 1
      if bracket_count > 0 then
        table.insert(chars, char)
      end
      self.position = self.position + 1
    else
      table.insert(chars, char)
      self.position = self.position + 1
    end
  end
  
  return table.concat(chars), self.position
end

-- Parse regular text (non-hook content)
function WSParser:parse_text()
  local start_pos = self.position
  local chars = {}

  while self.position <= #self.content do
    local char = self.content:sub(self.position, self.position)

    -- Check if we're at the start of a hook definition or operation
    local remaining = self.content:sub(self.position)
    if remaining:match("^|%w+>%[") or remaining:match("^@%w+:%s*%w+%s*{") then
      break
    end

    -- Check if we're at the start of rich text formatting
    -- Bold (**), italic (*), strikethrough (~~), inline code (`)
    if remaining:match("^%*%*[^%*]") then  -- Bold: **text**
      break
    end
    if remaining:match("^%*[^%*]") then  -- Italic: *text*
      break
    end
    if remaining:match("^~~") then  -- Strikethrough: ~~text~~
      break
    end
    if remaining:match("^`") then  -- Inline code: `code`
      break
    end

    table.insert(chars, char)
    self.position = self.position + 1
  end

  if #chars == 0 then
    return nil
  end

  return {
    type = "text",
    content = table.concat(chars),
    position = start_pos
  }
end

-- ============================================================================
-- Module System Parsing (WLS Chapter 12)
-- ============================================================================

-- Parse INCLUDE declaration: INCLUDE "path"
function WSParser:parse_include(content)
  self.content = content
  self.position = 1

  local remaining = self.content:sub(self.position)

  -- Match INCLUDE "path" or INCLUDE 'path'
  local path = remaining:match('^INCLUDE%s+"([^"]+)"') or
               remaining:match("^INCLUDE%s+'([^']+)'")

  if not path then
    return nil, "Expected path string after INCLUDE"
  end

  local start_pos = self.position
  local full_match = remaining:match('^INCLUDE%s+["\'][^"\']+["\']')
  self.position = self.position + #full_match

  return {
    type = "include_declaration",
    path = path,
    position = start_pos
  }
end

-- Parse FUNCTION declaration: FUNCTION name(param1, param2) ... END
function WSParser:parse_function_declaration(content)
  self.content = content
  self.position = 1

  local remaining = self.content:sub(self.position)

  -- Match FUNCTION name (name must be on same line)
  local name = remaining:match("^FUNCTION[ \t]+(%w+)")
  if not name then
    return nil, "Expected function name after FUNCTION"
  end

  local start_pos = self.position

  -- Move position past FUNCTION name
  self.position = self.position + #("FUNCTION " .. name)
  remaining = self.content:sub(self.position)

  -- Parse optional parameters
  local params = {}
  if remaining:match("^%s*%(") then
    -- Skip whitespace and opening paren
    local ws = remaining:match("^(%s*)%(")
    self.position = self.position + #ws + 1
    remaining = self.content:sub(self.position)

    -- Parse parameters until closing paren
    while not remaining:match("^%)") and self.position <= #self.content do
      -- Skip whitespace
      local ws_before = remaining:match("^(%s*)")
      if ws_before then
        self.position = self.position + #ws_before
        remaining = self.content:sub(self.position)
      end

      -- Match parameter name
      local param = remaining:match("^(%w+)")
      if param then
        table.insert(params, { name = param })
        self.position = self.position + #param
        remaining = self.content:sub(self.position)
      end

      -- Skip comma or whitespace
      local sep = remaining:match("^([%s,]*)")
      if sep then
        self.position = self.position + #sep
        remaining = self.content:sub(self.position)
      end

      if remaining:match("^%)") then
        break
      end
    end

    -- Skip closing paren
    if remaining:match("^%)") then
      self.position = self.position + 1
    end
  end

  -- Parse body until END
  remaining = self.content:sub(self.position)
  local body_content = remaining:match("(.-)%s*END%s*$")
  local body = {}

  if body_content then
    -- Parse body content recursively
    local body_parser = WSParser.new()
    local body_ast = body_parser:parse_passage_content(body_content)
    body = body_ast.nodes
  end

  return {
    type = "function_declaration",
    name = name,
    params = params,
    body = body,
    position = start_pos
  }
end

-- Parse NAMESPACE declaration: NAMESPACE Name ... END NAMESPACE
function WSParser:parse_namespace_declaration(content)
  self.content = content
  self.position = 1

  local remaining = self.content:sub(self.position)

  -- Match NAMESPACE name (name must be on same line)
  local name = remaining:match("^NAMESPACE[ \t]+(%w+)")
  if not name then
    return nil, "Expected namespace name after NAMESPACE"
  end

  local start_pos = self.position
  self.position = self.position + #("NAMESPACE " .. name)

  -- Note: Full parsing of namespace content would require recursive parsing
  -- For now, just capture the namespace structure
  local passages = {}
  local functions = {}
  local nested_namespaces = {}

  return {
    type = "namespace_declaration",
    name = name,
    passages = passages,
    functions = functions,
    nested_namespaces = nested_namespaces,
    position = start_pos
  }
end

-- Check if content starts with a module keyword
function WSParser:is_module_keyword(content)
  return content:match("^INCLUDE%s") ~= nil or
         content:match("^FUNCTION%s") ~= nil or
         content:match("^NAMESPACE%s") ~= nil or
         content:match("^END%s") ~= nil or
         content:match("^END$") ~= nil or
         content:match("^RETURN%s") ~= nil
end

-- Parse RETURN statement: RETURN value
function WSParser:parse_return(content)
  self.content = content
  self.position = 1

  local remaining = self.content:sub(self.position)

  -- Match RETURN and capture the rest as value
  if not remaining:match("^RETURN%s") then
    return nil, "Expected RETURN keyword"
  end

  local start_pos = self.position
  self.position = self.position + 7 -- Skip "RETURN "

  -- Get remaining content as value expression
  remaining = self.content:sub(self.position)
  local value = remaining:match("^(.-)$")

  return {
    type = "return_statement",
    value = value and value:match("^%s*(.-)%s*$") or nil, -- trim
    position = start_pos
  }
end

-- Full story parsing (WLS 1.0 .ws format)
-- Parses a complete story including metadata, variables, and passages
function WSParser:parse(input)
  local result = {
    success = true,
    story = {
      metadata = {},
      variables = {},
      passages = {},
      passage_by_name = {},
      start_passage_name = nil
    },
    errors = {},
    warnings = {}
  }

  if not input or input == "" then
    result.success = false
    table.insert(result.errors, "Empty input")
    return result
  end

  local lines = {}
  local line_positions = {} -- Track character position of each line
  local pos = 1
  for line in (input .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
    table.insert(line_positions, pos)
    pos = pos + #line + 1
  end

  local current_passage = nil
  local current_content = {}
  local in_vars_block = false
  local seen_passages = {} -- Track duplicate passages
  local i = 1

  while i <= #lines do
    local line = lines[i]
    local trimmed = line:match("^%s*(.-)%s*$")

    -- Check for passage marker first (ends @vars block, starts new passage)
    local passage_name = trimmed:match("^::%s*(.+)$")

    if passage_name then
      in_vars_block = false
      passage_name = passage_name:match("^%s*(.-)%s*$") -- trim

      -- Save previous passage
      if current_passage then
        current_passage.content = table.concat(current_content, "\n")
        current_passage.location.end_pos = line_positions[i] - 1
        current_passage.location["end"] = { line = i - 1, column = 1 }
        result.story.passages[current_passage.name] = current_passage
        result.story.passage_by_name[current_passage.name] = current_passage
      end

      -- Check for duplicate passage
      if seen_passages[passage_name] then
        table.insert(result.warnings, {
          code = "WLS-STR-001",
          message = "Duplicate passage: " .. passage_name,
          location = { line = i },
          suggestion = "Rename one of the passages to have a unique name"
        })
      end
      seen_passages[passage_name] = true

      -- Start new passage
      current_passage = {
        name = passage_name,
        tags = {},
        content = "",
        choices = {},
        gathers = {},
        tunnel_calls = {},
        has_tunnel_return = false,
        on_enter_script = nil,
        location = {
          line = i,
          start_pos = line_positions[i],
          end_pos = nil,
          start = { line = i, column = 1 },
          ["end"] = nil
        }
      }

      current_content = {}
      i = i + 1
      goto continue
    end

    -- Check for directives (@title:, @author:, @tags:, @onEnter:, etc.)
    local directive_name, directive_value = trimmed:match("^@([%w_]+):%s*(.*)$")
    if directive_name then
      if current_passage then
        -- Passage-level directives
        if directive_name == "tags" then
          for tag in directive_value:gmatch("([^,%s]+)") do
            table.insert(current_passage.tags, tag)
          end
        elseif directive_name == "onEnter" then
          current_passage.on_enter_script = directive_value
        end
      else
        -- Story-level directives
        if directive_name == "title" then
          result.story.metadata.title = directive_value
        elseif directive_name == "author" then
          result.story.metadata.author = directive_value
        elseif directive_name == "version" then
          result.story.metadata.version = directive_value
        elseif directive_name == "ifid" then
          result.story.metadata.ifid = directive_value
        elseif directive_name == "start" then
          result.story.start_passage_name = directive_value
        else
          result.story.metadata[directive_name] = directive_value
        end
      end
      i = i + 1
      goto continue
    end

    -- Check for @vars block start
    if trimmed == "@vars" then
      in_vars_block = true
      i = i + 1
      goto continue
    end

    -- Parse variable definitions in @vars block
    if in_vars_block and trimmed ~= "" then
      local var_name, var_value = trimmed:match("^([%w_]+):%s*(.+)$")
      if var_name then
        local parsed_value
        -- Parse value type
        if var_value:match("^%-?%d+%.?%d*$") then
          parsed_value = tonumber(var_value)
        elseif var_value == "true" then
          parsed_value = true
        elseif var_value == "false" then
          parsed_value = false
        elseif var_value:match('^"(.*)"$') then
          parsed_value = var_value:match('^"(.*)"$')
        else
          parsed_value = var_value
        end
        result.story.variables[var_name] = { value = parsed_value, name = var_name }
      end
      i = i + 1
      goto continue
    end

    -- Parse passage content
    if current_passage then
      -- Check for tunnel return: <-
      if trimmed == "<-" then
        current_passage.has_tunnel_return = true
        table.insert(current_content, line)
        i = i + 1
        goto continue
      end

      -- Check for tunnel call: -> Target ->
      local tunnel_target = trimmed:match("^%->%s*([%w_]+)%s*%->$")
      if tunnel_target then
        table.insert(current_passage.tunnel_calls, {
          target = tunnel_target,
          location = { line = i, start_pos = line_positions[i] }
        })
        table.insert(current_content, line)
        i = i + 1
        goto continue
      end

      -- Check for gather points: - or - - (spaced for depth)
      -- Match patterns like "- text" or "- - text" (spaced dashes for depth)
      local gather_content_check = trimmed:match("^%-[%s%-]*(.*)$")
      if gather_content_check and not trimmed:match("^%->") then
        -- Count depth by counting dashes (with optional spaces between)
        local depth = 0
        local rest = trimmed
        while rest:match("^%-%s*") do
          depth = depth + 1
          rest = rest:gsub("^%-%s*", "", 1)
        end
        if depth > 0 then
          table.insert(current_passage.gathers, {
            depth = depth,
            content = rest,
            location = { line = i, start_pos = line_positions[i] }
          })
          table.insert(current_content, line)
          i = i + 1
          goto continue
        end
      end

      -- Check for choices (with depth support)
      local choice_prefix = trimmed:match("^([%+%*]+)")
      if choice_prefix then
        local depth = #choice_prefix
        local choice_char = choice_prefix:sub(1, 1)
        local choice_type = (choice_char == "+") and "once" or "sticky"

        -- Match choice: +/* [text] -> Target or +/* [text]
        local rest = trimmed:sub(#choice_prefix + 1)
        local choice_text = rest:match("^%s*%[([^%]]+)%]")
        local choice_target = rest:match("%->%s*(.+)$")

        if choice_text then
          choice_target = choice_target and choice_target:match("^%s*(.-)%s*$") or nil
          table.insert(current_passage.choices, {
            choice_type = choice_type,
            text = choice_text,
            target = choice_target,
            depth = depth,
            location = {
              line = i,
              start_pos = line_positions[i],
              end_pos = line_positions[i] + #line,
              start = { line = i, column = 1 },
              ["end"] = { line = i, column = #line }
            }
          })
        end
        table.insert(current_content, line)
        i = i + 1
        goto continue
      end

      table.insert(current_content, line)
    end

    i = i + 1
    ::continue::
  end

  -- Save last passage
  if current_passage then
    current_passage.content = table.concat(current_content, "\n")
    current_passage.location.end_pos = #input
    current_passage.location["end"] = { line = #lines, column = 1 }
    result.story.passages[current_passage.name] = current_passage
    result.story.passage_by_name[current_passage.name] = current_passage
  end

  -- Set start passage if not specified
  if not result.story.start_passage_name then
    for name, _ in pairs(result.story.passage_by_name) do
      result.story.start_passage_name = name
      break
    end
  end

  -- Validate passage references
  for _, passage in pairs(result.story.passages) do
    -- Validate choice targets
    for _, choice in ipairs(passage.choices or {}) do
      if choice.target and choice.target ~= "END" and choice.target ~= "RESTART" and choice.target ~= "BACK" then
        if not result.story.passage_by_name[choice.target] then
          table.insert(result.warnings, {
            code = "WLS-REF-001",
            message = "Missing passage reference: " .. choice.target,
            passage = passage.name,
            location = choice.location,
            suggestion = "Create a passage named '" .. choice.target .. "' or fix the target name"
          })
        end
      end
    end

    -- Validate tunnel targets
    for _, tunnel in ipairs(passage.tunnel_calls or {}) do
      if tunnel.target and not result.story.passage_by_name[tunnel.target] then
        table.insert(result.warnings, {
          code = "WLS-REF-001",
          message = "Missing passage reference: " .. tunnel.target,
          passage = passage.name,
          location = tunnel.location,
          suggestion = "Create a passage named '" .. tunnel.target .. "' or fix the target name"
        })
      end
    end
  end

  -- Store for build_story
  self.last_parse_result = result

  return result
end

-- Build a Story object from the last parse result
-- Returns a Story-like object with metadata and passage access methods
function WSParser:build_story()
  if not self.last_parse_result then
    return nil
  end

  local story_data = self.last_parse_result.story
  local story = {
    metadata = story_data.metadata or {},
    passages = story_data.passages or {},
    passage_by_name = story_data.passage_by_name or {},
    variables = story_data.variables or {},
    start_passage_name = story_data.start_passage_name
  }

  -- Add get_passage_by_name method
  function story:get_passage_by_name(name)
    return self.passage_by_name[name]
  end

  -- Add get_start_passage method
  function story:get_start_passage()
    return self.passage_by_name[self.start_passage_name]
  end

  return story
end

return WSParser
