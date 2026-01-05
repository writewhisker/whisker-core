-- tests/wls/test_parser_coverage.lua
-- Coverage expansion tests for WLS 1.0 parser edge cases

describe("WLS Parser Coverage Expansion", function()
    local WSLexer = require("whisker.parser.ws_lexer")
    local WSParser = require("whisker.parser.ws_parser")

    describe("Lexer Edge Cases", function()
        local lexer

        before_each(function()
            lexer = WSLexer.new()
        end)

        -- Empty and minimal inputs
        describe("Empty/Minimal Input", function()
            it("should handle empty input", function()
                local result = lexer:tokenize("")
                assert.is_true(result.success)
                assert.equals(1, #result.tokens)
                assert.equals("EOF", result.tokens[1].type)
            end)

            it("should handle single newline", function()
                local result = lexer:tokenize("\n")
                assert.is_true(result.success)
                local has_newline = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "NEWLINE" then has_newline = true end
                end
                assert.is_true(has_newline)
            end)

            it("should handle only whitespace", function()
                local result = lexer:tokenize("   \t\t   ")
                assert.is_true(result.success)
            end)

            it("should handle carriage return line endings", function()
                local result = lexer:tokenize("Hello\r\nWorld\r\n")
                assert.is_true(result.success)
            end)
        end)

        -- Dollar sign edge cases
        describe("Dollar Sign Edge Cases", function()
            it("should handle standalone $", function()
                local result = lexer:tokenize("Cost: $")
                assert.is_true(result.success)
                local found_text_dollar = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "TEXT" and t.value == "$" then
                        found_text_dollar = true
                    end
                end
                assert.is_true(found_text_dollar)
            end)

            it("should handle $ followed by number", function()
                local result = lexer:tokenize("Price: $100")
                assert.is_true(result.success)
            end)

            it("should handle multiple $$ characters", function()
                local result = lexer:tokenize("$$money")
                assert.is_true(result.success)
            end)

            it("should handle $ at end of line", function()
                local result = lexer:tokenize("Total$\nNext line")
                assert.is_true(result.success)
            end)
        end)

        -- String edge cases
        describe("String Edge Cases", function()
            it("should handle empty string", function()
                local result = lexer:tokenize('""')
                assert.is_true(result.success)
                local found_string = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "STRING" and t.value == "" then
                        found_string = true
                    end
                end
                assert.is_true(found_string)
            end)

            it("should handle escaped newline in string", function()
                local result = lexer:tokenize('"Line1\\nLine2"')
                assert.is_true(result.success)
            end)

            it("should handle escaped tab in string", function()
                local result = lexer:tokenize('"Tab\\there"')
                assert.is_true(result.success)
            end)

            it("should handle escaped quote in string", function()
                local result = lexer:tokenize('"He said \\"hello\\""')
                assert.is_true(result.success)
            end)

            it("should handle escaped backslash in string", function()
                local result = lexer:tokenize('"path\\\\to\\\\file"')
                assert.is_true(result.success)
            end)

            it("should handle unterminated string", function()
                local result = lexer:tokenize('"unclosed string\n')
                -- Should produce error
                assert.is_true(#result.errors > 0)
            end)
        end)

        -- Number edge cases
        describe("Number Edge Cases", function()
            it("should handle integer", function()
                local result = lexer:tokenize("42")
                assert.is_true(result.success)
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "NUMBER" and t.value == "42" then found = true end
                end
                assert.is_true(found)
            end)

            it("should handle decimal number", function()
                local result = lexer:tokenize("3.14159")
                assert.is_true(result.success)
            end)

            it("should handle number with trailing dot", function()
                local result = lexer:tokenize("42.")
                assert.is_true(result.success)
            end)

            it("should handle zero", function()
                local result = lexer:tokenize("0")
                assert.is_true(result.success)
            end)

            it("should handle large number", function()
                local result = lexer:tokenize("999999999999")
                assert.is_true(result.success)
            end)
        end)

        -- Block comment edge cases
        describe("Block Comment Edge Cases", function()
            it("should handle unterminated block comment", function()
                local result = lexer:tokenize("/* unclosed comment")
                assert.is_true(#result.errors > 0)
            end)

            it("should handle empty block comment", function()
                local result = lexer:tokenize("/**/")
                assert.is_true(result.success)
            end)

            it("should handle multiline block comment", function()
                local result = lexer:tokenize("/* line1\nline2\nline3 */")
                assert.is_true(result.success)
            end)

            it("should handle nested asterisks in comment", function()
                local result = lexer:tokenize("/* ** star ** */")
                assert.is_true(result.success)
            end)
        end)

        -- Directive edge cases
        describe("Directive Edge Cases", function()
            it("should handle directive with empty value", function()
                local result = lexer:tokenize("@title: ")
                assert.is_true(result.success)
            end)

            it("should handle directive with leading/trailing spaces", function()
                local result = lexer:tokenize("@author:    John Smith   ")
                assert.is_true(result.success)
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "DIRECTIVE" and t.value.name == "author" then
                        found = true
                        -- Value should be trimmed
                        assert.equals("John Smith", t.value.value)
                    end
                end
                assert.is_true(found)
            end)

            it("should handle @ without valid directive", function()
                local result = lexer:tokenize("@notadirective text")
                assert.is_true(result.success)
            end)

            it("should handle multiple directives", function()
                local result = lexer:tokenize("@title: A\n@author: B\n@version: 1.0")
                assert.is_true(result.success)
                local directive_count = 0
                for _, t in ipairs(result.tokens) do
                    if t.type == "DIRECTIVE" then directive_count = directive_count + 1 end
                end
                assert.equals(3, directive_count)
            end)
        end)

        -- Collection keywords edge cases
        describe("Collection Keywords", function()
            it("should tokenize LIST at line start", function()
                local result = lexer:tokenize("LIST colors = red, blue")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "LIST" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize ARRAY at line start", function()
                local result = lexer:tokenize("ARRAY items = a, b, c")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "ARRAY" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize MAP at line start", function()
                local result = lexer:tokenize("MAP scores = name: 10")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "MAP" then found = true end
                end
                assert.is_true(found)
            end)

            it("should not tokenize LIST in middle of text", function()
                local result = lexer:tokenize("This is a LIST of things")
                for _, t in ipairs(result.tokens) do
                    assert.is_not_equal("LIST", t.type)
                end
            end)
        end)

        -- Module keywords edge cases
        describe("Module Keywords", function()
            it("should tokenize INCLUDE", function()
                local result = lexer:tokenize('INCLUDE "module.ws"')
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "INCLUDE" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize FUNCTION", function()
                local result = lexer:tokenize("FUNCTION greet(name)")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "FUNCTION" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize NAMESPACE", function()
                local result = lexer:tokenize("NAMESPACE Utils")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "NAMESPACE" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize END at line end", function()
                local result = lexer:tokenize("END\n")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "END" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize END at end of file", function()
                local result = lexer:tokenize("END")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "END" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize RETURN", function()
                local result = lexer:tokenize("RETURN value")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "RETURN" then found = true end
                end
                assert.is_true(found)
            end)
        end)

        -- Presentation keywords edge cases
        describe("Presentation Keywords", function()
            it("should tokenize THEME", function()
                local result = lexer:tokenize('THEME "dark"')
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "THEME" then found = true end
                end
                assert.is_true(found)
            end)

            it("should tokenize STYLE", function()
                local result = lexer:tokenize("STYLE { color: red }")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "STYLE" then found = true end
                end
                assert.is_true(found)
            end)
        end)

        -- Scope operator edge cases
        describe("Scope Operator", function()
            it("should tokenize :: as PASSAGE_MARKER at line start", function()
                local result = lexer:tokenize(":: Passage")
                assert.equals("PASSAGE_MARKER", result.tokens[1].type)
            end)

            it("should tokenize :: as SCOPE_OP in expressions", function()
                local result = lexer:tokenize("Utils::greet()")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "SCOPE_OP" then found = true end
                end
                assert.is_true(found)
            end)
        end)

        -- Choice context edge cases
        describe("Choice Context Edge Cases", function()
            it("should handle nested choices + +", function()
                local result = lexer:tokenize("+ + Nested choice")
                local choice_count = 0
                for _, t in ipairs(result.tokens) do
                    if t.type == "CHOICE_ONCE" then choice_count = choice_count + 1 end
                end
                assert.equals(2, choice_count)
            end)

            it("should handle mixed choice markers + *", function()
                local result = lexer:tokenize("+ * Mixed choice")
                local once_count, sticky_count = 0, 0
                for _, t in ipairs(result.tokens) do
                    if t.type == "CHOICE_ONCE" then once_count = once_count + 1 end
                    if t.type == "CHOICE_STICKY" then sticky_count = sticky_count + 1 end
                end
                assert.equals(1, once_count)
                assert.equals(1, sticky_count)
            end)

            it("should not tokenize + in middle of text as choice", function()
                local result = lexer:tokenize("1 + 2 = 3")
                for _, t in ipairs(result.tokens) do
                    assert.is_not_equal("CHOICE_ONCE", t.type)
                end
            end)

            it("should handle choice after block close", function()
                local result = lexer:tokenize("{condition}\n{/}\n+ After close")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "CHOICE_ONCE" then found = true end
                end
                assert.is_true(found)
            end)

            it("should handle choice after else", function()
                local result = lexer:tokenize("{else}\n+ After else")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "CHOICE_ONCE" then found = true end
                end
                assert.is_true(found)
            end)
        end)

        -- Gather edge cases
        describe("Gather Edge Cases", function()
            it("should handle nested gather - -", function()
                local result = lexer:tokenize("- - Nested gather")
                local gather_count = 0
                for _, t in ipairs(result.tokens) do
                    if t.type == "GATHER" then gather_count = gather_count + 1 end
                end
                assert.equals(2, gather_count)
            end)

            it("should not confuse - with -> arrow", function()
                local result = lexer:tokenize("->Target")
                for _, t in ipairs(result.tokens) do
                    assert.is_not_equal("GATHER", t.type)
                end
            end)
        end)

        -- Elif edge cases
        describe("Elif Edge Cases", function()
            it("should capture elif condition", function()
                local result = lexer:tokenize("{elif x > 5}")
                assert.equals("ELIF", result.tokens[1].type)
                assert.equals("x > 5", result.tokens[1].value)
            end)

            it("should handle complex elif condition", function()
                local result = lexer:tokenize("{elif health > 50 and mana > 25}")
                assert.equals("ELIF", result.tokens[1].type)
            end)
        end)

        -- Token location tracking
        describe("Token Location Tracking", function()
            it("should track line numbers", function()
                local result = lexer:tokenize("Line1\nLine2\nLine3")
                assert.is_true(result.success)
                -- Check that later tokens have higher line numbers
                local max_line = 0
                for _, t in ipairs(result.tokens) do
                    if t.line and t.line > max_line then max_line = t.line end
                end
                assert.is_true(max_line >= 3)
            end)

            it("should track column positions", function()
                local result = lexer:tokenize(":: Passage")
                assert.is_true(result.success)
                -- First token should be at column 1
                assert.is_true(result.tokens[1].column ~= nil)
            end)
        end)
    end)

    describe("Parser Edge Cases", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        -- Empty input
        describe("Empty/Minimal Input", function()
            it("should handle empty input", function()
                local result = parser:parse("")
                -- Parser should succeed with empty story
                assert.is_not_nil(result)
            end)

            it("should handle only whitespace", function()
                local result = parser:parse("   \n\n   ")
                assert.is_not_nil(result)
            end)

            it("should handle only comments", function()
                local result = parser:parse("// This is a comment\n/* Block comment */")
                assert.is_not_nil(result)
            end)
        end)

        -- Header parsing
        describe("Header Parsing", function()
            it("should parse story with only metadata", function()
                local result = parser:parse("@title: Test\n@author: Author")
                assert.is_true(result.success)
                assert.equals("Test", result.story.metadata.title)
                assert.equals("Author", result.story.metadata.author)
            end)

            it("should parse all standard directives", function()
                local input = [[
@title: My Story
@author: Writer
@version: 1.0.0
@ifid: 12345678-1234-1234-1234-123456789012

:: Start
Content
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should handle @vars block", function()
                local input = [[
@vars
  health: 100
  gold: 50
  name: "Hero"

:: Start
Welcome!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Passage parsing
        describe("Passage Parsing", function()
            it("should parse minimal passage", function()
                local result = parser:parse(":: Start\n")
                assert.is_true(result.success)
            end)

            it("should parse passage with content", function()
                local result = parser:parse(":: Start\nThis is the content")
                assert.is_true(result.success)
            end)

            it("should parse multiple passages", function()
                local input = [[
:: Start
First passage

:: Middle
Second passage

:: End
Third passage
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                -- Check passage count
                local count = 0
                for _ in pairs(result.story.passages) do count = count + 1 end
                assert.equals(3, count)
            end)

            it("should handle duplicate passage names", function()
                local input = [[
:: Duplicate
First

:: Duplicate
Second
]]
                local result = parser:parse(input)
                -- Should succeed but track duplicates or warn
                assert.is_not_nil(result)
            end)

            it("should handle passage with special characters in title", function()
                local result = parser:parse(":: My Passage (v2)\nContent")
                assert.is_true(result.success)
            end)
        end)

        -- Choice parsing
        describe("Choice Parsing", function()
            it("should parse once-only choice", function()
                local input = [[
:: Start
+ [Go north] -> North
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse sticky choice", function()
                local input = [[
:: Start
* [Look around] -> Look
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse choice with condition", function()
                local input = [[
:: Start
+ {gold > 10} [Buy item] -> Shop
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse choice with action", function()
                local input = [[
:: Start
+ [Take gold] @{gold = gold + 10} -> Next
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse choice with no display text (fallback)", function()
                local input = [[
:: Start
+ -> Next
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Gather parsing
        describe("Gather Parsing", function()
            it("should parse basic gather", function()
                local input = [[
:: Start
+ [Option A] Choice A content
+ [Option B] Choice B content
- Gathered content after choices
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse nested gathers", function()
                local input = [[
:: Start
+ + [Nested choice]
  - - Inner gather
- Outer gather
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Tunnel parsing
        describe("Tunnel Parsing", function()
            it("should parse tunnel call", function()
                local input = [[
:: Start
Going to helper
-> Helper ->
Back from helper

:: Helper
Helper content
<-
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse tunnel return", function()
                local input = [[
:: Helper
Some helper content
<-
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Conditional parsing
        describe("Conditional Parsing", function()
            it("should parse simple conditional", function()
                local input = [[
:: Start
{health > 50}
You feel strong.
{/}
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse if/else conditional", function()
                local input = [[
:: Start
{health > 50}
Strong
{else}
Weak
{/}
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse if/elif/else", function()
                local input = [[
:: Start
{health > 75}
Very strong
{elif health > 50}
Somewhat strong
{elif health > 25}
Weak
{else}
Very weak
{/}
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Alternative content
        describe("Alternative Content Parsing", function()
            it("should parse cycle alternatives", function()
                local input = [[
:: Start
{&| first | second | third }
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse shuffle alternatives", function()
                local input = [[
:: Start
{~| red | blue | green }
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse once alternatives", function()
                local input = [[
:: Start
{!| special message | fallback }
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Collection parsing
        describe("Collection Parsing", function()
            it("should tokenize LIST declaration", function()
                -- LIST parsing may not be fully implemented in parser yet
                -- Just verify the lexer handles it
                local WSLexer = require("whisker.parser.ws_lexer")
                local lexer = WSLexer.new()
                local result = lexer:tokenize("LIST colors = red, blue, green")
                assert.is_true(result.success)
            end)

            it("should tokenize ARRAY declaration", function()
                local WSLexer = require("whisker.parser.ws_lexer")
                local lexer = WSLexer.new()
                local result = lexer:tokenize("ARRAY inventory = sword, shield, potion")
                assert.is_true(result.success)
            end)

            it("should tokenize MAP declaration", function()
                local WSLexer = require("whisker.parser.ws_lexer")
                local lexer = WSLexer.new()
                local result = lexer:tokenize("MAP prices = apple: 5, bread: 3, cheese: 8")
                assert.is_true(result.success)
            end)
        end)

        -- Module parsing
        describe("Module Parsing", function()
            it("should parse INCLUDE directive", function()
                local input = [[
INCLUDE "helpers.ws"

:: Start
Using included content
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse FUNCTION definition", function()
                local input = [[
FUNCTION greet(name)
  return "Hello, " .. name
END

:: Start
$greet("World")
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse NAMESPACE", function()
                local input = [[
NAMESPACE Utils

FUNCTION helper()
  return 42
END

END

:: Start
$Utils::helper()
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Presentation parsing
        describe("Presentation Parsing", function()
            it("should parse THEME directive", function()
                local input = [[
THEME "dark"

:: Start
Dark theme content
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should tokenize STYLE keyword", function()
                -- STYLE parsing may not be fully implemented in parser yet
                -- Just verify the lexer handles it
                local WSLexer = require("whisker.parser.ws_lexer")
                local lexer = WSLexer.new()
                local result = lexer:tokenize("STYLE { color: red }")
                local found = false
                for _, t in ipairs(result.tokens) do
                    if t.type == "STYLE" then found = true end
                end
                assert.is_true(found)
            end)
        end)

        -- Variable interpolation
        describe("Variable Interpolation", function()
            it("should parse $varName in content", function()
                local input = [[
:: Start
Hello, $playerName! You have $gold gold.
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse ${expression}", function()
                local input = [[
:: Start
You have ${gold * 2} coins after doubling.
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should parse $_tempVar", function()
                local input = [[
:: Start
Temporary value: $_counter
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)

        -- Error recovery
        describe("Error Recovery", function()
            it("should recover from missing passage marker", function()
                local input = [[
Start without marker

:: Proper
Proper passage
]]
                local result = parser:parse(input)
                -- Parser should handle gracefully
                assert.is_not_nil(result)
            end)

            it("should handle malformed choice", function()
                local input = [[
:: Start
+ [] ->
]]
                local result = parser:parse(input)
                assert.is_not_nil(result)
            end)
        end)

        -- Special targets
        describe("Special Targets", function()
            it("should recognize END target", function()
                local input = [[
:: Start
+ [Finish] -> END
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should recognize BACK target", function()
                local input = [[
:: Start
+ [Go back] -> BACK
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)

            it("should recognize RESTART target", function()
                local input = [[
:: Start
+ [Start over] -> RESTART
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
            end)
        end)
    end)
end)
