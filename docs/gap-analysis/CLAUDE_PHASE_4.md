# CLAUDE.md - Whisker-Core Phase 4: Enhanced Twine Support

## Quick Reference

**Repository:** https://github.com/writewhisker/whisker-core  
**Phase:** 4 of 7 — Enhanced Twine Support  
**Language:** Lua  
**Test Framework:** Busted  
**CI:** GitHub Actions  

## Stage Completion Workflow

When asked to "complete stage N" or "implement stage N", follow this exact workflow:

### Step 1: Setup Branch
```bash
# Ensure we're on main and up to date
git checkout main
git pull origin main

# Create stage branch with descriptive name
git checkout -b phase4/stage-{NN}-{kebab-case-description}
```

**Branch naming examples:**
- Stage 01 → `phase4/stage-01-module-structure-interfaces`
- Stage 06 → `phase4/stage-06-harlowe-lexer`
- Stage 10 → `phase4/stage-10-harlowe-converter`

### Step 2: Implement Stage
1. Read the stage requirements from `docs/phase4-stages.md` (or the implementation stages document)
2. Create all files listed in "Outputs"
3. Implement all items in "Tasks"
4. Follow patterns in this CLAUDE.md
5. Write tests for all new code

### Step 3: Verify Locally
```bash
# Run all tests
busted tests/

# Run specific stage tests
busted tests/unit/formats/twine/

# Check for lua syntax errors
luacheck lib/whisker/formats/twine/

# Verify test coverage (if coverage tool available)
busted --coverage tests/
```

### Step 4: Commit Changes
```bash
# Stage all new and modified files
git add -A

# Commit with conventional commit format
git commit -m "feat(twine): implement stage {NN} - {description}

- {bullet point for each major deliverable}
- {bullet point for each major deliverable}

Closes #ISSUE_NUMBER (if applicable)"
```

**Commit message examples:**
```
feat(twine): implement stage 01 - module structure and interfaces

- Define ITwineFormat, ITwineArchive, ITwineMacro interfaces
- Create directory structure for all Twine formats
- Add contract tests for interface compliance
- Register format.twine capability with container
```

### Step 5: Push and Create PR
```bash
# Push branch to origin
git push -u origin phase4/stage-{NN}-{description}

# Create PR using GitHub CLI
gh pr create \
  --title "feat(twine): Stage {NN} - {Title from stages doc}" \
  --body "## Summary
Implements Phase 4, Stage {NN}: {Full title}

## Changes
- {List of files created/modified}

## Checklist
- [ ] All tasks from stage completed
- [ ] Unit tests written and passing
- [ ] Test coverage ≥85%
- [ ] Code follows project conventions
- [ ] No linting errors

## Testing
\`\`\`bash
busted tests/unit/formats/twine/{relevant_path}/
\`\`\`
" \
  --base main
```

### Step 6: Wait for CI and Verify
```bash
# Watch CI status
gh pr checks --watch

# If checks fail, view the logs
gh run view --log-failed

# Fix any issues, then:
git add -A
git commit -m "fix: address CI failures"
git push
```

### Step 7: Merge PR (after CI passes)
```bash
# Merge using squash (preferred) or merge commit
gh pr merge --squash --delete-branch

# Or if you prefer merge commits:
gh pr merge --merge --delete-branch
```

### Complete Single Command Example
When user says `complete stage 6`, execute this full workflow for Stage 06: Harlowe Lexer Implementation.

---

## Stage Reference

### Stage Descriptions (for branch naming)

| Stage | Branch Suffix | Description |
|-------|---------------|-------------|
| 01 | `module-structure-interfaces` | Twine Module Structure and Interfaces |
| 02 | `html-archive-parser` | HTML Archive Parser |
| 03 | `format-detection-extraction` | Format Detection and Passage Extraction |
| 04 | `common-link-parser` | Common Link Parser |
| 05 | `base-format-variables` | Base Format Class and Variable Handling |
| 06 | `harlowe-lexer` | Harlowe Lexer Implementation |
| 07 | `harlowe-parser-ast` | Harlowe Parser and AST |
| 08 | `harlowe-macro-registry-core` | Harlowe Macro Registry and Core Macros |
| 09 | `harlowe-control-data-macros` | Harlowe Control Flow and Data Macros |
| 10 | `harlowe-converter` | Harlowe to Whisker Converter |
| 11 | `sugarcube-lexer` | SugarCube Lexer Implementation |
| 12 | `sugarcube-parser-ast` | SugarCube Parser and AST |
| 13 | `sugarcube-macros` | SugarCube Macro Registry and Macros |
| 14 | `sugarcube-converter` | SugarCube to Whisker Converter |
| 15 | `chapbook-parser-converter` | Chapbook Parser and Converter |
| 16 | `snowman-parser-converter` | Snowman Parser and Converter |
| 17 | `export-harlowe` | Whisker to Harlowe Export |
| 18 | `export-sugarcube` | Whisker to SugarCube Export |
| 19 | `html-archive-generation` | HTML Archive Generation |
| 20 | `integration-tests` | Container Registration and Integration Tests |
| 21 | `documentation` | Format Documentation and Compatibility Guide |

### Stage Dependencies

```
Stage 01 ─┬─► Stage 02 ─► Stage 03
          │
          └─► Stage 04 ─► Stage 05 ─┬─► Stages 06-10 (Harlowe)
                                    ├─► Stages 11-14 (SugarCube)
                                    ├─► Stage 15 (Chapbook)
                                    └─► Stage 16 (Snowman)

Stages 10,14,15,16 ─► Stages 17-19 (Export) ─► Stage 20 ─► Stage 21
```

---

## Project Structure

### Directory Layout
```
lib/whisker/formats/twine/
├── init.lua                    # Module entry, format registry
├── interfaces.lua              # ITwineFormat, ITwineArchive, ITwineMacro
├── archive/
│   ├── init.lua
│   ├── parser.lua             # HTML archive parser
│   ├── extractor.lua          # Passage extraction
│   ├── detector.lua           # Format auto-detection
│   └── writer.lua             # Archive generation
├── common/
│   ├── init.lua
│   ├── links.lua              # [[...]] link parser
│   ├── variables.lua          # $var, _temp handling
│   └── base_format.lua        # Abstract base class
├── harlowe/
│   ├── init.lua
│   ├── tokens.lua             # Token type definitions
│   ├── lexer.lua              # (macro:) tokenizer
│   ├── ast.lua                # AST node definitions
│   ├── parser.lua             # AST builder
│   ├── macros/
│   │   ├── init.lua           # Registry + all macros
│   │   ├── registry.lua
│   │   ├── control.lua        # if, unless, else, for
│   │   ├── variables.lua      # set, put
│   │   ├── links.lua          # link, goto, link-goto
│   │   ├── data.lua           # a, dm, ds
│   │   ├── utility.lua        # either, nth, range
│   │   ├── state.lua          # history, passage
│   │   └── text.lua           # print, num, str
│   ├── converter.lua          # Harlowe → Whisker
│   └── format.lua             # ITwineFormat impl
├── sugarcube/
│   ├── init.lua
│   ├── tokens.lua
│   ├── lexer.lua              # <<macro>> tokenizer
│   ├── ast.lua
│   ├── parser.lua
│   ├── macros/
│   │   ├── init.lua
│   │   ├── registry.lua
│   │   ├── control.lua
│   │   ├── variables.lua
│   │   ├── links.lua
│   │   └── widgets.lua
│   ├── converter.lua
│   └── format.lua
├── chapbook/
│   ├── init.lua
│   ├── parser.lua             # [modifier] parser
│   ├── modifiers.lua
│   └── converter.lua
├── snowman/
│   ├── init.lua
│   ├── template.lua           # <% %> parser
│   └── converter.lua
└── export/
    ├── init.lua
    ├── harlowe.lua            # Whisker → Harlowe
    ├── sugarcube.lua          # Whisker → SugarCube
    └── archive.lua            # HTML generation

tests/
├── unit/formats/twine/
│   ├── archive/
│   ├── common/
│   ├── harlowe/
│   │   ├── lexer_spec.lua
│   │   ├── parser_spec.lua
│   │   ├── macros/
│   │   └── converter_spec.lua
│   ├── sugarcube/
│   ├── chapbook/
│   ├── snowman/
│   └── export/
├── integration/formats/twine/
├── contracts/
└── fixtures/twine/
    ├── archives/
    ├── harlowe/
    ├── sugarcube/
    ├── chapbook/
    └── snowman/
```

---

## Code Patterns

### Module Structure
```lua
-- lib/whisker/formats/twine/harlowe/lexer.lua
local HarloweLexer = {}
HarloweLexer.__index = HarloweLexer

function HarloweLexer.new(source)
  return setmetatable({
    source = source,
    pos = 1,
    line = 1,
    column = 1,
    tokens = {}
  }, HarloweLexer)
end

function HarloweLexer:tokenize()
  -- Implementation
  return self.tokens
end

return HarloweLexer
```

### Interface Definitions
```lua
-- lib/whisker/formats/twine/interfaces.lua
local Interfaces = {}

Interfaces.ITwineFormat = {
  can_import = "function(self, source) -> boolean",
  import = "function(self, source) -> Story",
  can_export = "function(self, story) -> boolean",
  export = "function(self, story) -> string",
  get_format_name = "function(self) -> string",
  get_format_version = "function(self) -> string",
  parse_passage = "function(self, content) -> AST",
  get_supported_macros = "function(self) -> table",
}

Interfaces.ITwineMacro = {
  name = "string",
  aliases = "table",
  format = "string",
  has_body = "function(self) -> boolean",
  parse = "function(self, args, body, ctx) -> node",
  convert = "function(self, node, ctx) -> whisker_node",
}

return Interfaces
```

### Macro Implementation
```lua
-- lib/whisker/formats/twine/harlowe/macros/control.lua
local IfMacro = {}
IfMacro.__index = IfMacro

IfMacro.name = "if"
IfMacro.aliases = {}
IfMacro.format = "harlowe"
IfMacro.category = "control"

function IfMacro:has_body()
  return true
end

function IfMacro:parse(args, body, ctx)
  if #args < 1 then
    ctx:error("(if:) requires a condition")
  end
  return {
    type = "if",
    condition = args[1],
    hook = body
  }
end

function IfMacro:convert(node, ctx)
  return ctx:create_conditional(node.condition, node.hook)
end

return IfMacro
```

### AST Nodes
```lua
-- lib/whisker/formats/twine/harlowe/ast.lua
local AST = {}

function AST.TextNode(text, position)
  return { type = "text", value = text, position = position }
end

function AST.MacroNode(name, args, hook, position)
  return { type = "macro", name = name, arguments = args, hook = hook, position = position }
end

function AST.HookNode(content, name, position)
  return { type = "hook", name = name, content = content, position = position }
end

function AST.LinkNode(display, target, setter, position)
  return { type = "link", display = display, target = target, setter = setter, position = position }
end

return AST
```

### Token Types
```lua
-- lib/whisker/formats/twine/harlowe/tokens.lua
local TokenType = {
  MACRO_START = "MACRO_START",
  MACRO_END = "MACRO_END",
  HOOK_START = "HOOK_START",
  HOOK_END = "HOOK_END",
  MACRO_NAME = "MACRO_NAME",
  VARIABLE = "VARIABLE",
  STRING = "STRING",
  NUMBER = "NUMBER",
  BOOLEAN = "BOOLEAN",
  OPERATOR = "OPERATOR",
  KEYWORD = "KEYWORD",
  LINK = "LINK",
  TEXT = "TEXT",
  EOF = "EOF",
  ERROR = "ERROR",
}

return TokenType
```

---

## Test Patterns

### Unit Test Structure
```lua
-- tests/unit/formats/twine/harlowe/lexer_spec.lua
describe("HarloweLexer", function()
  local HarloweLexer = require("whisker.formats.twine.harlowe.lexer")
  local TokenType = require("whisker.formats.twine.harlowe.tokens")
  
  describe("tokenize", function()
    it("tokenizes plain text", function()
      local lexer = HarloweLexer.new("Hello world")
      local tokens = lexer:tokenize()
      
      assert.equals(1, #tokens)
      assert.equals(TokenType.TEXT, tokens[1].type)
    end)
    
    it("tokenizes simple macro", function()
      local lexer = HarloweLexer.new("(set: $x to 5)")
      local tokens = lexer:tokenize()
      
      assert.equals(TokenType.MACRO_START, tokens[1].type)
      assert.equals("set", tokens[1].name)
    end)
  end)
  
  describe("error handling", function()
    it("reports unclosed macro", function()
      local lexer = HarloweLexer.new("(set: $x to 5")
      local tokens = lexer:tokenize()
      
      assert.equals(TokenType.ERROR, tokens[#tokens].type)
    end)
  end)
end)
```

### Contract Test
```lua
-- tests/contracts/twine_format_contract.lua
local function create_format_contract(name)
  return function(FormatImpl)
    describe(name .. " implements ITwineFormat", function()
      local format
      
      before_each(function()
        format = FormatImpl.new()
      end)
      
      it("has can_import method", function()
        assert.is_function(format.can_import)
      end)
      
      it("has import method", function()
        assert.is_function(format.import)
      end)
      
      it("can_import returns boolean", function()
        local result = format:can_import("<tw-storydata></tw-storydata>")
        assert.is_boolean(result)
      end)
    end)
  end
end

return create_format_contract
```

---

## Format Syntax Reference

### Harlowe
```
(macro: args)[hook]           # Macro with hook
$variable                     # Story variable
_temporary                    # Temp variable
[[display->target]]           # Link arrow
[[display|target]]            # Link pipe
[[target]]                    # Simple link
it                            # Self-reference
```

### SugarCube
```
<<macro args>>content<</macro>>  # Block macro
<<macro args>>                   # Self-closing
$variable, _temp, setup.const    # Variables
[[display->target]]              # Links
```

### Chapbook
```
varname: value                   # Vars section
--                               # Separator
[if condition]                   # Modifier
{variable}                       # Insert
> [[choice]]                     # Fork
```

### Snowman
```
<% code %>                       # Execute JS
<%= expression %>                # Output
s.variable                       # State
link("text", "passage")          # Helper
```

---

## Events to Emit

```lua
-- Import
"twine:import:start"       { source = html }
"twine:archive:parsed"     { passages = count, format = name }
"twine:format:detected"    { format = name, version = ver }
"twine:passage:parsing"    { name = name }
"twine:macro:parsed"       { name = macro, format = format }
"twine:macro:unsupported"  { name = macro, format = format }
"twine:import:complete"    { story = story, warnings = warnings }

-- Export
"twine:export:start"       { story = story, format = target }
"twine:passage:rendered"   { name = name }
"twine:export:complete"    { html = html }
```

---

## Commands Reference

```bash
# Tests
busted tests/                                    # All tests
busted tests/unit/formats/twine/                 # Twine tests
busted tests/unit/formats/twine/harlowe/         # Harlowe tests
busted --coverage tests/                         # With coverage

# Linting
luacheck lib/whisker/formats/twine/

# Git workflow
git checkout -b phase4/stage-{NN}-{desc}
git add -A && git commit -m "feat(twine): ..."
git push -u origin phase4/stage-{NN}-{desc}

# GitHub CLI
gh pr create --title "..." --body "..." --base main
gh pr checks --watch
gh pr merge --squash --delete-branch
```

---

## Acceptance Criteria

Every stage must satisfy:
- [ ] All "Tasks" items completed
- [ ] All "Outputs" files created
- [ ] Unit tests passing
- [ ] Test coverage ≥85% (≥90% for lexer/parser)
- [ ] No linting errors
- [ ] Events emitted at appropriate points
- [ ] Errors include position information
- [ ] Integration with prior stages verified
