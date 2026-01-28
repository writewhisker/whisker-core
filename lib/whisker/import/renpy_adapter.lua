--- Ren'Py Import Adapter
-- Imports Ren'Py visual novel script files (.rpy)
--
-- @module whisker.import.renpy_adapter
-- @author Whisker Team
-- @license MIT

local RenpyAdapter = {}

RenpyAdapter.name = "renpy"
RenpyAdapter.formats = {"rpy"}

--- Detect if data is a Ren'Py script
-- @param data string File content
-- @return boolean is_renpy True if Ren'Py format detected
function RenpyAdapter.detect(data)
  -- Check for Ren'Py markers
  if data:match("label%s+[%w_]+:") then
    return true
  end
  
  if data:match("define%s+[%w_]+%s*=") then
    return true
  end
  
  if data:match("menu:") or data:match("scene%s+") or data:match("show%s+") then
    return true
  end
  
  return false
end

--- Tokenize Ren'Py script
-- @param data string Script content
-- @return table tokens Array of tokens
local function tokenize(data)
  local tokens = {}
  local line_num = 0
  
  for line in data:gmatch("([^\n]*)\n?") do
    line_num = line_num + 1

    repeat
      -- Skip empty lines and comments
      if line:match("^%s*$") or line:match("^%s*#") then
        break
      end

      -- Calculate indentation
      local indent = 0
      for _ in line:gmatch("^%s") do
        indent = indent + 1
      end

      -- Trim line
      local trimmed = line:match("^%s*(.-)%s*$")

      table.insert(tokens, {
        line = line_num,
        indent = indent,
        content = trimmed
      })
    until true
  end
  
  return tokens
end

--- Parse Ren'Py script
-- @param data string Script content
-- @param options table Parse options
-- @return table ir Intermediate representation
function RenpyAdapter.parse(data, options)
  options = options or {}
  
  local ir = {
    format = "renpy",
    version = nil,
    metadata = {
      title = "Untitled",
      author = nil
    },
    passages = {},
    variables = {},
    characters = {},
    custom = {
      images = {},
      audio = {},
      transitions = {}
    }
  }
  
  local tokens = tokenize(data)
  local current_label = nil
  local current_menu = nil
  local base_indent = 0
  
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    local content = token.content
    
    -- Parse define statement (character or variable)
    if content:match("^define%s+") then
      local var_name, value = content:match("^define%s+([%w_]+)%s*=%s*(.+)$")
      if var_name then
        -- Check if it's a Character definition
        if value:match("Character%(") then
          local char_name = value:match('Character%("([^"]+)"')
          ir.characters[var_name] = char_name or var_name
        else
          -- Regular variable
          ir.variables[var_name] = value
        end
      end
    
    -- Parse label (new passage)
    elseif content:match("^label%s+") then
      local label_name = content:match("^label%s+([%w_]+):")
      if label_name then
        current_label = {
          id = label_name,
          name = label_name,
          content = "",
          tags = {},
          choices = {},
          position = { x = 0, y = 0 },
          metadata = {}
        }
        table.insert(ir.passages, current_label)
        base_indent = token.indent
      end
    
    -- Parse menu
    elseif content == "menu:" and current_label then
      current_menu = {
        choices = {}
      }
      base_indent = token.indent
    
    -- Parse menu choice
    elseif content:match('^".-":$') and current_menu then
      local choice_text = content:match('^"(.-)":$')
      local choice = {
        text = choice_text,
        target = nil,
        content = ""
      }
      current_menu.choices[#current_menu.choices + 1] = choice
      
      -- Look ahead for jump/call
      local j = i + 1
      while j <= #tokens and tokens[j].indent > token.indent do
        local next_content = tokens[j].content
        
        if next_content:match("^jump%s+") then
          choice.target = next_content:match("^jump%s+([%w_]+)")
          break
        elseif next_content:match("^call%s+") then
          choice.target = next_content:match("^call%s+([%w_]+)")
          choice.is_call = true
          break
        else
          -- Add to choice content
          choice.content = choice.content .. next_content .. "\n"
        end
        
        j = j + 1
      end
    
    -- Parse dialogue
    elseif content:match('^[%w_]+%s+".-"') and current_label then
      local char, text = content:match('^([%w_]+)%s+"(.-)"')
      if char and text then
        local char_name = ir.characters[char] or char
        current_label.content = current_label.content .. 
          string.format("%s: %s\n\n", char_name, text)
      end
    
    -- Parse narration (quoted text without character)
    elseif content:match('^".-"') and current_label then
      local text = content:match('^"(.-)"')
      current_label.content = current_label.content .. text .. "\n\n"
    
    -- Parse jump statement
    elseif content:match("^jump%s+") and current_label then
      local target = content:match("^jump%s+([%w_]+)")
      table.insert(current_label.choices, {
        text = "(Continue)",
        target = target
      })
    
    -- Parse return statement (end of label)
    elseif content == "return" then
      if current_menu and current_label then
        -- Add menu choices to current label
        for _, choice in ipairs(current_menu.choices) do
          table.insert(current_label.choices, choice)
        end
        current_menu = nil
      end
      current_label = nil
    
    -- Parse scene/show/hide commands (store as metadata)
    elseif content:match("^scene%s+") or content:match("^show%s+") or content:match("^hide%s+") then
      if current_label then
        current_label.content = current_label.content .. 
          string.format("(%s)\n\n", content)
      end
    
    -- Parse with statement (transitions)
    elseif content:match("^with%s+") then
      local transition = content:match("^with%s+([%w_]+)")
      if transition then
        table.insert(ir.custom.transitions, transition)
      end
    end
    
    i = i + 1
  end
  
  -- If no title was set, try to infer from first label
  if ir.metadata.title == "Untitled" and #ir.passages > 0 then
    ir.metadata.title = ir.passages[1].name
  end
  
  return ir
end

--- Validate Ren'Py intermediate representation
-- @param ir table Intermediate representation
-- @return table result Validation result
function RenpyAdapter.validate(ir)
  local errors = {}
  local warnings = {}
  
  if not ir.passages or #ir.passages == 0 then
    table.insert(errors, "Script has no labels (passages)")
  end
  
  -- Check for start label
  local has_start = false
  for _, passage in ipairs(ir.passages or {}) do
    if passage.id == "start" or passage.id == "main" then
      has_start = true
      break
    end
  end
  
  if not has_start and #(ir.passages or {}) > 0 then
    table.insert(warnings, "No 'start' or 'main' label found, will use first label")
  end
  
  -- Check for orphaned labels
  local targets = {}
  for _, passage in ipairs(ir.passages or {}) do
    for _, choice in ipairs(passage.choices or {}) do
      if choice.target then
        targets[choice.target] = true
      end
    end
  end
  
  return {
    valid = #errors == 0,
    errors = errors,
    warnings = warnings
  }
end

--- Transform intermediate representation to whisker story
-- @param ir table Intermediate representation
-- @return table story Whisker story object
function RenpyAdapter.transform(ir)
  local story = {
    id = string.format("renpy-%d", os.time()),
    title = ir.metadata.title,
    metadata = {
      title = ir.metadata.title,
      author = ir.metadata.author,
      format = "renpy",
      characters = ir.characters
    },
    passages = {},
    variables = {},
    tags = {}
  }
  
  -- Determine start passage
  local start_id = nil
  for _, passage in ipairs(ir.passages) do
    if passage.id == "start" or passage.id == "main" then
      start_id = passage.id
      break
    end
  end
  
  if not start_id and #ir.passages > 0 then
    start_id = ir.passages[1].id
  end
  
  story.start_passage = start_id
  
  -- Transform variables
  for name, value in pairs(ir.variables) do
    story.variables[name] = {
      type = "any",
      default = value
    }
  end
  
  -- Transform passages
  for _, ir_passage in ipairs(ir.passages) do
    local passage = {
      id = ir_passage.id,
      name = ir_passage.name,
      content = ir_passage.content:match("^%s*(.-)%s*$") or "", -- Trim
      tags = ir_passage.tags,
      choices = ir_passage.choices,
      position = ir_passage.position,
      metadata = ir_passage.metadata
    }
    
    table.insert(story.passages, passage)
  end
  
  return story
end

return RenpyAdapter
