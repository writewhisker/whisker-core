# Claude Instructions for whisker-core Phase 3

## Project Overview

**Repository:** https://github.com/writewhisker/whisker-core  
**Current Phase:** Phase 3 — Whisker Script Language  
**Language:** Lua (5.1, 5.2, 5.3, 5.4, LuaJIT compatible)  
**Architecture:** Microkernel with dependency injection, event bus, interface-first design

whisker-core is a Lua-based interactive fiction framework. Phase 3 implements Whisker Script—a domain-specific language for authoring interactive fiction stories. The compiler pipeline includes lexer, parser, semantic analyzer, and code generator.

## Phase 3 Context

You are implementing a complete compiler for the Whisker Script language. This phase builds on:

- **Phase 1 (Complete):** Microkernel, DI container, event bus, interfaces, module loader
- **Phase 2 (Complete):** Ink format integration via tinta library, IFormat patterns

### Key Deliverables
- Lexer that tokenizes `.wsk` source files
- Parser that builds AST from token stream
- Semantic analyzer for reference resolution and validation
- Code generator producing Story/Passage/Choice IR
- IFormat implementation for whisker-core integration
- Comprehensive error reporting with suggestions

## Architecture Principles

### 1. Interface-First Design
Always define interfaces before implementations. Every component depends on interfaces, not concrete classes.

```lua
-- CORRECT: Depend on interface
local format = whisker.container:resolve("IFormat", "whisker")

-- INCORRECT: Direct require
local WhiskerFormat = require("whisker.script.format")
```

### 2. Dependency Injection
Components receive dependencies through the container, not direct requires.

```lua
-- Registration
whisker.container:register("compiler.whisker", WhiskerCompiler, {
  implements = "IScriptCompiler",
  depends = { "lexer.whisker", "parser.whisker" }
})

-- Resolution (dependencies auto-injected)
local compiler = whisker.container:resolve("compiler.whisker")
```

### 3. Event-Driven Communication
Use events for cross-module communication, not direct calls.

```lua
-- Emit events at pipeline stages
whisker.events:emit("script:tokenize:complete", { tokens = tokens })
whisker.events:emit("script:parse:complete", { ast = ast })
```

### 4. Error Accumulation
Collect errors instead of throwing on first error. This enables reporting multiple issues in one pass.

```lua
-- CORRECT: Accumulate errors
function Lexer:error_token(code, message)
  table.insert(self.errors, { code = code, message = message, pos = self.pos })
  return Token.new(TokenType.ERROR, "", nil, self.pos)
end

-- INCORRECT: Throw immediately
function Lexer:error_token(code, message)
  error(message)  -- Don't do this
end
```

## File Structure

```
lib/whisker/script/
├── init.lua                 # Module entry, public API, container registration
├── interfaces.lua           # IScriptCompiler, ILexer, IParser, etc.
├── source.lua               # SourcePosition, SourceSpan, SourceFile
├── visitor.lua              # AST visitor base class
├── lexer/
│   ├── init.lua             # Lexer public interface
│   ├── tokens.lua           # TokenType enum, Token class
│   ├── scanner.lua          # Character-level scanning
│   ├── lexer.lua            # Main lexer implementation
│   ├── stream.lua           # TokenStream class
│   ├── rules.lua            # Tokenization rules
│   └── errors.lua           # Lexer-specific errors
├── parser/
│   ├── init.lua             # Parser public interface
│   ├── ast.lua              # AST node definitions
│   ├── grammar.lua          # Grammar rule implementations
│   └── recovery.lua         # Error recovery strategies
├── semantic/
│   ├── init.lua             # SemanticAnalyzer interface
│   ├── symbols.lua          # SymbolTable, Scope, Symbol
│   ├── resolver.lua         # Reference resolution
│   └── validator.lua        # Semantic validation rules
├── generator/
│   ├── init.lua             # CodeGenerator interface
│   ├── emitter.lua          # IR emission logic
│   └── sourcemap.lua        # Source map generation
├── errors/
│   ├── init.lua             # Error system interface
│   ├── codes.lua            # Error code definitions (WSK0001, etc.)
│   ├── messages.lua         # Human-readable message templates
│   └── reporter.lua         # Error formatting
├── format.lua               # IFormat implementation
└── writer.lua               # Source code generator (for export)

tests/
├── unit/script/
│   ├── lexer/
│   ├── parser/
│   ├── semantic/
│   └── generator/
├── integration/script/
├── contracts/script/
└── fixtures/script/
```

## Code Conventions

### Lua Style
- 2-space indentation
- Local variables preferred over globals
- Use `local M = {}` module pattern
- Return module table at end of file
- Use metatables for OOP patterns

```lua
-- Module pattern
local M = {}

local PrivateClass = {}
PrivateClass.__index = PrivateClass

function PrivateClass.new()
  return setmetatable({}, PrivateClass)
end

function M.create()
  return PrivateClass.new()
end

return M
```

### Naming Conventions
- `snake_case` for functions and variables
- `PascalCase` for classes/constructors
- `SCREAMING_SNAKE_CASE` for constants
- Prefix private functions with underscore: `_helper_function`

### Error Codes
- Format: `WSK` + 4-digit number
- Ranges:
  - `WSK0001-WSK0009`: Lexer errors
  - `WSK0010-WSK0039`: Parser errors
  - `WSK0040-WSK0059`: Semantic errors
  - `WSK0060-WSK0069`: Warnings

## Stage Implementation Workflow

### PR Requirements

**Before creating a PR for any stage, ALL of the following must be true:**

1. **All tests pass** — Run `busted` and verify 0 failures
2. **Stage acceptance criteria met** — Every checkbox in the stage's acceptance criteria must be satisfied
3. **No regressions** — All tests from previous stages continue to pass
4. **Coverage maintained** — Code coverage does not drop below targets
5. **Linting passes** — Run `luacheck lib/whisker/script/` with no errors

```bash
# Pre-PR checklist commands
luacheck lib/whisker/script/          # Linting
busted                                 # All tests
busted --coverage                      # Coverage check
```

### Stage Completion Checklist

For each stage, follow this workflow:

1. **Read the stage specification** — Understand prerequisites, objectives, and acceptance criteria
2. **Create feature branch** — `git checkout -b phase3/stage-NN-description`
3. **Implement production code** — Create/modify files listed in Outputs
4. **Write tests alongside code** — Don't defer testing; write tests as you implement
5. **Run tests frequently** — `busted tests/unit/script/` after each significant change
6. **Verify acceptance criteria** — Check every criterion before considering the stage complete
7. **Run full test suite** — `busted` to ensure no regressions
8. **Check coverage** — `busted --coverage` meets targets
9. **Create PR** — Only after all tests pass and criteria are met

### Test-Driven Development

When implementing a stage:

```
1. Write a failing test for the next piece of functionality
2. Write minimal code to make the test pass
3. Refactor if needed (tests must still pass)
4. Repeat until stage acceptance criteria are met
```

### Handling Test Failures

If tests fail during implementation:

- **Fix immediately** — Do not proceed with more features until tests pass
- **Investigate root cause** — Don't just patch the symptom
- **Check for regressions** — Ensure fix doesn't break other tests
- **Add regression test** — If bug was found, add test to prevent recurrence

### PR Description Template

```markdown
## Stage [NN]: [Title]

### Summary
Brief description of what this stage implements.

### Acceptance Criteria
- [x] Criterion 1
- [x] Criterion 2
- [x] All unit tests pass
- [x] Coverage targets met

### Test Results
- Tests: XX passed, 0 failed
- Coverage: XX%

### Files Changed
- `lib/whisker/script/...`
- `tests/unit/script/...`
```

---

## Testing Requirements

### Test Structure
```lua
-- tests/unit/script/lexer/tokens_spec.lua
describe("TokenType", function()
  describe("is_keyword", function()
    it("returns token type for keywords", function()
      assert.equals(TokenType.AND, is_keyword("and"))
    end)
    
    it("returns nil for non-keywords", function()
      assert.is_nil(is_keyword("foobar"))
    end)
  end)
end)
```

### Coverage Targets
| Component | Target |
|-----------|--------|
| `script/lexer/*` | 95% |
| `script/parser/*` | 90% |
| `script/semantic/*` | 90% |
| `script/generator/*` | 85% |
| **Overall** | 90% |

### Test Categories
1. **Unit tests:** Test single functions/modules in isolation
2. **Contract tests:** Verify implementations fulfill interface contracts
3. **Integration tests:** Test module interactions
4. **Fixture tests:** Test against `.wsk` story files

### Running Tests
```bash
# All tests
busted

# Specific module
busted tests/unit/script/lexer/

# With coverage
busted --coverage
```

## Whisker Script Syntax Quick Reference

```whisker
# Comments start with hash
@@ title: Story Title
@@ author: Author Name

:: PassageName [tag1, tag2]
Narrative text goes here.
Variables can be interpolated: {$player_name}

+ [Choice text] -> TargetPassage
+ { $has_key } [Conditional choice] -> UnlockedDoor

~ $variable = "value"
~ $counter += 1
~ $list[] = "append"

{ $health > 50:
    You feel strong.
- $health > 25:
    You're wounded.
- else:
    You're barely alive.
}

Inline conditional: { $gold > 0: {$gold} gold | no gold }

->-> TunnelPassage    # Tunnel call
->->                  # Tunnel return
<- BackgroundThread   # Thread start

>> include "chapter2.wsk"
>> import "utils.wsk" as utils
```

## Key Token Types

| Token | Pattern | Context |
|-------|---------|---------|
| `PASSAGE_DECL` | `::` | Passage declaration |
| `CHOICE` | `+` | Line start = choice marker |
| `DIVERT` | `->` | Navigation |
| `TUNNEL` | `->->` | Subroutine call/return |
| `THREAD` | `<-` | Parallel narrative |
| `ASSIGN` | `~` | Variable assignment |
| `VARIABLE` | `$name` | Variable reference |
| `LBRACE/RBRACE` | `{ }` | Conditionals, interpolation |

## AST Node Hierarchy

```
ScriptNode
├── MetadataNode[]
├── IncludeNode[]
└── PassageNode[]
    └── StatementNode[]
        ├── TextNode
        ├── ChoiceNode
        ├── AssignmentNode
        ├── ConditionalNode
        ├── DivertNode
        ├── TunnelCallNode
        ├── TunnelReturnNode
        └── ThreadStartNode

ExpressionNode
├── BinaryExprNode
├── UnaryExprNode
├── VariableRefNode
├── FunctionCallNode
├── LiteralNode
├── ListLiteralNode
├── InlineExprNode
└── InlineConditionalNode
```

## Common Implementation Patterns

### Token Factory
```lua
function Token.new(type, lexeme, literal, position)
  assert(TokenType[type], "Invalid token type")
  return setmetatable({
    type = type,
    lexeme = lexeme,
    literal = literal,
    pos = position
  }, Token)
end
```

### Precedence Climbing Parser
```lua
local PRECEDENCE = {
  [TokenType.OR] = 1,
  [TokenType.AND] = 2,
  [TokenType.EQ_EQ] = 3, [TokenType.BANG_EQ] = 3,
  [TokenType.LT] = 4, [TokenType.GT] = 4,
  [TokenType.PLUS] = 5, [TokenType.MINUS] = 5,
  [TokenType.STAR] = 6, [TokenType.SLASH] = 6,
}

function Parser:parse_precedence(min_prec)
  local left = self:parse_unary()
  while true do
    local prec = PRECEDENCE[self:peek().type]
    if not prec or prec < min_prec then break end
    local op = self:advance()
    local right = self:parse_precedence(prec + 1)
    left = Node.binary_expr(op.lexeme, left, right, left.pos)
  end
  return left
end
```

### Visitor Pattern
```lua
local Visitor = {}
Visitor.__index = Visitor

function Visitor:visit(node)
  if not node then return end
  local method = self["visit_" .. node.type]
  if method then
    return method(self, node)
  end
  return self:visit_default(node)
end

-- Override in subclasses
function Visitor:visit_Passage(node)
  for _, stmt in ipairs(node.body) do
    self:visit(stmt)
  end
end
```

### Error with Suggestion
```lua
function SemanticAnalyzer:undefined_passage_error(name, pos)
  local suggestion = self:find_similar_passage(name)
  return {
    code = "WSK0040",
    message = string.format("Undefined passage '%s'", name),
    position = pos,
    suggestion = suggestion and 
      string.format("Did you mean '%s'?", suggestion.name)
  }
end
```

## Error Message Guidelines

Error messages should:
1. **State what went wrong** — Clear, jargon-free
2. **State where** — Line, column, source snippet
3. **Suggest how to fix** — Actionable when possible
4. **Use narrative terminology** — "passage" not "function"

```
Error [WSK0040]: Undefined passage reference

  --> story.wsk:15:6
   |
14 | + [Go north]
15 |   -> NorthRoom
   |      ^^^^^^^^^ This passage doesn't exist
   |
   = help: Did you mean 'NorthChamber'? (defined at line 42)
```

## Integration Points

### Container Registration
```lua
-- In lib/whisker/script/init.lua
function M.init(container)
  container:register("format.whisker", M, {
    implements = "IFormat",
    capability = "format.whisker"
  })
  
  container:register("compiler.whisker", Compiler, {
    implements = "IScriptCompiler"
  })
end
```

### Event Emissions
```lua
-- Emit during compilation for observability
whisker.events:emit("script:compile:start", { source = source })
whisker.events:emit("script:tokenize:complete", { tokens = tokens, errors = lexer_errors })
whisker.events:emit("script:parse:complete", { ast = ast, errors = parse_errors })
whisker.events:emit("script:analyze:complete", { ast = annotated_ast, symbols = symbols })
whisker.events:emit("script:generate:complete", { story = story })
whisker.events:emit("script:compile:complete", { story = story, diagnostics = all_diagnostics })
```

### IFormat Implementation
```lua
function WhiskerScriptFormat:can_import(source)
  return source:match("^%s*::") or source:match("^%s*@@")
end

function WhiskerScriptFormat:import(source)
  local result = self.compiler:compile(source)
  if #result.errors > 0 then
    error(self:format_errors(result.errors))
  end
  return result.story
end

function WhiskerScriptFormat:export(story)
  return WhiskerScriptWriter.new():write(story)
end
```

## Implementation Stage Reference

The implementation is divided into 25 stages across 8 groups:

| Group | Stages | Focus |
|-------|--------|-------|
| A | 01-04 | Infrastructure, tokens, scanner |
| B | 05-08 | Lexer implementation |
| C | 09-12 | AST, visitor, parser infrastructure |
| D | 13-16 | Core parsing (passages, choices, expressions) |
| E | 17-19 | Advanced parsing (conditionals, tunnels) |
| F | 20-21 | Semantic analysis |
| G | 22-24 | Code generation, IFormat |
| H | 25 | Polish and documentation |

See `docs/gap-analysis/PHASE_3_IMPLEMENTATION.md.md` for detailed stage specifications.

## Debugging Tips

### Lexer Debugging
```lua
-- Print token stream
local tokens = lexer:tokenize()
for i, tok in ipairs(tokens.tokens) do
  print(string.format("%d: %s %q at %d:%d", 
    i, tok.type, tok.lexeme, tok.pos.line, tok.pos.column))
end
```

### Parser Debugging
```lua
-- Enable verbose parsing
parser.debug = true

-- Pretty-print AST
local function dump_ast(node, indent)
  indent = indent or 0
  local prefix = string.rep("  ", indent)
  print(prefix .. node.type)
  for k, v in pairs(node) do
    if type(v) == "table" and v.type then
      dump_ast(v, indent + 1)
    elseif type(v) == "table" then
      for _, child in ipairs(v) do
        if type(child) == "table" and child.type then
          dump_ast(child, indent + 1)
        end
      end
    end
  end
end
```

### Symbol Table Debugging
```lua
-- Dump symbol table
function SymbolTable:dump()
  local function dump_scope(scope, indent)
    for name, sym in pairs(scope.symbols) do
      print(string.rep("  ", indent) .. 
        string.format("%s: %s @ %d:%d", name, sym.kind, sym.position.line, sym.position.column))
    end
  end
  dump_scope(self.global_scope, 0)
end
```

## Questions to Ask When Implementing

1. **Do all tests pass?** Never proceed or create a PR with failing tests.
2. **Does this follow interface-first design?** Define the interface before the implementation.
3. **Are errors accumulated?** Don't throw on first error; collect all errors.
4. **Is source position preserved?** Every token and AST node needs position info.
5. **Are events emitted?** Pipeline transitions should emit events.
6. **Is it testable in isolation?** Can this be unit tested with mocks?
7. **Does the error message help writers?** Use narrative terminology, suggest fixes.
8. **Are acceptance criteria met?** Check every criterion in the stage specification.

## Resources

- **Implementation Stages:** `docs/gap-analysis/PHASE_3_IMPLEMENTATION.md'
- **Roadmap:** `whisker-core-analysis-initial-gap-analysis.md`
- **Phase 1 Patterns:** `lib/whisker/kernel/`, `lib/whisker/interfaces/`
- **Phase 2 Patterns:** `lib/whisker/formats/ink/`
- **Ink Reference:** [Ink documentation](https://github.com/inkle/ink/blob/master/Documentation/WritingWithInk.md)
