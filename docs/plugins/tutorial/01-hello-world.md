# Tutorial 1: Hello World Plugin

## Goal

Create a minimal working plugin that logs a message and exposes a simple API.

## Prerequisites

- whisker-core installed
- Basic Lua knowledge
- Text editor

## Step 1: Create Plugin File

Create `hello-plugin.lua`:

```lua
return {
  name = "hello",
  version = "1.0.0",
}
```

This is the minimal valid plugin: just a name and version.

## Step 2: Add Lifecycle Hook

Add initialization hook:

```lua
return {
  name = "hello",
  version = "1.0.0",

  on_init = function(ctx)
    ctx.log.info("Hello plugin initialized!")
  end,
}
```

The `on_init` hook executes during story startup. The `ctx` parameter provides plugin context.

## Step 3: Expose API

Add public function:

```lua
return {
  name = "hello",
  version = "1.0.0",

  on_init = function(ctx)
    ctx.log.info("Hello plugin initialized!")
  end,

  api = {
    greet = function(name)
      return "Hello, " .. (name or "World") .. "!"
    end,
  },
}
```

## Step 4: Load Plugin

Place `hello-plugin.lua` in `plugins/community/` directory.

Configure story to load plugins:

```lua
local story = Story.new({
  plugins = {
    paths = {"plugins/builtin", "plugins/community"},
  },
})
```

## Step 5: Use Plugin

In story script:

```lua
local greeting = whisker.plugin.hello.greet("Alice")
print(greeting)  -- "Hello, Alice!"
```

## Complete Code

```lua
-- hello-plugin.lua
return {
  name = "hello",
  version = "1.0.0",

  author = "Your Name",
  description = "A simple greeting plugin",

  on_init = function(ctx)
    ctx.log.info("Hello plugin initialized!")
  end,

  api = {
    greet = function(name)
      return "Hello, " .. (name or "World") .. "!"
    end,
  },
}
```

## What's Next?

- [Tutorial 2: Using Hooks](02-using-hooks.md) - React to story events
- [Tutorial 3: State Management](03-state-management.md) - Store data
