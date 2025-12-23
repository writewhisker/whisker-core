# Exporting whisker-core Stories to Twine

Export whisker stories as Twine HTML files for use in Twine editor or distribution.

## Quick Start

```lua
local TwineExporter = require('whisker.twine.export.exporter')

-- Your whisker story
local story = {
  metadata = { name = "My Story" },
  passages = {
    { name = "Start", text = "Welcome to the story!" }
  }
}

-- Export to Harlowe format
local html = TwineExporter.export(story, "harlowe")

-- Save to file
local file = io.open("my_story.html", "w")
file:write(html)
file:close()
```

## Step-by-Step Process

### Step 1: Prepare Story

Create a story with proper structure:

```lua
local story = {
  metadata = {
    name = "My Adventure",
    ifid = nil,  -- Auto-generated if nil
    author = "Your Name"
  },
  passages = {
    {
      name = "Start",
      text = "Welcome to the adventure!",
      tags = {}
    },
    {
      name = "Forest",
      text = "You enter a dark forest.",
      tags = { "outdoors" }
    }
  },
  css = "",  -- Optional custom CSS
  javascript = ""  -- Optional custom JavaScript
}
```

### Step 2: Choose Target Format

```lua
local TwineExporter = require('whisker.twine.export.exporter')

-- Check supported formats
local formats = TwineExporter.get_supported_formats()
-- Returns: { "harlowe", "sugarcube", "chapbook", "snowman" }

-- Verify format support
if TwineExporter.is_format_supported("harlowe") then
  local html = TwineExporter.export(story, "harlowe")
end
```

### Step 3: Export

```lua
-- Basic export
local html, err = TwineExporter.export(story, "harlowe")

if not html then
  print("Export failed:", err)
  return
end

-- Export with options
local options = {
  format_options = ""  -- Format-specific settings
}
local html = TwineExporter.export(story, "sugarcube", options)
```

### Step 4: Save HTML File

```lua
local function save_html(html, filename)
  local file = io.open(filename, "w")
  if file then
    file:write(html)
    file:close()
    print("Exported to:", filename)
    return true
  else
    print("Failed to write file")
    return false
  end
end

-- Generate filename from story name
local filename = story.metadata.name:gsub("%s+", "_"):lower() .. ".html"
save_html(html, filename)
```

### Step 5: Open in Twine

1. Launch Twine editor
2. Click **Import from File**
3. Select exported HTML file
4. Story loads with passages positioned in grid layout
5. Verify format under **Story > Story Formats**

## Format-Specific Export

### Exporting to Harlowe

Best for narrative-focused interactive fiction.

```lua
local story = {
  metadata = { name = "Harlowe Story" },
  passages = {
    {
      name = "Start",
      ast = {
        { type = "assignment", variable = "gold", value = { type = "literal", value = 100 } },
        { type = "text", value = "You have some gold." },
        { type = "choice", text = "Continue", destination = "Next" }
      }
    }
  }
}

local html = TwineExporter.export(story, "harlowe")
-- Produces: (set: $gold to 100) You have some gold. [[Continue->Next]]
```

### Exporting to SugarCube

Best for complex games with state management.

```lua
local html = TwineExporter.export(story, "sugarcube")
-- Produces: <<set $gold to 100>> You have some gold. [[Continue|Next]]
```

### Exporting to Chapbook

Best for text-heavy stories with markdown.

```lua
local html = TwineExporter.export(story, "chapbook")
-- Produces: gold: 100\n--\nYou have some gold.\n[[Continue->Next]]
```

### Exporting to Snowman

Best for developers who prefer JavaScript/templates.

```lua
local html = TwineExporter.export(story, "snowman")
-- Produces: <% s.gold = 100 %> You have some gold. <a data-passage="Next">Continue</a>
```

## Story Structure

### Metadata

```lua
story.metadata = {
  name = "Story Title",        -- Required
  ifid = "UUID",               -- Optional, auto-generated
  author = "Author Name",      -- Optional
  description = "About..."     -- Optional
}
```

### Passages

Each passage needs at minimum:

```lua
passage = {
  name = "PassageName",  -- Required, unique
  text = "Content",      -- Plain text content
  -- OR
  ast = { ... },         -- AST nodes (for structured content)
  tags = { }             -- Optional tags
}
```

### AST Nodes for Export

The exporter serializes these AST node types:

```lua
-- Text content
{ type = "text", value = "Plain text" }

-- Variable assignment
{
  type = "assignment",
  variable = "varName",
  value = { type = "literal", value_type = "number", value = 100 }
}

-- Conditional
{
  type = "conditional",
  condition = { type = "binary_op", operator = ">", left = {...}, right = {...} },
  body = { ... },
  else_body = { ... }  -- Optional
}

-- Choice/Link
{
  type = "choice",
  text = "Link text",
  destination = "TargetPassage"
}

-- Goto
{ type = "goto", destination = "TargetPassage" }
```

## Passage Positioning

Exported passages are arranged in a grid:

- 5 columns
- 200px horizontal spacing
- 150px vertical spacing
- Starting position: (100, 100)

Example layout for 7 passages:
```
[1] [2] [3] [4] [5]
[6] [7]
```

Manually reposition in Twine editor if needed.

## Including CSS and JavaScript

```lua
local story = {
  metadata = { name = "Styled Story" },
  passages = { ... },
  css = [[
body {
  background-color: #1a1a1a;
  color: #ffffff;
}
  ]],
  javascript = [[
window.setup = {
  version: "1.0.0"
};
  ]]
}

local html = TwineExporter.export(story, "sugarcube")
-- CSS and JS are embedded in the exported HTML
```

## Validation

After exporting:

1. **Open in Twine editor**
   - Import the HTML file
   - Verify passages load correctly
   - Check passage connections (arrows)

2. **Test playthrough**
   - Click "Play" in Twine
   - Navigate through story
   - Verify variables and conditions work

3. **Check format**
   - Verify correct story format selected
   - Check format version in story settings

## Error Handling

```lua
local html, err = TwineExporter.export(story, "harlowe")

if not html then
  if err:find("Unsupported") then
    print("Format not supported:", err)
  elseif err:find("at least one passage") then
    print("Story needs passages")
  else
    print("Export error:", err)
  end
  return
end
```

## Limitations

### Features that may not export perfectly:

- Complex Lua code without macro equivalent
- Custom runtime features
- Format-specific macros when cross-exporting
- Animations and transitions

### Recommendations:

1. Use simple, portable constructs
2. Test exported HTML in Twine
3. Keep whisker-core source as authoritative
4. Document any manual adjustments needed

## See Also

- [Twine Compatibility](TWINE_COMPATIBILITY.md) - Full macro support matrix
- [Twine Import Guide](TWINE_IMPORT_GUIDE.md) - Importing from Twine
