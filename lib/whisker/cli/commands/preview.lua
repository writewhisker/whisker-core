-- lib/whisker/cli/commands/preview.lua
-- CLI Preview Command
-- WLS 1.0 GAP-060: Interactive terminal story preview

local WSParser = require("lib.whisker.parser.ws_parser")
local Formatter = require("lib.whisker.cli.formatter")

local Preview = {}

local PreviewUI = {}
PreviewUI.__index = PreviewUI

--- Create a new PreviewUI instance
---@param engine table Engine instance
---@param debug_mode boolean Enable debug mode
---@return PreviewUI
function PreviewUI.new(engine, debug_mode)
    local self = setmetatable({}, PreviewUI)
    self.engine = engine
    self.debug_mode = debug_mode
    self.running = true
    self.formatter = Formatter.new({ colors = true })
    return self
end

--- Run the interactive preview
---@return number Exit code
function PreviewUI:run()
    -- Navigate to start passage
    local start_passage = self.engine.story:get_start_passage()
    if not start_passage then
        print(self.formatter:error("No start passage found"))
        return 1
    end

    local content, err = self.engine:navigate_to_passage(start_passage.name)
    if err then
        print(self.formatter:error("Failed to start: " .. err))
        return 1
    end

    while self.running do
        -- Render current passage
        self:render_passage()

        -- Get choices
        local choices = self:get_current_choices()

        if #choices == 0 then
            print("\n" .. self.formatter:info("Story ended. Press Enter to exit"))
            io.read()
            break
        end

        -- Display choices
        self:render_choices(choices)

        -- Get input
        local input = self:get_input()

        -- Process input
        self:process_input(input, choices)
    end

    return 0
end

--- Get current choices from the engine
---@return table Array of choices
function PreviewUI:get_current_choices()
    if not self.engine.current_passage then
        return {}
    end
    return self.engine.current_passage.choices or {}
end

--- Render the current passage
function PreviewUI:render_passage()
    print("\n" .. string.rep("=", 60))

    if self.engine.current_passage then
        -- Show passage name
        print(self.formatter:color("[" .. self.engine.current_passage.name .. "]", "cyan"))
        print("")

        -- Show passage content
        local content = self.engine.current_passage.content or ""
        -- Remove choice lines from content display
        local display_content = content:gsub("\n[%+%*]+%s*%[.-%].-\n?", "\n")
        display_content = display_content:gsub("^[%+%*]+%s*%[.-%].-\n?", "")
        display_content = display_content:match("^%s*(.-)%s*$") -- trim

        if display_content ~= "" then
            print(display_content)
        end
    end

    if self.debug_mode then
        self:render_debug_info()
    end
end

--- Render available choices
---@param choices table Array of choices
function PreviewUI:render_choices(choices)
    print("\n" .. string.rep("-", 40))
    for i, choice in ipairs(choices) do
        local prefix = self.formatter:color(string.format("[%d]", i), "yellow")
        print(string.format("  %s %s", prefix, choice.text))
    end
    print()
end

--- Render debug information
function PreviewUI:render_debug_info()
    print("\n" .. string.rep("-", 40))
    print(self.formatter:color("[DEBUG]", "magenta"))

    if self.engine.current_passage then
        print("  Passage: " .. self.engine.current_passage.name)
    end

    if self.engine.state then
        local vars = self.engine.state
        if next(vars) then
            print("  Variables:")
            for k, v in pairs(vars) do
                if type(k) == "string" and not k:match("^_") then
                    print(string.format("    $%s = %s", k, tostring(v)))
                end
            end
        end
    end

    -- Show visit count if game_state exists
    if self.engine.game_state and self.engine.current_passage then
        local visits = self.engine.game_state:get_visit_count(self.engine.current_passage.name)
        print("  Visits: " .. (visits or 0))
    end
end

--- Get input from user
---@return string
function PreviewUI:get_input()
    io.write(self.formatter:color("> ", "cyan"))
    io.flush()
    local input = io.read()
    return input or ""
end

--- Process user input
---@param input string User input
---@param choices table Available choices
function PreviewUI:process_input(input, choices)
    input = input:match("^%s*(.-)%s*$")  -- trim

    -- Check for special commands
    if input:match("^/") then
        self:process_command(input)
        return
    end

    -- Try to parse as choice number
    local num = tonumber(input)
    if num and num >= 1 and num <= #choices then
        local choice = choices[num]
        if choice.target then
            local content, err = self.engine:navigate_to_passage(choice.target)
            if err then
                print(self.formatter:error("Navigation failed: " .. err))
            end
        else
            print(self.formatter:info("Choice has no target passage"))
        end
    else
        print(self.formatter:error("Invalid choice. Enter a number 1-" .. #choices))
    end
end

--- Process special commands
---@param cmd string Command starting with /
function PreviewUI:process_command(cmd)
    if cmd == "/quit" or cmd == "/q" then
        self.running = false
        print(self.formatter:info("Goodbye!"))
    elseif cmd == "/save" then
        if self.engine.serialize_state then
            local state = self.engine:serialize_state()
            -- In a real implementation, this would save to a file
            print(self.formatter:success("State saved (to memory)"))
        else
            print(self.formatter:info("Save not available"))
        end
    elseif cmd == "/load" then
        print(self.formatter:info("Load not implemented in preview mode"))
    elseif cmd == "/vars" then
        if self.engine.state then
            print("\n" .. self.formatter:section("Variables"))
            local has_vars = false
            for k, v in pairs(self.engine.state) do
                if type(k) == "string" then
                    print(string.format("  $%s = %s", k, tostring(v)))
                    has_vars = true
                end
            end
            if not has_vars then
                print("  (no variables set)")
            end
        else
            print(self.formatter:info("No variables available"))
        end
    elseif cmd == "/debug" then
        self.debug_mode = not self.debug_mode
        print(self.formatter:info("Debug mode: " .. (self.debug_mode and "ON" or "OFF")))
    elseif cmd == "/help" or cmd == "/?" then
        print("\n" .. self.formatter:section("Commands"))
        print("  /quit, /q    - Exit preview")
        print("  /save        - Save game state")
        print("  /load        - Load game state")
        print("  /vars        - Show all variables")
        print("  /debug       - Toggle debug mode")
        print("  /back        - Go back (undo)")
        print("  /restart     - Restart from beginning")
        print("  /help, /?    - Show this help")
    elseif cmd == "/back" then
        if self.engine.history and #self.engine.history > 0 then
            local prev = table.remove(self.engine.history)
            if prev and prev.passage_id then
                self.engine:navigate_to_passage(prev.passage_id, true)
                print(self.formatter:info("Went back to: " .. prev.passage_id))
            end
        else
            print(self.formatter:info("Cannot go back further"))
        end
    elseif cmd == "/restart" then
        local start_passage = self.engine.story:get_start_passage()
        if start_passage then
            self.engine.history = {}
            self.engine.state = {}
            self.engine:navigate_to_passage(start_passage.name)
            print(self.formatter:info("Restarted"))
        else
            print(self.formatter:error("No start passage"))
        end
    else
        print(self.formatter:error("Unknown command. Type /help for help."))
    end
end

--- Parse command line arguments
---@param args table Command line arguments
---@return table Parsed options
function Preview.parse_args(args)
    local options = {
        file = nil,
        start = nil,
        watch = false,
        debug = false
    }

    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == "--start" then
            i = i + 1
            options.start = args[i]
        elseif arg == "--watch" then
            options.watch = true
        elseif arg == "--debug" then
            options.debug = true
        elseif arg == "-d" then
            options.debug = true
        elseif not arg:match("^%-") and not options.file then
            options.file = arg
        end
        i = i + 1
    end

    return options
end

--- Load a story from file
---@param file_path string Path to .ws file
---@return table|nil story, string|nil error
function Preview.load_story(file_path)
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Cannot open file: " .. file_path
    end

    local content = file:read("*a")
    file:close()

    local parser = WSParser.new()
    local result = parser:parse(content)

    if not result.success then
        local errors = {}
        for _, err in ipairs(result.errors or {}) do
            if type(err) == "table" then
                table.insert(errors, err.message or tostring(err))
            else
                table.insert(errors, tostring(err))
            end
        end
        return nil, table.concat(errors, "\n")
    end

    return parser:build_story()
end

--- Create a minimal engine for preview
---@param story table Story object
---@return table Engine-like object
function Preview.create_engine(story)
    local HookManager = require("lib.whisker.wls2.hook_manager")

    local engine = {
        story = story,
        state = {},
        history = {},
        current_passage = nil,
        hook_manager = HookManager.new()
    }

    function engine:navigate_to_passage(passage_id, skip_history)
        -- Save to history
        if not skip_history and self.current_passage then
            table.insert(self.history, {
                passage_id = self.current_passage.name,
                state = {}
            })
        end

        -- Load passage
        local passage = self.story:get_passage_by_name(passage_id)
        if not passage then
            return nil, "Passage not found: " .. passage_id
        end

        self.current_passage = passage
        return passage.content
    end

    function engine:serialize_state()
        return {
            state = self.state,
            current_passage = self.current_passage and self.current_passage.name,
            history = self.history
        }
    end

    return engine
end

--- Run the preview command
---@param args table Command line arguments
---@return number Exit code
function Preview.run(args)
    local options = Preview.parse_args(args)
    local formatter = Formatter.new({ colors = true })

    if not options.file then
        print("Usage: whisker preview <story.ws> [options]")
        print("")
        print("Options:")
        print("  --start <passage>  Start at specific passage")
        print("  --watch            Reload on file changes")
        print("  --debug, -d        Enable debug mode")
        print("")
        print("Interactive Commands:")
        print("  /help    Show available commands")
        print("  /quit    Exit preview")
        print("  /vars    Show variables")
        print("  /back    Go back")
        return 1
    end

    -- Load story
    print(formatter:progress("Loading story: " .. options.file))
    local story, err = Preview.load_story(options.file)
    if not story then
        print(formatter:error("Error loading story: " .. (err or "unknown error")))
        return 1
    end

    -- Create engine
    local engine = Preview.create_engine(story)

    -- Set start passage if specified
    if options.start then
        local passage = story:get_passage_by_name(options.start)
        if not passage then
            print(formatter:error("Start passage not found: " .. options.start))
            return 1
        end
    end

    -- Run preview
    print(formatter:success("Story loaded"))
    print(formatter:info("Type /help for commands"))

    if options.watch then
        print(formatter:info("Watch mode not yet implemented"))
    end

    local ui = PreviewUI.new(engine, options.debug)

    -- Override start passage if specified
    if options.start then
        local content, start_err = engine:navigate_to_passage(options.start)
        if start_err then
            print(formatter:error("Failed to navigate: " .. start_err))
            return 1
        end
        return ui:run()
    end

    return ui:run()
end

--- Show help for the preview command
function Preview.help()
    print([[
Usage: whisker preview <story.ws> [options]

Interactive story preview in the terminal.

Options:
  --start <passage>  Start at specific passage instead of the default
  --watch            Reload story when file changes
  --debug, -d        Enable debug mode (shows variables and visit counts)

Interactive Commands (during preview):
  /help, /?    Show available commands
  /quit, /q    Exit preview
  /save        Save current state
  /load        Load saved state
  /vars        Display all variables
  /debug       Toggle debug mode
  /back        Go back to previous passage
  /restart     Restart from beginning

Examples:
  whisker preview story.ws
  whisker preview story.ws --start "CustomStart"
  whisker preview story.ws --debug
]])
end

return Preview
