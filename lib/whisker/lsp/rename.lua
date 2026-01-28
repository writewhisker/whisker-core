--- LSP Rename Provider
-- Provides rename refactoring for WLS documents
-- @module whisker.lsp.rename
-- @author Whisker Core Team
-- @license MIT

local Rename = {}
Rename.__index = Rename
Rename._dependencies = {}

-- Reserved words that cannot be used as names
local RESERVED_WORDS = {
  INCLUDE = true,
  NAMESPACE = true,
  FUNCTION = true,
  END = true,
  RETURN = true,
  LIST = true,
  ARRAY = true,
  MAP = true,
  VAR = true,
  ["true"] = true,
  ["false"] = true,
  ["nil"] = true,
  BACK = true,
  RESTART = true
}

-- Reserved prefixes that cannot be used
local RESERVED_PREFIXES = { "whisker_", "wls_", "__" }

--- Create a new rename provider
-- @param options table Options with documents manager and navigation
-- @return Rename Provider instance
function Rename.new(options)
  options = options or {}
  local self = setmetatable({}, Rename)
  self._documents = options.documents
  self._navigation = options.navigation
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function Rename:set_parser(parser)
  self._parser = parser
end

--- Prepare rename - validate position and return placeholder
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return table|nil Prepare rename result with range and placeholder
function Rename:prepare_rename(uri, line, character)
  local doc = self._documents:get(uri)
  if not doc then
    return nil
  end

  -- Get word at position
  local word, range = self:_get_word_at_position(doc, line, character)
  if not word then
    return nil
  end

  -- Determine if this is a renameable symbol
  local symbol_type = self:_get_symbol_type(doc, line, character, word)
  if not symbol_type then
    return nil
  end

  -- Return the range and placeholder text
  return {
    range = range,
    placeholder = word
  }
end

--- Execute rename - find all references and create edits
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @param new_name string New name for the symbol
-- @return table|nil Workspace edit with changes
-- @return table|nil Error if validation fails
function Rename:do_rename(uri, line, character, new_name)
  local doc = self._documents:get(uri)
  if not doc then
    return nil
  end

  -- Validate new name
  local valid, err = self:_validate_name(new_name)
  if not valid then
    return nil, { code = -32602, message = err }
  end

  -- Get current word
  local word = self:_get_word_at_position(doc, line, character)
  if not word then
    return nil
  end

  -- Find all references
  local symbol_type = self:_get_symbol_type(doc, line, character, word)
  if not symbol_type then
    return nil, { code = -32602, message = "Cannot rename this symbol" }
  end

  local refs = self:_find_all_references(uri, word, symbol_type)

  -- Create text edits
  local changes = {}
  for _, ref in ipairs(refs) do
    if not changes[ref.uri] then
      changes[ref.uri] = {}
    end
    table.insert(changes[ref.uri], {
      range = ref.range,
      newText = new_name
    })
  end

  return {
    changes = changes
  }
end

--- Get word at position with range
-- @param doc table Document
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return string|nil Word
-- @return table|nil Range
function Rename:_get_word_at_position(doc, line, character)
  local content = doc.content or ""
  local lines = {}
  for l in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, l)
  end

  local line_text = lines[line + 1] or ""

  -- Find word boundaries (1-based positions)
  local word_start = character + 1
  local word_end = character + 1

  -- Search backwards for word start
  while word_start > 1 do
    local char = line_text:sub(word_start - 1, word_start - 1)
    if char:match("[%w_]") then
      word_start = word_start - 1
    else
      break
    end
  end

  -- Search forwards for word end
  while word_end <= #line_text do
    local char = line_text:sub(word_end, word_end)
    if char:match("[%w_]") then
      word_end = word_end + 1
    else
      break
    end
  end

  local word = line_text:sub(word_start, word_end - 1)
  if word == "" then
    return nil
  end

  local range = {
    start = { line = line, character = word_start - 1 },
    ["end"] = { line = line, character = word_end - 1 }
  }

  return word, range
end

--- Determine symbol type from context
-- @param doc table Document
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @param word string Word at position
-- @return string|nil Symbol type: "passage", "variable", "function", or "hook"
function Rename:_get_symbol_type(doc, line, character, word)
  local content = doc.content or ""
  local lines = {}
  for l in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, l)
  end

  local line_text = lines[line + 1] or ""

  -- Check for passage definition: :: Name
  if line_text:match("^%s*::%s*" .. word) then
    return "passage"
  end

  -- Check for passage reference: -> Name
  if line_text:match("->%s*" .. word) then
    return "passage"
  end

  -- Check for function definition: FUNCTION name
  if line_text:match("^%s*FUNCTION%s+" .. word) then
    return "function"
  end

  -- Check for function call: name(
  if line_text:match(word .. "%s*%(") then
    return "function"
  end

  -- Check for variable: $name or in VAR declaration
  if line_text:match("%$" .. word) or line_text:match("^%s*VAR%s+" .. word) then
    return "variable"
  end

  -- Check for hook: |name>
  if line_text:match("|" .. word .. ">") then
    return "hook"
  end

  -- Default: check if it's a passage name anywhere
  for _, l in ipairs(lines) do
    if l:match("^%s*::%s*" .. word) then
      return "passage"
    end
  end

  return nil
end

--- Find all references for a symbol
-- @param uri string Document URI
-- @param name string Symbol name
-- @param symbol_type string Symbol type
-- @return table Array of locations
function Rename:_find_all_references(uri, name, symbol_type)
  if symbol_type == "passage" then
    return self:_find_passage_references(uri, name)
  elseif symbol_type == "variable" then
    return self:_find_variable_references(uri, name)
  elseif symbol_type == "function" then
    return self:_find_function_references(uri, name)
  elseif symbol_type == "hook" then
    return self:_find_hook_references(uri, name)
  end

  return {}
end

--- Find all passage references
-- @param uri string Document URI
-- @param passage_name string Passage name
-- @return table Array of locations
function Rename:_find_passage_references(uri, passage_name)
  local references = {}
  local doc = self._documents:get(uri)
  if not doc then return references end

  local content = doc.content or ""
  local line_num = 0
  local escaped_name = passage_name:gsub("([^%w_])", "%%%1")

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    -- Definition: :: PassageName
    if line:match("^%s*::%s*" .. escaped_name .. "%s*$") or
       line:match("^%s*::%s*" .. escaped_name .. "%[") or
       line:match("^%s*::%s*" .. escaped_name .. "%s+") then
      local name_start = line:find(passage_name, 1, true)
      if name_start then
        table.insert(references, {
          uri = uri,
          range = {
            start = { line = line_num, character = name_start - 1 },
            ["end"] = { line = line_num, character = name_start - 1 + #passage_name }
          }
        })
      end
    end

    -- Navigation: -> PassageName
    local pos = 1
    while true do
      local arrow_start = line:find("->%s*" .. escaped_name .. "%f[^%w_]", pos)
      if not arrow_start then break end
      local name_start = line:find(passage_name, arrow_start, true)
      if name_start then
        table.insert(references, {
          uri = uri,
          range = {
            start = { line = line_num, character = name_start - 1 },
            ["end"] = { line = line_num, character = name_start - 1 + #passage_name }
          }
        })
      end
      pos = (arrow_start or 0) + 2
      if pos > #line then break end
    end

    -- visited() call
    pos = 1
    while true do
      local visit_start = line:find("visited%s*%(%s*[\"']" .. escaped_name .. "[\"']", pos)
      if not visit_start then break end
      local name_start = line:find(passage_name, visit_start, true)
      if name_start then
        table.insert(references, {
          uri = uri,
          range = {
            start = { line = line_num, character = name_start - 1 },
            ["end"] = { line = line_num, character = name_start - 1 + #passage_name }
          }
        })
      end
      pos = (visit_start or 0) + 7
      if pos > #line then break end
    end

    line_num = line_num + 1
  end

  return references
end

--- Find all variable references
-- @param uri string Document URI
-- @param var_name string Variable name
-- @return table Array of locations
function Rename:_find_variable_references(uri, var_name)
  local references = {}
  local doc = self._documents:get(uri)
  if not doc then return references end

  local content = doc.content or ""
  local line_num = 0
  local escaped_name = var_name:gsub("([^%w_])", "%%%1")

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    -- VAR declaration
    local var_decl_start = line:find("^%s*VAR%s+" .. escaped_name)
    if var_decl_start then
      local name_start = line:find(var_name, var_decl_start, true)
      if name_start then
        table.insert(references, {
          uri = uri,
          range = {
            start = { line = line_num, character = name_start - 1 },
            ["end"] = { line = line_num, character = name_start - 1 + #var_name }
          }
        })
      end
    end

    -- $var interpolation
    local pos = 1
    while true do
      local var_start, var_end = line:find("%$" .. escaped_name .. "%f[^%w_]", pos)
      if not var_start then break end
      table.insert(references, {
        uri = uri,
        range = {
          start = { line = line_num, character = var_start }, -- After $
          ["end"] = { line = line_num, character = var_start + #var_name }
        }
      })
      pos = var_end + 1
    end

    line_num = line_num + 1
  end

  return references
end

--- Find all function references
-- @param uri string Document URI
-- @param func_name string Function name
-- @return table Array of locations
function Rename:_find_function_references(uri, func_name)
  local references = {}
  local doc = self._documents:get(uri)
  if not doc then return references end

  local content = doc.content or ""
  local line_num = 0
  local escaped_name = func_name:gsub("([^%w_])", "%%%1")

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    -- Definition: FUNCTION name
    if line:match("^%s*FUNCTION%s+" .. escaped_name) then
      local name_start = line:find(func_name, 1, true)
      if name_start then
        table.insert(references, {
          uri = uri,
          range = {
            start = { line = line_num, character = name_start - 1 },
            ["end"] = { line = line_num, character = name_start - 1 + #func_name }
          }
        })
      end
    end

    -- Call: name(...)
    local pos = 1
    while true do
      local call_start = line:find(escaped_name .. "%s*%(", pos)
      if not call_start then break end
      table.insert(references, {
        uri = uri,
        range = {
          start = { line = line_num, character = call_start - 1 },
          ["end"] = { line = line_num, character = call_start - 1 + #func_name }
        }
      })
      pos = call_start + #func_name
    end

    line_num = line_num + 1
  end

  return references
end

--- Find all hook references
-- @param uri string Document URI
-- @param hook_name string Hook name
-- @return table Array of locations
function Rename:_find_hook_references(uri, hook_name)
  local references = {}
  local doc = self._documents:get(uri)
  if not doc then return references end

  local content = doc.content or ""
  local line_num = 0
  local escaped_name = hook_name:gsub("([^%w_])", "%%%1")

  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    -- Hook definition/reference: |name>
    local pos = 1
    while true do
      local hook_start = line:find("|" .. escaped_name .. ">", pos)
      if not hook_start then break end
      table.insert(references, {
        uri = uri,
        range = {
          start = { line = line_num, character = hook_start }, -- After |
          ["end"] = { line = line_num, character = hook_start + #hook_name }
        }
      })
      pos = hook_start + #hook_name + 2
    end

    line_num = line_num + 1
  end

  return references
end

--- Validate a new name
-- @param name string Name to validate
-- @return boolean Valid
-- @return string|nil Error message if invalid
function Rename:_validate_name(name)
  -- Check format: must start with letter or underscore, contain only word chars
  if not name:match("^[%a_][%w_]*$") then
    return false, "Invalid name format: must start with letter or underscore and contain only letters, numbers, and underscores"
  end

  -- Check reserved words
  if RESERVED_WORDS[name] then
    return false, "Cannot use reserved word: " .. name
  end

  -- Check reserved prefixes
  for _, prefix in ipairs(RESERVED_PREFIXES) do
    if name:sub(1, #prefix) == prefix then
      return false, "Cannot use reserved prefix: " .. prefix
    end
  end

  return true
end

return Rename
