# Whisker Script Token Specification

**Version:** 1.0

This document defines all lexical tokens for the Whisker Script language.

## Token Categories

### Structural Operators

| Token | Symbol | Regex | Description |
|-------|--------|-------|-------------|
| `PASSAGE_MARKER` | `::` | `::` | Passage declaration |
| `CHOICE_MARKER` | `+` | `\+` | Choice prefix |
| `ARROW` | `->` | `->` | Choice target separator |
| `LBRACE` | `{` | `\{` | Condition/block open |
| `RBRACE` | `}` | `\}` | Condition/block close |
| `SLASH` | `/` | `/` | Conditional close marker (inside braces) |
| `LBRACKET` | `[` | `\[` | Choice text open |
| `RBRACKET` | `]` | `\]` | Choice text close |
| `LPAREN` | `(` | `\(` | Expression grouping open |
| `RPAREN` | `)` | `\)` | Expression grouping close |

### Assignment Operators

| Token | Symbol | Regex | Description |
|-------|--------|-------|-------------|
| `ASSIGN` | `=` | `=(?!=)` | Variable assignment |
| `PLUS_ASSIGN` | `+=` | `\+=` | Addition assignment |
| `MINUS_ASSIGN` | `-=` | `-=` | Subtraction assignment |

### Comparison Operators

| Token | Symbol | Regex | Description |
|-------|--------|-------|-------------|
| `EQ` | `==` | `==` | Equal |
| `NEQ` | `!=` | `!=` | Not equal |
| `LT` | `<` | `<(?!=)` | Less than |
| `GT` | `>` | `>(?!=)` | Greater than |
| `LTE` | `<=` | `<=` | Less than or equal |
| `GTE` | `>=` | `>=` | Greater than or equal |

### Logical Operators

| Token | Symbol | Regex | Description |
|-------|--------|-------|-------------|
| `AND` | `&&` | `&&` | Logical AND |
| `OR` | `\|\|` | `\|\|` | Logical OR |
| `NOT` | `!` | `!(?!=)` | Logical NOT |

### Variable Prefix

| Token | Symbol | Regex | Description |
|-------|--------|-------|-------------|
| `DOLLAR` | `$` | `\$` | Variable prefix |

### Embedded Lua

| Token | Symbol | Regex | Description |
|-------|--------|-------|-------------|
| `LUA_OPEN` | `{{` | `\{\{` | Embedded Lua open |
| `LUA_CLOSE` | `}}` | `\}\}` | Embedded Lua close |

### Literals

| Token | Regex | Example | Description |
|-------|-------|---------|-------------|
| `IDENTIFIER` | `[A-Za-z_][A-Za-z0-9_]*` | `PassageName`, `player_health` | Names |
| `NUMBER` | `[0-9]+(\.[0-9]+)?` | `42`, `3.14` | Numeric literals |
| `STRING` | `"([^"\\]\|\\.)*"` | `"Hello"`, `"She said \"Hi\""` | String literals |
| `TRUE` | `true` | `true` | Boolean true |
| `FALSE` | `false` | `false` | Boolean false |

### Comments

| Token | Pattern | Description |
|-------|---------|-------------|
| `LINE_COMMENT` | `//[^\n]*` | Single-line comment (discarded) |
| `BLOCK_COMMENT` | `/\*.*?\*/` | Multi-line comment (non-greedy, discarded) |

### Whitespace

| Token | Regex | Description |
|-------|-------|-------------|
| `NEWLINE` | `\n` | Line separator (significant in some contexts) |
| `WHITESPACE` | `[ \t\r]+` | Spaces, tabs, carriage returns (ignored) |

### Text Content

| Token | Description |
|-------|-------------|
| `TEXT` | Any characters not matching above tokens (passage content) |

## Tokenization Rules

### Token Priority

Tokens are matched in the following priority order (longest match wins):

1. **Multi-character operators first:** `::`, `->`, `{{`, `}}`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, `+=`, `-=`
2. **Keywords:** `true`, `false`
3. **Single-character operators:** `+`, `{`, `}`, `[`, `]`, `(`, `)`, `$`, `=`, `<`, `>`, `!`, `/`
4. **Identifiers:** Match `[A-Za-z_][A-Za-z0-9_]*` only when preceded by `$` or in specific contexts
5. **Numbers:** Match `[0-9]+(\.[0-9]+)?`
6. **Strings:** Match quoted content with escape handling
7. **Text:** Default when nothing else matches

### Context-Sensitive Lexing

The lexer operates in different modes:

1. **Normal Mode:** Tokenizing passage content
   - `::` starts passage header mode
   - `+` starts choice mode
   - `{` starts condition mode
   - `$` followed by identifier is a variable reference
   - Other characters are TEXT

2. **Passage Header Mode:** After `::`
   - Skip whitespace
   - Read identifier as passage name
   - NEWLINE ends header mode

3. **Choice Mode:** After `+`
   - Optional `{` condition `}`
   - `[` text `]` for choice text
   - `->` followed by identifier for target
   - NEWLINE ends choice mode

4. **Condition Mode:** Inside `{ }`
   - Full expression tokenization
   - `}` ends condition mode

5. **String Mode:** Inside quotes
   - All characters are part of string
   - Handle escape sequences: `\"`, `\\`, `\n`, `\t`, `\r`
   - `"` ends string mode

### Escape Sequences

| Escape | Character |
|--------|-----------|
| `\\` | Backslash |
| `\"` | Double quote |
| `\n` | Newline |
| `\t` | Tab |
| `\r` | Carriage return |
| `\{` | Literal left brace |
| `\}` | Literal right brace |
| `\$` | Literal dollar sign |

### Line Ending Normalization

- `\r\n` (Windows) is normalized to `\n`
- `\r` alone is treated as whitespace (not newline)

### Comments

Comments are stripped during lexing and not emitted as tokens:

```whisker
// This is a comment
$gold = 100  // inline comment

/* Multi-line
   comment */
```

## Token Examples

### Passage Declaration

```
Input: ":: Start\n"
Tokens: [PASSAGE_MARKER, IDENTIFIER("Start"), NEWLINE]
```

### Choice

```
Input: "+ [Go north] -> North\n"
Tokens: [CHOICE_MARKER, LBRACKET, TEXT("Go north"), RBRACKET, ARROW, IDENTIFIER("North"), NEWLINE]
```

### Conditional Choice

```
Input: "+ { $has_key } [Unlock] -> Door\n"
Tokens: [CHOICE_MARKER, LBRACE, DOLLAR, IDENTIFIER("has_key"), RBRACE, LBRACKET, TEXT("Unlock"), RBRACKET, ARROW, IDENTIFIER("Door"), NEWLINE]
```

### Variable Assignment

```
Input: "$gold = 100\n"
Tokens: [DOLLAR, IDENTIFIER("gold"), ASSIGN, NUMBER(100), NEWLINE]
```

### Conditional Block

```
Input: "{ $gold > 50 }\n"
Tokens: [LBRACE, DOLLAR, IDENTIFIER("gold"), GT, NUMBER(50), RBRACE, NEWLINE]
```

### Complex Expression

```
Input: "{ $gold >= 50 && $level > 3 }"
Tokens: [LBRACE, DOLLAR, IDENTIFIER("gold"), GTE, NUMBER(50), AND, DOLLAR, IDENTIFIER("level"), GT, NUMBER(3), RBRACE]
```

---

*This token specification guides lexer implementation.*
