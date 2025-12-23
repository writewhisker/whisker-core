# Getting Started with Ink in Whisker

A step-by-step tutorial for using Ink stories with whisker-core.

## Prerequisites

- Lua 5.1+ or LuaJIT
- whisker-core installed
- Basic understanding of Ink (optional, but helpful)

## Step 1: Install the Ink Compiler

The Ink compiler (inklecate) converts `.ink` source files to `.json`:

```bash
# Using npm
npm install -g inkjs

# Or download from Inkle
# https://github.com/inkle/ink/releases
```

## Step 2: Write Your First Ink Story

Create a file called `hello.ink`:

```ink
=== start ===
Hello! Welcome to my interactive story.

What's your name?

* [Alice] -> greet("Alice")
* [Bob] -> greet("Bob")
* [Other] -> greet("Friend")

=== greet(name) ===
Nice to meet you, {name}!

Do you want to continue?

* [Yes, let's go!] -> adventure
* [No, goodbye] -> ending

=== adventure ===
You set off on an adventure...

# speaker: narrator

The path ahead is dark and mysterious.

-> ending

=== ending ===
Thanks for playing!
-> END
```

## Step 3: Compile to JSON

```bash
inklecate hello.ink -o hello.ink.json
```

This creates `hello.ink.json` that whisker-core can read.

## Step 4: Load in Whisker

Create a Lua file called `play.lua`:

```lua
-- Load whisker-core modules
local Container = require("whisker.kernel.container")
local EventBus = require("whisker.kernel.events")
local InkEngine = require("whisker.formats.ink.engine")

-- Create the dependency container
local container = Container.new()

-- Register required services
container:register("events", function()
  return EventBus.new()
end, { singleton = true })

container:register("state", function()
  return {
    _data = {},
    get = function(self, key) return self._data[key] end,
    set = function(self, key, val) self._data[key] = val end,
    has = function(self, key) return self._data[key] ~= nil end,
    delete = function(self, key) self._data[key] = nil end,
    keys = function(self)
      local k = {}
      for key in pairs(self._data) do table.insert(k, key) end
      return k
    end,
  }
end, { singleton = true })

container:register("logger", function()
  return {
    debug = function() end,
    info = print,
    warn = print,
    error = print,
  }
end)

-- Create the Ink engine
local engine = InkEngine.new({
  events = container:resolve("events"),
  state = container:resolve("state"),
  logger = container:resolve("logger"),
})

-- Read the story file
local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    error("Could not open " .. path)
  end
  local content = file:read("*all")
  file:close()
  return content
end

-- Load the story
local json = read_file("hello.ink.json")
local ok, err = engine:load(json)
if not ok then
  error("Failed to load: " .. err)
end

-- Start the story
engine:start()

print("=== HELLO STORY ===\n")

-- Main game loop
while true do
  -- Print all available text
  while engine:can_continue() do
    local text, tags = engine:continue()

    -- Handle tags (like speaker)
    if tags and #tags > 0 then
      for _, tag in ipairs(tags) do
        if tag:match("^speaker:") then
          print("[" .. tag:sub(9) .. "]")
        end
      end
    end

    -- Print the text
    io.write(text)
  end

  -- Check if story ended
  if engine:has_ended() then
    print("\n=== THE END ===")
    break
  end

  -- Show choices
  local choices = engine:get_choices()
  if #choices > 0 then
    print()
    for i, choice in ipairs(choices) do
      print(i .. ". " .. choice.text)
    end

    -- Get player input
    io.write("\nYour choice: ")
    local input = io.read()
    local num = tonumber(input)

    if num and num >= 1 and num <= #choices then
      engine:make_choice(num)
      print()
    else
      print("Please enter a number between 1 and " .. #choices)
    end
  end
end
```

## Step 5: Run Your Story

```bash
lua play.lua
```

You should see:

```
=== HELLO STORY ===

Hello! Welcome to my interactive story.
What's your name?

1. Alice
2. Bob
3. Other

Your choice: 1

Nice to meet you, Alice!
Do you want to continue?

1. Yes, let's go!
2. No, goodbye

Your choice: 1

[narrator]
You set off on an adventure...
The path ahead is dark and mysterious.

Thanks for playing!

=== THE END ===
```

## Step 6: Add Variables

Update your Ink story to use variables:

```ink
VAR player_name = "Unknown"
VAR health = 100
VAR gold = 50

=== start ===
Hello, {player_name}!
You have {health} health and {gold} gold.

* [Check status] -> check_status
* [Adventure!] -> adventure

=== check_status ===
Health: {health}
Gold: {gold}
-> start
```

Access variables in Lua:

```lua
-- Get a variable
local health = engine:get_variable("health")
print("Player health: " .. health)

-- Set a variable
engine:set_variable("gold", 100)

-- Variables are also in Whisker state
local state = container:resolve("state")
local gold = state:get("ink.gold")
```

## Step 7: External Functions

Add Lua functions callable from Ink:

In your Ink story:

```ink
EXTERNAL roll_dice(sides)
EXTERNAL get_player_class()

=== combat ===
You roll a {roll_dice(20)} on the d20!

As a {get_player_class()}, you attack with your weapon.
```

In Lua:

```lua
-- Before loading the story, bind functions
engine:bind_external_function("roll_dice", function(sides)
  return math.random(1, sides)
end, false)  -- false = has side effects

engine:bind_external_function("get_player_class", function()
  return "Warrior"
end, true)  -- true = safe for lookahead
```

## Step 8: Save and Load

Implement save/load functionality:

```lua
local json = require("cjson")

-- Save function
local function save_game(filename)
  local state = engine:save_state()
  local file = io.open(filename, "w")
  file:write(json.encode(state))
  file:close()
  print("Game saved!")
end

-- Load function
local function load_game(filename)
  local file = io.open(filename, "r")
  if not file then
    print("No save file found")
    return false
  end
  local state = json.decode(file:read("*all"))
  file:close()
  engine:restore_state(state)
  print("Game loaded!")
  return true
end

-- In your game loop, handle save/load commands
if input == "save" then
  save_game("save.json")
elseif input == "load" then
  load_game("save.json")
end
```

## Next Steps

- Read the [Ink Documentation](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md) to learn more about Ink
- Check out the [API Reference](../api/INK_API.md) for all available methods
- See [Examples](../../examples/ink/) for more complex examples
- Learn about [Multi-Flow](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md#2-threads-and-flows) for parallel narratives

## Troubleshooting

### "Module not found" errors

Make sure whisker-core is in your Lua path:

```lua
package.path = "./whisker-core/lib/?.lua;" .. package.path
```

### Story won't load

1. Check the JSON file exists and is readable
2. Verify it's valid JSON (try a JSON validator)
3. Ensure it has `inkVersion` and `root` keys

### Choices not appearing

1. Make sure you continue until `can_continue()` is false
2. Check if choices have conditions that aren't met
3. Once-only choices may have been used already

### External functions not working

1. Bind functions before starting the story
2. Declare them in Ink with `EXTERNAL func_name(args)`
3. Make sure argument counts match

## Getting Help

- [whisker-core Issues](https://github.com/writewhisker/whisker-core/issues)
- [Ink Discord](https://discord.gg/inkle)
- [Ink GitHub](https://github.com/inkle/ink)
