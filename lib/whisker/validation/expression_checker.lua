--- Expression Checker - Type checking for WLS expressions
-- @module whisker.validation.expression_checker
-- WLS 1.0.0 GAP-015: Expression Errors (EXP)

local ExpressionChecker = {}
ExpressionChecker.__index = ExpressionChecker

-- Known global functions available in expressions
ExpressionChecker.KNOWN_FUNCTIONS = {
    -- Built-in Lua
    "tostring", "tonumber", "type",
    -- WLS utilities (GAP-007, GAP-018)
    "visited", "visits", "pick", "random", "turns", "current", "previous",
    -- Math functions
    "math.abs", "math.floor", "math.ceil", "math.max", "math.min", "math.random",
    "math.sqrt", "math.pow", "math.fmod",
    -- String functions
    "string.len", "string.upper", "string.lower", "string.sub", "string.find",
    "string.match", "string.gsub", "string.rep", "string.reverse", "string.format",
}

--- Create a new ExpressionChecker instance
-- @param context table Optional context with variables, custom_functions
-- @return ExpressionChecker instance
function ExpressionChecker.new(context)
    local self = setmetatable({}, ExpressionChecker)
    self.context = context or {}
    self.variables = context.variables or {}
    self.custom_functions = context.custom_functions or {}
    self.diagnostics = {}
    return self
end

--- Check an expression AST node for type errors
-- @param expr table AST node
-- @return table Array of diagnostics
function ExpressionChecker:check(expr)
    self.diagnostics = {}
    self:check_node(expr)
    return self.diagnostics
end

--- Check a single AST node
-- @param node table The AST node to check
function ExpressionChecker:check_node(node)
    if not node or type(node) ~= "table" then
        return
    end

    if node.type == "binary_expression" then
        self:check_binary_expression(node)
    elseif node.type == "unary_expression" then
        self:check_unary_expression(node)
    elseif node.type == "call_expression" then
        self:check_call_expression(node)
    elseif node.type == "member_expression" then
        self:check_member_expression(node)
    elseif node.type == "assignment_expression" then
        self:check_assignment_expression(node)
    end
end

--- Check binary expression for type compatibility
-- @param node table Binary expression AST node
function ExpressionChecker:check_binary_expression(node)
    local op = node.operator
    local left_type = self:infer_type(node.left)
    local right_type = self:infer_type(node.right)

    -- Check operand types recursively
    self:check_node(node.left)
    self:check_node(node.right)

    -- Arithmetic operators require numbers
    if op:match("[+%-%*/%%]") then
        if left_type and left_type ~= "number" and left_type ~= "unknown" then
            self:add_diagnostic("WLS-EXP-001",
                string.format("Left operand of '%s' must be number, got %s", op, left_type),
                node.left.location
            )
        end
        if right_type and right_type ~= "number" and right_type ~= "unknown" then
            self:add_diagnostic("WLS-EXP-001",
                string.format("Right operand of '%s' must be number, got %s", op, right_type),
                node.right.location
            )
        end

        -- Division by zero check (static detection)
        if op == "/" and self:is_zero_literal(node.right) then
            self:add_diagnostic("WLS-EXP-003",
                "Division by zero",
                node.location,
                "warning"
            )
        end
    end

    -- String concatenation (..)
    if op == ".." then
        if left_type and left_type ~= "string" and left_type ~= "number" and left_type ~= "unknown" then
            self:add_diagnostic("WLS-EXP-002",
                string.format("Cannot concatenate type %s", left_type),
                node.left.location
            )
        end
        if right_type and right_type ~= "string" and right_type ~= "number" and right_type ~= "unknown" then
            self:add_diagnostic("WLS-EXP-002",
                string.format("Cannot concatenate type %s", right_type),
                node.right.location
            )
        end
    end

    -- Comparison operators - warn on type mismatch (but allow for duck typing)
    if op:match("[<>=]") or op == "==" or op == "~=" then
        if left_type and right_type and left_type ~= "unknown" and right_type ~= "unknown" then
            if left_type ~= right_type then
                self:add_diagnostic("WLS-EXP-001",
                    string.format("Comparing different types: %s and %s", left_type, right_type),
                    node.location,
                    "warning"
                )
            end
        end
    end
end

--- Check unary expression
-- @param node table Unary expression AST node
function ExpressionChecker:check_unary_expression(node)
    local op = node.operator
    local operand_type = self:infer_type(node.argument)

    self:check_node(node.argument)

    -- Negation requires number
    if op == "-" then
        if operand_type and operand_type ~= "number" and operand_type ~= "unknown" then
            self:add_diagnostic("WLS-EXP-001",
                string.format("Cannot negate type %s", operand_type),
                node.location
            )
        end
    end

    -- Logical not works on any type (Lua/WLS semantics)
end

--- Check function call
-- @param node table Call expression AST node
function ExpressionChecker:check_call_expression(node)
    local func_name = self:get_function_name(node.callee)

    if func_name then
        -- Check if function is known
        local is_known = false
        for _, known in ipairs(self.KNOWN_FUNCTIONS) do
            if known == func_name then
                is_known = true
                break
            end
        end

        -- Check custom functions
        if not is_known and self.custom_functions then
            if self.custom_functions[func_name] then
                is_known = true
            end
        end

        if not is_known then
            self:add_diagnostic("WLS-EXP-004",
                string.format("Unknown function: %s", func_name),
                node.callee.location
            )
        end
    end

    -- Check arguments recursively
    if node.arguments then
        for _, arg in ipairs(node.arguments) do
            self:check_node(arg)
        end
    end
end

--- Check member/property access
-- @param node table Member expression AST node
function ExpressionChecker:check_member_expression(node)
    local obj_type = self:infer_type(node.object)

    self:check_node(node.object)

    -- Check if object can have properties
    if obj_type and obj_type ~= "table" and obj_type ~= "object" and obj_type ~= "unknown" then
        self:add_diagnostic("WLS-EXP-005",
            string.format("Cannot access property on type %s", obj_type),
            node.location
        )
    end
end

--- Check assignment expression
-- @param node table Assignment expression AST node
function ExpressionChecker:check_assignment_expression(node)
    self:check_node(node.value)
    -- Could add type checking for assignments in the future
end

--- Infer the type of an expression
-- @param node table AST node
-- @return string|nil Type name
function ExpressionChecker:infer_type(node)
    if not node then return nil end

    if node.type == "literal" then
        if node.value_type then
            return node.value_type
        elseif type(node.value) == "number" then
            return "number"
        elseif type(node.value) == "string" then
            return "string"
        elseif type(node.value) == "boolean" then
            return "boolean"
        elseif node.value == nil then
            return "nil"
        end
    elseif node.type == "variable" or node.type == "identifier" then
        local name = node.name
        local var_info = self.variables[name]
        if var_info and var_info.inferred_type then
            return var_info.inferred_type
        end
        return "unknown"
    elseif node.type == "binary_expression" then
        local op = node.operator
        if op:match("[+%-%*/%%]") then
            return "number"
        elseif op:match("[<>=]") or op == "==" or op == "~=" or op == "and" or op == "or" then
            return "boolean"
        elseif op == ".." then
            return "string"
        end
    elseif node.type == "unary_expression" then
        if node.operator == "not" then
            return "boolean"
        elseif node.operator == "-" then
            return "number"
        elseif node.operator == "#" then
            return "number"
        end
    elseif node.type == "call_expression" then
        -- Could add return type inference for known functions
        return "unknown"
    elseif node.type == "member_expression" then
        return "unknown"
    end

    return "unknown"
end

--- Check if node is a zero literal
-- @param node table AST node
-- @return boolean
function ExpressionChecker:is_zero_literal(node)
    return node and node.type == "literal" and
           type(node.value) == "number" and
           node.value == 0
end

--- Get function name from callee node
-- @param node table AST node
-- @return string|nil Function name
function ExpressionChecker:get_function_name(node)
    if not node then return nil end

    if node.type == "identifier" then
        return node.name
    elseif node.type == "variable" then
        return node.name
    elseif node.type == "member_expression" then
        local obj = self:get_function_name(node.object)
        local prop = node.property
        if type(prop) == "table" then
            prop = prop.name or prop.value
        end
        if obj and prop then
            return obj .. "." .. prop
        end
    end
    return nil
end

--- Add a diagnostic
-- @param code string Error code
-- @param message string Error message
-- @param location table|nil Location information
-- @param severity string|nil "error" or "warning" (default "error")
function ExpressionChecker:add_diagnostic(code, message, location, severity)
    table.insert(self.diagnostics, {
        code = code,
        message = message,
        location = location,
        severity = severity or "error"
    })
end

--- Reset the checker state
function ExpressionChecker:reset()
    self.diagnostics = {}
end

--- Set variables for type inference
-- @param variables table Variable information table
function ExpressionChecker:set_variables(variables)
    self.variables = variables or {}
end

--- Add custom functions
-- @param functions table Custom function names table
function ExpressionChecker:add_custom_functions(functions)
    for name, info in pairs(functions or {}) do
        self.custom_functions[name] = info
    end
end

return ExpressionChecker
