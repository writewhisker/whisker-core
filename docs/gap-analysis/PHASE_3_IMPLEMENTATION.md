# Phase 3: Whisker Script Language — Implementation Stages

## Document Overview

This document provides detailed implementation stages for Phase 3 of the whisker-core project. Phase 3 creates Whisker Script—a domain-specific language (DSL) designed for authoring interactive fiction. The language includes a complete lexer, parser, AST representation, semantic analyzer, code generator, and comprehensive error reporting system.

**Total Stages:** 25  
**Estimated Duration:** 8-10 weeks  
**Code Volume:** ~3,500-5,000 lines production code + equivalent test code

---

## Phase Context

### Phase Overview

Phase 3 implements the Whisker Script language—a domain-specific language designed specifically for authoring interactive fiction. Unlike general-purpose programming languages, Whisker Script prioritizes narrative flow, readability by writers who may not have programming backgrounds, and minimal syntactic noise that would interrupt the creative process.

Interactive fiction authoring presents unique challenges. Writers need to express branching narratives, conditional content, and state management while maintaining focus on the story itself. Existing tools each have limitations: Twine scatters logic across visual passages making version control difficult; Ink's terse syntax requires a steep learning curve; Twee lacks proper conditionals and variables; custom JSON provides no authoring affordances; Yarn Spinner ties authors to the Unity ecosystem. Whisker Script addresses these limitations through a purpose-built syntax optimized for narrative authoring.

The language design follows six core principles that inform every implementation decision:

**Readability over brevity.** Writers spend more time reading and editing existing content than writing new material. The syntax optimizes for comprehension rather than keystroke minimization. Keywords are chosen for clarity, and structure is visually apparent through consistent formatting patterns.

**Progressive complexity.** Simple stories should require only simple syntax. A linear narrative with basic choices needs no variables, conditionals, or functions. As stories grow more complex, authors can introduce these features incrementally. The language never forces complexity onto simple use cases.

**Explicit structure.** Visual hierarchy through indentation and keywords makes story structure immediately apparent. There is no hidden state that affects behavior unexpectedly. Authors can understand what a passage does by reading it, without needing to trace execution paths through the entire story.

**Error-friendly design.** Error messages explain the narrative intent, not just syntax violations. When something goes wrong, the message should help writers understand what they meant to express and how to express it correctly. Suggestions for fixes are provided whenever possible.

**Round-trip capability.** Parsing source code then generating source code from the resulting AST should yield semantically identical results. This enables tooling like formatters, refactoring tools, and IDE features that modify code programmatically.

**Familiar patterns.** Where Ink has established successful syntax patterns, Whisker Script adopts them. Innovation occurs only where Ink's approach creates genuine usability problems for writers.

### Dependencies from Prior Phases

Phase 3 builds upon the complete Phase 1 (Foundation & Modularity Architecture) and Phase 2 (Ink Integration) infrastructure. Understanding these dependencies is crucial for proper implementation.

**From Phase 1 — Foundation & Modularity:**

The microkernel architecture provides the foundation for all modules. The dynamic module loader (`lib/whisker/kernel/loader.lua`) handles loading the script module and its subcomponents. The dependency injection container (`whisker.container`) manages component wiring throughout the compiler pipeline. Each compiler stage registers with the container and declares its dependencies explicitly.

The event bus (`whisker.events`) enables decoupled module communication. The script compiler emits events at each pipeline stage transition, enabling observability, extension, and debugging without tight coupling between modules.

Interface contracts from Phase 1 define the boundaries the script module must respect: `IFormat` for the format handler facade, `IState` for accessing story state, `IEngine` for runtime integration, `ISerializer` for persistence, and `IConditionEvaluator` for expression evaluation. The script module implements `IFormat` to integrate as a first-class format handler.

Module lifecycle management (init, start, stop, destroy) applies to the script compiler module. Proper initialization and cleanup ensures the compiler can be loaded and unloaded dynamically.

The logging and diagnostics infrastructure from Phase 1 provides the foundation for error reporting. The script module's error reporter integrates with this existing system.

Test infrastructure including the mock factory, contract tests, and fixture system provides patterns the script module testing must follow. The CI/CD pipeline with multi-version Lua testing ensures the compiler works across supported Lua versions.

**From Phase 2 — Ink Integration:**

The integrated tinta library demonstrates how an external parser/runtime integrates with whisker-core. The `IInkFormat` interface and implementation provide a pattern for the `IWhiskerScriptFormat` implementation.

Bidirectional conversion patterns (Ink JSON ↔ Whisker internal format) inform how the script module's code generator produces Story objects. The deep understanding of narrative flow constructs—knots, stitches, choices, diverts, tunnels, threads—transfers directly to Whisker Script's equivalent constructs.

Test fixtures with real Ink stories provide comparison points. Some test cases can verify that equivalent stories in Ink and Whisker Script produce identical runtime behavior.

The format handler pattern (`lib/whisker/formats/ink/`) provides the template for structuring the script module's public API.

### Compiler Architecture

Whisker Script uses a traditional multi-phase compiler pipeline. Each phase transforms its input into a representation suitable for the next phase, with errors accumulated rather than thrown immediately.

```
┌─────────────┐    ┌─────────┐    ┌────────┐    ┌───────────┐    ┌───────────┐
│ Source Text │───▶│  Lexer  │───▶│ Parser │───▶│ Semantic  │───▶│   Code    │
│   (.wsk)    │    │         │    │        │    │ Analyzer  │    │ Generator │
└─────────────┘    └─────────┘    └────────┘    └───────────┘    └───────────┘
       │                │              │              │                │
       │                ▼              ▼              ▼                ▼
       │           [Tokens]         [AST]      [Annotated       [Whisker IR]
       │                              │            AST]              │
       └──────────────────────────────┴──────────────┴───────────────┘
                                      │
                                      ▼
                              [Source Maps]
                              [Diagnostics]
```

**Lexer (Tokenizer):** Converts source text into a stream of tokens with source positions. The lexer handles whitespace significance, indentation tracking, comments, and produces error tokens for invalid input rather than throwing exceptions. Output is a `TokenStream` that supports lookahead and backtracking.

**Parser:** Builds an Abstract Syntax Tree (AST) that captures the hierarchical structure of the source. The parser implements error recovery to continue after syntax errors, enabling multiple error reporting in a single pass. The AST preserves source positions for all nodes.

**Semantic Analyzer:** Validates the AST for semantic correctness. This phase builds symbol tables, resolves references (passages, variables, functions), performs type checking where applicable, and annotates the AST with resolved information. Semantic errors and warnings are accumulated.

**Code Generator:** Transforms the annotated AST into Whisker's internal representation—Story, Passage, and Choice objects. The generator also produces source maps that enable debugging and error reporting to reference original source positions.

Each phase produces diagnostics that include source positions, error codes, human-readable messages, and when possible, suggestions for fixes. Diagnostics are categorized as errors (prevent compilation), warnings (compilation succeeds with caveats), or hints (stylistic suggestions).

### Module Structure

The script module organizes into submodules by compiler phase:

```
lib/whisker/script/
├── init.lua                 # Module entry point, public API
├── lexer/
│   ├── init.lua            # Lexer public interface
│   ├── tokens.lua          # Token type definitions
│   ├── scanner.lua         # Character-level scanning
│   └── rules.lua           # Tokenization rules
├── parser/
│   ├── init.lua            # Parser public interface
│   ├── grammar.lua         # Grammar rule implementations
│   ├── ast.lua             # AST node definitions
│   └── recovery.lua        # Error recovery strategies
├── semantic/
│   ├── init.lua            # Semantic analyzer interface
│   ├── symbols.lua         # Symbol table implementation
│   ├── resolver.lua        # Reference resolution
│   └── validator.lua       # Semantic validation rules
├── generator/
│   ├── init.lua            # Code generator interface
│   ├── emitter.lua         # IR emission logic
│   └── sourcemap.lua       # Source map generation
├── errors/
│   ├── init.lua            # Error system interface
│   ├── codes.lua           # Error code definitions
│   ├── messages.lua        # Human-readable messages
│   └── reporter.lua        # Error formatting and output
└── visitor.lua             # AST visitor base class
```

Each submodule exposes a clean public interface through its `init.lua` while keeping implementation details private. The top-level `init.lua` aggregates these into the public API.

### Interface Definitions

The script module implements and uses these interfaces:

```lua
-- IScriptCompiler: Main compiler interface
IScriptCompiler = {
  compile = function(self, source, options) end,    -- Returns CompileResult
  parse_only = function(self, source) end,          -- Returns AST without codegen
  validate = function(self, source) end,            -- Returns validation errors only
  get_tokens = function(self, source) end,          -- Returns token stream (for tooling)
}

-- ILexer: Tokenizer interface
ILexer = {
  tokenize = function(self, source) end,            -- Returns TokenStream
  reset = function(self) end,                       -- Reset internal state
}

-- IParser: Parser interface
IParser = {
  parse = function(self, tokens) end,               -- Returns AST
  set_error_handler = function(self, handler) end,  -- Custom error handling
}

-- ISemanticAnalyzer: Semantic analysis interface
ISemanticAnalyzer = {
  analyze = function(self, ast) end,                -- Returns AnnotatedAST
  get_symbols = function(self) end,                 -- Returns SymbolTable
  get_diagnostics = function(self) end,             -- Returns Diagnostic[]
}

-- ICodeGenerator: Code generation interface
ICodeGenerator = {
  generate = function(self, ast) end,               -- Returns Story IR
  generate_with_sourcemap = function(self, ast) end, -- Returns {ir, sourcemap}
}

-- IErrorReporter: Error reporting interface
IErrorReporter = {
  report = function(self, error) end,               -- Report single error
  report_all = function(self, errors) end,          -- Report multiple errors
  format = function(self, error, source) end,       -- Format error with context
  set_format = function(self, format) end,          -- "text", "json", "annotated"
}
```

These interfaces enable testing each compiler phase in isolation and swapping implementations for different use cases (e.g., a streaming lexer for large files, a lenient parser for IDE integration).

### Error Philosophy

Error messages are critical for writer adoption. Writers are not necessarily programmers; error messages that assume programming knowledge will frustrate them. Every error should communicate clearly using narrative terminology.

Each error message must accomplish four things:

**State what went wrong.** Use clear, jargon-free language. "Undefined passage reference" not "unresolved symbol in divert expression."

**State where it happened.** Include line number, column number, and a snippet of the relevant source code with the problematic portion highlighted.

**Suggest how to fix it.** Provide actionable suggestions when possible. If a passage name is misspelled, suggest the likely correct name. If syntax is malformed, show the correct pattern.

**Use narrative terminology.** Writers think in terms of passages, choices, and story flow—not functions, branches, and control flow. Error messages should reflect this mental model.

Example error output demonstrating these principles:

```
Error [WSK0040]: Undefined passage reference

  --> story.wsk:15:6
   |
14 | + [Go north]
15 |   -> NorthRoom
   |      ^^^^^^^^^ This passage doesn't exist
   |
   = help: Did you mean 'NorthChamber'? (defined at line 42)
   = help: Or declare a new passage with ':: NorthRoom'
```

The error code enables programmatic handling. The source snippet provides context. The suggestions guide the writer toward resolution.

### Integration with whisker-core

The script module integrates as an `IFormat` implementation, enabling Whisker Script to be used anywhere other formats are supported:

```lua
-- Registration with container
whisker.container:register("format.whisker", WhiskerScriptFormat, {
  implements = "IFormat",
  capability = "format.whisker",
  depends = { "compiler.whisker" }
})

-- Usage through standard IFormat interface
local format = whisker.formats:get("whisker")
local story = format:import(whisker_script_source)
local source = format:export(story)  -- Round-trip back to .wsk
```

This integration means any tool that works with whisker-core formats automatically supports Whisker Script without modification.

### Event Integration

The compiler emits events for observability and extension. These events enable debugging tools, profilers, and plugins to observe compilation without modifying compiler code:

```lua
-- Events emitted during compilation
whisker.events:emit("script:compile:start", { source = source })
whisker.events:emit("script:tokenize:complete", { tokens = tokens })
whisker.events:emit("script:parse:complete", { ast = ast })
whisker.events:emit("script:analyze:complete", { ast = annotated_ast })
whisker.events:emit("script:generate:complete", { story = story })
whisker.events:emit("script:compile:complete", { story = story, diagnostics = diagnostics })
whisker.events:emit("script:compile:error", { errors = errors })
```

Plugins can subscribe to these events to implement features like compilation progress bars, error aggregation, or custom validation rules.

---

## Stage Groups Overview

The 25 implementation stages organize into eight logical groups:

### Group A: Infrastructure & Token Foundation (Stages 01-04)
Foundation work establishing the module structure, interfaces, token types, source position tracking, and basic character-level scanning. These stages create the infrastructure upon which the entire compiler is built.

### Group B: Lexer Implementation (Stages 05-08)
Complete lexer implementation including the main tokenization loop, structural token recognition (passage declarations, choices, diverts), expression token recognition (operators, literals), and comprehensive error handling with recovery.

### Group C: AST & Parser Foundation (Stages 09-12)
AST node definitions, visitor infrastructure for tree traversal, parser infrastructure with error recovery mechanisms, and basic grammar rules for script-level and passage-level structure.

### Group D: Parser — Core Constructs (Stages 13-16)
Parsing of core narrative constructs: passages with metadata, choices with conditions and diverts, narrative text with inline expressions, and expression parsing using precedence climbing.

### Group E: Parser — Advanced Features (Stages 17-19)
Advanced parsing features including conditional blocks with elif/else chains, variable assignment with compound operators, and tunnels, threads, and include directives.

### Group F: Semantic Analysis (Stages 20-21)
Symbol table management with scope handling, and reference resolution with semantic validation. These stages catch errors that syntax-correct code can still contain.

### Group G: Code Generation & Integration (Stages 22-24)
Code generator implementation producing Story IR, advanced code generation for complex constructs with source map support, and the IFormat facade that integrates with whisker-core.

### Group H: Polish & Documentation (Stage 25)
Final polish on error messages, complete language specification documentation, and tutorials for writers adopting Whisker Script.

---

## Stage Definitions

---

## Stage 01: Script Module Structure and Interfaces

### Prerequisites
- Phase 1 complete: Microkernel, container, events, interfaces infrastructure
- Phase 2 complete: Format handler patterns established
- Understanding of whisker-core module conventions

### Objectives
Establish the script module directory structure, define all compiler interfaces, and create the module entry point that registers with the whisker-core container. This stage creates the skeleton that all subsequent stages will populate.

### Inputs
- `lib/whisker/interfaces/init.lua` (existing interface patterns)
- `lib/whisker/formats/ink/init.lua` (format handler pattern reference)
- `lib/whisker/kernel/loader.lua` (module loading patterns)

### Tasks
1. Create directory structure for `lib/whisker/script/` with all subdirectories:
   - `lexer/`, `parser/`, `semantic/`, `generator/`, `errors/`
2. Define `IScriptCompiler` interface with all method signatures:
   - `compile(source, options)` → CompileResult
   - `parse_only(source)` → AST
   - `validate(source)` → Diagnostic[]
   - `get_tokens(source)` → TokenStream
3. Define `ILexer` interface:
   - `tokenize(source)` → TokenStream
   - `reset()` → void
4. Define `IParser` interface:
   - `parse(tokens)` → AST
   - `set_error_handler(handler)` → void
5. Define `ISemanticAnalyzer` interface:
   - `analyze(ast)` → AnnotatedAST
   - `get_symbols()` → SymbolTable
   - `get_diagnostics()` → Diagnostic[]
6. Define `ICodeGenerator` interface:
   - `generate(ast)` → Story
   - `generate_with_sourcemap(ast)` → {story, sourcemap}
7. Define `IErrorReporter` interface:
   - `report(error)`, `report_all(errors)`, `format(error, source)`, `set_format(format)`
8. Create `lib/whisker/script/init.lua` with:
   - Module metadata (name, version, dependencies)
   - Container registration for `format.whisker`
   - Public API stub methods that throw "not implemented"
9. Create placeholder `init.lua` files for each subdirectory
10. Write contract test skeletons for each interface

### Outputs
- `lib/whisker/script/init.lua` (~80 lines)
- `lib/whisker/script/interfaces.lua` (~100 lines)
- `lib/whisker/script/lexer/init.lua` (stub, ~20 lines)
- `lib/whisker/script/parser/init.lua` (stub, ~20 lines)
- `lib/whisker/script/semantic/init.lua` (stub, ~20 lines)
- `lib/whisker/script/generator/init.lua` (stub, ~20 lines)
- `lib/whisker/script/errors/init.lua` (stub, ~20 lines)
- `tests/contracts/script/compiler_contract.lua` (~60 lines)
- `tests/contracts/script/lexer_contract.lua` (~40 lines)
- `tests/contracts/script/parser_contract.lua` (~40 lines)

### Acceptance Criteria
- [ ] `require("whisker.script")` loads without error
- [ ] Module registers with container as `format.whisker`
- [ ] All interface method stubs return "not implemented" error
- [ ] Directory structure matches specification
- [ ] Contract test files exist and are skipped (pending implementation)
- [ ] Module metadata includes name, version, dependencies list

### Estimated Scope
- **Production code:** 100-120 lines
- **Test code:** 80-100 lines
- **Estimated time:** 0.5-1 day

### Implementation Notes
**Pattern: Module Metadata**
```lua
local M = {
  _NAME = "whisker.script",
  _VERSION = "0.1.0",
  _DESCRIPTION = "Whisker Script language compiler",
  _DEPENDENCIES = { "whisker.kernel", "whisker.core" }
}
```

**Pattern: Container Registration**
```lua
function M.init(container)
  container:register("format.whisker", M, {
    implements = "IFormat",
    capability = "format.whisker"
  })
  container:register("compiler.whisker", M, {
    implements = "IScriptCompiler"
  })
end
```

**Pattern: Interface Definition**
Define interfaces as tables with function signatures documented:
```lua
local ILexer = {
  -- tokenize(source: string) -> TokenStream
  -- Converts source text to token stream
  tokenize = function(self, source) end,
  
  -- reset() -> void
  -- Resets lexer state for reuse
  reset = function(self) end,
}
```

---

## Stage 02: Token Type Definitions

### Prerequisites
- Stage 01: Script module structure complete

### Objectives
Define all token types used by the Whisker Script lexer. This includes structural tokens (passage declarations, choices, diverts), expression tokens (operators, literals), and synthetic tokens (indentation, EOF). Each token type is documented with its pattern, examples, and contextual notes.

### Inputs
- `lib/whisker/script/init.lua` (module structure)
- Whisker Script syntax reference (from prompt context)
- Token reference appendix (from prompt context)

### Tasks
1. Create `lib/whisker/script/lexer/tokens.lua` with:
   - `TokenType` enum table with all token type constants
   - `Token` class/factory for creating token instances
   - Token classification helpers (is_operator, is_keyword, is_literal)
2. Define structural token types:
   - `PASSAGE_DECL` (::), `CHOICE` (+), `DIVERT` (->), `TUNNEL` (->->)
   - `THREAD` (<-), `ASSIGN` (~), `METADATA` (@@), `INCLUDE` (>>)
3. Define delimiter token types:
   - `LBRACE`, `RBRACE`, `LBRACKET`, `RBRACKET`, `LPAREN`, `RPAREN`
   - `COLON`, `PIPE`, `COMMA`, `DASH`
4. Define operator token types:
   - Assignment: `EQ`, `PLUS_EQ`, `MINUS_EQ`, `STAR_EQ`, `SLASH_EQ`
   - Comparison: `EQ_EQ`, `BANG_EQ`, `LT`, `GT`, `LT_EQ`, `GT_EQ`
   - Arithmetic: `PLUS`, `MINUS`, `STAR`, `SLASH`, `PERCENT`
   - Logical: `AND`, `OR`, `NOT`
5. Define literal and identifier token types:
   - `TRUE`, `FALSE`, `NULL`
   - `IDENTIFIER`, `NUMBER`, `STRING`, `VARIABLE` ($identifier)
   - `TEXT` (narrative content)
6. Define keyword token types:
   - `ELSE`, `INCLUDE_KW`, `IMPORT_KW`, `AS`
7. Define synthetic token types:
   - `NEWLINE`, `INDENT`, `DEDENT`, `COMMENT`, `EOF`, `ERROR`
8. Implement Token factory:
   - `Token.new(type, lexeme, literal, position)`
   - Token should store: type, lexeme (source text), literal (parsed value), position
9. Create keyword lookup table for efficient recognition
10. Write unit tests for token creation and classification

### Outputs
- `lib/whisker/script/lexer/tokens.lua` (~150 lines)
- `tests/unit/script/lexer/tokens_spec.lua` (~100 lines)

### Acceptance Criteria
- [ ] All 45+ token types defined as constants
- [ ] `Token.new()` creates valid token instances
- [ ] Token instances have type, lexeme, literal, position fields
- [ ] `is_keyword(lexeme)` returns correct TokenType or nil
- [ ] `is_operator(type)` correctly identifies operator tokens
- [ ] `is_literal(type)` correctly identifies literal tokens
- [ ] Unit tests pass for all token operations

### Estimated Scope
- **Production code:** 130-160 lines
- **Test code:** 80-120 lines
- **Estimated time:** 1 day

### Implementation Notes
**Pattern: Enum-like Table**
```lua
local TokenType = {
  -- Structural
  PASSAGE_DECL = "PASSAGE_DECL",
  CHOICE = "CHOICE",
  DIVERT = "DIVERT",
  -- ...
}

-- Freeze the table to catch typos
setmetatable(TokenType, {
  __index = function(_, key)
    error("Unknown token type: " .. tostring(key))
  end,
  __newindex = function()
    error("Cannot modify TokenType enum")
  end
})
```

**Pattern: Token Factory**
```lua
local Token = {}
Token.__index = Token

function Token.new(type, lexeme, literal, position)
  assert(TokenType[type], "Invalid token type: " .. tostring(type))
  return setmetatable({
    type = type,
    lexeme = lexeme,
    literal = literal,
    pos = position
  }, Token)
end

function Token:__tostring()
  return string.format("Token(%s, %q, %s:%s)", 
    self.type, self.lexeme, self.pos.line, self.pos.column)
end
```

**Pattern: Keyword Lookup**
```lua
local keywords = {
  ["and"] = TokenType.AND,
  ["or"] = TokenType.OR,
  ["not"] = TokenType.NOT,
  ["true"] = TokenType.TRUE,
  ["false"] = TokenType.FALSE,
  ["null"] = TokenType.NULL,
  ["else"] = TokenType.ELSE,
  ["include"] = TokenType.INCLUDE_KW,
  ["import"] = TokenType.IMPORT_KW,
  ["as"] = TokenType.AS,
}
```

---

## Stage 03: Source Position and Span Tracking

### Prerequisites
- Stage 01: Script module structure complete
- Stage 02: Token type definitions complete

### Objectives
Implement source position tracking that enables accurate error reporting. Every token and AST node will carry position information. This stage creates the foundation for all diagnostic messages that reference source locations.

### Inputs
- `lib/whisker/script/lexer/tokens.lua` (Token uses position)
- Error message examples (from prompt context)

### Tasks
1. Create `lib/whisker/script/source.lua` with:
   - `SourcePosition` class (line, column, offset)
   - `SourceSpan` class (start position, end position)
   - `SourceLocation` class (file path, span)
2. Implement position creation and manipulation:
   - `SourcePosition.new(line, column, offset)`
   - `SourcePosition:advance(char)` — updates for single character
   - `SourcePosition:advance_line()` — handles newline
   - `SourcePosition:clone()` — creates copy for span endpoints
3. Implement span operations:
   - `SourceSpan.new(start_pos, end_pos)`
   - `SourceSpan.from_positions(start, end)` — convenience constructor
   - `SourceSpan:merge(other)` — combines spans (for AST nodes spanning tokens)
   - `SourceSpan:contains(position)` — for hover/click detection
4. Implement source line extraction:
   - `SourceFile.new(path, content)`
   - `SourceFile:get_line(line_number)` — returns line text
   - `SourceFile:get_context(position, context_lines)` — returns surrounding lines
5. Implement source snippet formatting:
   - `format_source_snippet(source, span, highlight)` — produces error output
6. Write comprehensive unit tests:
   - Position advancement through various characters
   - Span merging and containment
   - Line extraction edge cases (empty lines, last line without newline)
   - Snippet formatting with highlighting

### Outputs
- `lib/whisker/script/source.lua` (~180 lines)
- `tests/unit/script/source_spec.lua` (~150 lines)

### Acceptance Criteria
- [ ] `SourcePosition` tracks line (1-indexed), column (1-indexed), offset (0-indexed)
- [ ] `advance(char)` correctly updates column; `advance('\n')` updates line
- [ ] `SourceSpan:merge()` produces span covering both inputs
- [ ] `SourceFile:get_line()` returns correct line content
- [ ] Snippet formatting produces Rust-style error output
- [ ] All unit tests pass including edge cases

### Estimated Scope
- **Production code:** 150-200 lines
- **Test code:** 130-170 lines
- **Estimated time:** 1 day

### Implementation Notes
**Pattern: Position Tracking**
```lua
local SourcePosition = {}
SourcePosition.__index = SourcePosition

function SourcePosition.new(line, column, offset)
  return setmetatable({
    line = line or 1,
    column = column or 1,
    offset = offset or 0
  }, SourcePosition)
end

function SourcePosition:advance(char)
  local new = self:clone()
  new.offset = new.offset + 1
  if char == '\n' then
    new.line = new.line + 1
    new.column = 1
  else
    new.column = new.column + 1
  end
  return new
end
```

**Pattern: Source Snippet Formatting**
```lua
function format_source_snippet(source_file, span, message)
  local lines = {}
  local line_num = span.start.line
  local line = source_file:get_line(line_num)
  
  -- Line number gutter
  local gutter_width = #tostring(line_num) + 1
  
  table.insert(lines, string.format(
    "  --> %s:%d:%d", source_file.path, span.start.line, span.start.column
  ))
  table.insert(lines, string.rep(" ", gutter_width) .. "|")
  table.insert(lines, string.format("%d | %s", line_num, line))
  
  -- Underline the span
  local underline = string.rep(" ", gutter_width + span.start.column + 1)
  underline = underline .. string.rep("^", span.end_pos.column - span.start.column)
  underline = underline .. " " .. message
  table.insert(lines, underline)
  
  return table.concat(lines, "\n")
end
```

---

## Stage 04: Scanner Foundation (Character-Level Operations)

### Prerequisites
- Stage 01: Script module structure complete
- Stage 03: Source position tracking complete

### Objectives
Implement the character-level scanner that the lexer uses to traverse source text. The scanner provides peek/advance operations, position tracking, and character classification utilities. This separates character-level concerns from tokenization logic.

### Inputs
- `lib/whisker/script/source.lua` (SourcePosition)
- Character classification requirements from token patterns

### Tasks
1. Create `lib/whisker/script/lexer/scanner.lua` with:
   - `Scanner.new(source)` constructor
   - Character access methods
   - Position tracking integration
2. Implement basic navigation:
   - `peek(offset)` — look at character at current + offset without consuming
   - `advance()` — consume current character and return it
   - `at_end()` — check if at end of source
   - `current()` — return current character (peek(0))
3. Implement lookahead matching:
   - `match(expected)` — consume if matches, return boolean
   - `match_string(str)` — match multi-character sequence
   - `match_while(predicate)` — consume while predicate true, return consumed string
4. Implement position management:
   - `get_position()` — return current SourcePosition
   - `mark()` — save current position for backtracking
   - `reset_to_mark()` — restore to marked position
   - `get_lexeme_since_mark()` — get text from mark to current
5. Implement character classification functions:
   - `is_alpha(char)` — letter or underscore
   - `is_digit(char)` — 0-9
   - `is_alphanumeric(char)` — alpha or digit
   - `is_whitespace(char)` — space, tab (not newline)
   - `is_newline(char)` — \n or \r
6. Write unit tests covering:
   - Basic peek/advance/at_end
   - Multi-character lookahead
   - Position tracking through source
   - Mark/reset for backtracking
   - Character classification edge cases

### Outputs
- `lib/whisker/script/lexer/scanner.lua` (~140 lines)
- `tests/unit/script/lexer/scanner_spec.lua` (~160 lines)

### Acceptance Criteria
- [ ] `Scanner.new(source)` initializes at position (1,1,0)
- [ ] `peek()` returns current char without advancing
- [ ] `peek(n)` returns char at offset n from current
- [ ] `advance()` returns current char and updates position
- [ ] `match(char)` advances only if character matches
- [ ] `match_while(pred)` returns matched string
- [ ] `mark()`/`reset_to_mark()` enables backtracking
- [ ] Position correctly tracks line/column through newlines
- [ ] All unit tests pass

### Estimated Scope
- **Production code:** 120-160 lines
- **Test code:** 140-180 lines
- **Estimated time:** 1 day

### Implementation Notes
**Pattern: Scanner with Position Tracking**
```lua
local Scanner = {}
Scanner.__index = Scanner

function Scanner.new(source)
  return setmetatable({
    source = source,
    pos = SourcePosition.new(1, 1, 0),
    marks = {}  -- Stack for nested marks
  }, Scanner)
end

function Scanner:peek(offset)
  offset = offset or 0
  local idx = self.pos.offset + offset + 1  -- Lua 1-indexed
  if idx > #self.source then return nil end
  return self.source:sub(idx, idx)
end

function Scanner:advance()
  if self:at_end() then return nil end
  local char = self:peek()
  self.pos = self.pos:advance(char)
  return char
end

function Scanner:at_end()
  return self.pos.offset >= #self.source
end
```

**Pattern: Mark/Reset for Backtracking**
```lua
function Scanner:mark()
  table.insert(self.marks, self.pos:clone())
end

function Scanner:reset_to_mark()
  assert(#self.marks > 0, "No mark to reset to")
  self.pos = table.remove(self.marks)
end

function Scanner:pop_mark()
  -- Discard mark without resetting (when we commit to this path)
  assert(#self.marks > 0, "No mark to pop")
  table.remove(self.marks)
end

function Scanner:get_lexeme_since_mark()
  local mark = self.marks[#self.marks]
  return self.source:sub(mark.offset + 1, self.pos.offset)
end
```

---

## Stage 05: Core Lexer Implementation

### Prerequisites
- Stage 01: Script module structure and interfaces complete
- Stage 02: Token type definitions complete
- Stage 03: Source position tracking complete
- Stage 04: Scanner foundation complete

### Objectives
Implement the core lexer that tokenizes Whisker Script source into a stream of tokens. This stage handles the main tokenization loop, whitespace and newline significance rules, and produces a complete `TokenStream` for parser consumption.

### Inputs
- `lib/whisker/script/lexer/scanner.lua` (from Stage 04)
- `lib/whisker/script/lexer/tokens.lua` (from Stage 02)
- `lib/whisker/script/lexer/init.lua` (interface from Stage 01)
- Test fixtures: `tests/fixtures/script/lexer/` (basic scripts)

### Tasks
1. Implement `Lexer.new(source)` constructor:
   - Initialize scanner with source
   - Initialize state (indentation stack, error list)
   - Configure for significant whitespace mode
2. Implement `Lexer:tokenize()` main loop:
   - Call `next_token()` repeatedly until EOF
   - Accumulate tokens into array
   - Return TokenStream wrapping token array
3. Implement `Lexer:next_token()` dispatcher:
   - Skip whitespace (but track for indentation)
   - Check for EOF
   - Dispatch to specific tokenizers based on first character
4. Implement whitespace handling rules:
   - Track indentation at start of each line
   - Compare to indentation stack
   - Emit INDENT/DEDENT tokens as needed
   - Track whether we're at line start
5. Implement `TokenStream` class:
   - `peek(n)` — look ahead n tokens (default 0)
   - `advance()` — consume and return current token
   - `match(type)` — consume if type matches
   - `expect(type, message)` — consume or generate error
   - `at_end()` — check for EOF token
   - `current()` — return current token without consuming
6. Implement lexer error handling:
   - Create ERROR tokens for invalid input
   - Store error details (position, message)
   - Continue lexing after errors
7. Write comprehensive unit tests:
   - Empty source produces only EOF
   - Single tokens of each structural type
   - Multi-token sequences
   - Whitespace significance
   - Indentation changes
   - Error recovery

### Outputs
- `lib/whisker/script/lexer/lexer.lua` (~150 lines)
- `lib/whisker/script/lexer/stream.lua` (~80 lines)
- Updated `lib/whisker/script/lexer/init.lua` (exports)
- `tests/unit/script/lexer/lexer_spec.lua` (~180 lines)
- `tests/fixtures/script/lexer/basic.wsk`
- `tests/fixtures/script/lexer/indentation.wsk`

### Acceptance Criteria
- [ ] `Lexer.new(source):tokenize()` returns `TokenStream`
- [ ] EOF token terminates every token stream
- [ ] Source positions are accurate for all tokens
- [ ] Indentation tracking correctly identifies block depth
- [ ] INDENT/DEDENT tokens emitted at block boundaries
- [ ] `TokenStream` supports peek/advance/match/expect
- [ ] Lexer errors include position and descriptive message
- [ ] Contract tests pass for `ILexer` interface
- [ ] Unit test coverage ≥90% for lexer module

### Estimated Scope
- **Production code:** 180-230 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Token Dispatch**
```lua
function Lexer:next_token()
  self:skip_whitespace_and_track_indent()
  
  if self.scanner:at_end() then
    return self:make_token(TokenType.EOF)
  end
  
  local char = self.scanner:peek()
  
  -- Dispatch table pattern
  local handler = self.dispatch[char]
  if handler then
    return handler(self)
  end
  
  -- Fallbacks
  if is_alpha(char) then return self:identifier_or_keyword() end
  if is_digit(char) then return self:number() end
  if char == '"' then return self:string() end
  
  -- Unknown character
  return self:error_token("Unexpected character: " .. char)
end
```

**Pattern: Indentation Tracking**
```lua
function Lexer:handle_line_start()
  local indent = 0
  while self.scanner:match(" ") do indent = indent + 1 end
  -- Could also handle tabs with configurable width
  
  local tokens = {}
  local current_indent = self.indent_stack[#self.indent_stack] or 0
  
  if indent > current_indent then
    table.insert(self.indent_stack, indent)
    table.insert(tokens, self:make_token(TokenType.INDENT))
  elseif indent < current_indent then
    while #self.indent_stack > 0 and self.indent_stack[#self.indent_stack] > indent do
      table.remove(self.indent_stack)
      table.insert(tokens, self:make_token(TokenType.DEDENT))
    end
  end
  
  return tokens
end
```

**Pattern: TokenStream Immutability**
```lua
local TokenStream = {}
TokenStream.__index = TokenStream

function TokenStream.new(tokens)
  return setmetatable({
    tokens = tokens,
    cursor = 1
  }, TokenStream)
end

function TokenStream:peek(offset)
  offset = offset or 0
  local idx = self.cursor + offset
  if idx > #self.tokens then return self.tokens[#self.tokens] end -- EOF
  return self.tokens[idx]
end

function TokenStream:advance()
  local token = self:peek()
  if token.type ~= TokenType.EOF then
    self.cursor = self.cursor + 1
  end
  return token
end
```

---

## Stage 06: Structural Token Recognition

### Prerequisites
- Stage 05: Core lexer implementation complete

### Objectives
Implement recognition of Whisker Script's structural tokens: passage declarations (::), choices (+), diverts (->), tunnels (->->), threads (<-), assignments (~), metadata (@@), and includes (>>). These tokens define the narrative structure.

### Inputs
- `lib/whisker/script/lexer/lexer.lua` (from Stage 05)
- Token patterns from Appendix B

### Tasks
1. Implement passage declaration tokenizer:
   - `::` followed by identifier
   - Handle optional tag syntax `[tag1, tag2]`
2. Implement choice tokenizer:
   - `+` at line start (choice marker)
   - Note: `+` in expressions is handled differently
3. Implement divert tokenizer:
   - `->` for simple divert
   - `->->` for tunnel (must check for double arrow)
4. Implement thread tokenizer:
   - `<-` for thread start
5. Implement assignment tokenizer:
   - `~` for assignment marker
6. Implement metadata tokenizer:
   - `@@` for metadata declarations
7. Implement include tokenizer:
   - `>>` for include/import directives
8. Implement comment tokenizer:
   - `#` starts single-line comment
   - `##` for block comment continuation
   - Comments produce COMMENT tokens (may be discarded or preserved)
9. Add contextual disambiguation:
   - `+` at line start is CHOICE, in expression is PLUS
   - `-` at line start (after condition) is DASH, in expression is MINUS
10. Update lexer dispatch table with new handlers
11. Write unit tests for each structural token type

### Outputs
- Updated `lib/whisker/script/lexer/lexer.lua` (+60 lines)
- `lib/whisker/script/lexer/rules.lua` (~100 lines) — tokenization rules
- `tests/unit/script/lexer/structural_spec.lua` (~140 lines)
- `tests/fixtures/script/lexer/structural.wsk`

### Acceptance Criteria
- [ ] `::` recognized as PASSAGE_DECL
- [ ] `+` at line start recognized as CHOICE
- [ ] `->` recognized as DIVERT
- [ ] `->->` recognized as TUNNEL (not two DIVERTs)
- [ ] `<-` recognized as THREAD
- [ ] `~` recognized as ASSIGN
- [ ] `@@` recognized as METADATA
- [ ] `>>` recognized as INCLUDE
- [ ] `#` and `##` properly handle comments
- [ ] Context-sensitive tokens correctly classified
- [ ] All structural token tests pass

### Estimated Scope
- **Production code:** 120-160 lines
- **Test code:** 120-160 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes
**Pattern: Multi-character Token Recognition**
```lua
function Lexer:divert_or_tunnel()
  self.scanner:mark()
  self.scanner:advance()  -- consume first '-'
  
  if self.scanner:match('>') then
    -- We have '->'
    if self.scanner:match('-') and self.scanner:match('>') then
      -- We have '->->'
      self.scanner:pop_mark()
      return self:make_token(TokenType.TUNNEL)
    end
    self.scanner:pop_mark()
    return self:make_token(TokenType.DIVERT)
  end
  
  -- Just a minus
  self.scanner:reset_to_mark()
  return self:minus_or_dash()
end
```

**Pattern: Context Tracking**
```lua
function Lexer:new(source)
  -- ...
  self.at_line_start = true
  self.in_expression = false
end

function Lexer:choice_or_plus()
  if self.at_line_start and not self.in_expression then
    return self:make_token(TokenType.CHOICE)
  else
    return self:make_token(TokenType.PLUS)
  end
end
```

---

## Stage 07: Expression Token Recognition

### Prerequisites
- Stage 05: Core lexer implementation complete
- Stage 06: Structural token recognition complete

### Objectives
Implement recognition of expression-related tokens: operators (arithmetic, comparison, logical, assignment), literals (numbers, strings, booleans, null), identifiers, and variables ($-prefixed). These tokens appear within conditions, assignments, and inline expressions.

### Inputs
- `lib/whisker/script/lexer/lexer.lua` (from previous stages)
- Token patterns from Appendix B
- Expression syntax from grammar specification

### Tasks
1. Implement number literal tokenizer:
   - Integer: `[0-9]+`
   - Decimal: `[0-9]+\.[0-9]+`
   - Negative handled as unary operator, not in literal
   - Store parsed numeric value in token literal field
2. Implement string literal tokenizer:
   - Double-quoted: `"..."`
   - Escape sequences: `\"`, `\\`, `\n`, `\t`
   - Store unescaped content in literal field
   - Produce error token for unterminated strings
3. Implement identifier tokenizer:
   - `[a-zA-Z_][a-zA-Z0-9_]*`
   - Check against keyword table
   - Return keyword token type if match, else IDENTIFIER
4. Implement variable tokenizer:
   - `$` followed by identifier
   - Store variable name (without $) in literal field
5. Implement comparison operators:
   - `==`, `!=`, `<`, `>`, `<=`, `>=`
   - Multi-character operators require lookahead
6. Implement compound assignment operators:
   - `+=`, `-=`, `*=`, `/=`
7. Implement arithmetic operators:
   - `+`, `-`, `*`, `/`, `%`
8. Implement logical operators (keywords):
   - `and`, `or`, `not` (handled by keyword lookup)
9. Implement delimiter tokens:
   - `{`, `}`, `[`, `]`, `(`, `)`, `:`, `|`, `,`
10. Write unit tests for all expression tokens

### Outputs
- Updated `lib/whisker/script/lexer/lexer.lua` (+80 lines)
- Updated `lib/whisker/script/lexer/rules.lua` (+60 lines)
- `tests/unit/script/lexer/expression_spec.lua` (~180 lines)
- `tests/fixtures/script/lexer/expressions.wsk`

### Acceptance Criteria
- [ ] Numbers parsed with correct literal value (42, 3.14)
- [ ] Strings parsed with escape sequences resolved
- [ ] Unterminated strings produce ERROR token with position
- [ ] Variables produce VARIABLE token with name in literal
- [ ] All comparison operators correctly recognized
- [ ] All compound assignment operators correctly recognized
- [ ] Keywords (`and`, `or`, `not`, `true`, `false`, `null`, `else`) recognized
- [ ] Delimiters produce correct token types
- [ ] All expression token tests pass

### Estimated Scope
- **Production code:** 100-140 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes
**Pattern: String with Escapes**
```lua
function Lexer:string()
  self.scanner:mark()
  self.scanner:advance()  -- consume opening "
  
  local chars = {}
  while not self.scanner:at_end() and self.scanner:peek() ~= '"' do
    local char = self.scanner:advance()
    if char == '\\' then
      local escaped = self.scanner:advance()
      local escape_map = { n = '\n', t = '\t', ['"'] = '"', ['\\'] = '\\' }
      char = escape_map[escaped] or escaped
    end
    table.insert(chars, char)
  end
  
  if self.scanner:at_end() then
    return self:error_token("Unterminated string")
  end
  
  self.scanner:advance()  -- consume closing "
  self.scanner:pop_mark()
  
  return self:make_token(TokenType.STRING, table.concat(chars))
end
```

**Pattern: Number Parsing**
```lua
function Lexer:number()
  self.scanner:mark()
  local start = self.scanner:get_position()
  
  -- Consume integer part
  while is_digit(self.scanner:peek()) do
    self.scanner:advance()
  end
  
  -- Check for decimal
  if self.scanner:peek() == '.' and is_digit(self.scanner:peek(1)) then
    self.scanner:advance()  -- consume '.'
    while is_digit(self.scanner:peek()) do
      self.scanner:advance()
    end
  end
  
  local lexeme = self.scanner:get_lexeme_since_mark()
  self.scanner:pop_mark()
  
  return Token.new(TokenType.NUMBER, lexeme, tonumber(lexeme), start)
end
```

---

## Stage 08: Lexer Error Handling and Recovery

### Prerequisites
- Stage 05-07: Core lexer and token recognition complete

### Objectives
Implement comprehensive error handling for the lexer. This includes generating informative error tokens, recovering from errors to continue lexing, and producing diagnostic messages suitable for the error reporting system.

### Inputs
- `lib/whisker/script/lexer/lexer.lua` (from previous stages)
- `lib/whisker/script/errors/codes.lua` (error codes)
- Error message catalog from Appendix D

### Tasks
1. Define lexer error codes:
   - `WSK0001`: Unexpected character
   - `WSK0002`: Unterminated string
   - `WSK0003`: Invalid number format
   - `WSK0004`: Invalid escape sequence
   - `WSK0005`: Unexpected end of input
2. Implement `LexerError` class:
   - Store code, message, position, context
   - Include suggestion field for fix hints
3. Implement error token generation:
   - `error_token(code, message)` creates ERROR token with diagnostic
   - ERROR tokens contain full diagnostic info
4. Implement error recovery strategies:
   - Unexpected character: emit ERROR, skip character, continue
   - Unterminated string: emit ERROR, skip to newline, continue
   - Invalid number: emit ERROR with consumed text, continue
5. Implement error collection:
   - Lexer accumulates errors instead of throwing
   - `get_errors()` returns all accumulated errors
   - Errors include source snippets for context
6. Create error formatting utilities:
   - Format error with source context
   - Highlight problematic region
   - Include suggestions when available
7. Implement error limit:
   - Stop lexing after configurable error count (default: 100)
   - Prevents runaway error accumulation on severely malformed input
8. Write tests for error handling:
   - Each error type triggers correct code
   - Recovery allows continued lexing
   - Error messages are informative
   - Source positions are accurate

### Outputs
- `lib/whisker/script/errors/codes.lua` (~60 lines, lexer section)
- `lib/whisker/script/lexer/errors.lua` (~80 lines)
- Updated `lib/whisker/script/lexer/lexer.lua` (+40 lines)
- `tests/unit/script/lexer/errors_spec.lua` (~140 lines)
- `tests/fixtures/script/lexer/errors/` (error test cases)

### Acceptance Criteria
- [ ] Each error type has unique error code
- [ ] Error tokens include position and descriptive message
- [ ] Lexer continues after recoverable errors
- [ ] `get_errors()` returns all accumulated errors
- [ ] Error messages match catalog format
- [ ] Error limit prevents infinite loops on bad input
- [ ] Error tests cover all defined error types

### Estimated Scope
- **Production code:** 120-160 lines
- **Test code:** 120-160 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes
**Pattern: Error Token with Diagnostic**
```lua
function Lexer:error_token(code, message, suggestion)
  local pos = self.scanner:get_position()
  local diagnostic = {
    code = code,
    message = message,
    position = pos,
    suggestion = suggestion,
    source_line = self.source_file:get_line(pos.line)
  }
  
  table.insert(self.errors, diagnostic)
  
  -- Advance past problem character to continue lexing
  self.scanner:advance()
  
  return Token.new(TokenType.ERROR, "", diagnostic, pos)
end
```

**Pattern: Error Recovery in String**
```lua
function Lexer:string()
  local start = self.scanner:get_position()
  self.scanner:advance()  -- consume opening "
  
  while not self.scanner:at_end() do
    local char = self.scanner:peek()
    
    if char == '"' then
      self.scanner:advance()
      return self:make_string_token(start)
    end
    
    if char == '\n' then
      -- Unterminated string - recover at newline
      return self:error_token("WSK0002",
        "Unterminated string starting at line " .. start.line,
        "Add closing quote \" before end of line")
    end
    
    if char == '\\' then
      self.scanner:advance()
      if self.scanner:at_end() then
        return self:error_token("WSK0005", "Unexpected end of input in string")
      end
    end
    
    self.scanner:advance()
  end
  
  return self:error_token("WSK0002", "Unterminated string at end of file")
end
```

---

## Stage 09: AST Node Definitions

### Prerequisites
- Stage 01: Script module structure complete
- Stage 03: Source position tracking complete

### Objectives
Define all AST node types used by the Whisker Script parser. Each node type captures a specific language construct and includes source position information for error reporting. The nodes are designed for immutability to enable safe caching and transformation.

### Inputs
- AST Node Catalog from Appendix C
- Whisker Script grammar structure
- `lib/whisker/script/source.lua` (SourcePosition, SourceSpan)

### Tasks
1. Create `lib/whisker/script/parser/ast.lua` with:
   - Base `Node` class with type and position fields
   - Node factory functions for each node type
   - Node type constants (enum-like)
2. Define top-level nodes:
   - `ScriptNode`: root node containing metadata, includes, passages
   - `MetadataNode`: key-value metadata pairs
   - `IncludeNode`: include/import directives
   - `PassageNode`: passage with name, tags, body
3. Define statement nodes:
   - `TextNode`: narrative text with inline expressions
   - `ChoiceNode`: choice with condition, text, target, nested content
   - `AssignmentNode`: variable assignment
   - `ConditionalNode`: if/elif/else block
   - `DivertNode`: passage navigation
   - `TunnelCallNode` and `TunnelReturnNode`
   - `ThreadStartNode`
4. Define expression nodes:
   - `BinaryExprNode`: binary operations
   - `UnaryExprNode`: unary operations
   - `VariableRefNode`: variable reference with optional index
   - `FunctionCallNode`: function invocation
   - `LiteralNode`: number, string, boolean, null
   - `ListLiteralNode`: list expression
   - `InlineExprNode`: inline expression interpolation
   - `InlineConditionalNode`: ternary-style inline conditional
5. Implement node creation helpers:
   - `Node.script(...)`, `Node.passage(...)`, etc.
   - Validate required fields at creation time
6. Implement node position helpers:
   - `get_span()`: compute span from start to end positions
   - `with_position(node, pos)`: create node with position
7. Write unit tests for node creation and validation

### Outputs
- `lib/whisker/script/parser/ast.lua` (~280 lines)
- `tests/unit/script/parser/ast_spec.lua` (~150 lines)

### Acceptance Criteria
- [ ] All node types from Appendix C defined
- [ ] Every node has `type` and `pos` fields
- [ ] Node factories validate required fields
- [ ] Nodes are immutable after creation
- [ ] `NodeType` enum contains all node types
- [ ] Position spans correctly calculated
- [ ] Unit tests cover all node types

### Estimated Scope
- **Production code:** 250-300 lines
- **Test code:** 130-170 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Node Factory with Validation**
```lua
local NodeType = {
  Script = "Script",
  Passage = "Passage",
  Choice = "Choice",
  -- ...
}

local function create_node(type, fields)
  assert(NodeType[type], "Unknown node type: " .. tostring(type))
  local node = { type = type }
  for k, v in pairs(fields) do
    node[k] = v
  end
  -- Freeze the node to prevent mutation
  return setmetatable(node, {
    __newindex = function()
      error("AST nodes are immutable")
    end
  })
end

local Node = {}

function Node.passage(name, tags, body, pos)
  assert(type(name) == "string", "Passage requires name")
  assert(type(body) == "table", "Passage requires body array")
  return create_node(NodeType.Passage, {
    name = name,
    tags = tags or {},
    body = body,
    pos = pos
  })
end
```

**Pattern: Expression Node Hierarchy**
```lua
function Node.binary_expr(operator, left, right, pos)
  assert(type(operator) == "string", "Binary expression requires operator")
  assert(left and left.type, "Binary expression requires left operand")
  assert(right and right.type, "Binary expression requires right operand")
  return create_node(NodeType.BinaryExpr, {
    operator = operator,
    left = left,
    right = right,
    pos = pos
  })
end

function Node.variable_ref(name, index, pos)
  assert(type(name) == "string", "Variable reference requires name")
  return create_node(NodeType.VariableRef, {
    name = name,
    index = index,  -- Optional expression for $list[i]
    pos = pos
  })
end
```

---

## Stage 10: AST Visitor Infrastructure

### Prerequisites
- Stage 09: AST node definitions complete

### Objectives
Implement the visitor pattern for AST traversal. This enables multiple passes over the AST (semantic analysis, code generation, pretty printing) without duplicating traversal logic. The visitor infrastructure supports both depth-first and breadth-first traversal, with pre-visit and post-visit hooks.

### Inputs
- `lib/whisker/script/parser/ast.lua` (node definitions)
- Visitor pattern reference from language implementation guides

### Tasks
1. Create `lib/whisker/script/visitor.lua` with:
   - `Visitor` base class
   - Default visit methods for each node type
   - Traversal infrastructure
2. Implement visitor dispatching:
   - `visit(node)` dispatches to `visit_<NodeType>(node)`
   - Default methods traverse children
   - Subclasses override specific methods
3. Implement traversal modes:
   - `traverse_depth_first(node, visitor)` — pre-order traversal
   - `traverse_with_parent(node, visitor)` — provides parent context
   - `traverse_post_order(node, visitor)` — children before node
4. Implement visitor hooks:
   - `enter_<NodeType>(node)` — called before children
   - `leave_<NodeType>(node)` — called after children
   - Hooks can return modified nodes or same nodes
5. Implement `TransformVisitor` subclass:
   - Returns potentially modified nodes
   - Enables AST transformations
   - Handles child replacement correctly
6. Implement `CollectingVisitor` subclass:
   - Collects nodes matching criteria
   - Useful for finding all passages, variables, etc.
7. Write unit tests:
   - Visitor dispatches to correct methods
   - Traversal visits all nodes
   - Transform visitor modifies AST
   - Collecting visitor finds expected nodes

### Outputs
- `lib/whisker/script/visitor.lua` (~180 lines)
- `tests/unit/script/visitor_spec.lua` (~160 lines)

### Acceptance Criteria
- [ ] `Visitor:visit(node)` dispatches based on node type
- [ ] Default visit methods traverse children
- [ ] Subclasses can override specific node types
- [ ] `enter_*`/`leave_*` hooks called at correct times
- [ ] `TransformVisitor` can modify AST
- [ ] `CollectingVisitor` finds nodes by predicate
- [ ] All traversal modes work correctly
- [ ] Unit tests cover visitor patterns

### Estimated Scope
- **Production code:** 150-200 lines
- **Test code:** 140-180 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes
**Pattern: Visitor Base Class**
```lua
local Visitor = {}
Visitor.__index = Visitor

function Visitor.new()
  return setmetatable({}, Visitor)
end

function Visitor:visit(node)
  if not node then return end
  
  local method_name = "visit_" .. node.type
  local method = self[method_name]
  
  if method then
    return method(self, node)
  else
    return self:visit_default(node)
  end
end

function Visitor:visit_default(node)
  -- Default: traverse all child nodes
  self:visit_children(node)
end

function Visitor:visit_children(node)
  -- Node-type-specific child traversal
  local children = get_children(node)
  for _, child in ipairs(children) do
    self:visit(child)
  end
end
```

**Pattern: Enter/Leave Hooks**
```lua
function Visitor:traverse(node)
  if not node then return node end
  
  local enter_method = self["enter_" .. node.type]
  if enter_method then
    local result = enter_method(self, node)
    if result ~= nil then node = result end
  end
  
  -- Traverse children
  node = self:traverse_children(node)
  
  local leave_method = self["leave_" .. node.type]
  if leave_method then
    local result = leave_method(self, node)
    if result ~= nil then node = result end
  end
  
  return node
end
```

**Pattern: Collecting Visitor**
```lua
local CollectingVisitor = setmetatable({}, { __index = Visitor })

function CollectingVisitor.new(predicate)
  local self = Visitor.new()
  setmetatable(self, { __index = CollectingVisitor })
  self.predicate = predicate
  self.collected = {}
  return self
end

function CollectingVisitor:visit_default(node)
  if self.predicate(node) then
    table.insert(self.collected, node)
  end
  Visitor.visit_default(self, node)
end
```

---

## Stage 11: Parser Infrastructure and Error Recovery

### Prerequisites
- Stage 05-08: Lexer complete with TokenStream
- Stage 09: AST node definitions complete

### Objectives
Implement the parser infrastructure including the Parser class, error recovery mechanisms, and synchronization points. This stage creates the foundation for grammar rule implementation in subsequent stages.

### Inputs
- `lib/whisker/script/lexer/stream.lua` (TokenStream)
- `lib/whisker/script/parser/ast.lua` (AST nodes)
- Error codes from Appendix D

### Tasks
1. Create `lib/whisker/script/parser/init.lua` with:
   - `Parser.new(token_stream)` constructor
   - Public `parse()` method
   - Error accumulation and recovery infrastructure
2. Implement token stream interaction:
   - `peek()`, `advance()`, `previous()`
   - `check(type)` — check without consuming
   - `match(type...)` — consume if any type matches
   - `expect(type, message)` — consume or error
3. Implement error creation:
   - `error_at(token, message)` — error at specific token
   - `error_at_current(message)` — error at current position
   - `error_at_previous(message)` — error at last consumed token
4. Implement error recovery:
   - `synchronize()` — skip tokens until synchronization point
   - Synchronization points: PASSAGE_DECL, CHOICE, NEWLINE, EOF
   - Track "panic mode" to suppress cascading errors
5. Define parser error codes:
   - `WSK0010`: Expected passage declaration
   - `WSK0011`: Expected passage name
   - `WSK0012`: Expected closing bracket
   - (Additional codes from Appendix D)
6. Implement diagnostic collection:
   - `get_errors()` returns accumulated parser errors
   - Errors include source position and suggestions
7. Create parser state management:
   - Track current context (in_passage, in_choice, etc.)
   - Track nesting depth for error messages
8. Write infrastructure tests:
   - Token consumption methods work correctly
   - Error recovery reaches synchronization points
   - Errors include correct positions

### Outputs
- `lib/whisker/script/parser/init.lua` (~160 lines)
- `lib/whisker/script/parser/recovery.lua` (~80 lines)
- Updated `lib/whisker/script/errors/codes.lua` (+40 lines parser section)
- `tests/unit/script/parser/infrastructure_spec.lua` (~140 lines)

### Acceptance Criteria
- [ ] `Parser.new(tokens)` creates parser instance
- [ ] `peek()`, `advance()`, `check()`, `match()` work correctly
- [ ] `expect()` either consumes token or reports error
- [ ] `synchronize()` advances to recovery point
- [ ] Errors include position and descriptive message
- [ ] Panic mode prevents cascading errors
- [ ] Parser context tracks nesting correctly
- [ ] Infrastructure tests pass

### Estimated Scope
- **Production code:** 180-240 lines
- **Test code:** 120-160 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Parser with Error Recovery**
```lua
local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
  return setmetatable({
    tokens = tokens,
    errors = {},
    panic_mode = false,
    context = { in_passage = false, in_choice = false }
  }, Parser)
end

function Parser:expect(type, message)
  if self:check(type) then
    return self:advance()
  end
  
  return self:error_at_current(message)
end

function Parser:error_at_current(message)
  return self:error_at(self:peek(), message)
end

function Parser:error_at(token, message)
  if self.panic_mode then return nil end
  self.panic_mode = true
  
  local error = {
    code = self:determine_error_code(token, message),
    message = message,
    token = token,
    position = token.pos
  }
  table.insert(self.errors, error)
  
  return nil  -- Return nil to signal error
end
```

**Pattern: Synchronization**
```lua
local sync_tokens = {
  [TokenType.PASSAGE_DECL] = true,
  [TokenType.CHOICE] = true,
  [TokenType.ASSIGN] = true,
  [TokenType.EOF] = true,
}

function Parser:synchronize()
  self.panic_mode = false
  
  while not self:at_end() do
    -- Newline at same or lesser indentation ends statement
    if self:previous().type == TokenType.NEWLINE then
      return
    end
    
    if sync_tokens[self:peek().type] then
      return
    end
    
    self:advance()
  end
end
```

---

## Stage 12: Basic Grammar Rules (Script and Passage Structure)

### Prerequisites
- Stage 09: AST node definitions complete
- Stage 11: Parser infrastructure complete

### Objectives
Implement parsing of top-level script structure: the script itself, metadata declarations, include directives, and passage declarations. This establishes the outermost structure that all content nests within.

### Inputs
- `lib/whisker/script/parser/init.lua` (parser infrastructure)
- `lib/whisker/script/parser/ast.lua` (AST nodes)
- Grammar rules from Appendix A

### Tasks
1. Create `lib/whisker/script/parser/grammar.lua` with:
   - `parse_script()` — entry point
   - Grammar rule methods
2. Implement script parsing:
   - Parse sequence of metadata, includes, and passages
   - Continue on errors to find multiple issues
   - Build ScriptNode with collected children
3. Implement metadata parsing:
   - `@@` followed by identifier, `:`, value
   - Handle various value types (string, number, list)
   - Build MetadataNode
4. Implement include parsing:
   - `>>` followed by `include` or `import`
   - Parse string path
   - Optional `as` alias for imports
   - Build IncludeNode
5. Implement passage declaration parsing:
   - `::` followed by identifier
   - Optional tag list `[tag1, tag2]`
   - Build PassageNode (body parsing in Stage 13)
6. Implement tag list parsing:
   - `[` identifier { `,` identifier } `]`
   - Handle empty tags `[]`
7. Handle end-of-file gracefully:
   - Emit DEDENT tokens for unclosed indentation
   - Complete partial constructs where possible
8. Write grammar tests:
   - Empty script
   - Metadata only
   - Single passage
   - Multiple passages with metadata

### Outputs
- `lib/whisker/script/parser/grammar.lua` (~200 lines, initial)
- `tests/unit/script/parser/grammar_spec.lua` (~180 lines, initial)
- `tests/fixtures/script/parser/basic_structure.wsk`

### Acceptance Criteria
- [ ] Empty source produces empty ScriptNode
- [ ] Metadata declarations parsed correctly
- [ ] Include/import directives parsed correctly
- [ ] Passage declarations recognized
- [ ] Tags parsed as array of strings
- [ ] Errors for malformed declarations
- [ ] Parser continues after errors
- [ ] All grammar tests pass

### Estimated Scope
- **Production code:** 160-220 lines
- **Test code:** 150-200 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Grammar Rule Methods**
```lua
function Parser:parse_script()
  local metadata = {}
  local includes = {}
  local passages = {}
  local start_pos = self:peek().pos
  
  while not self:at_end() do
    if self:check(TokenType.METADATA) then
      local meta = self:parse_metadata()
      if meta then table.insert(metadata, meta) end
    elseif self:check(TokenType.INCLUDE) then
      local inc = self:parse_include()
      if inc then table.insert(includes, inc) end
    elseif self:check(TokenType.PASSAGE_DECL) then
      local passage = self:parse_passage()
      if passage then table.insert(passages, passage) end
    elseif self:check(TokenType.NEWLINE) then
      self:advance()  -- Skip blank lines
    else
      self:error_at_current("Expected passage declaration (::)")
      self:synchronize()
    end
  end
  
  return Node.script(metadata, includes, passages, start_pos)
end
```

**Pattern: Metadata Parsing**
```lua
function Parser:parse_metadata()
  local start = self:expect(TokenType.METADATA, "Expected @@").pos
  local key = self:expect(TokenType.IDENTIFIER, "Expected metadata key")
  
  if not key then
    self:synchronize()
    return nil
  end
  
  self:expect(TokenType.COLON, "Expected ':' after metadata key")
  local value = self:parse_expression()
  self:consume_line_end()
  
  return Node.metadata(key.lexeme, value, start)
end
```

---

## Stage 13: Passage and Metadata Parsing

### Prerequisites
- Stage 12: Basic grammar rules complete

### Objectives
Complete passage parsing including passage body content. Parse the statements that comprise a passage: narrative text, choices, diverts, variable assignments, and conditionals. This stage handles the primary narrative content structure.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (from Stage 12)
- Grammar rules from Appendix A

### Tasks
1. Extend passage parsing:
   - Parse passage name and tags
   - Parse statement sequence as passage body
   - Handle indentation-based block structure
2. Implement statement parsing:
   - Dispatch based on first token
   - TEXT → text statement
   - CHOICE → choice statement
   - ASSIGN → assignment statement
   - DIVERT → divert statement
   - LBRACE → conditional block
3. Implement text line parsing:
   - Plain text content
   - Inline expressions `{$var}` and `{condition: a | b}`
   - Build TextNode with mixed content
4. Implement passage reference validation:
   - Store passage names for later resolution
   - Don't error yet (semantic analysis will)
5. Handle whitespace significance:
   - INDENT increases nesting
   - DEDENT decreases nesting
   - Track indentation for nested content
6. Implement line continuation:
   - Long text can span multiple lines if indented
   - Blank lines within indented blocks
7. Write tests for passage parsing:
   - Simple passage with text
   - Passage with multiple paragraphs
   - Passage with inline expressions

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+160 lines)
- `tests/unit/script/parser/passage_spec.lua` (~180 lines)
- `tests/fixtures/script/parser/passages.wsk`

### Acceptance Criteria
- [ ] Passage name and tags parsed correctly
- [ ] Plain text lines become TextNode
- [ ] Statement dispatch works for all types
- [ ] Indentation correctly determines nesting
- [ ] Inline expressions detected in text
- [ ] Multiple paragraphs handled
- [ ] All passage tests pass

### Estimated Scope
- **Production code:** 140-180 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Statement Dispatch**
```lua
function Parser:parse_statement()
  local token = self:peek()
  
  if token.type == TokenType.CHOICE then
    return self:parse_choice()
  elseif token.type == TokenType.ASSIGN then
    return self:parse_assignment()
  elseif token.type == TokenType.DIVERT then
    return self:parse_divert()
  elseif token.type == TokenType.TUNNEL then
    return self:parse_tunnel()
  elseif token.type == TokenType.THREAD then
    return self:parse_thread()
  elseif token.type == TokenType.LBRACE then
    return self:parse_conditional()
  else
    return self:parse_text_line()
  end
end
```

**Pattern: Text with Inline Expressions**
```lua
function Parser:parse_text_line()
  local content = {}
  local start_pos = self:peek().pos
  
  while not self:at_line_end() do
    if self:check(TokenType.LBRACE) then
      local expr = self:parse_inline_expression()
      table.insert(content, expr)
    elseif self:check(TokenType.TEXT) then
      table.insert(content, self:advance().lexeme)
    else
      -- Unexpected token in text
      break
    end
  end
  
  self:consume_line_end()
  return Node.text(content, start_pos)
end
```

---

## Stage 14: Choice and Divert Parsing

### Prerequisites
- Stage 13: Passage and text parsing complete

### Objectives
Implement parsing of choices and diverts—the core navigation constructs in interactive fiction. Choices present options to the reader; diverts move to other passages. This stage handles the branching structure of narratives.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (from previous stages)
- Grammar rules for choice and divert

### Tasks
1. Implement choice parsing:
   - `+` choice marker
   - Optional condition `{ $condition }`
   - Choice text `[text content]`
   - Optional inline divert `-> Target`
   - Optional nested content (indented statements)
2. Implement conditional choice detection:
   - Check for `{` before `[`
   - Parse condition expression
   - Continue to choice text
3. Implement choice text parsing:
   - Content within `[` and `]`
   - Can contain inline expressions
   - Escape sequences for `]` in text
4. Implement divert parsing:
   - `->` followed by passage identifier
   - Handle `-> END` special target
   - Handle invalid targets (not identifiers)
5. Implement tunnel divert parsing:
   - `->->` with target (call)
   - `->->` alone (return)
   - Build appropriate node type
6. Implement thread parsing:
   - `<-` followed by passage identifier
   - Build ThreadStartNode
7. Handle nested choice content:
   - INDENT after choice indicates nested statements
   - Parse nested statement sequence
   - DEDENT ends nested content
8. Write comprehensive choice/divert tests:
   - Simple choice with divert
   - Conditional choice
   - Nested choice content
   - Multiple choices in sequence

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+180 lines)
- `tests/unit/script/parser/choices_spec.lua` (~200 lines)
- `tests/fixtures/script/parser/choices.wsk`

### Acceptance Criteria
- [ ] Simple choices parsed correctly
- [ ] Choice conditions parsed as expressions
- [ ] Choice text extracted correctly
- [ ] Inline diverts associated with choices
- [ ] Nested content under choices parsed
- [ ] Standalone diverts work
- [ ] Tunnel calls and returns distinguished
- [ ] Thread starts recognized
- [ ] All choice/divert tests pass

### Estimated Scope
- **Production code:** 160-200 lines
- **Test code:** 180-220 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Choice with Optional Components**
```lua
function Parser:parse_choice()
  local start = self:expect(TokenType.CHOICE, "Expected '+'").pos
  local condition = nil
  
  -- Optional condition
  if self:check(TokenType.LBRACE) then
    condition = self:parse_choice_condition()
  end
  
  -- Required choice text
  local text = self:parse_choice_text()
  if not text then
    return nil  -- Error already reported
  end
  
  -- Optional inline divert
  local target = nil
  if self:check(TokenType.DIVERT) then
    target = self:parse_divert()
  end
  
  self:consume_line_end()
  
  -- Optional nested content
  local nested = {}
  if self:check(TokenType.INDENT) then
    self:advance()
    nested = self:parse_statement_sequence()
    self:expect(TokenType.DEDENT, "Expected end of choice content")
  end
  
  return Node.choice(condition, text, target, nested, start)
end
```

**Pattern: Choice Text Parsing**
```lua
function Parser:parse_choice_text()
  if not self:expect(TokenType.LBRACKET, "Expected '[' for choice text") then
    return nil
  end
  
  local content = {}
  while not self:check(TokenType.RBRACKET) and not self:at_end() do
    if self:check(TokenType.LBRACE) then
      table.insert(content, self:parse_inline_expression())
    else
      local text = self:expect(TokenType.TEXT, "Expected choice text")
      if text then
        table.insert(content, text.lexeme)
      end
    end
  end
  
  self:expect(TokenType.RBRACKET, "Expected ']' after choice text")
  return content
end
```

---

## Stage 15: Text and Inline Expression Parsing

### Prerequisites
- Stage 13-14: Passage and choice parsing complete

### Objectives
Complete implementation of text parsing with embedded expressions. This includes variable interpolation `{$var}`, inline conditionals `{condition: then | else}`, and function calls within text. These features enable dynamic content without breaking narrative flow.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (from previous stages)
- Inline expression grammar

### Tasks
1. Implement inline expression parsing:
   - `{` expression `}` for simple interpolation
   - Build InlineExprNode
2. Implement inline conditional parsing:
   - `{` condition `:` then_text `}` — condition only
   - `{` condition `:` then_text `|` else_text `}` — with alternative
   - Build InlineConditionalNode
3. Distinguish expression types:
   - After `{`, peek ahead to determine type
   - Variable ref followed by `:` is conditional
   - Other expressions are simple interpolation
4. Implement inline text content parsing:
   - Text between `{` and `}` or `|` and `}`
   - Can contain nested expressions
   - Build mixed content array
5. Handle escaping in inline contexts:
   - `\{` produces literal `{`
   - `\|` produces literal `|` in conditionals
   - `\}` produces literal `}`
6. Implement graceful error recovery:
   - Missing `}` should recover at newline
   - Missing `|` in conditional should still parse
7. Write inline expression tests:
   - Simple variable interpolation
   - Variable with index `{$list[0]}`
   - Function call in text
   - Inline conditional with else
   - Nested expressions

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+140 lines)
- `tests/unit/script/parser/inline_spec.lua` (~180 lines)
- `tests/fixtures/script/parser/inline.wsk`

### Acceptance Criteria
- [ ] `{$variable}` produces InlineExprNode with VariableRefNode
- [ ] `{$cond: text}` produces InlineConditionalNode
- [ ] `{$cond: yes | no}` includes else branch
- [ ] Nested inline expressions work
- [ ] Escape sequences produce literal characters
- [ ] Errors recover gracefully
- [ ] All inline expression tests pass

### Estimated Scope
- **Production code:** 120-160 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes
**Pattern: Inline Expression Detection**
```lua
function Parser:parse_inline_expression()
  local start = self:expect(TokenType.LBRACE, "Expected '{'").pos
  
  -- Parse the expression
  local expr = self:parse_expression()
  
  -- Check if this is a conditional
  if self:check(TokenType.COLON) then
    return self:parse_inline_conditional(expr, start)
  end
  
  -- Simple interpolation
  self:expect(TokenType.RBRACE, "Expected '}' after expression")
  return Node.inline_expr(expr, start)
end

function Parser:parse_inline_conditional(condition, start)
  self:expect(TokenType.COLON, "Expected ':' after condition")
  
  -- Parse then-text (can be mixed content)
  local then_text = self:parse_inline_text_until({TokenType.PIPE, TokenType.RBRACE})
  
  -- Optional else branch
  local else_text = nil
  if self:match(TokenType.PIPE) then
    else_text = self:parse_inline_text_until({TokenType.RBRACE})
  end
  
  self:expect(TokenType.RBRACE, "Expected '}' after conditional")
  return Node.inline_conditional(condition, then_text, else_text, start)
end
```

---

## Stage 16: Expression Parsing (Precedence Climbing)

### Prerequisites
- Stage 11: Parser infrastructure complete
- Stage 09: AST node definitions for expressions

### Objectives
Implement expression parsing using precedence climbing (Pratt parser variant). This handles operator precedence and associativity for arithmetic, comparison, and logical expressions. The result is correct AST structure for complex expressions like `$a + $b * $c > $d and $e`.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (expression entry point)
- Operator precedence table
- Expression grammar from Appendix A

### Tasks
1. Define operator precedence levels:
   - Level 1 (lowest): `or`
   - Level 2: `and`
   - Level 3: `==`, `!=`
   - Level 4: `<`, `>`, `<=`, `>=`
   - Level 5: `+`, `-`
   - Level 6: `*`, `/`, `%`
   - Level 7 (highest): unary `not`, `-`
2. Implement precedence climbing parser:
   - `parse_expression()` entry point
   - `parse_precedence(min_precedence)` recursive parser
   - Handle left and right associativity
3. Implement binary expression parsing:
   - Get operator precedence
   - Recursively parse right operand at higher precedence
   - Build BinaryExprNode
4. Implement unary expression parsing:
   - `not` prefix operator
   - `-` numeric negation
   - Build UnaryExprNode
5. Implement primary expression parsing:
   - Literals (number, string, boolean, null)
   - Variable references `$name`
   - Function calls `name(args)`
   - Parenthesized expressions `(expr)`
   - List literals `[a, b, c]`
6. Implement function call parsing:
   - Identifier followed by `(`
   - Comma-separated argument list
   - Build FunctionCallNode
7. Implement variable index access:
   - `$list[expr]` for list indexing
   - Update VariableRefNode with index
8. Write expression tests:
   - All operator types
   - Precedence ordering
   - Associativity
   - Complex nested expressions

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+200 lines)
- `tests/unit/script/parser/expression_spec.lua` (~250 lines)
- `tests/fixtures/script/parser/expressions.wsk`

### Acceptance Criteria
- [ ] Arithmetic operators parse with correct precedence
- [ ] `a + b * c` produces `a + (b * c)` AST
- [ ] Comparison operators work
- [ ] Logical operators (`and`, `or`, `not`) work
- [ ] Unary operators bind correctly
- [ ] Function calls parse with arguments
- [ ] Variable indexing works
- [ ] Parentheses override precedence
- [ ] All expression tests pass

### Estimated Scope
- **Production code:** 180-220 lines
- **Test code:** 220-280 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes
**Pattern: Precedence Climbing**
```lua
local PRECEDENCE = {
  [TokenType.OR] = 1,
  [TokenType.AND] = 2,
  [TokenType.EQ_EQ] = 3, [TokenType.BANG_EQ] = 3,
  [TokenType.LT] = 4, [TokenType.GT] = 4,
  [TokenType.LT_EQ] = 4, [TokenType.GT_EQ] = 4,
  [TokenType.PLUS] = 5, [TokenType.MINUS] = 5,
  [TokenType.STAR] = 6, [TokenType.SLASH] = 6, [TokenType.PERCENT] = 6,
}

function Parser:parse_expression()
  return self:parse_precedence(1)
end

function Parser:parse_precedence(min_prec)
  local left = self:parse_unary()
  
  while true do
    local token = self:peek()
    local prec = PRECEDENCE[token.type]
    
    if not prec or prec < min_prec then
      break
    end
    
    local operator = self:advance()
    local right = self:parse_precedence(prec + 1)  -- Left associative
    left = Node.binary_expr(operator.lexeme, left, right, left.pos)
  end
  
  return left
end
```

**Pattern: Unary and Primary**
```lua
function Parser:parse_unary()
  if self:match(TokenType.NOT) then
    local op = self:previous()
    local operand = self:parse_unary()
    return Node.unary_expr("not", operand, op.pos)
  end
  
  if self:match(TokenType.MINUS) then
    local op = self:previous()
    local operand = self:parse_unary()
    return Node.unary_expr("-", operand, op.pos)
  end
  
  return self:parse_primary()
end

function Parser:parse_primary()
  if self:match(TokenType.NUMBER) then
    return Node.literal("number", self:previous().literal, self:previous().pos)
  end
  -- ... other literals, variables, function calls, etc.
end
```

---

## Stage 17: Conditional Block Parsing

### Prerequisites
- Stage 16: Expression parsing complete
- Stage 13: Statement sequence parsing complete

### Objectives
Implement parsing of conditional blocks with if/elif/else chains. This enables branching narrative content based on story state. The syntax uses braces with conditions and dashes for branches, designed for readability in narrative context.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (from previous stages)
- Conditional block grammar from Appendix A

### Tasks
1. Implement conditional block entry:
   - `{` condition `:` at statement level indicates block start
   - Distinguish from inline conditionals (in text context)
2. Implement main condition branch:
   - Parse condition expression
   - Expect `:` and NEWLINE
   - Parse INDENT and statement sequence
   - Build ConditionalBranchNode
3. Implement elif branches:
   - `-` at line start followed by condition
   - Multiple elif branches allowed
   - Parse same as main branch
4. Implement else branch:
   - `-` followed by `else` and `:`
   - Statement sequence
   - No condition
5. Implement block termination:
   - `}` closes conditional block
   - Track nesting for proper matching
6. Handle nested conditionals:
   - Conditionals can contain other conditionals
   - Proper tracking of block depth
7. Build ConditionalNode:
   - Array of ConditionalBranchNode (if + elifs)
   - Optional else body (statement array)
8. Write conditional block tests:
   - Simple if-only block
   - If with else
   - If with multiple elifs
   - Nested conditionals

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+140 lines)
- `tests/unit/script/parser/conditionals_spec.lua` (~180 lines)
- `tests/fixtures/script/parser/conditionals.wsk`

### Acceptance Criteria
- [ ] Simple conditional blocks parse correctly
- [ ] Elif chains captured in order
- [ ] Else branch optional and exclusive
- [ ] Nested conditionals work
- [ ] Block termination `}` required
- [ ] Error on missing condition
- [ ] Error on malformed branch syntax
- [ ] All conditional tests pass

### Estimated Scope
- **Production code:** 120-160 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1-1.5 days

### Implementation Notes
**Pattern: Conditional Block Parsing**
```lua
function Parser:parse_conditional()
  local start = self:expect(TokenType.LBRACE, "Expected '{'").pos
  
  -- First branch condition
  local condition = self:parse_expression()
  self:expect(TokenType.COLON, "Expected ':' after condition")
  self:consume_line_end()
  
  -- First branch body
  local first_body = self:parse_indented_block()
  local branches = { Node.conditional_branch(condition, first_body, condition.pos) }
  
  -- Elif branches
  while self:check(TokenType.DASH) and not self:check_else() do
    local branch = self:parse_elif_branch()
    if branch then table.insert(branches, branch) end
  end
  
  -- Optional else branch
  local else_body = nil
  if self:match_else() then
    self:expect(TokenType.COLON, "Expected ':' after else")
    self:consume_line_end()
    else_body = self:parse_indented_block()
  end
  
  self:expect(TokenType.RBRACE, "Expected '}' to close conditional")
  
  return Node.conditional(branches, else_body, start)
end
```

**Pattern: Elif Branch**
```lua
function Parser:parse_elif_branch()
  local start = self:expect(TokenType.DASH, "Expected '-' for elif").pos
  local condition = self:parse_expression()
  self:expect(TokenType.COLON, "Expected ':' after elif condition")
  self:consume_line_end()
  
  local body = self:parse_indented_block()
  return Node.conditional_branch(condition, body, start)
end

function Parser:check_else()
  return self:check(TokenType.DASH) and 
         self:peek(1).type == TokenType.ELSE
end

function Parser:match_else()
  if self:check_else() then
    self:advance()  -- DASH
    self:advance()  -- ELSE
    return true
  end
  return false
end
```

---

## Stage 18: Variable Assignment and Compound Operators

### Prerequisites
- Stage 16: Expression parsing complete
- Stage 13: Statement parsing infrastructure

### Objectives
Implement parsing of variable assignments including simple assignment, compound operators (+=, -=, etc.), and list append syntax. This enables story state management through variable manipulation.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (from previous stages)
- Assignment grammar from Appendix A

### Tasks
1. Implement assignment statement parsing:
   - `~` assignment marker
   - Variable reference target
   - Assignment operator
   - Value expression
2. Implement simple assignment:
   - `~ $variable = expression`
   - Build AssignmentNode with `=` operator
3. Implement compound assignment operators:
   - `+=`, `-=`, `*=`, `/=`
   - Store operator in AssignmentNode
4. Implement list append syntax:
   - `~ $list[] = value`
   - Empty index on target indicates append
   - Could translate to special operator or function call
5. Implement indexed assignment:
   - `~ $list[$index] = value`
   - Variable target with index expression
6. Validate assignment targets:
   - Only variable references allowed as targets
   - Error on invalid left-hand side
7. Handle multiple assignments:
   - Each assignment is a separate statement
   - No chained assignment in single statement
8. Write assignment tests:
   - Simple variable assignment
   - All compound operators
   - List append
   - Indexed assignment
   - Invalid target errors

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+100 lines)
- `tests/unit/script/parser/assignment_spec.lua` (~150 lines)
- `tests/fixtures/script/parser/assignments.wsk`

### Acceptance Criteria
- [ ] Simple assignments parse correctly
- [ ] All compound operators recognized
- [ ] List append syntax works
- [ ] Indexed assignment works
- [ ] Invalid targets produce errors
- [ ] Expression values parsed correctly
- [ ] All assignment tests pass

### Estimated Scope
- **Production code:** 80-120 lines
- **Test code:** 130-170 lines
- **Estimated time:** 1 day

### Implementation Notes
**Pattern: Assignment Parsing**
```lua
function Parser:parse_assignment()
  local start = self:expect(TokenType.ASSIGN, "Expected '~'").pos
  
  -- Parse target (must be variable reference)
  local target = self:parse_assignment_target()
  if not target then
    self:error_at_current("Expected variable as assignment target")
    self:synchronize()
    return nil
  end
  
  -- Parse operator
  local operator = self:parse_assignment_operator()
  if not operator then
    self:error_at_current("Expected assignment operator (=, +=, -=, *=, /=)")
    self:synchronize()
    return nil
  end
  
  -- Parse value
  local value = self:parse_expression()
  self:consume_line_end()
  
  return Node.assignment(target, operator, value, start)
end

function Parser:parse_assignment_target()
  if not self:check(TokenType.VARIABLE) then
    return nil
  end
  
  local var = self:advance()
  local name = var.literal
  local index = nil
  
  -- Check for index or list append
  if self:match(TokenType.LBRACKET) then
    if self:check(TokenType.RBRACKET) then
      -- Empty brackets: list append
      index = Node.literal("append_marker", nil, var.pos)
    else
      index = self:parse_expression()
    end
    self:expect(TokenType.RBRACKET, "Expected ']' after index")
  end
  
  return Node.variable_ref(name, index, var.pos)
end
```

---

## Stage 19: Tunnels, Threads, and Includes

### Prerequisites
- Stage 14: Divert parsing complete
- Stage 12: Include parsing basics

### Objectives
Complete parsing of advanced flow control constructs: tunnels (subroutines that return), threads (parallel narrative), and include/import directives. These enable modular story organization and complex narrative patterns.

### Inputs
- `lib/whisker/script/parser/grammar.lua` (from previous stages)
- Grammar for tunnels, threads, includes

### Tasks
1. Implement tunnel call parsing:
   - `->->` followed by passage identifier
   - Build TunnelCallNode
   - Store target passage for resolution
2. Implement tunnel return parsing:
   - `->->` alone (no target)
   - Build TunnelReturnNode
   - Must be inside a passage (semantic check later)
3. Implement thread start parsing:
   - `<-` followed by passage identifier
   - Build ThreadStartNode
   - Threads run concurrently with main narrative
4. Complete include directive parsing:
   - `>> include "path.wsk"` — inline the file
   - Handle quoted string path
   - Store for semantic phase file loading
5. Complete import directive parsing:
   - `>> import "path.wsk"` — import without namespace
   - `>> import "path.wsk" as utils` — with alias
   - Build IncludeNode with appropriate flags
6. Implement path validation:
   - Check for valid string path
   - Relative paths allowed
   - Error on malformed paths
7. Write flow control tests:
   - Tunnel call and return
   - Thread start
   - Include directive
   - Import with alias
   - Error cases

### Outputs
- Updated `lib/whisker/script/parser/grammar.lua` (+80 lines)
- `tests/unit/script/parser/flow_control_spec.lua` (~140 lines)
- `tests/fixtures/script/parser/flow_control.wsk`

### Acceptance Criteria
- [ ] Tunnel calls parse with target
- [ ] Tunnel returns parse without target
- [ ] `->->` distinguished from `->` + `->` or `->->`
- [ ] Thread starts parse correctly
- [ ] Include directives capture path
- [ ] Import directives capture path and alias
- [ ] Path strings validated
- [ ] All flow control tests pass

### Estimated Scope
- **Production code:** 60-100 lines
- **Test code:** 120-160 lines
- **Estimated time:** 0.5-1 day

### Implementation Notes
**Pattern: Tunnel Detection**
```lua
function Parser:parse_tunnel()
  local start = self:expect(TokenType.TUNNEL, "Expected '->->'").pos
  
  -- Check if target follows
  if self:check(TokenType.IDENTIFIER) then
    local target = self:advance()
    self:consume_line_end()
    return Node.tunnel_call(target.lexeme, start)
  end
  
  -- No target = tunnel return
  self:consume_line_end()
  return Node.tunnel_return(start)
end
```

**Pattern: Include vs Import**
```lua
function Parser:parse_include_directive()
  local start = self:expect(TokenType.INCLUDE, "Expected '>>'").pos
  
  local kind
  if self:match(TokenType.INCLUDE_KW) then
    kind = "include"
  elseif self:match(TokenType.IMPORT_KW) then
    kind = "import"
  else
    self:error_at_current("Expected 'include' or 'import'")
    self:synchronize()
    return nil
  end
  
  local path = self:expect(TokenType.STRING, "Expected file path")
  
  local alias = nil
  if kind == "import" and self:match(TokenType.AS) then
    alias = self:expect(TokenType.IDENTIFIER, "Expected alias name")
    alias = alias and alias.lexeme
  end
  
  self:consume_line_end()
  
  return Node.include(kind, path.literal, alias, start)
end
```

---

## Stage 20: Symbol Table and Scope Management

### Prerequisites
- Stage 09-10: AST nodes and visitor complete
- Stage 12-19: Parser complete

### Objectives
Implement the symbol table that tracks passages, variables, and functions throughout the story. This stage creates the data structures for semantic analysis, enabling reference resolution and duplicate detection in Stage 21.

### Inputs
- `lib/whisker/script/parser/ast.lua` (AST definitions)
- `lib/whisker/script/visitor.lua` (traversal)
- Symbol table design patterns

### Tasks
1. Create `lib/whisker/script/semantic/symbols.lua` with:
   - `SymbolTable` class
   - `Scope` class for nested scopes
   - `Symbol` class for entries
2. Implement Symbol class:
   - `name`: identifier string
   - `kind`: "passage", "variable", "function", "parameter"
   - `position`: source location of declaration
   - `type`: optional type information
   - `references`: list of usage locations
3. Implement Scope class:
   - `symbols`: map from name to Symbol
   - `parent`: enclosing scope or nil
   - `kind`: "global", "passage", "choice", "conditional"
4. Implement SymbolTable class:
   - `global_scope`: top-level scope
   - `current_scope`: active scope
   - `enter_scope(kind)`: push new scope
   - `exit_scope()`: pop scope
5. Implement symbol operations:
   - `define(name, kind, position)`: add symbol to current scope
   - `lookup(name)`: find symbol in current or parent scopes
   - `lookup_local(name)`: find only in current scope
   - `all_passages()`: list all passage symbols
   - `all_variables()`: list all variable symbols
6. Implement duplicate detection:
   - `define()` returns error if name exists in same scope
   - Different scopes can shadow (variables)
   - Passages are global (no shadowing)
7. Create symbol table builder visitor:
   - Traverse AST and populate symbol table
   - Enter/exit scopes at appropriate nodes
   - Define symbols for declarations
8. Write symbol table tests:
   - Define and lookup
   - Scope nesting
   - Shadowing behavior
   - Duplicate detection

### Outputs
- `lib/whisker/script/semantic/symbols.lua` (~200 lines)
- `tests/unit/script/semantic/symbols_spec.lua` (~180 lines)

### Acceptance Criteria
- [ ] Symbols store name, kind, position
- [ ] Scopes nest correctly
- [ ] Lookup searches parent scopes
- [ ] Duplicates in same scope detected
- [ ] Passages collected globally
- [ ] Variables can shadow in nested scopes
- [ ] All symbol table tests pass

### Estimated Scope
- **Production code:** 180-220 lines
- **Test code:** 160-200 lines
- **Estimated time:** 1.5-2 days

### Implementation Notes
**Pattern: Symbol Table Structure**
```lua
local Symbol = {}
Symbol.__index = Symbol

function Symbol.new(name, kind, position)
  return setmetatable({
    name = name,
    kind = kind,
    position = position,
    type_info = nil,
    references = {}
  }, Symbol)
end

function Symbol:add_reference(position)
  table.insert(self.references, position)
end
```

**Pattern: Scope with Parent Chain**
```lua
local Scope = {}
Scope.__index = Scope

function Scope.new(kind, parent)
  return setmetatable({
    kind = kind,
    parent = parent,
    symbols = {}
  }, Scope)
end

function Scope:define(name, symbol)
  if self.symbols[name] then
    return nil, "duplicate"
  end
  self.symbols[name] = symbol
  return symbol
end

function Scope:lookup(name)
  local sym = self.symbols[name]
  if sym then return sym end
  if self.parent then return self.parent:lookup(name) end
  return nil
end
```

---

## Stage 21: Reference Resolution and Semantic Validation

### Prerequisites
- Stage 20: Symbol table complete
- Stage 10: Visitor infrastructure

### Objectives
Implement the semantic analyzer that resolves references and validates semantic constraints. This catches errors like undefined passages, uninitialized variables, and type mismatches that syntax-correct code can still contain.

### Inputs
- `lib/whisker/script/semantic/symbols.lua` (symbol table)
- `lib/whisker/script/visitor.lua` (traversal)
- Error codes from Appendix D

### Tasks
1. Create `lib/whisker/script/semantic/init.lua` with:
   - `SemanticAnalyzer` class implementing `ISemanticAnalyzer`
   - `analyze(ast)` main method
2. Create `lib/whisker/script/semantic/resolver.lua` with:
   - Reference resolution visitor
   - Links references to their definitions
3. Implement passage reference resolution:
   - Every divert target must exist
   - Collect undefined passage errors
   - Suggest similar names (Levenshtein distance)
4. Implement variable resolution:
   - Variables should be assigned before use
   - Track variable initialization state
   - Warn on uninitialized read
5. Implement function resolution:
   - Built-in functions known
   - Check argument count
   - Unknown function = error
6. Create `lib/whisker/script/semantic/validator.lua` with:
   - Additional validation rules
7. Implement validation checks:
   - No duplicate passage names
   - Tunnel return only inside passage
   - Choice nesting limits (optional)
   - Unreachable passage detection (warning)
8. Build annotated AST:
   - Attach resolved symbols to reference nodes
   - Attach type information where inferred
9. Implement diagnostic collection:
   - Errors prevent code generation
   - Warnings allow code generation
   - Return all diagnostics
10. Write semantic analysis tests:
    - Undefined passage
    - Uninitialized variable
    - Unknown function
    - Duplicate passages
    - Valid story

### Outputs
- `lib/whisker/script/semantic/init.lua` (~100 lines)
- `lib/whisker/script/semantic/resolver.lua` (~160 lines)
- `lib/whisker/script/semantic/validator.lua` (~120 lines)
- Updated `lib/whisker/script/errors/codes.lua` (+30 lines)
- `tests/unit/script/semantic/resolver_spec.lua` (~180 lines)
- `tests/fixtures/script/semantic/` (valid and invalid scripts)

### Acceptance Criteria
- [ ] Undefined passages detected with suggestions
- [ ] Duplicate passages detected
- [ ] Uninitialized variable access flagged
- [ ] Unknown functions flagged with argument count
- [ ] Annotated AST has resolved references
- [ ] Errors and warnings collected
- [ ] Valid scripts produce no errors
- [ ] All semantic tests pass

### Estimated Scope
- **Production code:** 280-350 lines
- **Test code:** 160-200 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes
**Pattern: Resolution Visitor**
```lua
local ResolverVisitor = setmetatable({}, { __index = Visitor })

function ResolverVisitor.new(symbol_table)
  local self = Visitor.new()
  setmetatable(self, { __index = ResolverVisitor })
  self.symbols = symbol_table
  self.diagnostics = {}
  return self
end

function ResolverVisitor:visit_Divert(node)
  local passage = self.symbols:lookup_passage(node.target)
  if not passage then
    table.insert(self.diagnostics, {
      code = "WSK0040",
      message = "Undefined passage '" .. node.target .. "'",
      position = node.pos,
      suggestion = self:suggest_passage(node.target)
    })
  else
    node.resolved_target = passage
  end
end
```

**Pattern: Similar Name Suggestion**
```lua
function ResolverVisitor:suggest_passage(name)
  local passages = self.symbols:all_passages()
  local best = nil
  local best_dist = math.huge
  
  for _, p in ipairs(passages) do
    local dist = levenshtein_distance(name, p.name)
    if dist < best_dist and dist <= 3 then
      best = p
      best_dist = dist
    end
  end
  
  if best then
    return "Did you mean '" .. best.name .. "'? (defined at line " .. best.position.line .. ")"
  end
  return nil
end
```

---

## Stage 22: Code Generator — Basic IR Emission

### Prerequisites
- Stage 20-21: Semantic analysis complete
- Knowledge of Whisker internal story format

### Objectives
Implement the code generator that transforms an annotated AST into Whisker's internal representation (Story, Passage, Choice objects). This stage handles the core constructs; advanced features come in Stage 23.

### Inputs
- `lib/whisker/script/semantic/` (annotated AST)
- `lib/whisker/core/` (Story, Passage, Choice)
- `lib/whisker/script/generator/` (directory structure)

### Tasks
1. Create `lib/whisker/script/generator/init.lua` with:
   - `CodeGenerator` class implementing `ICodeGenerator`
   - `generate(ast)` main method returning Story
2. Create `lib/whisker/script/generator/emitter.lua` with:
   - IR emission visitor
   - Node-to-IR translation methods
3. Implement Story generation:
   - Create Story object with metadata
   - Collect generated passages
   - Set start passage
4. Implement Passage generation:
   - Create Passage with id, content, choices
   - Flatten nested statements into content
   - Collect inline expressions
5. Implement Choice generation:
   - Create Choice with text, condition, target
   - Handle nested choice content
   - Evaluate conditions at runtime
6. Implement text content generation:
   - Plain text becomes content strings
   - Inline expressions become placeholders
   - Content is array of mixed elements
7. Implement divert generation:
   - Simple divert sets next passage
   - Target resolved to passage id
8. Implement variable reference generation:
   - Create variable access expressions
   - Support indexed access
9. Implement literal generation:
   - Numbers, strings, booleans, null
   - Lists as Lua tables
10. Write code generator tests:
    - Simple passage with text
    - Passage with choices
    - Variables and inline expressions
    - Compare to expected IR structure

### Outputs
- `lib/whisker/script/generator/init.lua` (~60 lines)
- `lib/whisker/script/generator/emitter.lua` (~250 lines)
- `tests/unit/script/generator/basic_spec.lua` (~200 lines)
- `tests/fixtures/script/generator/` (input/expected pairs)

### Acceptance Criteria
- [ ] Story object created from script
- [ ] Passages have correct id, content, choices
- [ ] Choices have text, condition, target
- [ ] Diverts set next passage correctly
- [ ] Inline expressions in content
- [ ] Variables resolve to runtime access
- [ ] All basic generator tests pass

### Estimated Scope
- **Production code:** 250-300 lines
- **Test code:** 180-220 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes
**Pattern: Code Generator Structure**
```lua
local CodeGenerator = {}
CodeGenerator.__index = CodeGenerator

function CodeGenerator.new()
  return setmetatable({
    story = nil,
    current_passage = nil,
    diagnostics = {}
  }, CodeGenerator)
end

function CodeGenerator:generate(ast)
  self.story = Story.new({
    title = self:extract_metadata(ast, "title"),
    author = self:extract_metadata(ast, "author")
  })
  
  for _, passage_node in ipairs(ast.passages) do
    local passage = self:emit_passage(passage_node)
    self.story:add_passage(passage)
  end
  
  return self.story
end
```

**Pattern: Passage Emission**
```lua
function CodeGenerator:emit_passage(node)
  local passage = Passage.new({
    id = node.name,
    tags = node.tags
  })
  
  self.current_passage = passage
  
  local content = {}
  local choices = {}
  
  for _, stmt in ipairs(node.body) do
    if stmt.type == "Choice" then
      table.insert(choices, self:emit_choice(stmt))
    else
      local emitted = self:emit_statement(stmt)
      if emitted then
        table.insert(content, emitted)
      end
    end
  end
  
  passage.content = content
  passage.choices = choices
  
  return passage
end
```

---

## Stage 23: Code Generator — Advanced Constructs and Source Maps

### Prerequisites
- Stage 22: Basic code generation complete

### Objectives
Complete the code generator with advanced constructs (conditionals, tunnels, threads) and source map generation. Source maps enable runtime errors to reference original source positions, crucial for debugging.

### Inputs
- `lib/whisker/script/generator/emitter.lua` (basic emitter)
- `lib/whisker/script/source.lua` (source positions)
- Conditional and flow control nodes

### Tasks
1. Implement conditional generation:
   - Generate runtime conditional checks
   - Build content for each branch
   - Generate else fallback
2. Implement compound assignment generation:
   - Expand `+=` to get + add + set
   - Handle all compound operators
3. Implement list append generation:
   - `$list[] = value` becomes list push
   - Generate appropriate runtime code
4. Implement tunnel generation:
   - Tunnel calls save return point
   - Tunnel returns restore and continue
   - Track call stack for debugging
5. Implement thread generation:
   - Thread starts spawn parallel content
   - Threads collect at gather points
   - Complex runtime coordination
6. Create `lib/whisker/script/generator/sourcemap.lua` with:
   - SourceMap class
   - Mappings from IR positions to source positions
7. Implement source map generation:
   - Track source position during emission
   - Record mapping for each IR element
   - Support source map standard format
8. Implement `generate_with_sourcemap()`:
   - Returns both Story and SourceMap
   - Source map serializable to JSON
9. Write advanced generator tests:
   - Conditional blocks
   - Compound assignments
   - Tunnel call/return
   - Source map verification

### Outputs
- Updated `lib/whisker/script/generator/emitter.lua` (+150 lines)
- `lib/whisker/script/generator/sourcemap.lua` (~120 lines)
- `tests/unit/script/generator/advanced_spec.lua` (~180 lines)
- `tests/unit/script/generator/sourcemap_spec.lua` (~100 lines)

### Acceptance Criteria
- [ ] Conditionals generate runtime branches
- [ ] Compound assignments expand correctly
- [ ] Tunnels track call stack
- [ ] Source maps link IR to source
- [ ] Source map format is standard/documented
- [ ] All advanced generator tests pass

### Estimated Scope
- **Production code:** 220-270 lines
- **Test code:** 220-280 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes
**Pattern: Conditional Generation**
```lua
function CodeGenerator:emit_conditional(node)
  local condition_block = {
    type = "conditional",
    branches = {},
    else_branch = nil
  }
  
  for _, branch in ipairs(node.branches) do
    table.insert(condition_block.branches, {
      condition = self:emit_expression(branch.condition),
      content = self:emit_statements(branch.body)
    })
  end
  
  if node.else_branch then
    condition_block.else_branch = self:emit_statements(node.else_branch)
  end
  
  return condition_block
end
```

**Pattern: Source Map Recording**
```lua
function CodeGenerator:record_mapping(ir_element, source_node)
  if self.source_map and source_node.pos then
    self.source_map:add_mapping({
      generated_line = ir_element.line or 0,
      generated_column = ir_element.column or 0,
      source_line = source_node.pos.line,
      source_column = source_node.pos.column,
      name = source_node.name  -- Optional
    })
  end
end
```

---

## Stage 24: IFormat Implementation and Integration

### Prerequisites
- Stage 22-23: Code generator complete
- Phase 1 IFormat interface

### Objectives
Create the IFormat implementation that exposes Whisker Script as a first-class format handler in whisker-core. This enables using `.wsk` files anywhere other formats are used, and provides round-trip export capability.

### Inputs
- `lib/whisker/script/` (complete compiler)
- `lib/whisker/interfaces/format.lua` (IFormat)
- Phase 2 format handler patterns

### Tasks
1. Create `lib/whisker/script/format.lua` with:
   - `WhiskerScriptFormat` implementing `IFormat`
   - All required interface methods
2. Implement `can_import(source)`:
   - Detect Whisker Script syntax
   - Check for characteristic patterns (`::`, `+`, `~`)
   - Handle ambiguous cases
3. Implement `import(source)`:
   - Invoke full compiler pipeline
   - Handle compilation errors
   - Return Story object or throw
4. Implement `can_export(story)`:
   - Check if story has required structure
   - Return true for compatible stories
5. Implement `export(story)`:
   - Generate Whisker Script source from Story
   - Preserve passage order
   - Format choices and conditionals
6. Create source code generator:
   - Inverse of parser
   - Pretty-print with proper indentation
   - Round-trip should preserve semantics
7. Implement format registration:
   - Register with container as `format.whisker`
   - Declare capability
   - Register file extension `.wsk`
8. Add format event emissions:
   - Emit events at import/export
   - Enable extension points
9. Write format integration tests:
   - Import .wsk file
   - Export Story to .wsk
   - Round-trip preservation
   - Format detection

### Outputs
- `lib/whisker/script/format.lua` (~180 lines)
- `lib/whisker/script/writer.lua` (~200 lines) — source code generator
- `tests/unit/script/format_spec.lua` (~160 lines)
- `tests/integration/script/roundtrip_spec.lua` (~120 lines)
- `tests/contracts/script/format_contract.lua` (~80 lines)

### Acceptance Criteria
- [ ] `can_import()` correctly detects .wsk syntax
- [ ] `import()` compiles and returns Story
- [ ] `export()` generates valid .wsk source
- [ ] Round-trip produces equivalent AST
- [ ] Format registered with container
- [ ] IFormat contract tests pass
- [ ] All format tests pass

### Estimated Scope
- **Production code:** 320-400 lines
- **Test code:** 280-360 lines
- **Estimated time:** 2-2.5 days

### Implementation Notes
**Pattern: IFormat Implementation**
```lua
local WhiskerScriptFormat = {}
setmetatable(WhiskerScriptFormat, { __index = IFormat })

function WhiskerScriptFormat:can_import(source)
  -- Look for characteristic syntax
  return source:match("^%s*::") ~= nil or
         source:match("^%s*@@") ~= nil or
         source:match("\n::") ~= nil
end

function WhiskerScriptFormat:import(source)
  local compiler = self.container:resolve("compiler.whisker")
  local result = compiler:compile(source)
  
  if result.errors and #result.errors > 0 then
    error(self:format_errors(result.errors))
  end
  
  return result.story
end

function WhiskerScriptFormat:export(story)
  local writer = WhiskerScriptWriter.new()
  return writer:write(story)
end
```

**Pattern: Source Code Writer**
```lua
local WhiskerScriptWriter = {}

function WhiskerScriptWriter:write(story)
  local lines = {}
  
  -- Metadata
  for key, value in pairs(story.metadata or {}) do
    table.insert(lines, string.format("@@ %s: %s", key, self:format_value(value)))
  end
  
  if #lines > 0 then
    table.insert(lines, "")  -- Blank line after metadata
  end
  
  -- Passages
  for _, passage in ipairs(story.passages) do
    self:write_passage(lines, passage)
  end
  
  return table.concat(lines, "\n")
end
```

---

## Stage 25: Error Message Polish, Language Spec, and Tutorials

### Prerequisites
- Stages 01-24: All implementation complete

### Objectives
Final polish phase: review and improve all error messages, create comprehensive language specification documentation, and write tutorials for writers adopting Whisker Script. This stage ensures the language is well-documented and user-friendly.

### Inputs
- All error messages from stages 08, 11, 21
- Complete grammar and syntax examples
- User feedback from testing (if available)

### Tasks
1. Review all error messages:
   - Consistent tone and terminology
   - All use narrative terms (passage, choice, not function, branch)
   - Suggestions provided where possible
   - Messages are actionable
2. Improve error suggestions:
   - Better typo detection (Levenshtein)
   - Context-aware suggestions
   - Common mistake patterns
3. Create `docs/WHISKER_SCRIPT.md` specification:
   - Complete syntax reference
   - All constructs with examples
   - Grammar in EBNF
   - Semantic rules
4. Create `docs/WHISKER_SCRIPT_TUTORIAL.md`:
   - Getting started guide
   - Progressive complexity examples
   - Common patterns
   - Comparison to Ink for familiar users
5. Create `docs/WHISKER_SCRIPT_REFERENCE.md`:
   - Quick reference card
   - All syntax in compact form
   - Error code reference
   - Built-in function reference
6. Create example stories:
   - `examples/script/hello.wsk` — minimal example
   - `examples/script/tutorial.wsk` — tutorial story
   - `examples/script/advanced.wsk` — advanced features
7. Review and update error code catalog:
   - All codes documented
   - Consistent numbering
   - Grouped by category
8. Final test review:
   - Verify all features tested
   - Add missing edge case tests
   - Integration test coverage

### Outputs
- Updated `lib/whisker/script/errors/messages.lua` (review/polish)
- `docs/WHISKER_SCRIPT.md` (~1500-2000 lines)
- `docs/WHISKER_SCRIPT_TUTORIAL.md` (~800-1000 lines)
- `docs/WHISKER_SCRIPT_REFERENCE.md` (~400 lines)
- `examples/script/hello.wsk`
- `examples/script/tutorial.wsk`
- `examples/script/advanced.wsk`
- Updated test coverage

### Acceptance Criteria
- [ ] All error messages reviewed and polished
- [ ] Language spec is complete and accurate
- [ ] Tutorial enables new users to learn
- [ ] Reference provides quick lookups
- [ ] Example stories work correctly
- [ ] All error codes documented
- [ ] Test coverage meets targets (90% overall)

### Estimated Scope
- **Documentation:** 2500-3500 lines
- **Example code:** 200-300 lines
- **Test additions:** 100-150 lines
- **Estimated time:** 2-3 days

### Implementation Notes
**Error Message Style Guide:**
- Start with what went wrong: "Undefined passage reference"
- Include the specific name: "'NorthRoom'"
- Provide context: "at line 15"
- Suggest fix: "Did you mean 'NorthChamber'?"
- Use narrative terms: "passage" not "symbol"

**Tutorial Structure:**
1. First Story (10 lines, no variables)
2. Adding Choices (choices and diverts)
3. Using Variables (assignment and interpolation)
4. Conditional Content (if/else blocks)
5. Inline Conditionals (dynamic text)
6. Organizing Stories (includes, tunnels)
7. Advanced Patterns (threads, functions)

---

## Appendix A: Whisker Script Grammar (EBNF)

```ebnf
(* Top-level structure *)
script          = { metadata | include | passage } ;
metadata        = "@@" identifier ":" value NEWLINE ;
include         = ">>" ( "include" | "import" ) string [ "as" identifier ] NEWLINE ;
passage         = "::" identifier [ tags ] NEWLINE { statement } ;
tags            = "[" identifier { "," identifier } "]" ;

(* Statements *)
statement       = text_line 
                | choice 
                | assignment 
                | conditional 
                | divert 
                | tunnel_call 
                | tunnel_return 
                | thread_start ;

text_line       = { TEXT | inline_expr } NEWLINE ;

choice          = "+" [ condition ] "[" choice_text "]" [ divert ] NEWLINE 
                  [ INDENT { statement } DEDENT ] ;

assignment      = "~" variable_ref assignment_op expression NEWLINE ;
assignment_op   = "=" | "+=" | "-=" | "*=" | "/=" ;

conditional     = "{" condition ":" NEWLINE 
                  INDENT { statement } DEDENT 
                  { elif_branch } 
                  [ else_branch ] 
                  "}" ;
elif_branch     = "-" condition ":" NEWLINE INDENT { statement } DEDENT ;
else_branch     = "-" "else" ":" NEWLINE INDENT { statement } DEDENT ;

divert          = "->" identifier ;
tunnel_call     = "->->" identifier ;
tunnel_return   = "->->" ;
thread_start    = "<-" identifier ;

(* Choice text and inline expressions *)
choice_text     = { TEXT | inline_expr } ;
inline_expr     = "{" expression "}" 
                | "{" condition ":" inline_text [ "|" inline_text ] "}" ;
inline_text     = { TEXT | inline_expr } ;
condition       = expression ;

(* Expressions — precedence from lowest to highest *)
expression      = or_expr ;
or_expr         = and_expr { "or" and_expr } ;
and_expr        = equality_expr { "and" equality_expr } ;
equality_expr   = comparison_expr { ( "==" | "!=" ) comparison_expr } ;
comparison_expr = additive_expr { ( "<" | ">" | "<=" | ">=" ) additive_expr } ;
additive_expr   = multiplicative_expr { ( "+" | "-" ) multiplicative_expr } ;
multiplicative_expr = unary_expr { ( "*" | "/" | "%" ) unary_expr } ;
unary_expr      = [ "not" | "-" ] postfix_expr ;
postfix_expr    = primary_expr { "[" expression "]" | "(" arguments ")" } ;
primary_expr    = literal | variable_ref | identifier | "(" expression ")" ;

(* Literals and references *)
literal         = NUMBER | STRING | "true" | "false" | "null" | list_literal ;
list_literal    = "[" [ expression { "," expression } ] "]" ;
variable_ref    = "$" identifier [ "[" expression "]" ] ;
arguments       = [ expression { "," expression } ] ;

(* Lexical elements *)
identifier      = ALPHA { ALPHA | DIGIT | "_" } ;
ALPHA           = "a".."z" | "A".."Z" | "_" ;
DIGIT           = "0".."9" ;
NUMBER          = DIGIT { DIGIT } [ "." DIGIT { DIGIT } ] ;
STRING          = '"' { any_char - '"' | escape_seq } '"' ;
escape_seq      = "\\" ( '"' | "\\" | "n" | "t" ) ;
TEXT            = (* non-special characters in text context *) ;
NEWLINE         = "\n" | "\r\n" ;
COMMENT         = "#" { any_char - NEWLINE } NEWLINE ;
BLOCK_COMMENT   = "##" { any_char - NEWLINE } NEWLINE 
                  { "##" { any_char - NEWLINE } NEWLINE } ;
```

---

## Appendix B: Token Reference

| Token Type | Pattern | Example | Notes |
|------------|---------|---------|-------|
| `PASSAGE_DECL` | `::` | `:: Start` | Passage declaration marker |
| `CHOICE` | `+` | `+ [Go north]` | Choice marker (line start) |
| `DIVERT` | `->` | `-> NextPassage` | Navigation divert |
| `TUNNEL` | `->->` | `->-> SubRoutine` | Tunnel call/return |
| `THREAD` | `<-` | `<- Background` | Thread start |
| `ASSIGN` | `~` | `~ $x = 5` | Variable assignment marker |
| `METADATA` | `@@` | `@@ title: Story` | Metadata marker |
| `INCLUDE` | `>>` | `>> include "f.wsk"` | Include/import marker |
| `VARIABLE` | `$[a-zA-Z_][a-zA-Z0-9_]*` | `$player_name` | Variable reference |
| `LBRACE` | `{` | `{ $cond: ... }` | Block/interpolation start |
| `RBRACE` | `}` | `}` | Block/interpolation end |
| `LBRACKET` | `[` | `[choice text]` | Choice text, list start |
| `RBRACKET` | `]` | `]` | Choice text, list end |
| `LPAREN` | `(` | `fn(args)` | Function call, grouping |
| `RPAREN` | `)` | `)` | Grouping end |
| `COLON` | `:` | `{cond:` | Condition separator |
| `PIPE` | `\|` | `{c: a \| b}` | Inline else separator |
| `COMMA` | `,` | `fn(a, b)` | Argument separator |
| `DASH` | `-` | `- else:` | Elif/else marker (line start) |
| `EQ` | `=` | `$x = 5` | Assignment |
| `PLUS_EQ` | `+=` | `$x += 1` | Compound add |
| `MINUS_EQ` | `-=` | `$x -= 1` | Compound subtract |
| `STAR_EQ` | `*=` | `$x *= 2` | Compound multiply |
| `SLASH_EQ` | `/=` | `$x /= 2` | Compound divide |
| `EQ_EQ` | `==` | `$x == 5` | Equality comparison |
| `BANG_EQ` | `!=` | `$x != 5` | Inequality comparison |
| `LT` | `<` | `$x < 5` | Less than |
| `GT` | `>` | `$x > 5` | Greater than |
| `LT_EQ` | `<=` | `$x <= 5` | Less or equal |
| `GT_EQ` | `>=` | `$x >= 5` | Greater or equal |
| `PLUS` | `+` | `$x + 1` | Addition (in expression) |
| `MINUS` | `-` | `$x - 1` | Subtraction (in expression) |
| `STAR` | `*` | `$x * 2` | Multiplication |
| `SLASH` | `/` | `$x / 2` | Division |
| `PERCENT` | `%` | `$x % 2` | Modulo |
| `AND` | `and` | `$a and $b` | Logical and |
| `OR` | `or` | `$a or $b` | Logical or |
| `NOT` | `not` | `not $flag` | Logical not |
| `TRUE` | `true` | `$flag = true` | Boolean literal |
| `FALSE` | `false` | `$flag = false` | Boolean literal |
| `NULL` | `null` | `$x = null` | Null literal |
| `ELSE` | `else` | `- else:` | Else keyword |
| `INCLUDE_KW` | `include` | `>> include` | Include keyword |
| `IMPORT_KW` | `import` | `>> import` | Import keyword |
| `AS` | `as` | `import x as y` | Alias keyword |
| `IDENTIFIER` | `[a-zA-Z_][a-zA-Z0-9_]*` | `passage_name` | Names/identifiers |
| `NUMBER` | `[0-9]+(\.[0-9]+)?` | `42`, `3.14` | Numeric literal |
| `STRING` | `"[^"]*"` | `"hello"` | String literal |
| `TEXT` | *(narrative content)* | Plain prose | Non-special text |
| `NEWLINE` | `\n`, `\r\n` | | Line terminator |
| `INDENT` | *(synthetic)* | | Indentation increase |
| `DEDENT` | *(synthetic)* | | Indentation decrease |
| `COMMENT` | `#...` | `# note` | Single-line comment |
| `EOF` | *(end of input)* | | End of file |
| `ERROR` | *(invalid input)* | | Lexer error token |

---

## Appendix C: AST Node Catalog

```lua
-- Base node structure (all nodes include these)
Node = {
  type = "NodeType",           -- Discriminator string
  pos = SourcePosition,        -- Start position in source
  end_pos = SourcePosition,    -- End position (optional)
}

-- ============================================
-- Top-level Nodes
-- ============================================

ScriptNode = {
  type = "Script",
  metadata = MetadataNode[],   -- @@ declarations
  includes = IncludeNode[],    -- >> directives
  passages = PassageNode[],    -- :: passages
}

MetadataNode = {
  type = "Metadata",
  key = string,                -- Metadata key
  value = ExpressionNode,      -- Value expression
}

IncludeNode = {
  type = "Include",
  kind = "include" | "import", -- Include vs import
  path = string,               -- File path
  alias = string | nil,        -- Import alias (for import only)
}

PassageNode = {
  type = "Passage",
  name = string,               -- Passage identifier
  tags = string[],             -- Optional tags
  body = StatementNode[],      -- Passage content
}

-- ============================================
-- Statement Nodes
-- ============================================

TextNode = {
  type = "Text",
  content = (string | InlineExprNode)[],  -- Mixed text/expression
}

ChoiceNode = {
  type = "Choice",
  condition = ExpressionNode | nil,  -- Optional condition
  text = (string | InlineExprNode)[], -- Choice display text
  target = DivertNode | nil,          -- Inline divert target
  nested = StatementNode[],           -- Nested content
}

AssignmentNode = {
  type = "Assignment",
  target = VariableRefNode,           -- Variable being assigned
  operator = "=" | "+=" | "-=" | "*=" | "/=",
  value = ExpressionNode,             -- Value expression
}

ConditionalNode = {
  type = "Conditional",
  branches = ConditionalBranchNode[], -- If and elif branches
  else_branch = StatementNode[] | nil, -- Optional else body
}

ConditionalBranchNode = {
  type = "ConditionalBranch",
  condition = ExpressionNode,         -- Branch condition
  body = StatementNode[],             -- Branch content
}

DivertNode = {
  type = "Divert",
  target = string,                    -- Target passage name
  resolved_target = Symbol | nil,     -- Resolved after semantic analysis
}

TunnelCallNode = {
  type = "TunnelCall",
  target = string,                    -- Target passage name
}

TunnelReturnNode = {
  type = "TunnelReturn",
  -- No fields (bare ->->)
}

ThreadStartNode = {
  type = "ThreadStart",
  target = string,                    -- Target passage name
}

-- ============================================
-- Expression Nodes
-- ============================================

BinaryExprNode = {
  type = "BinaryExpr",
  operator = string,                  -- Operator symbol
  left = ExpressionNode,              -- Left operand
  right = ExpressionNode,             -- Right operand
}

UnaryExprNode = {
  type = "UnaryExpr",
  operator = "not" | "-",             -- Unary operator
  operand = ExpressionNode,           -- Operand
}

VariableRefNode = {
  type = "VariableRef",
  name = string,                      -- Variable name (without $)
  index = ExpressionNode | nil,       -- Optional index for $list[i]
  resolved_symbol = Symbol | nil,     -- Resolved after semantic analysis
}

FunctionCallNode = {
  type = "FunctionCall",
  name = string,                      -- Function name
  arguments = ExpressionNode[],       -- Argument expressions
}

LiteralNode = {
  type = "Literal",
  value_type = "number" | "string" | "boolean" | "null",
  value = any,                        -- Lua value
}

ListLiteralNode = {
  type = "ListLiteral",
  elements = ExpressionNode[],        -- List elements
}

InlineExprNode = {
  type = "InlineExpr",
  expression = ExpressionNode,        -- The expression to evaluate
}

InlineConditionalNode = {
  type = "InlineConditional",
  condition = ExpressionNode,         -- Condition to evaluate
  then_text = (string | InlineExprNode)[],  -- If true
  else_text = (string | InlineExprNode)[] | nil,  -- If false
}

-- ============================================
-- Source Tracking
-- ============================================

SourcePosition = {
  line = number,                      -- 1-indexed line number
  column = number,                    -- 1-indexed column number
  offset = number,                    -- 0-indexed byte offset
}

SourceSpan = {
  start = SourcePosition,             -- Span start
  end_pos = SourcePosition,           -- Span end (exclusive)
}
```

---

## Appendix D: Error Message Catalog

### Lexer Errors (WSK0001-WSK0009)

| Code | Message Template | Suggestion |
|------|------------------|------------|
| `WSK0001` | Unexpected character '{char}' | Remove or escape this character |
| `WSK0002` | Unterminated string starting at line {line} | Add closing quote " |
| `WSK0003` | Invalid number format '{text}' | Check decimal point placement |
| `WSK0004` | Invalid escape sequence '\\{char}' | Use \\n, \\t, \\", or \\\\ |
| `WSK0005` | Unexpected end of input | Check for missing closing quotes or brackets |

### Parser Errors — Structure (WSK0010-WSK0019)

| Code | Message Template | Suggestion |
|------|------------------|------------|
| `WSK0010` | Expected passage declaration (::) | Start passages with ':: PassageName' |
| `WSK0011` | Expected passage name after '::' | Add a name: ':: MyPassage' |
| `WSK0012` | Expected ']' after choice text | Close the choice: '+ [text]' |
| `WSK0013` | Expected expression after '{$' | Complete: {$variable} or {condition:} |
| `WSK0014` | Expected ':' after condition | Add colon: {$cond: text} |
| `WSK0015` | Unclosed conditional block | Add closing '}' |
| `WSK0016` | Expected 'include' or 'import' after '>>' | Use: >> include "file.wsk" |
| `WSK0017` | Expected file path after include/import | Add path: >> include "path.wsk" |
| `WSK0018` | Expected identifier after 'as' | Add alias: >> import "x.wsk" as name |
| `WSK0019` | Unexpected token in passage body | Check syntax at this location |

### Parser Errors — Expressions (WSK0020-WSK0039)

| Code | Message Template | Suggestion |
|------|------------------|------------|
| `WSK0020` | Invalid divert target '{name}' | Passage names must be identifiers |
| `WSK0021` | Expected passage name after '->' | Add target: -> PassageName |
| `WSK0022` | Expected ')' after function arguments | Close parenthesis: fn(a, b) |
| `WSK0023` | Expected expression | Add value after operator |
| `WSK0024` | Expected ')' after grouped expression | Close parenthesis |
| `WSK0025` | Expected ']' after list elements | Close bracket: [a, b, c] |
| `WSK0030` | Expected '=' or compound assignment after variable | Use: ~ $var = value |
| `WSK0031` | Invalid left-hand side for assignment | Can only assign to $variables |
| `WSK0032` | Expected ']' after variable index | Close bracket: $list[index] |

### Semantic Errors (WSK0040-WSK0059)

| Code | Message Template | Suggestion |
|------|------------------|------------|
| `WSK0040` | Undefined passage '{name}' | Declare with ':: {name}' or check spelling |
| `WSK0041` | Undefined variable '{name}' | Assign first with '~ ${name} = value' |
| `WSK0042` | Undefined function '{name}' | Check spelling or use built-in function |
| `WSK0043` | Duplicate passage name '{name}' | Rename one of the passages |
| `WSK0044` | Circular include detected: {path} | Break the circular dependency |
| `WSK0045` | File not found: '{path}' | Check the file path |
| `WSK0050` | Type mismatch: expected {expected}, got {actual} | Check your expression types |
| `WSK0051` | Cannot index non-list variable '{name}' | Remove [index] or use a list |
| `WSK0052` | Wrong argument count for '{name}': expected {n}, got {m} | Adjust argument count |
| `WSK0053` | Tunnel return outside of passage | ->-> can only be used inside a passage |

### Warnings (WSK0060-WSK0069)

| Code | Message Template | Suggestion |
|------|------------------|------------|
| `WSK0060` | Unreachable passage '{name}' | Add a divert to this passage or remove it |
| `WSK0061` | Variable '{name}' assigned but never read | Use the variable or remove assignment |
| `WSK0062` | Choice has no effect | Add -> target or nested statements |
| `WSK0063` | Condition always true/false | Simplify the conditional |
| `WSK0064` | Empty passage '{name}' | Add content to the passage |

---

## Testing Strategy Summary

### By Stage Group

| Group | Testing Focus | Key Patterns |
|-------|---------------|--------------|
| **A-B (Lexer)** | Token snapshots, source positions, error tokens | Property-based roundtrip testing |
| **C-D (Parser basics)** | AST structure, error messages, recovery | Snapshot tests for AST |
| **E (Advanced parsing)** | Complex constructs, nesting, edge cases | Fixture-based testing |
| **F (Semantic)** | Symbol resolution, error detection | Fixtures with deliberate errors |
| **G (Codegen)** | IR structure, roundtrip | Compare to expected Story objects |
| **H (Polish)** | Error message quality, docs accuracy | Review and manual testing |

### Coverage Targets

| Component | Target |
|-----------|--------|
| `script/lexer/*` | 95% |
| `script/parser/*` | 90% |
| `script/semantic/*` | 90% |
| `script/generator/*` | 85% |
| `script/errors/*` | 80% |
| **Overall** | 90% |

---

## Cross-References

- **Phase 1:** Module loader pattern (`lib/whisker/kernel/loader.lua`), interface definitions (`lib/whisker/interfaces/`)
- **Phase 2:** Format handler pattern (`lib/whisker/formats/ink/`), round-trip testing pattern
- **Roadmap Section 0.5:** File organization for modularity
- **Roadmap Section 0.9:** Testing philosophy and contract test patterns
- **Roadmap Appendix C:** Whisker Script quick reference (syntax examples)

---

*This document defines 25 implementation stages for Phase 3 of the whisker-core project. Each stage builds upon previous stages and culminates in a complete, well-tested, and documented Whisker Script language implementation.*
