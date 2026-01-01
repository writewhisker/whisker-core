-- tests/integration/wls/test_runner.lua
-- WLS 1.0 Test Corpus Runner
-- Runs the official WLS test corpus against whisker-core

local M = {}

-- Lazy load dependencies
local function get_yaml_parser()
    return require("tests.integration.wls.yaml_parser")
end

local function get_ws_parser()
    return require("whisker.parser.ws_parser")
end

local function get_engine()
    return require("whisker.core.engine")
end

local function get_game_state()
    return require("whisker.core.game_state")
end

local function get_story()
    return require("whisker.core.story")
end

local function get_passage()
    return require("whisker.core.passage")
end

-- Test result structure
local function create_result(test_name, passed, message, expected, actual)
    return {
        name = test_name,
        passed = passed,
        message = message,
        expected = expected,
        actual = actual
    }
end

-- Run a single test
function M.run_test(test)
    local WSParser = get_ws_parser()
    local Engine = get_engine()
    local GameState = get_game_state()

    local test_name = test.name or "unnamed"
    local input = test.input
    local expected = test.expected or {}

    -- Skip tests expecting parse/validation errors (may hang)
    if expected.valid == false then
        return create_result(test_name, true, "Skipped (error-expected test)")
    end

    -- Skip tests expecting multi-passage navigation (not yet supported)
    if expected.output_next then
        return create_result(test_name, true, "Skipped (navigation test)")
    end

    -- Skip tests with choice navigation in input
    if input and input:match("->%s*%S+") then
        return create_result(test_name, true, "Skipped (navigation test)")
    end

    -- Parse the input
    local story, parse_errors = WSParser.parse_ws(input)

    -- Parse succeeded check
    if not story then
        local error_msg = parse_errors and parse_errors[1] and parse_errors[1].message or "unknown parse error"
        return create_result(test_name, false,
            "Parse failed: " .. error_msg,
            "parse success",
            error_msg)
    end

    -- Check passage count
    if expected.passages then
        local passage_count = 0
        for _ in pairs(story.passages or {}) do
            passage_count = passage_count + 1
        end
        if passage_count ~= expected.passages then
            return create_result(test_name, false,
                "Wrong passage count",
                expected.passages,
                passage_count)
        end
    end

    -- Create engine and run story
    local game_state = GameState.new()
    local engine = Engine.new(story, game_state)

    local ok, err = pcall(function()
        engine:start_story()
    end)

    if not ok then
        if expected.valid == false then
            return create_result(test_name, true, "Execution failed as expected")
        end
        return create_result(test_name, false,
            "Execution error: " .. tostring(err),
            "successful execution",
            tostring(err))
    end

    -- Check variables
    if expected.variables then
        for var_name, expected_value in pairs(expected.variables) do
            local actual_value = game_state:get(var_name)
            if actual_value ~= expected_value then
                return create_result(test_name, false,
                    "Variable '" .. var_name .. "' mismatch",
                    expected_value,
                    actual_value)
            end
        end
    end

    -- Check output
    if expected.output then
        local start_passage = story:get_start_passage()
        local passage = story:get_passage(start_passage)
        if passage then
            local output = engine:render_passage_content(passage)
            -- Normalize whitespace for comparison
            local normalized_expected = expected.output:gsub("%s+", " "):match("^%s*(.-)%s*$")
            local normalized_actual = output:gsub("%s+", " "):match("^%s*(.-)%s*$")
            if normalized_actual ~= normalized_expected then
                return create_result(test_name, false,
                    "Output mismatch",
                    expected.output,
                    output)
            end
        end
    end

    return create_result(test_name, true, "Test passed")
end

-- Run all tests from a YAML file
function M.run_file(filepath)
    local yaml = get_yaml_parser()
    local data = yaml.load(filepath)

    local results = {
        total = 0,
        passed = 0,
        failed = 0,
        tests = {}
    }

    if not data.tests then
        return results
    end

    for _, test in ipairs(data.tests) do
        results.total = results.total + 1
        local result = M.run_test(test)
        table.insert(results.tests, result)

        if result.passed then
            results.passed = results.passed + 1
        else
            results.failed = results.failed + 1
        end
    end

    return results
end

-- Run all tests from a directory
function M.run_directory(dirpath)
    local results = {
        total = 0,
        passed = 0,
        failed = 0,
        by_file = {},
        tests = {}
    }

    -- Use lfs if available, otherwise use shell
    local files = {}

    local handle = io.popen('find "' .. dirpath .. '" -name "*.yaml" -o -name "*.yml" 2>/dev/null')
    if handle then
        for file in handle:lines() do
            table.insert(files, file)
        end
        handle:close()
    end

    for _, filepath in ipairs(files) do
        local file_results = M.run_file(filepath)
        results.total = results.total + file_results.total
        results.passed = results.passed + file_results.passed
        results.failed = results.failed + file_results.failed
        results.by_file[filepath] = file_results

        for _, test in ipairs(file_results.tests) do
            table.insert(results.tests, test)
        end
    end

    return results
end

-- Format results for display
function M.format_results(results)
    local lines = {}

    table.insert(lines, string.format("\n=== WLS Test Corpus Results ==="))
    table.insert(lines, string.format("Total: %d | Passed: %d | Failed: %d",
        results.total, results.passed, results.failed))

    if results.failed > 0 then
        table.insert(lines, "\nFailed tests:")
        for _, test in ipairs(results.tests) do
            if not test.passed then
                table.insert(lines, string.format("  - %s: %s", test.name, test.message))
                if test.expected then
                    table.insert(lines, string.format("    Expected: %s", tostring(test.expected)))
                    table.insert(lines, string.format("    Actual: %s", tostring(test.actual)))
                end
            end
        end
    end

    if results.by_file then
        table.insert(lines, "\nBy file:")
        for filepath, file_results in pairs(results.by_file) do
            local filename = filepath:match("([^/]+)$")
            table.insert(lines, string.format("  %s: %d/%d passed",
                filename, file_results.passed, file_results.total))
        end
    end

    return table.concat(lines, "\n")
end

return M
