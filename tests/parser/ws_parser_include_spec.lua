-- tests/parser/ws_parser_include_spec.lua
-- Tests for WLS 1.0 Parser INCLUDE support (GAP-004, GAP-005)

describe("WSParser INCLUDE", function()
    local WSParser
    local ModulesRuntime

    setup(function()
        WSParser = require("whisker.parser.ws_parser")
        ModulesRuntime = require("whisker.core.modules_runtime")
    end)

    describe("parse_include()", function()
        it("parses INCLUDE with double quotes", function()
            local parser = WSParser.new()
            local result = parser:parse_include('INCLUDE "utils.ws"')

            assert.is_not_nil(result)
            assert.are.equal("include_declaration", result.type)
            assert.are.equal("utils.ws", result.path)
        end)

        it("parses INCLUDE with single quotes", function()
            local parser = WSParser.new()
            local result = parser:parse_include("INCLUDE 'utils.ws'")

            assert.is_not_nil(result)
            assert.are.equal("include_declaration", result.type)
            assert.are.equal("utils.ws", result.path)
        end)

        it("parses relative path", function()
            local parser = WSParser.new()
            local result = parser:parse_include('INCLUDE "../shared/utils.ws"')

            assert.is_not_nil(result)
            assert.are.equal("../shared/utils.ws", result.path)
        end)

        it("parses absolute path", function()
            local parser = WSParser.new()
            local result = parser:parse_include('INCLUDE "/lib/common.ws"')

            assert.is_not_nil(result)
            assert.are.equal("/lib/common.ws", result.path)
        end)

        it("returns error for missing path", function()
            local parser = WSParser.new()
            local result, err = parser:parse_include('INCLUDE')

            assert.is_nil(result)
            assert.is_not_nil(err)
        end)
    end)

    describe("process_include()", function()
        it("returns error when no modules_runtime configured", function()
            local parser = WSParser.new()
            local result, err = parser:process_include("test.ws", nil)

            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.has.match("No modules runtime", err)
        end)

        it("delegates to modules_runtime when configured", function()
            local parser = WSParser.new()
            local called = false
            local called_path = nil

            -- Mock modules runtime
            parser.modules_runtime = {
                load_include = function(self, path, from_file, location)
                    called = true
                    called_path = path
                    return nil, "Mock error"
                end
            }
            parser.current_file = "/project/main.ws"

            local result, err = parser:process_include("utils.ws", { line = 1 })

            assert.is_true(called)
            assert.are.equal("utils.ws", called_path)
        end)
    end)

    describe("is_module_keyword()", function()
        it("recognizes INCLUDE", function()
            local parser = WSParser.new()
            assert.is_true(parser:is_module_keyword("INCLUDE \"file.ws\""))
        end)

        it("recognizes FUNCTION", function()
            local parser = WSParser.new()
            assert.is_true(parser:is_module_keyword("FUNCTION test()"))
        end)

        it("recognizes NAMESPACE", function()
            local parser = WSParser.new()
            assert.is_true(parser:is_module_keyword("NAMESPACE Utils"))
        end)

        it("recognizes END", function()
            local parser = WSParser.new()
            assert.is_true(parser:is_module_keyword("END"))
            assert.is_true(parser:is_module_keyword("END "))
        end)

        it("recognizes RETURN", function()
            local parser = WSParser.new()
            assert.is_true(parser:is_module_keyword("RETURN value"))
        end)

        it("does not match non-keywords", function()
            local parser = WSParser.new()
            assert.is_false(parser:is_module_keyword("Some text"))
            assert.is_false(parser:is_module_keyword(":: Passage"))
        end)
    end)
end)
