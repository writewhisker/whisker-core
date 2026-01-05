# WLS 2.0 API Reference

API documentation for WLS 2.0 Lua modules.

## Module Overview

| Module | Path | Description |
|--------|------|-------------|
| `wls2` | `whisker.wls2` | Main module re-exports |
| `thread_scheduler` | `whisker.wls2.thread_scheduler` | Thread management |
| `timed_content` | `whisker.wls2.timed_content` | Timer management |
| `text_effects` | `whisker.wls2.text_effects` | Text effect system |
| `external_functions` | `whisker.wls2.external_functions` | Host integration |
| `wls2_integration` | `whisker.wls2.wls2_integration` | Unified runtime |

---

## whisker.wls2

Main module providing access to all WLS 2.0 functionality.

```lua
local wls2 = require("whisker.wls2")

-- Create integration instance
local runtime = wls2.new(options)

-- Access submodules
local scheduler = wls2.thread_scheduler
local timers = wls2.timed_content
local effects = wls2.text_effects
local externals = wls2.external_functions
```

### wls2.new(options)

Creates a new WLS2Integration instance.

**Parameters:**
- `options` (table, optional): Configuration options
  - `max_threads` (number): Maximum concurrent threads (default: 10)
  - `tick_rate` (number): Updates per second (default: 60)
  - `scheduler_mode` (string): "priority" or "round_robin" (default: "priority")

**Returns:** WLS2Integration instance

```lua
local runtime = wls2.new({
  max_threads = 20,
  tick_rate = 30,
  scheduler_mode = "round_robin"
})
```

---

## whisker.wls2.thread_scheduler

Thread scheduling and management.

### Constants

```lua
local STATUS = {
  RUNNING = "running",
  WAITING = "waiting",
  COMPLETED = "completed",
  ERROR = "error"
}

local EVENTS = {
  THREAD_CREATED = "thread:created",
  THREAD_STARTED = "thread:started",
  THREAD_COMPLETED = "thread:completed",
  THREAD_ERROR = "thread:error",
  ALL_COMPLETE = "scheduler:all_complete"
}
```

### thread_scheduler.new(options, deps)

Creates a new ThreadScheduler instance.

**Parameters:**
- `options` (table, optional):
  - `max_threads` (number): Maximum threads (default: 10)
  - `mode` (string): "priority" or "round_robin"
- `deps` (table, optional): Dependencies for DI

**Returns:** ThreadScheduler instance

```lua
local scheduler = thread_scheduler.new({
  max_threads = 5,
  mode = "priority"
})
```

### scheduler:create_thread(options)

Creates a new thread.

**Parameters:**
- `options` (table):
  - `id` (string, optional): Thread ID (auto-generated if omitted)
  - `passage_id` (string): Starting passage
  - `priority` (number): Execution priority (default: 5)
  - `locals` (table): Thread-local variables

**Returns:** Thread ID (string)

```lua
local id = scheduler:create_thread({
  passage_id = "BackgroundNoise",
  priority = 3,
  locals = { counter = 0 }
})
```

### scheduler:spawn_thread(passage_id, options)

Spawns and starts a thread.

**Parameters:**
- `passage_id` (string): Starting passage
- `options` (table, optional): Same as create_thread

**Returns:** Thread ID (string)

```lua
local id = scheduler:spawn_thread("AmbientSounds", {
  priority = 2
})
```

### scheduler:complete_thread(thread_id, result)

Marks a thread as completed.

**Parameters:**
- `thread_id` (string): Thread to complete
- `result` (any, optional): Completion result

```lua
scheduler:complete_thread("thread_1", { success = true })
```

### scheduler:await_thread_completion(thread_id, callback)

Registers a callback for thread completion.

**Parameters:**
- `thread_id` (string): Thread to await
- `callback` (function): Called on completion with (thread_id, result)

```lua
scheduler:await_thread_completion("thread_1", function(id, result)
  print("Thread " .. id .. " finished")
end)
```

### scheduler:get_thread(thread_id)

Gets thread information.

**Returns:** Thread table or nil

```lua
local thread = scheduler:get_thread("thread_1")
if thread then
  print(thread.status)  -- "running", "waiting", etc.
  print(thread.priority)
end
```

### scheduler:set_thread_local(thread_id, key, value)

Sets a thread-local variable.

```lua
scheduler:set_thread_local("thread_1", "counter", 42)
```

### scheduler:get_thread_local(thread_id, key)

Gets a thread-local variable.

```lua
local counter = scheduler:get_thread_local("thread_1", "counter")
```

### scheduler:step()

Executes one scheduler step.

**Returns:** Next thread to process, or nil

```lua
while true do
  local thread = scheduler:step()
  if not thread then break end
  process_thread(thread)
end
```

### scheduler:get_next_thread()

Gets the next thread to execute without modifying state.

**Returns:** Thread table or nil

```lua
local next = scheduler:get_next_thread()
```

### scheduler:on(event, callback)

Registers an event listener.

```lua
scheduler:on("thread:completed", function(data)
  print("Thread completed: " .. data.thread_id)
end)
```

---

## whisker.wls2.timed_content

Timer and scheduled content management.

### timed_content.parse_time_string(time_str)

Parses a time string to milliseconds.

**Parameters:**
- `time_str` (string): Time in format "Nms", "Ns", or "Nm"

**Returns:** Milliseconds (number)

```lua
local ms = timed_content.parse_time_string("2s")    -- 2000
local ms = timed_content.parse_time_string("500ms") -- 500
local ms = timed_content.parse_time_string("1.5s")  -- 1500
```

### timed_content.new(deps)

Creates a TimedContentManager instance.

```lua
local manager = timed_content.new()
```

### manager:schedule(delay_ms, content, options)

Schedules content for later delivery.

**Parameters:**
- `delay_ms` (number): Delay in milliseconds
- `content` (any): Content to deliver
- `options` (table, optional):
  - `id` (string): Timer ID
  - `callback` (function): Delivery callback
  - `context` (table): Associated context

**Returns:** Timer ID (string)

```lua
local id = manager:schedule(2000, "Hello!", {
  callback = function(content)
    print(content)
  end
})
```

### manager:schedule_repeat(interval_ms, content, options)

Schedules repeating content.

**Parameters:**
- `interval_ms` (number): Interval in milliseconds
- `content` (any): Content to deliver
- `options` (table, optional):
  - `id` (string): Timer ID
  - `callback` (function): Delivery callback
  - `max_repeats` (number): Maximum repetitions

**Returns:** Timer ID (string)

```lua
local id = manager:schedule_repeat(1000, "Tick", {
  callback = function(content)
    print(content)
  end,
  max_repeats = 10
})
```

### manager:cancel(timer_id)

Cancels a timer.

**Returns:** boolean (success)

```lua
manager:cancel("timer_1")
```

### manager:pause(timer_id)

Pauses a timer.

**Returns:** boolean (success)

```lua
manager:pause("timer_1")
```

### manager:resume(timer_id)

Resumes a paused timer.

**Returns:** boolean (success)

```lua
manager:resume("timer_1")
```

### manager:update(delta_ms)

Updates all timers.

**Parameters:**
- `delta_ms` (number): Elapsed time in milliseconds

**Returns:** Table of delivered content

```lua
local delivered = manager:update(16)
for _, item in ipairs(delivered) do
  print(item.content)
end
```

### manager:get_remaining(timer_id)

Gets remaining time for a timer.

**Returns:** Milliseconds remaining, or nil

```lua
local remaining = manager:get_remaining("timer_1")
```

---

## whisker.wls2.text_effects

Text effect system.

### Constants

```lua
local EFFECTS = {
  TYPEWRITER = "typewriter",
  FADE_IN = "fade-in",
  FADE_OUT = "fade-out",
  SHAKE = "shake",
  RAINBOW = "rainbow",
  GLITCH = "glitch"
}
```

### text_effects.parse_effect_declaration(declaration)

Parses an effect declaration string.

**Parameters:**
- `declaration` (string): Effect declaration

**Returns:** Table with name, duration, options

```lua
local effect = text_effects.parse_effect_declaration("shake 500ms intensity:10")
-- { name = "shake", duration = 500, options = { intensity = 10 } }
```

### text_effects.new(deps)

Creates a TextEffectsManager instance.

```lua
local manager = text_effects.new()
```

### manager:apply(text, effect_name, options)

Applies an effect to text.

**Parameters:**
- `text` (string): Text to apply effect to
- `effect_name` (string): Effect type
- `options` (table, optional):
  - `id` (string): Effect instance ID
  - `duration` (number): Duration in ms
  - `speed` (number): For typewriter, chars per second
  - `intensity` (number): For shake effect
  - `callback` (function): Completion callback

**Returns:** Effect instance ID (string)

```lua
local id = manager:apply("Hello World", "typewriter", {
  speed = 50,
  callback = function(text, completed)
    print(text)
  end
})
```

### manager:update(delta_ms)

Updates all active effects.

**Parameters:**
- `delta_ms` (number): Elapsed time in milliseconds

**Returns:** Table of effect updates

```lua
local updates = manager:update(16)
for _, update in ipairs(updates) do
  render(update.text, update.progress)
end
```

### manager:cancel(effect_id)

Cancels an active effect.

**Returns:** boolean (success)

```lua
manager:cancel("effect_1")
```

### manager:register_handler(name, handler)

Registers a custom effect handler.

**Parameters:**
- `name` (string): Effect name
- `handler` (function): Handler function(text, options, progress) -> string

```lua
manager:register_handler("blink", function(text, options, progress)
  local visible = math.floor(progress * 10) % 2 == 0
  return visible and text or ""
end)
```

### manager:skip(effect_id)

Skips to effect completion.

**Returns:** Final text (string)

```lua
local final = manager:skip("effect_1")
```

### manager:pause(effect_id)

Pauses an effect.

```lua
manager:pause("effect_1")
```

### manager:resume(effect_id)

Resumes a paused effect.

```lua
manager:resume("effect_1")
```

---

## whisker.wls2.external_functions

Host application function integration.

### external_functions.new(deps)

Creates an ExternalFunctionsManager instance.

```lua
local manager = external_functions.new()
```

### manager:register(name, fn, options)

Registers an external function.

**Parameters:**
- `name` (string): Function name
- `fn` (function): Implementation
- `options` (table, optional):
  - `async` (boolean): Is async function
  - `returns` (string): Return type hint
  - `params` (table): Parameter type hints

```lua
manager:register("playSound", function(soundId)
  audio.play(soundId)
end, {
  params = { "string" }
})

manager:register("fetchData", function(url, callback)
  http.get(url, callback)
end, {
  async = true,
  returns = "table"
})
```

### manager:register_all(functions)

Registers multiple functions at once.

**Parameters:**
- `functions` (table): Map of name to function

```lua
manager:register_all({
  playSound = function(id) audio.play(id) end,
  stopSound = function(id) audio.stop(id) end,
  getScore = function() return game.score end
})
```

### manager:register_namespace(namespace, functions)

Registers functions under a namespace.

**Parameters:**
- `namespace` (string): Namespace prefix
- `functions` (table): Map of name to function

```lua
manager:register_namespace("audio", {
  play = function(id) audio.play(id) end,
  stop = function(id) audio.stop(id) end,
  volume = function(level) audio.setVolume(level) end
})

-- Call as: manager:call("audio.play", "bgm")
```

### manager:call(name, ...)

Calls an external function.

**Parameters:**
- `name` (string): Function name (with optional namespace)
- `...` (any): Function arguments

**Returns:** Function result

**Throws:** Error if function not found

```lua
local score = manager:call("getScore")
manager:call("audio.play", "bgm")
```

### manager:try_call(name, ...)

Calls an external function, returning nil on error.

**Parameters:**
- `name` (string): Function name
- `...` (any): Function arguments

**Returns:** Result or nil, error message

```lua
local result, err = manager:try_call("riskyFunction")
if err then
  print("Error: " .. err)
end
```

### manager:create_proxy(namespace)

Creates a proxy table for namespace access.

**Parameters:**
- `namespace` (string): Namespace

**Returns:** Proxy table

```lua
local audio = manager:create_proxy("audio")
audio.play("bgm")  -- Calls audio.play
audio.stop("bgm")  -- Calls audio.stop
```

### manager:list()

Lists all registered functions.

**Returns:** Table of function info

```lua
local functions = manager:list()
for _, fn in ipairs(functions) do
  print(fn.name, fn.namespace or "global")
end
```

---

## whisker.wls2.wls2_integration

Unified WLS 2.0 runtime combining all components.

### wls2_integration.new(options, deps)

Creates a WLS2Integration instance.

**Parameters:**
- `options` (table, optional):
  - `max_threads` (number): Maximum threads
  - `tick_rate` (number): Updates per second
  - `scheduler_mode` (string): Thread scheduling mode
- `deps` (table, optional): Dependencies

**Returns:** WLS2Integration instance

```lua
local runtime = wls2_integration.new({
  max_threads = 10,
  tick_rate = 60
})
```

### integration:initialize()

Initializes the integration.

```lua
runtime:initialize()
```

### integration:start()

Starts the runtime.

```lua
runtime:start()
```

### integration:spawn_thread(passage_id, options)

Spawns a new thread.

**Returns:** Thread ID

```lua
local id = runtime:spawn_thread("BackgroundLoop", {
  priority = 3
})
```

### integration:schedule_content(delay_ms, content, options)

Schedules timed content.

**Returns:** Timer ID

```lua
local id = runtime:schedule_content(2000, "Delayed text", {
  callback = function(content) print(content) end
})
```

### integration:apply_effect(text, effect_name, options)

Applies a text effect.

**Returns:** Effect ID

```lua
local id = runtime:apply_effect("Hello", "typewriter", {
  speed = 30
})
```

### integration:tick(delta_ms)

Advances the runtime by delta milliseconds.

**Parameters:**
- `delta_ms` (number): Elapsed time

**Returns:** Table with updates

```lua
local updates = runtime:tick(16)
for _, event in ipairs(updates.events) do
  handle_event(event)
end
```

### integration:run_until_blocked(max_ticks)

Runs until no more progress can be made.

**Parameters:**
- `max_ticks` (number, optional): Maximum ticks (default: 1000)

**Returns:** Number of ticks executed

```lua
local ticks = runtime:run_until_blocked(100)
```

### integration:on(event, callback)

Registers an event listener.

```lua
runtime:on("thread:completed", function(data)
  print("Thread done: " .. data.thread_id)
end)

runtime:on("timer:fired", function(data)
  print("Timer fired: " .. data.timer_id)
end)
```

---

## Engine Integration

The `whisker.core.engine` module provides WLS 2.0 integration.

### Creating WLS 2.0 Engine

```lua
local engine = require("whisker.core.engine")

local e = engine.create({
  enable_wls2 = true,
  wls2_options = {
    max_threads = 10,
    tick_rate = 60
  }
})
```

### Engine Methods

#### engine:has_wls2()

Checks if WLS 2.0 is enabled.

```lua
if e:has_wls2() then
  -- Use WLS 2.0 features
end
```

#### engine:spawn_thread(passage_id, options)

Spawns a thread from the engine.

```lua
local id = e:spawn_thread("Background", { priority = 3 })
```

#### engine:await_thread(thread_id)

Sets up await for thread completion.

```lua
e:await_thread("thread_1")
```

#### engine:schedule_content(delay, content, options)

Schedules content.

```lua
e:schedule_content(2000, "Later...", {
  callback = function(c) e:add_output(c) end
})
```

#### engine:apply_effect(text, effect_name, options)

Applies effect to text.

```lua
e:apply_effect("Dramatic!", "shake", { intensity = 5 })
```

#### engine:register_externals(functions)

Registers external functions.

```lua
e:register_externals({
  playSound = audio.play,
  getScore = function() return score end
})
```

#### engine:call_external(name, ...)

Calls an external function.

```lua
local score = e:call_external("getScore")
```

#### engine:tick(delta_ms)

Advances time.

```lua
-- Game loop
while running do
  e:tick(16)
  render(e:get_output())
end
```

#### engine:run_until_blocked(max_ticks)

Runs until blocked.

```lua
e:run_until_blocked(1000)
```

---

## Events

### Thread Events

| Event | Data | Description |
|-------|------|-------------|
| `thread:created` | `{ thread_id, passage_id }` | Thread created |
| `thread:started` | `{ thread_id }` | Thread started execution |
| `thread:completed` | `{ thread_id, result }` | Thread completed |
| `thread:error` | `{ thread_id, error }` | Thread error |
| `scheduler:all_complete` | `{}` | All threads completed |

### Timer Events

| Event | Data | Description |
|-------|------|-------------|
| `timer:scheduled` | `{ timer_id, delay }` | Timer scheduled |
| `timer:fired` | `{ timer_id, content }` | Timer delivered content |
| `timer:cancelled` | `{ timer_id }` | Timer cancelled |
| `timer:paused` | `{ timer_id }` | Timer paused |
| `timer:resumed` | `{ timer_id }` | Timer resumed |

### Effect Events

| Event | Data | Description |
|-------|------|-------------|
| `effect:started` | `{ effect_id, name }` | Effect started |
| `effect:progress` | `{ effect_id, progress, text }` | Effect progress |
| `effect:completed` | `{ effect_id, final_text }` | Effect completed |
| `effect:cancelled` | `{ effect_id }` | Effect cancelled |

---

## Error Handling

All WLS 2.0 modules use consistent error handling:

```lua
-- Check operation success
local success, err = manager:try_call("riskyFunction")
if not success then
  print("Error: " .. err)
end

-- Listen for errors
runtime:on("thread:error", function(data)
  log_error(data.thread_id, data.error)
end)
```

### Common Errors

| Error | Description |
|-------|-------------|
| `thread_not_found` | Thread ID doesn't exist |
| `max_threads_exceeded` | Too many concurrent threads |
| `timer_not_found` | Timer ID doesn't exist |
| `effect_not_found` | Effect type not registered |
| `function_not_found` | External function not registered |
| `invalid_time_format` | Time string couldn't be parsed |
