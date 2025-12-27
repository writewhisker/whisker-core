-- Whisker Data Macros
-- Implements data manipulation macros compatible with Twine formats
-- Supports Harlowe, SugarCube, and Chapbook-style data operations
--
-- lib/whisker/script/macros/data/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local Data = {}

--- Module version
Data.VERSION = "1.0.0"

-- ============================================================================
-- Variable Assignment Macros
-- ============================================================================

--- set macro - Assign a value to a variable
-- Harlowe: (set: $var to value)
-- SugarCube: <<set $var to value>>
-- Chapbook: var: value
Data.set_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]
        local value = args[2]

        -- Handle variable name normalization (remove $ prefix)
        if type(name) == "string" then
            name = name:gsub("^%$", "")
        elseif type(name) == "table" and name._is_variable then
            name = name.name
        else
            return nil, "Invalid variable name"
        end

        -- Evaluate value if it's an expression
        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        ctx:set(name, value)
        return value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable name (with or without $)")
            :required("value", "any", "Value to assign")
            :build(),
        description = "Assign a value to a variable",
        format = Macros.FORMAT.WHISKER,
        aliases = { "put" },  -- Harlowe alias
        examples = {
            "(set: $score to 10)",
            "<<set $name to 'Alice'>>",
            "score: 10",
        },
    }
)

--- unset macro - Remove a variable
-- SugarCube: <<unset $var>>
Data.unset_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        elseif type(name) == "table" and name._is_variable then
            name = name.name
        else
            return nil, "Invalid variable name"
        end

        ctx:delete(name)
        return true
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable name to unset")
            :build(),
        description = "Remove a variable",
        format = Macros.FORMAT.SUGARCUBE,
        aliases = { "delete" },
        examples = {
            "<<unset $tempScore>>",
        },
    }
)

--- let macro - Create a temporary variable
-- Creates a variable scoped to the current execution frame
Data.let_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]
        local value = args[2]

        if type(name) == "string" then
            name = name:gsub("^%$", ""):gsub("^_", "")
        elseif type(name) == "table" and name._is_variable then
            name = name.name
        else
            return nil, "Invalid variable name"
        end

        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        ctx:set(name, value, { temp = true })
        return value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable name")
            :required("value", "any", "Value to assign")
            :build(),
        description = "Create a temporary scoped variable",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(let: _temp to $score * 2)",
        },
    }
)

--- move macro - Move value from one variable to another
-- Harlowe: (move: $target to $source)
Data.move_macro = Macros.define_data(
    function(ctx, args)
        local target = args[1]
        local source = args[2]

        if type(target) == "string" then
            target = target:gsub("^%$", "")
        end
        if type(source) == "string" then
            source = source:gsub("^%$", "")
        end

        local value = ctx:get(source)
        ctx:set(target, value)
        ctx:delete(source)

        return value
    end,
    {
        signature = Signature.builder()
            :required("target", "any", "Target variable")
            :required("source", "any", "Source variable")
            :build(),
        description = "Move value from source to target, deleting source",
        format = Macros.FORMAT.HARLOWE,
        examples = {
            "(move: $backup to $score)",
        },
    }
)

-- ============================================================================
-- Arithmetic Update Macros
-- ============================================================================

--- increment macro - Add to a variable
Data.increment_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]
        local amount = args[2] or 1

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        local current = ctx:get(name) or 0
        local new_value = current + amount
        ctx:set(name, new_value)

        return new_value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable to increment")
            :optional("amount", "number", 1, "Amount to add")
            :build(),
        description = "Add to a numeric variable",
        format = Macros.FORMAT.WHISKER,
        aliases = { "add" },
        examples = {
            "(increment: $score)",
            "(increment: $score, 10)",
        },
    }
)

--- decrement macro - Subtract from a variable
Data.decrement_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]
        local amount = args[2] or 1

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        local current = ctx:get(name) or 0
        local new_value = current - amount
        ctx:set(name, new_value)

        return new_value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable to decrement")
            :optional("amount", "number", 1, "Amount to subtract")
            :build(),
        description = "Subtract from a numeric variable",
        format = Macros.FORMAT.WHISKER,
        aliases = { "subtract" },
        examples = {
            "(decrement: $health)",
            "(decrement: $health, 10)",
        },
    }
)

--- multiply macro - Multiply a variable
Data.multiply_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]
        local factor = args[2]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        local current = ctx:get(name) or 0
        local new_value = current * factor
        ctx:set(name, new_value)

        return new_value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable to multiply")
            :required("factor", "number", "Factor to multiply by")
            :build(),
        description = "Multiply a numeric variable",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(multiply: $score, 2)",
        },
    }
)

--- divide macro - Divide a variable
Data.divide_macro = Macros.define_data(
    function(ctx, args)
        local name = args[1]
        local divisor = args[2]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        if divisor == 0 then
            return nil, "Division by zero"
        end

        local current = ctx:get(name) or 0
        local new_value = current / divisor
        ctx:set(name, new_value)

        return new_value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable to divide")
            :required("divisor", "number", "Divisor")
            :build(),
        description = "Divide a numeric variable",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(divide: $score, 2)",
        },
    }
)

-- ============================================================================
-- Array Macros
-- ============================================================================

--- a / array macro - Create an array
-- Harlowe: (a: 1, 2, 3) or (array: 1, 2, 3)
Data.array_macro = Macros.define_data(
    function(ctx, args)
        local result = {}
        for i, v in ipairs(args) do
            if type(v) == "table" and v._is_expression then
                result[i] = ctx:eval(v)
            else
                result[i] = v
            end
        end
        return result
    end,
    {
        signature = Signature.builder()
            :rest("values", "any", "Values to include in array")
            :build(),
        description = "Create an array from values",
        format = Macros.FORMAT.HARLOWE,
        aliases = { "a" },
        pure = true,
        examples = {
            "(a: 1, 2, 3)",
            "(array: 'red', 'green', 'blue')",
        },
    }
)

--- push macro - Add item to end of array
Data.push_macro = Macros.define_data(
    function(ctx, args)
        local arr_name = args[1]
        local value = args[2]

        if type(arr_name) == "string" then
            arr_name = arr_name:gsub("^%$", "")
        end

        local arr = ctx:get(arr_name) or {}
        if type(arr) ~= "table" then
            arr = { arr }
        end

        table.insert(arr, value)
        ctx:set(arr_name, arr)

        return arr
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array variable")
            :required("value", "any", "Value to add")
            :build(),
        description = "Add item to end of array",
        format = Macros.FORMAT.WHISKER,
        aliases = { "append" },
        examples = {
            "(push: $inventory, 'sword')",
        },
    }
)

--- pop macro - Remove and return last item
Data.pop_macro = Macros.define_data(
    function(ctx, args)
        local arr_name = args[1]

        if type(arr_name) == "string" then
            arr_name = arr_name:gsub("^%$", "")
        end

        local arr = ctx:get(arr_name)
        if type(arr) ~= "table" or #arr == 0 then
            return nil
        end

        local value = table.remove(arr)
        ctx:set(arr_name, arr)

        return value
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array variable")
            :build(),
        description = "Remove and return last item from array",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(pop: $stack)",
        },
    }
)

--- unshift macro - Add item to beginning of array
Data.unshift_macro = Macros.define_data(
    function(ctx, args)
        local arr_name = args[1]
        local value = args[2]

        if type(arr_name) == "string" then
            arr_name = arr_name:gsub("^%$", "")
        end

        local arr = ctx:get(arr_name) or {}
        if type(arr) ~= "table" then
            arr = { arr }
        end

        table.insert(arr, 1, value)
        ctx:set(arr_name, arr)

        return arr
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array variable")
            :required("value", "any", "Value to add")
            :build(),
        description = "Add item to beginning of array",
        format = Macros.FORMAT.WHISKER,
        aliases = { "prepend" },
        examples = {
            "(unshift: $queue, 'first')",
        },
    }
)

--- shift macro - Remove and return first item
Data.shift_macro = Macros.define_data(
    function(ctx, args)
        local arr_name = args[1]

        if type(arr_name) == "string" then
            arr_name = arr_name:gsub("^%$", "")
        end

        local arr = ctx:get(arr_name)
        if type(arr) ~= "table" or #arr == 0 then
            return nil
        end

        local value = table.remove(arr, 1)
        ctx:set(arr_name, arr)

        return value
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array variable")
            :build(),
        description = "Remove and return first item from array",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(shift: $queue)",
        },
    }
)

--- slice macro - Get portion of array
Data.slice_macro = Macros.define_data(
    function(ctx, args)
        local arr = args[1]
        local start_idx = args[2] or 1
        local end_idx = args[3]

        if type(arr) == "string" then
            arr = ctx:get(arr:gsub("^%$", ""))
        end

        if type(arr) ~= "table" then
            return {}
        end

        end_idx = end_idx or #arr

        local result = {}
        for i = start_idx, end_idx do
            if arr[i] ~= nil then
                table.insert(result, arr[i])
            end
        end

        return result
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array to slice")
            :optional("start", "number", 1, "Start index")
            :optional("end_idx", "number", nil, "End index (inclusive)")
            :build(),
        description = "Get a portion of an array",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(slice: $items, 2, 5)",
        },
    }
)

--- contains macro - Check if array contains value
Data.contains_macro = Macros.define_data(
    function(ctx, args)
        local arr = args[1]
        local value = args[2]

        if type(arr) == "string" then
            arr = ctx:get(arr:gsub("^%$", ""))
        end

        if type(arr) ~= "table" then
            return false
        end

        for _, v in ipairs(arr) do
            if v == value then
                return true
            end
        end

        return false
    end,
    {
        signature = Signature.builder()
            :required("array", "any", "Array to search")
            :required("value", "any", "Value to find")
            :build(),
        description = "Check if array contains a value",
        format = Macros.FORMAT.HARLOWE,
        pure = true,
        examples = {
            "(if: (contains: $inventory, 'key'))[You have the key!]",
        },
    }
)

--- length macro - Get array or string length
Data.length_macro = Macros.define_data(
    function(ctx, args)
        local value = args[1]

        if type(value) == "string" then
            -- Could be a variable name or actual string
            if value:match("^%$") then
                value = ctx:get(value:gsub("^%$", ""))
            end
        end

        if type(value) == "table" then
            return #value
        elseif type(value) == "string" then
            return #value
        end

        return 0
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Array or string")
            :build(),
        description = "Get length of array or string",
        format = Macros.FORMAT.WHISKER,
        aliases = { "count" },
        pure = true,
        examples = {
            "(length: $inventory)",
            "(count: 'hello')",
        },
    }
)

-- ============================================================================
-- Datamap Macros
-- ============================================================================

--- dm / datamap macro - Create a datamap (key-value object)
-- Harlowe: (dm: 'key1', value1, 'key2', value2)
Data.datamap_macro = Macros.define_data(
    function(ctx, args)
        local result = {}

        -- Process key-value pairs
        for i = 1, #args, 2 do
            local key = args[i]
            local value = args[i + 1]

            if type(key) == "table" and key._is_expression then
                key = ctx:eval(key)
            end
            if type(value) == "table" and value._is_expression then
                value = ctx:eval(value)
            end

            if key ~= nil then
                result[tostring(key)] = value
            end
        end

        return result
    end,
    {
        signature = Signature.builder()
            :rest("pairs", "any", "Key-value pairs")
            :build(),
        description = "Create a datamap from key-value pairs",
        format = Macros.FORMAT.HARLOWE,
        aliases = { "dm", "map", "object" },
        pure = true,
        examples = {
            "(dm: 'name', 'Alice', 'age', 30)",
        },
    }
)

--- get macro - Get value from datamap
Data.get_macro = Macros.define_data(
    function(ctx, args)
        local map = args[1]
        local key = args[2]

        if type(map) == "string" then
            map = ctx:get(map:gsub("^%$", ""))
        end

        if type(map) ~= "table" then
            return nil
        end

        return map[tostring(key)]
    end,
    {
        signature = Signature.builder()
            :required("map", "any", "Datamap")
            :required("key", "any", "Key to get")
            :build(),
        description = "Get value from datamap by key",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(get: $player, 'name')",
        },
    }
)

--- put macro - Set value in datamap
Data.put_macro = Macros.define_data(
    function(ctx, args)
        local map_name = args[1]
        local key = args[2]
        local value = args[3]

        if type(map_name) == "string" then
            map_name = map_name:gsub("^%$", "")
        end

        local map = ctx:get(map_name)
        if type(map) ~= "table" then
            map = {}
        end

        map[tostring(key)] = value
        ctx:set(map_name, map)

        return map
    end,
    {
        signature = Signature.builder()
            :required("map", "any", "Datamap variable")
            :required("key", "any", "Key to set")
            :required("value", "any", "Value to set")
            :build(),
        description = "Set value in datamap by key",
        format = Macros.FORMAT.WHISKER,
        examples = {
            "(put: $player, 'score', 100)",
        },
    }
)

--- keys macro - Get all keys from datamap
Data.keys_macro = Macros.define_data(
    function(ctx, args)
        local map = args[1]

        if type(map) == "string" then
            map = ctx:get(map:gsub("^%$", ""))
        end

        if type(map) ~= "table" then
            return {}
        end

        local result = {}
        for k, _ in pairs(map) do
            table.insert(result, k)
        end
        table.sort(result)

        return result
    end,
    {
        signature = Signature.builder()
            :required("map", "any", "Datamap")
            :build(),
        description = "Get all keys from a datamap",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(keys: $player)",
        },
    }
)

--- values macro - Get all values from datamap
Data.values_macro = Macros.define_data(
    function(ctx, args)
        local map = args[1]

        if type(map) == "string" then
            map = ctx:get(map:gsub("^%$", ""))
        end

        if type(map) ~= "table" then
            return {}
        end

        local result = {}
        for _, v in pairs(map) do
            table.insert(result, v)
        end

        return result
    end,
    {
        signature = Signature.builder()
            :required("map", "any", "Datamap")
            :build(),
        description = "Get all values from a datamap",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(values: $player)",
        },
    }
)

--- has macro - Check if datamap has key
Data.has_macro = Macros.define_data(
    function(ctx, args)
        local map = args[1]
        local key = args[2]

        if type(map) == "string" then
            map = ctx:get(map:gsub("^%$", ""))
        end

        if type(map) ~= "table" then
            return false
        end

        return map[tostring(key)] ~= nil
    end,
    {
        signature = Signature.builder()
            :required("map", "any", "Datamap")
            :required("key", "any", "Key to check")
            :build(),
        description = "Check if datamap has a key",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(if: (has: $player, 'weapon'))[Armed!]",
        },
    }
)

--- merge macro - Merge multiple datamaps
Data.merge_macro = Macros.define_data(
    function(ctx, args)
        local result = {}

        for _, map in ipairs(args) do
            if type(map) == "string" then
                map = ctx:get(map:gsub("^%$", ""))
            end

            if type(map) == "table" then
                for k, v in pairs(map) do
                    result[k] = v
                end
            end
        end

        return result
    end,
    {
        signature = Signature.builder()
            :rest("maps", "any", "Datamaps to merge")
            :build(),
        description = "Merge multiple datamaps",
        format = Macros.FORMAT.WHISKER,
        pure = true,
        examples = {
            "(merge: $defaults, $overrides)",
        },
    }
)

-- ============================================================================
-- Type Conversion Macros
-- ============================================================================

--- num / number macro - Convert to number
Data.num_macro = Macros.define_data(
    function(ctx, args)
        local value = args[1]

        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        return tonumber(value)
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to convert")
            :build(),
        description = "Convert value to number",
        format = Macros.FORMAT.HARLOWE,
        aliases = { "number", "int" },
        pure = true,
        examples = {
            "(num: '42')",
        },
    }
)

--- str / string macro - Convert to string
Data.str_macro = Macros.define_data(
    function(ctx, args)
        local value = args[1]

        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        return tostring(value)
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to convert")
            :build(),
        description = "Convert value to string",
        format = Macros.FORMAT.HARLOWE,
        aliases = { "string", "text" },
        pure = true,
        examples = {
            "(str: 42)",
        },
    }
)

--- bool macro - Convert to boolean
Data.bool_macro = Macros.define_data(
    function(ctx, args)
        local value = args[1]

        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        if value == nil or value == false or value == 0 or value == "" then
            return false
        end

        return true
    end,
    {
        signature = Signature.builder()
            :required("value", "any", "Value to convert")
            :build(),
        description = "Convert value to boolean",
        format = Macros.FORMAT.WHISKER,
        aliases = { "boolean" },
        pure = true,
        examples = {
            "(bool: $value)",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all data macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function Data.register_all(registry)
    local macros = {
        -- Variable assignment
        ["set"] = Data.set_macro,
        ["unset"] = Data.unset_macro,
        ["let"] = Data.let_macro,
        ["move"] = Data.move_macro,

        -- Arithmetic
        ["increment"] = Data.increment_macro,
        ["decrement"] = Data.decrement_macro,
        ["multiply"] = Data.multiply_macro,
        ["divide"] = Data.divide_macro,

        -- Arrays
        ["array"] = Data.array_macro,
        ["push"] = Data.push_macro,
        ["pop"] = Data.pop_macro,
        ["unshift"] = Data.unshift_macro,
        ["shift"] = Data.shift_macro,
        ["slice"] = Data.slice_macro,
        ["contains"] = Data.contains_macro,
        ["length"] = Data.length_macro,

        -- Datamaps
        ["datamap"] = Data.datamap_macro,
        ["get"] = Data.get_macro,
        ["put_key"] = Data.put_macro,
        ["keys"] = Data.keys_macro,
        ["values"] = Data.values_macro,
        ["has"] = Data.has_macro,
        ["merge"] = Data.merge_macro,

        -- Type conversion
        ["num"] = Data.num_macro,
        ["str"] = Data.str_macro,
        ["bool"] = Data.bool_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return Data
