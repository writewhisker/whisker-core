-- lib/whisker/script/i18n_compiler.lua
-- Compiler for i18n tags to Lua code
-- Stage 7: Whisker Script i18n Integration

local M = {}

-- Module version
M._VERSION = "1.0.0"

--- Compile i18n tag to Lua code
-- @param node table AST node
-- @param context table Compiler context
-- @return string Lua code
function M.compile(node, context)
  context = context or { locals = {} }

  if node.type == "i18n_translate" then
    return M.compileTranslate(node, context)
  elseif node.type == "i18n_plural" then
    return M.compilePlural(node, context)
  elseif node.type == "text" then
    return M.compileText(node, context)
  elseif node.type == "text_block" then
    return M.compileTextBlock(node, context)
  end

  return ""
end

--- Compile @@t tag
-- @param node table AST node
-- @param context table Compiler context
-- @return string Lua code
function M.compileTranslate(node, context)
  local key = string.format('"%s"', node.key)
  local vars = M.compileVars(node.args, context)

  return string.format('_i18n:t(%s, %s)', key, vars)
end

--- Compile @@p tag
-- @param node table AST node
-- @param context table Compiler context
-- @return string Lua code
function M.compilePlural(node, context)
  local key = string.format('"%s"', node.key)

  -- Extract count expression
  local countExpr = M.compileExpr(node.args.count.expression, context)

  -- Compile other variables (excluding count)
  local otherArgs = {}
  for varName, arg in pairs(node.args) do
    if varName ~= "count" then
      otherArgs[varName] = arg
    end
  end

  local vars = M.compileVars(otherArgs, context)

  return string.format('_i18n:p(%s, %s, %s)', key, countExpr, vars)
end

--- Compile text node
-- @param node table AST node
-- @param context table Compiler context
-- @return string Lua code
function M.compileText(node, context)
  -- Escape quotes and special characters
  local escaped = node.value
  escaped = escaped:gsub("\\", "\\\\")
  escaped = escaped:gsub('"', '\\"')
  escaped = escaped:gsub("\n", "\\n")
  escaped = escaped:gsub("\r", "\\r")
  escaped = escaped:gsub("\t", "\\t")

  return string.format('"%s"', escaped)
end

--- Compile text block (mixed text and i18n)
-- @param node table AST node
-- @param context table Compiler context
-- @return string Lua code
function M.compileTextBlock(node, context)
  if not node.nodes or #node.nodes == 0 then
    return '""'
  end

  if #node.nodes == 1 then
    return M.compile(node.nodes[1], context)
  end

  -- Multiple nodes: concatenate with ..
  local parts = {}
  for _, child in ipairs(node.nodes) do
    table.insert(parts, M.compile(child, context))
  end

  return table.concat(parts, " .. ")
end

--- Compile variable table
-- @param args table Argument map
-- @param context table Compiler context
-- @return string Lua table code
function M.compileVars(args, context)
  if not args or not next(args) then
    return "{}"
  end

  local varPairs = {}
  for varName, arg in pairs(args) do
    local expr = M.compileExpr(arg.expression, context)
    table.insert(varPairs, string.format('%s = %s', varName, expr))
  end

  -- Sort for deterministic output
  table.sort(varPairs)

  return "{" .. table.concat(varPairs, ", ") .. "}"
end

--- Compile expression to Lua
-- @param expression string Expression text
-- @param context table Compiler context
-- @return string Lua code
function M.compileExpr(expression, context)
  context = context or { locals = {} }

  -- Simple case: variable reference (player.name → _ctx.player.name)
  if expression:match("^[%w%.]+$") then
    -- Split on dots and build access chain
    local parts = {}
    for part in expression:gmatch("[^%.]+") do
      table.insert(parts, part)
    end

    -- First part: check if local variable or context field
    local first = parts[1]
    if context.locals and context.locals[first] then
      -- Local variable - use directly
      local chain = first
      for i = 2, #parts do
        chain = chain .. "." .. parts[i]
      end
      return chain
    else
      -- Context field - prefix with _ctx
      local chain = "_ctx." .. first
      for i = 2, #parts do
        chain = chain .. "." .. parts[i]
      end
      return chain
    end
  end

  -- Complex expression: return as-is
  return expression
end

--- Generate full compiled output for a text block
-- @param node table AST node (text_block)
-- @param context table Compiler context
-- @param varName string Variable name to assign result (optional)
-- @return string Lua code
function M.generateOutput(node, context, varName)
  local compiled = M.compile(node, context)

  if varName then
    return string.format("local %s = %s", varName, compiled)
  else
    return compiled
  end
end

--- Generate print statement for a text block
-- @param node table AST node
-- @param context table Compiler context
-- @return string Lua code
function M.generatePrint(node, context)
  local compiled = M.compile(node, context)
  return string.format("print(%s)", compiled)
end

return M
