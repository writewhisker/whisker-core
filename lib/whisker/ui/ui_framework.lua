-- whisker UI Framework
-- Provides unified interface for displaying stories across platforms
-- Integrates rendering and input handling

local UIFramework = {}
UIFramework._dependencies = {}
UIFramework.__index = UIFramework

-- Create new UI framework instance
function UIFramework.new(platform, config)
    local self = setmetatable({}, UIFramework)

    self.platform = platform or "console"

    -- Configuration
    self.config = {
        max_content_width = 80,
        choice_prefix = "> ",
        selected_prefix = "* ",
        clear_screen_on_passage = true,
        show_help_hint = true,
        show_debug_info = false,
        number_choices = true,
        color_support = false,
        auto_wrap_text = true
    }

    -- Override with provided config
    if config then
        for k, v in pairs(config) do
            self.config[k] = v
        end
    end

    -- UI state
    self.current_content = nil
    self.current_choices = {}
    self.selected_choice = 1
    self.waiting_for_input = false

    -- Platform components
    self.renderer = nil
    self.input_handler = nil

    -- UI history
    self.display_history = {}

    -- Statistics
    self.stats = {
        passages_displayed = 0,
        choices_displayed = 0,
        messages_shown = 0,
        saves_performed = 0,
        loads_performed = 0
    }

    -- Initialize platform-specific components
    self:initialize_platform()

    return self
end

-- Initialize platform-specific components
function UIFramework:initialize_platform()
    if self.platform == "console" then
        self:setup_console_platform()
    elseif self.platform == "love2d" then
        self:setup_love2d_platform()
    elseif self.platform == "web" then
        self:setup_web_platform()
    else
        error("Unsupported platform: " .. self.platform)
    end
end

-- Setup console platform
function UIFramework:setup_console_platform()
    -- Create renderer callbacks
    self.renderer = {
        display_passage = function(content, choices)
            self:render_console_passage(content, choices)
        end,

        show_message = function(message, message_type)
            self:render_console_message(message, message_type)
        end,

        show_save_menu = function(saves)
            self:render_console_save_menu(saves)
        end,

        show_load_menu = function(saves)
            self:render_console_load_menu(saves)
        end,

        clear_screen = function()
            self:clear_console_screen()
        end
    }

    -- Create input handler callbacks
    self.input_handler = {
        get_user_input = function()
            return self:get_console_input()
        end,

        get_save_name = function()
            return self:get_console_save_name()
        end,

        get_load_choice = function(saves)
            return self:get_console_load_choice(saves)
        end,

        confirm_action = function(message)
            return self:get_console_confirmation(message)
        end
    }
end

-- Console rendering methods
function UIFramework:render_console_passage(content, choices)
    if self.config.clear_screen_on_passage then
        self:clear_console_screen()
    end

    -- Display passage content
    local formatted_content = self:format_content(content.content or content.text or "")
    print(formatted_content)
    print()

    -- Display choices
    if choices and #choices > 0 then
        print("What do you choose?")

        for i, choice in ipairs(choices) do
            local choice_text = choice.text or "Unnamed choice"
            local prefix = self.config.choice_prefix

            if self.config.number_choices then
                prefix = string.format("%d. ", i)
            end

            local formatted_choice = self:colorize(prefix .. choice_text, "choice")
            print(formatted_choice)
        end

        print()
        self.stats.choices_displayed = self.stats.choices_displayed + #choices
    else
        print(self:colorize("(Story complete - no choices available)", "info"))
        print()
    end

    -- Show help hint
    if self.config.show_help_hint then
        print(self:colorize("Commands: 'save', 'load', 'help', 'quit'", "hint"))
        print()
    end

    -- Debug information
    if self.config.show_debug_info then
        self:render_debug_info(content)
    end

    self.stats.passages_displayed = self.stats.passages_displayed + 1
end

function UIFramework:render_console_message(message, message_type)
    local prefix = ""
    local color = "normal"

    if message_type == "error" then
        prefix = "ERROR: "
        color = "error"
    elseif message_type == "warning" then
        prefix = "WARNING: "
        color = "warning"
    elseif message_type == "info" then
        prefix = "INFO: "
        color = "info"
    elseif message_type == "success" then
        prefix = "SUCCESS: "
        color = "success"
    end

    print(self:colorize(prefix .. message, color))
    self.stats.messages_shown = self.stats.messages_shown + 1
end

function UIFramework:render_console_save_menu(saves)
    print("=== Save Game ===")
    print()

    if saves and #saves > 0 then
        print("Existing saves:")
        for i, save in ipairs(saves) do
            local save_info = string.format(
                "%d. %s (Passage: %s, Date: %s)",
                i,
                save.name or "Unnamed",
                save.current_passage or "Unknown",
                os.date("%Y-%m-%d %H:%M", save.timestamp or 0)
            )
            print(save_info)
        end
        print()
    end

    print("Enter a new save name or type 'cancel' to return.")
end

function UIFramework:render_console_load_menu(saves)
    print("=== Load Game ===")
    print()

    if not saves or #saves == 0 then
        print("No saved games found.")
        print()
        print("Press Enter to return...")
        return
    end

    for i, save in ipairs(saves) do
        local save_info = string.format(
            "%d. %s",
            i,
            save.name or "Unnamed"
        )
        print(save_info)

        print(string.format(
            "   Passage: %s | Turns: %d | Date: %s",
            save.current_passage or "Unknown",
            save.turn_count or 0,
            os.date("%Y-%m-%d %H:%M", save.timestamp or 0)
        ))
        print()
    end

    print("Enter save number to load, or 'cancel' to return.")
end

function UIFramework:render_debug_info(content)
    print("\n--- Debug Info ---")
    print("Passage: " .. (content.name or "Unknown"))
    print("PID: " .. (content.pid or "Unknown"))
    if content.tags and #content.tags > 0 then
        print("Tags: " .. table.concat(content.tags, ", "))
    end
    print("------------------\n")
end

-- Console input methods
function UIFramework:get_console_input()
    while true do
        io.write(self.config.choice_prefix)
        io.flush()

        local input = io.read()

        if not input then
            return {type = "quit"}
        end

        input = input:match("^%s*(.-)%s*$") -- trim whitespace

        if input == "" then
            return {type = "continue"}
        end

        input = input:lower()

        -- Check for commands
        if input == "help" or input == "h" or input == "?" then
            self:show_help()

        elseif input == "save" or input == "s" then
            return {type = "save"}

        elseif input == "load" or input == "l" then
            return {type = "load"}

        elseif input == "quit" or input == "q" or input == "exit" then
            return {type = "quit"}

        elseif input == "undo" or input == "u" or input == "back" then
            return {type = "undo"}

        elseif input == "restart" or input == "r" then
            return {type = "restart"}

        else
            -- Try to parse as choice number
            local choice_num = tonumber(input)

            if choice_num and choice_num >= 1 and choice_num <= #self.current_choices then
                return {type = "choice", choice = choice_num}
            else
                print("Invalid input. Please enter a choice number (1-" .. #self.current_choices .. ") or a command.")
                print("Type 'help' for available commands.")
            end
        end
    end
end

function UIFramework:get_console_save_name()
    while true do
        io.write("Save name: ")
        io.flush()

        local input = io.read()

        if not input then
            return nil
        end

        input = input:match("^%s*(.-)%s*$") -- trim

        if input:lower() == "cancel" then
            return nil
        end

        if input == "" then
            print("Save name cannot be empty. Try again or type 'cancel'.")
        else
            -- Validate save name
            if input:match("[<>:\"/\\|?*]") then
                print("Save name contains invalid characters. Please use letters, numbers, and spaces only.")
            else
                return input
            end
        end
    end
end

function UIFramework:get_console_load_choice(saves)
    while true do
        io.write("Load save: ")
        io.flush()

        local input = io.read()

        if not input then
            return nil
        end

        input = input:match("^%s*(.-)%s*$") -- trim

        if input:lower() == "cancel" then
            return nil
        end

        local choice = tonumber(input)

        if choice and choice >= 1 and choice <= #saves then
            return saves[choice]
        else
            print("Invalid save number. Please try again or type 'cancel'.")
        end
    end
end

function UIFramework:get_console_confirmation(message)
    print(message .. " (y/n)")

    while true do
        io.write("Confirm: ")
        io.flush()

        local input = io.read()

        if not input then
            return false
        end

        input = input:match("^%s*(.-)%s*$"):lower()

        if input == "y" or input == "yes" then
            return true
        elseif input == "n" or input == "no" then
            return false
        else
            print("Please enter 'y' for yes or 'n' for no.")
        end
    end
end

-- Public interface methods
function UIFramework:display_passage(content, game_state)
    -- Store current state
    self.current_content = content
    self.current_choices = content.choices or {}
    self.selected_choice = 1

    -- Display through renderer
    self.renderer.display_passage(content, self.current_choices)
end

function UIFramework:get_user_input()
    self.waiting_for_input = true
    local input = self.input_handler.get_user_input()
    self.waiting_for_input = false

    return input
end

function UIFramework:show_save_interface()
    local saves = {} -- Placeholder - would be passed in

    self.renderer.show_save_menu(saves)

    local save_name = self.input_handler.get_save_name()
    if save_name then
        self.stats.saves_performed = self.stats.saves_performed + 1
        return {type = "save_confirmed", save_name = save_name}
    else
        return {type = "save_cancelled"}
    end
end

function UIFramework:show_load_interface(saves)
    self.renderer.show_load_menu(saves)

    if not saves or #saves == 0 then
        io.read() -- Wait for Enter
        return {type = "load_cancelled"}
    end

    local selected_save = self.input_handler.get_load_choice(saves)
    if selected_save then
        self.stats.loads_performed = self.stats.loads_performed + 1
        return {type = "load_confirmed", save = selected_save}
    else
        return {type = "load_cancelled"}
    end
end

function UIFramework:show_message(message, message_type)
    self.renderer.show_message(message, message_type or "info")
end

function UIFramework:confirm_action(message)
    return self.input_handler.confirm_action(message)
end

function UIFramework:clear_screen()
    self.renderer.clear_screen()
end

-- Helper methods
function UIFramework:format_content(text)
    if self.config.auto_wrap_text then
        return self:wrap_text(text, self.config.max_content_width)
    end
    return text
end

function UIFramework:wrap_text(text, width)
    local lines = {}
    local current_line = ""

    for word in text:gmatch("%S+") do
        if #current_line + #word + 1 > width then
            if current_line ~= "" then
                table.insert(lines, current_line)
                current_line = word
            else
                -- Word is longer than width
                table.insert(lines, word)
            end
        else
            if current_line == "" then
                current_line = word
            else
                current_line = current_line .. " " .. word
            end
        end
    end

    if current_line ~= "" then
        table.insert(lines, current_line)
    end

    return table.concat(lines, "\n")
end

function UIFramework:colorize(text, color_type)
    if not self.config.color_support then
        return text
    end

    -- ANSI color codes
    local colors = {
        normal = "\27[0m",
        error = "\27[31m",    -- Red
        warning = "\27[33m",  -- Yellow
        info = "\27[36m",     -- Cyan
        success = "\27[32m",  -- Green
        choice = "\27[37m",   -- White
        hint = "\27[90m"      -- Gray
    }

    local color_code = colors[color_type] or colors.normal
    return color_code .. text .. colors.normal
end

function UIFramework:clear_console_screen()
    -- Try Unix/Linux/Mac clear
    local success = os.execute("clear")

    if not success then
        -- Try Windows cls
        os.execute("cls")
    end

    -- If both fail, print newlines
    if not success then
        print(string.rep("\n", 50))
    end
end

function UIFramework:show_help()
    print("\n=== Available Commands ===")
    print("  help, h, ?      - Show this help")
    print("  save, s         - Save game")
    print("  load, l         - Load game")
    print("  quit, q, exit   - Quit game")
    print("  undo, u, back   - Undo last choice")
    print("  restart, r      - Restart story")
    print("\nDuring gameplay:")
    print("  [number]        - Select choice")
    print("  [Enter]         - Continue")
    print()
end

-- Setup LÖVE2D platform
function UIFramework:setup_love2d_platform()
    -- Verify LÖVE2D environment
    if not love then
        error("LÖVE2D environment not detected. Please run from LÖVE2D.")
    end

    -- LÖVE2D-specific state
    self.love2d_state = {
        y_offset = 20,
        line_height = 24,
        padding = 20,
        scroll_offset = 0,
        font = love.graphics.getFont(),
        content_lines = {},
        choice_buttons = {},
        pending_choice = nil,
        waiting_for_continue = false
    }

    -- Create renderer callbacks
    self.renderer = {
        display_passage = function(content, choices)
            self:render_love2d_passage(content, choices)
        end,

        show_message = function(message, message_type)
            self:render_love2d_message(message, message_type)
        end,

        show_save_menu = function(saves)
            self:render_love2d_save_menu(saves)
        end,

        show_load_menu = function(saves)
            self:render_love2d_load_menu(saves)
        end,

        clear_screen = function()
            self.love2d_state.content_lines = {}
            self.love2d_state.choice_buttons = {}
        end
    }

    -- Create input handler callbacks
    self.input_handler = {
        get_user_input = function()
            return self:get_love2d_input()
        end,

        get_save_name = function()
            -- LÖVE2D would show a text input dialog
            return os.date("%Y-%m-%d %H:%M:%S")
        end,

        get_load_choice = function(saves)
            return self:get_love2d_load_choice(saves)
        end,

        confirm_action = function(message)
            return true -- Simplified for now
        end
    }

    -- Register LÖVE2D draw callback
    local original_draw = love.draw or function() end
    love.draw = function()
        original_draw()
        self:love2d_draw()
    end

    -- Register LÖVE2D key callback
    local original_keypressed = love.keypressed or function() end
    love.keypressed = function(key)
        original_keypressed(key)
        self:love2d_keypressed(key)
    end

    -- Register LÖVE2D mouse callback
    local original_mousepressed = love.mousepressed or function() end
    love.mousepressed = function(x, y, button)
        original_mousepressed(x, y, button)
        self:love2d_mousepressed(x, y, button)
    end
end

-- LÖVE2D rendering methods
function UIFramework:render_love2d_passage(content, choices)
    local state = self.love2d_state
    state.content_lines = {}
    state.choice_buttons = {}

    -- Format and wrap passage content
    local text = content.content or content.text or ""
    local width = love.graphics.getWidth() - 2 * state.padding
    local wrapped = self:wrap_text_love2d(text, width)

    for _, line in ipairs(wrapped) do
        table.insert(state.content_lines, {text = line, type = "content"})
    end

    -- Add spacing
    table.insert(state.content_lines, {text = "", type = "spacer"})

    -- Add choices
    if choices and #choices > 0 then
        for i, choice in ipairs(choices) do
            local choice_text = string.format("%d. %s", i, choice.text or "Unnamed choice")
            table.insert(state.choice_buttons, {
                text = choice_text,
                index = i,
                y = 0 -- Will be calculated in draw
            })
        end
        state.waiting_for_continue = false
    else
        table.insert(state.content_lines, {text = "(Story complete)", type = "info"})
        state.waiting_for_continue = true
    end

    self.stats.passages_displayed = self.stats.passages_displayed + 1
    if choices then
        self.stats.choices_displayed = self.stats.choices_displayed + #choices
    end
end

function UIFramework:render_love2d_message(message, message_type)
    local color = {1, 1, 1}
    if message_type == "error" then color = {1, 0.3, 0.3}
    elseif message_type == "warning" then color = {1, 0.8, 0.2}
    elseif message_type == "info" then color = {0.5, 0.8, 1}
    elseif message_type == "success" then color = {0.3, 1, 0.3}
    end

    table.insert(self.love2d_state.content_lines, {
        text = message,
        type = message_type,
        color = color
    })
    self.stats.messages_shown = self.stats.messages_shown + 1
end

function UIFramework:render_love2d_save_menu(saves)
    -- Would show a save dialog - for now, just display message
    self:render_love2d_message("Save menu not yet fully implemented", "info")
end

function UIFramework:render_love2d_load_menu(saves)
    -- Would show a load dialog - for now, just display message
    self:render_love2d_message("Load menu not yet fully implemented", "info")
end

function UIFramework:love2d_draw()
    local state = self.love2d_state
    local y = state.padding - state.scroll_offset

    -- Draw content lines
    love.graphics.setColor(1, 1, 1)
    for _, line in ipairs(state.content_lines) do
        if line.color then
            love.graphics.setColor(line.color)
        else
            love.graphics.setColor(1, 1, 1)
        end
        love.graphics.print(line.text, state.padding, y)
        y = y + state.line_height
    end

    -- Draw choice buttons
    love.graphics.setColor(0.3, 0.6, 1)
    for _, button in ipairs(state.choice_buttons) do
        button.y = y
        love.graphics.print(button.text, state.padding, y)
        y = y + state.line_height
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)

    -- Show continue prompt if waiting
    if state.waiting_for_continue then
        love.graphics.print("Press Enter to continue...", state.padding, y + state.line_height)
    end
end

function UIFramework:love2d_keypressed(key)
    local state = self.love2d_state

    -- Handle number keys for choice selection
    local num = tonumber(key)
    if num and num >= 1 and num <= #state.choice_buttons then
        state.pending_choice = num
        return
    end

    -- Handle arrow keys for scrolling
    if key == "up" then
        state.scroll_offset = math.max(0, state.scroll_offset - state.line_height)
    elseif key == "down" then
        state.scroll_offset = state.scroll_offset + state.line_height
    elseif key == "return" or key == "space" then
        if state.waiting_for_continue then
            state.pending_choice = 0 -- Signal continue
        end
    end
end

function UIFramework:love2d_mousepressed(x, y, button)
    if button ~= 1 then return end

    local state = self.love2d_state
    for _, btn in ipairs(state.choice_buttons) do
        if y >= btn.y and y < btn.y + state.line_height then
            state.pending_choice = btn.index
            return
        end
    end
end

function UIFramework:get_love2d_input()
    local state = self.love2d_state

    -- Wait for choice selection via coroutine yield
    while state.pending_choice == nil do
        coroutine.yield()
    end

    local choice = state.pending_choice
    state.pending_choice = nil
    return tostring(choice)
end

function UIFramework:get_love2d_load_choice(saves)
    -- Simplified - would show proper UI
    return 1
end

function UIFramework:wrap_text_love2d(text, max_width)
    local lines = {}
    local font = love.graphics.getFont()

    for line in text:gmatch("[^\n]+") do
        local words = {}
        for word in line:gmatch("%S+") do
            table.insert(words, word)
        end

        local current_line = ""
        for _, word in ipairs(words) do
            local test_line = current_line == "" and word or (current_line .. " " .. word)
            if font:getWidth(test_line) <= max_width then
                current_line = test_line
            else
                if current_line ~= "" then
                    table.insert(lines, current_line)
                end
                current_line = word
            end
        end
        if current_line ~= "" then
            table.insert(lines, current_line)
        end
    end

    if #lines == 0 then
        table.insert(lines, "")
    end

    return lines
end

-- Setup web platform (Fengari or other Lua-JS bridge)
function UIFramework:setup_web_platform()
    -- Try to detect JavaScript bridge (Fengari)
    local js, window
    local has_js = pcall(function()
        js = require("js")
        window = js.global
    end)

    if not has_js then
        error("Web platform requires Fengari or compatible Lua-JS bridge.")
    end

    -- Web-specific state
    self.web_state = {
        output_element = nil,
        choices_element = nil,
        pending_choice = nil,
        document = window.document
    }

    -- Find or create output elements
    local doc = self.web_state.document
    self.web_state.output_element = doc:getElementById("story-output")
    self.web_state.choices_element = doc:getElementById("story-choices")

    if not self.web_state.output_element then
        -- Create default container
        local container = doc:createElement("div")
        container.id = "whisker-story"
        container.innerHTML = [[
            <div id="story-output" style="padding:20px;max-width:800px;margin:0 auto;"></div>
            <div id="story-choices" style="padding:20px;max-width:800px;margin:0 auto;"></div>
        ]]
        doc.body:appendChild(container)
        self.web_state.output_element = doc:getElementById("story-output")
        self.web_state.choices_element = doc:getElementById("story-choices")
    end

    -- Create renderer callbacks
    self.renderer = {
        display_passage = function(content, choices)
            self:render_web_passage(content, choices)
        end,

        show_message = function(message, message_type)
            self:render_web_message(message, message_type)
        end,

        show_save_menu = function(saves)
            self:render_web_save_menu(saves)
        end,

        show_load_menu = function(saves)
            self:render_web_load_menu(saves)
        end,

        clear_screen = function()
            self.web_state.output_element.innerHTML = ""
            self.web_state.choices_element.innerHTML = ""
        end
    }

    -- Create input handler callbacks
    self.input_handler = {
        get_user_input = function()
            return self:get_web_input()
        end,

        get_save_name = function()
            return window:prompt("Enter save name:", os.date("%Y-%m-%d %H:%M:%S")) or ""
        end,

        get_load_choice = function(saves)
            return self:get_web_load_choice(saves)
        end,

        confirm_action = function(message)
            return window:confirm(message)
        end
    }
end

-- Web rendering methods
function UIFramework:render_web_passage(content, choices)
    local js = require("js")
    local doc = self.web_state.document
    local output = self.web_state.output_element
    local choices_div = self.web_state.choices_element

    -- Clear previous content
    output.innerHTML = ""
    choices_div.innerHTML = ""

    -- Create passage content
    local passage_div = doc:createElement("div")
    passage_div.className = "passage"
    passage_div.style.cssText = "margin-bottom:20px;line-height:1.6;"

    local text = content.content or content.text or ""
    -- Convert newlines to <br> and preserve paragraphs
    text = text:gsub("\n\n", "</p><p>")
    text = text:gsub("\n", "<br>")
    passage_div.innerHTML = "<p>" .. text .. "</p>"
    output:appendChild(passage_div)

    -- Render choices
    if choices and #choices > 0 then
        for i, choice in ipairs(choices) do
            local button = doc:createElement("button")
            button.className = "choice-button"
            button.style.cssText = [[
                display:block;
                width:100%;
                padding:12px 20px;
                margin:8px 0;
                background:#4a90d9;
                color:white;
                border:none;
                border-radius:4px;
                cursor:pointer;
                font-size:16px;
                text-align:left;
            ]]
            button.textContent = (i .. ". " .. (choice.text or "Unnamed choice"))

            -- Store choice index for click handler
            local choice_index = i
            button.onclick = function()
                self.web_state.pending_choice = choice_index
            end

            choices_div:appendChild(button)
        end
        self.stats.choices_displayed = self.stats.choices_displayed + #choices
    else
        local end_div = doc:createElement("div")
        end_div.style.cssText = "color:#666;font-style:italic;padding:20px 0;"
        end_div.textContent = "The End"
        choices_div:appendChild(end_div)
    end

    self.stats.passages_displayed = self.stats.passages_displayed + 1

    -- Scroll to top of output
    output:scrollIntoView(js.new(js.global.Object, {behavior = "smooth"}))
end

function UIFramework:render_web_message(message, message_type)
    local doc = self.web_state.document
    local output = self.web_state.output_element

    local msg_div = doc:createElement("div")
    msg_div.className = "message message-" .. (message_type or "info")

    local colors = {
        error = "#ff4444",
        warning = "#ffaa00",
        info = "#4a90d9",
        success = "#44aa44"
    }

    msg_div.style.cssText = string.format([[
        padding:12px 16px;
        margin:10px 0;
        border-radius:4px;
        background:%s22;
        border-left:4px solid %s;
        color:%s;
    ]], colors[message_type] or colors.info,
        colors[message_type] or colors.info,
        colors[message_type] or colors.info)

    msg_div.textContent = message
    output:appendChild(msg_div)

    self.stats.messages_shown = self.stats.messages_shown + 1
end

function UIFramework:render_web_save_menu(saves)
    self:render_web_message("Save functionality: use browser's localStorage", "info")
end

function UIFramework:render_web_load_menu(saves)
    self:render_web_message("Load functionality: use browser's localStorage", "info")
end

function UIFramework:get_web_input()
    local js = require("js")
    local window = js.global

    -- Wait for choice selection using a Promise-like approach
    -- In Fengari, we can use coroutines with JavaScript event loop

    self.web_state.pending_choice = nil

    -- Create a simple polling mechanism
    -- In production, you'd use proper async/await with Fengari
    while self.web_state.pending_choice == nil do
        -- Yield to allow JS event loop to process
        coroutine.yield()
    end

    local choice = self.web_state.pending_choice
    self.web_state.pending_choice = nil
    return tostring(choice)
end

function UIFramework:get_web_load_choice(saves)
    local js = require("js")
    local window = js.global

    if not saves or #saves == 0 then
        window:alert("No saves available")
        return nil
    end

    -- Simple prompt-based selection
    local list = ""
    for i, save in ipairs(saves) do
        list = list .. i .. ". " .. (save.name or "Save " .. i) .. "\n"
    end

    local choice = window:prompt("Select save to load:\n" .. list, "1")
    return tonumber(choice) or 1
end

-- Web storage helpers
function UIFramework:web_save_state(key, data)
    local js = require("js")
    -- Use vendor-approved JSON library
    local json = require("whisker.vendor.dkjson")
    local window = js.global
    window.localStorage:setItem("whisker_" .. key, json.encode(data))
end

function UIFramework:web_load_state(key)
    local js = require("js")
    -- Use vendor-approved JSON library
    local json = require("whisker.vendor.dkjson")
    local window = js.global
    local data = window.localStorage:getItem("whisker_" .. key)
    if data then
        return json.decode(data)
    end
    return nil
end

-- Get statistics
function UIFramework:get_stats()
    return {
        passages_displayed = self.stats.passages_displayed,
        choices_displayed = self.stats.choices_displayed,
        messages_shown = self.stats.messages_shown,
        saves_performed = self.stats.saves_performed,
        loads_performed = self.stats.loads_performed
    }
end

return UIFramework