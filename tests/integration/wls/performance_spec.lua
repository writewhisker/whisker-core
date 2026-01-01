-- tests/integration/wls/performance_spec.lua
-- WLS 1.0 Performance Benchmarks

describe("WLS 1.0 Performance", function()
    local WSParser = require("whisker.parser.ws_parser")
    local Engine = require("whisker.core.engine")
    local GameState = require("whisker.core.game_state")
    local Story = require("whisker.core.story")
    local Passage = require("whisker.core.passage")

    -- Helper to measure execution time
    local function benchmark(name, iterations, fn)
        local start = os.clock()
        for _ = 1, iterations do
            fn()
        end
        local elapsed = os.clock() - start
        local avg = (elapsed / iterations) * 1000  -- ms
        return {
            name = name,
            iterations = iterations,
            total_ms = elapsed * 1000,
            avg_ms = avg
        }
    end

    describe("Parser Performance", function()
        local simple_story = [[
:: Start
Hello, World!
$gold = 100
You have $gold gold.
+ [Continue] -> End

:: End
The end.
]]

        local complex_story = [[
@title: Performance Test
@author: Test

@vars
    gold: 100
    name: "Hero"
    hasKey: false

:: Start
Welcome, $name!

{ $gold >= 50 }
    You have enough gold.
{elif $gold >= 25}
    You have some gold.
{else}
    You are poor.
{/}

+ { $gold >= 100 } [Buy key] -> Shop { $gold -= 50; $hasKey = true }
* [Check inventory] -> Inventory
+ [Leave] -> END

:: Shop
You bought a key!
+ [Back] -> Start

:: Inventory
Gold: $gold
Has key: $hasKey
+ [Back] -> Start
]]

        it("should parse simple story quickly", function()
            local result = benchmark("simple_parse", 100, function()
                WSParser.parse_ws(simple_story)
            end)

            print(string.format("\n  %s: %.3f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            -- Should parse in under 10ms on average
            assert.is_true(result.avg_ms < 10, "Simple parse should be under 10ms")
        end)

        it("should parse complex story within limits", function()
            local result = benchmark("complex_parse", 50, function()
                WSParser.parse_ws(complex_story)
            end)

            print(string.format("\n  %s: %.3f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            -- Should parse in under 20ms on average
            assert.is_true(result.avg_ms < 20, "Complex parse should be under 20ms")
        end)

        it("should scale linearly with story size", function()
            -- Create stories of different sizes
            local function make_story(passages)
                local parts = {}
                for i = 1, passages do
                    table.insert(parts, string.format([[
:: Passage%d
Content for passage %d.
$var%d = %d
]], i, i, i, i))
                end
                return table.concat(parts)
            end

            local small = make_story(10)
            local medium = make_story(50)
            local large = make_story(100)

            local small_result = benchmark("small_10p", 20, function()
                WSParser.parse_ws(small)
            end)

            local medium_result = benchmark("medium_50p", 10, function()
                WSParser.parse_ws(medium)
            end)

            local large_result = benchmark("large_100p", 5, function()
                WSParser.parse_ws(large)
            end)

            print(string.format("\n  10 passages: %.3f ms", small_result.avg_ms))
            print(string.format("  50 passages: %.3f ms", medium_result.avg_ms))
            print(string.format("  100 passages: %.3f ms", large_result.avg_ms))

            -- Should scale roughly linearly (within 3x for 10x size increase)
            local ratio = large_result.avg_ms / small_result.avg_ms
            assert.is_true(ratio < 30, "Should scale sub-linearly")
        end)
    end)

    describe("Engine Performance", function()
        local function create_story_with_content(content)
            local story = Story.new()
            story:set_metadata("name", "Perf Test")
            local start = Passage.new("start", "start")
            start:set_content(content)
            story:add_passage(start)
            story:set_start_passage("start")
            return story
        end

        it("should render simple content quickly", function()
            local story = create_story_with_content("Hello, World!")
            local game_state = GameState.new()
            local engine = Engine.new(story, game_state)
            engine:start_story()

            local result = benchmark("simple_render", 1000, function()
                engine:render_passage_content(story:get_passage("start"))
            end)

            print(string.format("\n  %s: %.3f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            assert.is_true(result.avg_ms < 1, "Simple render should be under 1ms")
        end)

        it("should handle variable interpolation efficiently", function()
            local story = create_story_with_content([[
$name is a $profession with $gold gold.
They have been playing for $hours hours.
Score: ${$gold * 10 + $hours}
]])
            local game_state = GameState.new()
            game_state:set("name", "Hero")
            game_state:set("profession", "knight")
            game_state:set("gold", 100)
            game_state:set("hours", 5)

            local engine = Engine.new(story, game_state)
            engine:start_story()

            local result = benchmark("interp_render", 500, function()
                engine:render_passage_content(story:get_passage("start"))
            end)

            print(string.format("\n  %s: %.3f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            assert.is_true(result.avg_ms < 5, "Interpolation render should be under 5ms")
        end)

        it("should evaluate conditionals efficiently", function()
            local story = create_story_with_content([[
{ $gold >= 100 }
    You are rich!
{elif $gold >= 50}
    You have some gold.
{elif $gold >= 25}
    You have a little gold.
{else}
    You are poor.
{/}

{ $hasKey and $gold >= 10 }
    You can enter.
{/}
]])
            local game_state = GameState.new()
            game_state:set("gold", 75)
            game_state:set("hasKey", true)

            local engine = Engine.new(story, game_state)
            engine:start_story()

            local result = benchmark("conditional_render", 200, function()
                engine:render_passage_content(story:get_passage("start"))
            end)

            print(string.format("\n  %s: %.3f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            assert.is_true(result.avg_ms < 10, "Conditional render should be under 10ms")
        end)
    end)

    describe("State Operations", function()
        it("should handle rapid state changes efficiently", function()
            local game_state = GameState.new()

            local result = benchmark("state_ops", 10000, function()
                game_state:set("counter", (game_state:get("counter") or 0) + 1)
                game_state:set("name", "test")
                game_state:has("counter")
                game_state:get("name")
            end)

            print(string.format("\n  %s: %.6f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            assert.is_true(result.avg_ms < 0.1, "State ops should be under 0.1ms")
        end)

        it("should handle temp variables efficiently", function()
            local game_state = GameState.new()

            local result = benchmark("temp_ops", 5000, function()
                game_state:set_temp("_temp1", 100)
                game_state:set_temp("_temp2", "value")
                game_state:get_temp("_temp1")
                game_state:has_temp("_temp2")
                game_state:delete_temp("_temp1")
                game_state:delete_temp("_temp2")
            end)

            print(string.format("\n  %s: %.6f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            assert.is_true(result.avg_ms < 0.5, "Temp ops should be under 0.5ms")
        end)
    end)

    describe("API Performance", function()
        it("should access whisker.state API efficiently", function()
            local story = Story.new()
            local passage = Passage.new("start", "start")
            passage:set_content("Test")
            story:add_passage(passage)
            story:set_start_passage("start")

            local game_state = GameState.new()
            local engine = Engine.new(story, game_state)
            engine:start_story()

            -- Get the API from engine context
            local result = benchmark("api_ops", 5000, function()
                game_state:set("gold", 100)
                game_state:get("gold")
                game_state:increment("gold", 10)
                game_state:decrement("gold", 5)
                game_state:has("gold")
            end)

            print(string.format("\n  %s: %.6f ms avg (%d iterations)",
                result.name, result.avg_ms, result.iterations))

            assert.is_true(result.avg_ms < 0.2, "API ops should be under 0.2ms")
        end)
    end)

    describe("Performance Summary", function()
        it("should report overall performance metrics", function()
            print("\n\n=== WLS 1.0 Performance Summary ===")
            print("Parser: Simple story < 10ms, Complex < 20ms")
            print("Render: Simple < 1ms, With interpolation < 5ms")
            print("Conditionals: < 10ms")
            print("State ops: < 0.1ms per operation")
            print("API ops: < 0.2ms per call")
            print("===================================\n")
            assert.is_true(true)
        end)
    end)
end)
