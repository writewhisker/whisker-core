-- lib/whisker/parser/ws_parser.lua
-- WLS 2.0 Parser with Hook Support

local WSParser = {}
WSParser.__index = WSParser

-- Hook pattern constants
local HOOK_DEFINITION_PATTERN = "|(%w+)>%[(.-)%]"
local HOOK_OPERATION_PATTERN = "@(%w+):%s*(%w+)%s*{(.-)}"

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

return WSParser
