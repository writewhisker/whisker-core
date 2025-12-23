# Whisker Script Language Design

**Version:** 1.0
**Status:** Final Design

## Philosophy

Whisker Script prioritizes **author experience over technical elegance**. Authors should write prose with minimal syntax overhead. The language follows progressive disclosure: simple stories require simple syntax, while complex features are available when needed.

### Design Principles

1. **Prose First:** Story content should look like prose, not code
2. **Minimal Punctuation:** Avoid excessive symbols and brackets
3. **Readable at a Glance:** Authors should read branching structure easily
4. **Progressive Disclosure:** Simple stories require simple syntax, complexity is opt-in
5. **No Surprises:** Syntax should behave predictably and intuitively
6. **Consistent Patterns:** Similar constructs use similar syntax
7. **Helpful Errors:** When syntax is wrong, error messages guide to correct form

### Anti-Goals (What Whisker Script Is NOT)

- Not a general-purpose programming language
- Not competing with Lua for scripting flexibility
- Not optimizing for minimal character count (readability > brevity)
- Not hiding all technical concepts (authors can learn variables, conditionals)

## Target Audience

- **Beginners:** Fiction writers with no programming experience
- **Intermediate:** Authors who want branching narratives with state tracking
- **Advanced:** Users who need escape hatches to Lua for complex logic

## Core Constructs

### Passage Declaration

**Purpose:** Name and delimit story sections

**Syntax:**
```whisker
:: PassageName
Content of the passage goes here.
```

**Rationale:**
- `::` is visually distinct, easy to spot when scanning
- Capitalizing passage names is convention (like chapter titles)
- No closing delimiter needed (passages end when next `::` begins or EOF)
- Passage names are identifiers (alphanumeric + underscore, no spaces)

**Alternatives Considered:**
- `# PassageName` — Conflicts with Markdown headers
- `[PassageName]` — Conflicts with choice syntax
- `@PassageName` — Suggests variables/references rather than declarations

### Choice Presentation

**Purpose:** Let readers make decisions

**Syntax:**
```whisker
+ [Choice text] -> TargetPassage
```

**Rationale:**
- `+` suggests addition/branching visually
- Square brackets clearly contain display text
- `->` is universal "goes to" arrow
- Target is required (choices must lead somewhere)

**Alternatives Considered:**
- `* Choice text -> Target` — `*` suggests lists, not interactivity
- `- [Choice text](Target)` — Markdown link syntax may confuse web authors
- `[[Choice text|Target]]` — Twine syntax is hard to read with long text

### Conditional Content

**Purpose:** Show content only when conditions are met

**Syntax:**
```whisker
{ $gold > 50 }
You have enough gold!
{ / }
```

**Rationale:**
- Curly braces for conditions (common in many languages)
- `$` prefix marks variables (easy to visually distinguish)
- Closing `{ / }` is explicit (avoids nesting confusion)
- Condition is a Lua-like expression (familiar to many authors)

**Alternatives Considered:**
- `if gold > 50: ... end` — Introduces new keywords
- `{? gold > 50 ?} ... {? end ?}` — Too verbose

### Variable Assignment

**Purpose:** Store and modify story state

**Syntax:**
```whisker
$gold = 100
$name = "Alice"
$has_key = true
$visited_cave = false
```

**Modification:**
```whisker
$gold += 50
$health -= 10
$visit_count += 1
```

**Rationale:**
- `$` prefix makes variables visually obvious
- `=` is universal assignment operator
- Type inference (no need to declare types)
- Supports numbers, strings (quoted), booleans (`true`/`false`)
- `+=`, `-=` are familiar from many languages

### Conditional Choices

**Purpose:** Show choices only when conditions are met

**Syntax:**
```whisker
+ { $has_key } [Unlock door] -> UnlockedRoom
+ { $gold >= 50 } [Buy sword] -> ShopPurchase
+ [Leave] -> Exit
```

**Rationale:**
- Condition appears before choice text (read left-to-right)
- Same `{ }` syntax as conditional content (consistency)
- Unconditional choices have no `{ }` prefix
- Clear visual distinction between conditional and unconditional

## Advanced Features

### Comments

**Syntax:**
```whisker
// This is a single-line comment

/* This is a
   multi-line comment */
```

**Rationale:**
- C-style comments are widely understood
- Single-line for quick notes
- Multi-line for disabling large sections

### String Interpolation

**Syntax:**
```whisker
You have $gold gold coins.
Welcome, $player_name!
```

**Rationale:**
- Variables in prose expand naturally
- No special syntax needed (just use `$var` in text)
- Authors write what they mean

### Embedded Lua

**Purpose:** Escape hatch for complex logic

**Syntax:**
```whisker
$random_gold = {{ math.random(10, 100) }}

{{
  if player.level > 10 then
    whisker.state:set("expert_mode", true)
  end
}}
```

**Rationale:**
- `{{ }}` clearly marks "this is Lua code"
- Double braces avoid conflict with single brace conditions
- Authors can drop into Lua when Whisker Script isn't expressive enough

### Escaping

**Syntax:**
```whisker
Use \{ to show a literal brace.
Use \\ to show a backslash.
Use \n for a newline.
Use \$ to show a literal dollar sign.
```

**Rationale:**
- Standard backslash escaping (familiar)
- Authors can show syntax characters as content

## Expression Operators

### Comparison Operators

| Operator | Meaning |
|----------|---------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

### Logical Operators

| Operator | Meaning |
|----------|---------|
| `&&` | Logical AND |
| `\|\|` | Logical OR |
| `!` | Logical NOT |

### Examples

```whisker
{ $gold >= 50 && $level > 3 }
{ $has_sword || $has_axe }
{ !$visited_cave }
```

## Grammar Sketch

```
program       := passage+
passage       := '::' identifier newline content
content       := (text | choice | conditional | assignment)*
choice        := '+' condition? '[' text ']' '->' identifier
conditional   := '{' expression '}' content '{' '/' '}'
assignment    := '$' identifier ('=' | '+=' | '-=') value
expression    := // Boolean expression with operators
value         := expression
```

## Design Decisions Log

### Empty Passages
**Decision:** Allowed
**Rationale:** Useful for placeholders during authoring

### Terminal Choices (no target)
**Decision:** Not allowed
**Rationale:** Choices must have `-> target` for clarity

### Variable Scope
**Decision:** All global
**Rationale:** Simplicity for non-programmer authors

### Nested Conditionals
**Decision:** Allowed
**Rationale:** Braces must balance; natural for complex logic

### Unicode in Identifiers
**Decision:** Not allowed (ASCII only for now)
**Rationale:** Simplifies lexer; can be added later

### Line Endings
**Decision:** Normalize `\r\n` to `\n`
**Rationale:** Cross-platform compatibility

### Arithmetic Operators
**Decision:** Not included in v1
**Rationale:** Keep initial language simple; use embedded Lua for math

## Example Stories

### Example 1: Linear Story (Minimal Syntax)

```whisker
:: Start
You wake up in a mysterious room. The door is locked.

+ [Examine the room] -> Examine
+ [Try the door] -> TryDoor

:: Examine
You find a key under the bed!
$has_key = true

+ [Take the key and return] -> Start

:: TryDoor
{ $has_key }
You unlock the door and escape!
{ / }

{ !$has_key }
The door is locked. You need a key.
+ [Go back] -> Start
{ / }
```

### Example 2: Branching with State

```whisker
:: Village
You arrive at a small village.

$visited_village = true
$gold = 100

+ [Visit the shop] -> Shop
+ [Visit the inn] -> Inn
+ { $has_map } [Follow the map] -> Treasure

:: Shop
Welcome to my shop!

+ { $gold >= 50 } [Buy sword ($50)] -> BuySword
+ { $gold >= 20 } [Buy potion ($20)] -> BuyPotion
+ [Leave] -> Village

:: BuySword
You buy a sword.
$gold -= 50
$has_sword = true

+ [Continue] -> Village
```

### Example 3: Complex Conditions

```whisker
:: BossRoom
The dragon stares at you.

+ { $has_sword && $level >= 5 } [Fight the dragon] -> FightDragon
+ { $has_shield || $has_armor } [Defend yourself] -> Defend
+ { $gold > 100 } [Bribe the dragon] -> Bribe
+ [Run away] -> Escape
```

## Open Questions (Future Iterations)

1. **Functions/Macros:** Should authors be able to define reusable content blocks?
2. **Lists/Arrays:** Should variables support collections?
3. **Arithmetic:** Should `+`, `-`, `*`, `/` be added to expressions?
4. **Once-only content:** Should there be syntax for content shown only once?
5. **Passage parameters:** Should passages accept arguments?

These are deferred to future versions to keep v1 simple and focused.

---

*This design document serves as the authoritative reference for Whisker Script syntax decisions.*
