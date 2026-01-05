--- LSP Completion Provider
-- Provides code completion for WLS documents
-- @module whisker.lsp.completion
-- @author Whisker Core Team
-- @license MIT

local Completion = {}
Completion.__index = Completion
Completion._dependencies = {}

--- Completion item kinds
local CompletionItemKind = {
  TEXT = 1,
  FUNCTION = 3,
  VARIABLE = 6,
  CLASS = 7,
  MODULE = 9,
  PROPERTY = 10,
  KEYWORD = 14,
  SNIPPET = 15,
  REFERENCE = 18,
  CONSTANT = 21,
}

--- Special passage targets
local SPECIAL_TARGETS = {
  { name = "END", description = "End the story" },
  { name = "BACK", description = "Go back to previous passage" },
  { name = "RESTART", description = "Restart the story" },
}

--- WLS Keywords
local KEYWORDS = {
  "if", "else", "elif", "do", "not", "and", "or",
  "true", "false", "null",
}

--- Create a new completion provider
-- @param options table Options with documents manager
-- @return Completion Provider instance
function Completion.new(options)
  options = options or {}
  local self = setmetatable({}, Completion)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function Completion:set_parser(parser)
  self._parser = parser
end

--- Get completions at position
-- @param uri string Document URI
-- @param line number Line number (0-based)
-- @param character number Character position (0-based)
-- @return table Completion list
function Completion:get_completions(uri, line, character)
  local items = {}

  local text_before = self._documents:get_text_before(uri, line, character)
  if not text_before then
    return { isIncomplete = false, items = items }
  end

  -- Check context to determine completion type
  local context = self:_detect_context(text_before)

  if context == "passage_link" then
    items = self:_get_passage_completions(uri, text_before)
  elseif context == "variable" then
    items = self:_get_variable_completions(uri, text_before)
  elseif context == "choice" then
    items = self:_get_choice_completions(text_before)
  elseif context == "conditional" then
    items = self:_get_conditional_completions(text_before)
  else
    -- Default completions
    items = self:_get_default_completions(uri)
  end

  return { isIncomplete = false, items = items }
end

--- Detect completion context from text before cursor
-- @param text_before string Text before cursor position
-- @return string Context type
function Completion:_detect_context(text_before)
  -- Check for passage link context (after -> or in [[ ]])
  if text_before:match("->%s*[%w_]*$") or text_before:match("%[%[[%w_]*$") then
    return "passage_link"
  end

  -- Check for variable context (after $)
  if text_before:match("%$[%w_]*$") then
    return "variable"
  end

  -- Check for choice context (after + or * at start of line)
  if text_before:match("^%s*[+*]%s*") then
    return "choice"
  end

  -- Check for conditional context (inside { })
  if text_before:match("{[^}]*$") then
    return "conditional"
  end

  return "default"
end

--- Get passage completions
-- @param uri string Document URI
-- @param text_before string Text before cursor
-- @return table Completion items
function Completion:_get_passage_completions(uri, text_before)
  local items = {}
  local prefix = text_before:match("->%s*([%w_]*)$") or text_before:match("%[%[([%w_]*)$") or ""

  -- Add special targets first
  for _, target in ipairs(SPECIAL_TARGETS) do
    if target.name:lower():find(prefix:lower(), 1, true) then
      table.insert(items, {
        label = target.name,
        kind = CompletionItemKind.CONSTANT,
        detail = target.description,
        insertText = target.name,
      })
    end
  end

  -- Add passage names from document
  local passages = self:_extract_passages(uri)
  for _, passage in ipairs(passages) do
    if passage.name:lower():find(prefix:lower(), 1, true) then
      table.insert(items, {
        label = passage.name,
        kind = CompletionItemKind.REFERENCE,
        detail = "Passage",
        documentation = passage.preview and { kind = "markdown", value = passage.preview } or nil,
        insertText = passage.name,
      })
    end
  end

  return items
end

--- Get variable completions
-- @param uri string Document URI
-- @param text_before string Text before cursor
-- @return table Completion items
function Completion:_get_variable_completions(uri, text_before)
  local items = {}
  local prefix = text_before:match("%$([%w_]*)$") or ""

  -- Extract variables from document
  local variables = self:_extract_variables(uri)
  for _, variable in ipairs(variables) do
    if variable.name:lower():find(prefix:lower(), 1, true) then
      local detail = variable.var_type or "variable"
      if variable.value ~= nil then
        detail = detail .. " = " .. tostring(variable.value)
      end

      table.insert(items, {
        label = variable.name,
        kind = CompletionItemKind.VARIABLE,
        detail = detail,
        insertText = variable.name,
      })
    end
  end

  return items
end

--- Get choice completions
-- @param text_before string Text before cursor
-- @return table Completion items
function Completion:_get_choice_completions(text_before)
  local items = {}

  -- Add choice templates
  table.insert(items, {
    label = "[Choice text] -> target",
    kind = CompletionItemKind.SNIPPET,
    detail = "Choice with target",
    insertText = "[${1:Choice text}] -> ${2:passage}",
    insertTextFormat = 2, -- Snippet
  })

  table.insert(items, {
    label = "[Choice text]",
    kind = CompletionItemKind.SNIPPET,
    detail = "Simple choice",
    insertText = "[${1:Choice text}]",
    insertTextFormat = 2,
  })

  table.insert(items, {
    label = "(condition) [Choice text] -> target",
    kind = CompletionItemKind.SNIPPET,
    detail = "Conditional choice",
    insertText = "(${1:condition}) [${2:Choice text}] -> ${3:passage}",
    insertTextFormat = 2,
  })

  return items
end

--- Get conditional completions
-- @param text_before string Text before cursor
-- @return table Completion items
function Completion:_get_conditional_completions(text_before)
  local items = {}

  -- Add keywords
  for _, keyword in ipairs(KEYWORDS) do
    table.insert(items, {
      label = keyword,
      kind = CompletionItemKind.KEYWORD,
      insertText = keyword,
    })
  end

  -- Add conditional templates
  table.insert(items, {
    label = "if condition}",
    kind = CompletionItemKind.SNIPPET,
    detail = "If conditional",
    insertText = "if ${1:condition}}${2:text}{/}",
    insertTextFormat = 2,
  })

  table.insert(items, {
    label = "do assignment}",
    kind = CompletionItemKind.SNIPPET,
    detail = "Do action",
    insertText = "do ${1:var} = ${2:value}}",
    insertTextFormat = 2,
  })

  return items
end

--- Get default completions
-- @param uri string Document URI
-- @return table Completion items
function Completion:_get_default_completions(uri)
  local items = {}

  -- Add directives
  local directives = {
    { label = "@TITLE", detail = "Story title directive" },
    { label = "@AUTHOR", detail = "Story author directive" },
    { label = "@VERSION", detail = "Story version directive" },
    { label = "@IFID", detail = "Story IFID directive" },
    { label = "@START", detail = "Start passage directive" },
    { label = "VAR", detail = "Variable declaration" },
  }

  for _, directive in ipairs(directives) do
    table.insert(items, {
      label = directive.label,
      kind = CompletionItemKind.KEYWORD,
      detail = directive.detail,
      insertText = directive.label,
    })
  end

  -- Add passage header snippet
  table.insert(items, {
    label = ":: Passage",
    kind = CompletionItemKind.SNIPPET,
    detail = "New passage header",
    insertText = ":: ${1:PassageName}\n${2:Content}\n",
    insertTextFormat = 2,
  })

  return items
end

--- Extract passages from document
-- @param uri string Document URI
-- @return table Array of passage info
function Completion:_extract_passages(uri)
  local passages = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return passages end

  for i, line in ipairs(lines) do
    local name = line:match("^::%s*([^%[%]]+)")
    if name then
      name = name:match("^%s*(.-)%s*$")
      -- Get preview (next non-empty line)
      local preview = nil
      for j = i + 1, math.min(i + 3, #lines) do
        if lines[j] and lines[j]:match("%S") then
          preview = lines[j]:sub(1, 80)
          break
        end
      end

      table.insert(passages, {
        name = name,
        line = i - 1,
        preview = preview,
      })
    end
  end

  return passages
end

--- Extract variables from document
-- @param uri string Document URI
-- @return table Array of variable info
function Completion:_extract_variables(uri)
  local variables = {}
  local seen = {}
  local lines = self._documents:get_lines(uri)
  if not lines then return variables end

  for _, line in ipairs(lines) do
    -- VAR declarations
    local name, value = line:match("^%s*VAR%s+([%w_]+)%s*=%s*(.+)$")
    if name and not seen[name] then
      seen[name] = true
      local var_type = "string"
      if value == "true" or value == "false" then
        var_type = "boolean"
      elseif tonumber(value) then
        var_type = "number"
      end
      table.insert(variables, {
        name = name,
        value = value,
        var_type = var_type,
      })
    end

    -- Variable usage patterns ($var)
    for var_name in line:gmatch("%$([%w_]+)") do
      if not seen[var_name] then
        seen[var_name] = true
        table.insert(variables, {
          name = var_name,
          var_type = "unknown",
        })
      end
    end
  end

  return variables
end

return Completion
