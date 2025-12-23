-- Whisker Script Syntax Test Cases
-- Used for validating parser implementation

return {
  -- Valid syntax (should parse successfully)
  valid = {
    {
      name = "simple passage",
      source = [[
:: Start
Hello, world!
]],
      expect = "passage with id='Start', content='Hello, world!'"
    },

    {
      name = "choice with target",
      source = [[
:: Start
+ [Go north] -> North
]],
      expect = "choice with text='Go north', target='North'"
    },

    {
      name = "conditional content",
      source = [[
:: Start
{ $has_key }
The door is unlocked.
{ / }
]],
      expect = "conditional with expression='$has_key'"
    },

    {
      name = "variable assignment number",
      source = [[
:: Start
$gold = 100
]],
      expect = "assignment: $gold = 100"
    },

    {
      name = "variable assignment string",
      source = [[
:: Start
$name = "Alice"
]],
      expect = "assignment: $name = 'Alice'"
    },

    {
      name = "variable assignment boolean",
      source = [[
:: Start
$has_key = true
]],
      expect = "assignment: $has_key = true"
    },

    {
      name = "compound assignment",
      source = [[
:: Start
$gold += 50
$health -= 10
]],
      expect = "compound assignments"
    },

    {
      name = "complex expression",
      source = [[
:: Start
{ $gold >= 50 && $level > 3 }
You qualify!
{ / }
]],
      expect = "conditional with AND expression"
    },

    {
      name = "or expression",
      source = [[
:: Start
{ $has_sword || $has_axe }
You have a weapon.
{ / }
]],
      expect = "conditional with OR expression"
    },

    {
      name = "negation expression",
      source = [[
:: Start
{ !$visited }
First time here!
{ / }
]],
      expect = "conditional with NOT expression"
    },

    {
      name = "nested conditionals",
      source = [[
:: Start
{ $a }
  { $b }
    Content
  { / }
{ / }
]],
      expect = "nested conditional blocks"
    },

    {
      name = "choice with condition",
      source = [[
:: Start
+ { $has_sword } [Attack] -> Battle
]],
      expect = "conditional choice"
    },

    {
      name = "multiple choices",
      source = [[
:: Start
+ [Go north] -> North
+ [Go south] -> South
+ [Go east] -> East
]],
      expect = "three choices"
    },

    {
      name = "multiple passages",
      source = [[
:: Start
Content

:: Second
More content

:: Third
Even more
]],
      expect = "three passages"
    },

    {
      name = "line comments",
      source = [[
:: Start
// This is a comment
Content
// Another comment
]],
      expect = "passage with comments removed"
    },

    {
      name = "block comments",
      source = [[
:: Start
/* Block comment */
Content
/* Multi
   line */
]],
      expect = "passage with block comments removed"
    },

    {
      name = "comparison operators",
      source = [[
:: Start
{ $a == 1 }
equal
{ / }
{ $a != 2 }
not equal
{ / }
{ $a < 10 }
less than
{ / }
{ $a > 5 }
greater than
{ / }
{ $a <= 10 }
less than or equal
{ / }
{ $a >= 5 }
greater than or equal
{ / }
]],
      expect = "all comparison operators"
    },

    {
      name = "parenthesized expression",
      source = [[
:: Start
{ ($a || $b) && $c }
Complex logic
{ / }
]],
      expect = "parentheses override precedence"
    },

    {
      name = "embedded lua inline",
      source = [[
:: Start
$random = {{ math.random(1, 10) }}
]],
      expect = "embedded lua expression"
    },

    {
      name = "embedded lua block",
      source = [[
:: Start
{{
  local x = 1
  whisker.state:set("x", x)
}}
]],
      expect = "embedded lua block"
    },

    {
      name = "string with escapes",
      source = [[
:: Start
$message = "Hello \"World\""
]],
      expect = "string with escaped quotes"
    },

    {
      name = "decimal number",
      source = [[
:: Start
$price = 19.99
]],
      expect = "decimal number assignment"
    },

    {
      name = "variable in condition",
      source = [[
:: Start
{ $flag }
Shown if flag is truthy
{ / }
]],
      expect = "simple variable condition"
    },

    {
      name = "mixed content",
      source = [[
:: Start
Welcome to the adventure!
$gold = 100
$health = 100

You stand at a crossroads.

{ $has_map }
You consult your map.
{ / }

+ [Go north] -> North
+ { $gold >= 50 } [Buy supplies] -> Shop
+ [Rest] -> Rest
]],
      expect = "complex passage with all elements"
    },
  },

  -- Invalid syntax (should produce parse errors)
  invalid = {
    {
      name = "missing passage name",
      source = "::\nContent",
      expect_error = "expected identifier after ::"
    },

    {
      name = "choice without target",
      source = ":: Start\n+ [Go north]",
      expect_error = "expected -> after choice text"
    },

    {
      name = "choice without arrow",
      source = ":: Start\n+ [Go north] North",
      expect_error = "expected -> after choice text"
    },

    {
      name = "unclosed choice bracket",
      source = ":: Start\n+ [Go north -> North",
      expect_error = "expected ] to close choice text"
    },

    {
      name = "unclosed conditional",
      source = ":: Start\n{ $condition }\nContent",
      expect_error = "expected { / } to close conditional"
    },

    {
      name = "unclosed conditional brace",
      source = ":: Start\n{ $condition \nContent",
      expect_error = "expected } after condition"
    },

    {
      name = "invalid expression operator",
      source = ":: Start\n{ $a $b }",
      expect_error = "unexpected token in expression"
    },

    {
      name = "assignment without value",
      source = ":: Start\n$gold =",
      expect_error = "expected value after ="
    },

    {
      name = "assignment without operator",
      source = ":: Start\n$gold 100",
      expect_error = "expected assignment operator"
    },

    {
      name = "unclosed string",
      source = ':: Start\n$name = "Alice',
      expect_error = "unterminated string"
    },

    {
      name = "unclosed parenthesis",
      source = ":: Start\n{ ($a && $b }",
      expect_error = "expected ) to close grouping"
    },

    {
      name = "unclosed lua block",
      source = ":: Start\n{{ code",
      expect_error = "expected }} to close Lua block"
    },

    {
      name = "empty condition",
      source = ":: Start\n{ }",
      expect_error = "expected expression in condition"
    },

    {
      name = "choice text with newline",
      source = ":: Start\n+ [Go\nnorth] -> North",
      expect_error = "unexpected newline in choice text"
    },

    {
      name = "invalid identifier start",
      source = ":: 123Start",
      expect_error = "invalid passage name"
    },

    {
      name = "dangling operator",
      source = ":: Start\n{ $a && }",
      expect_error = "expected expression after &&"
    },

    {
      name = "double operator",
      source = ":: Start\n{ $a && || $b }",
      expect_error = "unexpected operator"
    },
  },

  -- Edge cases
  edge_cases = {
    {
      name = "empty passage",
      source = [[
:: Empty
:: Next
Content
]],
      expect = "first passage is empty"
    },

    {
      name = "passage name with underscores",
      source = ":: Start_Level_One\nContent",
      expect = "passage id includes underscores"
    },

    {
      name = "passage name with numbers",
      source = ":: Level2Boss\nContent",
      expect = "passage id includes numbers"
    },

    {
      name = "very long choice text",
      source = [[
:: Start
+ [This is a very long choice with lots of text that might wrap across multiple lines in the editor but should still work] -> Target
]],
      expect = "choice text can be arbitrarily long"
    },

    {
      name = "escaped braces in text",
      source = ":: Start\nShe said \\{hello\\}",
      expect = "literal braces in text content"
    },

    {
      name = "escaped dollar in text",
      source = ":: Start\nThe price is \\$100",
      expect = "literal dollar sign in text"
    },

    {
      name = "multiple newlines",
      source = ":: Start\n\n\nContent\n\n\n",
      expect = "extra newlines are whitespace"
    },

    {
      name = "tabs and spaces",
      source = ":: Start\n\t  Content\t  ",
      expect = "tabs and spaces handled"
    },

    {
      name = "windows line endings",
      source = ":: Start\r\nContent\r\n",
      expect = "CRLF normalized to LF"
    },

    {
      name = "zero value",
      source = ":: Start\n$count = 0",
      expect = "zero is valid number"
    },

    {
      name = "negative comparison",
      source = ":: Start\n{ $health > 0 }\nAlive\n{ / }",
      expect = "compare against zero"
    },

    {
      name = "deeply nested conditionals",
      source = [[
:: Start
{ $a }
{ $b }
{ $c }
{ $d }
Content
{ / }
{ / }
{ / }
{ / }
]],
      expect = "four levels of nesting"
    },

    {
      name = "inline comment after code",
      source = ":: Start\n$gold = 100 // initial gold\n",
      expect = "inline comment on same line"
    },

    {
      name = "empty string assignment",
      source = ':: Start\n$name = ""',
      expect = "empty string is valid"
    },

    {
      name = "boolean false",
      source = ":: Start\n$dead = false",
      expect = "false is valid boolean"
    },

    {
      name = "conditional at end of file",
      source = ":: Start\n{ $flag }\nContent\n{ / }",
      expect = "conditional can end file"
    },

    {
      name = "single character passage name",
      source = ":: A\nContent",
      expect = "single char name is valid"
    },

    {
      name = "underscore only identifier",
      source = ":: _\nContent",
      expect = "underscore alone is valid"
    },

    {
      name = "passage with only choices",
      source = [[
:: Start
+ [Option A] -> A
+ [Option B] -> B
]],
      expect = "passage can have only choices"
    },
  }
}
