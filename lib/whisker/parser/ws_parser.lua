-- lib/whisker/parser/ws_parser.lua
-- WLS 2.0 Parser with Hook and Rich Text Support
-- GAP-016: @fallback directive support
-- GAP-017: @seed directive support
-- GAP-020: @set directive support
-- GAP-021: IFID validation

-- UUID module is optional for IFID validation
local UUID
pcall(function()
  UUID = require("whisker.utils.uuid")
end)

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

-- Parse markdown image: ![alt](src "title" width=X height=Y loading="lazy" class="..." id="...")
function WSParser:parse_markdown_image()
  local remaining = self.content:sub(self.position)

  -- Look for ![ pattern
  if not remaining:match("^!%[") then
    return nil
  end

  -- Parse ![alt](src...)
  local alt, inner = remaining:match("^!%[(.-)%]%((.-)%)")
  if not alt or not inner then
    return nil
  end

  local start_pos = self.position
  local full_match = remaining:match("^!%[.-%]%(.-%)")
  self.position = self.position + #full_match

  -- Parse inner content: src "title" attr=value ...
  -- First extract src (up to first space or quote after src)
  local clean_src = inner
  local title = nil
  local rest = ""

  -- Try to match src followed by optional title in quotes
  local src_part, title_part, rest_part = inner:match('^(%S+)%s+"([^"]+)"%s*(.*)$')
  if src_part and title_part then
    clean_src = src_part
    title = title_part
    rest = rest_part or ""
  else
    -- Try src followed by title in single quotes
    src_part, title_part, rest_part = inner:match("^(%S+)%s+'([^']+)'%s*(.*)$")
    if src_part and title_part then
      clean_src = src_part
      title = title_part
      rest = rest_part or ""
    else
      -- Try just src followed by attributes
      src_part, rest_part = inner:match("^(%S+)%s+(.*)$")
      if src_part then
        clean_src = src_part
        rest = rest_part or ""
      end
    end
  end

  -- Remove quotes from src if present
  clean_src = clean_src:match('^"(.-)"$') or clean_src:match("^'(.-)'$") or clean_src

  -- Parse additional attributes: key=value or key="value"
  local attributes = {
    width = nil,
    height = nil,
    loading = nil,
    class = nil,
    id = nil
  }

  for key, value in rest:gmatch('([%w%-_]+)%s*=%s*"?([^%s"]+)"?') do
    -- Remove quotes from value if present
    value = value:match('^"(.-)"$') or value:match("^'(.-)'$") or value

    if key == "width" or key == "height" then
      attributes[key] = tonumber(value) or value
    else
      attributes[key] = value
    end
  end

  return {
    type = "image",
    alt = alt,
    src = clean_src:match("^%s*(.-)%s*$"), -- trim
    title = title,
    width = attributes.width,
    height = attributes.height,
    loading = attributes.loading,
    class = attributes.class,
    id = attributes.id,
    position = start_pos
  }
end

-- Parse directive-based media: @image(src), @video(src), @embed(url), @audio(src)
function WSParser:parse_media_directive()
  local remaining = self.content:sub(self.position)

  -- Look for @image, @video, @embed, or @audio pattern
  local directive_type = remaining:match("^@(image)%(")
  if not directive_type then
    directive_type = remaining:match("^@(video)%(")
  end
  if not directive_type then
    directive_type = remaining:match("^@(embed)%(")
  end
  if not directive_type then
    directive_type = remaining:match("^@(audio)%(")
  end

  if not directive_type then
    return nil
  end

  local start_pos = self.position

  -- Find matching closing paren (handle nested parens)
  local paren_start = remaining:find("%(")
  local paren_depth = 1
  local paren_end = paren_start + 1

  while paren_end <= #remaining and paren_depth > 0 do
    local char = remaining:sub(paren_end, paren_end)
    if char == "(" then paren_depth = paren_depth + 1
    elseif char == ")" then paren_depth = paren_depth - 1
    end
    paren_end = paren_end + 1
  end

  local content = remaining:sub(paren_start + 1, paren_end - 2)

  -- Parse src (quoted or unquoted)
  local src, attrs_str = content:match('^"([^"]+)"(.*)$')
  if not src then
    src, attrs_str = content:match("^'([^']+)'(.*)$")
  end
  if not src then
    -- Unquoted src: take until first comma or end
    local first_part = content:match("^([^,]+)")
    if first_part then
      src = first_part:match("^%s*(.-)%s*$")
      attrs_str = content:sub(#first_part + 1)
    else
      src = content
      attrs_str = ""
    end
  end
  attrs_str = attrs_str or ""

  -- Parse attributes: key: value or key=value
  local attributes = {}
  -- Match both key: value and key=value patterns
  for key, value in attrs_str:gmatch(",?%s*([%w_%-]+)%s*[:=]%s*([^,]+)") do
    key = key:match("^%s*(.-)%s*$")
    value = value:match("^%s*(.-)%s*$")
    -- Remove quotes from value if present
    value = value:match('^"(.-)"$') or value:match("^'(.-)'$") or value
    if value == "true" then value = true
    elseif value == "false" then value = false
    elseif tonumber(value) then value = tonumber(value)
    end
    attributes[key] = value
  end

  self.position = self.position + paren_end - 1

  local clean_src = src:match("^%s*(.-)%s*$") -- trim

  -- Build node based on directive type
  if directive_type == "audio" then
    return {
      type = "audio",
      src = clean_src,
      autoplay = attributes.autoplay or false,
      loop = attributes.loop or false,
      controls = attributes.controls ~= false, -- default true
      volume = attributes.volume or 1.0,
      muted = attributes.muted or false,
      position = start_pos
    }
  elseif directive_type == "video" then
    return {
      type = "video",
      src = clean_src,
      width = attributes.width,
      height = attributes.height,
      autoplay = attributes.autoplay or false,
      loop = attributes.loop or false,
      muted = attributes.muted or false,
      controls = attributes.controls ~= false, -- default true
      poster = attributes.poster,
      position = start_pos
    }
  elseif directive_type == "embed" then
    return {
      type = "embed",
      url = clean_src,
      width = attributes.width or 560,
      height = attributes.height or 315,
      sandbox = attributes.sandbox ~= false, -- default true for security
      allow = attributes.allow or "",
      title = attributes.title or "Embedded content",
      loading = attributes.loading or "lazy",
      position = start_pos
    }
  else
    -- image (default)
    return {
      type = "image",
      src = clean_src,
      alt = attributes.alt or "",
      title = attributes.title,
      width = attributes.width,
      height = attributes.height,
      loading = attributes.loading,
      class = attributes.class,
      id = attributes.id,
      position = start_pos
    }
  end
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
    local remaining = self.content:sub(self.position)

    -- Check if we're at the start of a hook definition or operation
    if remaining:match("^|%w+>%[") or remaining:match("^@%w+:%s*%w+%s*{") then
      break
    end

    -- Check if we're at the start of formatting markers
    -- Bold: **
    if remaining:match("^%*%*") then
      break
    end
    -- Strikethrough: ~~
    if remaining:match("^~~") then
      break
    end
    -- Underline: __
    if remaining:match("^__") then
      break
    end
    -- Inline code: ` (but not ```)
    if remaining:match("^`[^`]") then
      break
    end
    -- Code fence: ```
    if remaining:match("^```") then
      break
    end
    -- Italic: * (but not **)
    if remaining:match("^%*[^%*]") then
      break
    end

    local char = self.content:sub(self.position, self.position)
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
-- WLS 1.0 GAP-033: Escaped Brackets Support in Choices
-- ============================================================================

--- Parse choice text with support for escaped brackets
-- Scans for matching closing bracket while respecting \[ and \] escapes
-- @param text string The text starting after the choice prefix (e.g., after + or *)
-- @return string|nil The extracted choice text (with escapes still present)
-- @return string|nil The remaining text after the closing bracket
function WSParser:parse_choice_text_with_escapes(text)
  -- Skip whitespace and find opening bracket
  local ws, bracket_start = text:match("^(%s*)%[")
  if not ws then
    -- Fallback to simple pattern for backwards compatibility
    local simple_text = text:match("^%s*%[([^%]]+)%]")
    if simple_text then
      local after_bracket = text:match("^%s*%[[^%]]+%](.*)$")
      return simple_text, after_bracket
    end
    return nil, nil
  end

  local start_pos = #ws + 2  -- After whitespace and opening [
  local pos = start_pos
  local depth = 1
  local in_escape = false
  local chars = {}

  while pos <= #text and depth > 0 do
    local char = text:sub(pos, pos)

    if in_escape then
      -- Previous char was backslash, include this char literally
      table.insert(chars, char)
      in_escape = false
    elseif char == "\\" then
      -- Escape character - include it, mark next char as escaped
      table.insert(chars, char)
      in_escape = true
    elseif char == "[" then
      -- Non-escaped opening bracket - this actually adds to depth
      -- for nested brackets (e.g., [[inner]])
      depth = depth + 1
      table.insert(chars, char)
    elseif char == "]" then
      depth = depth - 1
      if depth > 0 then
        table.insert(chars, char)
      end
      -- If depth == 0, we found the closing bracket, don't include it
    else
      table.insert(chars, char)
    end

    pos = pos + 1
  end

  if depth == 0 then
    local choice_text = table.concat(chars)
    local remaining = text:sub(pos)
    return choice_text, remaining
  end

  -- Malformed - no closing bracket found
  return nil, nil
end

-- ============================================================================
-- Module System Parsing (WLS Chapter 12)
-- Implements GAP-045 (Qualified Names) and GAP-046 (Nested Namespaces)
-- ============================================================================

--- GAP-045: Parse a qualified name (identifier.identifier.identifier)
-- @return table|nil A qualified name AST node with parts, full_name, namespace, and name
function WSParser:parse_qualified_name()
    local remaining = self.content:sub(self.position)

    -- Match identifier.identifier... pattern
    local full_name = remaining:match("^([%w_]+%.[%w_%.]+)")
    if not full_name then
        return nil
    end

    local start_pos = self.position
    self.position = self.position + #full_name

    -- Split into parts
    local parts = {}
    for part in full_name:gmatch("([%w_]+)") do
        table.insert(parts, part)
    end

    return {
        type = "qualified_name",
        parts = parts,
        full_name = full_name,
        namespace = table.concat(parts, ".", 1, #parts - 1),
        name = parts[#parts],
        position = start_pos
    }
end

--- GAP-046: Parse a NAMESPACE block with support for nested namespaces
-- @param parent_namespace string|nil The parent namespace path
-- @return table|nil A namespace AST node
function WSParser:parse_namespace_block(parent_namespace)
    local remaining = self.content:sub(self.position)

    -- Match NAMESPACE name
    local name = remaining:match("^NAMESPACE[ \t]+(%w+)")
    if not name then
        return nil
    end

    local start_pos = self.position
    self.position = self.position + #("NAMESPACE " .. name)

    -- Skip trailing whitespace/newline
    remaining = self.content:sub(self.position)
    local ws = remaining:match("^([ \t]*\n?)")
    if ws then
        self.position = self.position + #ws
    end

    local namespace = {
        type = "namespace_declaration",
        name = name,
        full_name = parent_namespace and (parent_namespace .. "." .. name) or name,
        parent = parent_namespace,
        passages = {},
        functions = {},
        nested_namespaces = {},
        position = start_pos
    }

    -- Parse content until END NAMESPACE
    while self.position <= #self.content do
        remaining = self.content:sub(self.position)

        -- Skip whitespace/newlines
        local leading_ws = remaining:match("^([ \t\n]+)")
        if leading_ws then
            self.position = self.position + #leading_ws
            remaining = self.content:sub(self.position)
        end

        -- Check for END NAMESPACE
        if remaining:match("^END%s+NAMESPACE") then
            local end_match = remaining:match("^END%s+NAMESPACE")
            self.position = self.position + #end_match
            break
        end

        -- Check for nested NAMESPACE
        if remaining:match("^NAMESPACE%s+%w+") then
            local nested = self:parse_namespace_block(namespace.full_name)
            if nested then
                namespace.nested_namespaces[nested.name] = nested
            end
            goto ns_continue
        end

        -- Check for passage (::)
        local passage_name = remaining:match("^::%s*([%w_]+)")
        if passage_name then
            local passage = self:parse_passage_in_namespace(namespace.full_name)
            if passage then
                namespace.passages[passage.name] = passage
            end
            goto ns_continue
        end

        -- Check for FUNCTION
        if remaining:match("^FUNCTION%s+%w+") then
            local func = self:parse_function_in_namespace(namespace.full_name)
            if func then
                namespace.functions[func.name] = func
            end
            goto ns_continue
        end

        -- Skip any other content (single character at a time to avoid infinite loop)
        if self.position <= #self.content then
            self.position = self.position + 1
        end

        ::ns_continue::
    end

    return namespace
end

--- GAP-046: Parse a passage within a namespace context
-- @param namespace_path string The full namespace path
-- @return table|nil A passage AST node
function WSParser:parse_passage_in_namespace(namespace_path)
    local remaining = self.content:sub(self.position)

    -- Match :: PassageName
    local passage_name = remaining:match("^::%s*([%w_]+)")
    if not passage_name then
        return nil
    end

    local start_pos = self.position
    self.position = self.position + #"::" + #(passage_name:match("^%s*") or "") + #passage_name

    -- Skip optional whitespace after name
    remaining = self.content:sub(self.position)
    local ws = remaining:match("^([ \t]*)")
    if ws then
        self.position = self.position + #ws
    end

    -- Collect content until next passage, function, namespace, or END NAMESPACE
    local content_parts = {}
    while self.position <= #self.content do
        remaining = self.content:sub(self.position)

        -- Check for end markers
        if remaining:match("^::%s*%w+") or
           remaining:match("^FUNCTION%s+%w+") or
           remaining:match("^NAMESPACE%s+%w+") or
           remaining:match("^END%s+NAMESPACE") then
            break
        end

        -- Add character to content
        table.insert(content_parts, self.content:sub(self.position, self.position))
        self.position = self.position + 1
    end

    return {
        type = "passage",
        name = passage_name,
        qualified_name = namespace_path .. "." .. passage_name,
        namespace = namespace_path,
        content = table.concat(content_parts),
        position = start_pos
    }
end

--- GAP-046: Parse a function within a namespace context
-- @param namespace_path string The full namespace path
-- @return table|nil A function AST node
function WSParser:parse_function_in_namespace(namespace_path)
    local remaining = self.content:sub(self.position)

    -- Match FUNCTION name
    local func_name = remaining:match("^FUNCTION%s+(%w+)")
    if not func_name then
        return nil
    end

    local start_pos = self.position
    self.position = self.position + #("FUNCTION " .. func_name)

    remaining = self.content:sub(self.position)

    -- Parse optional parameters
    local params = {}
    if remaining:match("^%s*%(") then
        local ws_paren = remaining:match("^(%s*)%(")
        self.position = self.position + #ws_paren + 1
        remaining = self.content:sub(self.position)

        -- Parse parameters until closing paren
        while not remaining:match("^%)") and self.position <= #self.content do
            local ws_before = remaining:match("^(%s*)")
            if ws_before then
                self.position = self.position + #ws_before
                remaining = self.content:sub(self.position)
            end

            local param = remaining:match("^(%w+)")
            if param then
                table.insert(params, { name = param })
                self.position = self.position + #param
                remaining = self.content:sub(self.position)
            end

            local sep = remaining:match("^([%s,]*)")
            if sep then
                self.position = self.position + #sep
                remaining = self.content:sub(self.position)
            end

            if remaining:match("^%)") then
                break
            end
        end

        if remaining:match("^%)") then
            self.position = self.position + 1
        end
    end

    -- Collect body until END
    local body_parts = {}
    while self.position <= #self.content do
        remaining = self.content:sub(self.position)

        -- Check for END (but not END NAMESPACE)
        if remaining:match("^END%s*$") or remaining:match("^END[%s\n]") then
            if not remaining:match("^END%s+NAMESPACE") then
                local end_match = remaining:match("^END[%s\n]*") or "END"
                self.position = self.position + #end_match
                break
            end
        end

        table.insert(body_parts, self.content:sub(self.position, self.position))
        self.position = self.position + 1
    end

    return {
        type = "function_declaration",
        name = func_name,
        qualified_name = namespace_path .. "." .. func_name,
        namespace = namespace_path,
        params = params,
        body = table.concat(body_parts):match("^%s*(.-)%s*$"),  -- Trim
        position = start_pos
    }
end

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

-- Process an INCLUDE and load the referenced file
-- @param include_path string The path from the INCLUDE statement
-- @param location table|nil Source location for error reporting
-- @return table|nil The included story content
-- @return string|nil Error message if loading failed
function WSParser:process_include(include_path, location)
  if not self.modules_runtime then
    return nil, "No modules runtime configured for include processing"
  end

  local module_content, err = self.modules_runtime:load_include(
    include_path,
    self.current_file,
    location
  )

  if not module_content then
    return nil, err
  end

  return module_content
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
        -- GAP-016: Passage-level fallback
        elseif directive_name == "fallback" then
          current_passage.fallback = directive_value:match("^%s*(.-)%s*$")  -- trim
        end
      else
        -- Story-level directives
        if directive_name == "title" then
          result.story.metadata.title = directive_value
        elseif directive_name == "author" then
          result.story.metadata.author = directive_value
        elseif directive_name == "version" then
          result.story.metadata.version = directive_value
        -- GAP-021: IFID with validation
        elseif directive_name == "ifid" then
          local ifid = directive_value:match("^%s*(.-)%s*$")  -- trim
          -- Normalize to uppercase
          ifid = UUID.normalize(ifid)
          -- Validate format
          if UUID.is_valid(ifid) then
            result.story.metadata.ifid = ifid
          else
            table.insert(result.warnings, {
              code = "WLS-META-001",
              message = "Invalid IFID format: " .. directive_value,
              location = { line = i },
              suggestion = "Use UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
            })
            -- Store anyway but mark as invalid
            result.story.metadata.ifid = directive_value
            result.story.metadata.ifid_invalid = true
          end
        elseif directive_name == "start" then
          result.story.start_passage_name = directive_value
        -- GAP-017: Random seed directive
        elseif directive_name == "seed" then
          local seed_value = directive_value:match("^%s*(.-)%s*$")  -- trim
          -- Try to parse as number
          local num_seed = tonumber(seed_value)
          if num_seed then
            result.story.random_seed = num_seed
          else
            -- Remove quotes if present and keep as string (will be hashed)
            seed_value = seed_value:match('^"(.-)"$') or seed_value:match("^'(.-)'$") or seed_value
            result.story.random_seed = seed_value
          end
        -- GAP-016: Story-level default fallback
        elseif directive_name == "fallback" then
          result.story.default_fallback = directive_value:match("^%s*(.-)%s*$")  -- trim
        elseif directive_name == "theme" then
          -- Parse theme(s) - can be comma-separated
          local themes = {}
          for theme in directive_value:gmatch("([^,]+)") do
            theme = theme:match("^%s*(.-)%s*$")  -- trim
            -- Remove quotes if present
            theme = theme:match('^"(.-)"$') or theme:match("^'(.-)'$") or theme
            table.insert(themes, theme)
          end
          result.story.metadata.themes = themes
        else
          result.story.metadata[directive_name] = directive_value
        end
      end
      i = i + 1
      goto continue
    end

    -- GAP-020: Check for @set directive (story-level settings)
    local set_key, set_value = trimmed:match("^@set%s+([%w_]+)%s*=%s*(.+)$")
    if set_key and not current_passage then
      -- Initialize settings if needed
      if not result.story.settings then
        result.story.settings = {}
      end

      -- Parse value type
      local parsed_value
      set_value = set_value:match("^%s*(.-)%s*$")  -- trim
      if set_value == "true" then
        parsed_value = true
      elseif set_value == "false" then
        parsed_value = false
      elseif tonumber(set_value) then
        parsed_value = tonumber(set_value)
      elseif set_value:match('^"(.-)"$') then
        parsed_value = set_value:match('^"(.-)"$')
      elseif set_value:match("^'(.-)'$") then
        parsed_value = set_value:match("^'(.-)'$")
      else
        parsed_value = set_value
      end

      result.story.settings[set_key] = parsed_value
      i = i + 1
      goto continue
    end

    -- Check for @style block start
    if trimmed:match("^@style%s*{") or trimmed == "@style {" then
      -- Parse entire style block - find matching closing brace
      local style_content = {}
      local brace_depth = 1
      -- Check if opening brace is on same line
      local inline_content = trimmed:match("^@style%s*{(.*)$")
      if inline_content and inline_content ~= "" then
        -- Count braces in inline content
        for c in inline_content:gmatch(".") do
          if c == "{" then brace_depth = brace_depth + 1
          elseif c == "}" then brace_depth = brace_depth - 1
          end
        end
        if brace_depth > 0 then
          table.insert(style_content, inline_content)
        else
          -- Closing brace was on same line
          local css = inline_content:match("^(.-)%}%s*$") or inline_content
          if not result.story.metadata.custom_styles then
            result.story.metadata.custom_styles = {}
          end
          table.insert(result.story.metadata.custom_styles, css)
          i = i + 1
          goto continue
        end
      end

      i = i + 1
      while i <= #lines and brace_depth > 0 do
        local style_line = lines[i]
        for c in style_line:gmatch(".") do
          if c == "{" then brace_depth = brace_depth + 1
          elseif c == "}" then brace_depth = brace_depth - 1
          end
        end
        if brace_depth > 0 then
          table.insert(style_content, style_line)
        else
          -- Last line may have content before closing brace
          local final_content = style_line:match("^(.-)%}") or ""
          if final_content ~= "" then
            table.insert(style_content, final_content)
          end
        end
        i = i + 1
      end

      if not result.story.metadata.custom_styles then
        result.story.metadata.custom_styles = {}
      end
      table.insert(result.story.metadata.custom_styles, table.concat(style_content, "\n"))
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

        -- GAP-033: Handle escaped brackets in choice text
        -- Use bracket-counting approach that skips escaped brackets
        local choice_text, remaining = self:parse_choice_text_with_escapes(rest)
        local choice_target = remaining and remaining:match("%->%s*(.+)$")

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
