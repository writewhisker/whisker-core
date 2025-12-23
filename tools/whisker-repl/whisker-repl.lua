#!/usr/bin/env lua
-- whisker-repl: Interactive Story Playground for whisker-core
-- Read-Eval-Print Loop for testing and exploring stories

local function print_help()
  print([[
whisker-repl - Interactive Story Playground

Usage: whisker-repl [options] [story-file]

Options:
  -h, --help       Show this help message
  -v, --version    Show version information
  --no-color       Disable colored output

Commands (in REPL):
  :load <file>     Load a story file
  :reload          Reload current story
  :restart         Restart from beginning
  :state           Show current state
  :passages        List all passages
  :goto <passage>  Jump to passage
  :set <var>=<val> Set variable
  :history         Show navigation history
  :save <file>     Save current state
  :load-state <f>  Load saved state
  :quit            Exit REPL

Navigation:
  Enter number to select a choice
  Press Enter to continue (when no choices)

Examples:
  whisker-repl story.ink
  whisker-repl
  > :load story.ink
]])
end

local function print_version()
  print("whisker-repl 0.1.0")
  print("Interactive story playground for whisker-core")
end

-- ANSI color codes
local colors = {
  reset = "\27[0m",
  bold = "\27[1m",
  dim = "\27[2m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  cyan = "\27[36m"
}

local use_colors = true

local function colorize(text, color)
  if not use_colors or not colors[color] then
    return text
  end
  return colors[color] .. text .. colors.reset
end

-- Simple story runtime simulation
local StoryRunner = {}
StoryRunner.__index = StoryRunner

function StoryRunner.new()
  local self = setmetatable({}, StoryRunner)
  self.story = nil
  self.state = {}
  self.current_passage = nil
  self.history = {}
  self.passages = {}
  return self
end

function StoryRunner:load(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return false, "Cannot open file: " .. filepath
  end

  local content = file:read("*a")
  file:close()

  self.filepath = filepath
  self.passages = {}
  self.state = {}
  self.history = {}

  -- Detect and parse format
  local ext = filepath:match("%.([^%.]+)$")

  if ext == "ink" then
    self:parse_ink(content)
  elseif ext == "twee" or ext == "tw" then
    self:parse_twee(content)
  elseif ext == "wscript" then
    self:parse_wscript(content)
  else
    return false, "Unknown file format: " .. ext
  end

  -- Find start passage
  local start_names = {"Start", "START", "start", "Beginning"}
  for _, name in ipairs(start_names) do
    if self.passages[name] then
      self.current_passage = name
      break
    end
  end

  if not self.current_passage then
    for name, _ in pairs(self.passages) do
      self.current_passage = name
      break
    end
  end

  return true
end

function StoryRunner:parse_ink(content)
  local current = nil
  local current_content = {}

  for line in content:gmatch("([^\n]*)\n?") do
    local passage_name = line:match("^%s*===+%s*([%w_]+)%s*===+")

    if passage_name then
      if current then
        self.passages[current].content = table.concat(current_content, "\n")
        self.passages[current].choices = self:extract_choices(self.passages[current].content, "ink")
      end

      current = passage_name
      current_content = {}
      self.passages[passage_name] = {name = passage_name, content = "", choices = {}}
    elseif current then
      table.insert(current_content, line)
    end
  end

  if current then
    self.passages[current].content = table.concat(current_content, "\n")
    self.passages[current].choices = self:extract_choices(self.passages[current].content, "ink")
  end
end

function StoryRunner:parse_twee(content)
  local current = nil
  local current_content = {}

  for line in content:gmatch("([^\n]*)\n?") do
    local passage_name = line:match("^::%s*([^%[%{]+)")

    if passage_name then
      passage_name = passage_name:match("^%s*(.-)%s*$")

      if current then
        self.passages[current].content = table.concat(current_content, "\n")
        self.passages[current].choices = self:extract_choices(self.passages[current].content, "twee")
      end

      current = passage_name
      current_content = {}
      self.passages[passage_name] = {name = passage_name, content = "", choices = {}}
    elseif current then
      table.insert(current_content, line)
    end
  end

  if current then
    self.passages[current].content = table.concat(current_content, "\n")
    self.passages[current].choices = self:extract_choices(self.passages[current].content, "twee")
  end
end

function StoryRunner:parse_wscript(content)
  local current = nil
  local brace_count = 0
  local current_content = {}

  for line in content:gmatch("([^\n]*)\n?") do
    local passage_name = line:match('^%s*passage%s+"([^"]+)"')

    if passage_name and brace_count == 0 then
      current = passage_name
      current_content = {}
      self.passages[passage_name] = {name = passage_name, content = "", choices = {}}
      brace_count = 1
    elseif current then
      for _ in line:gmatch("{") do brace_count = brace_count + 1 end
      for _ in line:gmatch("}") do brace_count = brace_count - 1 end

      if brace_count == 0 then
        self.passages[current].content = table.concat(current_content, "\n")
        self.passages[current].choices = self:extract_choices(self.passages[current].content, "wscript")
        current = nil
      else
        table.insert(current_content, line)
      end
    end
  end
end

function StoryRunner:extract_choices(content, format)
  local choices = {}

  if format == "ink" or format == "wscript" then
    for text, target in content:gmatch("[%*%+]%s*%[([^%]]+)%]%s*->%s*([%w_]+)") do
      table.insert(choices, {text = text, target = target})
    end
  elseif format == "twee" then
    for link in content:gmatch("%[%[([^%]]+)%]%]") do
      local text, target = link:match("([^|]+)|(.+)")
      if not text then
        text, target = link:match("([^%-]+)->(.+)")
      end
      if not text then
        text = link
        target = link
      end
      table.insert(choices, {text = text:match("^%s*(.-)%s*$"), target = target:match("^%s*(.-)%s*$")})
    end
  end

  return choices
end

function StoryRunner:get_display_text()
  if not self.current_passage or not self.passages[self.current_passage] then
    return nil
  end

  local content = self.passages[self.current_passage].content

  -- Remove choice lines for display
  local lines = {}
  for line in content:gmatch("([^\n]*)\n?") do
    if not line:match("^%s*[%*%+]%s*%[") and not line:match("%[%[") then
      if line:match("%S") then
        table.insert(lines, line)
      end
    end
  end

  return table.concat(lines, "\n")
end

function StoryRunner:goto_passage(name)
  if not self.passages[name] then
    return false, "Passage not found: " .. name
  end

  table.insert(self.history, self.current_passage)
  self.current_passage = name
  return true
end

function StoryRunner:choose(index)
  local passage = self.passages[self.current_passage]
  if not passage then
    return false, "No current passage"
  end

  local choice = passage.choices[index]
  if not choice then
    return false, "Invalid choice"
  end

  return self:goto_passage(choice.target)
end

function StoryRunner:get_choices()
  if not self.current_passage or not self.passages[self.current_passage] then
    return {}
  end
  return self.passages[self.current_passage].choices
end

function StoryRunner:is_ended()
  local choices = self:get_choices()
  return #choices == 0
end

-- REPL main loop
local function run_repl(story_file)
  local runner = StoryRunner.new()

  print(colorize("whisker-repl", "bold") .. " - Interactive Story Playground")
  print("Type :help for commands, :quit to exit\n")

  if story_file then
    local ok, err = runner:load(story_file)
    if ok then
      print(colorize("Loaded: " .. story_file, "green"))
    else
      print(colorize("Error: " .. err, "red"))
    end
  end

  while true do
    -- Show current passage
    if runner.current_passage then
      print("\n" .. colorize("=== " .. runner.current_passage .. " ===", "cyan"))
      local text = runner:get_display_text()
      if text then
        print(text)
      end

      -- Show choices
      local choices = runner:get_choices()
      if #choices > 0 then
        print("")
        for i, choice in ipairs(choices) do
          print(colorize(tostring(i), "yellow") .. ". " .. choice.text)
        end
      elseif runner:is_ended() then
        print(colorize("\n[Story ended]", "dim"))
      end
    end

    -- Read input
    io.write("\n" .. colorize("> ", "green"))
    local input = io.read("*l")

    if not input then
      break
    end

    input = input:match("^%s*(.-)%s*$")

    if input == "" then
      -- Continue / no action
    elseif input:match("^:") then
      -- Command
      local cmd, args = input:match("^:(%S+)%s*(.*)")

      if cmd == "quit" or cmd == "q" or cmd == "exit" then
        break
      elseif cmd == "help" or cmd == "h" or cmd == "?" then
        print_help()
      elseif cmd == "load" then
        local ok, err = runner:load(args)
        if ok then
          print(colorize("Loaded: " .. args, "green"))
        else
          print(colorize("Error: " .. err, "red"))
        end
      elseif cmd == "reload" then
        if runner.filepath then
          local ok, err = runner:load(runner.filepath)
          if ok then
            print(colorize("Reloaded", "green"))
          else
            print(colorize("Error: " .. err, "red"))
          end
        else
          print(colorize("No story loaded", "yellow"))
        end
      elseif cmd == "restart" then
        if runner.filepath then
          runner:load(runner.filepath)
          print(colorize("Restarted", "green"))
        end
      elseif cmd == "state" then
        print("Current state:")
        for k, v in pairs(runner.state) do
          print("  " .. k .. " = " .. tostring(v))
        end
        if next(runner.state) == nil then
          print("  (empty)")
        end
      elseif cmd == "passages" then
        print("Passages:")
        for name, _ in pairs(runner.passages) do
          local marker = name == runner.current_passage and " *" or ""
          print("  " .. name .. marker)
        end
      elseif cmd == "goto" then
        local ok, err = runner:goto_passage(args)
        if not ok then
          print(colorize("Error: " .. err, "red"))
        end
      elseif cmd == "set" then
        local var, val = args:match("(%S+)%s*=%s*(.+)")
        if var then
          local num = tonumber(val)
          if num then
            runner.state[var] = num
          elseif val == "true" then
            runner.state[var] = true
          elseif val == "false" then
            runner.state[var] = false
          else
            runner.state[var] = val
          end
          print(colorize(var .. " = " .. tostring(runner.state[var]), "green"))
        else
          print(colorize("Usage: :set var=value", "yellow"))
        end
      elseif cmd == "history" then
        print("Navigation history:")
        for i, p in ipairs(runner.history) do
          print("  " .. i .. ". " .. p)
        end
        print("  -> " .. (runner.current_passage or "(none)"))
      else
        print(colorize("Unknown command: " .. cmd, "yellow"))
      end
    elseif tonumber(input) then
      -- Choice selection
      local choice = tonumber(input)
      local ok, err = runner:choose(choice)
      if not ok then
        print(colorize("Error: " .. err, "red"))
      end
    else
      print(colorize("Enter a number to choose, or :command", "yellow"))
    end
  end

  print("\nGoodbye!")
end

local function main()
  local story_file = nil
  local i = 1

  while i <= #arg do
    local a = arg[i]
    if a == "-h" or a == "--help" then
      print_help()
      os.exit(0)
    elseif a == "-v" or a == "--version" then
      print_version()
      os.exit(0)
    elseif a == "--no-color" then
      use_colors = false
    elseif not a:match("^%-") then
      story_file = a
    end
    i = i + 1
  end

  run_repl(story_file)
end

if arg[0]:match("whisker%-repl") then
  main()
end

return {
  StoryRunner = StoryRunner,
  run_repl = run_repl
}
