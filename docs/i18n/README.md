# whisker-core Internationalization (i18n)

whisker-core's i18n system enables creating interactive fiction that works in multiple languages. The system supports translation files in YAML, JSON, or Lua format, handles pluralization rules for 40+ languages, and provides proper text direction for right-to-left languages.

## Features

- **Translation Files**: YAML, JSON, or compiled Lua formats
- **Variable Interpolation**: `{name}` syntax for dynamic content
- **Pluralization**: CLDR-compliant rules for all major languages
- **RTL Support**: Automatic text direction for Arabic, Hebrew, etc.
- **Fallback Chain**: Graceful handling of missing translations
- **Workflow Tools**: Extract, validate, and compile translations
- **Whisker Script Integration**: `@@t` and `@@p` syntax for translations

## Quick Start

```lua
local I18n = require("whisker.i18n")

-- Initialize
local i18n = I18n.new():init({
  defaultLocale = "en",
  autoDetect = true
})

-- Load translations
i18n:loadData("en", {
  greeting = "Hello, {name}!",
  items = {
    count = {
      one = "{count} item",
      other = "{count} items"
    }
  }
})

-- Translate
print(i18n:t("greeting", { name = "Alice" }))
-- "Hello, Alice!"

-- Pluralize
print(i18n:p("items.count", 5))
-- "5 items"
```

## Documentation

| Guide | Audience | Description |
|-------|----------|-------------|
| [Author Guide](author-guide.md) | Story Authors | How to internationalize your stories |
| [Translator Guide](translator-guide.md) | Translators | How to create translations |
| [API Reference](api-reference.md) | Developers | Complete API documentation |
| [Best Practices](best-practices.md) | Everyone | Conventions and patterns |
| [Troubleshooting](troubleshooting.md) | Everyone | Common issues and solutions |
| [CLI Tools](cli-tools.md) | Authors/DevOps | Command-line tools |

## Examples

| Example | Description |
|---------|-------------|
| [Simple Story](examples/simple-story.md) | Basic i18n setup |
| [Advanced Features](examples/advanced-features.md) | Complex patterns |
| [RTL Languages](examples/rtl-languages.md) | Arabic, Hebrew support |
| [Multi-Locale Project](examples/multi-locale-project.md) | Full project setup |

## Supported Languages

whisker-core includes pluralization rules for 40+ languages including:

- **Western European**: English, Spanish, French, German, Italian, Portuguese
- **Eastern European**: Russian, Polish, Czech, Ukrainian
- **Asian**: Chinese, Japanese, Korean, Vietnamese, Thai
- **Middle Eastern**: Arabic, Hebrew, Persian, Turkish
- **Others**: Hindi, Indonesian, Filipino, and more

## Architecture

```
whisker.i18n
├── init.lua           -- Main I18n class
├── string_table.lua   -- Translation storage
├── locale.lua         -- Locale detection
├── pluralization.lua  -- Plural rules
├── bidi.lua           -- RTL text handling
├── formats/
│   ├── yaml.lua       -- YAML parser
│   ├── json.lua       -- JSON parser
│   └── lua.lua        -- Lua loader
└── tools/
    ├── extract.lua    -- String extraction
    ├── validate.lua   -- Translation validation
    └── status.lua     -- Status reporting
```

## Version

Current version: 1.0.0

## License

Part of whisker-core. See main project for license.
