# Importing Twine Stories into whisker-core

This guide walks through importing existing Twine HTML files into whisker-core.

## Quick Start

```lua
local TwineParser = require('whisker.twine.parser')

-- Load Twine HTML file
local file = io.open("my_story.html", "r")
local html_content = file:read("*all")
file:close()

-- Parse to whisker story
local story, err = TwineParser.parse(html_content)

if not story then
  error("Failed to parse: " .. err)
end

-- Access passages
for _, passage in ipairs(story.passages) do
  print("Passage:", passage.name)
end
```

## Step-by-Step Process

### Step 1: Export from Twine

1. Open your story in Twine editor
2. Click **Build > Publish to File**
3. Save as `.html` file

### Step 2: Verify Format

Check which story format your story uses:

1. Open HTML file in text editor
2. Look for `format="..."` in `<tw-storydata>` tag
3. Note format name and version

### Step 3: Parse with whisker-core

```lua
local TwineParser = require('whisker.twine.parser')

local story, err = TwineParser.parse(html_content)

if not story then
  print("Parse error:", err)
  return
end

-- Check for warnings
if story.warnings then
  for _, warning in ipairs(story.warnings) do
    print("Warning:", warning)
  end
end
```

### Step 4: Review Passages

```lua
-- Iterate passages
for i, passage in ipairs(story.passages) do
  print(string.format("Passage %d: %s", i, passage.name))

  -- Check passage tags
  if passage.tags and #passage.tags > 0 then
    print("  Tags:", table.concat(passage.tags, ", "))
  end

  -- Review AST nodes
  for _, node in ipairs(passage.ast) do
    print("  Node type:", node.type)
  end
end
```

### Step 5: Access Story Metadata

```lua
print("Story name:", story.metadata.name)
print("Format:", story.metadata.format)
print("IFID:", story.metadata.ifid)
print("Start passage:", story.metadata.startnode)

-- CSS and JavaScript
if story.css and story.css ~= "" then
  print("Custom CSS found")
end

if story.javascript and story.javascript ~= "" then
  print("Custom JavaScript found")
end
```

## Format-Specific Notes

### Importing Harlowe

Harlowe uses parenthetical macro syntax:

```
(set: $gold to 100)
(if: $gold > 50)[You are wealthy.]
```

**Supported**:
- Variable assignment with `(set:)` and `(put:)`
- Conditionals with `(if:)`, `(else-if:)`, `(else:)`
- Links with `(link:)` and `(link-goto:)`
- Arrays with `(a:)` and datamaps with `(dm:)`
- Loops with `(for:)`

**Limited**:
- `(live:)` macros execute once
- Named hooks converted to fragments

### Importing SugarCube

SugarCube uses angle-bracket macros:

```
<<set $gold to 100>>
<<if $gold > 50>>You are wealthy.<<else>>You are poor.<</if>>
```

**Supported**:
- All assignment forms: `=`, `+=`, `-=`, `++`, `--`
- Conditionals: `<<if>>`, `<<elseif>>`, `<<else>>`
- Loops: `<<for>>` (C-style and range)
- Widgets: `<<widget>>` definitions
- Control flow: `<<switch>>`, `<<case>>`

**Limited**:
- `<<script>>` blocks translate simple JS
- Special passages (StoryInit) are processed

### Importing Chapbook

Chapbook uses modifier/insert syntax:

```
gold: 100
--

[if gold > 50]
You are wealthy.

{gold} coins remaining.
```

**Supported**:
- Variable assignment in vars section
- Conditionals: `[if]`, `[unless]`
- Inserts: `{variable}`, `{random()}`
- Wiki-style links: `[[text->destination]]`

**Limited**:
- `[after]` modifiers show immediately
- Markdown formatting preserved as text

### Importing Snowman

Snowman uses ERB-style templates:

```
<% s.gold = s.gold || 100; %>
<%= s.gold %> coins
<% if (s.gold > 50) { %>Rich!<% } %>
```

**Supported**:
- Variable access via `s.` object
- Template expressions `<%= %>`
- Code blocks `<% %>`
- Navigation via `window.story.show()`

**Limited**:
- JavaScript translation is best-effort
- DOM manipulation not supported

## Accessing Parsed Content

### Story Metadata

```lua
story.metadata = {
  name = "Story Title",
  ifid = "UUID",
  format = "harlowe",
  format_version = "3.3.8",
  startnode = 1,
  creator = "Twine",
  creator_version = "2.6.0"
}
```

### Passages

```lua
passage = {
  pid = 1,
  name = "Start",
  tags = { "startup" },
  position = { x = 100, y = 100 },
  content = "Raw passage text",
  text = "Raw passage text",
  ast = { ... }  -- Parsed AST nodes
}
```

### AST Nodes

Common node types:

```lua
-- Text
{ type = "text", content = "Plain text" }

-- Assignment
{ type = "assignment", variable = "gold", value = { ... } }

-- Conditional
{ type = "conditional", condition = { ... }, body = { ... } }

-- Choice/Link
{ type = "choice", text = "Go north", destination = "North" }

-- Goto
{ type = "goto", destination = "End" }
```

## Error Handling

```lua
local story, err = TwineParser.parse(html_content)

if not story then
  -- Parse failed completely
  print("Error:", err)
  return
end

-- Check format detection
print("Detected format:", story.metadata.format)

-- Collect warnings during parsing
local warning_count = 0
for _, passage in ipairs(story.passages) do
  for _, node in ipairs(passage.ast) do
    if node.type == "warning" then
      print("Warning in", passage.name, ":", node.message)
      warning_count = warning_count + 1
    end
  end
end

print("Total warnings:", warning_count)
```

## See Also

- [Twine Compatibility](TWINE_COMPATIBILITY.md) - Full macro support matrix
- [Twine Export Guide](TWINE_EXPORT_GUIDE.md) - Exporting to Twine formats
