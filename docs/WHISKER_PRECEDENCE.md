# Whisker Script Operator Precedence and Associativity

**Version:** 1.0

## Precedence Table (High to Low)

| Level | Operator | Description | Associativity |
|-------|----------|-------------|---------------|
| 1 (highest) | `!` | Logical NOT | Right |
| 2 | `<`, `>`, `<=`, `>=` | Comparison | Left |
| 3 | `==`, `!=` | Equality | Left |
| 4 | `&&` | Logical AND | Left |
| 5 (lowest) | `\|\|` | Logical OR | Left |

## Precedence Examples

### NOT has highest precedence

```whisker
!$a && $b        -> (!$a) && $b
!$a || $b        -> (!$a) || $b
```

### AND before OR

```whisker
$a || $b && $c   -> $a || ($b && $c)
$a && $b || $c   -> ($a && $b) || $c
```

### Equality before logical

```whisker
$a == $b || $c   -> ($a == $b) || $c
$a == $b && $c   -> ($a == $b) && $c
```

### Comparison before equality

```whisker
$a < $b == $c    -> ($a < $b) == $c
$a >= $b && $c   -> ($a >= $b) && $c
```

### Complex expressions

```whisker
$a < $b && $c > $d           -> ($a < $b) && ($c > $d)
$a == 1 || $b == 2 && $c     -> ($a == 1) || (($b == 2) && $c)
!$a && $b || $c              -> ((!$a) && $b) || $c
```

## Parentheses Override Precedence

```whisker
($a || $b) && $c    -> Evaluate OR first, then AND
!($a && $b)         -> Evaluate AND first, then NOT
($a == $b) || ($c != $d)  -> Explicit grouping for clarity
```

## Assignment Operators

Assignment has the lowest precedence and is right-associative:

```whisker
$a = $b == $c       -> $a = ($b == $c)
$gold += 50         -> $gold = $gold + 50 (semantically)
```

**Note:** Chained assignments like `$a = $b = 100` are not supported.

## Expression Evaluation

Expressions in Whisker Script evaluate to boolean values for conditionals:

| Expression | Result Type | Example |
|------------|-------------|---------|
| Comparison | boolean | `$gold > 50` -> `true` or `false` |
| Equality | boolean | `$name == "Alice"` -> `true` or `false` |
| Logical | boolean | `$a && $b` -> `true` or `false` |
| Variable | value | `$has_key` -> `true`, `false`, number, or string |
| Literal | value | `100`, `"hello"`, `true` |

## Truthiness Rules

In boolean contexts, values are evaluated as:

| Value | Boolean Interpretation |
|-------|----------------------|
| `true` | true |
| `false` | false |
| `0` | false |
| non-zero number | true |
| empty string `""` | false |
| non-empty string | true |
| `nil` | false |

## Comparison Rules

### Numeric Comparison

```whisker
{ $gold > 50 }      // Compare numbers
{ $level >= 10 }    // Works with integers and floats
```

### String Comparison

```whisker
{ $name == "Alice" }   // Exact string match
{ $status != "dead" }  // String inequality
```

### Boolean Comparison

```whisker
{ $has_key == true }   // Explicit boolean check
{ $has_key }           // Shorthand (truthy check)
{ !$has_key }          // Shorthand for false check
```

## Implementation Notes

### Parser Implementation

The parser uses **precedence climbing** (Pratt parsing) for expressions:

```lua
function parse_expression(min_precedence)
  local left = parse_unary()

  while current_precedence() >= min_precedence do
    local op = consume_operator()
    local right = parse_expression(precedence_of(op) + 1)
    left = BinaryOp(op, left, right)
  end

  return left
end
```

### Precedence Values

```lua
local PRECEDENCE = {
  ["||"] = 1,
  ["&&"] = 2,
  ["=="] = 3, ["!="] = 3,
  ["<"] = 4, [">"] = 4, ["<="] = 4, [">="] = 4,
}

local UNARY_PRECEDENCE = 5  -- '!' has highest
```

---

*This precedence specification guides parser implementation for expressions.*
