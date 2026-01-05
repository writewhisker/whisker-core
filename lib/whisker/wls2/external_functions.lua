--- External Functions Registry for WLS 2.0
--- Allows stories to call host application functions
--- @module whisker.wls2.external_functions

local ExternalFunctions = {
    _VERSION = "2.0.0"
}
ExternalFunctions.__index = ExternalFunctions
ExternalFunctions._dependencies = {}

--- Valid parameter types for external function declarations
local VALID_TYPES = {
    string = true,
    number = true,
    boolean = true,
    any = true
}

--- Parse an external function declaration string
--- @param declaration string The declaration (e.g., "playSound(id: string): void")
--- @return table The parsed declaration with name, params, and returnType
function ExternalFunctions.parseDeclaration(declaration)
    if type(declaration) ~= "string" or declaration == "" then
        error("Declaration must be a non-empty string")
    end

    -- Match function name and parameter list
    local name, params_str, return_type = declaration:match("^([%w_]+)%((.*)%)%s*:%s*(%w+)$")

    if not name then
        -- Try without return type
        name, params_str = declaration:match("^([%w_]+)%((.*)%)$")
        return_type = "void"
    end

    if not name then
        error("Invalid declaration format: " .. declaration)
    end

    local params = {}

    if params_str and params_str ~= "" then
        -- Parse parameters: name: type, name?: type (optional)
        for param in params_str:gmatch("[^,]+") do
            param = param:match("^%s*(.-)%s*$")  -- trim

            local param_name, optional_mark, param_type = param:match("^([%w_]+)(%??):?%s*(%w*)$")

            if param_name then
                local is_optional = optional_mark == "?"
                local ptype = param_type ~= "" and param_type or "any"

                if not VALID_TYPES[ptype] then
                    error("Invalid parameter type: " .. ptype)
                end

                table.insert(params, {
                    name = param_name,
                    type = ptype,
                    optional = is_optional
                })
            end
        end
    end

    return {
        name = name,
        params = params,
        returnType = return_type
    }
end

--- Create a new ExternalFunctions registry
--- @param deps table Optional dependencies
--- @return ExternalFunctions The new registry instance
function ExternalFunctions.new(deps)
    local self = setmetatable({}, ExternalFunctions)
    self._functions = {}      -- name -> function
    self._declarations = {}   -- name -> declaration
    self._deps = deps or {}
    return self
end

--- Register an external function
--- @param name string The function name
--- @param fn function The function to call
function ExternalFunctions:register(name, fn)
    if type(name) ~= "string" or name == "" then
        error("Function name must be a non-empty string")
    end
    if type(fn) ~= "function" then
        error("Handler must be a function")
    end

    self._functions[name] = fn
end

--- Declare a function's signature for type checking
--- @param declaration table|string The declaration object or string
function ExternalFunctions:declare(declaration)
    if type(declaration) == "string" then
        declaration = ExternalFunctions.parseDeclaration(declaration)
    end

    if type(declaration) ~= "table" or not declaration.name then
        error("Invalid declaration")
    end

    self._declarations[declaration.name] = declaration
end

--- Check if a function is registered
--- @param name string The function name
--- @return boolean True if registered
function ExternalFunctions:has(name)
    return self._functions[name] ~= nil
end

--- Validate arguments against a function's declaration
--- @param name string The function name
--- @param args table The arguments to validate
--- @return boolean, string|nil True if valid, or false with error message
function ExternalFunctions:validateArgs(name, args)
    local decl = self._declarations[name]
    if not decl then
        return true  -- No declaration, skip validation
    end

    local required_count = 0
    for _, param in ipairs(decl.params) do
        if not param.optional then
            required_count = required_count + 1
        end
    end

    if #args < required_count then
        return false, string.format(
            "Function '%s' requires at least %d argument(s), got %d",
            name, required_count, #args
        )
    end

    if #args > #decl.params then
        return false, string.format(
            "Function '%s' accepts at most %d argument(s), got %d",
            name, #decl.params, #args
        )
    end

    -- Type check each argument
    for i, arg in ipairs(args) do
        local param = decl.params[i]
        if param and param.type ~= "any" then
            local arg_type = type(arg)
            if arg_type ~= param.type then
                return false, string.format(
                    "Argument %d ('%s') expected %s, got %s",
                    i, param.name, param.type, arg_type
                )
            end
        end
    end

    return true
end

--- Call a registered external function
--- @param name string The function name
--- @param args table The arguments to pass
--- @return any The function's return value
function ExternalFunctions:call(name, args)
    args = args or {}

    local fn = self._functions[name]
    if not fn then
        error("External function not registered: " .. name)
    end

    -- Validate arguments if declaration exists
    local valid, err = self:validateArgs(name, args)
    if not valid then
        error(err)
    end

    -- Call the function with unpacked arguments
    return fn(table.unpack(args))
end

--- Get all registered function names
--- @return table Array of function names
function ExternalFunctions:getRegisteredNames()
    local names = {}
    for name in pairs(self._functions) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

--- Get a function's declaration
--- @param name string The function name
--- @return table|nil The declaration or nil
function ExternalFunctions:getDeclaration(name)
    return self._declarations[name]
end

--- Clear all registered functions and declarations
function ExternalFunctions:clear()
    self._functions = {}
    self._declarations = {}
end

return ExternalFunctions
