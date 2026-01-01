-- tests/wls/test_ws_format.lua
-- WLS 1.0 .ws Format Parser Tests

describe("WLS 1.0 .ws Format", function()
    local WSLexer = require("whisker.parser.ws_lexer")
    local WSParser = require("whisker.parser.ws_parser")

    describe("Lexer", function()
        local lexer

        before_each(function()
            lexer = WSLexer.new()
        end)

        describe("Passage Markers", function()
            it("should tokenize passage marker ::", function()
                local result = lexer:tokenize(":: Start")
                assert.is_true(result.success)
                assert.equals("PASSAGE_MARKER", result.tokens[1].type)
            end)

            it("should tokenize multiple passages", function()
                local result = lexer:tokenize(":: First\n:: Second")
                local passage_count = 0
                for _, token in ipairs(result.tokens) do
                    if token.type == "PASSAGE_MARKER" then
                        passage_count = passage_count + 1
                    end
                end
                assert.equals(2, passage_count)
            end)
        end)

        describe("Directives", function()
            it("should tokenize @title directive", function()
                local result = lexer:tokenize("@title: My Story")
                assert.is_true(result.success)
                assert.equals("DIRECTIVE", result.tokens[1].type)
                assert.equals("title", result.tokens[1].value.name)
                assert.equals("My Story", result.tokens[1].value.value)
            end)

            it("should tokenize @author directive", function()
                local result = lexer:tokenize("@author: Jane Writer")
                assert.is_true(result.success)
                assert.equals("author", result.tokens[1].value.name)
                assert.equals("Jane Writer", result.tokens[1].value.value)
            end)

            it("should tokenize @vars block start", function()
                local result = lexer:tokenize("@vars\n  gold: 100")
                assert.is_true(result.success)
                assert.equals("VARS_START", result.tokens[1].type)
            end)
        end)

        describe("Choices", function()
            it("should tokenize once-only choice +", function()
                local result = lexer:tokenize("+ [Go north] -> North")
                assert.is_true(result.success)
                assert.equals("CHOICE_ONCE", result.tokens[1].type)
            end)

            it("should tokenize sticky choice *", function()
                local result = lexer:tokenize("* [Look around] -> Look")
                assert.is_true(result.success)
                assert.equals("CHOICE_STICKY", result.tokens[1].type)
            end)

            it("should tokenize arrow ->", function()
                local result = lexer:tokenize("-> Target")
                assert.is_true(result.success)
                assert.equals("ARROW", result.tokens[1].type)
            end)
        end)

        describe("Interpolation", function()
            it("should tokenize $varName", function()
                local result = lexer:tokenize("Hello $playerName!")
                local found = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "VAR_INTERP" and token.value == "playerName" then
                        found = true
                        break
                    end
                end
                assert.is_true(found)
            end)

            it("should tokenize ${expr}", function()
                local result = lexer:tokenize("You have ${gold * 2} coins")
                local found = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "EXPR_INTERP" and token.value == "gold * 2" then
                        found = true
                        break
                    end
                end
                assert.is_true(found)
            end)

            it("should tokenize $_tempVar", function()
                local result = lexer:tokenize("Temp value: $_counter")
                local found = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "TEMP_VAR_INTERP" and token.value == "_counter" then
                        found = true
                        break
                    end
                end
                assert.is_true(found)
            end)
        end)

        describe("Comments", function()
            it("should skip line comments //", function()
                local result = lexer:tokenize("Hello // this is a comment\nWorld")
                assert.is_true(result.success)
                -- Comment should not appear in tokens
                for _, token in ipairs(result.tokens) do
                    assert.is_not_equal("LINE_COMMENT", token.type)
                end
            end)

            it("should skip block comments /* */", function()
                local result = lexer:tokenize("Hello /* block comment */ World")
                assert.is_true(result.success)
                for _, token in ipairs(result.tokens) do
                    assert.is_not_equal("BLOCK_COMMENT", token.type)
                end
            end)
        end)

        describe("Control Flow", function()
            it("should tokenize block start {", function()
                local result = lexer:tokenize("{ condition }")
                local found = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "BLOCK_START" then
                        found = true
                        break
                    end
                end
                assert.is_true(found)
            end)

            it("should tokenize block close {/}", function()
                local result = lexer:tokenize("{/}")
                assert.equals("BLOCK_CLOSE", result.tokens[1].type)
            end)

            it("should tokenize {else}", function()
                local result = lexer:tokenize("{else}")
                assert.equals("ELSE", result.tokens[1].type)
            end)

            it("should tokenize {elif ...}", function()
                local result = lexer:tokenize("{elif x > 5}")
                assert.equals("ELIF", result.tokens[1].type)
                assert.equals("x > 5", result.tokens[1].value)
            end)

            it("should tokenize pipe |", function()
                local result = lexer:tokenize("{| a | b | c }")
                local pipe_count = 0
                for _, token in ipairs(result.tokens) do
                    if token.type == "PIPE" then
                        pipe_count = pipe_count + 1
                    end
                end
                assert.equals(3, pipe_count)
            end)

            it("should tokenize ampersand & for cycle mode", function()
                local result = lexer:tokenize("{&| one | two | three }")
                assert.is_true(result.success)
                local found_ampersand = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "AMPERSAND" then
                        found_ampersand = true
                        break
                    end
                end
                assert.is_true(found_ampersand)
            end)

            it("should tokenize tilde ~ for shuffle mode", function()
                local result = lexer:tokenize("{~| red | blue | green }")
                assert.is_true(result.success)
                local found_tilde = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "TILDE" then
                        found_tilde = true
                        break
                    end
                end
                assert.is_true(found_tilde)
            end)

            it("should tokenize exclamation ! for once mode", function()
                local result = lexer:tokenize("{!| first | fallback }")
                assert.is_true(result.success)
                local found_exclamation = false
                for _, token in ipairs(result.tokens) do
                    if token.type == "EXCLAMATION" then
                        found_exclamation = true
                        break
                    end
                end
                assert.is_true(found_exclamation)
            end)
        end)
    end)

    describe("Parser", function()
        local parser

        before_each(function()
            parser = WSParser.new()
        end)

        describe("Header Parsing", function()
            it("should parse story title", function()
                local result = parser:parse("@title: My Adventure\n:: Start\nHello")
                assert.is_true(result.success)
                assert.equals("My Adventure", result.story.metadata.title)
            end)

            it("should parse multiple header directives", function()
                local input = [[
@title: Test Story
@author: Test Author
@version: 1.0.0
@ifid: 12345-67890

:: Start
Welcome!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals("Test Story", result.story.metadata.title)
                assert.equals("Test Author", result.story.metadata.author)
                assert.equals("1.0.0", result.story.metadata.version)
                assert.equals("12345-67890", result.story.metadata.ifid)
            end)

            it("should parse @start directive", function()
                local result = parser:parse("@start: Intro\n:: Intro\nHello")
                assert.is_true(result.success)
                assert.equals("Intro", result.story.start_passage_name)
            end)
        end)

        describe("Variables Block", function()
            it("should parse @vars block with numbers", function()
                local input = [[
@vars
  gold: 100
  health: 50

:: Start
You have $gold gold.
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(100, result.story.variables.gold.value)
                assert.equals(50, result.story.variables.health.value)
            end)

            it("should parse @vars block with strings", function()
                local input = [[
@vars
  playerName: "Hero"

:: Start
Hello $playerName!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals("Hero", result.story.variables.playerName.value)
            end)

            it("should parse @vars block with booleans", function()
                local input = [[
@vars
  hasKey: false

:: Start
Test
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(false, result.story.variables.hasKey.value)
            end)
        end)

        describe("Passage Parsing", function()
            it("should parse passage name", function()
                local result = parser:parse(":: Start\nHello world!")
                assert.is_true(result.success)
                assert.is_not_nil(result.story.passage_by_name["Start"])
            end)

            it("should parse passage content", function()
                local result = parser:parse(":: Start\nHello world!")
                assert.is_true(result.success)
                assert.is_not_nil(result.story.passage_by_name["Start"].content:match("Hello world"))
            end)

            it("should parse multiple passages", function()
                local input = [[
:: Start
Welcome!

:: Second
The second passage.

:: Third
The third passage.
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.is_not_nil(result.story.passage_by_name["Start"])
                assert.is_not_nil(result.story.passage_by_name["Second"])
                assert.is_not_nil(result.story.passage_by_name["Third"])
            end)

            it("should parse passage tags", function()
                local input = [[
:: Start
@tags: beginning, tutorial

Welcome!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                local tags = result.story.passage_by_name["Start"].tags
                assert.equals(2, #tags)
                assert.equals("beginning", tags[1])
                assert.equals("tutorial", tags[2])
            end)

            it("should parse passage onEnter script", function()
                local input = [[
:: Start
@onEnter: whisker.state.set("visited", true)

Welcome!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.is_not_nil(result.story.passage_by_name["Start"].on_enter_script)
            end)
        end)

        describe("Choice Parsing", function()
            it("should parse once-only choice", function()
                local input = [[
:: Start
Welcome!
+ [Go north] -> North
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                local choices = result.story.passage_by_name["Start"].choices
                assert.equals(1, #choices)
                assert.equals("Go north", choices[1].text)
                assert.equals("North", choices[1].target)
                assert.equals("once", choices[1].choice_type)
            end)

            it("should parse sticky choice", function()
                local input = [[
:: Start
Welcome!
* [Look around] -> Start
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                local choices = result.story.passage_by_name["Start"].choices
                assert.equals("sticky", choices[1].choice_type)
            end)

            it("should parse multiple choices", function()
                local input = [[
:: Start
Make a choice:
+ [Option A] -> A
+ [Option B] -> B
* [Look around] -> Start
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                local choices = result.story.passage_by_name["Start"].choices
                assert.equals(3, #choices)
            end)

            it("should parse special target END", function()
                local input = [[
:: Start
+ [End game] -> END
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals("END", result.story.passage_by_name["Start"].choices[1].target)
            end)

            it("should parse special target BACK", function()
                local input = [[
:: Start
+ [Go back] -> BACK
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals("BACK", result.story.passage_by_name["Start"].choices[1].target)
            end)

            it("should parse special target RESTART", function()
                local input = [[
:: Start
+ [Restart] -> RESTART
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals("RESTART", result.story.passage_by_name["Start"].choices[1].target)
            end)
        end)

        describe("Variable Interpolation in Content", function()
            it("should preserve $var in content", function()
                local input = [[
:: Start
You have $gold gold coins.
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.is_not_nil(result.story.passage_by_name["Start"].content:match("%$gold"))
            end)

            it("should preserve ${expr} in content", function()
                local input = [[
:: Start
Double gold: ${gold * 2}
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.is_not_nil(result.story.passage_by_name["Start"].content:match("%${gold %* 2}"))
            end)
        end)

        describe("Control Flow in Content", function()
            it("should preserve conditionals in content", function()
                local input = [[
:: Start
{ visited }
  Welcome back!
{else}
  First time here.
{/}
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                local content = result.story.passage_by_name["Start"].content
                assert.is_not_nil(content:match("{"))
                assert.is_not_nil(content:match("{else}"))
                assert.is_not_nil(content:match("{/}"))
            end)
        end)

        describe("Validation", function()
            it("should warn about missing passage references", function()
                local input = [[
:: Start
+ [Go somewhere] -> NonExistent
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(1, #result.warnings)
                assert.is_not_nil(result.warnings[1].message:match("NonExistent"))
            end)

            it("should include error code for missing passage reference", function()
                local input = [[
:: Start
+ [Go somewhere] -> NonExistent
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(1, #result.warnings)
                assert.equals("WLS-REF-001", result.warnings[1].code)
                assert.is_not_nil(result.warnings[1].suggestion)
            end)

            it("should warn about duplicate passages with error code", function()
                local input = [[
:: Start
Hello

:: Start
Duplicate!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(1, #result.warnings)
                assert.equals("WLS-STR-001", result.warnings[1].code)
                assert.is_not_nil(result.warnings[1].suggestion)
            end)

            it("should not warn about special targets", function()
                local input = [[
:: Start
+ [End] -> END
+ [Back] -> BACK
+ [Restart] -> RESTART
]]
                local result = parser:parse(input)
                assert.is_true(result.success)
                assert.equals(0, #result.warnings)
            end)
        end)

        describe("Story Building", function()
            it("should build Story object from parsed data", function()
                local input = [[
@title: Test Story
@start: Start

:: Start
Welcome!
+ [Continue] -> End

:: End
Goodbye!
]]
                local result = parser:parse(input)
                assert.is_true(result.success)

                local story = parser:build_story()
                assert.is_not_nil(story)
                assert.equals("Test Story", story.metadata.title)
                assert.is_not_nil(story:get_passage_by_name("Start"))
                assert.is_not_nil(story:get_passage_by_name("End"))
            end)
        end)
    end)

    describe("Complete Example", function()
        it("should parse WLS 1.0 example story", function()
            local input = [[
@title: The Lost Key
@author: Example Author
@version: 1.0.0
@ifid: 123e4567-e89b-12d3-a456-426614174000
@start: Start

@vars
  gold: 50
  hasKey: false
  playerName: "Traveler"

:: Start
@tags: beginning
@color: #3498db

Welcome, $playerName!

You find yourself at the entrance to a mysterious dungeon.
Your purse contains $gold gold coins.

+ [Enter the dungeon] -> DungeonEntrance
+ [Search the area] -> SearchArea

:: SearchArea
You search the surrounding area carefully.

{ whisker.visited("SearchArea") == 1 }
  You find 10 gold coins!
{else}
  Nothing new to find.
{/}

+ [Enter the dungeon] -> DungeonEntrance
* [Keep searching] -> SearchArea

:: DungeonEntrance
@tags: dungeon, main

The dungeon entrance looms before you.

{ $hasKey }
  The iron gate stands open.
  + [Proceed inside] -> END
{else}
  A locked iron gate blocks your path.
  + [Look for another way] -> SearchArea
{/}

+ [Leave this place] -> END
]]
            local result = WSParser.new():parse(input)
            assert.is_true(result.success)

            -- Check metadata
            assert.equals("The Lost Key", result.story.metadata.title)
            assert.equals("Example Author", result.story.metadata.author)

            -- Check variables
            assert.equals(50, result.story.variables.gold.value)
            assert.equals(false, result.story.variables.hasKey.value)
            assert.equals("Traveler", result.story.variables.playerName.value)

            -- Check passages
            assert.is_not_nil(result.story.passage_by_name["Start"])
            assert.is_not_nil(result.story.passage_by_name["SearchArea"])
            assert.is_not_nil(result.story.passage_by_name["DungeonEntrance"])

            -- Check Start passage
            local start = result.story.passage_by_name["Start"]
            assert.equals(2, #start.choices)
            assert.equals("beginning", start.tags[1])

            -- Check SearchArea passage has sticky choice
            local search = result.story.passage_by_name["SearchArea"]
            local has_sticky = false
            for _, choice in ipairs(search.choices) do
                if choice.choice_type == "sticky" then
                    has_sticky = true
                    break
                end
            end
            assert.is_true(has_sticky)

            -- Check DungeonEntrance tags
            local dungeon = result.story.passage_by_name["DungeonEntrance"]
            assert.equals(2, #dungeon.tags)
        end)
    end)
end)
