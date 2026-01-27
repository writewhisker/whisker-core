#!/usr/bin/env lua
-- Demo script for GAP-030 through GAP-036
-- Run with: lua tests/wls/test_gap_030_036_demo.lua

-- Add lib to path
package.path = './lib/?.lua;./lib/?/init.lua;' .. package.path

local ControlFlow = require("whisker.core.control_flow")
local Renderer = require("whisker.core.renderer")
local WSParser = require("whisker.parser.ws_parser")

-- Mock GameState for testing
local function MockGameState()
    local gs = {
        _vars = {},
        _temp = {}
    }
    function gs:get(key)
        return self._vars[key]
    end
    function gs:set(key, value)
        self._vars[key] = value
    end
    function gs:get_temp(key)
        return self._temp[key]
    end
    function gs:set_temp(key, value)
        self._temp[key] = value
    end
    return gs
end

print("=" .. string.rep("=", 60))
print("WLS 1.0 Presentation Features Demo (GAP-030 to GAP-036)")
print("=" .. string.rep("=", 60))

-- GAP-030: Named Alternatives
print("\n--- GAP-030: Named Alternatives ---")
local game_state = MockGameState()
local cf = ControlFlow.new(nil, game_state, { passage_id = "demo" })

print("Testing named alternative {@counter:| first | second | third }")
local content = "{@counter:| first | second | third }"
print("  Call 1: " .. cf:process_alternatives(content))
print("  Call 2: " .. cf:process_alternatives(content))
print("  Call 3: " .. cf:process_alternatives(content))
print("  Call 4 (sticks): " .. cf:process_alternatives(content))

print("\nTesting named cycle {@loop&:| A | B }")
game_state = MockGameState()  -- Reset state
cf = ControlFlow.new(nil, game_state, { passage_id = "demo2" })
content = "{@loop&:| A | B }"
print("  Call 1: " .. cf:process_alternatives(content))
print("  Call 2: " .. cf:process_alternatives(content))
print("  Call 3 (cycles): " .. cf:process_alternatives(content))

-- GAP-031: Gather Points
print("\n--- GAP-031: Gather Points ---")
local parser = WSParser.new()
local result = parser:parse([[
:: TestGather
+ [Choice 1] -> Target1
+ [Choice 2] -> Target2
- This is a gather point at depth 1
]])
local passage = result.story.passages["TestGather"]
print("Parsed gathers: " .. #(passage.gathers or {}))
if passage.gathers and #passage.gathers > 0 then
    for i, g in ipairs(passage.gathers) do
        print("  Gather " .. i .. ": depth=" .. g.depth .. ", content=\"" .. g.content .. "\"")
    end
end

-- GAP-032: Choice Expression Interpolation
print("\n--- GAP-032: Choice Expression Interpolation ---")
local renderer = Renderer.new(nil, "web")
local state = { gold = 100, name = "Hero" }

print("Testing $variable: $gold coins")
print("  Result: " .. renderer:evaluate_expressions("$gold coins", state))

print("Testing ${expression}: ${gold * 2} doubled")
print("  Result: " .. renderer:evaluate_expressions("${gold * 2} doubled", state))

print("Testing ${math.floor(3.7)}")
print("  Result: " .. renderer:evaluate_expressions("${math.floor(3.7)}", {}))

-- GAP-033: Escaped Brackets in Choices
print("\n--- GAP-033: Escaped Brackets in Choices ---")
print("Testing \\[ and \\] unescaping")
print("  Input: Open \\[secret\\] door")
print("  Result: " .. renderer:unescape_brackets("Open \\[secret\\] door"))

print("\nTesting parser with escaped brackets:")
local text = " [Open \\[secret\\] door] -> Target"
local choice_text, remaining = parser:parse_choice_text_with_escapes(text)
print("  Input: " .. text)
print("  Parsed choice text: " .. tostring(choice_text))
print("  Remaining: " .. tostring(remaining))

-- GAP-034: Text Alternatives in Choices
print("\n--- GAP-034: Text Alternatives in Choices ---")
game_state = MockGameState()
cf = ControlFlow.new(nil, game_state, { passage_id = "choices" })

print("Testing alternatives in choice context:")
local choice_content = "{| Take | Grab | Pick up } the sword"
print("  Context 'choice_1' call 1: " .. cf:process_alternatives_in_text(choice_content, "choice_1"))
print("  Context 'choice_1' call 2: " .. cf:process_alternatives_in_text(choice_content, "choice_1"))
print("  Context 'choice_2' call 1: " .. cf:process_alternatives_in_text(choice_content, "choice_2"))

-- GAP-035: Block CSS Classes
print("\n--- GAP-035: Block CSS Classes ---")
local renderer_web = Renderer.new(nil, "web")
local renderer_plain = Renderer.new(nil, "plain")

local block_css = ".highlight.important::[This is important content]"
print("Block CSS input: " .. block_css)
print("  Web output: " .. renderer_web:apply_formatting(block_css))
print("  Plain output: " .. renderer_plain:apply_formatting(block_css))

-- GAP-036: Inline CSS Classes
print("\n--- GAP-036: Inline CSS Classes ---")
local inline_css = "You have .gold.bold:[100 coins] remaining."
print("Inline CSS input: " .. inline_css)
print("  Web output: " .. renderer_web:apply_formatting(inline_css))
print("  Plain output: " .. renderer_plain:apply_formatting(inline_css))

print("\n" .. string.rep("=", 61))
print("Demo Complete!")
print(string.rep("=", 61))
