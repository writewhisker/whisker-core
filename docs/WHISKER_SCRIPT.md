# Whisker Script Language Specification

**Version:** 1.0.0
**Status:** Complete

## Table of Contents

1. [Introduction](#introduction)
2. [Design Principles](#design-principles)
3. [Lexical Structure](#lexical-structure)
4. [Syntax](#syntax)
5. [Passages](#passages)
6. [Text and Content](#text-and-content)
7. [Choices](#choices)
8. [Variables](#variables)
9. [Expressions](#expressions)
10. [Conditionals](#conditionals)
11. [Control Flow](#control-flow)
12. [Built-in Functions](#built-in-functions)
13. [Metadata](#metadata)
14. [Comments](#comments)
15. [Grammar (EBNF)](#grammar-ebnf)
16. [Error Codes](#error-codes)

---

## Introduction

Whisker Script is a domain-specific language (DSL) designed for authoring interactive fiction. It prioritizes readability, progressive complexity, and writer-friendly syntax over programming language conventions.

### File Extension

Whisker Script files use the `.wsk` extension.

### Example

```whisker
@@ title: My First Story
@@ author: Jane Writer

:: Start
Welcome to my interactive story!

~ $name = "Adventurer"

Hello, {$name}! What would you like to do?

+ [Go exploring] -> Forest
+ [Stay home] -> Home

:: Forest
The forest is dark and mysterious.

:: Home
Home is cozy and warm.
```

---

## Design Principles

Whisker Script follows six core design principles:

1. **Readability over brevity** - Syntax optimizes for comprehension, not keystroke minimization
2. **Progressive complexity** - Simple stories need only simple syntax
3. **Explicit structure** - Visual hierarchy through indentation and keywords
4. **Error-friendly design** - Messages use narrative terminology and suggest fixes
5. **Round-trip capability** - Parse then generate yields identical results
6. **Familiar patterns** - Adopts successful patterns from Ink where appropriate

---

## Lexical Structure

### Character Set

Whisker Script files are UTF-8 encoded. Source text may contain any Unicode characters in strings and text content.

### Whitespace

- Spaces and tabs are generally insignificant except for indentation
- Newlines are significant as statement terminators
- Indentation uses consistent spaces or tabs (mixing is discouraged)

### Line Continuation

Long lines can be continued using a backslash at the end:

```whisker
This is a very long line that \
continues on the next line.
```

### Tokens

| Token | Pattern | Description |
|-------|---------|-------------|
| `::` | Passage declaration | Starts a passage definition |
| `+` | Choice marker | Starts a choice option |
| `->` | Divert | Navigation to another passage |
| `->->` | Tunnel | Subroutine call/return |
| `<-` | Thread | Background thread start |
| `~` | Assignment | Variable assignment |
| `@@` | Metadata | Story metadata declaration |
| `>>` | Include | File inclusion |
| `$` | Variable prefix | Marks a variable reference |
| `{` `}` | Braces | Expressions and conditionals |
| `[` `]` | Brackets | Choice text, lists, tags |
| `(` `)` | Parentheses | Grouping, function calls |
| `#` | Comment | Line comment |

---

## Syntax

### Top-Level Structure

A Whisker Script file consists of:

1. Optional metadata declarations
2. Optional include/import statements
3. One or more passage definitions

```whisker
@@ title: Story Title        # Metadata
>> include "chapter2.wsk"    # Include

:: PassageName               # Passage
Content goes here.
```

### Statement Types

Within passages, the following statement types are available:

- **Text lines** - Narrative content displayed to the reader
- **Choices** - Interactive options for the reader
- **Assignments** - Variable modifications
- **Conditionals** - Branching based on conditions
- **Diverts** - Navigation to other passages
- **Tunnel calls** - Subroutine-style navigation
- **Thread starts** - Background narrative threads

---

## Passages

Passages are the fundamental building blocks of a story. Each passage has a unique name and contains content.

### Passage Declaration

```whisker
:: PassageName
Content of the passage.
```

### Passage Tags

Tags provide metadata about passages:

```whisker
:: PassageName [tag1, tag2, tag3]
Content here.
```

Common tag uses:
- `[start]` - Entry point of the story
- `[end]` - Terminal passage
- `[hidden]` - Not directly navigable
- `[checkpoint]` - Save point

### Special Passage: Start

The passage named `Start` is the default entry point if no other is specified.

### Duplicate Passages

Defining two passages with the same name is an error:

```whisker
:: MyPassage
First definition.

:: MyPassage    # ERROR: Duplicate passage 'MyPassage'
Second definition.
```

---

## Text and Content

### Plain Text

Text in passages is displayed directly to the reader:

```whisker
:: Example
This text appears to the reader.
Multiple lines are displayed as separate paragraphs.

Blank lines create paragraph breaks.
```

### Variable Interpolation

Variables can be embedded in text using curly braces:

```whisker
Hello, {$player_name}! You have {$gold} gold.
```

### Inline Expressions

Any expression can be embedded in text:

```whisker
The sum is {2 + 2}.
You are { $health > 50: healthy | wounded }.
```

### Inline Conditionals

Show different text based on conditions:

```whisker
{ $has_key: You have the key. | You need to find a key. }
```

Multi-branch inline conditionals are not supported; use block conditionals for complex logic.

---

## Choices

Choices allow readers to make decisions that affect the story.

### Basic Choice

```whisker
+ [Choice text] -> TargetPassage
```

### Choice Without Target

Choices can have inline content instead of a target:

```whisker
+ [Examine the book]
  The book is old and dusty.
  -> Library
```

### Conditional Choices

Show choices only when conditions are met:

```whisker
+ { $has_key } [Unlock the door] -> SecretRoom
+ [Try to force the door] -> ForceDoor
```

### Sticky vs Consumable Choices

By default, choices persist. Use `*` for one-time choices:

```whisker
* [Take the apple] -> TakeApple   # Only appears once
+ [Look around] -> LookAround     # Always appears
```

### Choice Nesting

Choices can contain nested content:

```whisker
+ [Go north]
  You head north through the forest.
  + [Follow the path] -> Path
  + [Leave the path] -> Wilderness
```

---

## Variables

Variables store state that persists across passages.

### Variable Names

- Start with `$` prefix
- Contain letters, numbers, and underscores
- Case-sensitive

```whisker
$player_name
$gold_count
$hasKey
$_internal
```

### Assignment

Use `~` to assign values:

```whisker
~ $name = "Hero"
~ $gold = 100
~ $has_key = true
~ $items = []
```

### Compound Assignment

```whisker
~ $gold += 50      # Add
~ $health -= 10    # Subtract
~ $damage *= 2     # Multiply
~ $shares /= 4     # Divide
```

### List Operations

```whisker
~ $inventory = []           # Empty list
~ $inventory[] = "sword"    # Append
~ $inventory[] = "shield"   # Append another
```

### Variable Types

Variables can hold:
- **Numbers** - `42`, `3.14`, `-10`
- **Strings** - `"hello"`, `'world'`
- **Booleans** - `true`, `false`
- **Lists** - `[1, 2, 3]`, `["a", "b"]`
- **Null** - `null`

Type is determined dynamically based on assigned value.

---

## Expressions

Expressions compute values for conditions, assignments, and interpolation.

### Literals

```whisker
42              # Integer
3.14            # Float
"hello"         # String (double quotes only)
true            # Boolean true
false           # Boolean false
null            # Null value
[1, 2, 3]       # List
```

**Note:** Only double quotes are supported for strings. Single quotes (apostrophes) are reserved for use in narrative text (e.g., "you'll", "it's").

### Operators

#### Arithmetic
| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division |
| `%` | Modulo |

#### Comparison
| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

#### Logical
| Operator | Description |
|----------|-------------|
| `and` | Logical AND |
| `or` | Logical OR |
| `not` | Logical NOT |

### Operator Precedence

From lowest to highest:

1. `or`
2. `and`
3. `==`, `!=`
4. `<`, `>`, `<=`, `>=`
5. `+`, `-`
6. `*`, `/`, `%`
7. `not`, unary `-`
8. Index `[]`, function call `()`

### Grouping

Use parentheses to override precedence:

```whisker
($a + $b) * $c
```

---

## Conditionals

### Block Conditionals

```whisker
{ $health > 50:
    You feel strong and healthy.
- $health > 25:
    You're wounded but still standing.
- else:
    You're barely clinging to life.
}
```

### Conditional Structure

```
{ condition:
    content when true
- alternative_condition:
    content when alternative is true
- else:
    content when all conditions are false
}
```

### Nested Conditionals

```whisker
{ $has_weapon:
    { $weapon == "sword":
        You draw your trusty sword.
    - else:
        You ready your weapon.
    }
- else:
    You raise your fists.
}
```

### Inline Conditionals

For simple either/or text:

```whisker
You are { $health > 50: healthy | hurt }.
```

---

## Control Flow

### Divert

Navigate to another passage:

```whisker
-> TargetPassage
```

With arguments (for parameterized passages):

```whisker
-> Battle($enemy, $weapon)
```

### Tunnel Call

Call a passage like a subroutine and return:

```whisker
->-> DescribeWeather

# Later, after DescribeWeather completes:
The story continues here.
```

### Tunnel Return

Return from a tunnel:

```whisker
:: DescribeWeather
The sky is { $weather: sunny | cloudy }.
->->
```

### Thread Start

Start a background narrative thread:

```whisker
<- BackgroundAmbience
```

Threads run in parallel and can interleave with main content.

---

## Built-in Functions

### Math Functions

| Function | Description | Example |
|----------|-------------|---------|
| `abs(x)` | Absolute value | `abs(-5)` → `5` |
| `floor(x)` | Round down | `floor(3.7)` → `3` |
| `ceil(x)` | Round up | `ceil(3.2)` → `4` |
| `round(x)` | Round to nearest | `round(3.5)` → `4` |
| `min(a, b)` | Minimum of two | `min(3, 5)` → `3` |
| `max(a, b)` | Maximum of two | `max(3, 5)` → `5` |
| `random(a, b)` | Random integer | `random(1, 10)` → `1-10` |

### String Functions

| Function | Description | Example |
|----------|-------------|---------|
| `len(s)` | String length | `len("hello")` → `5` |
| `upper(s)` | Uppercase | `upper("hi")` → `"HI"` |
| `lower(s)` | Lowercase | `lower("HI")` → `"hi"` |
| `trim(s)` | Remove whitespace | `trim(" hi ")` → `"hi"` |
| `substr(s, start, len)` | Substring | `substr("hello", 1, 2)` → `"he"` |
| `contains(s, sub)` | Contains substring | `contains("hello", "ell")` → `true` |

### List Functions

| Function | Description | Example |
|----------|-------------|---------|
| `count(list)` | Number of items | `count([1,2,3])` → `3` |
| `first(list)` | First item | `first([1,2,3])` → `1` |
| `last(list)` | Last item | `last([1,2,3])` → `3` |
| `has(list, item)` | Contains item | `has([1,2], 1)` → `true` |
| `push(list, item)` | Add item | Modifies list |
| `pop(list)` | Remove last item | Returns removed item |

### Type Functions

| Function | Description | Example |
|----------|-------------|---------|
| `type(x)` | Get type name | `type(42)` → `"number"` |
| `str(x)` | Convert to string | `str(42)` → `"42"` |
| `num(x)` | Convert to number | `num("42")` → `42` |
| `bool(x)` | Convert to boolean | `bool(1)` → `true` |

### Story Functions

| Function | Description | Example |
|----------|-------------|---------|
| `visited(passage)` | Times passage visited | `visited("Start")` → `1` |
| `visit_count(passage)` | Same as visited | `visit_count()` → current count |
| `turns()` | Total turns taken | `turns()` → `15` |
| `choice_count()` | Choices available | `choice_count()` → `3` |

---

## Metadata

Story metadata is declared at the top of the file:

```whisker
@@ title: My Story
@@ author: Jane Writer
@@ version: "1.0.0"
@@ ifid: 12345678-1234-1234-1234-123456789012
```

### Standard Metadata Fields

| Field | Description |
|-------|-------------|
| `title` | Story title |
| `author` | Author name |
| `version` | Version string |
| `ifid` | Interactive Fiction ID (UUID) |

### Custom Metadata

Any key-value pair can be added:

```whisker
@@ language: en
@@ genre: fantasy
@@ content_warning: violence
```

---

## Comments

### Line Comments

```whisker
# This is a comment
~ $x = 5  # This is also a comment
```

### Block Comments

```whisker
## This is a block comment.
## It spans multiple lines.
## Each line starts with ##.
```

---

## Grammar (EBNF)

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

choice          = ( "+" | "*" ) [ condition ] "[" choice_text "]" [ divert ] NEWLINE
                  [ INDENT { statement } DEDENT ] ;

assignment      = "~" variable_ref assignment_op expression NEWLINE ;
assignment_op   = "=" | "+=" | "-=" | "*=" | "/=" ;

conditional     = "{" condition ":" NEWLINE
                  { statement }
                  { elif_branch }
                  [ else_branch ]
                  "}" ;
elif_branch     = "-" condition ":" NEWLINE { statement } ;
else_branch     = "-" "else" ":" NEWLINE { statement } ;

divert          = "->" identifier [ "(" arguments ")" ] ;
tunnel_call     = "->->" identifier [ "(" arguments ")" ] ;
tunnel_return   = "->->" ;
thread_start    = "<-" identifier ;

(* Expressions *)
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

(* Literals *)
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
escape_seq      = "\\" ( '"' | "'" | "\\" | "n" | "t" | "r" ) ;
COMMENT         = "#" { any_char - NEWLINE } ;
```

---

## Error Codes

### Lexer Errors (WSK00xx)

| Code | Description |
|------|-------------|
| WSK0001 | Unexpected character |
| WSK0002 | Unterminated string |
| WSK0003 | Invalid number format |
| WSK0004 | Invalid escape sequence |
| WSK0005 | Unexpected end of input |
| WSK0006 | Invalid variable name |
| WSK0007 | Too many errors |

### Parser Errors (WSK01xx)

| Code | Description |
|------|-------------|
| WSK0100 | Expected passage declaration |
| WSK0101 | Expected passage name |
| WSK0102 | Expected closing bracket |
| WSK0103 | Expected closing parenthesis |
| WSK0104 | Expected closing brace |
| WSK0105 | Expected expression |
| WSK0106 | Expected statement |
| WSK0107 | Expected identifier |
| WSK0108 | Expected newline |
| WSK0109 | Unexpected token |
| WSK0110 | Unexpected indentation |
| WSK0111 | Expected divert target |
| WSK0112 | Expected choice text |
| WSK0113 | Expected condition |
| WSK0114 | Invalid assignment target |
| WSK0115 | Too many parser errors |

### Semantic Errors (WSK02xx)

| Code | Description |
|------|-------------|
| WSK0200 | Undefined passage reference |
| WSK0201 | Undefined variable |
| WSK0202 | Undefined function |
| WSK0210 | Duplicate passage definition |
| WSK0211 | Duplicate variable definition |
| WSK0220 | Uninitialized variable |
| WSK0230 | Wrong argument count |
| WSK0240 | Tunnel return outside passage |
| WSK0250 | Unreachable passage (warning) |
| WSK0251 | Unused variable (warning) |

---

## Appendix: Comparison to Ink

Whisker Script is inspired by Ink but with key differences:

| Feature | Ink | Whisker Script |
|---------|-----|----------------|
| Choice syntax | `* [text]` | `+ [text]` (+ for persistent, * for once) |
| Variables | `VAR x = 5` | `~ $x = 5` |
| Conditionals | `{condition:` | `{ condition:` |
| Diverts | `-> target` | `-> target` (same) |
| Tunnels | `->target->` | `->-> target` |
| Comments | `//` | `#` |
| Passages | `=== knot` | `:: passage` |
| Tags | `# tag` | `[tag1, tag2]` |

---

*Document generated for Whisker Script v1.0.0*
