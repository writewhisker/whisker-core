# whisker-core 🎮

[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Lua](https://img.shields.io/badge/lua-5.1%2B-purple.svg)](https://www.lua.org/)
[![Version](https://img.shields.io/badge/version-0.0.1--dev-orange.svg)]()

**Core Lua library for interactive fiction and choice-based narratives.** This is the engine that powers whisker - a pure Lua interactive fiction engine with no dependencies.

> **Note:** This is the core library only. For visual editors and authoring tools, see:
> - **[whisker-editor-web](https://github.com/writewhisker/whisker-editor-web)** - Visual web-based story editor (AGPLv3)
> - **Full ecosystem:** [writewhisker organization](https://github.com/writewhisker)

## 🛠️ What is whisker-core?

whisker-core is a lightweight, embeddable interactive fiction engine written in pure Lua. It provides:

- 📦 **Pure Lua** - Zero dependencies, runs anywhere Lua 5.1+ runs
- 🔧 **Embeddable** - Integrate into games, applications, or tools
- ⚡ **Efficient** - Compact story format (20-40% smaller than alternatives)
- 🧪 **Well-tested** - Comprehensive test suite
- 🔄 **Format Support** - Import/export Twine (Harlowe, SugarCube, Chapbook, Snowman)
- 🐛 **Developer Tools** - Built-in debugger, profiler, and validator

## 📦 Installation

### LuaRocks (Recommended)

```bash
luarocks install whisker-core
```

### Manual Installation

```bash
git clone https://github.com/writewhisker/whisker-core.git
cd whisker-core
# Add lib/ to your Lua path
export LUA_PATH="./lib/?.lua;./lib/?/init.lua;$LUA_PATH"
```

## 🚀 Quick Start

### Basic Story Creation

```lua
local Story = require("whisker.core.story")
local Passage = require("whisker.core.passage")
local Choice = require("whisker.core.choice")

-- Create a new story
local story = Story.new({
    title = "My Adventure",
    author = "Your Name"
})

-- Create the starting passage
local start = Passage.new({
    id = "start",
    content = "You wake up in a mysterious cave. What do you do?"
})

-- Add choices
start:add_choice(Choice.new({
    text = "Explore deeper into the cave",
    target = "deep_cave"
}))

start:add_choice(Choice.new({
    text = "Head toward the light",
    target = "exit"
}))

-- Add passage to story
story:add_passage(start)
story:set_start_passage("start")

return story
```

### Running a Story

```lua
local Runtime = require("whisker.runtime.engine")

-- Load your story
local story = require("my_story")

-- Create runtime engine
local runtime = Runtime.new(story)

-- Start the story
runtime:start()

-- Get current passage
local passage = runtime:get_current_passage()
print(passage.content)

-- Display choices
for i, choice in ipairs(passage:get_choices()) do
    print(string.format("%d. %s", i, choice.text))
end

-- Make a choice
runtime:choose(1)  -- Select first choice
```

## 📚 Core Modules

### Story Management
- **`whisker.core.story`** - Story container and metadata
- **`whisker.core.passage`** - Individual story passages/nodes
- **`whisker.core.choice`** - Choice options and branching
- **`whisker.core.variable`** - Story state variables

### Runtime
- **`whisker.runtime.engine`** - Story execution engine
- **`whisker.runtime.state`** - State management and save/load
- **`whisker.runtime.history`** - Passage history and navigation

### Format Support
- **`whisker.format.twine`** - Import/export Twine HTML
- **`whisker.format.json`** - JSON story format
- **`whisker.format.compact`** - Compact binary format (20-40% smaller)

### Parser
- **`whisker.parser.twee`** - Parse Twee text format
- **`whisker.parser.markdown`** - Markdown passage content

### Developer Tools
- **`whisker.tools.validator`** - Validate story structure
- **`whisker.tools.debugger`** - Interactive debugging
- **`whisker.tools.profiler`** - Performance profiling

## 🔧 Advanced Features

### Variables and Conditional Logic

```lua
local passage = Passage.new({
    id = "shop",
    content = "Welcome to the shop!",
    conditions = {
        { var = "gold", op = ">=", value = 10 }
    }
})

-- Modify variables
runtime:set_variable("gold", 50)
runtime:set_variable("has_sword", true)
```

### Save/Load System

```lua
-- Save game state
local save_data = runtime:save()

-- Load game state
runtime:load(save_data)
```

### Event System

```lua
-- Listen for passage changes
runtime:on("passage_change", function(old_passage, new_passage)
    print("Moved from " .. old_passage.id .. " to " .. new_passage.id)
end)
```

## 📖 Documentation

- **[API Reference](docs/API_REFERENCE.md)** - Complete API documentation
- **[Architecture Guide](docs/ARCHITECTURE.md)** - Engine internals
- **[Format Specification](docs/COMPACT_FORMAT.md)** - Story format details
- **[Examples](examples/)** - Working code examples

## 🎯 Use Cases

- **Game Development** - Embed interactive narratives in games
- **Educational Software** - Create interactive tutorials
- **Chatbots** - Conversation flow management
- **Content Tools** - Build custom authoring tools
- **Prototyping** - Rapid dialogue system prototyping

## 🏗️ Library Structure

```
lib/whisker/
├── core/          # Core story primitives
│   ├── story.lua
│   ├── passage.lua
│   ├── choice.lua
│   └── variable.lua
├── runtime/       # Story execution
│   ├── engine.lua
│   ├── state.lua
│   └── history.lua
├── format/        # Import/Export
│   ├── twine/
│   ├── json.lua
│   └── compact.lua
├── parser/        # Text parsing
│   ├── twee.lua
│   └── markdown.lua
├── tools/         # Developer tools
│   ├── validator.lua
│   ├── debugger.lua
│   └── profiler.lua
└── utils/         # Utilities
    └── helpers.lua
```

## 🤝 Contributing

Contributions welcome! This is the core library, so we prioritize:

- **Stability** - Backward compatibility is important
- **Performance** - Keep it fast and lightweight
- **Testing** - All features must have tests
- **Documentation** - Clear API docs and examples

### Development Setup

```bash
git clone https://github.com/writewhisker/whisker-core.git
cd whisker-core

# Run tests
busted tests/

# Run validator on examples
lua bin/whisker --validate examples/simple.lua
```

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

This permissive license allows you to use whisker-core in commercial and open-source projects.

## 🔗 Related Projects

Part of the **writewhisker** ecosystem:

- **[whisker-editor-web](https://github.com/writewhisker/whisker-editor-web)** - Visual web editor (AGPLv3)
- **[whisker-editor-desktop](https://github.com/writewhisker/whisker-editor-desktop)** - Desktop editor (AGPLv3)
- **More coming soon!**

## 📞 Support

- **Documentation:** [docs/](docs/)
- **Issues:** [GitHub Issues](https://github.com/writewhisker/whisker-core/issues)
- **Discussions:** [GitHub Discussions](https://github.com/writewhisker/whisker-core/discussions)

## 🙏 Acknowledgments

- Inspired by [Twine](https://twinery.org/) and its community
- Built with [Lua](https://www.lua.org/)
- Thanks to all contributors

---

**Build interactive narratives into your applications!** 🚀

For visual authoring tools, check out [whisker-editor-web](https://github.com/writewhisker/whisker-editor-web).
