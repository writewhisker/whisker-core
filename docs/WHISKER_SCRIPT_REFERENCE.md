# Whisker Script Quick Reference

A compact reference for Whisker Script syntax.

---

## Structure

```whisker
@@ title: Story Title          # Metadata
@@ author: Author Name

:: PassageName [tag1, tag2]    # Passage declaration
Content goes here.             # Text content
```

---

## Passages

```whisker
:: PassageName                 # Basic passage
:: PassageName [tag]           # With tag
:: PassageName [tag1, tag2]    # Multiple tags
```

---

## Choices

```whisker
+ [Text] -> Target             # Basic choice
+ [Text]                       # Choice with inline content
  Content here.
  -> Target

* [Text] -> Target             # One-time choice (consumed after use)
+ { $condition } [Text] -> T   # Conditional choice
```

---

## Variables

```whisker
~ $name = "value"              # String
~ $count = 42                  # Number
~ $flag = true                 # Boolean
~ $items = []                  # Empty list
~ $items = [1, 2, 3]           # List with values

~ $x += 10                     # Add
~ $x -= 5                      # Subtract
~ $x *= 2                      # Multiply
~ $x /= 4                      # Divide

~ $list[] = "item"             # Append to list
```

---

## Expressions

### Operators

| Type | Operators |
|------|-----------|
| Math | `+` `-` `*` `/` `%` |
| Compare | `==` `!=` `<` `>` `<=` `>=` |
| Logic | `and` `or` `not` |

### Literals

```whisker
42                             # Integer
3.14                           # Float
"hello"                        # String (double quotes only)
true / false                   # Boolean
null                           # Null
[1, 2, 3]                      # List
```

Note: Only double quotes for strings. Apostrophes allowed in text.

---

## Interpolation

```whisker
{$variable}                    # Variable value
{expression}                   # Expression result
{$a + $b}                      # Math in text
{fn($x)}                       # Function call
```

---

## Conditionals

### Block

```whisker
{ $condition:
    Content if true.
- $other_condition:
    Content if other is true.
- else:
    Content if all false.
}
```

### Inline

```whisker
{ $cond: if_true | if_false }
```

---

## Control Flow

```whisker
-> Target                      # Divert to passage
-> Target($arg1, $arg2)        # Divert with arguments
->-> Tunnel                    # Tunnel call (returns)
->->                           # Tunnel return
<- Thread                      # Start background thread
```

---

## Built-in Functions

### Math

| Function | Description |
|----------|-------------|
| `abs(x)` | Absolute value |
| `floor(x)` | Round down |
| `ceil(x)` | Round up |
| `round(x)` | Round to nearest |
| `min(a, b)` | Minimum |
| `max(a, b)` | Maximum |
| `random(a, b)` | Random integer in range |

### String

| Function | Description |
|----------|-------------|
| `len(s)` | Length |
| `upper(s)` | Uppercase |
| `lower(s)` | Lowercase |
| `trim(s)` | Remove whitespace |
| `substr(s, start, len)` | Substring |
| `contains(s, sub)` | Contains check |

### List

| Function | Description |
|----------|-------------|
| `count(list)` | Number of items |
| `first(list)` | First item |
| `last(list)` | Last item |
| `has(list, item)` | Contains item |
| `push(list, item)` | Add to end |
| `pop(list)` | Remove from end |

### Type

| Function | Description |
|----------|-------------|
| `type(x)` | Get type name |
| `str(x)` | Convert to string |
| `num(x)` | Convert to number |
| `bool(x)` | Convert to boolean |

### Story

| Function | Description |
|----------|-------------|
| `visited(passage)` | Visit count |
| `visit_count(passage)` | Same as visited |
| `turns()` | Total turns |
| `choice_count()` | Available choices |

---

## Metadata

```whisker
@@ title: Story Title
@@ author: Author Name
@@ version: "1.0.0"
@@ ifid: UUID
@@ custom_key: custom value
```

---

## Comments

```whisker
# Single line comment
## Block comment line 1
## Block comment line 2
```

---

## File Operations

```whisker
>> include "file.wsk"          # Include file
>> import "file.wsk" as name   # Import with alias
```

---

## Error Codes

| Range | Category |
|-------|----------|
| WSK00xx | Lexer errors |
| WSK01xx | Parser errors |
| WSK02xx | Semantic errors |

### Common Errors

| Code | Description |
|------|-------------|
| WSK0001 | Unexpected character |
| WSK0002 | Unterminated string |
| WSK0101 | Expected passage name |
| WSK0104 | Expected closing brace |
| WSK0200 | Undefined passage |
| WSK0202 | Undefined function |
| WSK0210 | Duplicate passage |
| WSK0230 | Wrong argument count |

---

## Quick Examples

### Minimal Story

```whisker
:: Start
Hello, world!
+ [End] -> End

:: End
Goodbye!
```

### Variables and Conditions

```whisker
:: Start
~ $gold = 100

You have {$gold} gold.

{ $gold >= 50:
    + [Buy sword (50g)]
      ~ $gold -= 50
      -> Start
}

+ [Leave] -> End
```

### Tunnel Pattern

```whisker
:: Scene
->-> DescribeRoom
What do you do?

:: DescribeRoom
The room is {$room_type}.
->->
```

---

*Whisker Script v1.0.0*
