-- Whisker Macro Signature
-- Defines and validates macro argument signatures
-- Supports positional args, named args, optional args, rest params
--
-- lib/whisker/script/macros/signature.lua

local MacroSignature = {}
MacroSignature.__index = MacroSignature

-- Parameter types
MacroSignature.TYPE = {
    ANY = "any",           -- Any value
    STRING = "string",     -- String value
    NUMBER = "number",     -- Numeric value
    BOOLEAN = "boolean",   -- Boolean value
    TABLE = "table",       -- Table/array/datamap
    FUNCTION = "function", -- Function/lambda
    NIL = "nil",           -- Nil/null
    ARRAY = "array",       -- Array (sequential table)
    DATAMAP = "datamap",   -- Datamap (key-value table)
    CHANGER = "changer",   -- Changer function (Harlowe)
    HOOK = "hook",         -- Hook reference (Harlowe)
    PASSAGE = "passage",   -- Passage reference
    VARIABLE = "variable", -- Variable reference
    EXPRESSION = "expression", -- Unevaluated expression
}

-- Parameter modifiers
MacroSignature.MODIFIER = {
    OPTIONAL = "optional",   -- Parameter is optional
    REST = "rest",           -- Collects remaining args
    SPREAD = "spread",       -- Spreads array into args
    NAMED = "named",         -- Named parameter
}

--- Create a new MacroSignature
-- @param params table Array of parameter definitions
-- @return MacroSignature instance
function MacroSignature.new(params)
    local self = setmetatable({}, MacroSignature)

    self._params = {}
    self._named_params = {}
    self._rest_param = nil
    self._min_args = 0
    self._max_args = 0
    self._has_rest = false

    if params then
        self:_parse_params(params)
    end

    return self
end

--- Create a signature from a string definition (shorthand)
-- Format: "name:type?, name:type..." where ? marks optional
-- @param definition string The signature definition
-- @return MacroSignature instance
function MacroSignature.from_string(definition)
    local self = MacroSignature.new()

    if not definition or definition == "" then
        return self
    end

    for part in definition:gmatch("[^,]+") do
        part = part:match("^%s*(.-)%s*$")  -- trim
        local name, type_spec = part:match("^([^:]+):?(.*)$")

        if name then
            name = name:match("^%s*(.-)%s*$")  -- trim

            local optional = name:sub(-1) == "?" or type_spec:sub(-1) == "?"
            if optional then
                name = name:gsub("%?$", "")
                type_spec = type_spec:gsub("%?$", "")
            end

            local rest = name:sub(1, 3) == "..."
            if rest then
                name = name:sub(4)
            end

            local param_type = type_spec ~= "" and type_spec or MacroSignature.TYPE.ANY

            self:add_param({
                name = name,
                type = param_type,
                optional = optional,
                rest = rest,
            })
        end
    end

    return self
end

--- Create a builder for fluent signature construction
-- @return SignatureBuilder
function MacroSignature.builder()
    return setmetatable({
        _params = {},
    }, {
        __index = {
            param = function(self, name, param_type, options)
                options = options or {}
                table.insert(self._params, {
                    name = name,
                    type = param_type or MacroSignature.TYPE.ANY,
                    optional = options.optional,
                    default = options.default,
                    description = options.description,
                    validator = options.validator,
                    rest = options.rest,
                    named = options.named,
                })
                return self
            end,

            required = function(self, name, param_type, description)
                return self:param(name, param_type, {
                    description = description,
                })
            end,

            optional = function(self, name, param_type, default, description)
                return self:param(name, param_type, {
                    optional = true,
                    default = default,
                    description = description,
                })
            end,

            rest = function(self, name, param_type, description)
                return self:param(name, param_type, {
                    rest = true,
                    description = description,
                })
            end,

            named = function(self, name, param_type, options)
                options = options or {}
                options.named = true
                return self:param(name, param_type, options)
            end,

            build = function(self)
                return MacroSignature.new(self._params)
            end,
        }
    })
end

-- ============================================================================
-- Parameter Management
-- ============================================================================

--- Add a parameter to the signature
-- @param param table Parameter definition
-- @return MacroSignature self for chaining
function MacroSignature:add_param(param)
    if type(param) ~= "table" then
        error("Parameter must be a table")
    end

    local p = {
        name = param.name or ("arg" .. (#self._params + 1)),
        type = param.type or MacroSignature.TYPE.ANY,
        types = param.types,  -- Multiple allowed types
        optional = param.optional or false,
        default = param.default,
        rest = param.rest or false,
        named = param.named or false,
        spread = param.spread or false,
        description = param.description or "",
        validator = param.validator,  -- Custom validation function
        transform = param.transform,  -- Transform function
    }

    -- Handle rest parameter
    if p.rest then
        if self._has_rest then
            error("Only one rest parameter allowed")
        end
        self._has_rest = true
        self._rest_param = p
        self._max_args = math.huge
    end

    -- Handle named parameter
    if p.named then
        self._named_params[p.name] = p
    else
        table.insert(self._params, p)

        -- Update argument counts
        if not p.optional and not p.rest then
            self._min_args = self._min_args + 1
        end
        if not p.rest then
            self._max_args = self._max_args + 1
        end
    end

    return self
end

--- Get parameter by index
-- @param index number The parameter index (1-based)
-- @return table|nil The parameter definition
function MacroSignature:get_param(index)
    return self._params[index]
end

--- Get parameter by name
-- @param name string The parameter name
-- @return table|nil The parameter definition
function MacroSignature:get_param_by_name(name)
    -- Check positional params
    for _, param in ipairs(self._params) do
        if param.name == name then
            return param
        end
    end
    -- Check named params
    return self._named_params[name]
end

--- Get all parameters
-- @return table Array of parameter definitions
function MacroSignature:get_params()
    local result = {}
    for _, param in ipairs(self._params) do
        table.insert(result, param)
    end
    return result
end

--- Get all named parameters
-- @return table Map of name -> parameter
function MacroSignature:get_named_params()
    return self._named_params
end

--- Get minimum required arguments
-- @return number
function MacroSignature:get_min_args()
    return self._min_args
end

--- Get maximum allowed arguments
-- @return number (may be math.huge for rest params)
function MacroSignature:get_max_args()
    return self._max_args
end

--- Check if signature has rest parameter
-- @return boolean
function MacroSignature:has_rest()
    return self._has_rest
end

-- ============================================================================
-- Validation
-- ============================================================================

--- Validate arguments against this signature
-- @param args table The arguments to validate
-- @param options table Optional validation options
-- @return boolean, table Success and errors/warnings
function MacroSignature:validate(args, options)
    options = options or {}
    local errors = {}
    local warnings = {}

    args = args or {}
    local positional_args = {}
    local named_args = {}

    -- Separate positional and named arguments
    for k, v in pairs(args) do
        if type(k) == "number" then
            positional_args[k] = v
        else
            named_args[k] = v
        end
    end

    -- Check argument count
    local num_args = #positional_args
    if num_args < self._min_args then
        table.insert(errors, {
            type = "MISSING_ARGUMENT",
            message = string.format("Expected at least %d argument(s), got %d",
                self._min_args, num_args),
            expected = self._min_args,
            actual = num_args,
        })
    end

    if num_args > self._max_args then
        table.insert(errors, {
            type = "TOO_MANY_ARGUMENTS",
            message = string.format("Expected at most %d argument(s), got %d",
                self._max_args, num_args),
            expected = self._max_args,
            actual = num_args,
        })
    end

    -- Validate each positional parameter
    for i, param in ipairs(self._params) do
        if not param.rest then
            local arg = positional_args[i]
            local param_errors = self:_validate_param(param, arg, i)
            for _, err in ipairs(param_errors) do
                table.insert(errors, err)
            end
        end
    end

    -- Validate rest parameter
    if self._rest_param then
        local rest_start = #self._params
        for i = rest_start, num_args do
            local arg = positional_args[i]
            local param_errors = self:_validate_param(self._rest_param, arg, i)
            for _, err in ipairs(param_errors) do
                table.insert(errors, err)
            end
        end
    end

    -- Validate named parameters
    for name, value in pairs(named_args) do
        local param = self._named_params[name]
        if param then
            local param_errors = self:_validate_param(param, value, name)
            for _, err in ipairs(param_errors) do
                table.insert(errors, err)
            end
        elseif not options.allow_extra_named then
            table.insert(warnings, {
                type = "UNKNOWN_PARAMETER",
                message = "Unknown named parameter: " .. name,
                name = name,
            })
        end
    end

    -- Check for missing required named parameters
    for name, param in pairs(self._named_params) do
        if not param.optional and named_args[name] == nil then
            table.insert(errors, {
                type = "MISSING_NAMED_ARGUMENT",
                message = "Missing required named parameter: " .. name,
                name = name,
            })
        end
    end

    return #errors == 0, { errors = errors, warnings = warnings }
end

--- Validate a single parameter
-- @param param table The parameter definition
-- @param value any The value to validate
-- @param position number|string The argument position or name
-- @return table Array of errors
function MacroSignature:_validate_param(param, value, position)
    local errors = {}

    -- Check if value is missing
    if value == nil then
        if not param.optional then
            table.insert(errors, {
                type = "MISSING_ARGUMENT",
                message = string.format("Missing required argument '%s' at position %s",
                    param.name, tostring(position)),
                param = param.name,
                position = position,
            })
        end
        return errors
    end

    -- Check type
    local valid_type = self:_check_type(value, param.type, param.types)
    if not valid_type then
        local expected = param.types
            and table.concat(param.types, "|")
            or param.type
        table.insert(errors, {
            type = "TYPE_MISMATCH",
            message = string.format("Argument '%s' expected type '%s', got '%s'",
                param.name, expected, type(value)),
            param = param.name,
            position = position,
            expected = expected,
            actual = type(value),
        })
    end

    -- Run custom validator if present
    if param.validator and type(param.validator) == "function" then
        local ok, err = param.validator(value, param)
        if not ok then
            table.insert(errors, {
                type = "VALIDATION_FAILED",
                message = err or string.format("Validation failed for '%s'", param.name),
                param = param.name,
                position = position,
            })
        end
    end

    return errors
end

--- Check if value matches expected type(s)
-- @param value any The value to check
-- @param expected_type string The expected type
-- @param allowed_types table Optional array of allowed types
-- @return boolean
function MacroSignature:_check_type(value, expected_type, allowed_types)
    -- Handle multiple allowed types
    if allowed_types then
        for _, t in ipairs(allowed_types) do
            if self:_check_single_type(value, t) then
                return true
            end
        end
        return false
    end

    return self:_check_single_type(value, expected_type)
end

--- Check if value matches a single type
-- @param value any The value
-- @param expected_type string The type
-- @return boolean
function MacroSignature:_check_single_type(value, expected_type)
    if expected_type == MacroSignature.TYPE.ANY then
        return true
    end

    local actual_type = type(value)

    if expected_type == MacroSignature.TYPE.STRING then
        return actual_type == "string"
    elseif expected_type == MacroSignature.TYPE.NUMBER then
        return actual_type == "number"
    elseif expected_type == MacroSignature.TYPE.BOOLEAN then
        return actual_type == "boolean"
    elseif expected_type == MacroSignature.TYPE.TABLE then
        return actual_type == "table"
    elseif expected_type == MacroSignature.TYPE.FUNCTION then
        return actual_type == "function"
    elseif expected_type == MacroSignature.TYPE.NIL then
        return value == nil
    elseif expected_type == MacroSignature.TYPE.ARRAY then
        return actual_type == "table" and self:_is_array(value)
    elseif expected_type == MacroSignature.TYPE.DATAMAP then
        return actual_type == "table" and not self:_is_array(value)
    elseif expected_type == MacroSignature.TYPE.CHANGER then
        return actual_type == "function" or
               (actual_type == "table" and value._is_changer)
    elseif expected_type == MacroSignature.TYPE.HOOK then
        return actual_type == "table" and value._is_hook
    elseif expected_type == MacroSignature.TYPE.PASSAGE then
        return actual_type == "string" or
               (actual_type == "table" and value._is_passage)
    elseif expected_type == MacroSignature.TYPE.VARIABLE then
        return actual_type == "table" and value._is_variable
    elseif expected_type == MacroSignature.TYPE.EXPRESSION then
        return actual_type == "table" and value._is_expression
    end

    return false
end

--- Check if table is an array (sequential integer keys)
-- @param t table The table to check
-- @return boolean
function MacroSignature:_is_array(t)
    if type(t) ~= "table" then
        return false
    end

    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end

    for i = 1, count do
        if t[i] == nil then
            return false
        end
    end

    return true
end

-- ============================================================================
-- Argument Processing
-- ============================================================================

--- Process arguments according to signature (apply defaults, transforms)
-- @param args table The raw arguments
-- @return table Processed arguments
function MacroSignature:process(args)
    args = args or {}
    local result = {}
    local positional_args = {}
    local named_args = {}

    -- Separate positional and named
    for k, v in pairs(args) do
        if type(k) == "number" then
            positional_args[k] = v
        else
            named_args[k] = v
        end
    end

    -- Process positional parameters
    for i, param in ipairs(self._params) do
        if not param.rest then
            local value = positional_args[i]

            -- Apply default if missing
            if value == nil and param.default ~= nil then
                value = param.default
            end

            -- Apply transform
            if value ~= nil and param.transform then
                value = param.transform(value)
            end

            result[i] = value
            result[param.name] = value
        end
    end

    -- Process rest parameter
    if self._rest_param then
        local rest_values = {}
        local rest_start = #self._params
        for i = rest_start, #positional_args do
            local value = positional_args[i]
            if self._rest_param.transform and value ~= nil then
                value = self._rest_param.transform(value)
            end
            table.insert(rest_values, value)
        end
        result[self._rest_param.name] = rest_values
    end

    -- Process named parameters
    for name, param in pairs(self._named_params) do
        local value = named_args[name]

        -- Apply default if missing
        if value == nil and param.default ~= nil then
            value = param.default
        end

        -- Apply transform
        if value ~= nil and param.transform then
            value = param.transform(value)
        end

        result[name] = value
    end

    return result
end

-- ============================================================================
-- Serialization
-- ============================================================================

--- Convert signature to string representation
-- @return string
function MacroSignature:to_string()
    local parts = {}

    for _, param in ipairs(self._params) do
        local str = param.name .. ":" .. param.type
        if param.optional then
            str = str .. "?"
        end
        if param.rest then
            str = "..." .. str
        end
        table.insert(parts, str)
    end

    for name, param in pairs(self._named_params) do
        local str = name .. ":" .. param.type
        if param.optional then
            str = str .. "?"
        end
        table.insert(parts, "[" .. str .. "]")
    end

    return table.concat(parts, ", ")
end

--- Export signature for documentation
-- @return table
function MacroSignature:export()
    local params = {}
    for _, param in ipairs(self._params) do
        table.insert(params, {
            name = param.name,
            type = param.type,
            types = param.types,
            optional = param.optional,
            default = param.default,
            rest = param.rest,
            description = param.description,
        })
    end

    local named = {}
    for name, param in pairs(self._named_params) do
        named[name] = {
            type = param.type,
            types = param.types,
            optional = param.optional,
            default = param.default,
            description = param.description,
        }
    end

    return {
        params = params,
        named = named,
        min_args = self._min_args,
        max_args = self._max_args,
        has_rest = self._has_rest,
    }
end

-- ============================================================================
-- Internal
-- ============================================================================

--- Parse parameter definitions
-- @param params table Array of parameter definitions
function MacroSignature:_parse_params(params)
    for _, param in ipairs(params) do
        if type(param) == "string" then
            -- Simple string format: "name:type?"
            local name, type_spec = param:match("^([^:]+):?(.*)$")
            local optional = name:sub(-1) == "?" or type_spec:sub(-1) == "?"
            name = name:gsub("%?$", "")
            type_spec = type_spec:gsub("%?$", "")
            self:add_param({
                name = name,
                type = type_spec ~= "" and type_spec or MacroSignature.TYPE.ANY,
                optional = optional,
            })
        else
            self:add_param(param)
        end
    end
end

return MacroSignature
