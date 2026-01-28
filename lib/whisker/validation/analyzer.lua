--- Story Analyzer - Advanced Validation & Analysis
-- @module whisker.validation.analyzer
-- WLS 1.0 compliant with:
--   Gaps 24-29: Validation error codes (STR, LNK, FLW, VAR, AST, META, SCR, COL, MOD, PRS)
--   GAP-015: Expression errors (EXP)

local Analyzer = {}
Analyzer.__index = Analyzer

-- Optional validator imports (loaded on demand)
local AssetValidator
local ScriptValidator
local Diagnostic

-- Special navigation targets
local SPECIAL_TARGETS = {
  END = true,
  BACK = true,
  RESTART = true
}

-- Error code constants (matching WLS spec)
Analyzer.ERROR_CODES = {
  -- Structure errors (STR)
  MISSING_START_PASSAGE = "WLS-STR-001",
  UNREACHABLE_PASSAGE = "WLS-STR-002",
  DUPLICATE_PASSAGE = "WLS-STR-003",
  EMPTY_PASSAGE = "WLS-STR-004",
  ORPHAN_PASSAGE = "WLS-STR-005",
  NO_TERMINAL = "WLS-STR-006",
  -- Link errors (LNK)
  DEAD_LINK = "WLS-LNK-001",
  SELF_LINK_NO_CHANGE = "WLS-LNK-002",
  SPECIAL_TARGET_CASE = "WLS-LNK-003",
  BACK_ON_START = "WLS-LNK-004",
  EMPTY_CHOICE_TARGET = "WLS-LNK-005",
  -- Flow control errors (FLW)
  DEAD_END = "WLS-FLW-001",
  BOTTLENECK = "WLS-FLW-002",
  CYCLE_DETECTED = "WLS-FLW-003",
  INFINITE_LOOP = "WLS-FLW-004",
  UNREACHABLE_CHOICE = "WLS-FLW-005",
  ALWAYS_TRUE_CONDITION = "WLS-FLW-006",
  -- Variable errors (VAR)
  UNDEFINED_VARIABLE = "WLS-VAR-001",
  UNUSED_VARIABLE = "WLS-VAR-002",
  INVALID_VARIABLE_NAME = "WLS-VAR-003",
  RESERVED_PREFIX = "WLS-VAR-004",
  VARIABLE_SHADOWING = "WLS-VAR-005",
  LONE_DOLLAR = "WLS-VAR-006",
  UNCLOSED_INTERPOLATION = "WLS-VAR-007",
  TEMP_CROSS_PASSAGE = "WLS-VAR-008",
  -- Asset errors (AST) - GAP-024
  MISSING_ASSET = "WLS-AST-001",
  INVALID_ASSET_PATH = "WLS-AST-002",
  UNSUPPORTED_ASSET_TYPE = "WLS-AST-003",
  ASSET_TOO_LARGE = "WLS-AST-004",
  -- Metadata errors (META) - GAP-025
  MISSING_METADATA = "WLS-META-001",
  INVALID_METADATA = "WLS-META-002",
  DEPRECATED_METADATA = "WLS-META-003",
  -- Script errors (SCR) - GAP-026
  SCRIPT_SYNTAX_ERROR = "WLS-SCR-001",
  SCRIPT_UNDEFINED_VAR = "WLS-SCR-002",
  SCRIPT_FORBIDDEN_CALL = "WLS-SCR-003",
  SCRIPT_TIMEOUT_RISK = "WLS-SCR-004",
  -- Collection errors (COL) - GAP-027
  DUPLICATE_COLLECTION = "WLS-COL-001",
  INVALID_COLLECTION_SYNTAX = "WLS-COL-002",
  INVALID_COLLECTION_TYPE = "WLS-COL-003",
  -- Module errors (MOD) - GAP-028
  CIRCULAR_INCLUDE = "WLS-MOD-001",
  INCLUDE_NOT_FOUND = "WLS-MOD-002",
  INCLUDE_PARSE_ERROR = "WLS-MOD-003",
  MAX_INCLUDE_DEPTH = "WLS-MOD-004",
  DUPLICATE_NAMESPACE = "WLS-MOD-005",
  INVALID_FUNCTION_SIGNATURE = "WLS-MOD-006",
  -- Presentation errors (PRS)
  RESERVED_CSS_PREFIX = "WLS-PRS-001",
  -- Expression errors (EXP) - GAP-015
  TYPE_MISMATCH = "WLS-EXP-001",
  INVALID_OPERATOR = "WLS-EXP-002",
  DIVISION_BY_ZERO = "WLS-EXP-003",
  UNDEFINED_FUNCTION = "WLS-EXP-004",
  PROPERTY_ON_NON_OBJECT = "WLS-EXP-005",
}

-- Required metadata fields
Analyzer.REQUIRED_METADATA = {
  "title",  -- Story must have a title
}

-- Recommended metadata fields
Analyzer.RECOMMENDED_METADATA = {
  "author",
  "ifid",
  "version",
}

-- Deprecated metadata fields
Analyzer.DEPRECATED_METADATA = {
  format = "Use 'wls' field instead",
  creator = "Use 'author' field instead",
}

-- Reserved prefixes for variables
local RESERVED_PREFIXES = { "_", "__", "whisker_", "wls_" }

-- Reserved CSS class prefixes (GAP-006)
local RESERVED_CSS_PREFIXES = {
  "whisker-",
  "ws-",
}

-- System variables (allowed to use reserved prefixes)
local SYSTEM_VARIABLES = {
  _visits = true,
  _turns = true,
  _passage = true,
  _previous = true,
  _random = true
}

function Analyzer.new()
  local self = setmetatable({}, Analyzer)
  self.issues = {}
  return self
end

--- Create a diagnostic entry
-- @param code Error code
-- @param message Human-readable message
-- @param severity "error" | "warning" | "info"
-- @param passage_id Optional passage ID
-- @param target Optional target
-- @param suggestion Optional fix suggestion
local function create_diagnostic(code, message, severity, passage_id, target, suggestion)
  return {
    code = code,
    message = message,
    severity = severity or "error",
    passage_id = passage_id,
    target = target,
    suggestion = suggestion
  }
end

--- Check if target is a special navigation target
local function is_special_target(target)
  if not target then return false end
  return SPECIAL_TARGETS[target:upper()] == true
end

--- Check if special target has correct case
local function has_correct_case(target)
  return SPECIAL_TARGETS[target] == true
end

--- Get correct case for special target
local function get_correct_case(target)
  return target:upper()
end

--- Check if choice has state-changing action
local function has_state_change(choice)
  return choice.action ~= nil and choice.action ~= ""
end

--- Check if target is a terminal target (END, BACK, RESTART)
local function is_terminal_target(target)
  if not target then return false end
  local upper = target:upper()
  return upper == "END" or upper == "BACK" or upper == "RESTART"
end

--- Detect dead ends in story
function Analyzer:detect_dead_ends(story)
  local diagnostics = {}

  if not story or not story.passages then
    return diagnostics
  end

  -- Build set of passage names
  local passage_names = {}
  for passage_id, _ in pairs(story.passages) do
    passage_names[passage_id] = true
  end

  -- Check each passage for outgoing links
  for passage_id, passage in pairs(story.passages) do
    local has_terminal = false
    local has_valid_link = false

    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        local target = choice.target_passage
        if target then
          if is_terminal_target(target) then
            has_terminal = true
          elseif passage_names[target] then
            has_valid_link = true
          end
        end
      end
    end

    -- Dead end if no choices or no valid outgoing links and no terminal
    if not passage.choices or #passage.choices == 0 then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DEAD_END,
        string.format('Dead end: passage "%s" has no outgoing links', passage_id),
        "warning",
        passage_id,
        nil,
        "Add a choice with a target or use END to mark as intentional ending"
      ))
    elseif not has_valid_link and not has_terminal then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DEAD_END,
        string.format('Dead end: passage "%s" has no valid outgoing links', passage_id),
        "warning",
        passage_id,
        nil,
        "Ensure targets point to existing passages or use END"
      ))
    end
  end

  return diagnostics
end

--- Detect orphan passages (unreachable from start)
function Analyzer:detect_orphans(story)
  local diagnostics = {}

  if not story or not story.passages then
    return diagnostics
  end

  -- Build set of passage names
  local passage_names = {}
  for passage_id, _ in pairs(story.passages) do
    passage_names[passage_id] = true
  end

  -- Track referenced passages
  local referenced = {}
  local start_passage = story.start_passage

  if start_passage then
    referenced[start_passage] = true
  end

  -- Collect all targets
  for _, passage in pairs(story.passages) do
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        if choice.target_passage and not is_special_target(choice.target_passage) then
          referenced[choice.target_passage] = true
        end
      end
    end
  end

  -- Find orphans
  for passage_id, _ in pairs(passage_names) do
    if passage_id ~= start_passage and not referenced[passage_id] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.ORPHAN_PASSAGE,
        string.format('Orphan passage "%s" is never referenced', passage_id),
        "warning",
        passage_id,
        nil,
        "Add a link to this passage or remove it"
      ))
    end
  end

  return diagnostics
end

--- Validate links in story
function Analyzer:validate_links(story)
  local diagnostics = {}

  if not story or not story.passages then
    return diagnostics
  end

  -- Build set of passage names
  local passage_names = {}
  for passage_id, _ in pairs(story.passages) do
    passage_names[passage_id] = true
  end

  local start_passage = story.start_passage

  -- Check each passage
  for passage_id, passage in pairs(story.passages) do
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        local target = choice.target_passage

        repeat
          -- Check for empty target (WLS-LNK-005)
          if not target or target == "" then
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.EMPTY_CHOICE_TARGET,
              string.format('Empty choice target in passage "%s"', passage_id),
              "error",
              passage_id,
              nil,
              "Add a target passage name or use END/BACK/RESTART"
            ))
            break
          end

          -- Check for special target case (WLS-LNK-003)
          if is_special_target(target) and not has_correct_case(target) then
            local correct = get_correct_case(target)
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.SPECIAL_TARGET_CASE,
              string.format('Special target "%s" should be "%s"', target, correct),
              "warning",
              passage_id,
              target,
              string.format('Use "%s" instead of "%s"', correct, target)
            ))
          end

          -- Check for BACK on start passage (WLS-LNK-004)
          if target:upper() == "BACK" and passage_id == start_passage then
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.BACK_ON_START,
              string.format('BACK target on start passage "%s" will have no effect', passage_id),
              "warning",
              passage_id,
              target,
              "Remove BACK from start passage or use a different navigation"
            ))
          end

          -- Check for dead links (WLS-LNK-001)
          if not is_special_target(target) and not passage_names[target] then
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.DEAD_LINK,
              string.format('Dead link: passage "%s" does not exist', target),
              "error",
              passage_id,
              target,
              string.format('Create passage "%s" or fix the target name', target)
            ))
          end

          -- Check for self-link without state change (WLS-LNK-002)
          if target == passage_id and not has_state_change(choice) then
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.SELF_LINK_NO_CHANGE,
              string.format('Self-link in passage "%s" without state change creates infinite loop', passage_id),
              "warning",
              passage_id,
              target,
              "Add an action to modify state or change the target"
            ))
          end
        until true
      end
    end
  end

  return diagnostics
end

--- Check if variable name is valid
local function is_valid_variable_name(name)
  return string.match(name, "^[a-zA-Z_][a-zA-Z0-9_]*$") ~= nil
end

--- Check if variable uses reserved prefix
local function has_reserved_prefix(name)
  if SYSTEM_VARIABLES[name] then
    return nil
  end
  for _, prefix in ipairs(RESERVED_PREFIXES) do
    if string.sub(name, 1, #prefix) == prefix then
      return prefix
    end
  end
  return nil
end

--- Check if variable is a temp variable
local function is_temp_variable(name)
  return string.sub(name, 1, 1) == "_" and not SYSTEM_VARIABLES[name]
end

--- Get normalized variable name (handle scope="temp" case)
local function get_normalized_var_name(var_node)
  local name = var_node.name
  -- If scope is "temp", prepend underscore to normalize
  if var_node.scope == "temp" and string.sub(name, 1, 1) ~= "_" then
    return "_" .. name
  end
  return name
end

--- Extract variables from an expression
local function extract_vars_from_expression(expr, is_write)
  local vars = {}

  if not expr then return vars end

  if expr.type == "variable" then
    table.insert(vars, {
      name = get_normalized_var_name(expr),
      location = expr.location,
      is_write = is_write or false
    })
  elseif expr.type == "assignment_expression" then
    -- Target is a write
    if expr.target and expr.target.type == "variable" then
      table.insert(vars, {
        name = get_normalized_var_name(expr.target),
        location = expr.target.location,
        is_write = true
      })
    end
    -- Value is a read
    local value_vars = extract_vars_from_expression(expr.value, false)
    for _, v in ipairs(value_vars) do
      table.insert(vars, v)
    end
  elseif expr.type == "binary_expression" then
    local left_vars = extract_vars_from_expression(expr.left, false)
    local right_vars = extract_vars_from_expression(expr.right, false)
    for _, v in ipairs(left_vars) do table.insert(vars, v) end
    for _, v in ipairs(right_vars) do table.insert(vars, v) end
  elseif expr.type == "unary_expression" then
    local arg_vars = extract_vars_from_expression(expr.argument, false)
    for _, v in ipairs(arg_vars) do table.insert(vars, v) end
  elseif expr.type == "call_expression" then
    if expr.arguments then
      for _, arg in ipairs(expr.arguments) do
        local arg_vars = extract_vars_from_expression(arg, false)
        for _, v in ipairs(arg_vars) do table.insert(vars, v) end
      end
    end
  elseif expr.type == "member_expression" then
    local obj_vars = extract_vars_from_expression(expr.object, false)
    for _, v in ipairs(obj_vars) do table.insert(vars, v) end
  end

  return vars
end

--- Extract variables from content nodes
local function extract_vars_from_content(content, passage_name)
  local vars = {}

  if not content then return vars end

  for _, node in ipairs(content) do
    if node.type == "interpolation" and node.expression then
      local expr_vars = extract_vars_from_expression(node.expression, false)
      for _, v in ipairs(expr_vars) do
        v.passage = passage_name
        table.insert(vars, v)
      end
    elseif node.type == "expression_statement" and node.expression then
      local expr_vars = extract_vars_from_expression(node.expression, false)
      for _, v in ipairs(expr_vars) do
        v.passage = passage_name
        table.insert(vars, v)
      end
    elseif node.type == "choice" then
      if node.condition then
        local cond_vars = extract_vars_from_expression(node.condition, false)
        for _, v in ipairs(cond_vars) do
          v.passage = passage_name
          table.insert(vars, v)
        end
      end
      if node.action then
        for _, action in ipairs(node.action) do
          local action_vars = extract_vars_from_expression(action, false)
          for _, v in ipairs(action_vars) do
            v.passage = passage_name
            table.insert(vars, v)
          end
        end
      end
      if node.text then
        local text_vars = extract_vars_from_content(node.text, passage_name)
        for _, v in ipairs(text_vars) do table.insert(vars, v) end
      end
    elseif node.type == "conditional" then
      if node.condition then
        local cond_vars = extract_vars_from_expression(node.condition, false)
        for _, v in ipairs(cond_vars) do
          v.passage = passage_name
          table.insert(vars, v)
        end
      end
      if node.consequent then
        local cons_vars = extract_vars_from_content(node.consequent, passage_name)
        for _, v in ipairs(cons_vars) do table.insert(vars, v) end
      end
      if node.alternatives then
        for _, alt in ipairs(node.alternatives) do
          if alt.condition then
            local alt_cond_vars = extract_vars_from_expression(alt.condition, false)
            for _, v in ipairs(alt_cond_vars) do
              v.passage = passage_name
              table.insert(vars, v)
            end
          end
          if alt.content then
            local alt_content_vars = extract_vars_from_content(alt.content, passage_name)
            for _, v in ipairs(alt_content_vars) do table.insert(vars, v) end
          end
        end
      end
      if node.alternate then
        local alt_vars = extract_vars_from_content(node.alternate, passage_name)
        for _, v in ipairs(alt_vars) do table.insert(vars, v) end
      end
    end
  end

  return vars
end

--- Helper to check if table contains value
local function table_contains(tbl, value)
  for _, v in ipairs(tbl) do
    if v == value then return true end
  end
  return false
end

--- Track variables in story
function Analyzer:track_variables(story)
  local variables = {}

  if not story then return variables end

  -- Track global variable declarations
  if story.variables then
    for _, decl in ipairs(story.variables) do
      local name = decl.name
      if not variables[name] then
        variables[name] = {
          name = name,
          is_temp = is_temp_variable(name),
          defined_in = { "_global" },
          used_in = {},
          locations = decl.location and { decl.location } or {},
          is_global = true
        }
      end
    end
  end

  -- Track variables in passages
  if story.passages then
    for passage_id, passage in pairs(story.passages) do
      local refs = extract_vars_from_content(passage.content, passage_id)

      for _, ref in ipairs(refs) do
        local info = variables[ref.name]
        if not info then
          info = {
            name = ref.name,
            is_temp = is_temp_variable(ref.name),
            defined_in = {},
            used_in = {},
            locations = {},
            is_global = false
          }
          variables[ref.name] = info
        end

        if ref.is_write then
          if not table_contains(info.defined_in, ref.passage) then
            table.insert(info.defined_in, ref.passage)
          end
        else
          if not table_contains(info.used_in, ref.passage) then
            table.insert(info.used_in, ref.passage)
          end
        end

        if ref.location then
          table.insert(info.locations, ref.location)
        end
      end
    end
  end

  return variables
end

--- Validate variables in story
function Analyzer:validate_variables(story)
  local diagnostics = {}
  local variables = self:track_variables(story)

  for name, info in pairs(variables) do
    repeat
      -- Skip system variables
      if SYSTEM_VARIABLES[name] then
        break
      end

      -- Check for invalid variable name (WLS-VAR-003)
      if not is_valid_variable_name(name) then
        table.insert(diagnostics, create_diagnostic(
          self.ERROR_CODES.INVALID_VARIABLE_NAME,
          string.format('Invalid variable name "%s"', name),
          "error",
          nil,
          nil,
          "Variable names must start with a letter or underscore and contain only alphanumeric characters"
        ))
      end

      -- Check for reserved prefix (WLS-VAR-004)
      local reserved_prefix = has_reserved_prefix(name)
      if reserved_prefix then
        table.insert(diagnostics, create_diagnostic(
          self.ERROR_CODES.RESERVED_PREFIX,
          string.format('Variable "%s" uses reserved prefix "%s"', name, reserved_prefix),
          "warning",
          nil,
          nil,
          string.format('Avoid using "%s" prefix as it\'s reserved for system use', reserved_prefix)
        ))
      end

      -- Check for undefined variable (WLS-VAR-001)
      if #info.used_in > 0 and #info.defined_in == 0 then
        table.insert(diagnostics, create_diagnostic(
          self.ERROR_CODES.UNDEFINED_VARIABLE,
          string.format('Variable "%s" is used but never defined', name),
          "error",
          nil,
          nil,
          string.format('Define "%s" before using it, or declare it in the story header', name)
        ))
      end

      -- Check for unused variable (WLS-VAR-002)
      if #info.defined_in > 0 and #info.used_in == 0 and not info.is_global then
        table.insert(diagnostics, create_diagnostic(
          self.ERROR_CODES.UNUSED_VARIABLE,
          string.format('Variable "%s" is defined but never used', name),
          "warning",
          nil,
          nil,
          "Remove unused variable or use it in your story"
        ))
      end

      -- Check for temp variable cross-passage usage (WLS-VAR-008)
      if info.is_temp then
        local all_passages = {}
        for _, p in ipairs(info.defined_in) do
          if not table_contains(all_passages, p) then
            table.insert(all_passages, p)
          end
        end
        for _, p in ipairs(info.used_in) do
          if not table_contains(all_passages, p) then
            table.insert(all_passages, p)
          end
        end

        if #all_passages > 1 then
          table.insert(diagnostics, create_diagnostic(
            self.ERROR_CODES.TEMP_CROSS_PASSAGE,
            string.format('Temp variable "%s" is used across multiple passages', name),
            "warning",
            nil,
            nil,
            "Temp variables (starting with _) should only be used within a single passage"
          ))
        end
      end
    until true
  end

  local has_errors = false
  for _, d in ipairs(diagnostics) do
    if d.severity == "error" then
      has_errors = true
      break
    end
  end

  return {
    valid = not has_errors,
    diagnostics = diagnostics,
    variables = variables
  }
end

--- Check accessibility
function Analyzer:check_accessibility(story)
  local diagnostics = {}

  if not story or not story.passages then
    return { valid = true, diagnostics = diagnostics }
  end

  for passage_id, passage in pairs(story.passages) do
    -- Check for too many choices (decision fatigue)
    if passage.choices and #passage.choices > 7 then
      table.insert(diagnostics, create_diagnostic(
        "WLS-A11Y-003",
        string.format('Passage "%s" has %d choices (recommended: 7 or fewer)', passage_id, #passage.choices),
        "info",
        passage_id,
        nil,
        "Consider reducing choices or grouping related options"
      ))
    end

    -- Check for very long text content
    if passage.content then
      local total_length = 0
      for _, node in ipairs(passage.content) do
        if node.type == "text" and node.value then
          total_length = total_length + #node.value
        end
      end
      if total_length > 2000 then
        table.insert(diagnostics, create_diagnostic(
          "WLS-A11Y-002",
          string.format('Passage "%s" has very long text (%d chars)', passage_id, total_length),
          "info",
          passage_id,
          nil,
          "Consider breaking into smaller passages for readability"
        ))
      end
    end
  end

  local has_errors = false
  for _, d in ipairs(diagnostics) do
    if d.severity == "error" then
      has_errors = true
      break
    end
  end

  return {
    valid = not has_errors,
    diagnostics = diagnostics
  }
end

--- Build adjacency graph from story
local function build_graph(story)
  local graph = {}

  for passage_id, passage in pairs(story.passages) do
    graph[passage_id] = {}
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        local target = choice.target_passage
        if target and not is_terminal_target(target) then
          table.insert(graph[passage_id], target)
        end
      end
    end
  end

  return graph
end

--- Calculate max depth using BFS
local function calculate_max_depth(story, graph)
  if not story.start_passage then return 0 end

  local visited = {}
  local queue = { { node = story.start_passage, depth = 0 } }
  local max_depth = 0

  while #queue > 0 do
    local item = table.remove(queue, 1)
    local node, depth = item.node, item.depth

    if not visited[node] then
      visited[node] = true
      if depth > max_depth then max_depth = depth end

      local neighbors = graph[node] or {}
      for _, neighbor in ipairs(neighbors) do
        if not visited[neighbor] and graph[neighbor] then
          table.insert(queue, { node = neighbor, depth = depth + 1 })
        end
      end
    end
  end

  return max_depth
end

--- Analyze flow
function Analyzer:analyze_flow(story)
  local metrics = {
    passage_count = 0,
    choice_count = 0,
    max_depth = 0,
    avg_branching = 0,
    complexity = 1,
    terminal_count = 0,
    loop_back_count = 0
  }

  if not story or not story.passages then
    return {
      metrics = metrics,
      diagnostics = {},
      dead_ends = {},
      bottlenecks = {},
      cycles = {}
    }
  end

  -- Count passages and choices
  for _, passage in pairs(story.passages) do
    metrics.passage_count = metrics.passage_count + 1
    if passage.choices then
      for _, choice in ipairs(passage.choices) do
        metrics.choice_count = metrics.choice_count + 1
        local target = choice.target_passage
        if target then
          local upper = target:upper()
          if upper == "END" then
            metrics.terminal_count = metrics.terminal_count + 1
          elseif upper == "BACK" or upper == "RESTART" then
            metrics.loop_back_count = metrics.loop_back_count + 1
          end
        end
      end
    end
  end

  -- Calculate metrics
  local graph = build_graph(story)
  metrics.max_depth = calculate_max_depth(story, graph)

  if metrics.passage_count > 0 then
    metrics.avg_branching = metrics.choice_count / metrics.passage_count
    metrics.avg_branching = math.floor(metrics.avg_branching * 100 + 0.5) / 100
  end

  -- Cyclomatic complexity: E - N + 2
  metrics.complexity = math.max(1, metrics.choice_count - metrics.passage_count + 2)

  -- Collect diagnostics
  local diagnostics = {}
  local dead_end_diagnostics = self:detect_dead_ends(story)
  for _, d in ipairs(dead_end_diagnostics) do
    table.insert(diagnostics, d)
  end

  -- Extract dead end passage IDs
  local dead_ends = {}
  for _, d in ipairs(dead_end_diagnostics) do
    if d.passage_id then
      table.insert(dead_ends, d.passage_id)
    end
  end

  return {
    metrics = metrics,
    diagnostics = diagnostics,
    dead_ends = dead_ends,
    bottlenecks = {},
    cycles = {}
  }
end

--- Check if a CSS class name uses a reserved prefix (GAP-006)
---@param class_name string
---@return boolean is_reserved
---@return string|nil prefix
local function has_reserved_css_prefix(class_name)
  for _, prefix in ipairs(RESERVED_CSS_PREFIXES) do
    if class_name:sub(1, #prefix) == prefix then
      return true, prefix
    end
  end
  return false, nil
end

--- Validate CSS classes in content (GAP-006)
---@param content string Passage content
---@param passage_id string Passage identifier
---@return table diagnostics
function Analyzer:validate_css_classes(content, passage_id)
  local diagnostics = {}

  if not content or type(content) ~= "string" then
    return diagnostics
  end

  -- Pattern for inline CSS classes: .class:[text]
  for class_name in content:gmatch("%.([%w_%-]+):%[") do
    local is_reserved, prefix = has_reserved_css_prefix(class_name)
    if is_reserved then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.RESERVED_CSS_PREFIX,
        string.format(
          'CSS class "%s" uses reserved prefix "%s"',
          class_name, prefix
        ),
        "warning",
        passage_id,
        nil,
        string.format(
          'Rename to "user-%s" to avoid conflicts with system styles',
          class_name:sub(#prefix + 1)
        )
      ))
    end
  end

  -- Pattern for block CSS classes: .class::[content]
  for class_name in content:gmatch("%.([%w_%-]+)::%[") do
    local is_reserved, prefix = has_reserved_css_prefix(class_name)
    if is_reserved then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.RESERVED_CSS_PREFIX,
        string.format(
          'CSS class "%s" uses reserved prefix "%s"',
          class_name, prefix
        ),
        "warning",
        passage_id,
        nil,
        string.format(
          'Rename to "user-%s" to avoid conflicts with system styles',
          class_name:sub(#prefix + 1)
        )
      ))
    end
  end

  return diagnostics
end

-- ============================================================================
-- GAP-024: Asset Validation
-- ============================================================================

--- Extract asset references from content
---@param content string|table Content to search
---@return table assets Array of {type, path, location}
function Analyzer:extract_assets(content)
  local assets = {}

  local content_str = content
  if type(content) == "table" then
    -- Join content nodes
    local parts = {}
    for _, node in ipairs(content) do
      if node.value then
        table.insert(parts, node.value)
      elseif node.type == "text" and type(node) == "table" then
        table.insert(parts, tostring(node.value or ""))
      end
    end
    content_str = table.concat(parts)
  end

  if type(content_str) ~= "string" then
    return assets
  end

  -- Markdown images: ![alt](path)
  for alt, path in content_str:gmatch("!%[(.-)%]%((.-)%)") do
    table.insert(assets, {
      type = "image",
      path = path:match("^([^%s\"]+)") or path,
      alt = alt
    })
  end

  -- @image directive: @image(path) or @image("path")
  for path in content_str:gmatch("@image%(([^%)]+)%)") do
    path = path:match('^"?(.-)"?$')  -- Remove quotes
    table.insert(assets, { type = "image", path = path })
  end

  -- @audio directive
  for path in content_str:gmatch("@audio%(([^%)]+)%)") do
    path = path:match('^"?(.-)"?$')
    table.insert(assets, { type = "audio", path = path })
  end

  -- @video directive
  for path in content_str:gmatch("@video%(([^%)]+)%)") do
    path = path:match('^"?(.-)"?$')
    table.insert(assets, { type = "video", path = path })
  end

  -- @embed directive
  for url in content_str:gmatch("@embed%(([^%)]+)%)") do
    url = url:match('^"?(.-)"?$')
    table.insert(assets, { type = "embed", path = url })
  end

  return assets
end

--- Validate all assets in story (GAP-024)
---@param story table The story to validate
---@param config table|nil Validation config
---@return table diagnostics
function Analyzer:validate_assets(story, config)
  local diagnostics = {}

  -- Lazy load AssetValidator
  if not AssetValidator then
    local ok, validator = pcall(require, "whisker.validation.asset_validator")
    if ok then
      AssetValidator = validator
    else
      return diagnostics  -- Validator not available
    end
  end

  local validator = AssetValidator.new(config or {})

  if not story or not story.passages then
    return diagnostics
  end

  for passage_id, passage in pairs(story.passages) do
    local content = passage.content or ""
    local assets = self:extract_assets(content)

    for _, asset in ipairs(assets) do
      local asset_diagnostics = validator:validate(
        asset.type,
        asset.path,
        { passage_id = passage_id }
      )

      for _, d in ipairs(asset_diagnostics) do
        d.passage_id = passage_id
        table.insert(diagnostics, d)
      end
    end
  end

  return diagnostics
end

-- ============================================================================
-- GAP-025: Metadata Validation
-- ============================================================================

--- Validate story metadata (GAP-025)
---@param story table The story to validate
---@return table diagnostics
function Analyzer:validate_metadata(story)
  local diagnostics = {}

  if not story then
    return diagnostics
  end

  local metadata = story.metadata or {}
  -- Also check top-level fields
  local name = story.name or story.title or metadata.title
  local ifid = story.ifid or metadata.ifid

  -- Check required fields
  if not name or name == "" then
    table.insert(diagnostics, create_diagnostic(
      self.ERROR_CODES.MISSING_METADATA,
      "Missing required metadata: title/name",
      "error",
      nil,
      nil,
      "Add @title: Your Story Title directive"
    ))
  end

  -- Check recommended fields (warnings)
  if not story.author and not metadata.author then
    table.insert(diagnostics, create_diagnostic(
      self.ERROR_CODES.MISSING_METADATA,
      "Missing recommended metadata: author",
      "warning",
      nil,
      nil,
      "Add @author: Author Name directive"
    ))
  end

  if not ifid then
    table.insert(diagnostics, create_diagnostic(
      self.ERROR_CODES.MISSING_METADATA,
      "Missing recommended metadata: ifid",
      "warning",
      nil,
      nil,
      "Add @ifid: UUID directive or let it be auto-generated"
    ))
  end

  -- Validate IFID format if present
  if ifid then
    -- Simple UUID v4 pattern check
    local uuid_pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-[14]%x%x%x%-[89ABab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
    if not ifid:match(uuid_pattern) then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.INVALID_METADATA,
        string.format('Invalid IFID format: "%s"', ifid),
        "error",
        nil,
        nil,
        "Use UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
      ))
    end
  end

  -- Validate version format if present
  local version = story.version or metadata.version
  if version then
    if not version:match("^%d+%.%d+%.?%d*$") then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.INVALID_METADATA,
        string.format('Invalid version format: "%s"', version),
        "warning",
        nil,
        nil,
        "Use semantic versioning: X.Y.Z"
      ))
    end
  end

  -- Check for deprecated fields
  for field, suggestion in pairs(self.DEPRECATED_METADATA) do
    if metadata[field] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DEPRECATED_METADATA,
        string.format('Deprecated metadata field: %s', field),
        "warning",
        nil,
        nil,
        suggestion
      ))
    end
  end

  return diagnostics
end

-- ============================================================================
-- GAP-026: Script Validation
-- ============================================================================

--- Extract script blocks from content
---@param content string|table Content to search
---@return table scripts Array of {script, type}
function Analyzer:extract_scripts(content)
  local scripts = {}

  local content_str = content
  if type(content) == "table" then
    local parts = {}
    for _, node in ipairs(content) do
      if node.value then
        table.insert(parts, node.value)
      end
    end
    content_str = table.concat(parts)
  end

  if type(content_str) ~= "string" then
    return scripts
  end

  -- Script blocks: {@ ... @}
  for script in content_str:gmatch("{@(.-)@}") do
    table.insert(scripts, { script = script, type = "block" })
  end

  -- onEnter scripts
  for script in content_str:gmatch("@onEnter:%s*(.-)[\r\n]") do
    table.insert(scripts, { script = script, type = "onEnter" })
  end

  return scripts
end

--- Validate scripts in story (GAP-026)
---@param story table The story to validate
---@return table diagnostics
function Analyzer:validate_scripts(story)
  local diagnostics = {}

  -- Lazy load ScriptValidator
  if not ScriptValidator then
    local ok, validator = pcall(require, "whisker.validation.script_validator")
    if ok then
      ScriptValidator = validator
    else
      return diagnostics  -- Validator not available
    end
  end

  local validator = ScriptValidator.new()

  if not story or not story.passages then
    return diagnostics
  end

  for passage_id, passage in pairs(story.passages) do
    local content = passage.content or ""
    local scripts = self:extract_scripts(content)

    for _, s in ipairs(scripts) do
      local script_diags = validator:validate(s.script, {
        passage_id = passage_id,
        script_type = s.type
      })
      for _, d in ipairs(script_diags) do
        d.passage_id = passage_id
        table.insert(diagnostics, d)
      end
    end

    -- Check onEnter script
    if passage.on_enter_script then
      local script_diags = validator:validate(passage.on_enter_script, {
        passage_id = passage_id,
        script_type = "onEnter"
      })
      for _, d in ipairs(script_diags) do
        d.passage_id = passage_id
        table.insert(diagnostics, d)
      end
    end
  end

  return diagnostics
end

-- ============================================================================
-- GAP-027: Collection Validation
-- ============================================================================

--- Validate collection declarations (GAP-027)
---@param story table The story to validate
---@return table diagnostics
function Analyzer:validate_collections(story)
  local diagnostics = {}
  local seen_names = {}

  if not story then return diagnostics end

  -- Check lists
  for name, list in pairs(story.lists or {}) do
    if seen_names[name] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DUPLICATE_COLLECTION,
        string.format('Duplicate collection name: %s', name),
        "error"
      ))
    end
    seen_names[name] = "list"

    -- Validate list items are valid types
    if type(list) == "table" then
      local items = list.values or list
      if type(items) == "table" then
        for i, item in ipairs(items) do
          local item_type = type(item)
          if item_type ~= "string" and item_type ~= "number" and item_type ~= "boolean" and item_type ~= "table" then
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.INVALID_COLLECTION_TYPE,
              string.format('Invalid list item type in %s[%d]: %s', name, i, item_type),
              "error"
            ))
          end
        end
      end
    end
  end

  -- Check arrays
  for name, _ in pairs(story.arrays or {}) do
    if seen_names[name] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DUPLICATE_COLLECTION,
        string.format('Duplicate collection name: %s (conflicts with %s)', name, seen_names[name]),
        "error"
      ))
    end
    seen_names[name] = "array"
  end

  -- Check maps
  for name, map in pairs(story.maps or {}) do
    if seen_names[name] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DUPLICATE_COLLECTION,
        string.format('Duplicate collection name: %s (conflicts with %s)', name, seen_names[name]),
        "error"
      ))
    end
    seen_names[name] = "map"

    -- Validate map keys are strings
    if type(map) == "table" then
      local entries = map.entries or map
      if type(entries) == "table" then
        for key, _ in pairs(entries) do
          if type(key) ~= "string" then
            table.insert(diagnostics, create_diagnostic(
              self.ERROR_CODES.INVALID_COLLECTION_TYPE,
              string.format('Map %s has non-string key: %s', name, type(key)),
              "error"
            ))
          end
        end
      end
    end
  end

  return diagnostics
end

-- ============================================================================
-- GAP-028: Module Validation
-- ============================================================================

--- Validate module declarations (GAP-028)
---@param story table The story to validate
---@return table diagnostics
function Analyzer:validate_modules(story)
  local diagnostics = {}
  local seen_namespaces = {}
  local seen_functions = {}

  if not story then return diagnostics end

  -- Check namespaces
  for name, ns in pairs(story.namespaces or {}) do
    if seen_namespaces[name] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.DUPLICATE_NAMESPACE,
        string.format('Duplicate namespace: %s', name),
        "error"
      ))
    end
    seen_namespaces[name] = true

    -- Validate nested namespaces
    if type(ns) == "table" and ns.nested_namespaces then
      for nested_name, _ in pairs(ns.nested_namespaces) do
        local full_name = name .. "::" .. nested_name
        if seen_namespaces[full_name] then
          table.insert(diagnostics, create_diagnostic(
            self.ERROR_CODES.DUPLICATE_NAMESPACE,
            string.format('Duplicate nested namespace: %s', full_name),
            "error"
          ))
        end
        seen_namespaces[full_name] = true
      end
    end
  end

  -- Check functions
  for name, func in pairs(story.functions or {}) do
    if seen_functions[name] then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.INVALID_FUNCTION_SIGNATURE,
        string.format('Duplicate function: %s', name),
        "error"
      ))
    end
    seen_functions[name] = true

    -- Validate function parameters
    if type(func) == "table" and func.params then
      local seen_params = {}
      for _, param in ipairs(func.params) do
        local param_name = type(param) == "table" and param.name or param
        if seen_params[param_name] then
          table.insert(diagnostics, create_diagnostic(
            self.ERROR_CODES.INVALID_FUNCTION_SIGNATURE,
            string.format('Duplicate parameter in %s: %s', name, param_name),
            "error"
          ))
        end
        seen_params[param_name] = true
      end
    end
  end

  return diagnostics
end

--- Validate includes (static analysis) (GAP-028)
---@param story table The story to validate
---@return table diagnostics
function Analyzer:validate_includes(story)
  local diagnostics = {}

  if not story or not story.includes then
    return diagnostics
  end

  for _, include in ipairs(story.includes) do
    -- Check for obviously invalid paths
    local path = type(include) == "table" and include.path or include
    if not path or path == "" then
      table.insert(diagnostics, create_diagnostic(
        self.ERROR_CODES.INCLUDE_NOT_FOUND,
        "Empty include path",
        "error",
        nil,
        nil,
        "Provide a valid file path for the include"
      ))
    elseif type(path) == "string" and path:match("^%.%.") and path:match("%.%..*%.%.") then
      -- Multiple parent traversals might be suspicious
      table.insert(diagnostics, create_diagnostic(
        "WLS-MOD-007",  -- Path traversal warning
        string.format('Suspicious include path: %s', path),
        "warning",
        nil,
        nil,
        "Avoid excessive parent directory traversal"
      ))
    end
  end

  return diagnostics
end

--- Run all analyses
function Analyzer:analyze(story)
  local var_validation = self:validate_variables(story)

  -- Collect CSS class diagnostics (GAP-006)
  local css_diagnostics = {}
  if story and story.passages then
    for passage_id, passage in pairs(story.passages) do
      -- Handle both string content and table content (AST nodes)
      local content_str = nil
      if type(passage.content) == "string" then
        content_str = passage.content
      elseif type(passage.content) == "table" then
        -- Extract text from content nodes
        local texts = {}
        for _, node in ipairs(passage.content) do
          if node.type == "text" and node.value then
            table.insert(texts, node.value)
          end
        end
        content_str = table.concat(texts, "")
      end

      if content_str then
        local css_issues = self:validate_css_classes(content_str, passage_id)
        for _, issue in ipairs(css_issues) do
          table.insert(css_diagnostics, issue)
        end
      end
    end
  end

  return {
    dead_ends = self:detect_dead_ends(story),
    orphans = self:detect_orphans(story),
    invalid_links = self:validate_links(story),
    variables = var_validation.variables,
    variable_diagnostics = var_validation.diagnostics,
    accessibility = self:check_accessibility(story),
    flow = self:analyze_flow(story),
    css_diagnostics = css_diagnostics,  -- GAP-006
    -- GAP-024 through GAP-028
    asset_diagnostics = self:validate_assets(story),
    metadata_diagnostics = self:validate_metadata(story),
    script_diagnostics = self:validate_scripts(story),
    collection_diagnostics = self:validate_collections(story),
    module_diagnostics = self:validate_modules(story),
    include_diagnostics = self:validate_includes(story),
  }
end

--- Get all diagnostics as a flat array (GAP-029)
---@param story table The story to validate
---@return table diagnostics All diagnostics in a single array
function Analyzer:get_all_diagnostics(story)
  local result = self:analyze(story)
  local all = {}

  -- Helper to add all from array
  local function add_all(arr)
    if arr then
      for _, d in ipairs(arr) do
        table.insert(all, d)
      end
    end
  end

  -- Collect all diagnostics
  add_all(result.dead_ends)
  add_all(result.orphans)
  add_all(result.invalid_links)
  add_all(result.variable_diagnostics)
  add_all(result.accessibility and result.accessibility.diagnostics)
  add_all(result.flow and result.flow.diagnostics)
  add_all(result.css_diagnostics)
  add_all(result.asset_diagnostics)
  add_all(result.metadata_diagnostics)
  add_all(result.script_diagnostics)
  add_all(result.collection_diagnostics)
  add_all(result.module_diagnostics)
  add_all(result.include_diagnostics)

  return all
end

--- Get diagnostics filtered by severity (GAP-029)
---@param story table The story to validate
---@param severity string "error", "warning", or "info"
---@return table diagnostics Filtered diagnostics
function Analyzer:get_diagnostics_by_severity(story, severity)
  local all = self:get_all_diagnostics(story)
  local filtered = {}

  for _, d in ipairs(all) do
    if d.severity == severity then
      table.insert(filtered, d)
    end
  end

  return filtered
end

--- Get diagnostics filtered by code prefix (GAP-029)
---@param story table The story to validate
---@param prefix string Code prefix (e.g., "WLS-VAR", "WLS-AST")
---@return table diagnostics Filtered diagnostics
function Analyzer:get_diagnostics_by_code(story, prefix)
  local all = self:get_all_diagnostics(story)
  local filtered = {}

  for _, d in ipairs(all) do
    if d.code and d.code:sub(1, #prefix) == prefix then
      table.insert(filtered, d)
    end
  end

  return filtered
end

return Analyzer
