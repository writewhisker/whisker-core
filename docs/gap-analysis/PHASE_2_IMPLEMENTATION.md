# Phase 2 Implementation: Ink Integration

## Document Information
- **Project:** whisker-core
- **Phase:** 2 of 7
- **Depends On:** whisker-core-roadmap.md, PHASE_1_IMPLEMENTATION.md
- **Estimated Duration:** 6-8 weeks
- **Total Stages:** 22
- **Generation Status:** Complete

---

## Phase 2 Context

### Ink Format Overview

Ink is Inkle's scripting language for interactive narrative, designed to handle complex branching stories with sophisticated state management. Understanding Ink's core concepts is essential for proper integration with whisker-core.

#### Ink Structural Concepts

**Knots** are the primary organizational unit in Ink, analogous to chapters or scenes. They are declared with `=== knot_name ===` and serve as major navigation targets. Each knot can contain narrative content, choices, and logic.

**Stitches** are subsections within knots, declared with `= stitch_name`. They provide finer-grained organization and can be addressed as `knot_name.stitch_name`. Stitches inherit their parent knot's context.

**Choices** come in two varieties:
- **Once-only choices** (`* choice text`): Can only be selected once per playthrough
- **Sticky choices** (`+ choice text`): Remain available for repeated selection

Choice text can include:
- Bracketed text `[shown only in choice]` vs `shown in both choice and output`
- Conditional display using `{condition}` guards
- Fallback choices that trigger automatically when no other choices are available

**Diverts** (`-> target`) handle navigation between content sections. They can target knots, stitches, or special destinations like `-> DONE` (end current flow) or `-> END` (end story entirely).

**Tunnels** (`->->`) provide subroutine-like functionality. Content flows into a tunnel, executes, and returns to the calling location. Tunnels use `->->` for return.

**Threads** (`<- knot`) enable parallel content gathering, allowing content from multiple sources to be combined into a single output stream.

#### Ink State and Logic

**Variables** are declared with `VAR name = value` for globals or `temp name = value` for temporaries. Ink supports integers, floats, booleans, strings, and special types like divert targets and lists.

**Conditionals** use curly braces:
- Inline conditionals: `{condition: true text | false text}`
- Multi-line conditionals with branches: `{ condition: ... - else: ... }`
- Sequence variations: `{&shuffle|options}`, `{!once|only}`, `{stopping|at|last}`

**Logic operations** use the `~` prefix for assignments and function calls outside of conditional contexts.

**Visit counts** track how many times content has been visited, accessible via `knot_name` returning the count directly. This enables adaptive narrative that changes based on player exploration.

**Tags** (`# tag_name`) attach metadata to content for use by the game engine (e.g., speaker identification, mood indicators, audio cues).

**Glue** (`<>`) controls whitespace by preventing line breaks between content pieces.

#### Compiled Ink JSON Format

When Ink source is compiled by inklecate, it produces a JSON format designed for runtime execution. Key characteristics:

- **inkVersion**: Integer indicating the format version (current versions use 20+)
- **root**: The outermost Container holding all story content
- **Containers**: Arrays that hold ordered content and optional named children
- **Control Commands**: String instructions like `"ev"` (evaluation start), `"/ev"` (evaluation end), `"str"` (string mode), etc.
- **Primitives**: Strings (prefixed with `^`), numbers, and boolean representations
- **Objects**: Structured data like choice points, diverts, variable references

The JSON format represents the story as a tree of Containers with embedded instructions that the runtime interprets sequentially, managing an evaluation stack and output stream.

### tinta Library Architecture

tinta is a Lua port of the official Ink runtime, providing a reference implementation that we can adapt for whisker-core. Understanding its architecture is crucial for proper integration.

#### Core Components

**Story** (`tinta/engine/story.lua`): The main entry point. Creates a story instance from a pre-converted Lua table (originally from ink.json). Manages:
- Content continuation (`Continue()`, `ContinueAsync()`)
- Choice presentation (`currentChoices`, `ChooseChoiceIndex()`)
- Path navigation (`ChoosePathString()`)
- State serialization

**StoryState** (`tinta/engine/state.lua`): Maintains runtime state including:
- Current content pointer
- Evaluation stack
- Output stream
- Turn/visit counts
- Callstack for tunnels and functions
- Flow management

**CallStack** (`tinta/engine/callstack.lua`): Manages the execution stack for:
- Function calls and returns
- Tunnel entry and exit
- Thread management
- Temporary variable scoping

**VariablesState** (`tinta/engine/variables_state.lua`): Handles:
- Global variable storage
- Variable observers (callbacks on change)
- Default variable values from story definition

**Flow** (`tinta/engine/flow.lua`): Represents parallel execution contexts, each with its own callstack and temporary state but sharing global variables.

#### tinta Execution Model

1. **Initialization**: Story definition (Lua table) is loaded; initial state is created
2. **Continuation**: `Continue()` advances the story until reaching a stopping point (choices, end, or async yield)
3. **Evaluation Mode**: Between `"ev"` and `"/ev"` commands, content goes to evaluation stack instead of output
4. **Choice Resolution**: Player selections are processed via `ChooseChoiceIndex()`
5. **State Persistence**: `state:save()` and `state:load()` enable save/restore functionality

#### Key tinta Patterns

**Import Pattern**: tinta uses a custom `import()` function for module loading, which we'll need to adapt to whisker-core's `require()` conventions.

**JSON-to-Lua Conversion**: tinta requires pre-conversion of ink.json to Lua tables via scripts (`json_to_lua.sh`). We'll provide native JSON loading capability.

**External Functions**: Lua functions can be bound to Ink declarations, enabling game engine integration.

**Variable Observers**: Callback functions triggered when Ink variables change, useful for UI updates and game state synchronization.

### Integration Strategy

Our integration approach follows these principles:

#### Adapter Pattern

Rather than deeply modifying tinta, we create adapter layers that bridge tinta's internal interfaces to whisker-core's standardized interfaces. This provides:
- Isolation of tinta code for easier updates
- Clean separation of concerns
- Ability to swap implementations later

#### Interface Compliance

All Ink-related modules implement whisker-core interfaces:
- **IInkFormat** implements **IFormat**: Loading and validating Ink stories
- **InkState** wraps tinta's state to implement **IState**: State management interface
- **InkEngine** implements **IEngine**: Runtime execution interface

#### Event Integration

tinta's internal operations emit events through whisker-core's event bus:
- `ink.story.loaded` — When an Ink story is successfully loaded
- `ink.story.continued` — After each Continue() call
- `ink.choice.made` — When a choice is selected
- `ink.variable.changed` — When an Ink variable changes
- `ink.external.called` — When an external function is invoked

#### DI Container Registration

All Ink components register with the dependency injection container:
```lua
container:register("format.ink", InkFormat, { implements = "IFormat" })
container:register("engine.ink", InkEngine, { implements = "IEngine" })
container:register("state.ink", InkState, { implements = "IState" })
```

### Interface Mappings

This table defines how Ink concepts map to whisker-core structures:

| Ink Concept | Whisker Component | Mapping Strategy |
|-------------|-------------------|------------------|
| Story | Story | Direct wrapping with metadata extraction |
| Knot | Passage | Each knot becomes a Passage with `type: "knot"` |
| Stitch | Passage | Each stitch becomes a Passage with `parent` reference |
| Choice | Choice | Direct mapping with sticky flag preserved |
| Divert | Link/Navigation | Target passage reference |
| VAR | Variable | Type-preserving storage in Variable system |
| temp | Variable | Scoped temporary with lifecycle management |
| Conditional | Condition | Expression tree conversion |
| Tag | Metadata | Attached to parent Passage or Choice |
| Tunnel | Passage + CallStack | Special passage type with return tracking |
| Thread | GatheredContent | Parallel evaluation result aggregation |
| Flow | Separate State | Isolated execution context |
| Visit Count | State.visits | Persisted in state as path-indexed counts |
| Glue | Content Flag | Whitespace control in passage content |

#### Content Path Mapping

Ink uses dot-notation paths (`knot.stitch.gather.0`). These map to whisker-core passage IDs:
- Simple knot: `"meeting"` → Passage ID `"meeting"`
- Stitch: `"meeting.intro"` → Passage ID `"meeting.intro"`
- Indexed content: Handled internally by engine, not exposed as passages

#### Choice Type Preservation

| Ink Choice Type | Whisker Choice Flags |
|-----------------|---------------------|
| `*` (once-only) | `{ once: true, sticky: false }` |
| `+` (sticky) | `{ once: false, sticky: true }` |
| `* { cond }` | `{ once: true, condition: {...} }` |
| Fallback | `{ fallback: true, auto: true }` |

### File Organization

Ink-related code lives in a dedicated directory structure:

```
lib/whisker/
├── formats/
│   └── ink/
│       ├── init.lua              # Module entry point
│       ├── format.lua            # IInkFormat implementation
│       ├── adapter.lua           # tinta-to-whisker adapter
│       ├── converter.lua         # Ink-to-Whisker conversion
│       ├── exporter.lua          # Whisker-to-Ink export
│       ├── json_loader.lua       # Native JSON loading (no pre-conversion)
│       └── engine.lua            # InkEngine (IEngine impl)
│
├── vendor/
│   └── tinta/                    # Vendored tinta library
│       ├── engine/
│       │   ├── story.lua
│       │   ├── state.lua
│       │   ├── callstack.lua
│       │   ├── variables_state.lua
│       │   ├── flow.lua
│       │   └── ...
│       ├── values/
│       │   ├── value.lua
│       │   ├── list.lua
│       │   └── ...
│       └── ...
│
spec/
├── formats/
│   └── ink/
│       ├── format_spec.lua       # IFormat contract tests
│       ├── engine_spec.lua       # IEngine contract tests
│       ├── converter_spec.lua    # Conversion tests
│       ├── exporter_spec.lua     # Export tests
│       └── integration_spec.lua  # Full story playthroughs
│
test/
└── fixtures/
    └── ink/
        ├── minimal.json          # Simplest valid Ink story
        ├── choices.json          # All choice types
        ├── variables.json        # Variable operations
        ├── conditionals.json     # Conditional content
        ├── tunnels.json          # Tunnel and thread usage
        ├── flows.json            # Multi-flow stories
        └── real_world/           # Larger test stories
            └── intercept/        # Official test story
```

### Conversion Architecture

#### Ink-to-Whisker Conversion

The converter transforms compiled Ink JSON into whisker-core's native format:

1. **Parse Phase**: Load ink.json, validate inkVersion
2. **Structure Extraction**: Walk container tree, identify knots/stitches
3. **Content Transformation**: Convert Ink primitives to Whisker equivalents
4. **Choice Processing**: Extract choice points, preserve conditions
5. **Variable Mapping**: Capture global declarations, default values
6. **Metadata Preservation**: Extract and store all tags
7. **Validation**: Ensure all references resolve, no orphaned content

#### Whisker-to-Ink Export

The exporter produces ink.json from whisker-core stories:

1. **Structure Building**: Create container hierarchy from passages
2. **Content Encoding**: Convert text and logic to Ink JSON format
3. **Choice Generation**: Produce choice points with proper flags
4. **Variable Declarations**: Generate VAR statements for globals
5. **Path Resolution**: Ensure all diverts have valid targets
6. **Version Tagging**: Set appropriate inkVersion for compatibility

### Testing Strategy

Following the roadmap's testing principles:

#### Contract Tests
Every interface implementation must pass the contract test suite:
- `IFormat` contract: load, validate, can_import, can_export
- `IEngine` contract: load, start, continue, get_choices, make_choice
- `IState` contract: get, set, snapshot, restore

#### Ink Compliance Tests
Verify behavior against official Ink test cases:
- Variable operations
- Conditional evaluation
- Choice mechanics
- Tunnel behavior
- Thread gathering
- Flow management

#### Round-Trip Tests
Ensure conversion fidelity:
- Ink → Whisker → Ink produces equivalent stories
- No data loss in metadata, variables, or structure

#### Real-World Story Tests
Test against published Ink content:
- The Intercept (official Inkle demo)
- Community stories with known-good behavior

---

## Stage Definitions

---

## Stage 01: tinta Repository Analysis and Documentation

### Prerequisites
- Phase 1 complete (all stages)
- Access to tinta repository at https://github.com/smwhr/tinta
- Access to Ink JSON format documentation

### Objectives
- Analyze tinta's complete source structure and architecture
- Document all public APIs and extension points
- Identify adaptation requirements for whisker-core integration
- Create reference documentation for subsequent stages

### Inputs
- tinta repository source code
- Ink JSON runtime format specification
- whisker-core interface definitions from `lib/whisker/interfaces/`

### Tasks
1. Clone and analyze tinta repository structure
2. Document all files in `tinta/source/engine/` with purpose and dependencies
3. Document all files in `tinta/source/values/` with type mappings
4. Identify tinta's internal interfaces and extension points
5. Map tinta APIs to whisker-core interfaces
6. Document tinta's state serialization format
7. Create `docs/tinta-analysis.md` with complete findings

### Outputs
- `docs/tinta-analysis.md` — Comprehensive tinta architecture documentation (~150 lines)
- `docs/ink-whisker-mapping.md` — Detailed concept mapping table (~80 lines)

### Acceptance Criteria
- [ ] All tinta source files documented with purpose
- [ ] Public APIs fully documented with signatures
- [ ] Extension points identified and documented
- [ ] Adaptation requirements clearly specified
- [ ] Interface mapping table complete
- [ ] Documentation reviewed for accuracy

### Estimated Scope
- New lines: ~230 (documentation)
- Modified lines: 0
- Test lines: 0

### Implementation Notes
- Focus on understanding, not modification
- Pay special attention to tinta's import/require patterns
- Note any Playdate-specific code that needs adaptation
- Document the json_to_lua conversion process and alternatives

---

## Stage 02: Vendor tinta into whisker-core

### Prerequisites
- Phase 1 complete (all stages)
- Stage 01 completed (tinta analysis documentation)

### Objectives
- Fork tinta source code into whisker-core's vendor directory
- Adapt module loading to use standard Lua require()
- Ensure vendored tinta runs independently
- Establish version tracking for vendored code

### Inputs
- tinta repository source files
- `docs/tinta-analysis.md` from Stage 01
- whisker-core project structure

### Tasks
1. Create `lib/whisker/vendor/tinta/` directory structure
2. Copy tinta source files preserving internal organization
3. Create `lib/whisker/vendor/tinta/init.lua` as entry point
4. Modify `import()` calls to use standard `require()`
5. Add `lib/whisker/vendor/tinta/VERSION` file tracking source commit
6. Create `lib/whisker/vendor/tinta/LICENSE` with MIT license text
7. Add basic smoke test to verify vendored tinta loads

### Outputs
- `lib/whisker/vendor/tinta/init.lua` — Entry point (~30 lines)
- `lib/whisker/vendor/tinta/engine/` — Core engine files (vendored)
- `lib/whisker/vendor/tinta/values/` — Value type files (vendored)
- `lib/whisker/vendor/tinta/VERSION` — Version tracking (~5 lines)
- `spec/vendor/tinta_smoke_spec.lua` — Basic loading test (~40 lines)

### Acceptance Criteria
- [ ] All tinta source files present in vendor directory
- [ ] `require("whisker.vendor.tinta")` loads without error
- [ ] Module paths correctly resolve internal dependencies
- [ ] VERSION file contains source repository commit hash
- [ ] MIT license properly attributed
- [ ] Smoke test passes: `busted spec/vendor/tinta_smoke_spec.lua`

### Estimated Scope
- New lines: ~75 (init, version, tests)
- Modified lines: ~50 (import → require conversions)
- Test lines: ~40

### Implementation Notes
- Preserve tinta's directory structure for easier future updates
- Use relative requires within vendor directory
- Document any modifications to vendored code in a CHANGES.md file
- The init.lua should export the Story constructor as primary interface

---

## Stage 03: Native JSON Loading for tinta

### Prerequisites
- Phase 1 complete (all stages)
- Stage 02 completed (tinta vendored)
- JSON library available (cjson or similar)

### Objectives
- Enable loading ink.json files directly without pre-conversion
- Implement runtime JSON-to-Lua table conversion
- Maintain compatibility with pre-converted Lua tables
- Provide streaming support for large stories

### Inputs
- `lib/whisker/vendor/tinta/` from Stage 02
- Sample ink.json files for testing
- Ink JSON format specification

### Tasks
1. Create `lib/whisker/formats/ink/json_loader.lua` module
2. Implement JSON parsing using available library
3. Handle ink.json specific structures (containers, commands)
4. Create conversion function matching tinta's expected table format
5. Add support for loading from file path or string content
6. Implement lazy loading option for large stories
7. Add comprehensive tests for JSON loading

### Outputs
- `lib/whisker/formats/ink/json_loader.lua` — JSON loader (~120 lines)
- `spec/formats/ink/json_loader_spec.lua` — Loader tests (~100 lines)
- `test/fixtures/ink/minimal.json` — Minimal test story (~20 lines)

### Acceptance Criteria
- [ ] Can load ink.json file by path
- [ ] Can load ink.json from string content
- [ ] Converted table matches tinta's expected format
- [ ] inkVersion field properly validated (supports 19+)
- [ ] Error messages clear for malformed JSON
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~140
- Modified lines: ~10
- Test lines: ~100

### Implementation Notes
- Use pcall for safe JSON parsing with good error messages
- The Ink JSON format uses specific conventions for commands (strings) vs content
- Handle the `^` prefix for string values
- Container arrays may have trailing null for named content dictionary
- Reference: https://github.com/inkle/ink/blob/master/Documentation/ink_JSON_runtime_format.md

---

## Stage 04: IInkFormat Interface Implementation

### Prerequisites
- Phase 1 complete (all stages)
- Stage 03 completed (JSON loader)
- IFormat interface defined at `lib/whisker/interfaces/format.lua`

### Objectives
- Create IInkFormat as an IFormat implementation for Ink stories
- Establish the adapter pattern between tinta and whisker-core
- Register IInkFormat with the DI container
- Enable capability detection for Ink support

### Inputs
- `lib/whisker/interfaces/format.lua` — IFormat interface definition
- `lib/whisker/kernel/container.lua` — DI container for registration
- `lib/whisker/vendor/tinta/` — Vendored tinta library
- `lib/whisker/formats/ink/json_loader.lua` — JSON loading

### Tasks
1. Create `lib/whisker/formats/ink/init.lua` — Module entry point
2. Create `lib/whisker/formats/ink/format.lua` — IInkFormat implementation
3. Implement `can_import()` detecting ink.json format
4. Implement `load()` using json_loader
5. Implement `validate()` for story structure verification
6. Implement `get_metadata()` for story info extraction
7. Register format in DI container with capability flag
8. Add IFormat contract tests for InkFormat

### Outputs
- `lib/whisker/formats/ink/init.lua` — Module entry (~25 lines)
- `lib/whisker/formats/ink/format.lua` — IInkFormat implementation (~100 lines)
- `spec/formats/ink/format_spec.lua` — Format tests (~90 lines)

### Acceptance Criteria
- [ ] IInkFormat passes IFormat interface compliance tests
- [ ] Can load ink.json file via `format:load(path)`
- [ ] Can load ink.json from string via `format:load_string(content)`
- [ ] `can_import()` returns true for valid ink.json, false otherwise
- [ ] Format registered: `container:has('format.ink') == true`
- [ ] Capability detectable: `kernel:has_capability('format.ink') == true`
- [ ] All tests pass: `busted spec/formats/ink/`

### Estimated Scope
- New lines: ~125
- Modified lines: ~15
- Test lines: ~90

### Implementation Notes
- IInkFormat:load() should accept both file paths and raw JSON strings
- Use lazy loading—don't fully parse until content is needed
- Emit 'format.loaded' event when an Ink story is successfully loaded
- Handle inkVersion field—tinta supports version 19+
- Store original ink.json for potential re-export

---

## Stage 05: Ink Story Wrapper and Metadata Extraction

### Prerequisites
- Phase 1 complete (all stages)
- Stage 04 completed (IInkFormat)

### Objectives
- Create InkStory wrapper around tinta Story
- Extract story metadata (title, author, tags)
- Provide passage enumeration for conversion
- Enable story introspection without full execution

### Inputs
- `lib/whisker/vendor/tinta/` — tinta Story class
- `lib/whisker/formats/ink/format.lua` — IInkFormat
- `lib/whisker/core/story.lua` — whisker-core Story structure

### Tasks
1. Create `lib/whisker/formats/ink/story.lua` — InkStory wrapper
2. Implement metadata extraction from story tags
3. Implement knot/stitch enumeration
4. Implement global variable listing
5. Implement external function declaration listing
6. Connect wrapper to IInkFormat
7. Add comprehensive tests

### Outputs
- `lib/whisker/formats/ink/story.lua` — InkStory wrapper (~130 lines)
- `spec/formats/ink/story_spec.lua` — Story wrapper tests (~100 lines)
- `test/fixtures/ink/metadata.json` — Test story with metadata (~30 lines)

### Acceptance Criteria
- [ ] Can extract story title from global tags
- [ ] Can enumerate all knots in story
- [ ] Can enumerate stitches within knots
- [ ] Can list global variables with default values
- [ ] Can list external function declarations
- [ ] Original tinta Story accessible for runtime execution
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~160
- Modified lines: ~20
- Test lines: ~100

### Implementation Notes
- Ink stories use `# title: Story Name` in global tags for metadata
- Knots are top-level named containers in root
- Stitches are named containers within knot containers
- External functions are declared with EXTERNAL keyword, tracked in story definition
- This wrapper enables conversion without full story execution

---

## Stage 06: InkEngine IEngine Implementation - Core

### Prerequisites
- Phase 1 complete (all stages)
- Stage 05 completed (InkStory wrapper)
- IEngine interface defined at `lib/whisker/interfaces/engine.lua`

### Objectives
- Create InkEngine implementing IEngine interface
- Wrap tinta's runtime execution model
- Provide standard engine operations (load, start, continue)
- Enable story playthrough via whisker-core interface

### Inputs
- `lib/whisker/interfaces/engine.lua` — IEngine interface
- `lib/whisker/vendor/tinta/` — tinta runtime
- `lib/whisker/formats/ink/story.lua` — InkStory wrapper

### Tasks
1. Create `lib/whisker/formats/ink/engine.lua` — InkEngine class
2. Implement `load(story)` accepting InkStory
3. Implement `start()` beginning story execution
4. Implement `can_continue()` checking story state
5. Implement `continue()` advancing to next stop point
6. Implement `get_current_text()` returning output content
7. Implement `get_current_tags()` returning current tags
8. Register engine in DI container
9. Add IEngine contract tests for InkEngine

### Outputs
- `lib/whisker/formats/ink/engine.lua` — InkEngine core (~140 lines)
- `spec/formats/ink/engine_spec.lua` — Engine tests (~120 lines)

### Acceptance Criteria
- [ ] InkEngine passes IEngine interface compliance tests
- [ ] `engine:load(story)` accepts InkStory instance
- [ ] `engine:start()` initializes execution
- [ ] `engine:can_continue()` returns correct state
- [ ] `engine:continue()` advances story, returns text
- [ ] `engine:get_current_tags()` returns tag array
- [ ] Engine registered in container
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~140
- Modified lines: ~15
- Test lines: ~120

### Implementation Notes
- InkEngine wraps tinta Story's Continue/canContinue methods
- Text output comes from tinta's currentText property
- Tags come from currentTags property
- Emit 'engine.continued' event after each continue
- Handle async continuation if needed (ContinueAsync)

---

## Stage 07: InkEngine Choice Handling

### Prerequisites
- Phase 1 complete (all stages)
- Stage 06 completed (InkEngine core)

### Objectives
- Add choice retrieval to InkEngine
- Implement choice selection mechanism
- Preserve choice metadata (sticky, once-only, conditions)
- Map Ink choices to whisker-core Choice structure

### Inputs
- `lib/whisker/formats/ink/engine.lua` — InkEngine core
- `lib/whisker/core/choice.lua` — whisker-core Choice structure
- tinta choice handling documentation

### Tasks
1. Implement `get_available_choices()` in InkEngine
2. Create choice adapter mapping Ink choice to whisker Choice
3. Implement `make_choice(index)` for selection
4. Preserve choice text (both choice-only and content portions)
5. Track choice availability (once-only vs sticky)
6. Emit choice-related events
7. Add comprehensive choice tests

### Outputs
- `lib/whisker/formats/ink/engine.lua` — Updated with choice handling (~50 lines added)
- `lib/whisker/formats/ink/choice_adapter.lua` — Choice mapping (~60 lines)
- `spec/formats/ink/choices_spec.lua` — Choice tests (~100 lines)
- `test/fixtures/ink/choices.json` — Choice test story (~40 lines)

### Acceptance Criteria
- [ ] `get_available_choices()` returns array of Choice objects
- [ ] Choices include text, index, and metadata
- [ ] `make_choice(index)` advances story correctly
- [ ] Once-only choices not repeated after selection
- [ ] Sticky choices remain available
- [ ] 'engine.choice.made' event emitted on selection
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~110
- Modified lines: ~20
- Test lines: ~100

### Implementation Notes
- tinta provides currentChoices as array of choice objects
- Each Ink choice has text, index, and pathStringOnChoice
- Choice text may have different "choice text" vs "content text" portions
- Once-only is default; sticky uses `+` syntax in source
- Fallback choices (default when others unavailable) need special handling

---

## Stage 08: InkEngine State Integration

### Prerequisites
- Phase 1 complete (all stages)
- Stage 07 completed (InkEngine choices)
- IState interface defined at `lib/whisker/interfaces/state.lua`

### Objectives
- Create InkState implementing IState interface
- Bridge tinta's state management to whisker-core
- Enable save/load functionality
- Provide variable access through standard interface

### Inputs
- `lib/whisker/interfaces/state.lua` — IState interface
- `lib/whisker/formats/ink/engine.lua` — InkEngine
- tinta state serialization format

### Tasks
1. Create `lib/whisker/formats/ink/state.lua` — InkState class
2. Implement IState methods: get, set, has, clear
3. Implement `snapshot()` for save state
4. Implement `restore(snapshot)` for load state
5. Wire InkState to InkEngine
6. Bridge variable access to tinta variablesState
7. Add IState contract tests for InkState

### Outputs
- `lib/whisker/formats/ink/state.lua` — InkState implementation (~110 lines)
- `spec/formats/ink/state_spec.lua` — State tests (~100 lines)

### Acceptance Criteria
- [ ] InkState passes IState interface compliance tests
- [ ] `state:get(key)` retrieves variable values
- [ ] `state:set(key, value)` modifies variables
- [ ] `state:snapshot()` returns serializable state
- [ ] `state:restore(snapshot)` restores saved state
- [ ] State changes emit 'state.changed' events
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~110
- Modified lines: ~25
- Test lines: ~100

### Implementation Notes
- tinta's state includes variablesState, callStack, outputStream
- Use tinta's story.state:save() and story.state:load() for serialization
- Variable access goes through tinta's variablesState["varName"]
- Visit counts available via VisitCountAtPathString
- State changes should be reflected in both tinta and whisker-core

---

## Stage 09: Event Bus Integration

### Prerequisites
- Phase 1 complete (all stages)
- Stage 08 completed (InkState)
- Event bus defined at `lib/whisker/kernel/events.lua`

### Objectives
- Connect Ink components to whisker-core event bus
- Emit events for all significant Ink operations
- Enable external systems to react to Ink story events
- Implement variable observers via event system

### Inputs
- `lib/whisker/kernel/events.lua` — Event bus
- `lib/whisker/formats/ink/engine.lua` — InkEngine
- `lib/whisker/formats/ink/state.lua` — InkState

### Tasks
1. Define Ink-specific event types and payloads
2. Wire story loading to emit 'ink.story.loaded'
3. Wire continuation to emit 'ink.story.continued'
4. Wire choice selection to emit 'ink.choice.made'
5. Bridge tinta variable observers to 'ink.variable.changed'
6. Wire external function calls to 'ink.external.called'
7. Add event integration tests

### Outputs
- `lib/whisker/formats/ink/events.lua` — Event definitions (~50 lines)
- `lib/whisker/formats/ink/engine.lua` — Updated with events (~30 lines added)
- `spec/formats/ink/events_spec.lua` — Event tests (~90 lines)

### Acceptance Criteria
- [ ] 'ink.story.loaded' fires when story loads
- [ ] 'ink.story.continued' fires after each continue
- [ ] 'ink.choice.made' fires on choice selection
- [ ] 'ink.variable.changed' fires on variable changes
- [ ] Event payloads include relevant context
- [ ] External observers can subscribe to events
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~80
- Modified lines: ~40
- Test lines: ~90

### Implementation Notes
- tinta supports ObserveVariable for variable change notifications
- Bridge these to whisker-core events for consistency
- Events should be emitted AFTER the operation completes
- Include story reference in event payloads for context
- External function calls in Ink can be observed via BindExternalFunction wrapper

---

## Stage 10: External Functions Bridge

### Prerequisites
- Phase 1 complete (all stages)
- Stage 09 completed (event integration)

### Objectives
- Enable binding Lua functions to Ink EXTERNAL declarations
- Provide safe function calling interface
- Support return values from external functions
- Handle function validation and error reporting

### Inputs
- `lib/whisker/formats/ink/engine.lua` — InkEngine
- tinta BindExternalFunction documentation

### Tasks
1. Create `lib/whisker/formats/ink/externals.lua` — External function manager
2. Implement `bind_function(name, fn)` for registering handlers
3. Implement `unbind_function(name)` for removal
4. Create wrapper ensuring proper argument passing (table format)
5. Handle return value propagation
6. Add validation for unbound required functions
7. Add comprehensive tests with various function signatures

### Outputs
- `lib/whisker/formats/ink/externals.lua` — External function manager (~90 lines)
- `spec/formats/ink/externals_spec.lua` — External function tests (~100 lines)
- `test/fixtures/ink/externals.json` — Test story with externals (~30 lines)

### Acceptance Criteria
- [ ] Can bind Lua function to Ink EXTERNAL
- [ ] Bound functions receive arguments correctly
- [ ] Return values propagate back to Ink
- [ ] Unbound required functions raise clear errors
- [ ] Fallback functions work when defined in Ink
- [ ] 'ink.external.called' event fires on invocation
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~120
- Modified lines: ~20
- Test lines: ~100

### Implementation Notes
- tinta passes arguments as a table: args[1], args[2], etc.
- Functions can be marked "look ahead safe" for optimization
- Fallback behavior controlled by Ink source
- Cannot bind multiple functions to same declaration
- Use pcall for safe function execution with error handling

---

## Stage 11: Flows Support

### Prerequisites
- Phase 1 complete (all stages)
- Stage 10 completed (external functions)

### Objectives
- Support Ink's parallel flow system
- Enable creating, switching, and removing flows
- Maintain separate callstacks per flow
- Share global variables across flows

### Inputs
- `lib/whisker/formats/ink/engine.lua` — InkEngine
- `lib/whisker/formats/ink/state.lua` — InkState
- tinta flow documentation

### Tasks
1. Create `lib/whisker/formats/ink/flows.lua` — Flow manager
2. Implement `create_flow(name)` for new parallel context
3. Implement `switch_flow(name)` for changing active flow
4. Implement `remove_flow(name)` for cleanup
5. Implement `get_current_flow()` and `list_flows()`
6. Handle flow state in save/restore
7. Add flow management tests

### Outputs
- `lib/whisker/formats/ink/flows.lua` — Flow manager (~80 lines)
- `spec/formats/ink/flows_spec.lua` — Flow tests (~90 lines)
- `test/fixtures/ink/flows.json` — Multi-flow test story (~40 lines)

### Acceptance Criteria
- [ ] Can create named flows
- [ ] Can switch between flows
- [ ] Each flow has independent callstack
- [ ] Global variables shared across flows
- [ ] DEFAULT_FLOW always exists
- [ ] Cannot remove DEFAULT_FLOW
- [ ] Flow state preserved in snapshots
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~120
- Modified lines: ~30
- Test lines: ~90

### Implementation Notes
- tinta provides SwitchFlow, RemoveFlow, currentFlowName
- New flows start without a position; must use ChoosePathString
- aliveFlowNames() lists all active flows
- currentFlowIsDefaultFlow() checks if in default
- Flow state must be included in save/restore

---

## Stage 12: Ink-to-Whisker Converter Foundation

### Prerequisites
- Phase 1 complete (all stages)
- Stage 11 completed (flows support)
- whisker-core Story/Passage/Choice structures

### Objectives
- Create converter infrastructure for Ink-to-Whisker transformation
- Implement knot-to-passage conversion
- Establish conversion pipeline architecture
- Handle basic content transformation

### Inputs
- `lib/whisker/formats/ink/story.lua` — InkStory
- `lib/whisker/core/story.lua` — whisker-core Story
- `lib/whisker/core/passage.lua` — whisker-core Passage

### Tasks
1. Create `lib/whisker/formats/ink/converter.lua` — Converter class
2. Implement conversion pipeline structure
3. Create knot-to-passage transformer
4. Handle basic text content conversion
5. Preserve knot metadata (tags)
6. Generate passage IDs from Ink paths
7. Add foundation tests

### Outputs
- `lib/whisker/formats/ink/converter.lua` — Converter foundation (~120 lines)
- `lib/whisker/formats/ink/transformers/init.lua` — Transformer registry (~30 lines)
- `lib/whisker/formats/ink/transformers/knot.lua` — Knot transformer (~60 lines)
- `spec/formats/ink/converter_spec.lua` — Converter tests (~100 lines)

### Acceptance Criteria
- [ ] Converter accepts InkStory, produces whisker Story
- [ ] Each knot becomes a Passage
- [ ] Passage IDs match Ink path format
- [ ] Basic text content preserved
- [ ] Tags attached to passages
- [ ] Pipeline extensible for additional transformers
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~210
- Modified lines: ~10
- Test lines: ~100

### Implementation Notes
- Conversion is static transformation, not runtime execution
- Use visitor pattern for extensible content handling
- Preserve original Ink paths for debugging/round-trip
- Content may include Ink-specific constructs to transform
- This stage handles knots only; stitches in next stage

---

## Stage 13: Stitch and Nested Content Conversion

### Prerequisites
- Phase 1 complete (all stages)
- Stage 12 completed (converter foundation)

### Objectives
- Add stitch-to-passage conversion
- Handle nested content within knots/stitches
- Preserve parent-child relationships
- Convert inline content and gathers

### Inputs
- `lib/whisker/formats/ink/converter.lua` — Converter
- `lib/whisker/formats/ink/transformers/knot.lua` — Knot transformer

### Tasks
1. Create `lib/whisker/formats/ink/transformers/stitch.lua` — Stitch transformer
2. Implement parent-child relationship tracking
3. Handle gather points (labeled and unlabeled)
4. Convert inline conditionals to passage content
5. Handle nested containers appropriately
6. Update converter to process full hierarchy
7. Add stitch and nested content tests

### Outputs
- `lib/whisker/formats/ink/transformers/stitch.lua` — Stitch transformer (~70 lines)
- `lib/whisker/formats/ink/transformers/gather.lua` — Gather transformer (~50 lines)
- `spec/formats/ink/stitch_converter_spec.lua` — Stitch tests (~90 lines)
- `test/fixtures/ink/stitches.json` — Stitch test story (~40 lines)

### Acceptance Criteria
- [ ] Stitches convert to passages with parent reference
- [ ] Passage IDs use dot notation (knot.stitch)
- [ ] Gathers create appropriate junction passages
- [ ] Nested content preserved in structure
- [ ] Parent-child navigation works
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~120
- Modified lines: ~40
- Test lines: ~90

### Implementation Notes
- Stitches appear as named children within knot containers
- Gathers are labeled positions that collect diverts
- Some nested content may need flattening for whisker structure
- Preserve Ink nesting depth for potential reconstruction
- Handle anonymous gathers with generated IDs

---

## Stage 14: Choice Conversion

### Prerequisites
- Phase 1 complete (all stages)
- Stage 13 completed (stitch conversion)

### Objectives
- Convert Ink choices to whisker-core Choice structures
- Preserve choice types (sticky, once-only)
- Handle choice conditions
- Convert choice content (text variations)

### Inputs
- `lib/whisker/formats/ink/converter.lua` — Converter
- `lib/whisker/core/choice.lua` — whisker-core Choice

### Tasks
1. Create `lib/whisker/formats/ink/transformers/choice.lua` — Choice transformer
2. Implement choice point detection in containers
3. Convert choice text (bracketed vs displayed)
4. Preserve sticky/once-only flags
5. Convert choice conditions to whisker format
6. Link choices to target passages
7. Add choice conversion tests

### Outputs
- `lib/whisker/formats/ink/transformers/choice.lua` — Choice transformer (~90 lines)
- `spec/formats/ink/choice_converter_spec.lua` — Choice conversion tests (~100 lines)

### Acceptance Criteria
- [ ] All choice types convert correctly
- [ ] Choice text extracted properly
- [ ] Sticky flag preserved
- [ ] Conditions converted to whisker Condition
- [ ] Choices link to correct target passages
- [ ] Fallback choices identified
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~90
- Modified lines: ~30
- Test lines: ~100

### Implementation Notes
- Ink choice points in JSON have specific structure
- Text may have "choice only" vs "output" portions
- Conditions appear as runtime logic before choice
- Target is the pathStringOnChoice property
- Handle choices within stitches correctly

---

## Stage 15: Variable and Logic Conversion

### Prerequisites
- Phase 1 complete (all stages)
- Stage 14 completed (choice conversion)

### Objectives
- Convert Ink variables to whisker-core Variable system
- Transform Ink logic to whisker conditions
- Handle variable declarations and defaults
- Convert assignment operations

### Inputs
- `lib/whisker/formats/ink/converter.lua` — Converter
- `lib/whisker/core/variable.lua` — whisker-core Variable

### Tasks
1. Create `lib/whisker/formats/ink/transformers/variable.lua` — Variable transformer
2. Extract global variable declarations
3. Convert variable types (int, float, string, bool, list)
4. Create `lib/whisker/formats/ink/transformers/logic.lua` — Logic transformer
5. Convert Ink operators to whisker equivalents
6. Handle comparison and logical operations
7. Add variable and logic tests

### Outputs
- `lib/whisker/formats/ink/transformers/variable.lua` — Variable transformer (~70 lines)
- `lib/whisker/formats/ink/transformers/logic.lua` — Logic transformer (~80 lines)
- `spec/formats/ink/variable_converter_spec.lua` — Variable tests (~90 lines)
- `test/fixtures/ink/variables.json` — Variable test story (~40 lines)

### Acceptance Criteria
- [ ] All variable types convert correctly
- [ ] Default values preserved
- [ ] Assignment operations convert
- [ ] Comparison operators map correctly
- [ ] Logical operators (and, or, not) convert
- [ ] Complex expressions handled
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~150
- Modified lines: ~30
- Test lines: ~90

### Implementation Notes
- Ink variables in JSON have type indicators
- List variables have special structure
- Operators in Ink JSON: +, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||, !
- Some Ink operations may not have direct whisker equivalents
- Document any lossy conversions

---

## Stage 16: Tunnel and Thread Conversion

### Prerequisites
- Phase 1 complete (all stages)
- Stage 15 completed (variable conversion)

### Objectives
- Convert Ink tunnels to whisker passage + call stack pattern
- Handle tunnel return points
- Convert threads to gathered content
- Preserve execution semantics

### Inputs
- `lib/whisker/formats/ink/converter.lua` — Converter
- Ink tunnel/thread documentation

### Tasks
1. Create `lib/whisker/formats/ink/transformers/tunnel.lua` — Tunnel transformer
2. Identify tunnel entry points
3. Create return address tracking structure
4. Create `lib/whisker/formats/ink/transformers/thread.lua` — Thread transformer
5. Convert thread gathering to content aggregation
6. Handle thread join points
7. Add tunnel and thread tests

### Outputs
- `lib/whisker/formats/ink/transformers/tunnel.lua` — Tunnel transformer (~70 lines)
- `lib/whisker/formats/ink/transformers/thread.lua` — Thread transformer (~60 lines)
- `spec/formats/ink/tunnel_converter_spec.lua` — Tunnel/thread tests (~90 lines)
- `test/fixtures/ink/tunnels.json` — Tunnel test story (~40 lines)

### Acceptance Criteria
- [ ] Tunnel passages marked with special type
- [ ] Return points tracked in passage metadata
- [ ] Thread content properly gathered
- [ ] Execution order preserved
- [ ] Complex tunnel nesting handled
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~130
- Modified lines: ~30
- Test lines: ~90

### Implementation Notes
- Tunnels in Ink JSON use pushpop commands
- Return address stored on callstack
- Threads use fork/join pattern in containers
- Some thread patterns may be complex to convert statically
- Consider runtime-only handling for complex cases

---

## Stage 17: Conversion Validation and Error Reporting

### Prerequisites
- Phase 1 complete (all stages)
- Stage 16 completed (tunnel conversion)

### Objectives
- Validate converted stories for completeness
- Generate helpful error messages for conversion issues
- Report unsupported features clearly
- Create conversion report

### Inputs
- `lib/whisker/formats/ink/converter.lua` — Converter
- All transformer modules

### Tasks
1. Create `lib/whisker/formats/ink/validator.lua` — Conversion validator
2. Implement passage reference validation
3. Implement variable reference validation
4. Check for orphaned content
5. Create conversion report structure
6. Implement warning system for partial support
7. Add validation tests

### Outputs
- `lib/whisker/formats/ink/validator.lua` — Validator (~100 lines)
- `lib/whisker/formats/ink/report.lua` — Report generator (~60 lines)
- `spec/formats/ink/validator_spec.lua` — Validation tests (~80 lines)

### Acceptance Criteria
- [ ] All passage links validated
- [ ] All variable references validated
- [ ] Orphaned content detected
- [ ] Clear error messages produced
- [ ] Warnings for partial feature support
- [ ] Conversion report includes statistics
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~160
- Modified lines: ~20
- Test lines: ~80

### Implementation Notes
- Validation runs after conversion completes
- Check that all divert targets exist
- Check that all variables are declared
- Report includes: passages, choices, variables, errors, warnings
- Consider severity levels: error, warning, info

---

## Stage 18: Whisker-to-Ink Exporter Foundation

### Prerequisites
- Phase 1 complete (all stages)
- Stage 17 completed (conversion validation)

### Objectives
- Create exporter infrastructure for Whisker-to-Ink transformation
- Implement passage-to-knot generation
- Establish export pipeline architecture
- Generate valid ink.json structure

### Inputs
- `lib/whisker/core/story.lua` — whisker-core Story
- Ink JSON format specification

### Tasks
1. Create `lib/whisker/formats/ink/exporter.lua` — Exporter class
2. Implement export pipeline structure
3. Create passage-to-container generator
4. Generate root container structure
5. Set appropriate inkVersion
6. Handle basic text content export
7. Add foundation tests

### Outputs
- `lib/whisker/formats/ink/exporter.lua` — Exporter foundation (~130 lines)
- `lib/whisker/formats/ink/generators/init.lua` — Generator registry (~30 lines)
- `lib/whisker/formats/ink/generators/passage.lua` — Passage generator (~70 lines)
- `spec/formats/ink/exporter_spec.lua` — Exporter tests (~100 lines)

### Acceptance Criteria
- [ ] Exporter accepts whisker Story, produces ink.json
- [ ] Generated JSON has valid inkVersion
- [ ] Root container properly structured
- [ ] Passages become named containers
- [ ] Basic text content exported correctly
- [ ] Generated JSON loadable by tinta
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~230
- Modified lines: ~10
- Test lines: ~100

### Implementation Notes
- Target inkVersion 20 for broad compatibility
- Use appropriate control commands (ev, /ev, str, etc.)
- Text content needs `^` prefix in JSON
- Container structure: array + optional named dict
- Validate output by loading with tinta

---

## Stage 19: Choice and Navigation Export

### Prerequisites
- Phase 1 complete (all stages)
- Stage 18 completed (exporter foundation)

### Objectives
- Export whisker choices to Ink choice points
- Generate divert commands for navigation
- Handle choice conditions in export
- Preserve choice flags (sticky, once-only)

### Inputs
- `lib/whisker/formats/ink/exporter.lua` — Exporter
- `lib/whisker/core/choice.lua` — whisker-core Choice

### Tasks
1. Create `lib/whisker/formats/ink/generators/choice.lua` — Choice generator
2. Generate choice point structures
3. Create divert commands for targets
4. Export choice conditions as Ink conditionals
5. Set appropriate choice flags
6. Handle fallback choice generation
7. Add choice export tests

### Outputs
- `lib/whisker/formats/ink/generators/choice.lua` — Choice generator (~90 lines)
- `lib/whisker/formats/ink/generators/divert.lua` — Divert generator (~50 lines)
- `spec/formats/ink/choice_exporter_spec.lua` — Choice export tests (~100 lines)

### Acceptance Criteria
- [ ] All choice types export correctly
- [ ] Divert targets resolve properly
- [ ] Conditions export as Ink logic
- [ ] Sticky/once-only flags set correctly
- [ ] Choice text properly formatted
- [ ] Generated choices work in tinta
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~140
- Modified lines: ~30
- Test lines: ~100

### Implementation Notes
- Choice points in Ink JSON have specific structure
- Diverts use "->" notation in path
- Conditions become evaluation mode content
- Test by running exported stories in tinta

---

## Stage 20: Variable and Logic Export

### Prerequisites
- Phase 1 complete (all stages)
- Stage 19 completed (choice export)

### Objectives
- Export whisker variables as Ink VAR declarations
- Generate Ink logic from whisker conditions
- Handle variable assignments
- Support all variable types

### Inputs
- `lib/whisker/formats/ink/exporter.lua` — Exporter
- `lib/whisker/core/variable.lua` — whisker-core Variable

### Tasks
1. Create `lib/whisker/formats/ink/generators/variable.lua` — Variable generator
2. Generate VAR declarations for globals
3. Create `lib/whisker/formats/ink/generators/logic.lua` — Logic generator
4. Generate evaluation mode content for expressions
5. Export assignment operations
6. Handle type conversions
7. Add variable export tests

### Outputs
- `lib/whisker/formats/ink/generators/variable.lua` — Variable generator (~70 lines)
- `lib/whisker/formats/ink/generators/logic.lua` — Logic generator (~80 lines)
- `spec/formats/ink/variable_exporter_spec.lua` — Variable export tests (~90 lines)

### Acceptance Criteria
- [ ] All variable types export correctly
- [ ] Default values preserved
- [ ] Assignments generate proper commands
- [ ] Conditions export as Ink logic
- [ ] Operators map correctly
- [ ] Variables work in exported story
- [ ] All tests pass with 80%+ coverage

### Estimated Scope
- New lines: ~150
- Modified lines: ~25
- Test lines: ~90

### Implementation Notes
- Variables appear in listDefs section of root
- Evaluation mode wraps logic operations
- Operators need mapping to Ink equivalents
- Test variable behavior in exported stories

---

## Stage 21: Round-Trip Integrity Verification

### Prerequisites
- Phase 1 complete (all stages)
- Stage 20 completed (variable export)

### Objectives
- Verify Ink → Whisker → Ink produces equivalent stories
- Create comprehensive round-trip test suite
- Document any lossy conversions
- Establish conversion fidelity metrics

### Inputs
- `lib/whisker/formats/ink/converter.lua` — Converter
- `lib/whisker/formats/ink/exporter.lua` — Exporter
- Various test stories

### Tasks
1. Create `spec/formats/ink/roundtrip_spec.lua` — Round-trip tests
2. Implement story comparison utilities
3. Test with minimal stories
4. Test with complex stories
5. Identify and document lossy conversions
6. Create fidelity report generator
7. Add integration tests with real stories

### Outputs
- `spec/formats/ink/roundtrip_spec.lua` — Round-trip tests (~150 lines)
- `lib/whisker/formats/ink/compare.lua` — Comparison utilities (~80 lines)
- `docs/ink-conversion-fidelity.md` — Fidelity documentation (~100 lines)

### Acceptance Criteria
- [ ] Simple stories round-trip perfectly
- [ ] Complex stories maintain functionality
- [ ] Any data loss documented
- [ ] Comparison utilities work correctly
- [ ] Fidelity metrics captured
- [ ] All round-trip tests pass

### Estimated Scope
- New lines: ~230
- Modified lines: ~20
- Test lines: ~150

### Implementation Notes
- Compare structure, not byte-for-byte equality
- Some Ink features may not have perfect equivalents
- Focus on functional equivalence (same playthrough)
- Document which features lose fidelity
- Consider "whisker-origin" vs "ink-origin" story handling

---

## Stage 22: Integration Testing and Documentation

### Prerequisites
- Phase 1 complete (all stages)
- Stages 01-21 completed

### Objectives
- Test with real-world Ink projects
- Complete integration documentation
- Create compatibility matrix
- Prepare for Phase 3

### Inputs
- All Ink integration components
- Real-world Ink stories (The Intercept, community projects)

### Tasks
1. Download and test with The Intercept
2. Test with additional community Ink projects
3. Create `docs/ink-integration-guide.md`
4. Create compatibility matrix document
5. Document known limitations
6. Add integration test suite
7. Final review and cleanup

### Outputs
- `spec/formats/ink/integration_spec.lua` — Integration tests (~120 lines)
- `docs/ink-integration-guide.md` — User documentation (~200 lines)
- `docs/ink-compatibility-matrix.md` — Feature compatibility (~80 lines)
- `test/fixtures/ink/real_world/` — Real-world test stories

### Acceptance Criteria
- [ ] The Intercept runs correctly
- [ ] Additional test stories pass
- [ ] Integration guide complete
- [ ] Compatibility matrix accurate
- [ ] Known limitations documented
- [ ] All integration tests pass
- [ ] Ready for Phase 3

### Estimated Scope
- New lines: ~400 (mostly documentation)
- Modified lines: ~30
- Test lines: ~120

### Implementation Notes
- The Intercept available at https://github.com/inkle/the-intercept
- Focus on functionality over edge cases
- Document workarounds for unsupported features
- Compatibility matrix should list: feature, support level, notes

---

## Phase 2 Completion Checklist

- [ ] All stages completed (01-22)
- [ ] tinta fully integrated and adapted
- [ ] Ink stories load and run correctly
- [ ] Ink-to-Whisker conversion functional
- [ ] Whisker-to-Ink export functional
- [ ] Compliance tests passing
- [ ] Integration documented
- [ ] Ready for Phase 3 (Whisker Script Language)

---

## Appendix A: File Manifest

| File Path | Stage | Description |
|-----------|-------|-------------|
| `docs/tinta-analysis.md` | 01 | tinta architecture documentation |
| `docs/ink-whisker-mapping.md` | 01 | Concept mapping reference |
| `lib/whisker/vendor/tinta/init.lua` | 02 | Vendored tinta entry point |
| `lib/whisker/vendor/tinta/engine/` | 02 | Vendored tinta engine |
| `lib/whisker/vendor/tinta/values/` | 02 | Vendored tinta values |
| `lib/whisker/formats/ink/init.lua` | 04 | Ink format module entry |
| `lib/whisker/formats/ink/json_loader.lua` | 03 | Native JSON loading |
| `lib/whisker/formats/ink/format.lua` | 04 | IInkFormat implementation |
| `lib/whisker/formats/ink/story.lua` | 05 | InkStory wrapper |
| `lib/whisker/formats/ink/engine.lua` | 06-07 | InkEngine implementation |
| `lib/whisker/formats/ink/state.lua` | 08 | InkState implementation |
| `lib/whisker/formats/ink/events.lua` | 09 | Event definitions |
| `lib/whisker/formats/ink/externals.lua` | 10 | External functions |
| `lib/whisker/formats/ink/flows.lua` | 11 | Flow management |
| `lib/whisker/formats/ink/converter.lua` | 12 | Ink-to-Whisker converter |
| `lib/whisker/formats/ink/transformers/` | 12-16 | Content transformers |
| `lib/whisker/formats/ink/validator.lua` | 17 | Conversion validator |
| `lib/whisker/formats/ink/exporter.lua` | 18 | Whisker-to-Ink exporter |
| `lib/whisker/formats/ink/generators/` | 18-20 | Content generators |
| `lib/whisker/formats/ink/compare.lua` | 21 | Story comparison |
| `docs/ink-integration-guide.md` | 22 | User documentation |
| `docs/ink-compatibility-matrix.md` | 22 | Feature support |

---

## Appendix B: Ink Compatibility Matrix

| Ink Feature | Support Level | Notes |
|-------------|---------------|-------|
| Knots | Full | Direct passage mapping |
| Stitches | Full | Nested passage structure |
| Choices (*) | Full | Once-only default |
| Sticky choices (+) | Full | Sticky flag preserved |
| Diverts (->) | Full | Passage navigation |
| DONE | Full | End current section |
| END | Full | End story |
| VAR | Full | Global variables |
| temp | Full | Temporary variables |
| Conditionals {} | Full | Expression conversion |
| Tags (#) | Full | Metadata attachment |
| Tunnels (->->) | Full | Call stack tracking |
| Threads (<-) | Partial | Basic gathering supported |
| Flows | Full | Parallel execution |
| External functions | Full | Lua binding |
| Variable observers | Full | Event-based |
| Save/Load | Full | State serialization |
| Lists | Partial | Basic support |
| Visit counts | Full | State tracking |
| Glue (<>) | Full | Whitespace control |
| Sequences {} | Full | Variation handling |

---

## Appendix C: tinta Modifications

All modifications to vendored tinta code are tracked here:

| File | Change | Reason |
|------|--------|--------|
| `init.lua` | Created | Entry point for require() |
| `engine/*.lua` | import→require | Standard Lua module loading |
| `values/*.lua` | import→require | Standard Lua module loading |

Original tinta source: https://github.com/smwhr/tinta
Version vendored: (commit hash to be filled during Stage 02)
License: MIT
