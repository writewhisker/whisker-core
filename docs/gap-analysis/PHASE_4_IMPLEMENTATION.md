# Phase 4 Implementation Stages: Enhanced Twine Support

## Document Metadata

| Property | Value |
|----------|-------|
| Phase | 4 of 7 |
| Title | Enhanced Twine Support |
| Duration | 4-6 weeks |
| Stages | 21 stages |
| Code Volume | ~2,500-3,500 lines production + equivalent tests |
| Repository | https://github.com/writewhisker/whisker-core |

---

## Phase Context

### Executive Overview

Phase 4 implements comprehensive Twine story format support, enabling whisker-core to import, execute, and export stories created in Twine's visual editor. Twine is one of the most popular interactive fiction tools, with an estimated 50%+ market share among hobbyist IF creators. Full compatibility significantly expands whisker-core's utility and potential user base.

This phase covers four major story formats:
- **Harlowe** (~50% market share) — Default format, beginner-friendly, parentheses-based macros
- **SugarCube** (~35% market share) — Power-user format, wiki-style macros, JavaScript integration
- **Chapbook** (~10% market share) — Minimalist, modifier-based, clean prose
- **Snowman** (~5% market share) — Programmer-oriented, JavaScript templates

### Dependencies from Prior Phases

Phase 4 builds upon the complete Phases 1-3 infrastructure:

**From Phase 1 — Foundation & Modularity:**
- Microkernel architecture with dynamic module loader
- Dependency injection container (`whisker.container`)
- Event bus (`whisker.events`) for decoupled communication
- Interface contracts: `IFormat`, `IState`, `IEngine`, `IConditionEvaluator`
- Module lifecycle management
- Test infrastructure with contract tests

**From Phase 2 — Ink Integration:**
- `IFormat` implementation patterns for story formats
- Bidirectional conversion strategies
- Narrative construct mapping (choices, conditionals, variables)
- Round-trip testing patterns for format conversion

**From Phase 3 — Whisker Script:**
- Expression parsing and evaluation infrastructure
- Condition evaluator patterns
- Variable and state management patterns
- Error reporting with source context
- Lexer/parser patterns reusable for macro parsing

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Applications                                │
│  (CLI Player, Web Player, Editor, Custom Integrations)          │
├─────────────────────────────────────────────────────────────────┤
│                    Extension Layer                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                 Twine Format Module                          ││
│  │  ┌──────────┬──────────┬──────────┬──────────┐             ││
│  │  │ Harlowe  │SugarCube │ Chapbook │ Snowman  │             ││
│  │  └──────────┴──────────┴──────────┴──────────┘             ││
│  │           │                │                                 ││
│  │  ┌────────┴────────┬───────┴───────┐                        ││
│  │  │  Archive Parser │ Link Parser   │                        ││
│  │  └────────────────┴───────────────┘                         ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    Core Abstractions                             │
│  (Story, Passage, Choice, Condition Interfaces)                  │
├─────────────────────────────────────────────────────────────────┤
│                    Microkernel                                   │
│  (Module Loader, Dependency Injection, Event Bus)                │
└─────────────────────────────────────────────────────────────────┘
```

### Twine HTML Archive Format

Twine 2 stores stories in self-contained HTML files:

```html
<tw-storydata name="Story Title" 
              startnode="1" 
              creator="Twine" 
              creator-version="2.3.14" 
              ifid="12345678-ABCD-1234-EFGH-567890ABCDEF" 
              format="Harlowe" 
              format-version="3.2.3">
  
  <tw-passagedata pid="1" name="Start" tags="" position="100,100">
    Passage content with (macros:) and [[links]]
  </tw-passagedata>
  
  <style role="stylesheet" id="twine-user-stylesheet" type="text/twine-css">
    /* Custom author CSS */
  </style>
  
  <script role="script" id="twine-user-script" type="text/twine-javascript">
    // Custom author JavaScript
  </script>
  
</tw-storydata>
```

### Module Structure

```
lib/whisker/formats/twine/
├── init.lua                    # Module entry point, format registry
├── archive/
│   ├── init.lua               # Archive handling interface
│   ├── parser.lua             # HTML archive parser
│   ├── extractor.lua          # Passage/metadata extraction
│   └── writer.lua             # Archive generation
├── common/
│   ├── init.lua               # Shared utilities
│   ├── links.lua              # Link syntax parsing ([[...]])
│   ├── variables.lua          # Variable reference handling
│   └── base_format.lua        # Abstract base for formats
├── harlowe/
│   ├── init.lua               # Harlowe IFormat implementation
│   ├── lexer.lua              # Harlowe macro tokenizer
│   ├── parser.lua             # Harlowe AST builder
│   ├── macros/
│   │   ├── init.lua           # Macro registry
│   │   ├── control.lua        # if, unless, else, for
│   │   ├── variables.lua      # set, put, move
│   │   ├── links.lua          # link, goto, link-goto
│   │   ├── data.lua           # array (a:), datamap (dm:)
│   │   └── text.lua           # print, text, lowercase
│   └── converter.lua          # Harlowe → Whisker conversion
├── sugarcube/
│   ├── init.lua               # SugarCube IFormat implementation
│   ├── lexer.lua              # SugarCube macro tokenizer
│   ├── parser.lua             # SugarCube AST builder
│   ├── macros/
│   │   ├── init.lua           # Macro registry
│   │   ├── control.lua        # if, elseif, else, for, switch
│   │   ├── variables.lua      # set, unset, run
│   │   ├── links.lua          # link, goto, return
│   │   └── widgets.lua        # widget, capture
│   └── converter.lua          # SugarCube → Whisker conversion
├── chapbook/
│   ├── init.lua               # Chapbook IFormat implementation
│   ├── parser.lua             # Vars/modifier/insert parser
│   ├── modifiers.lua          # Modifier implementations
│   └── converter.lua          # Chapbook → Whisker conversion
├── snowman/
│   ├── init.lua               # Snowman IFormat implementation
│   ├── template.lua           # Template tag parser
│   └── converter.lua          # Snowman → Whisker conversion
└── export/
    ├── init.lua               # Export interface
    ├── harlowe.lua            # Whisker → Harlowe generation
    ├── sugarcube.lua          # Whisker → SugarCube generation
    └── archive.lua            # HTML archive assembly
```

### Interface Definitions

```lua
-- ITwineFormat: Extended format interface for Twine formats
ITwineFormat = {
  -- Inherits from IFormat
  can_import = function(self, source) end,
  import = function(self, source) end,
  can_export = function(self, story) end,
  export = function(self, story) end,
  
  -- Twine-specific extensions
  get_format_name = function(self) end,
  get_format_version = function(self) end,
  parse_passage = function(self, content) end,
  render_passage = function(self, passage) end,
  get_supported_macros = function(self) end,
}

-- ITwineArchive: Archive handling interface
ITwineArchive = {
  parse = function(self, html) end,
  get_passages = function(self) end,
  get_passage = function(self, name) end,
  get_metadata = function(self) end,
  detect_format = function(self) end,
  generate = function(self, story, options) end,
}

-- ITwineMacro: Macro implementation interface
ITwineMacro = {
  name = "string",
  aliases = {},
  format = "string",
  has_body = function(self) end,
  parse = function(self, args, body, ctx) end,
  convert = function(self, node, ctx) end,
}

-- IMacroRegistry: Macro registration and lookup
IMacroRegistry = {
  register = function(self, macro) end,
  get = function(self, name) end,
  has = function(self, name) end,
  list = function(self) end,
}
```

---

## Stage Groups Overview

| Group | Stages | Focus Area | Deliverables |
|-------|--------|------------|--------------|
| **A** | 01-03 | Infrastructure & Archive Parsing | Module structure, HTML parser, format detection |
| **B** | 04-05 | Common Twine Utilities | Link parser, base format class, variable handling |
| **C** | 06-10 | Harlowe Support | Lexer, parser, macro registry, macros, converter |
| **D** | 11-14 | SugarCube Support | Lexer, parser, macros, converter |
| **E** | 15-16 | Chapbook & Snowman | Lighter-weight format implementations |
| **F** | 17-19 | Export & Round-Trip | Whisker → Twine export, archive generation |
| **G** | 20-21 | Integration & Documentation | Container registration, tests, docs |

---

## Group A: Infrastructure & Archive Parsing

---

## Stage 01: Twine Module Structure and Interfaces

### Prerequisites
- Phase 1 complete (microkernel, DI container, interfaces)
- Phase 2 complete (IFormat implementation patterns)
- Phase 3 complete (lexer/parser patterns)

### Objectives
Establish the Twine module directory structure, define all Twine-specific interfaces, and create the module entry point that registers with the whisker container.

### Inputs
- `lib/whisker/interfaces/format.lua` (IFormat definition)
- `lib/whisker/kernel/container.lua` (DI container)
- `lib/whisker/kernel/registry.lua` (module registry patterns)

### Tasks
1. Create the `lib/whisker/formats/twine/` directory structure as specified in the architecture
2. Define `ITwineFormat` interface extending `IFormat`
3. Define `ITwineArchive` interface for archive operations
4. Define `ITwineMacro` interface for macro handlers
5. Define `IMacroRegistry` interface for macro registration
6. Define `ITwineLinkParser` interface for link syntax handling
7. Create `init.lua` module entry point with capability registration
8. Create interface contract tests following Phase 1 patterns
9. Register `format.twine` capability with whisker container

### Outputs
- `lib/whisker/formats/twine/init.lua` (new, ~80 lines)
- `lib/whisker/formats/twine/interfaces.lua` (new, ~120 lines)
- `tests/unit/formats/twine/interfaces_spec.lua` (new, ~100 lines)
- `tests/contracts/twine_format_contract.lua` (new, ~80 lines)

### Acceptance Criteria
- [ ] All Twine interfaces are defined with complete method signatures
- [ ] Module entry point loads without errors
- [ ] `whisker.capabilities:has("format.twine")` returns true after load
- [ ] Contract tests define behavior for all interface methods
- [ ] Directory structure matches specification

### Estimated Scope
- **Production code:** 180-220 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes

**Pattern: Interface Definition**
Follow the Phase 1 pattern for interface definitions:
```lua
-- lib/whisker/formats/twine/interfaces.lua
local Interfaces = {}

Interfaces.ITwineFormat = {
  -- Method signatures with documentation
  can_import = "function(self, source) -> boolean",
  import = "function(self, source) -> Story",
  -- ... etc
}

return Interfaces
```

**Pattern: Module Registration**
```lua
-- lib/whisker/formats/twine/init.lua
local Twine = {}

function Twine.init(container)
  container:register("format.twine", Twine, {
    implements = "IFormat",
    singleton = true
  })
  whisker.capabilities:add("format.twine")
end

return Twine
```

### Claude Code Instructions

To complete this stage using Claude Code:

```bash
# 1. Create the directory structure
claude "Create the directory structure for lib/whisker/formats/twine/ with subdirectories: archive, common, harlowe, sugarcube, chapbook, snowman, export. Add empty init.lua files in each."

# 2. Define interfaces
claude "Read the Phase 4 prompt document and create lib/whisker/formats/twine/interfaces.lua with ITwineFormat, ITwineArchive, ITwineMacro, IMacroRegistry, and ITwineLinkParser interfaces. Follow the interface pattern from lib/whisker/interfaces/format.lua"

# 3. Create module entry point
claude "Create lib/whisker/formats/twine/init.lua that requires the interfaces, sets up module registration with the DI container, and adds the format.twine capability"

# 4. Write contract tests
claude "Create tests/contracts/twine_format_contract.lua following the pattern from Phase 1 contract tests. Define test cases for each ITwineFormat method."

# 5. Write unit tests for interfaces
claude "Create tests/unit/formats/twine/interfaces_spec.lua that verifies interface definitions are complete and properly structured"

# 6. Verify
claude "Run all tests in tests/unit/formats/twine/ and tests/contracts/ related to Twine. Fix any failures."
```

---

## Stage 02: HTML Archive Parser

### Prerequisites
- Stage 01: Twine module structure and interfaces complete

### Objectives
Implement an HTML parser that extracts Twine story data from published HTML archive files. This parser handles the `<tw-storydata>` and `<tw-passagedata>` elements, extracting all metadata and passage content.

### Inputs
- `lib/whisker/formats/twine/interfaces.lua` (ITwineArchive interface)
- Sample Twine HTML files for testing
- HTML parsing library (recommend `htmlparser` or custom XML-like parser)

### Tasks
1. Create `TwineArchive` class implementing `ITwineArchive`
2. Implement `parse(html)` method:
   - Find `<tw-storydata>` element
   - Extract story metadata attributes
   - Find all `<tw-passagedata>` elements
   - Extract passage content (preserving original formatting)
3. Implement `get_metadata()` returning story info:
   - name, startnode, creator, creator-version
   - ifid, format, format-version, options
4. Implement `get_passages()` returning all passages
5. Implement `get_passage(name)` for single passage lookup
6. Handle edge cases:
   - Missing attributes (provide defaults)
   - HTML entities in passage content
   - CDATA sections
   - Malformed HTML (graceful degradation)
7. Extract author CSS and JavaScript if present
8. Write comprehensive unit tests

### Outputs
- `lib/whisker/formats/twine/archive/parser.lua` (new, ~200 lines)
- `lib/whisker/formats/twine/archive/init.lua` (new, ~40 lines)
- `tests/unit/formats/twine/archive/parser_spec.lua` (new, ~250 lines)
- `tests/fixtures/twine/archives/` (new fixture directory with sample HTML)

### Acceptance Criteria
- [ ] `TwineArchive.parse(html)` correctly parses valid Twine HTML
- [ ] All `<tw-storydata>` attributes are extracted
- [ ] All `<tw-passagedata>` elements are found and parsed
- [ ] Passage content preserves original formatting
- [ ] HTML entities are decoded correctly
- [ ] Malformed HTML produces errors with helpful messages
- [ ] Author CSS/JS are extracted when present
- [ ] Unit test coverage ≥90%

### Estimated Scope
- **Production code:** 200-250 lines
- **Test code:** 250-300 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes

**Pattern: HTML Parsing Strategy**
Since Twine HTML is well-structured, use a simple pattern-based approach:
```lua
function TwineArchive:parse(html)
  -- Find tw-storydata element
  local story_match = html:match('<tw%-storydata(.-)>(.-)</tw%-storydata>')
  if not story_match then
    error("No tw-storydata element found")
  end
  
  -- Extract attributes
  self.metadata = self:parse_attributes(story_match)
  
  -- Find all passages
  for attrs, content in html:gmatch('<tw%-passagedata(.-)>(.-)</tw%-passagedata>') do
    local passage = self:parse_passage(attrs, content)
    self.passages[passage.name] = passage
  end
end
```

**Pattern: HTML Entity Decoding**
```lua
local entities = {
  ["&amp;"] = "&",
  ["&lt;"] = "<",
  ["&gt;"] = ">",
  ["&quot;"] = '"',
  ["&#39;"] = "'",
}

function decode_entities(text)
  for entity, char in pairs(entities) do
    text = text:gsub(entity, char)
  end
  return text
end
```

### Claude Code Instructions

```bash
# 1. Create test fixtures first
claude "Create tests/fixtures/twine/archives/ directory with sample Twine HTML files: minimal.html (single passage), basic.html (3 passages with links), harlowe.html (Harlowe format with macros), sugarcube.html (SugarCube format), with_css_js.html (includes author CSS and JS)"

# 2. Implement the parser
claude "Read the ITwineArchive interface from lib/whisker/formats/twine/interfaces.lua. Create lib/whisker/formats/twine/archive/parser.lua implementing TwineArchive class with parse(), get_metadata(), get_passages(), and get_passage() methods"

# 3. Handle HTML entity decoding
claude "Add HTML entity decoding to the archive parser. Support &amp; &lt; &gt; &quot; &#39; and numeric entities like &#60;"

# 4. Create archive init module
claude "Create lib/whisker/formats/twine/archive/init.lua that exports the TwineArchive class"

# 5. Write comprehensive tests
claude "Create tests/unit/formats/twine/archive/parser_spec.lua with tests for: basic parsing, attribute extraction, passage extraction, HTML entity decoding, malformed HTML handling, CSS/JS extraction. Use the fixtures in tests/fixtures/twine/archives/"

# 6. Test error handling
claude "Add tests for error cases: missing tw-storydata, missing startnode, empty passages, duplicate passage names"
```

---

## Stage 03: Format Detection and Passage Extraction

### Prerequisites
- Stage 01: Module structure complete
- Stage 02: HTML archive parser complete

### Objectives
Implement format auto-detection from archive metadata and passage content analysis. Create a unified passage extractor that normalizes passage data across all formats.

### Inputs
- `lib/whisker/formats/twine/archive/parser.lua` (from Stage 02)
- Format-specific passage content samples

### Tasks
1. Implement `detect_format(archive)` method:
   - Check `format` attribute on `<tw-storydata>`
   - If missing/unknown, analyze passage content for format hints
   - Return format name and confidence level
2. Implement format-specific content hints detection:
   - Harlowe: `(macro:)` syntax
   - SugarCube: `<<macro>>` syntax
   - Chapbook: `[modifier]` lines, `--` separator
   - Snowman: `<%` and `%>` tags
3. Create `PassageExtractor` class:
   - Normalize passage data structure
   - Handle format-specific passage tags
   - Track passage relationships (linked passages)
4. Implement passage graph construction:
   - Build adjacency list from links
   - Detect unreachable passages
   - Identify start passage
5. Add format version detection where possible
6. Write tests with mixed-format detection scenarios

### Outputs
- `lib/whisker/formats/twine/archive/extractor.lua` (new, ~180 lines)
- `lib/whisker/formats/twine/archive/detector.lua` (new, ~120 lines)
- `tests/unit/formats/twine/archive/extractor_spec.lua` (new, ~150 lines)
- `tests/unit/formats/twine/archive/detector_spec.lua` (new, ~120 lines)

### Acceptance Criteria
- [ ] Format detection correctly identifies all 4 supported formats
- [ ] Content-based detection works when format attribute is missing
- [ ] Detection returns confidence score (high/medium/low)
- [ ] PassageExtractor produces normalized passage objects
- [ ] Passage graph correctly identifies all links
- [ ] Unreachable passages are flagged with warnings
- [ ] Format version is detected when present in content
- [ ] Tests cover all format detection scenarios

### Estimated Scope
- **Production code:** 280-320 lines
- **Test code:** 250-300 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes

**Pattern: Format Detection Heuristics**
```lua
local format_patterns = {
  harlowe = {
    patterns = { "%(%w+:[^%)]*%)", "%[%[.-%]%]" },
    weight = 1.0
  },
  sugarcube = {
    patterns = { "<<%w+", "<</", "$%w+" },
    weight = 1.0
  },
  chapbook = {
    patterns = { "^%[%w+%]", "^%-%-$", "{%w+}" },
    weight = 0.8
  },
  snowman = {
    patterns = { "<%% ", " %%>", "<%%=" },
    weight = 0.9
  }
}

function detect_format(archive)
  -- First check metadata
  local meta_format = archive:get_metadata().format
  if meta_format and format_patterns[meta_format:lower()] then
    return meta_format:lower(), 1.0
  end
  
  -- Content-based detection
  local scores = {}
  for name, config in pairs(format_patterns) do
    scores[name] = calculate_score(archive, config)
  end
  
  return highest_score(scores)
end
```

### Claude Code Instructions

```bash
# 1. Implement format detector
claude "Create lib/whisker/formats/twine/archive/detector.lua with format detection logic. Check tw-storydata format attribute first, then analyze passage content for format-specific patterns. Return format name and confidence score."

# 2. Add content pattern matching
claude "Add content-based format detection to detector.lua. Define patterns for Harlowe ((macro:)), SugarCube (<<macro>>), Chapbook ([modifier]), and Snowman (<% %>). Score each format and return highest confidence match."

# 3. Implement passage extractor
claude "Create lib/whisker/formats/twine/archive/extractor.lua with PassageExtractor class. Normalize passage data into consistent structure with: name, content, tags, pid, links (extracted from content)."

# 4. Add passage graph building
claude "Add passage graph construction to extractor.lua. Build adjacency list from [[link]] patterns. Detect and warn about unreachable passages. Identify start passage from startnode attribute."

# 5. Update archive init
claude "Update lib/whisker/formats/twine/archive/init.lua to export detector and extractor modules"

# 6. Write detector tests
claude "Create tests/unit/formats/twine/archive/detector_spec.lua testing format detection for each format type, missing format attribute fallback, and mixed content handling"

# 7. Write extractor tests
claude "Create tests/unit/formats/twine/archive/extractor_spec.lua testing passage normalization, link extraction, graph construction, and unreachable passage detection"
```

---

## Group B: Common Twine Utilities

---

## Stage 04: Common Link Parser

### Prerequisites
- Stage 01: Module structure and interfaces complete

### Objectives
Implement a shared link parser that handles all Twine link syntax variations (`[[...]]`), which is common across all formats. This parser extracts display text, target passage, and optional setter expressions.

### Inputs
- `lib/whisker/formats/twine/interfaces.lua` (ITwineLinkParser interface)
- Link syntax documentation from all formats

### Tasks
1. Implement `LinkParser` class implementing `ITwineLinkParser`
2. Support all link syntax variations:
   - `[[target]]` — Simple link (display = target)
   - `[[display->target]]` — Arrow syntax
   - `[[display|target]]` — Pipe syntax
   - `[[target][setter]]` — SugarCube setter syntax
   - `[[display->target][$var = value]]` — Combined
3. Handle edge cases:
   - Escaped brackets
   - Nested brackets in display text
   - Unicode in passage names
   - Leading/trailing whitespace
4. Return structured link objects:
   - `display`: Text shown to user
   - `target`: Passage name to navigate to
   - `setter`: Optional expression to evaluate
5. Create `find_all_links(text)` for bulk extraction
6. Write comprehensive tests for all syntax variations

### Outputs
- `lib/whisker/formats/twine/common/links.lua` (new, ~150 lines)
- `lib/whisker/formats/twine/common/init.lua` (new, ~20 lines)
- `tests/unit/formats/twine/common/links_spec.lua` (new, ~200 lines)

### Acceptance Criteria
- [ ] All link syntax variations are correctly parsed
- [ ] `parse("[[display->target]]")` returns `{display="display", target="target"}`
- [ ] Setter expressions are extracted but not evaluated
- [ ] Edge cases (escaping, nesting, unicode) are handled
- [ ] `find_all_links()` extracts all links from passage text
- [ ] Invalid link syntax produces helpful error messages
- [ ] Unit test coverage ≥95%

### Estimated Scope
- **Production code:** 130-160 lines
- **Test code:** 180-220 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes

**Pattern: Link Parsing State Machine**
```lua
function LinkParser:parse(text)
  local state = "start"
  local display, target, setter = "", "", nil
  
  for char in text:gmatch(".") do
    if state == "start" and char == "[" then
      state = "content"
    elseif state == "content" then
      if self:sees_arrow() then
        target = self:consume_until_end()
        state = "done"
      elseif self:sees_pipe() then
        display = self.buffer
        target = self:consume_until_end()
        state = "done"
      else
        display = display .. char
      end
    end
  end
  
  if display == "" then display = target end
  return { display = display, target = target, setter = setter }
end
```

**Supported Link Formats:**
| Format | Example | Display | Target |
|--------|---------|---------|--------|
| Simple | `[[Room]]` | Room | Room |
| Arrow | `[[Go north->NorthRoom]]` | Go north | NorthRoom |
| Pipe | `[[Go north|NorthRoom]]` | Go north | NorthRoom |
| Setter | `[[Continue][$gold += 10]]` | Continue | Continue |

### Claude Code Instructions

```bash
# 1. Create common module init
claude "Create lib/whisker/formats/twine/common/init.lua that will export shared utilities"

# 2. Implement link parser
claude "Create lib/whisker/formats/twine/common/links.lua with LinkParser class. Implement parse() method supporting: simple [[target]], arrow [[display->target]], and pipe [[display|target]] syntax. Return {display, target, setter} table."

# 3. Add setter expression support
claude "Add SugarCube setter syntax support to links.lua: [[link][$var = value]]. Extract setter expression but don't evaluate it."

# 4. Add bulk link extraction
claude "Add find_all_links(text) function to links.lua that finds and parses all [[...]] patterns in a passage's text content"

# 5. Handle edge cases
claude "Add edge case handling to links.lua: escaped brackets \\[\\], nested brackets in display text, unicode passage names, whitespace trimming"

# 6. Write comprehensive tests
claude "Create tests/unit/formats/twine/common/links_spec.lua with tests for every link syntax variation, edge cases, and error handling. Include at least 20 test cases."

# 7. Update common init
claude "Update lib/whisker/formats/twine/common/init.lua to export LinkParser"
```

---

## Stage 05: Base Format Class and Variable Handling

### Prerequisites
- Stage 01: Module structure and interfaces complete
- Stage 04: Common link parser complete

### Objectives
Create an abstract base format class that provides shared functionality for all Twine format implementations. Implement common variable reference handling for `$variable` and `_temporary` syntax.

### Inputs
- `lib/whisker/formats/twine/interfaces.lua` (ITwineFormat interface)
- `lib/whisker/formats/twine/common/links.lua` (from Stage 04)

### Tasks
1. Create `BaseTwineFormat` abstract class:
   - Implement common `can_import()` logic
   - Provide default `import()` skeleton
   - Implement shared event emission
   - Define abstract methods for subclasses
2. Implement `VariableHandler` for variable references:
   - Parse `$name` (story variables)
   - Parse `_name` (temporary variables)
   - Parse `setup.name` (SugarCube setup vars)
   - Track variable usage for analysis
3. Create shared passage preprocessing:
   - Link extraction and normalization
   - Variable reference collection
   - Basic text/code separation
4. Implement variable type inference:
   - String literals
   - Numeric values
   - Boolean values
   - Array/object initialization
5. Add event emission for import stages
6. Write base class tests and variable handler tests

### Outputs
- `lib/whisker/formats/twine/common/base_format.lua` (new, ~180 lines)
- `lib/whisker/formats/twine/common/variables.lua` (new, ~120 lines)
- `tests/unit/formats/twine/common/base_format_spec.lua` (new, ~120 lines)
- `tests/unit/formats/twine/common/variables_spec.lua` (new, ~150 lines)

### Acceptance Criteria
- [ ] `BaseTwineFormat` provides working skeleton for format implementations
- [ ] Subclasses only need to implement format-specific parsing
- [ ] Variable handler correctly identifies `$var`, `_temp`, `setup.var`
- [ ] Variable type inference works for basic types
- [ ] Events are emitted at import stages
- [ ] Base class is truly abstract (errors if instantiated directly)
- [ ] Unit test coverage ≥85%

### Estimated Scope
- **Production code:** 280-320 lines
- **Test code:** 250-300 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes

**Pattern: Abstract Base Class**
```lua
local BaseTwineFormat = {}
BaseTwineFormat.__index = BaseTwineFormat

function BaseTwineFormat:new()
  error("BaseTwineFormat is abstract and cannot be instantiated directly")
end

function BaseTwineFormat:can_import(source)
  -- Common detection logic
  return source:match("<tw%-storydata") ~= nil
end

function BaseTwineFormat:import(source)
  whisker.events:emit("twine:import:start", { source = source })
  
  local archive = TwineArchive.new():parse(source)
  whisker.events:emit("twine:archive:parsed", { 
    passages = #archive:get_passages(),
    format = archive:get_metadata().format
  })
  
  -- Subclass implements parse_passages()
  local story = self:parse_passages(archive)
  
  whisker.events:emit("twine:import:complete", { story = story })
  return story
end

-- Abstract method - must be overridden
function BaseTwineFormat:parse_passages(archive)
  error("parse_passages() must be implemented by subclass")
end
```

**Pattern: Variable Reference Handling**
```lua
local VariableHandler = {}

function VariableHandler:parse_reference(text)
  -- Story variable: $name
  local story_var = text:match("^%$(%w+)")
  if story_var then
    return { type = "story", name = story_var }
  end
  
  -- Temporary variable: _name
  local temp_var = text:match("^_(%w+)")
  if temp_var then
    return { type = "temporary", name = temp_var }
  end
  
  -- SugarCube setup: setup.name
  local setup_var = text:match("^setup%.(%w+)")
  if setup_var then
    return { type = "setup", name = setup_var }
  end
  
  return nil
end
```

### Claude Code Instructions

```bash
# 1. Create variable handler
claude "Create lib/whisker/formats/twine/common/variables.lua with VariableHandler class. Support parsing $name (story), _name (temporary), and setup.name (SugarCube) variable references. Include find_all_variables(text) function."

# 2. Implement base format class
claude "Create lib/whisker/formats/twine/common/base_format.lua with BaseTwineFormat abstract class. Implement can_import(), import() skeleton with event emission, and define abstract parse_passages() method. Error on direct instantiation."

# 3. Add shared preprocessing
claude "Add passage preprocessing to base_format.lua: link extraction using LinkParser, variable reference collection, text/code region identification"

# 4. Add type inference
claude "Add variable type inference to variables.lua. Detect string literals, numbers, booleans, arrays, and objects from assignment expressions."

# 5. Write variable tests
claude "Create tests/unit/formats/twine/common/variables_spec.lua testing variable reference parsing for all types, find_all_variables(), and type inference"

# 6. Write base format tests
claude "Create tests/unit/formats/twine/common/base_format_spec.lua testing can_import(), abstract method enforcement, and event emission"

# 7. Update common init
claude "Update lib/whisker/formats/twine/common/init.lua to export BaseTwineFormat and VariableHandler"
```

---

## Group C: Harlowe Support

---

## Stage 06: Harlowe Lexer Implementation

### Prerequisites
- Stage 01: Module structure complete
- Stage 04: Common link parser complete
- Stage 05: Base format class complete

### Objectives
Implement the Harlowe lexer that tokenizes passage content into a stream of tokens representing macros, hooks, links, and plain text. This lexer handles Harlowe's parentheses-based macro syntax and square-bracket hooks.

### Inputs
- `lib/whisker/formats/twine/common/base_format.lua` (from Stage 05)
- Reference: Phase 3 lexer patterns (`lib/whisker/script/lexer/`)
- Test fixtures: Harlowe passage samples

### Tasks
1. Define Harlowe-specific token types:
   - `MACRO_START` `(`, `MACRO_END` `)`
   - `HOOK_START` `[`, `HOOK_END` `]`
   - `MACRO_NAME` (identifier after open paren)
   - `VARIABLE` (`$name` or `_name`)
   - `KEYWORD` (`to`, `into`, `it`, `its`)
   - `STRING`, `NUMBER`, `BOOLEAN`
   - `OPERATOR` (`+`, `-`, `*`, `/`, `is`, `is not`, `contains`, etc.)
   - `LINK` (complete `[[...]]` sequence)
   - `TEXT` (narrative content)
2. Implement `HarloweLexer.new(source)` constructor
3. Implement `HarloweLexer:tokenize()` returning token stream
4. Handle Harlowe-specific scanning:
   - Macro detection: `(name:` pattern
   - Hook detection: `[` not part of link
   - Link detection: `[[` sequence
   - Variable detection: `$` or `_` prefix
   - The `it` keyword and possessive `its`
5. Implement nested structure tracking
6. Add error handling for unclosed macros/hooks
7. Write comprehensive unit tests

### Outputs
- `lib/whisker/formats/twine/harlowe/lexer.lua` (new, ~180 lines)
- `lib/whisker/formats/twine/harlowe/tokens.lua` (new, ~50 lines)
- `tests/unit/formats/twine/harlowe/lexer_spec.lua` (new, ~220 lines)
- `tests/fixtures/twine/harlowe/lexer/` (new fixture directory)

### Acceptance Criteria
- [ ] `HarloweLexer.new(source):tokenize()` returns token stream
- [ ] All Harlowe token types are correctly recognized
- [ ] Nested macros `(if: (num: 5) > 3)` tokenize correctly
- [ ] Hooks within macros `(if: $x)[text]` tokenize correctly
- [ ] Links `[[display->target]]` are captured as single tokens
- [ ] Variables `$name` and `_temp` are distinguished
- [ ] The `it` keyword is recognized in expressions
- [ ] Lexer errors include position and descriptive message
- [ ] Unit test coverage ≥90%

### Estimated Scope
- **Production code:** 200-250 lines
- **Test code:** 200-250 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes

**Pattern: Macro Detection**
```lua
function HarloweLexer:try_macro()
  if self:peek() ~= '(' then return nil end
  local start_pos = self:position()
  self:advance() -- consume '('
  
  -- Scan macro name
  local name = self:scan_identifier()
  if not name or self:peek() ~= ':' then
    -- Not a macro, might be grouping parens
    self:rewind(start_pos)
    return nil
  end
  self:advance() -- consume ':'
  
  return self:make_token(TokenType.MACRO_START, name)
end
```

**Pattern: Hook vs Link Disambiguation**
```lua
function HarloweLexer:scan_bracket()
  if self:peek() == '[' and self:peek_next() == '[' then
    return self:scan_link()  -- [[...]] link syntax
  else
    return self:make_token(TokenType.HOOK_START)
  end
end
```

**Harlowe Operators (must recognize as tokens):**
- `is`, `is not`, `contains`, `is in`
- `and`, `or`, `not`
- `to`, `into`
- `+`, `-`, `*`, `/`, `<`, `>`, `<=`, `>=`

### Claude Code Instructions

```bash
# 1. Create token type definitions
claude "Create lib/whisker/formats/twine/harlowe/tokens.lua defining TokenType enum for Harlowe: MACRO_START, MACRO_END, HOOK_START, HOOK_END, MACRO_NAME, VARIABLE, KEYWORD, STRING, NUMBER, BOOLEAN, OPERATOR, LINK, TEXT, EOF, ERROR"

# 2. Create test fixtures
claude "Create tests/fixtures/twine/harlowe/lexer/ directory with sample passages: plain_text.txt, simple_macro.txt, nested_macros.txt, hooks.txt, variables.txt, operators.txt, complex.txt"

# 3. Implement lexer core
claude "Create lib/whisker/formats/twine/harlowe/lexer.lua with HarloweLexer class. Implement new(source), peek(), advance(), position(), tokenize() methods. Follow Phase 3 lexer patterns."

# 4. Add macro/hook scanning
claude "Add macro scanning to lexer.lua: detect (name: pattern, handle nested parentheses. Add hook scanning: detect [ not followed by [, track nesting depth."

# 5. Add operator recognition
claude "Add Harlowe operator recognition to lexer.lua: is, is not, contains, is in, and, or, not, to, into, plus arithmetic and comparison operators"

# 6. Add link scanning
claude "Add link token scanning to lexer.lua: detect [[ and scan complete link including arrow/pipe syntax, return as single LINK token"

# 7. Write lexer tests
claude "Create tests/unit/formats/twine/harlowe/lexer_spec.lua testing all token types, nested structures, error cases. Use fixtures from tests/fixtures/twine/harlowe/lexer/"

# 8. Update harlowe init
claude "Create lib/whisker/formats/twine/harlowe/init.lua exporting lexer and tokens modules"
```

---

## Stage 07: Harlowe Parser and AST

### Prerequisites
- Stage 06: Harlowe lexer complete

### Objectives
Implement the Harlowe parser that builds an Abstract Syntax Tree from the token stream. The AST represents the complete structure of Harlowe passage content including macros, hooks, text, and their relationships.

### Inputs
- `lib/whisker/formats/twine/harlowe/lexer.lua` (from Stage 06)
- `lib/whisker/formats/twine/harlowe/tokens.lua` (from Stage 06)

### Tasks
1. Define AST node types:
   - `TextNode` — Plain narrative text
   - `MacroNode` — Macro invocation with args and optional hook
   - `HookNode` — Content block (may be named)
   - `LinkNode` — Navigation link
   - `VariableNode` — Variable reference
   - `ExpressionNode` — Evaluated expression
   - `PassageNode` — Root node for passage content
2. Implement `HarloweParser.new(tokens)` constructor
3. Implement `parse()` returning PassageNode AST
4. Handle macro argument parsing:
   - Named hooks: `(if: $x)[content]`
   - Inline expressions: `(set: $x to 5)`
   - Chained macros: `(if: $x)(else:)[alt]`
5. Handle hook relationships:
   - Changers applied to hooks
   - Named hooks with `?name` syntax
6. Track source positions for error reporting
7. Write parser tests with complex structures

### Outputs
- `lib/whisker/formats/twine/harlowe/ast.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/harlowe/parser.lua` (new, ~220 lines)
- `tests/unit/formats/twine/harlowe/parser_spec.lua` (new, ~250 lines)
- `tests/fixtures/twine/harlowe/parser/` (new fixture directory)

### Acceptance Criteria
- [ ] All AST node types are defined with proper structure
- [ ] Parser correctly builds AST from token stream
- [ ] Macro arguments are properly parsed
- [ ] Hook attachments are correctly associated with macros
- [ ] Chained macros produce correct AST structure
- [ ] Named hooks (`?name`) are tracked
- [ ] Source positions are preserved in all nodes
- [ ] Error messages include line/column information
- [ ] Unit test coverage ≥90%

### Estimated Scope
- **Production code:** 300-350 lines
- **Test code:** 230-280 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes

**Pattern: AST Node Structure**
```lua
-- lib/whisker/formats/twine/harlowe/ast.lua
local AST = {}

AST.TextNode = {
  new = function(text, pos)
    return {
      type = "text",
      value = text,
      position = pos
    }
  end
}

AST.MacroNode = {
  new = function(name, args, hook, pos)
    return {
      type = "macro",
      name = name,
      arguments = args,
      hook = hook,  -- Optional attached hook
      position = pos
    }
  end
}

AST.HookNode = {
  new = function(content, name, pos)
    return {
      type = "hook",
      name = name,  -- Optional ?name
      content = content,  -- Array of child nodes
      position = pos
    }
  end
}
```

**Pattern: Recursive Descent Parsing**
```lua
function HarloweParser:parse_content()
  local nodes = {}
  
  while not self:at_end() do
    local node = self:parse_element()
    if node then
      table.insert(nodes, node)
    end
  end
  
  return AST.PassageNode.new(nodes)
end

function HarloweParser:parse_element()
  if self:check(TokenType.MACRO_START) then
    return self:parse_macro()
  elseif self:check(TokenType.HOOK_START) then
    return self:parse_hook()
  elseif self:check(TokenType.LINK) then
    return self:parse_link()
  elseif self:check(TokenType.TEXT) then
    return self:parse_text()
  end
end
```

### Claude Code Instructions

```bash
# 1. Define AST node types
claude "Create lib/whisker/formats/twine/harlowe/ast.lua defining AST node constructors: TextNode, MacroNode, HookNode, LinkNode, VariableNode, ExpressionNode, PassageNode. Each should store type, relevant data, and position."

# 2. Create parser fixtures
claude "Create tests/fixtures/twine/harlowe/parser/ with complex Harlowe samples: conditionals.txt, nested_macros.txt, chained_changers.txt, named_hooks.txt"

# 3. Implement parser core
claude "Create lib/whisker/formats/twine/harlowe/parser.lua with HarloweParser class. Implement recursive descent parser with parse(), parse_element(), parse_macro(), parse_hook(), parse_link()"

# 4. Add macro argument parsing
claude "Add macro argument parsing to parser.lua. Handle expressions like (set: $x to 5), (if: $x > 3), (a: 1, 2, 3). Track commas as argument separators."

# 5. Add hook association
claude "Add hook association logic to parser.lua. When a macro is followed by [hook], attach the hook to the macro. Handle chained macros like (if:)(else:)"

# 6. Add named hook support
claude "Add named hook support to parser.lua. Parse ?hookname syntax for hook references. Track named hooks for later use by macros like (append:)"

# 7. Write parser tests
claude "Create tests/unit/formats/twine/harlowe/parser_spec.lua testing AST construction for all node types, nested structures, chained macros, error cases"

# 8. Update harlowe init
claude "Update lib/whisker/formats/twine/harlowe/init.lua to export ast and parser modules"
```

---

## Stage 08: Harlowe Macro Registry and Core Macros

### Prerequisites
- Stage 07: Harlowe parser and AST complete

### Objectives
Implement the Harlowe macro registry system and the core (Priority 1) macros: `set`, `put`, `if`, `unless`, `else-if`, `else`, `link`, `link-goto`, `goto`, `print`, `a`, `dm`, `ds`.

### Inputs
- `lib/whisker/formats/twine/harlowe/ast.lua` (from Stage 07)
- `lib/whisker/formats/twine/interfaces.lua` (ITwineMacro, IMacroRegistry)
- Harlowe macro documentation

### Tasks
1. Implement `HarloweMacroRegistry` class:
   - `register(macro)` — Register macro handler
   - `get(name)` — Retrieve handler by name
   - `has(name)` — Check existence
   - `list()` — List all registered macros
2. Create base macro class with shared functionality
3. Implement core macros:
   - **Variables:** `set`, `put`
   - **Control:** `if`, `unless`, `else-if`, `else`
   - **Links:** `link`, `link-goto`, `goto`
   - **Output:** `print`
   - **Data:** `a` (array), `dm` (datamap), `ds` (dataset)
4. Each macro implements `ITwineMacro`:
   - `parse(args, body, ctx)` — Parse arguments
   - `convert(node, ctx)` — Convert to Whisker IR
5. Add macro category tracking for documentation
6. Write tests for each macro

### Outputs
- `lib/whisker/formats/twine/harlowe/macros/init.lua` (new, ~80 lines)
- `lib/whisker/formats/twine/harlowe/macros/registry.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/harlowe/macros/variables.lua` (new, ~120 lines)
- `lib/whisker/formats/twine/harlowe/macros/control.lua` (new, ~150 lines)
- `lib/whisker/formats/twine/harlowe/macros/links.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/harlowe/macros/data.lua` (new, ~120 lines)
- `tests/unit/formats/twine/harlowe/macros/` (new test directory, ~400 lines total)

### Acceptance Criteria
- [ ] Macro registry correctly registers and retrieves macros
- [ ] All Priority 1 macros are implemented
- [ ] `(set: $x to 5)` correctly assigns variables
- [ ] `(if: cond)[hook]` correctly handles conditionals
- [ ] `(link-goto: "text", "passage")` creates navigation
- [ ] `(a: 1, 2, 3)` creates arrays
- [ ] Macros emit appropriate warnings for unsupported features
- [ ] Each macro has corresponding unit tests
- [ ] Macro registry is extensible for future macros

### Estimated Scope
- **Production code:** 650-750 lines
- **Test code:** 400-500 lines
- **Estimated time:** 2.5-3 days

### Implementation Notes

**Pattern: Macro Implementation**
```lua
-- lib/whisker/formats/twine/harlowe/macros/variables.lua
local SetMacro = {}
SetMacro.__index = SetMacro

SetMacro.name = "set"
SetMacro.aliases = {}
SetMacro.format = "harlowe"
SetMacro.category = "variables"

function SetMacro:has_body()
  return false
end

function SetMacro:parse(args, body, ctx)
  -- Parse: $variable to value
  local var = args[1]
  local value = args[3]  -- Skip 'to'
  
  if not var or var.type ~= "variable" then
    ctx:error("set: requires variable as first argument")
  end
  
  return {
    variable = var.name,
    value = value
  }
end

function SetMacro:convert(node, ctx)
  return ctx:create_assignment(node.variable, node.value)
end
```

**Pattern: Registry Population**
```lua
-- lib/whisker/formats/twine/harlowe/macros/init.lua
local registry = HarloweMacroRegistry.new()

-- Register all core macros
registry:register(require("...variables").SetMacro)
registry:register(require("...variables").PutMacro)
registry:register(require("...control").IfMacro)
-- ... etc

return registry
```

### Claude Code Instructions

```bash
# 1. Create macro registry
claude "Create lib/whisker/formats/twine/harlowe/macros/registry.lua implementing HarloweMacroRegistry class with register(), get(), has(), list(), list_by_category() methods"

# 2. Implement variable macros
claude "Create lib/whisker/formats/twine/harlowe/macros/variables.lua with SetMacro and PutMacro implementations. Handle 'to' and 'into' syntax variations."

# 3. Implement control macros
claude "Create lib/whisker/formats/twine/harlowe/macros/control.lua with IfMacro, UnlessMacro, ElseIfMacro, ElseMacro. Handle hook attachment and chaining."

# 4. Implement link macros
claude "Create lib/whisker/formats/twine/harlowe/macros/links.lua with LinkMacro, LinkGotoMacro, GotoMacro. Handle display text and passage targets."

# 5. Implement data macros
claude "Create lib/whisker/formats/twine/harlowe/macros/data.lua with ArrayMacro (a:), DatamapMacro (dm:), DatasetMacro (ds:). Handle element creation."

# 6. Create output macro (print)
claude "Add PrintMacro to an appropriate file (or create text.lua). Handle value conversion to string output."

# 7. Create macros init
claude "Create lib/whisker/formats/twine/harlowe/macros/init.lua that creates registry, registers all macros, and exports the populated registry"

# 8. Write macro tests
claude "Create tests/unit/formats/twine/harlowe/macros/ directory with registry_spec.lua, variables_spec.lua, control_spec.lua, links_spec.lua, data_spec.lua testing each macro's parse and convert methods"
```

---

## Stage 09: Harlowe Control Flow and Data Macros

### Prerequisites
- Stage 08: Harlowe macro registry and core macros complete

### Objectives
Implement the Priority 2 (common) macros for Harlowe: additional control flow macros (`for`, `cond`), link variants (`link-reveal`, `link-repeat`), utility macros (`either`, `nth`, `count`, `range`), state macros (`history`, `passage`), and type conversion macros (`num`, `str`, `lowercase`, `uppercase`).

### Inputs
- `lib/whisker/formats/twine/harlowe/macros/` (from Stage 08)
- Harlowe documentation for Priority 2 macros

### Tasks
1. Implement control flow extensions:
   - `for` — Loop over arrays: `(for: each _item, $array)[hook]`
   - `cond` — Conditional value: `(cond: test, val, test2, val2)`
2. Implement link variants:
   - `link-reveal` — Show content on click
   - `link-repeat` — Repeatable click action
3. Implement utility macros:
   - `either` — Random selection from values
   - `nth` — Get nth item from values
   - `count` — Count occurrences in array
   - `range` — Generate number range
4. Implement state macros:
   - `history` — Get visited passage list
   - `passage` — Get passage metadata
5. Implement type conversion:
   - `num` — Convert to number
   - `str` — Convert to string
   - `lowercase`, `uppercase` — Text case conversion
6. Add these to the macro registry
7. Write comprehensive tests

### Outputs
- `lib/whisker/formats/twine/harlowe/macros/control.lua` (modified, +80 lines)
- `lib/whisker/formats/twine/harlowe/macros/links.lua` (modified, +60 lines)
- `lib/whisker/formats/twine/harlowe/macros/utility.lua` (new, ~120 lines)
- `lib/whisker/formats/twine/harlowe/macros/state.lua` (new, ~80 lines)
- `lib/whisker/formats/twine/harlowe/macros/text.lua` (new, ~80 lines)
- `tests/unit/formats/twine/harlowe/macros/` (additional tests, ~300 lines)

### Acceptance Criteria
- [ ] All Priority 2 macros are implemented
- [ ] `(for: each _item, $array)[hook]` iterates correctly
- [ ] `(either: "a", "b", "c")` returns random selection
- [ ] `(range: 1, 10)` creates array [1,2,...,10]
- [ ] `(history:)` returns visited passage list
- [ ] Type conversion macros work correctly
- [ ] All new macros registered in registry
- [ ] Each macro has unit tests
- [ ] Integration tests verify macro interaction

### Estimated Scope
- **Production code:** 400-450 lines
- **Test code:** 300-350 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes

**Pattern: For Loop Macro**
```lua
local ForMacro = {}
ForMacro.name = "for"

function ForMacro:parse(args, body, ctx)
  -- Parse: each _varname, $array
  -- or: _varname range start, end
  local iterator_type = args[1].value  -- "each" or var name
  
  if iterator_type == "each" then
    return {
      type = "each",
      variable = args[2].name,
      array = args[4]  -- Skip comma
    }
  else
    -- range iteration
    return {
      type = "range",
      variable = args[1].name,
      start = args[3],
      stop = args[5]
    }
  end
end

function ForMacro:convert(node, ctx)
  return ctx:create_for_loop(node)
end
```

**Pattern: Random Selection**
```lua
local EitherMacro = {}
EitherMacro.name = "either"

function EitherMacro:convert(node, ctx)
  -- Convert to random selection expression
  return ctx:create_function_call("random_choice", node.arguments)
end
```

### Claude Code Instructions

```bash
# 1. Add for loop macro
claude "Add ForMacro to lib/whisker/formats/twine/harlowe/macros/control.lua. Handle 'each _var, array' and 'range start, end' syntax. Convert to Whisker for loop."

# 2. Add cond macro
claude "Add CondMacro to control.lua. Handle (cond: test, val, test2, val2, ...) conditional value syntax."

# 3. Add link variants
claude "Add LinkRevealMacro and LinkRepeatMacro to lib/whisker/formats/twine/harlowe/macros/links.lua. Handle reveal-on-click and repeatable click patterns."

# 4. Create utility macros
claude "Create lib/whisker/formats/twine/harlowe/macros/utility.lua with EitherMacro (random), NthMacro (index), CountMacro (occurrences), RangeMacro (number range)"

# 5. Create state macros
claude "Create lib/whisker/formats/twine/harlowe/macros/state.lua with HistoryMacro (visited passages) and PassageMacro (passage metadata)"

# 6. Create text macros
claude "Create lib/whisker/formats/twine/harlowe/macros/text.lua with NumMacro, StrMacro, LowercaseMacro, UppercaseMacro for type conversion"

# 7. Register new macros
claude "Update lib/whisker/formats/twine/harlowe/macros/init.lua to import and register all new macros from utility.lua, state.lua, and text.lua"

# 8. Write tests
claude "Add tests for all new macros in tests/unit/formats/twine/harlowe/macros/. Create utility_spec.lua, state_spec.lua, text_spec.lua"
```

---

## Stage 10: Harlowe to Whisker Converter

### Prerequisites
- Stage 07: Harlowe parser complete
- Stage 08-09: Harlowe macros complete

### Objectives
Implement the complete Harlowe-to-Whisker converter that transforms Harlowe ASTs into Whisker story format. This converter uses the macro registry to handle each macro type and produces valid Whisker stories.

### Inputs
- `lib/whisker/formats/twine/harlowe/parser.lua` (from Stage 07)
- `lib/whisker/formats/twine/harlowe/macros/` (from Stages 08-09)
- `lib/whisker/formats/twine/archive/` (from Stages 02-03)

### Tasks
1. Create `HarloweConverter` class:
   - Accept parsed archive and AST
   - Traverse AST nodes
   - Build Whisker story structure
2. Implement node conversion methods:
   - `convert_passage(ast)` → Whisker Passage
   - `convert_macro(node)` → Appropriate Whisker construct
   - `convert_hook(node)` → Inline content or separate passage
   - `convert_link(node)` → Whisker Choice
   - `convert_text(node)` → Narrative content
3. Handle conversion context:
   - Track current passage
   - Manage variable scopes
   - Accumulate warnings for unsupported features
4. Implement Harlowe IFormat entry points:
   - `import(source)` — Full conversion pipeline
   - `parse_passage(content)` — Single passage parsing
5. Handle edge cases:
   - Passages with only macros (no text)
   - Circular passage references
   - Unsupported macro fallback
6. Generate conversion warnings/errors
7. Write integration tests with real Harlowe stories

### Outputs
- `lib/whisker/formats/twine/harlowe/converter.lua` (new, ~250 lines)
- `lib/whisker/formats/twine/harlowe/format.lua` (new, ~120 lines)
- `lib/whisker/formats/twine/harlowe/init.lua` (modified)
- `tests/unit/formats/twine/harlowe/converter_spec.lua` (new, ~200 lines)
- `tests/integration/formats/twine/harlowe/` (new, ~150 lines)

### Acceptance Criteria
- [ ] Complete Harlowe stories convert to valid Whisker stories
- [ ] All implemented macros convert correctly
- [ ] Unsupported macros generate warnings (not errors)
- [ ] Passage structure is preserved
- [ ] Variables are correctly mapped
- [ ] Links become Whisker choices
- [ ] Conditionals convert to Whisker conditional syntax
- [ ] Round-trip metadata (CSS, JS) is preserved
- [ ] Integration tests pass with real Harlowe stories

### Estimated Scope
- **Production code:** 350-400 lines
- **Test code:** 350-400 lines
- **Estimated time:** 2.5-3 days

### Implementation Notes

**Pattern: Converter Structure**
```lua
local HarloweConverter = {}
HarloweConverter.__index = HarloweConverter

function HarloweConverter.new(archive, registry)
  return setmetatable({
    archive = archive,
    registry = registry,
    story = nil,
    current_passage = nil,
    warnings = {}
  }, HarloweConverter)
end

function HarloweConverter:convert()
  self.story = Story.new()
  self.story.metadata = self:convert_metadata()
  
  for _, passage_data in ipairs(self.archive:get_passages()) do
    local ast = self:parse_passage(passage_data.content)
    local passage = self:convert_passage(passage_data.name, ast)
    self.story:add_passage(passage)
  end
  
  return self.story, self.warnings
end

function HarloweConverter:convert_node(node)
  if node.type == "macro" then
    local handler = self.registry:get(node.name)
    if handler then
      return handler:convert(node, self)
    else
      self:warn("Unsupported macro: " .. node.name)
      return nil
    end
  elseif node.type == "text" then
    return node.value
  -- ... etc
  end
end
```

**Pattern: Warning Accumulation**
```lua
function HarloweConverter:warn(message, node)
  table.insert(self.warnings, {
    message = message,
    position = node and node.position,
    passage = self.current_passage
  })
end
```

### Claude Code Instructions

```bash
# 1. Create converter core
claude "Create lib/whisker/formats/twine/harlowe/converter.lua with HarloweConverter class. Implement convert() that iterates passages, parses each, and builds Whisker story structure."

# 2. Add node conversion
claude "Add convert_node() method to converter.lua that dispatches to convert_macro(), convert_text(), convert_link(), convert_hook() based on node type"

# 3. Add macro conversion
claude "Add convert_macro() that uses the macro registry to look up handlers and call their convert() methods. Accumulate warnings for unknown macros."

# 4. Add context management
claude "Add conversion context to converter.lua: track current passage, variable scopes, emit events at conversion stages"

# 5. Create IFormat implementation
claude "Create lib/whisker/formats/twine/harlowe/format.lua with HarloweFormat class implementing ITwineFormat. Wire up import() to use archive parser and converter."

# 6. Update harlowe init
claude "Update lib/whisker/formats/twine/harlowe/init.lua to export format module and register with container as 'format.twine.harlowe'"

# 7. Write converter tests
claude "Create tests/unit/formats/twine/harlowe/converter_spec.lua testing conversion of all node types, warning generation, edge cases"

# 8. Write integration tests
claude "Create tests/integration/formats/twine/harlowe/ with real Harlowe story files. Test full import pipeline produces valid Whisker stories."
```

---

## Group D: SugarCube Support

---

## Stage 11: SugarCube Lexer Implementation

### Prerequisites
- Stage 05: Base format class complete
- Stage 06: Harlowe lexer (for patterns)

### Objectives
Implement the SugarCube lexer that tokenizes passage content into a stream of tokens. SugarCube uses wiki-style `<<macro>>` syntax with block macros using `<</macro>>` closing tags.

### Inputs
- `lib/whisker/formats/twine/harlowe/lexer.lua` (pattern reference)
- SugarCube documentation

### Tasks
1. Define SugarCube-specific token types:
   - `MACRO_OPEN` `<<`, `MACRO_CLOSE` `>>`
   - `MACRO_END` `<</name>>`
   - `MACRO_NAME`
   - `VARIABLE` (`$name`, `_name`, `setup.name`)
   - `EXPRESSION` (JavaScript-like expressions)
   - `STRING`, `NUMBER`, `BOOLEAN`
   - `LINK` (complete `[[...]]` sequence)
   - `HTML_TAG` (embedded HTML)
   - `TEXT`
2. Implement `SugarCubeLexer.new(source)` constructor
3. Implement `tokenize()` returning token stream
4. Handle SugarCube-specific scanning:
   - Block macro detection: `<<name>>...<</name>>`
   - Self-closing macros: `<<set $x to 5>>`
   - Bare output: `<<print $var>>`
   - JavaScript expressions within macros
5. Handle embedded HTML within passages
6. Write comprehensive tests

### Outputs
- `lib/whisker/formats/twine/sugarcube/lexer.lua` (new, ~200 lines)
- `lib/whisker/formats/twine/sugarcube/tokens.lua` (new, ~50 lines)
- `tests/unit/formats/twine/sugarcube/lexer_spec.lua` (new, ~220 lines)
- `tests/fixtures/twine/sugarcube/lexer/` (new fixture directory)

### Acceptance Criteria
- [ ] `SugarCubeLexer:tokenize()` returns valid token stream
- [ ] Block macros `<<if>>...<</if>>` are correctly paired
- [ ] Self-closing macros are recognized
- [ ] JavaScript expressions in macros are captured
- [ ] Variables `$x`, `_x`, `setup.x` are distinguished
- [ ] Embedded HTML is preserved
- [ ] Links `[[...]]` are correctly tokenized
- [ ] Unit test coverage ≥90%

### Estimated Scope
- **Production code:** 200-250 lines
- **Test code:** 200-250 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes

**Pattern: Block Macro Detection**
```lua
function SugarCubeLexer:scan_macro()
  if not self:match("<<") then return nil end
  
  -- Check for closing tag
  if self:peek() == "/" then
    self:advance()
    local name = self:scan_identifier()
    self:expect(">>")
    return self:make_token(TokenType.MACRO_END, name)
  end
  
  local name = self:scan_identifier()
  local args = self:scan_until(">>")
  
  return self:make_token(TokenType.MACRO_OPEN, {
    name = name,
    args = args
  })
end
```

### Claude Code Instructions

```bash
# 1. Create token types
claude "Create lib/whisker/formats/twine/sugarcube/tokens.lua defining SugarCube token types: MACRO_OPEN, MACRO_CLOSE, MACRO_END, MACRO_NAME, VARIABLE, EXPRESSION, STRING, NUMBER, BOOLEAN, LINK, HTML_TAG, TEXT, EOF"

# 2. Create test fixtures
claude "Create tests/fixtures/twine/sugarcube/lexer/ with samples: simple_macro.txt, block_macro.txt, nested.txt, variables.txt, html_mixed.txt"

# 3. Implement lexer
claude "Create lib/whisker/formats/twine/sugarcube/lexer.lua with SugarCubeLexer class. Implement << >> macro scanning with block detection via <</name>>"

# 4. Add expression scanning
claude "Add JavaScript expression scanning to sugarcube lexer. Handle expressions inside macros like <<set $x to $y + 5>>"

# 5. Add HTML handling
claude "Add HTML tag preservation to sugarcube lexer. Tokenize <tag>...</tag> as HTML_TAG tokens"

# 6. Write tests
claude "Create tests/unit/formats/twine/sugarcube/lexer_spec.lua testing all token types, block matching, nested structures"

# 7. Create sugarcube init
claude "Create lib/whisker/formats/twine/sugarcube/init.lua exporting lexer and tokens"
```

---

## Stage 12: SugarCube Parser and AST

### Prerequisites
- Stage 11: SugarCube lexer complete

### Objectives
Implement the SugarCube parser that builds an AST from the token stream. Handle block macro nesting, widget definitions, and JavaScript integration.

### Inputs
- `lib/whisker/formats/twine/sugarcube/lexer.lua` (from Stage 11)
- `lib/whisker/formats/twine/harlowe/parser.lua` (pattern reference)

### Tasks
1. Define SugarCube AST node types:
   - `MacroNode` — Macro invocation (may have body)
   - `BlockNode` — Block macro with content
   - `TextNode` — Plain text
   - `LinkNode` — Navigation link
   - `VariableNode` — Variable reference
   - `HtmlNode` — Embedded HTML
   - `WidgetNode` — Widget definition
   - `ScriptNode` — JavaScript block
2. Implement `SugarCubeParser.new(tokens)` constructor
3. Implement `parse()` returning PassageNode
4. Handle block macro matching:
   - Track open macros
   - Match `<<name>>` with `<</name>>`
   - Validate nesting
5. Handle special constructs:
   - Widget definitions (`<<widget "name">>`)
   - JavaScript blocks (`<<script>>`)
   - Inline JavaScript (`<<run>>`)
6. Write parser tests

### Outputs
- `lib/whisker/formats/twine/sugarcube/ast.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/sugarcube/parser.lua` (new, ~250 lines)
- `tests/unit/formats/twine/sugarcube/parser_spec.lua` (new, ~250 lines)

### Acceptance Criteria
- [ ] Parser correctly handles block macro nesting
- [ ] Widget definitions are captured as WidgetNode
- [ ] Script blocks preserve JavaScript content
- [ ] HTML nodes preserve structure
- [ ] Error messages identify unclosed blocks
- [ ] Source positions are tracked
- [ ] Unit test coverage ≥90%

### Estimated Scope
- **Production code:** 330-380 lines
- **Test code:** 230-280 lines
- **Estimated time:** 2-2.5 days

### Claude Code Instructions

```bash
# 1. Define AST nodes
claude "Create lib/whisker/formats/twine/sugarcube/ast.lua with MacroNode, BlockNode, TextNode, LinkNode, VariableNode, HtmlNode, WidgetNode, ScriptNode constructors"

# 2. Implement parser
claude "Create lib/whisker/formats/twine/sugarcube/parser.lua with recursive descent parser. Handle <<macro>>content<</macro>> block structure."

# 3. Add block matching
claude "Add block macro matching to parser. Track open blocks on a stack, match closing tags, report unclosed blocks as errors"

# 4. Add widget/script handling
claude "Add special handling for <<widget>> and <<script>> blocks in parser. Preserve their content as-is."

# 5. Write tests
claude "Create tests/unit/formats/twine/sugarcube/parser_spec.lua testing block nesting, widget parsing, script blocks, error cases"

# 6. Update sugarcube init
claude "Update lib/whisker/formats/twine/sugarcube/init.lua to export ast and parser"
```

---

## Stage 13: SugarCube Macro Registry and Macros

### Prerequisites
- Stage 12: SugarCube parser complete

### Objectives
Implement the SugarCube macro registry and Priority 1+2 macros: `set`, `unset`, `if`, `elseif`, `else`, `for`, `link`, `goto`, `print`, `include`, `run`, `script`, plus link variants and control flow extensions.

### Inputs
- `lib/whisker/formats/twine/sugarcube/parser.lua` (from Stage 12)
- `lib/whisker/formats/twine/harlowe/macros/` (pattern reference)
- SugarCube documentation

### Tasks
1. Create `SugarCubeMacroRegistry` (similar to Harlowe)
2. Implement core macros:
   - **Variables:** `set`, `unset`, `run`
   - **Control:** `if`, `elseif`, `else`, `for`, `switch`, `case`, `default`
   - **Links:** `link`, `goto`, `return`, `back`
   - **Output:** `print`, `include`
   - **JavaScript:** `run`, `script`
3. Implement common macros:
   - **Link variants:** `linkreplace`, `linkappend`, `linkprepend`
   - **Scope:** `capture`, `silently`
   - **Widgets:** `widget`
4. Implement ITwineMacro for each
5. Register all macros
6. Write macro tests

### Outputs
- `lib/whisker/formats/twine/sugarcube/macros/init.lua` (new, ~80 lines)
- `lib/whisker/formats/twine/sugarcube/macros/registry.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/sugarcube/macros/variables.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/sugarcube/macros/control.lua` (new, ~180 lines)
- `lib/whisker/formats/twine/sugarcube/macros/links.lua` (new, ~140 lines)
- `lib/whisker/formats/twine/sugarcube/macros/widgets.lua` (new, ~100 lines)
- `tests/unit/formats/twine/sugarcube/macros/` (new, ~400 lines)

### Acceptance Criteria
- [ ] All Priority 1+2 SugarCube macros implemented
- [ ] `<<set $x to 5>>` assigns variables
- [ ] `<<if cond>>...<</if>>` handles conditionals
- [ ] `<<for>>` loops work correctly
- [ ] `<<widget>>` definitions are captured
- [ ] JavaScript in `<<run>>` is preserved
- [ ] All macros have unit tests

### Estimated Scope
- **Production code:** 700-800 lines
- **Test code:** 400-500 lines
- **Estimated time:** 2.5-3 days

### Claude Code Instructions

```bash
# 1. Create registry
claude "Create lib/whisker/formats/twine/sugarcube/macros/registry.lua implementing SugarCubeMacroRegistry"

# 2. Implement variable macros
claude "Create lib/whisker/formats/twine/sugarcube/macros/variables.lua with SetMacro, UnsetMacro, RunMacro"

# 3. Implement control macros
claude "Create lib/whisker/formats/twine/sugarcube/macros/control.lua with IfMacro, ElseifMacro, ElseMacro, ForMacro, SwitchMacro, CaseMacro, DefaultMacro"

# 4. Implement link macros
claude "Create lib/whisker/formats/twine/sugarcube/macros/links.lua with LinkMacro, GotoMacro, ReturnMacro, BackMacro, LinkreplaceMacro, LinkappendMacro, LinkprependMacro"

# 5. Implement widget macros
claude "Create lib/whisker/formats/twine/sugarcube/macros/widgets.lua with WidgetMacro, CaptureMacro, SilentlyMacro"

# 6. Create macros init
claude "Create lib/whisker/formats/twine/sugarcube/macros/init.lua registering all macros"

# 7. Write tests
claude "Create tests for all macros in tests/unit/formats/twine/sugarcube/macros/"
```

---

## Stage 14: SugarCube to Whisker Converter

### Prerequisites
- Stage 12: SugarCube parser complete
- Stage 13: SugarCube macros complete

### Objectives
Implement the complete SugarCube-to-Whisker converter, following the same pattern as the Harlowe converter. Handle SugarCube-specific features like widgets and JavaScript blocks.

### Inputs
- `lib/whisker/formats/twine/sugarcube/parser.lua`
- `lib/whisker/formats/twine/sugarcube/macros/`
- `lib/whisker/formats/twine/harlowe/converter.lua` (pattern)

### Tasks
1. Create `SugarCubeConverter` class
2. Implement conversion methods for all node types
3. Handle SugarCube-specific conversions:
   - Widgets → Whisker functions/includes
   - JavaScript blocks → Metadata preservation
   - Special passages (StoryInit, etc.)
4. Implement `SugarCubeFormat` (ITwineFormat)
5. Handle special SugarCube variables
6. Write integration tests

### Outputs
- `lib/whisker/formats/twine/sugarcube/converter.lua` (new, ~280 lines)
- `lib/whisker/formats/twine/sugarcube/format.lua` (new, ~120 lines)
- `tests/unit/formats/twine/sugarcube/converter_spec.lua` (new, ~200 lines)
- `tests/integration/formats/twine/sugarcube/` (new, ~150 lines)

### Acceptance Criteria
- [ ] Complete SugarCube stories convert to valid Whisker stories
- [ ] Widgets are converted appropriately
- [ ] JavaScript is preserved as metadata
- [ ] Special passages are handled
- [ ] Integration tests pass with real SugarCube stories

### Estimated Scope
- **Production code:** 380-430 lines
- **Test code:** 330-380 lines
- **Estimated time:** 2.5-3 days

### Claude Code Instructions

```bash
# 1. Create converter
claude "Create lib/whisker/formats/twine/sugarcube/converter.lua following HarloweConverter pattern. Handle SugarCube AST nodes."

# 2. Add widget conversion
claude "Add widget conversion to SugarCubeConverter. Convert <<widget>> definitions to Whisker function-like structures or preserve as metadata"

# 3. Handle special passages
claude "Add special passage handling: StoryInit runs at start, PassageHeader/Footer prepend/append to all passages"

# 4. Create format implementation
claude "Create lib/whisker/formats/twine/sugarcube/format.lua implementing ITwineFormat. Register as 'format.twine.sugarcube'"

# 5. Write tests
claude "Create tests for converter and integration tests with real SugarCube stories"

# 6. Update sugarcube init
claude "Update lib/whisker/formats/twine/sugarcube/init.lua to export format module"
```

---

## Group E: Chapbook & Snowman Support

---

## Stage 15: Chapbook Parser and Converter

### Prerequisites
- Stage 05: Base format class complete
- Stage 10: Converter patterns from Harlowe

### Objectives
Implement Chapbook format support. Chapbook uses a simpler modifier-based syntax with a vars section separated by `--`. This is a lighter-weight implementation focusing on core features.

### Inputs
- `lib/whisker/formats/twine/common/base_format.lua`
- Chapbook documentation

### Tasks
1. Implement `ChapbookParser`:
   - Parse vars section (above `--`)
   - Parse modifiers (`[if condition]`, `[after time]`)
   - Parse inserts (`{variable}`, `{expression}`)
   - Parse forks (`> [[link]]`)
2. Implement core modifiers:
   - `[if condition]`, `[unless condition]`, `[else]`
   - `[cont'd]`, `[append]`
   - `[note]` (editor-only)
3. Implement core inserts:
   - `{variable}`, `{expression}`
   - `{embed passage: 'name'}`
   - `{reveal link: 'text', passage: 'name'}`
4. Create `ChapbookConverter`
5. Implement `ChapbookFormat`
6. Write tests

### Outputs
- `lib/whisker/formats/twine/chapbook/parser.lua` (new, ~180 lines)
- `lib/whisker/formats/twine/chapbook/modifiers.lua` (new, ~120 lines)
- `lib/whisker/formats/twine/chapbook/converter.lua` (new, ~150 lines)
- `lib/whisker/formats/twine/chapbook/init.lua` (new, ~60 lines)
- `tests/unit/formats/twine/chapbook/` (new, ~250 lines)

### Acceptance Criteria
- [ ] Chapbook stories parse correctly
- [ ] Vars section is extracted and converted
- [ ] Core modifiers work (`[if]`, `[else]`)
- [ ] Inserts are converted to expressions
- [ ] Forks become choices
- [ ] Integration tests pass

### Estimated Scope
- **Production code:** 500-550 lines
- **Test code:** 250-300 lines
- **Estimated time:** 2-2.5 days

### Claude Code Instructions

```bash
# 1. Create parser
claude "Create lib/whisker/formats/twine/chapbook/parser.lua. Parse vars section above --, then modifiers [type], inserts {expr}, and forks > [[link]]"

# 2. Implement modifiers
claude "Create lib/whisker/formats/twine/chapbook/modifiers.lua with handlers for [if], [unless], [else], [cont'd], [append], [note], [after]"

# 3. Create converter
claude "Create lib/whisker/formats/twine/chapbook/converter.lua converting Chapbook structure to Whisker stories"

# 4. Create format
claude "Create lib/whisker/formats/twine/chapbook/init.lua with ChapbookFormat implementing ITwineFormat. Register as 'format.twine.chapbook'"

# 5. Write tests
claude "Create tests/unit/formats/twine/chapbook/ with parser, modifiers, and converter tests"
```

---

## Stage 16: Snowman Parser and Converter

### Prerequisites
- Stage 05: Base format class complete
- Stage 15: Lighter-weight format pattern from Chapbook

### Objectives
Implement Snowman format support. Snowman uses JavaScript template literals (`<% %>`, `<%= %>`). This is the lightest implementation as Snowman is essentially embedded JavaScript.

### Inputs
- `lib/whisker/formats/twine/common/base_format.lua`
- Snowman documentation

### Tasks
1. Implement `SnowmanParser`:
   - Parse `<% code %>` execution blocks
   - Parse `<%= expression %>` output blocks
   - Parse `<%- html %>` raw output
   - Preserve surrounding HTML/text
2. Implement template conversion:
   - JavaScript execution → Whisker statements
   - Output expressions → Whisker interpolation
   - `s.variable` → `$variable` mapping
3. Handle Snowman helpers:
   - `link(text, passage)` → Choice
   - `visited(passage)` → History check
   - `either(...)` → Random selection
4. Create `SnowmanConverter`
5. Implement `SnowmanFormat`
6. Write tests

### Outputs
- `lib/whisker/formats/twine/snowman/template.lua` (new, ~150 lines)
- `lib/whisker/formats/twine/snowman/converter.lua` (new, ~120 lines)
- `lib/whisker/formats/twine/snowman/init.lua` (new, ~50 lines)
- `tests/unit/formats/twine/snowman/` (new, ~180 lines)

### Acceptance Criteria
- [ ] Snowman template tags are correctly parsed
- [ ] JavaScript is preserved or converted where possible
- [ ] `s.variable` maps to `$variable`
- [ ] Common helpers are converted
- [ ] Complex JavaScript is preserved with warnings
- [ ] Tests pass

### Estimated Scope
- **Production code:** 300-350 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1.5-2 days

### Claude Code Instructions

```bash
# 1. Create template parser
claude "Create lib/whisker/formats/twine/snowman/template.lua. Parse <% %> code blocks, <%= %> output, and <%- %> raw output. Track surrounding text."

# 2. Create converter
claude "Create lib/whisker/formats/twine/snowman/converter.lua. Map s.variable to $variable, convert link() helper to choices, preserve complex JS as metadata with warnings"

# 3. Create format
claude "Create lib/whisker/formats/twine/snowman/init.lua with SnowmanFormat implementing ITwineFormat. Register as 'format.twine.snowman'"

# 4. Write tests
claude "Create tests/unit/formats/twine/snowman/ testing template parsing and conversion"
```

---

## Group F: Export & Round-Trip

---

## Stage 17: Whisker to Harlowe Export

### Prerequisites
- Stage 10: Harlowe converter (for reverse patterns)
- Full Whisker story structure understanding

### Objectives
Implement export from Whisker story format back to Harlowe syntax. This enables round-trip conversion and editing Whisker stories in Twine.

### Inputs
- Whisker story structure
- `lib/whisker/formats/twine/harlowe/` (for syntax reference)

### Tasks
1. Create `HarloweExporter` class:
   - Accept Whisker Story
   - Generate Harlowe passage content
2. Implement Whisker-to-Harlowe mappings:
   - Passage → Passage content
   - Choice → `(link-goto:)` or `[[link]]`
   - Conditional → `(if:)`, `(else:)` chains
   - Assignment → `(set:)`
   - Expression → Harlowe expression syntax
3. Handle formatting:
   - Generate readable Harlowe
   - Preserve metadata
4. Implement `HarloweFormat:export(story)`
5. Write export tests

### Outputs
- `lib/whisker/formats/twine/export/harlowe.lua` (new, ~200 lines)
- `tests/unit/formats/twine/export/harlowe_spec.lua` (new, ~180 lines)

### Acceptance Criteria
- [ ] Whisker stories export to valid Harlowe syntax
- [ ] Exported content imports back correctly (round-trip)
- [ ] Choices become appropriate link types
- [ ] Conditionals use correct Harlowe syntax
- [ ] Variables use `$name` syntax
- [ ] Export is readable/maintainable

### Estimated Scope
- **Production code:** 180-220 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1.5-2 days

### Claude Code Instructions

```bash
# 1. Create exporter
claude "Create lib/whisker/formats/twine/export/harlowe.lua with HarloweExporter class. Convert Whisker passages to Harlowe syntax."

# 2. Implement choice export
claude "Add choice export to HarloweExporter. Use [[link]] for simple choices, (link-goto:) for complex ones with conditions"

# 3. Implement conditional export
claude "Add conditional export. Convert Whisker conditionals to (if:)[hook](else-if:)[hook](else:)[hook] chains"

# 4. Add round-trip tests
claude "Create tests/unit/formats/twine/export/harlowe_spec.lua including round-trip tests: import → export → import = same structure"
```

---

## Stage 18: Whisker to SugarCube Export

### Prerequisites
- Stage 14: SugarCube converter (for reverse patterns)
- Stage 17: Export patterns from Harlowe

### Objectives
Implement export from Whisker story format to SugarCube syntax, following the same pattern as Harlowe export.

### Inputs
- Whisker story structure
- `lib/whisker/formats/twine/sugarcube/` (for syntax reference)

### Tasks
1. Create `SugarCubeExporter` class
2. Implement Whisker-to-SugarCube mappings:
   - Choice → `<<link>>` or `[[link]]`
   - Conditional → `<<if>>...<</if>>`
   - Assignment → `<<set>>`
   - Loop → `<<for>>`
3. Generate special passages where appropriate
4. Implement `SugarCubeFormat:export(story)`
5. Write export tests including round-trip

### Outputs
- `lib/whisker/formats/twine/export/sugarcube.lua` (new, ~200 lines)
- `tests/unit/formats/twine/export/sugarcube_spec.lua` (new, ~180 lines)

### Acceptance Criteria
- [ ] Whisker stories export to valid SugarCube syntax
- [ ] Round-trip conversion preserves structure
- [ ] Block macros are properly closed
- [ ] Special passages are generated where needed

### Estimated Scope
- **Production code:** 180-220 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1.5-2 days

### Claude Code Instructions

```bash
# 1. Create exporter
claude "Create lib/whisker/formats/twine/export/sugarcube.lua with SugarCubeExporter class. Convert Whisker passages to SugarCube syntax with <<macro>> format."

# 2. Add block macro generation
claude "Implement block macro generation ensuring all <<if>>, <<for>>, etc. have matching <</if>>, <</for>> closers"

# 3. Write tests
claude "Create tests/unit/formats/twine/export/sugarcube_spec.lua with comprehensive export and round-trip tests"
```

---

## Stage 19: HTML Archive Generation

### Prerequisites
- Stage 02: Archive parser (for format reference)
- Stage 17-18: Format exporters complete

### Objectives
Implement HTML archive generation that produces complete, playable Twine HTML files. This completes the export pipeline.

### Inputs
- Twine HTML format specification
- `lib/whisker/formats/twine/archive/parser.lua` (format reference)

### Tasks
1. Create `ArchiveWriter` class:
   - Generate `<tw-storydata>` element
   - Generate `<tw-passagedata>` elements
   - Include author CSS/JS if present
2. Implement metadata generation:
   - IFID (generate if missing)
   - Format specification
   - Creator attribution
3. Handle passage attributes:
   - pid generation
   - Position/size (optional, for Twine editor)
   - Tag preservation
4. Implement `ITwineArchive:generate(story, options)`
5. Write archive generation tests
6. Test with Twine import

### Outputs
- `lib/whisker/formats/twine/archive/writer.lua` (new, ~180 lines)
- `lib/whisker/formats/twine/export/archive.lua` (new, ~100 lines)
- `lib/whisker/formats/twine/export/init.lua` (new, ~40 lines)
- `tests/unit/formats/twine/archive/writer_spec.lua` (new, ~150 lines)
- `tests/integration/formats/twine/archive_roundtrip_spec.lua` (new, ~100 lines)

### Acceptance Criteria
- [ ] Generated HTML is valid Twine archive format
- [ ] All passages are included with correct attributes
- [ ] Metadata is properly formatted
- [ ] IFID is generated if not present
- [ ] Author CSS/JS is included
- [ ] Generated archives import into Twine 2
- [ ] Full round-trip: Twine → Whisker → Twine works

### Estimated Scope
- **Production code:** 300-350 lines
- **Test code:** 230-280 lines
- **Estimated time:** 2-2.5 days

### Claude Code Instructions

```bash
# 1. Create archive writer
claude "Create lib/whisker/formats/twine/archive/writer.lua with ArchiveWriter class. Generate valid Twine HTML with tw-storydata and tw-passagedata elements."

# 2. Add metadata generation
claude "Add metadata generation to writer: IFID (UUID) generation, creator info, format specification"

# 3. Create export init
claude "Create lib/whisker/formats/twine/export/init.lua exporting Harlowe, SugarCube, and archive generation"

# 4. Add archive integration
claude "Create lib/whisker/formats/twine/export/archive.lua that combines format exporter + archive writer for complete HTML generation"

# 5. Write tests
claude "Create tests for archive writer and full round-trip integration test"

# 6. Update main archive init
claude "Update lib/whisker/formats/twine/archive/init.lua to export writer"
```

---

## Group G: Integration & Documentation

---

## Stage 20: Container Registration and Integration Tests

### Prerequisites
- All format implementations complete (Stages 10, 14, 15, 16)
- Archive parser and writer complete

### Objectives
Register all Twine format implementations with the whisker container and create comprehensive integration tests that verify the complete import/export pipeline for all formats.

### Inputs
- All format implementations
- `lib/whisker/kernel/container.lua`

### Tasks
1. Update `lib/whisker/formats/twine/init.lua`:
   - Register all formats with container
   - Add capability detection
   - Emit registration events
2. Create format selection logic:
   - Auto-detect from source
   - Allow explicit format specification
3. Create integration test suite:
   - Test each format's import/export
   - Test cross-format conversion
   - Test round-trip for each format
4. Add end-to-end tests with community stories
5. Verify event emission at all stages
6. Performance benchmarks

### Outputs
- `lib/whisker/formats/twine/init.lua` (major update, ~150 lines)
- `tests/integration/formats/twine/import_export_spec.lua` (new, ~300 lines)
- `tests/integration/formats/twine/cross_format_spec.lua` (new, ~200 lines)
- `tests/integration/formats/twine/community_stories/` (new fixture directory)
- `tests/performance/formats/twine/` (new, ~100 lines)

### Acceptance Criteria
- [ ] All 4 formats registered with container
- [ ] `whisker.formats:get("twine.harlowe")` returns correct format
- [ ] Auto-detection selects correct format
- [ ] All integration tests pass
- [ ] Cross-format conversion works (e.g., Harlowe → SugarCube)
- [ ] Community story tests pass
- [ ] Performance benchmarks establish baseline

### Estimated Scope
- **Production code:** 130-160 lines
- **Test code:** 580-650 lines
- **Estimated time:** 2-2.5 days

### Claude Code Instructions

```bash
# 1. Update main init
claude "Update lib/whisker/formats/twine/init.lua to register all formats with container: format.twine.harlowe, format.twine.sugarcube, format.twine.chapbook, format.twine.snowman. Add auto-detection from archive."

# 2. Create integration tests
claude "Create tests/integration/formats/twine/import_export_spec.lua testing full import/export pipeline for each format"

# 3. Create cross-format tests
claude "Create tests/integration/formats/twine/cross_format_spec.lua testing conversion between formats (Harlowe→SugarCube, etc.)"

# 4. Add community stories
claude "Create tests/integration/formats/twine/community_stories/ directory. Add representative stories from itch.io or Twine cookbook for each format."

# 5. Create performance tests
claude "Create tests/performance/formats/twine/ with benchmarks for large story import/export"

# 6. Verify event emission
claude "Add tests verifying all documented events are emitted during import/export"
```

---

## Stage 21: Format Documentation and Compatibility Guide

### Prerequisites
- Stage 20: Integration tests complete
- All formats fully implemented

### Objectives
Create comprehensive documentation for Twine format support including API reference, compatibility matrices, migration guides, and troubleshooting.

### Inputs
- All implementation code
- Test results and compatibility notes
- Appendices from this prompt

### Tasks
1. Create TWINE_FORMATS.md:
   - Overview of Twine support
   - Quick start guide
   - Format comparison
2. Create FORMAT_COMPATIBILITY.md:
   - Feature support matrix
   - Macro compatibility tables
   - Known limitations
3. Create MIGRATION_GUIDE.md:
   - Importing Twine stories
   - Exporting to Twine
   - Cross-format conversion tips
4. Add API documentation:
   - ITwineFormat methods
   - Macro registry API
   - Event reference
5. Create troubleshooting guide
6. Update main README

### Outputs
- `docs/TWINE_FORMATS.md` (new, ~300 lines)
- `docs/FORMAT_COMPATIBILITY.md` (new, ~200 lines)
- `docs/MIGRATION_GUIDE.md` (new, ~250 lines)
- `docs/api/TWINE_API.md` (new, ~200 lines)
- `README.md` (updated)

### Acceptance Criteria
- [ ] Documentation covers all 4 formats
- [ ] Feature matrices are accurate and complete
- [ ] Code examples are tested and working
- [ ] Migration guide covers common scenarios
- [ ] Troubleshooting addresses known issues
- [ ] README updated with Twine support info

### Estimated Scope
- **Documentation:** 900-1000 lines
- **Estimated time:** 1.5-2 days

### Claude Code Instructions

```bash
# 1. Create main documentation
claude "Create docs/TWINE_FORMATS.md with overview, quick start, and format comparison for Harlowe, SugarCube, Chapbook, Snowman"

# 2. Create compatibility matrix
claude "Create docs/FORMAT_COMPATIBILITY.md with feature support matrix, macro compatibility tables for each format, and known limitations list"

# 3. Create migration guide
claude "Create docs/MIGRATION_GUIDE.md with step-by-step guides for importing Twine stories, exporting to Twine, and converting between formats"

# 4. Create API reference
claude "Create docs/api/TWINE_API.md documenting ITwineFormat, IMacroRegistry, archive parser, and event reference"

# 5. Update README
claude "Update README.md with section on Twine format support, linking to detailed documentation"
```

---

## Appendix A: Twine Archive Format Reference

### Twine 2 HTML Structure

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{{STORY_NAME}}</title>
</head>
<body>
  <tw-storydata 
    name="{{STORY_NAME}}"
    startnode="{{START_PID}}"
    creator="Twine"
    creator-version="{{TWINE_VERSION}}"
    ifid="{{UUID}}"
    format="{{FORMAT_NAME}}"
    format-version="{{FORMAT_VERSION}}"
    options=""
    hidden>
    
    <tw-passagedata 
      pid="{{PASSAGE_ID}}"
      name="{{PASSAGE_NAME}}"
      tags="{{SPACE_SEPARATED_TAGS}}"
      position="{{X}},{{Y}}"
      size="{{W}},{{H}}">
      {{PASSAGE_CONTENT}}
    </tw-passagedata>
    
    <style role="stylesheet" id="twine-user-stylesheet" type="text/twine-css">
      {{AUTHOR_CSS}}
    </style>
    
    <script role="script" id="twine-user-script" type="text/twine-javascript">
      {{AUTHOR_JS}}
    </script>
    
  </tw-storydata>
</body>
</html>
```

### Attribute Reference

| Attribute | Element | Description |
|-----------|---------|-------------|
| `name` | tw-storydata | Story title |
| `startnode` | tw-storydata | PID of starting passage |
| `creator` | tw-storydata | Editor name ("Twine") |
| `creator-version` | tw-storydata | Editor version |
| `ifid` | tw-storydata | Interactive Fiction ID (UUID) |
| `format` | tw-storydata | Story format name |
| `format-version` | tw-storydata | Story format version |
| `pid` | tw-passagedata | Passage ID (numeric, unique) |
| `name` | tw-passagedata | Passage name (string, unique) |
| `tags` | tw-passagedata | Space-separated tag list |
| `position` | tw-passagedata | Editor position "x,y" |
| `size` | tw-passagedata | Editor size "w,h" |

---

## Appendix B: Harlowe Macro Catalog

### Priority 1: Core Macros (Must Implement)

| Macro | Syntax | Category | Description |
|-------|--------|----------|-------------|
| `(set:)` | `(set: $var to value)` | Variables | Assign value |
| `(put:)` | `(put: value into $var)` | Variables | Reverse assign |
| `(if:)` | `(if: cond)[hook]` | Control | Conditional |
| `(unless:)` | `(unless: cond)[hook]` | Control | Negated conditional |
| `(else-if:)` | `(else-if: cond)[hook]` | Control | Chained conditional |
| `(else:)` | `(else:)[hook]` | Control | Default branch |
| `(link:)` | `(link: "text")[hook]` | Links | Clickable link |
| `(link-goto:)` | `(link-goto: "text", "passage")` | Links | Navigation link |
| `(goto:)` | `(goto: "passage")` | Navigation | Immediate navigation |
| `(print:)` | `(print: value)` | Output | Display value |
| `(a:)` | `(a: 1, 2, 3)` | Data | Create array |
| `(dm:)` | `(dm: "key", val)` | Data | Create datamap |
| `(ds:)` | `(ds: 1, 2, 3)` | Data | Create dataset |

### Priority 2: Common Macros (Should Implement)

| Macro | Syntax | Category | Description |
|-------|--------|----------|-------------|
| `(link-reveal:)` | `(link-reveal: "text")[hook]` | Links | Reveal on click |
| `(link-repeat:)` | `(link-repeat: "text")[hook]` | Links | Repeatable action |
| `(for:)` | `(for: each _item, array)[hook]` | Control | Loop over array |
| `(either:)` | `(either: a, b, c)` | Random | Random selection |
| `(cond:)` | `(cond: test, val, ...)` | Control | Conditional value |
| `(nth:)` | `(nth: n, a, b, c)` | Data | Get nth item |
| `(count:)` | `(count: array, item)` | Data | Count occurrences |
| `(range:)` | `(range: 1, 10)` | Data | Number range |
| `(history:)` | `(history:)` | State | Visited passages |
| `(passage:)` | `(passage: "name")` | State | Passage data |
| `(num:)` | `(num: "123")` | Type | To number |
| `(str:)` | `(str: 123)` | Type | To string |
| `(lowercase:)` | `(lowercase: "ABC")` | Text | Lowercase |
| `(uppercase:)` | `(uppercase: "abc")` | Text | Uppercase |

---

## Appendix C: SugarCube Macro Catalog

### Priority 1: Core Macros (Must Implement)

| Macro | Syntax | Category |
|-------|--------|----------|
| `<<set>>` | `<<set $var to val>>` | Variables |
| `<<unset>>` | `<<unset $var>>` | Variables |
| `<<if>>` | `<<if cond>>...<</if>>` | Control |
| `<<elseif>>` | `<<elseif cond>>` | Control |
| `<<else>>` | `<<else>>` | Control |
| `<<for>>` | `<<for _i range $arr>>` | Control |
| `<<link>>` | `<<link "text">>...<</link>>` | Links |
| `<<goto>>` | `<<goto "passage">>` | Navigation |
| `<<print>>` | `<<print $var>>` | Output |
| `<<include>>` | `<<include "passage">>` | Include |
| `<<run>>` | `<<run code>>` | JavaScript |
| `<<script>>` | `<<script>>js<</script>>` | JavaScript |

### Priority 2: Common Macros (Should Implement)

| Macro | Syntax | Category |
|-------|--------|----------|
| `<<linkreplace>>` | `<<linkreplace "text">>...<</linkreplace>>` | Links |
| `<<linkappend>>` | `<<linkappend "text">>...<</linkappend>>` | Links |
| `<<switch>>` | `<<switch $var>>...<</switch>>` | Control |
| `<<case>>` | `<<case val>>` | Control |
| `<<default>>` | `<<default>>` | Control |
| `<<capture>>` | `<<capture $var>>...<</capture>>` | Variables |
| `<<silently>>` | `<<silently>>...<</silently>>` | Output |
| `<<widget>>` | `<<widget "name">>...<</widget>>` | Custom |
| `<<return>>` | `<<return>>` | Navigation |
| `<<back>>` | `<<back>>` | Navigation |

---

## Appendix D: Chapbook & Snowman Reference

### Chapbook Modifiers

| Modifier | Example | Description |
|----------|---------|-------------|
| `[if condition]` | `[if gold > 50]` | Conditional display |
| `[unless condition]` | `[unless visited]` | Negated conditional |
| `[else]` | `[else]` | Else branch |
| `[cont'd]` | `[cont'd]` | Continue paragraph |
| `[append]` | `[append]` | Append to previous |
| `[note]` | `[note]` | Editor-only text |
| `[after time]` | `[after 2 seconds]` | Delayed display |

### Chapbook Inserts

| Insert | Example | Description |
|--------|---------|-------------|
| `{var}` | `{gold}` | Variable value |
| `{expression}` | `{gold * 2}` | Expression result |
| `{embed passage: 'name'}` | | Embed passage |
| `{reveal link: 'text', passage: 'name'}` | | Reveal link |

### Snowman Helpers

| Helper | Example | Description |
|--------|---------|-------------|
| `link(text, passage)` | `<%= link("Go", "Room") %>` | Create link |
| `passage(name)` | `<%= passage("Intro") %>` | Render passage |
| `either(...args)` | `<%= either("a","b","c") %>` | Random choice |
| `visited(passage)` | `<% if(visited("Room")) %>` | Check visited |

---

## Appendix E: Format Feature Comparison Matrix

| Feature | Harlowe | SugarCube | Chapbook | Snowman | Whisker Mapping |
|---------|---------|-----------|----------|---------|-----------------|
| Basic links | ✅ | ✅ | ✅ | ✅ | Choice + Divert |
| Conditional display | ✅ | ✅ | ✅ | ✅ | Conditional |
| Variables | ✅ | ✅ | ✅ | ✅ | Assignment |
| Loops | ✅ | ✅ | ❌ | ✅ | For statement |
| Custom macros | ❌ | ✅ (widgets) | ❌ | ✅ (JS) | Functions |
| Passage includes | ✅ | ✅ | ✅ | ✅ | Include |
| Arrays/Lists | ✅ | ✅ | ✅ | ✅ | List |
| DOM manipulation | ✅ | ✅ | ❌ | ✅ | ⚠️ Warning |
| Audio/Video | ❌ | ✅ | ❌ | ❌ | ⚠️ Metadata |
| Save/Load | ✅ | ✅ | ✅ | ✅ | IState |

**Legend:** ✅ Full support | ⚠️ Partial/warning | ❌ Not supported

---

## Token Budget Checkpoint Protocol

If you reach ~65% of your token budget while generating this document:

1. Complete the current stage fully
2. Generate a checkpoint summary with:
   - Completed stages list
   - Current position (group, stage number)
   - Key patterns established
   - Macros implemented by format
3. Provide continuation prompt for next session

### Continuation Prompt Template

```markdown
## Continuation Prompt for Phase 4 Stages

Continue generating Phase 4 (Enhanced Twine Support) implementation stages.

**Completed stages:** [list]
**Current position:** Stage [NN], Group [X]
**Next stage:** [Title]

**Established patterns:**
- [Key patterns to maintain]

**Resume from Stage [NN]: [Title]**
```

---

*End of Phase 4 Implementation Stages Document*
