-- spec/script/parser/infrastructure_spec.lua
-- Tests for parser infrastructure

describe("Parser Infrastructure", function()
  local parser_module
  local lexer_module
  local tokens_module
  local Parser
  local TokenType

  before_each(function()
    -- Clear module cache
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    parser_module = require("whisker.script.parser")
    lexer_module = require("whisker.script.lexer")
    tokens_module = require("whisker.script.lexer.tokens")
    Parser = parser_module.Parser
    TokenType = tokens_module.TokenType
  end)

  -- Helper to create parser from source
  local function create_parser(source)
    local tokens = lexer_module.tokenize(source)
    return Parser.new(tokens, { source = source })
  end

  describe("Parser.new", function()
    it("should create parser from token stream", function()
      local parser = create_parser("test")
      assert.is_not_nil(parser)
    end)

    it("should initialize with empty errors", function()
      local parser = create_parser("test")
      assert.are.equal(0, #parser:get_errors())
    end)

    it("should initialize context", function()
      local parser = create_parser("test")
      assert.is_false(parser:in_context("in_passage"))
      assert.is_false(parser:in_context("in_choice"))
      assert.are.equal(0, parser:get_nesting_depth())
    end)

    it("should accept options", function()
      local tokens = lexer_module.tokenize("test")
      local parser = Parser.new(tokens, {
        max_errors = 5,
        file_path = "test.wsk"
      })
      assert.are.equal(5, parser.max_errors)
    end)
  end)

  describe("Token stream interaction", function()
    describe("peek", function()
      it("should return current token without consuming", function()
        local parser = create_parser("hello world")
        local first = parser:peek()
        assert.are.equal("IDENTIFIER", first.type)
        -- Peek again should return same token
        assert.are.equal(first, parser:peek())
      end)

      it("should support offset parameter", function()
        local parser = create_parser("one two three")
        assert.are.equal("one", parser:peek(0).literal)
        assert.are.equal("two", parser:peek(1).literal)
        assert.are.equal("three", parser:peek(2).literal)
      end)
    end)

    describe("advance", function()
      it("should consume and return current token", function()
        local parser = create_parser("one two")
        local first = parser:advance()
        assert.are.equal("one", first.literal)
        local second = parser:peek()
        assert.are.equal("two", second.literal)
      end)

      it("should not advance past EOF", function()
        local parser = create_parser("")
        local eof1 = parser:advance()
        local eof2 = parser:advance()
        assert.are.equal("EOF", eof1.type)
        assert.are.equal("EOF", eof2.type)
      end)
    end)

    describe("previous", function()
      it("should return last consumed token", function()
        local parser = create_parser("one two")
        parser:advance()  -- consume "one"
        local prev = parser:previous()
        assert.are.equal("one", prev.literal)
      end)
    end)

    describe("check", function()
      it("should return true for matching type", function()
        local parser = create_parser("hello")
        assert.is_true(parser:check(TokenType.IDENTIFIER))
      end)

      it("should return false for non-matching type", function()
        local parser = create_parser("hello")
        assert.is_false(parser:check(TokenType.NUMBER))
      end)

      it("should return false at EOF", function()
        local parser = create_parser("")
        assert.is_false(parser:check(TokenType.IDENTIFIER))
      end)
    end)

    describe("check_any", function()
      it("should return true if any type matches", function()
        local parser = create_parser("42")
        assert.is_true(parser:check_any(TokenType.IDENTIFIER, TokenType.NUMBER))
      end)

      it("should return false if no type matches", function()
        local parser = create_parser("hello")
        assert.is_false(parser:check_any(TokenType.NUMBER, TokenType.STRING))
      end)
    end)

    describe("match", function()
      it("should consume and return token if type matches", function()
        local parser = create_parser("hello world")
        local token = parser:match(TokenType.IDENTIFIER)
        assert.is_not_nil(token)
        assert.are.equal("hello", token.literal)
        assert.are.equal("world", parser:peek().literal)
      end)

      it("should return nil without consuming if type doesn't match", function()
        local parser = create_parser("hello")
        local token = parser:match(TokenType.NUMBER)
        assert.is_nil(token)
        assert.are.equal("hello", parser:peek().literal)
      end)
    end)

    describe("match_any", function()
      it("should match first matching type", function()
        local parser = create_parser("42")
        local token = parser:match_any(TokenType.IDENTIFIER, TokenType.NUMBER)
        assert.is_not_nil(token)
        assert.are.equal("NUMBER", token.type)
      end)
    end)

    describe("expect", function()
      it("should consume token if type matches", function()
        local parser = create_parser("hello")
        local token = parser:expect(TokenType.IDENTIFIER, "Expected identifier")
        assert.is_not_nil(token)
        assert.are.equal("hello", token.literal)
      end)

      it("should report error if type doesn't match", function()
        local parser = create_parser("hello")
        local token = parser:expect(TokenType.NUMBER, "Expected number")
        assert.is_nil(token)
        assert.is_true(parser:has_errors())
      end)
    end)

    describe("skip", function()
      it("should skip tokens of specified type", function()
        local parser = create_parser("a\nb")
        parser:advance()  -- skip 'a'
        local count = parser:skip(TokenType.NEWLINE)
        assert.is_true(count >= 1)  -- At least one newline
        assert.are.equal("b", parser:peek().literal)
      end)

      it("should return 0 if no tokens to skip", function()
        local parser = create_parser("hello")
        local count = parser:skip(TokenType.NEWLINE)
        assert.are.equal(0, count)
      end)
    end)
  end)

  describe("Error handling", function()
    describe("error_at", function()
      it("should add error to error list", function()
        local parser = create_parser("hello")
        parser:error_at(parser:peek(), "Test error")
        assert.are.equal(1, #parser:get_errors())
      end)

      it("should include position in error", function()
        local parser = create_parser("hello")
        parser:error_at(parser:peek(), "Test error")
        local err = parser:get_errors()[1]
        assert.is_not_nil(err.position)
        assert.are.equal(1, err.position.line)
      end)

      it("should set panic mode", function()
        local parser = create_parser("hello")
        assert.is_false(parser.panic_mode)
        parser:error_at(parser:peek(), "Test error")
        assert.is_true(parser.panic_mode)
      end)

      it("should suppress cascading errors in panic mode", function()
        local parser = create_parser("hello world")
        parser:error_at(parser:peek(), "First error")
        parser:error_at(parser:peek(), "Second error")  -- Should be suppressed
        assert.are.equal(1, #parser:get_errors())
      end)
    end)

    describe("error_at_current", function()
      it("should report error at current token", function()
        local parser = create_parser("hello")
        parser:error_at_current("Error here")
        assert.is_true(parser:has_errors())
      end)
    end)

    describe("error_at_previous", function()
      it("should report error at previous token", function()
        local parser = create_parser("hello world")
        parser:advance()  -- consume "hello"
        parser:error_at_previous("Error at previous")
        local err = parser:get_errors()[1]
        assert.is_not_nil(err)
      end)
    end)

    describe("error_limit", function()
      it("should add too-many-errors message at limit", function()
        local tokens = lexer_module.tokenize("a b c d e")
        local parser = Parser.new(tokens, { max_errors = 3 })

        -- Report errors up to limit
        for i = 1, 3 do
          parser.panic_mode = false  -- Reset to allow error
          parser:error_at_current("Error " .. i)
          parser:advance()
        end

        -- Should have 3 errors + 1 "too many errors" message = 4
        local errors = parser:get_errors()
        assert.is_true(#errors >= 3)
        -- Check that one of the errors is the limit error
        local found_limit = false
        for _, err in ipairs(errors) do
          if err.code == "WSK0115" then
            found_limit = true
            break
          end
        end
        assert.is_true(found_limit)
      end)
    end)

    describe("error_handler", function()
      it("should call error handler when set", function()
        local parser = create_parser("hello")
        local handler_called = false
        local received_error = nil

        parser:set_error_handler(function(err)
          handler_called = true
          received_error = err
        end)

        parser:error_at_current("Test error")
        assert.is_true(handler_called)
        assert.are.equal("Test error", received_error.message)
      end)
    end)
  end)

  describe("Error recovery", function()
    describe("synchronize", function()
      it("should advance to synchronization point", function()
        local parser = create_parser("bad tokens :: Start")
        parser:error_at_current("Error")
        parser:synchronize()

        -- Should now be at ::
        assert.are.equal("PASSAGE_DECL", parser:peek().type)
      end)

      it("should stop at newline", function()
        local parser = create_parser("bad tokens\ngood")
        parser:error_at_current("Error")
        parser:advance()  -- consume "bad"
        parser:advance()  -- consume "tokens"
        parser:advance()  -- consume newline
        parser:synchronize()

        -- Should stop after newline
        assert.is_false(parser.panic_mode)
      end)

      it("should clear panic mode", function()
        local parser = create_parser("bad :: Start")
        parser.panic_mode = true
        parser:synchronize()
        assert.is_false(parser.panic_mode)
      end)
    end)

    describe("synchronize_statement", function()
      it("should synchronize to statement boundary", function()
        local parser = create_parser("bad -> Target")
        parser:error_at_current("Error")
        parser:synchronize_statement()
        assert.are.equal("DIVERT", parser:peek().type)
      end)
    end)

    describe("synchronize_block", function()
      it("should synchronize to block boundary", function()
        local parser = create_parser("bad :: Passage")
        parser:error_at_current("Error")
        parser:synchronize_block()
        assert.are.equal("PASSAGE_DECL", parser:peek().type)
      end)
    end)
  end)

  describe("Context management", function()
    describe("enter_context", function()
      it("should set context flag", function()
        local parser = create_parser("test")
        parser:enter_context("in_passage")
        assert.is_true(parser:in_context("in_passage"))
      end)

      it("should increment nesting depth", function()
        local parser = create_parser("test")
        assert.are.equal(0, parser:get_nesting_depth())
        parser:enter_context("in_passage")
        assert.are.equal(1, parser:get_nesting_depth())
        parser:enter_context("in_choice")
        assert.are.equal(2, parser:get_nesting_depth())
      end)
    end)

    describe("leave_context", function()
      it("should clear context flag", function()
        local parser = create_parser("test")
        parser:enter_context("in_passage")
        parser:leave_context("in_passage")
        assert.is_false(parser:in_context("in_passage"))
      end)

      it("should decrement nesting depth", function()
        local parser = create_parser("test")
        parser:enter_context("in_passage")
        parser:enter_context("in_choice")
        parser:leave_context("in_choice")
        assert.are.equal(1, parser:get_nesting_depth())
      end)

      it("should not go below zero", function()
        local parser = create_parser("test")
        parser:leave_context("in_passage")
        assert.are.equal(0, parser:get_nesting_depth())
      end)
    end)
  end)

  describe("Module functions", function()
    describe("parser_module.new", function()
      it("should create parser from tokens", function()
        local tokens = lexer_module.tokenize("test")
        local parser = parser_module.new(tokens)
        assert.is_not_nil(parser)
      end)
    end)

    describe("parser_module.parse", function()
      it("should parse source and return AST", function()
        local ast, errors = parser_module.parse("test")
        assert.is_not_nil(ast)
        assert.are.equal("Script", ast.type)
      end)

      it("should return errors", function()
        local ast, errors = parser_module.parse("test")
        assert.is_not_nil(errors)
        assert.are.equal("table", type(errors))
      end)
    end)
  end)

  describe("is_at_end", function()
    it("should return true at EOF", function()
      local parser = create_parser("")
      assert.is_true(parser:is_at_end())
    end)

    it("should return false when tokens remain", function()
      local parser = create_parser("hello")
      assert.is_false(parser:is_at_end())
    end)
  end)
end)
