--- Story Analyzer - Advanced Validation & Analysis
-- @module whisker.validation.analyzer

local Analyzer = {}
Analyzer.__index = Analyzer

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
  TEMP_CROSS_PASSAGE = "WLS-VAR-008"
}

-- Reserved prefixes for variables
local RESERVED_PREFIXES = { "_", "__", "whisker_", "wls_" }

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
          goto continue
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

        ::continue::
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
    -- Skip system variables
    if SYSTEM_VARIABLES[name] then
      goto continue
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

    ::continue::
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

--- Run all analyses
function Analyzer:analyze(story)
  local var_validation = self:validate_variables(story)
  return {
    dead_ends = self:detect_dead_ends(story),
    orphans = self:detect_orphans(story),
    invalid_links = self:validate_links(story),
    variables = var_validation.variables,
    variable_diagnostics = var_validation.diagnostics,
    accessibility = self:check_accessibility(story),
    flow = self:analyze_flow(story)
  }
end

return Analyzer
