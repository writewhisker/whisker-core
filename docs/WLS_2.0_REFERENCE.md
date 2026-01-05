# WLS 2.0 Reference Guide

This document covers all new features in Whisker Language Specification 2.0.

## Overview

WLS 2.0 introduces advanced narrative features for interactive fiction:

| Feature | Description | Syntax |
|---------|-------------|--------|
| Threads | Parallel narrative streams | `== ThreadName` |
| Timed Content | Delayed/scheduled content | `@delay`, `@every` |
| Text Effects | Visual text presentation | `@effect` |
| External Functions | Host application integration | `@external` |
| Audio | Sound and music control | `@audio`, `@play` |
| Parameterized Passages | Reusable passages with arguments | `:: Name(param)` |
| State Machines | LIST-based state management | `+=`, `-=`, `?` |

---

## Threads (Parallel Content)

Threads allow multiple narrative streams to execute simultaneously, enabling ambient storytelling and parallel events.

### Thread Spawning

Use `==` to define a thread passage:

```whisker
:: Start
The main story begins.
-> AmbientSounds

== AmbientSounds
{~|Wind howls.|Rain patters.|Thunder rumbles.}
@delay 2s { -> AmbientSounds }
```

### Thread Syntax

| Syntax | Description |
|--------|-------------|
| `== ThreadName` | Define a thread passage |
| `-> ThreadName` | Spawn a thread |
| `@await ThreadName` | Wait for thread completion |
| `@sync` | Synchronization point |

### Thread-Local Variables

Variables scoped to a specific thread:

```whisker
== CountingThread
@set $_thread.counter = 0
@loop 5 {
  @set $_thread.counter = $_thread.counter + 1
  Count: $_thread.counter
}
```

### Thread Priority

Control execution order:

```whisker
:: Start
-> HighPriority priority:10
-> LowPriority priority:1
-> NormalPriority
```

Higher priority threads execute first each tick.

### Awaiting Threads

Wait for a thread to complete:

```whisker
:: Start
-> BackgroundTask
Doing other things...
@await BackgroundTask
Background task finished!
```

---

## Timed Content

Reveal content after delays or on schedules.

### Basic Delay

```whisker
:: Suspense
You wait in silence.

@delay 2s {
Suddenly, a noise!
}
```

### Repeating Content

```whisker
:: Clock
@every 1s {
Tick.
}
```

### Timer Control

```whisker
:: Timer
@delay 5s id:countdown {
Time's up!
}

+ [Cancel] @cancel countdown
+ [Pause] @pause countdown
+ [Resume] @resume countdown
```

### Nested Delays

```whisker
:: Sequence
First.
@delay 1s {
Second.
  @delay 1s {
  Third.
  }
}
```

### Choice Timeouts

```whisker
:: TimedChoice
Make your choice!
@delay 10s {
  -> AutoChoice
}
+ [Option A] -> A
+ [Option B] -> B
```

### Time Formats

- `500ms` - Milliseconds
- `2s` - Seconds
- `1m` - Minutes
- `1.5s` - Fractional seconds

---

## Text Effects

Visual text presentation and animations.

### Built-in Effects

| Effect | Description | Syntax |
|--------|-------------|--------|
| `typewriter` | Character-by-character reveal | `@effect typewriter speed:50` |
| `fade-in` | Gradual opacity increase | `@effect fade-in 500ms` |
| `fade-out` | Gradual opacity decrease | `@effect fade-out 300ms` |
| `shake` | Vibration effect | `@effect shake 200ms intensity:5` |
| `rainbow` | Color cycling | `@effect rainbow 1s` |
| `glitch` | Distortion effect | `@effect glitch 500ms` |

### Typewriter Effect

```whisker
:: Introduction
@effect typewriter speed:30 {
Welcome to the story...
}
```

### Fade Effects

```whisker
:: Transition
@effect fade-in 1s {
The scene comes into focus.
}
```

### Inline Effects

```whisker
:: Danger
Watch out for [shake:DANGER] ahead!
```

### Chained Effects

```whisker
:: Dramatic
@effect fade-in 500ms {
  @effect typewriter {
    The truth is revealed...
  }
}
```

### Effect Control

```whisker
:: SkippableText
@effect typewriter id:intro {
Long introduction text...
}
+ [Skip] @skip intro
```

### Custom Effect Handlers

Define custom effects in the header:

```whisker
@effect bounce = {
  handler: "wave"
  duration: 500ms
  amplitude: 10
}

:: Start
@effect bounce {
Bouncing text!
}
```

---

## External Functions

Integrate with host application functionality.

### Declaration

```whisker
@external playSound(soundId: string)
@external getUserName(): string
@external saveProgress(slot: number): boolean
```

### Calling External Functions

```whisker
:: Victory
@call playSound("fanfare")
Congratulations, ${getUserName()}!
@call saveProgress(1)
```

### Namespaced Functions

```whisker
@external game.addScore(points: number)
@external game.getHighScore(): number
@external audio.setVolume(level: number)

:: Score
@call game.addScore(100)
High score: ${game.getHighScore()}
```

### Async External Functions

```whisker
@external async fetchQuote(): string

:: Quote
Loading...
@await fetchQuote() as quote
"$quote"
```

### Error Handling

```whisker
:: SafeCall
@try
  @call riskyFunction()
@catch error
  Something went wrong: $error
@endtry
```

### Host Registration (Lua)

```lua
local engine = require("whisker.core.engine")
local e = engine.create()

e:register_externals({
  playSound = function(soundId)
    -- Play sound
  end,
  getUserName = function()
    return "Player"
  end
})
```

---

## Audio

First-class audio and music control.

### Declaration

```whisker
@audio bgm = "music/theme.mp3" loop
@audio sfx_click = "sounds/click.wav"
@audio ambient = "sounds/forest.ogg" loop volume:0.5
```

### Playback Control

```whisker
:: Start
@play bgm
Music begins.

+ [Stop music]
  @stop bgm
+ [Pause music]
  @pause bgm
+ [Resume]
  @resume bgm
```

### Volume Control

```whisker
:: Volume
@play bgm
@volume bgm 0.5
Now quieter.
```

### Fading

```whisker
:: Transition
@play day_theme
@delay 3s {
  @fade day_theme 1s 0
  @play night_theme
}
```

### Crossfading

```whisker
:: SceneChange
@play track1
...
@crossfade track1 track2 2s
```

### Audio Channels

```whisker
@audio music = "theme.mp3" channel:music loop
@audio effect = "explosion.wav" channel:sfx
@audio narration = "intro.mp3" channel:voice

:: Start
@play music
@play effect
@play narration
```

### Autoplay on Passage Entry

```whisker
:: Forest
@audio forest_ambient = "forest.ogg" loop autoplay
You enter the forest.
```

### Inline Audio

```whisker
:: Bell
[audio:chime] The bell rings.
```

---

## Parameterized Passages

Reusable passages that accept arguments.

### Basic Parameters

```whisker
:: Describe(item)
You see a $item.

:: Start
-> Describe("sword") ->
-> Describe("shield") ->
```

### Default Values

```whisker
:: Greet(name, title = "friend")
Hello, $title $name!

:: Start
-> Greet("Alice") ->
-> Greet("Bob", "Sir") ->
```

Output:
```
Hello, friend Alice!
Hello, Sir Bob!
```

### Typed Parameters

```whisker
:: Calculate(x: number, y: number)
Result: ${x + y}

:: Start
-> Calculate(10, 20) ->
```

### Optional Parameters

```whisker
:: Format(value, prefix?, suffix?)
${prefix || ""}$value${suffix || ""}

:: Start
-> Format("test") ->
-> Format("test", "[", "]") ->
```

### Rest Parameters

```whisker
:: ListAll(...items)
@each item in items
  - $item
@endeach

:: Start
-> ListAll("apple", "banana", "cherry") ->
```

### Recursive Passages

```whisker
:: Countdown(n)
@if n > 0
  $n...
  -> Countdown(n - 1) ->
@else
  Blast off!
@endif

:: Start
-> Countdown(3) ->
```

### Parameters with Choices

```whisker
:: Talk(topic)
Discussing: $topic

:: Start
+ [Weather] -> Talk("weather") ->
+ [Sports] -> Talk("sports") ->
Continue...
```

### Tunnel Return with Parameters

```whisker
:: Transform(input)
Processing: $input
->->

:: Start
Before.
-> Transform("data") ->
After.
```

---

## State Machines (LIST Extensions)

Enhanced LIST operations for state management.

### LIST Definition

```whisker
LIST doorState = (closed), locked, unlocked, open
LIST inventory = empty
```

### State Transitions

| Operator | Description | Example |
|----------|-------------|---------|
| `+=` | Add state | `@set doorState += open` |
| `-=` | Remove state | `@set doorState -= locked` |
| `^=` | Toggle state | `@set inventory ^= hasKey` |

### State Queries

| Operator | Description | Example |
|----------|-------------|---------|
| `?` | Contains state | `@if doorState ? open` |
| `!?` | Does not contain | `@if doorState !? locked` |

### Example

```whisker
LIST doorState = (closed), locked, unlocked, open

:: Door
@if doorState ? closed
  The door is closed.
  + [Unlock]
    @set doorState -= closed
    @set doorState += unlocked
    -> Door
@endif

@if doorState ? unlocked
  The door is unlocked.
  + [Open]
    @set doorState -= unlocked
    @set doorState += open
    -> Door
@endif

@if doorState ? open
  You can pass through.
  + [Go through] -> NextRoom
@endif
```

### Multi-Value States

```whisker
LIST traits = brave, clever, strong

:: Character
@set traits += brave
@set traits += clever

@if traits ? brave
  You feel courageous.
@endif
```

---

## Migration from WLS 1.x

### Reserved Words

WLS 2.0 reserves new keywords. Variables using these names are automatically renamed:

| 1.x Variable | 2.0 Variable |
|--------------|--------------|
| `$thread` | `$_thread` |
| `$await` | `$_await` |
| `$spawn` | `$_spawn` |
| `$sync` | `$_sync` |
| `$channel` | `$_channel` |
| `$timer` | `$_timer` |
| `$effect` | `$_effect` |
| `$audio` | `$_audio` |
| `$external` | `$_external` |

### Using the Migration Tool

```bash
lua tools/migrate_1x_to_2x.lua story.ws -o story_2x.ws
```

Options:
- `-o, --output` - Output file (defaults to stdout)
- `--dry-run` - Show changes without writing
- `--report` - Generate migration report

### Deprecated Patterns

These patterns generate warnings in 2.0:

| Pattern | Warning | Replacement |
|---------|---------|-------------|
| `->->` tunnels | `TUNNEL_DEPRECATED` | Use parameterized passages |
| `<script>` blocks | `SCRIPT_DEPRECATED` | Use `@set` directives |
| `{{#if}}` blocks | `LEGACY_IF` | Use `@if` directive |
| `{{#each}}` blocks | `LEGACY_EACH` | Use `@each` directive |

---

## Error Codes

### WLS 2.0 Error Codes

| Code | Description |
|------|-------------|
| `WLS-THR-001` | Invalid thread definition |
| `WLS-THR-002` | Thread not found |
| `WLS-THR-003` | Circular thread dependency |
| `WLS-TMD-001` | Invalid time format |
| `WLS-TMD-002` | Timer not found |
| `WLS-EFX-001` | Unknown effect type |
| `WLS-EFX-002` | Invalid effect options |
| `WLS-EXT-001` | Undefined external function |
| `WLS-EXT-002` | External function type mismatch |
| `WLS-AUD-001` | Audio file not found |
| `WLS-AUD-002` | Invalid audio channel |
| `WLS-PRM-001` | Parameter type mismatch |
| `WLS-PRM-002` | Missing required parameter |
| `WLS-LST-001` | Invalid LIST operation |
| `WLS-LST-002` | Undefined LIST |

---

## Runtime API

### Lua Engine Integration

```lua
local engine = require("whisker.core.engine")

-- Create engine with WLS 2.0 support
local e = engine.create({
  enable_wls2 = true,
  wls2_options = {
    max_threads = 10,
    tick_rate = 60
  }
})

-- Load and start story
e:load_story(story_content)
e:start()

-- Game loop
while e:is_running() do
  e:tick(16)  -- 16ms per frame

  local output = e:get_output()
  print(output)

  if e:has_choices() then
    local choices = e:get_choices()
    -- Handle choice selection
  end
end
```

### Thread Control

```lua
-- Spawn a thread
local thread_id = e:spawn_thread("AmbientSounds", {
  priority = 5
})

-- Await thread completion
e:await_thread(thread_id)

-- Get thread status
local status = e:get_thread_status(thread_id)
```

### Timed Content

```lua
-- Schedule content
local timer_id = e:schedule_content(2000, "Delayed text", {
  repeat_interval = 1000
})

-- Cancel timer
e:cancel_timer(timer_id)
```

### Text Effects

```lua
-- Apply effect
e:apply_effect("Hello", "typewriter", {
  speed = 50
})

-- Register custom effect
e:register_effect("custom", function(text, options, callback)
  -- Custom effect implementation
  callback(text)
end)
```

### External Functions

```lua
-- Register external functions
e:register_externals({
  playSound = function(id)
    audio.play(id)
  end,
  getScore = function()
    return game.score
  end
})

-- Call external
local result = e:call_external("getScore")
```

---

## Best Practices

### Thread Management

1. **Limit concurrent threads** - Too many threads can impact performance
2. **Use priorities** - Important content should have higher priority
3. **Clean up threads** - Await or cancel threads when no longer needed
4. **Avoid circular spawning** - Threads should not spawn each other indefinitely

### Timed Content

1. **Use reasonable delays** - Keep players engaged, not waiting
2. **Provide skip options** - Let players skip long sequences
3. **Cancel on navigation** - Clean up timers when leaving passages
4. **Test on slow devices** - Timing may vary across platforms

### External Functions

1. **Document all externals** - Clearly define expected parameters
2. **Handle errors gracefully** - External calls can fail
3. **Use async for long operations** - Don't block the story
4. **Validate inputs** - Check types before processing

### Audio

1. **Preload important audio** - Use the `preload` flag
2. **Use channels appropriately** - Separate music, SFX, and voice
3. **Respect user preferences** - Honor volume/mute settings
4. **Crossfade for smooth transitions** - Avoid abrupt audio changes

### Parameterized Passages

1. **Use types when possible** - Catch errors early
2. **Provide defaults** - Make passages flexible
3. **Keep parameters minimal** - Too many becomes confusing
4. **Document expected values** - Comment complex passages
