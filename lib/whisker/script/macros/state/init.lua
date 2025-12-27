-- Whisker State & Save Macros
-- Implements state persistence, save/load, and undo/redo macros
-- Compatible with Twine save system patterns
--
-- lib/whisker/script/macros/state/init.lua

local Macros = require("whisker.script.macros")
local Signature = Macros.Signature

local State = {}

--- Module version
State.VERSION = "1.0.0"

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Export all variables from context as a table
-- @param ctx MacroContext The context
-- @return table All variable names and values
local function export_state(ctx)
    local state = {}
    local names = ctx:get_variable_names()
    for _, name in ipairs(names) do
        state[name] = ctx:get(name)
    end
    return state
end

-- ============================================================================
-- Save System Macros
-- ============================================================================

--- save macro - Save game state to a slot
-- SugarCube: Save.slots.save(slot)
State.save_macro = Macros.define(
    function(ctx, args)
        local slot = args[1] or "auto"
        local title = args[2] or ""
        local metadata = args[3] or {}

        -- Get current state to save
        local state_data = export_state(ctx)

        local save_data = {
            _type = "save",
            slot = slot,
            title = title,
            metadata = metadata,
            state = state_data,
            timestamp = os.time(),
            passage = ctx:get("_current_passage"),
        }

        -- Emit event for client-side save handling
        ctx:_emit_event("SAVE_GAME", save_data)

        return save_data
    end,
    {
        signature = Signature.builder()
            :optional("slot", "any", "auto", "Save slot identifier")
            :optional("title", "string", "", "Save title/description")
            :optional("metadata", "table", {}, "Additional metadata")
            :build(),
        description = "Save game state to a slot",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        aliases = { "savegame" },
        examples = {
            "(save:)",
            "(save: 1, 'Chapter 1 Complete')",
            "(save: 'quicksave')",
        },
    }
)

--- load macro - Load game state from a slot
-- SugarCube: Save.slots.load(slot)
State.load_macro = Macros.define(
    function(ctx, args)
        local slot = args[1] or "auto"

        local load_data = {
            _type = "load",
            slot = slot,
        }

        -- Emit event for client-side load handling
        ctx:_emit_event("LOAD_GAME", load_data)

        return load_data
    end,
    {
        signature = Signature.builder()
            :optional("slot", "any", "auto", "Save slot to load")
            :build(),
        description = "Load game state from a slot",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        aliases = { "loadgame", "restore" },
        async = true,
        examples = {
            "(load:)",
            "(load: 1)",
            "(load: 'quicksave')",
        },
    }
)

--- savedgames macro - List all saved games
State.savedgames_macro = Macros.define(
    function(ctx, args)
        local filter = args[1]

        local query_data = {
            _type = "savedgames_query",
            query = "list",
            filter = filter,
        }

        ctx:_emit_event("QUERY_SAVES", query_data)

        return query_data
    end,
    {
        signature = Signature.builder()
            :optional("filter", "string", nil, "Filter pattern for slot names")
            :build(),
        description = "List all saved games",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(savedgames:)",
        },
    }
)

--- deletesave macro - Delete a saved game
State.deletesave_macro = Macros.define(
    function(ctx, args)
        local slot = args[1]

        if slot == nil then
            return nil, "Slot identifier required"
        end

        local delete_data = {
            _type = "delete_save",
            slot = slot,
        }

        ctx:_emit_event("DELETE_SAVE", delete_data)

        return delete_data
    end,
    {
        signature = Signature.builder()
            :required("slot", "any", "Save slot to delete")
            :build(),
        description = "Delete a saved game",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(deletesave: 1)",
            "(deletesave: 'quicksave')",
        },
    }
)

--- saveexists macro - Check if a save exists
State.saveexists_macro = Macros.define(
    function(ctx, args)
        local slot = args[1]

        local query_data = {
            _type = "save_query",
            query = "exists",
            slot = slot,
        }

        ctx:_emit_event("QUERY_SAVE", query_data)

        return query_data
    end,
    {
        signature = Signature.builder()
            :required("slot", "any", "Save slot to check")
            :build(),
        description = "Check if a save exists",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(if: (saveexists: 'auto'))[Continue]",
        },
    }
)

--- autosave macro - Configure or trigger autosave
State.autosave_macro = Macros.define(
    function(ctx, args)
        local action = args[1] or "save"
        local options = args[2] or {}

        local autosave_data = {
            _type = "autosave",
            action = action,
            options = options,
        }

        if action == "save" then
            autosave_data.state = export_state(ctx)
            autosave_data.timestamp = os.time()
            autosave_data.passage = ctx:get("_current_passage")
        end

        ctx:_emit_event("AUTOSAVE", autosave_data)

        return autosave_data
    end,
    {
        signature = Signature.builder()
            :optional("action", "string", "save", "Action: save, enable, disable, config")
            :optional("options", "table", {}, "Configuration options")
            :build(),
        description = "Configure or trigger autosave",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(autosave:)",
            "(autosave: 'disable')",
            "(autosave: 'config', (dm: 'interval', 60))",
        },
    }
)

-- ============================================================================
-- Persistent State Macros (Cross-Session)
-- ============================================================================

--- remember macro - Save value persistently across sessions
-- SugarCube: memorize
State.remember_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local value = args[2]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        -- Evaluate expression if needed
        if type(value) == "table" and value._is_expression then
            value = ctx:eval(value)
        end

        local remember_data = {
            _type = "remember",
            key = name,
            value = value,
        }

        -- Also store in context with special prefix
        ctx:set("_persistent_" .. name, value)

        ctx:_emit_event("REMEMBER", remember_data)

        return value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Key to remember")
            :required("value", "any", "Value to store")
            :build(),
        description = "Save value persistently across sessions",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.DATA,
        aliases = { "memorize" },
        examples = {
            "(remember: 'highscore', $score)",
            "(memorize: 'playerName', $name)",
        },
    }
)

--- forget macro - Remove a remembered value
State.forget_macro = Macros.define(
    function(ctx, args)
        local name = args[1]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        local forget_data = {
            _type = "forget",
            key = name,
        }

        -- Remove from context
        ctx:delete("_persistent_" .. name)

        ctx:_emit_event("FORGET", forget_data)

        return true
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Key to forget")
            :build(),
        description = "Remove a remembered value",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(forget: 'highscore')",
        },
    }
)

--- recall macro - Get a remembered value
State.recall_macro = Macros.define(
    function(ctx, args)
        local name = args[1]
        local default = args[2]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        local recall_data = {
            _type = "recall",
            key = name,
            default = default,
        }

        -- Try to get from context first
        local value = ctx:get("_persistent_" .. name)
        if value == nil then
            value = default
        end

        recall_data.value = value

        ctx:_emit_event("RECALL", recall_data)

        return value
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Key to recall")
            :optional("default", "any", nil, "Default value if not found")
            :build(),
        description = "Get a remembered value",
        format = Macros.FORMAT.SUGARCUBE,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(recall: 'highscore', 0)",
        },
    }
)

--- forgetall macro - Clear all remembered values
State.forgetall_macro = Macros.define(
    function(ctx, args)
        local forgetall_data = {
            _type = "forgetall",
        }

        -- Clear all persistent values from context
        local state = export_state(ctx)
        for key, _ in pairs(state) do
            if key:match("^_persistent_") then
                ctx:delete(key)
            end
        end

        ctx:_emit_event("FORGET_ALL", forgetall_data)

        return true
    end,
    {
        signature = Signature.builder():build(),
        description = "Clear all remembered values",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(forgetall:)",
        },
    }
)

-- ============================================================================
-- Undo/Redo Macros
-- ============================================================================

--- checkpoint macro - Create a save point for undo
State.checkpoint_macro = Macros.define(
    function(ctx, args)
        local label = args[1] or ""

        local checkpoint_data = {
            _type = "checkpoint",
            label = label,
            state = export_state(ctx),
            timestamp = os.time(),
            passage = ctx:get("_current_passage"),
        }

        -- Store in undo stack
        local undo_stack = ctx:get("_undo_stack") or {}
        table.insert(undo_stack, checkpoint_data)

        -- Limit stack size
        local max_checkpoints = ctx:get("_max_checkpoints") or 20
        while #undo_stack > max_checkpoints do
            table.remove(undo_stack, 1)
        end

        ctx:set("_undo_stack", undo_stack)

        -- Clear redo stack when creating new checkpoint
        ctx:set("_redo_stack", {})

        ctx:_emit_event("CHECKPOINT", checkpoint_data)

        return checkpoint_data
    end,
    {
        signature = Signature.builder()
            :optional("label", "string", "", "Optional label for checkpoint")
            :build(),
        description = "Create a save point for undo",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(checkpoint:)",
            "(checkpoint: 'Before battle')",
        },
    }
)

--- undo macro - Undo to last checkpoint
State.undo_macro = Macros.define(
    function(ctx, args)
        local undo_stack = ctx:get("_undo_stack") or {}

        if #undo_stack == 0 then
            return nil, "Nothing to undo"
        end

        -- Save current state to redo stack
        local redo_stack = ctx:get("_redo_stack") or {}
        table.insert(redo_stack, {
            state = export_state(ctx),
            timestamp = os.time(),
            passage = ctx:get("_current_passage"),
        })
        ctx:set("_redo_stack", redo_stack)

        -- Pop from undo stack
        local checkpoint = table.remove(undo_stack)
        ctx:set("_undo_stack", undo_stack)

        local undo_data = {
            _type = "undo",
            checkpoint = checkpoint,
        }

        ctx:_emit_event("UNDO", undo_data)

        return undo_data
    end,
    {
        signature = Signature.builder():build(),
        description = "Undo to last checkpoint",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        async = true,
        examples = {
            "(undo:)",
        },
    }
)

--- redo macro - Redo undone action
State.redo_macro = Macros.define(
    function(ctx, args)
        local redo_stack = ctx:get("_redo_stack") or {}

        if #redo_stack == 0 then
            return nil, "Nothing to redo"
        end

        -- Save current state to undo stack
        local undo_stack = ctx:get("_undo_stack") or {}
        table.insert(undo_stack, {
            state = export_state(ctx),
            timestamp = os.time(),
            passage = ctx:get("_current_passage"),
        })
        ctx:set("_undo_stack", undo_stack)

        -- Pop from redo stack
        local redo_point = table.remove(redo_stack)
        ctx:set("_redo_stack", redo_stack)

        local redo_data = {
            _type = "redo",
            checkpoint = redo_point,
        }

        ctx:_emit_event("REDO", redo_data)

        return redo_data
    end,
    {
        signature = Signature.builder():build(),
        description = "Redo undone action",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        async = true,
        examples = {
            "(redo:)",
        },
    }
)

--- history macro - Get navigation/undo history
State.history_macro = Macros.define(
    function(ctx, args)
        local history_type = args[1] or "undo"

        local history_data = {
            _type = "history",
            history_type = history_type,
        }

        if history_type == "undo" then
            history_data.items = ctx:get("_undo_stack") or {}
        elseif history_type == "redo" then
            history_data.items = ctx:get("_redo_stack") or {}
        elseif history_type == "passages" then
            history_data.items = ctx:get("_passage_history") or {}
        else
            history_data.items = {}
        end

        history_data.count = #history_data.items

        return history_data
    end,
    {
        signature = Signature.builder()
            :optional("type", "string", "undo", "History type: undo, redo, passages")
            :build(),
        description = "Get navigation/undo history",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(history:)",
            "(history: 'passages')",
        },
    }
)

--- canundo macro - Check if undo is available
State.canundo_macro = Macros.define(
    function(ctx, args)
        local undo_stack = ctx:get("_undo_stack") or {}
        return #undo_stack > 0
    end,
    {
        signature = Signature.builder():build(),
        description = "Check if undo is available",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(if: (canundo:))[<<link 'Undo'>>(undo:)<</link>>]",
        },
    }
)

--- canredo macro - Check if redo is available
State.canredo_macro = Macros.define(
    function(ctx, args)
        local redo_stack = ctx:get("_redo_stack") or {}
        return #redo_stack > 0
    end,
    {
        signature = Signature.builder():build(),
        description = "Check if redo is available",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(if: (canredo:))[<<link 'Redo'>>(redo:)<</link>>]",
        },
    }
)

-- ============================================================================
-- State Management Macros
-- ============================================================================

--- clearall macro - Clear all story variables
State.clearall_macro = Macros.define(
    function(ctx, args)
        local preserve = args[1] or {}

        -- Convert preserve to a set for faster lookup
        local preserve_set = {}
        if type(preserve) == "table" then
            for _, name in ipairs(preserve) do
                if type(name) == "string" then
                    preserve_set[name:gsub("^%$", "")] = true
                end
            end
        end

        local clearall_data = {
            _type = "clearall",
            preserved = preserve,
        }

        -- Export current state and clear non-preserved variables
        local state = export_state(ctx)
        for key, _ in pairs(state) do
            -- Don't clear internal variables or preserved ones
            if not key:match("^_") and not preserve_set[key] then
                ctx:delete(key)
            end
        end

        ctx:_emit_event("CLEAR_ALL", clearall_data)

        return clearall_data
    end,
    {
        signature = Signature.builder()
            :optional("preserve", "table", {}, "Variables to preserve")
            :build(),
        description = "Clear all story variables",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        aliases = { "reset" },
        examples = {
            "(clearall:)",
            "(clearall: (a: 'score', 'name'))",
        },
    }
)

--- snapshot macro - Capture current state
State.snapshot_macro = Macros.define(
    function(ctx, args)
        local label = args[1] or ""
        local filter = args[2]

        local state = export_state(ctx)

        -- Apply filter if provided
        if type(filter) == "table" then
            local filtered = {}
            for _, key in ipairs(filter) do
                local clean_key = key:gsub("^%$", "")
                filtered[clean_key] = state[clean_key]
            end
            state = filtered
        elseif type(filter) == "function" then
            local filtered = {}
            for key, value in pairs(state) do
                if filter(key, value) then
                    filtered[key] = value
                end
            end
            state = filtered
        end

        local snapshot_data = {
            _type = "snapshot",
            label = label,
            state = state,
            timestamp = os.time(),
        }

        return snapshot_data
    end,
    {
        signature = Signature.builder()
            :optional("label", "string", "", "Optional label")
            :optional("filter", "any", nil, "Variables to include or filter function")
            :build(),
        description = "Capture current state",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(snapshot:)",
            "(snapshot: 'before-battle', (a: 'health', 'items'))",
        },
    }
)

--- restoresnapshot macro - Restore from snapshot
State.restoresnapshot_macro = Macros.define(
    function(ctx, args)
        local snapshot = args[1]
        local merge = args[2]

        if type(snapshot) ~= "table" or snapshot._type ~= "snapshot" then
            return nil, "Invalid snapshot"
        end

        local restore_data = {
            _type = "restore_snapshot",
            snapshot = snapshot,
            merge = merge or false,
        }

        -- Restore state
        if snapshot.state then
            if not merge then
                -- Clear current state first
                local current = export_state(ctx)
                for key, _ in pairs(current) do
                    if not key:match("^_") then
                        ctx:delete(key)
                    end
                end
            end

            -- Apply snapshot state
            for key, value in pairs(snapshot.state) do
                ctx:set(key, value)
            end
        end

        ctx:_emit_event("RESTORE_SNAPSHOT", restore_data)

        return restore_data
    end,
    {
        signature = Signature.builder()
            :required("snapshot", "table", "Snapshot to restore")
            :optional("merge", "boolean", false, "Merge with current state")
            :build(),
        description = "Restore from snapshot",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(restoresnapshot: $savedSnapshot)",
        },
    }
)

-- ============================================================================
-- State Query Macros
-- ============================================================================

--- vartype macro - Get type of a variable
State.vartype_macro = Macros.define(
    function(ctx, args)
        local name = args[1]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        local value = ctx:get(name)
        return type(value)
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable name")
            :build(),
        description = "Get type of a variable",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        aliases = { "typeof" },
        pure = true,
        examples = {
            "(vartype: $score)",
        },
    }
)

--- hasvar macro - Check if variable exists
State.hasvar_macro = Macros.define(
    function(ctx, args)
        local name = args[1]

        if type(name) == "string" then
            name = name:gsub("^%$", "")
        end

        return ctx:get(name) ~= nil
    end,
    {
        signature = Signature.builder()
            :required("name", "any", "Variable name")
            :build(),
        description = "Check if variable exists",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        aliases = { "defined", "exists" },
        pure = true,
        examples = {
            "(if: (hasvar: $playerName))[Hello, $playerName!]",
        },
    }
)

--- getvars macro - Get all variable names
State.getvars_macro = Macros.define(
    function(ctx, args)
        local filter = args[1]

        local state = export_state(ctx)
        local vars = {}

        for key, _ in pairs(state) do
            -- Skip internal variables
            if not key:match("^_") then
                if filter == nil then
                    table.insert(vars, key)
                elseif type(filter) == "string" then
                    if key:match(filter) then
                        table.insert(vars, key)
                    end
                end
            end
        end

        table.sort(vars)
        return vars
    end,
    {
        signature = Signature.builder()
            :optional("filter", "string", nil, "Pattern to filter variable names")
            :build(),
        description = "Get all variable names",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        pure = true,
        examples = {
            "(getvars:)",
            "(getvars: '^player')",
        },
    }
)

--- debug macro - Output state for debugging
State.debug_macro = Macros.define(
    function(ctx, args)
        local target = args[1]

        local debug_data = {
            _type = "debug",
        }

        if target == nil then
            -- Debug all state
            debug_data.state = export_state(ctx)
        elseif type(target) == "string" then
            local name = target:gsub("^%$", "")
            debug_data.variable = name
            debug_data.value = ctx:get(name)
            debug_data.type = type(debug_data.value)
        else
            debug_data.value = target
            debug_data.type = type(target)
        end

        ctx:_emit_event("DEBUG", debug_data)

        return debug_data
    end,
    {
        signature = Signature.builder()
            :optional("target", "any", nil, "Variable or value to debug")
            :build(),
        description = "Output state for debugging",
        format = Macros.FORMAT.WHISKER,
        category = Macros.CATEGORY.DATA,
        examples = {
            "(debug:)",
            "(debug: $player)",
        },
    }
)

-- ============================================================================
-- Registration Helper
-- ============================================================================

--- Register all state macros with a registry
-- @param registry MacroRegistry The registry to register with
-- @return number Number of macros registered
function State.register_all(registry)
    local macros = {
        -- Save system
        ["save"] = State.save_macro,
        ["load"] = State.load_macro,
        ["savedgames"] = State.savedgames_macro,
        ["deletesave"] = State.deletesave_macro,
        ["saveexists"] = State.saveexists_macro,
        ["autosave"] = State.autosave_macro,

        -- Persistent state
        ["remember"] = State.remember_macro,
        ["forget"] = State.forget_macro,
        ["recall"] = State.recall_macro,
        ["forgetall"] = State.forgetall_macro,

        -- Undo/redo
        ["checkpoint"] = State.checkpoint_macro,
        ["undo"] = State.undo_macro,
        ["redo"] = State.redo_macro,
        ["history"] = State.history_macro,
        ["canundo"] = State.canundo_macro,
        ["canredo"] = State.canredo_macro,

        -- State management
        ["clearall"] = State.clearall_macro,
        ["snapshot"] = State.snapshot_macro,
        ["restoresnapshot"] = State.restoresnapshot_macro,

        -- State queries
        ["vartype"] = State.vartype_macro,
        ["hasvar"] = State.hasvar_macro,
        ["getvars"] = State.getvars_macro,
        ["debug"] = State.debug_macro,
    }

    local count, _ = registry:register_all(macros)
    return count
end

return State
