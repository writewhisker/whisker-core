# Whisker Script Grammar Ambiguities and Resolutions

**Version:** 1.0

This document describes potential parsing ambiguities in the Whisker Script language and their resolution strategies.

## Ambiguity 1: Text vs. Conditional Brace

### Problem

```whisker
She said {quietly} to him.
```

When the lexer encounters `{`, it could be:
1. A conditional block: `{ $condition }`
2. A literal brace in text

### Resolution: Lookahead

The lexer uses **lookahead** to determine the meaning of `{`:

- If `{` is followed by:
  - `$` (variable) → conditional
  - `!` (NOT operator) → conditional
  - `(` (parenthesis) → conditional
  - `/` (close marker) → conditional end
  - `true` or `false` (boolean) → conditional
  - Otherwise → literal text

**Implementation:**

```lua
function lexer:scan_lbrace()
  local next = self:peek()
  if next == "$" or next == "!" or next == "(" or next == "/" or
     self:peek_keyword("true") or self:peek_keyword("false") then
    return Token("LBRACE", "{")
  else
    return self:scan_text("{")  -- Treat as literal text
  end
end
```

### Author Guidance

If authors need a literal `{` before a variable-like pattern, they should escape it:

```whisker
She said \{$name\} to him.  // Literal braces around variable text
```

## Ambiguity 2: Content Inside Conditionals

### Problem

```whisker
{ $has_key }
The door unlocks.
+ [Enter] -> Room
{ / }
```

Could "The door unlocks." and the choice be:
1. Parsed as content inside the conditional
2. Parsed as separate top-level elements

### Resolution: Conditional Scope

Content between `{ $expr }` and `{ / }` is **nested content** belonging to the conditional. The parser tracks conditional nesting depth:

```lua
function parser:parse_conditional()
  local condition = self:parse_expression()
  self:expect("RBRACE")

  -- Parse content until we see { / }
  local content = {}
  while not self:check_conditional_end() do
    table.insert(content, self:parse_content_element())
  end

  self:expect("LBRACE")
  self:expect("SLASH")
  self:expect("RBRACE")

  return ConditionalNode(condition, content)
end
```

Content inside conditionals is parsed identically to passage content, allowing:
- Nested conditionals
- Choices
- Assignments
- Text
- Embedded Lua

## Ambiguity 3: Variable in Choice Text

### Problem

```whisker
+ [You have $gold coins] -> Shop
```

Is `$gold` inside choice text:
1. A variable to interpolate
2. Literal text including the dollar sign

### Resolution: Variable Interpolation Enabled

Choice text **supports variable interpolation**. The parser expands `$identifier` patterns in choice text to variable references.

**Implementation:**

```lua
function parser:parse_choice_text()
  local segments = {}
  while not self:check("RBRACKET") do
    if self:check("DOLLAR") then
      self:advance()
      local name = self:expect("IDENTIFIER")
      table.insert(segments, VarRef(name.value))
    else
      table.insert(segments, TextSegment(self:advance().value))
    end
  end
  return ChoiceText(segments)
end
```

### Escaping

To include a literal `$` in choice text:

```whisker
+ [Price is \$100] -> Purchase
```

## Ambiguity 4: Empty Passages

### Problem

```whisker
:: EmptyPassage
:: NextPassage
Content here.
```

Is an empty passage (with no content before the next `::`) valid?

### Resolution: Empty Passages Are Valid

Empty passages are allowed. They serve as:
- Placeholders during authoring
- Junction points in story flow
- Redirect targets

**Grammar Note:**

```ebnf
passage = passage_header , content ;
content = { content_element } ;  (* Zero or more elements *)
```

The `{ }` repetition allows zero occurrences, making empty content valid.

## Ambiguity 5: Conditional vs. Choice Condition

### Problem

```whisker
:: Start
{ $has_key }
+ [Unlock door] -> Inside
{ / }
```

vs.

```whisker
:: Start
+ { $has_key } [Unlock door] -> Inside
```

These look similar but have different semantics:
1. First: Conditional block containing a choice
2. Second: Choice with inline condition

### Resolution: Context-Sensitive Parsing

The parser distinguishes by looking at what follows `}`:

- **Conditional block:** `{ $expr }` followed by content, then `{ / }`
- **Choice condition:** `{ $expr }` inside a choice, followed by `[`

**Key Rule:** After `+`, if `{` appears, it's a choice condition (must be followed by `[ ]`).

```lua
function parser:parse_choice()
  self:expect("CHOICE_MARKER")  -- +

  local condition = nil
  if self:check("LBRACE") then
    self:advance()
    condition = self:parse_expression()
    self:expect("RBRACE")
  end

  -- Must have choice text next
  self:expect("LBRACKET")
  local text = self:parse_choice_text()
  self:expect("RBRACKET")

  self:expect("ARROW")
  local target = self:expect("IDENTIFIER")

  return ChoiceNode(text, target, condition)
end
```

## Ambiguity 6: Assignment vs. Comparison

### Problem

```whisker
$gold = 50
```

vs.

```whisker
{ $gold == 50 }
```

Single `=` vs. double `==` could confuse authors.

### Resolution: Context Determines Operator

- `=` at statement level → assignment
- `=` inside `{ }` → parse error (must use `==`)

**Error Message:**

```
error: story.ws:5:9: use '==' for comparison, not '='
  |
5 | { $gold = 50 }
  |         ^ did you mean '=='?
  |
help: for comparison, use: { $gold == 50 }
      for assignment, put $gold = 50 outside the condition
```

## Ambiguity 7: Minus Sign in Expressions

### Problem

```whisker
{ $a - 5 }
```

Currently, arithmetic operators are not in the language. Is this:
1. A subtraction (not supported)
2. A parse error

### Resolution: Future Extension

Arithmetic expressions are reserved for future versions. Current parser will report:

```
error: story.ws:3:6: unexpected '-' in expression
  |
3 | { $a - 5 }
  |      ^ arithmetic operators not yet supported
  |
help: arithmetic is planned for a future version
      for now, use embedded Lua: {{ state.a - 5 }}
```

## Ambiguity 8: Newlines in Strings

### Problem

```whisker
$message = "Hello
World"
```

Is a newline inside a string literal:
1. Part of the string
2. A syntax error

### Resolution: Newlines Not Allowed

String literals must be on a single line. For multi-line strings, use Lua:

```whisker
$message = {{ [[Hello
World]] }}
```

**Error Message:**

```
error: story.ws:1:12: unterminated string
  |
1 | $message = "Hello
  |            ^ string started here
2 | World"
  |
help: strings must be on a single line
      for multi-line text, use embedded Lua: {{ [[text]] }}
```

## Ambiguity 9: Operator Spacing

### Problem

```whisker
{ $a&&$b }
{ $a && $b }
```

Are these equivalent?

### Resolution: Whitespace Optional

Operators do not require surrounding whitespace. Both forms are valid and equivalent:

```whisker
{$a&&$b}           // Valid
{ $a && $b }       // Valid (preferred for readability)
{$gold>=50&&$has_map}  // Valid but hard to read
```

The lexer extracts tokens regardless of whitespace.

## Ambiguity 10: Comment in Expression

### Problem

```whisker
{ $gold > 50 // minimum gold
}
```

Can comments appear inside conditions?

### Resolution: Line Comments End at Newline

Line comments (`//`) consume everything to the newline. This creates issues inside `{ }`:

```whisker
{ $gold > 50 // this comment consumes the closing brace?
}
```

**Resolution:** The lexer strips comments before parsing. The `}` on the next line correctly closes the condition.

However, this could be confusing, so authors are advised:

```whisker
// minimum gold check
{ $gold > 50 }
```

## Summary Table

| Ambiguity | Resolution Strategy |
|-----------|---------------------|
| Text vs. Conditional `{` | Lookahead for `$`, `!`, `(`, `/` |
| Content in Conditionals | Parse until `{ / }` marker |
| Variable in Choice Text | Enable interpolation, escape with `\$` |
| Empty Passages | Valid, zero content allowed |
| Conditional vs. Choice Condition | Context: after `+`, condition precedes `[` |
| Assignment vs. Comparison | Context: `=` outside `{ }`, `==` inside |
| Arithmetic Operators | Not supported (future extension) |
| Newlines in Strings | Not allowed (use Lua for multi-line) |
| Operator Spacing | Whitespace optional |
| Comments in Expressions | Comments stripped during lexing |

---

*This ambiguity document guides parser implementation and error handling.*
