-- whisker-lsp/lib/providers/completion.lua
-- Auto-completion provider

local interfaces = require("lib.interfaces")

local CompletionProvider = {}
CompletionProvider.__index = CompletionProvider

--- Create a new completion provider
--- @param document_manager table DocumentManager instance
--- @param parser_integration table ParserIntegration instance
--- @return table CompletionProvider instance
function CompletionProvider.new(document_manager, parser_integration)
  local self = setmetatable({}, CompletionProvider)
  self.document_manager = document_manager
  self.parser = parser_integration
  return self
end

--- Get completions for a position
--- @param params table Completion request params
--- @return table CompletionList
function CompletionProvider:get_completions(params)
  local uri = params.textDocument.uri
  local line = params.position.line
  local character = params.position.character

  local items = {}

  -- Get line content
  local line_text = self.document_manager:get_line(uri, line)
  if not line_text then
    return { isIncomplete = false, items = {} }
  end

  -- Get text before cursor
  local prefix = line_text:sub(1, character)

  -- Determine context and provide appropriate completions
  local context = self:detect_context(prefix, line_text)

  if context.type == "divert" then
    -- After "->", complete with passage names
    items = self:get_passage_completions(uri, context.prefix)
  elseif context.type == "variable" then
    -- Inside "{}", complete with variable names
    items = self:get_variable_completions(uri, context.prefix)
  elseif context.type == "macro" then
    -- Inside "<<>>", complete with macro names
    items = self:get_macro_completions(context.prefix)
  elseif context.type == "choice_target" then
    -- After choice "-> ", complete with passages
    items = self:get_passage_completions(uri, context.prefix)
  else
    -- General completions: keywords, snippets
    items = self:get_general_completions(prefix)
  end

  return {
    isIncomplete = false,
    items = items
  }
end

--- Detect completion context from line prefix
--- @param prefix string Text before cursor
--- @param line_text string Full line text
--- @return table Context information
function CompletionProvider:detect_context(prefix, line_text)
  -- Check for choice target (* [...] ->) - must be checked before general divert
  local choice_target = prefix:match("%[.-%]%s*->%s*([%w_]*)$")
  if choice_target then
    return { type = "choice_target", prefix = choice_target }
  end

  -- Check for divert (->)
  local divert_match = prefix:match("->%s*([%w_]*)$")
  if divert_match then
    return { type = "divert", prefix = divert_match }
  end

  -- Check for variable reference ({)
  local var_match = prefix:match("{([%w_]*)$")
  if var_match then
    return { type = "variable", prefix = var_match }
  end

  -- Check for macro (<<)
  local macro_match = prefix:match("<<([%w_]*)$")
  if macro_match then
    return { type = "macro", prefix = macro_match }
  end

  return { type = "general", prefix = "" }
end

--- Get passage name completions
--- @param uri string Document URI
--- @param prefix string Prefix to filter
--- @return table Array of completion items
function CompletionProvider:get_passage_completions(uri, prefix)
  local items = {}
  local passages = self.parser:get_passages(uri)

  for _, passage in ipairs(passages) do
    if self:matches_prefix(passage.name, prefix) then
      items[#items + 1] = {
        label = passage.name,
        kind = interfaces.CompletionItemKind.Reference,
        detail = "Passage",
        documentation = passage.description ~= "" and passage.description or nil,
        insertText = passage.name
      }
    end
  end

  -- Add special passages
  local special_passages = { "END", "DONE" }
  for _, name in ipairs(special_passages) do
    if self:matches_prefix(name, prefix) then
      items[#items + 1] = {
        label = name,
        kind = interfaces.CompletionItemKind.Constant,
        detail = "Special passage",
        insertText = name
      }
    end
  end

  return items
end

--- Get variable name completions
--- @param uri string Document URI
--- @param prefix string Prefix to filter
--- @return table Array of completion items
function CompletionProvider:get_variable_completions(uri, prefix)
  local items = {}
  local variables = self.parser:get_variables(uri)

  for _, var in ipairs(variables) do
    if self:matches_prefix(var.name, prefix) then
      local detail = var.type
      if var.value then
        detail = detail .. " = " .. tostring(var.value)
      end

      items[#items + 1] = {
        label = var.name,
        kind = interfaces.CompletionItemKind.Variable,
        detail = detail,
        insertText = var.name
      }
    end
  end

  return items
end

--- Get macro completions
--- @param prefix string Prefix to filter
--- @return table Array of completion items
function CompletionProvider:get_macro_completions(prefix)
  local items = {}

  -- Built-in macros
  local macros = {
    { name = "if", detail = "Conditional block", snippet = "if $1>>\n  $2\n<<endif>>" },
    { name = "else", detail = "Else branch", snippet = "else>>" },
    { name = "elseif", detail = "Else if branch", snippet = "elseif $1>>" },
    { name = "endif", detail = "End conditional", snippet = "endif>>" },
    { name = "set", detail = "Set variable", snippet = "set $1 = $2>>" },
    { name = "include", detail = "Include passage", snippet = "include $1>>" },
    { name = "link", detail = "Create link", snippet = "link $1>>$2<</link>>" },
    { name = "silently", detail = "Silent block", snippet = "silently>>\n  $1\n<</silently>>" },
    { name = "nobr", detail = "No line breaks", snippet = "nobr>>\n  $1\n<</nobr>>" }
  }

  for _, macro in ipairs(macros) do
    if self:matches_prefix(macro.name, prefix) then
      items[#items + 1] = {
        label = macro.name,
        kind = interfaces.CompletionItemKind.Snippet,
        detail = macro.detail,
        insertText = macro.snippet,
        insertTextFormat = 2  -- Snippet format
      }
    end
  end

  return items
end

--- Get general completions (keywords, snippets)
--- @param prefix string Current prefix
--- @return table Array of completion items
function CompletionProvider:get_general_completions(prefix)
  local items = {}

  -- Keyword completions
  local keywords = {
    { name = "passage", detail = "Define a passage", snippet = 'passage "$1" {\n  $2\n}' },
    { name = "choice", detail = "Define a choice", snippet = '* [$1] -> $2' },
    { name = "sticky", detail = "Sticky choice", snippet = '+ [$1] -> $2' }
  }

  for _, kw in ipairs(keywords) do
    if self:matches_prefix(kw.name, prefix) then
      items[#items + 1] = {
        label = kw.name,
        kind = interfaces.CompletionItemKind.Keyword,
        detail = kw.detail,
        insertText = kw.snippet,
        insertTextFormat = 2
      }
    end
  end

  return items
end

--- Check if name matches prefix (case-insensitive)
--- @param name string Name to check
--- @param prefix string Prefix to match
--- @return boolean
function CompletionProvider:matches_prefix(name, prefix)
  if not prefix or prefix == "" then
    return true
  end
  return name:lower():sub(1, #prefix) == prefix:lower()
end

--- Resolve additional completion item details
--- @param item table Completion item
--- @return table Resolved completion item
function CompletionProvider:resolve_completion(item)
  -- Could add more details here if needed
  return item
end

return CompletionProvider
