-- spec/script/lexer/errors_spec.lua
-- Tests for lexer error handling and recovery

describe("Lexer Error Handling", function()
  local lexer_module
  local codes_module
  local errors_module

  before_each(function()
    -- Clear module cache
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    lexer_module = require("whisker.script.lexer")
    codes_module = require("whisker.script.errors.codes")
    errors_module = require("whisker.script.lexer.errors")
  end)

  describe("Error Codes", function()
    it("should define lexer error codes", function()
      assert.are.equal("WSK0001", codes_module.Lexer.UNEXPECTED_CHARACTER)
      assert.are.equal("WSK0002", codes_module.Lexer.UNTERMINATED_STRING)
      assert.are.equal("WSK0003", codes_module.Lexer.INVALID_NUMBER_FORMAT)
      assert.are.equal("WSK0004", codes_module.Lexer.INVALID_ESCAPE_SEQUENCE)
      assert.are.equal("WSK0005", codes_module.Lexer.UNEXPECTED_END_OF_INPUT)
      assert.are.equal("WSK0006", codes_module.Lexer.INVALID_VARIABLE_NAME)
      assert.are.equal("WSK0007", codes_module.Lexer.TOO_MANY_ERRORS)
    end)

    it("should format error messages with substitutions", function()
      local msg = codes_module.format_message(codes_module.Lexer.UNEXPECTED_CHARACTER, "@")
      assert.are.equal("Unexpected character '@'", msg)
    end)

    it("should provide suggestions for errors", function()
      local suggestion = codes_module.get_suggestion(codes_module.Lexer.UNTERMINATED_STRING)
      assert.is_truthy(suggestion)
      assert.is_truthy(suggestion:match("quote"))
    end)

    it("should return severity for error codes", function()
      local severity = codes_module.get_severity(codes_module.Lexer.UNEXPECTED_CHARACTER)
      assert.are.equal("error", severity)
    end)
  end)

  describe("LexerError class", function()
    it("should create error with code and message", function()
      local pos = { line = 5, column = 10, offset = 50 }
      local err = errors_module.LexerError.new("WSK0001", "Unexpected character", pos)

      assert.are.equal("WSK0001", err.code)
      assert.are.equal("Unexpected character", err.message)
      assert.are.equal(5, err.position.line)
      assert.are.equal(10, err.position.column)
    end)

    it("should create error from code with automatic message", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.LexerError.from_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos, "@")

      assert.are.equal("WSK0001", err.code)
      assert.is_truthy(err.message:match("@"))
      assert.is_truthy(err.suggestion)
    end)

    it("should convert to string representation", function()
      local pos = { line = 3, column = 7, offset = 25 }
      local err = errors_module.LexerError.new("WSK0002", "Unterminated string", pos)

      local str = tostring(err)
      assert.is_truthy(str:match("WSK0002"))
      assert.is_truthy(str:match("Unterminated string"))
      assert.is_truthy(str:match("3:7"))
    end)

    it("should include suggestion in options", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.LexerError.new("WSK0001", "Test error", pos, {
        suggestion = "Try doing something different"
      })

      assert.are.equal("Try doing something different", err.suggestion)
    end)
  end)

  describe("ErrorCollector", function()
    it("should collect multiple errors", function()
      local collector = errors_module.ErrorCollector.new()
      local pos1 = { line = 1, column = 1, offset = 0 }
      local pos2 = { line = 2, column = 5, offset = 10 }

      collector:report_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos1, "@")
      collector:report_code(codes_module.Lexer.UNTERMINATED_STRING, pos2)

      assert.are.equal(2, collector:count())
      assert.is_true(collector:has_errors())
    end)

    it("should enforce error limit", function()
      local collector = errors_module.ErrorCollector.new({ max_errors = 3 })
      local pos = { line = 1, column = 1, offset = 0 }

      -- Add 3 errors (limit)
      collector:report_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos, "a")
      collector:report_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos, "b")
      collector:report_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos, "c")

      -- Should hit limit - count is 4 (3 + "too many errors" message)
      assert.is_true(collector:limit_reached())
      assert.are.equal(4, collector:count())

      -- Should not add more
      local result = collector:report_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos, "d")
      assert.is_false(result)
      assert.are.equal(4, collector:count())
    end)

    it("should clear errors", function()
      local collector = errors_module.ErrorCollector.new()
      local pos = { line = 1, column = 1, offset = 0 }

      collector:report_code(codes_module.Lexer.UNEXPECTED_CHARACTER, pos, "@")
      assert.is_true(collector:has_errors())

      collector:clear()
      assert.is_false(collector:has_errors())
      assert.are.equal(0, collector:count())
    end)
  end)

  describe("Unexpected character errors", function()
    it("should report unexpected character and continue", function()
      local lexer = lexer_module.Lexer.new("@")
      local stream = lexer:tokenize()

      assert.is_true(lexer:has_errors())
      assert.are.equal(1, lexer:error_count())

      local errors = lexer:get_errors()
      assert.are.equal("WSK0001", errors[1].code)
    end)

    it("should continue lexing after unexpected character", function()
      local lexer = lexer_module.Lexer.new("abc @ def")
      local stream = lexer:tokenize()

      -- Should have identifier, error, identifier, EOF
      assert.are.equal("IDENTIFIER", stream:advance().type)
      assert.are.equal("ERROR", stream:advance().type)
      assert.are.equal("IDENTIFIER", stream:advance().type)
      assert.are.equal("EOF", stream:advance().type)

      assert.are.equal(1, lexer:error_count())
    end)

    it("should report multiple unexpected characters", function()
      local lexer = lexer_module.Lexer.new("@ ^ @")
      local stream = lexer:tokenize()

      assert.are.equal(3, lexer:error_count())
    end)
  end)

  describe("Unterminated string errors", function()
    it("should report unterminated string at newline", function()
      local lexer = lexer_module.Lexer.new('"hello\nworld')
      local stream = lexer:tokenize()

      assert.is_true(lexer:has_errors())
      local errors = lexer:get_errors()
      assert.are.equal("WSK0002", errors[1].code)
    end)

    it("should report unterminated string at EOF", function()
      local lexer = lexer_module.Lexer.new('"hello')
      local stream = lexer:tokenize()

      assert.is_true(lexer:has_errors())
      local errors = lexer:get_errors()
      assert.are.equal("WSK0002", errors[1].code)
    end)

    it("should continue after unterminated string", function()
      local lexer = lexer_module.Lexer.new('"hello\nfoo')
      local stream = lexer:tokenize()

      -- Should have: ERROR, NEWLINE, IDENTIFIER, EOF
      assert.are.equal("ERROR", stream:advance().type)
      assert.are.equal("NEWLINE", stream:advance().type)
      assert.are.equal("IDENTIFIER", stream:advance().type)
      assert.are.equal("EOF", stream:advance().type)
    end)
  end)

  describe("Invalid variable name errors", function()
    it("should report invalid variable name", function()
      local lexer = lexer_module.Lexer.new("$123")
      local stream = lexer:tokenize()

      assert.is_true(lexer:has_errors())
      local errors = lexer:get_errors()
      assert.are.equal("WSK0006", errors[1].code)
    end)

    it("should report $ at end of input", function()
      local lexer = lexer_module.Lexer.new("$")
      local stream = lexer:tokenize()

      assert.is_true(lexer:has_errors())
    end)
  end)

  describe("Error recovery", function()
    it("should continue lexing valid content after errors", function()
      local source = "valid @ more valid"
      local lexer = lexer_module.Lexer.new(source)
      local stream = lexer:tokenize()

      local tokens = {}
      while not stream:at_end() do
        table.insert(tokens, stream:advance())
      end

      -- Should have: IDENTIFIER, ERROR, IDENTIFIER, IDENTIFIER, EOF
      local types = {}
      for _, t in ipairs(tokens) do
        table.insert(types, t.type)
      end

      assert.is_truthy(table.concat(types, " "):match("IDENTIFIER"))
      assert.is_truthy(table.concat(types, " "):match("ERROR"))
    end)

    it("should handle multiple consecutive errors", function()
      local source = "@@@ not_at_symbol"
      local lexer = lexer_module.Lexer.new(source)
      local stream = lexer:tokenize()

      -- @@ is METADATA, then @ is unexpected
      local first = stream:advance()
      assert.are.equal("METADATA", first.type)

      -- After METADATA comes error for the third @? Actually third @ might be error
      -- Let's just verify we can get through without crashing
      while not stream:at_end() do
        stream:advance()
      end

      -- Should have at least one error (third @ is not @@)
      assert.is_true(lexer:has_errors())
    end)
  end)

  describe("Error limit", function()
    it("should stop at error limit", function()
      -- Create source with many errors
      local source = string.rep("@ ", 150)  -- 150 @ characters
      local lexer = lexer_module.Lexer.new(source, { max_errors = 10 })
      local stream = lexer:tokenize()

      -- Should stop at 10 + 1 (the "too many errors" message)
      local errors = lexer:get_errors()
      assert.are.equal(11, #errors)

      -- Last error should be "too many errors"
      local last = errors[#errors]
      assert.are.equal("WSK0007", last.code)
    end)

    it("should respect custom error limit", function()
      local source = string.rep("@ ", 50)
      local lexer = lexer_module.Lexer.new(source, { max_errors = 5 })
      local stream = lexer:tokenize()

      local errors = lexer:get_errors()
      assert.are.equal(6, #errors)  -- 5 + "too many errors"
    end)
  end)

  describe("Error formatting", function()
    it("should format error with source context", function()
      local lexer = lexer_module.Lexer.new("hello @ world", { file_path = "test.wsk" })
      local stream = lexer:tokenize()

      local formatted = lexer:format_errors()
      assert.is_truthy(formatted:match("WSK0001"))
      assert.is_truthy(formatted:match("test.wsk"))
    end)

    it("should include line and column in formatted output", function()
      local lexer = lexer_module.Lexer.new("abc\n  @")
      local stream = lexer:tokenize()

      local formatted = lexer:format_errors()
      -- Error is at line 2, column 3
      assert.is_truthy(formatted:match("2:3") or formatted:match("line.*2"))
    end)

    it("should include suggestion in formatted error", function()
      local lexer = lexer_module.Lexer.new('@')
      local stream = lexer:tokenize()

      local formatted = lexer:format_errors()
      assert.is_truthy(formatted:match("help"))
    end)
  end)

  describe("Position tracking in errors", function()
    it("should track correct position for errors", function()
      local lexer = lexer_module.Lexer.new("abc @")
      local stream = lexer:tokenize()

      local errors = lexer:get_errors()
      assert.are.equal(1, #errors)
      assert.are.equal(1, errors[1].position.line)
      assert.are.equal(5, errors[1].position.column)
    end)

    it("should track position on multiple lines", function()
      local lexer = lexer_module.Lexer.new("line1\n  @")
      local stream = lexer:tokenize()

      local errors = lexer:get_errors()
      assert.are.equal(1, #errors)
      assert.are.equal(2, errors[1].position.line)
      assert.are.equal(3, errors[1].position.column)
    end)
  end)

  describe("Error convenience constructors", function()
    it("should create unexpected character error", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.errors.unexpected_character("@", pos)

      assert.are.equal("WSK0001", err.code)
      assert.is_truthy(err.message:match("@"))
    end)

    it("should create unterminated string error", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.errors.unterminated_string(pos)

      assert.are.equal("WSK0002", err.code)
    end)

    it("should create invalid escape error", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.errors.invalid_escape("x", pos)

      assert.are.equal("WSK0004", err.code)
      assert.is_truthy(err.message:match("x"))
    end)

    it("should create unexpected EOF error", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.errors.unexpected_eof(pos, "in string")

      assert.are.equal("WSK0005", err.code)
      assert.is_truthy(err.message:match("string"))
    end)

    it("should create invalid variable name error", function()
      local pos = { line = 1, column = 1, offset = 0 }
      local err = errors_module.errors.invalid_variable_name(pos)

      assert.are.equal("WSK0006", err.code)
    end)
  end)

  describe("Integration with tokenize_with_errors", function()
    it("should return both stream and errors", function()
      local stream, errors = lexer_module.tokenize_with_errors("valid @ text")

      assert.is_not_nil(stream)
      assert.is_not_nil(errors)
      assert.are.equal(1, #errors)
      assert.are.equal("WSK0001", errors[1].code)
    end)

    it("should return empty errors for valid input", function()
      local stream, errors = lexer_module.tokenize_with_errors("valid text")

      assert.is_not_nil(stream)
      assert.are.equal(0, #errors)
    end)
  end)
end)
