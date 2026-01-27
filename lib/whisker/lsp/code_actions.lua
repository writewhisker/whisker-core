--- LSP Code Actions Provider
-- Provides code actions (quick fixes and refactoring) for WLS documents
-- @module whisker.lsp.code_actions
-- @author Whisker Core Team
-- @license MIT

local CodeActions = {}
CodeActions.__index = CodeActions
CodeActions._dependencies = {}

--- Create a new code actions provider
-- @param options table Options with documents manager
-- @return CodeActions Provider instance
function CodeActions.new(options)
  options = options or {}
  local self = setmetatable({}, CodeActions)
  self._documents = options.documents
  self._parser = nil
  return self
end

--- Set the parser
-- @param parser table Parser instance
function CodeActions:set_parser(parser)
  self._parser = parser
end

--- Get code actions for a range
-- @param uri string Document URI
-- @param range table LSP range
-- @param context table Code action context with diagnostics
-- @return table Array of code actions
function CodeActions:get_actions(uri, range, context)
  local actions = {}
  local doc = self._documents:get(uri)

  if not doc then
    return actions
  end

  -- Get diagnostics for range
  local diagnostics = context.diagnostics or {}

  -- Generate actions for each diagnostic
  for _, diagnostic in ipairs(diagnostics) do
    local diagnostic_actions = self:_actions_for_diagnostic(uri, diagnostic, doc)
    for _, action in ipairs(diagnostic_actions) do
      table.insert(actions, action)
    end
  end

  -- Add general refactoring actions if text is selected (multi-line selection)
  if range and range.start and range["end"] then
    if range.start.line ~= range["end"].line then
      local extract_action = self:_create_extract_passage_action(uri, range, doc)
      if extract_action then
        table.insert(actions, extract_action)
      end
    end
  end

  -- Add source actions (always available)
  local source_actions = self:_get_source_actions(uri, doc)
  for _, action in ipairs(source_actions) do
    table.insert(actions, action)
  end

  return actions
end

--- Generate actions for a specific diagnostic
-- @param uri string Document URI
-- @param diagnostic table LSP diagnostic
-- @param doc table Document
-- @return table Array of code actions
function CodeActions:_actions_for_diagnostic(uri, diagnostic, doc)
  local actions = {}
  local code = diagnostic.code
  local message = diagnostic.message or ""

  -- Dead link - create passage
  -- Match diagnostic messages like "Broken link: passage 'Target' not found"
  local target_name = message:match("passage%s+'([^']+)'%s+not%s+found")
  if target_name then
    local end_range = self:_end_of_document_range(doc)
    table.insert(actions, {
      title = string.format('Create passage "%s"', target_name),
      kind = "quickfix",
      diagnostics = { diagnostic },
      edit = {
        changes = {
          [uri] = {
            {
              range = end_range,
              newText = string.format("\n\n:: %s\n[Content for %s]\n", target_name, target_name)
            }
          }
        }
      }
    })
  end

  -- Special target case - fix capitalization
  if code == "WLS-LNK-003" then
    local data = diagnostic.data or {}
    local target = data.target
    local correct = data.correct
    if target and correct then
      table.insert(actions, {
        title = string.format('Fix capitalization: "%s" -> "%s"', target, correct),
        kind = "quickfix",
        diagnostics = { diagnostic },
        isPreferred = true,
        edit = {
          changes = {
            [uri] = {
              {
                range = diagnostic.range,
                newText = correct
              }
            }
          }
        }
      })
    end
  end

  -- Missing metadata - add directive
  if code == "WLS-QUA-006" then
    local data = diagnostic.data or {}
    local field = data.field
    if field then
      table.insert(actions, {
        title = string.format('Add @%s directive', field),
        kind = "quickfix",
        diagnostics = { diagnostic },
        edit = {
          changes = {
            [uri] = {
              {
                range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
                newText = string.format('@%s: ""\n', field)
              }
            }
          }
        }
      })
    end
  end

  -- Duplicate passage - rename or remove
  if message:match("[Dd]uplicate%s+passage") then
    local passage_name = message:match("passage%s+'([^']+)'")
    if passage_name then
      table.insert(actions, {
        title = string.format('Rename duplicate passage "%s"', passage_name),
        kind = "quickfix",
        diagnostics = { diagnostic },
        command = {
          title = "Rename Passage",
          command = "whisker.renamePassage",
          arguments = { uri, diagnostic.range, passage_name }
        }
      })
    end
  end

  -- Undefined variable - declare it
  local var_name = message:match("%$([%w_]+).-not%s+be%s+defined") or message:match("undefined%s+variable%s+'%$([^']+)'")
  if var_name then
    table.insert(actions, {
      title = string.format('Declare variable "$%s"', var_name),
      kind = "quickfix",
      diagnostics = { diagnostic },
      edit = {
        changes = {
          [uri] = {
            {
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
              newText = string.format("VAR %s = 0\n", var_name)
            }
          }
        }
      }
    })
  end

  return actions
end

--- Create extract to passage action
-- @param uri string Document URI
-- @param range table Selection range
-- @param doc table Document
-- @return table|nil Code action
function CodeActions:_create_extract_passage_action(uri, range, doc)
  return {
    title = "Extract to new passage",
    kind = "refactor.extract",
    command = {
      title = "Extract to Passage",
      command = "whisker.extractPassage",
      arguments = { uri, range }
    }
  }
end

--- Get source actions (organize, format, etc.)
-- @param uri string Document URI
-- @param doc table Document
-- @return table Array of code actions
function CodeActions:_get_source_actions(uri, doc)
  local actions = {}
  local content = doc.content or ""

  -- Generate IFID if not present
  if not content:match("@ifid:") then
    table.insert(actions, {
      title = "Generate IFID",
      kind = "source",
      edit = {
        changes = {
          [uri] = {
            {
              range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
              newText = string.format("@ifid: %s\n", self:_generate_ifid())
            }
          }
        }
      }
    })
  end

  return actions
end

--- Generate a new IFID (UUID)
-- @return string IFID
function CodeActions:_generate_ifid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  local ifid = template:gsub("[xy]", function(c)
    local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
    return string.format("%X", v)
  end)
  return ifid
end

--- Get range at end of document
-- @param doc table Document
-- @return table LSP range
function CodeActions:_end_of_document_range(doc)
  local content = doc.content or ""
  local lines = {}
  for line in (content .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end

  local last_line = math.max(0, #lines - 1)
  local last_col = #(lines[#lines] or "")

  return {
    start = { line = last_line, character = last_col },
    ["end"] = { line = last_line, character = last_col }
  }
end

return CodeActions
