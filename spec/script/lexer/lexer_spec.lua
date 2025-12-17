-- spec/script/lexer/lexer_spec.lua
-- Unit tests for core lexer implementation

describe("Lexer", function()
  local lexer_module

  before_each(function()
    -- Clear module cache
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    lexer_module = require("whisker.script.lexer")
  end)

  describe("Lexer.new()", function()
    it("should create lexer with source", function()
      local lexer = lexer_module.Lexer.new("hello")
      assert.is_table(lexer)
    end)

    it("should handle empty source", function()
      local lexer = lexer_module.Lexer.new("")
      local stream = lexer:tokenize()
      assert.is_true(stream:at_end())
    end)

    it("should handle nil source", function()
      local lexer = lexer_module.Lexer.new(nil)
      local stream = lexer:tokenize()
      assert.is_true(stream:at_end())
    end)
  end)

  describe("tokenize()", function()
    it("should return TokenStream", function()
      local lexer = lexer_module.Lexer.new("test")
      local stream = lexer:tokenize()
      assert.is_table(stream)
      assert.is_function(stream.peek)
      assert.is_function(stream.advance)
    end)

    it("should end with EOF token", function()
      local lexer = lexer_module.Lexer.new("hello")
      local stream = lexer:tokenize()

      -- Consume all tokens until EOF
      local count = 0
      while not stream:at_end() and count < 100 do
        stream:advance()
        count = count + 1
      end

      local last = stream:current()
      assert.are.equal("EOF", last.type)
    end)

    it("should produce only EOF for empty source", function()
      local stream = lexer_module.tokenize("")
      assert.are.equal("EOF", stream:peek().type)
    end)
  end)

  describe("Identifier tokenization", function()
    it("should tokenize simple identifier", function()
      local stream = lexer_module.tokenize("hello")
      local token = stream:advance()
      assert.are.equal("IDENTIFIER", token.type)
      assert.are.equal("hello", token.lexeme)
    end)

    it("should tokenize identifier with underscore", function()
      local stream = lexer_module.tokenize("my_var")
      local token = stream:advance()
      assert.are.equal("IDENTIFIER", token.type)
      assert.are.equal("my_var", token.lexeme)
    end)

    it("should tokenize identifier with digits", function()
      local stream = lexer_module.tokenize("var123")
      local token = stream:advance()
      assert.are.equal("IDENTIFIER", token.type)
      assert.are.equal("var123", token.lexeme)
    end)

    it("should recognize keywords", function()
      local stream = lexer_module.tokenize("and or not true false null else if elif")

      assert.are.equal("AND", stream:advance().type)
      assert.are.equal("OR", stream:advance().type)
      assert.are.equal("NOT", stream:advance().type)
      assert.are.equal("TRUE", stream:advance().type)
      assert.are.equal("FALSE", stream:advance().type)
      assert.are.equal("NULL", stream:advance().type)
      assert.are.equal("ELSE", stream:advance().type)
      assert.are.equal("IF", stream:advance().type)
      assert.are.equal("ELIF", stream:advance().type)
    end)
  end)

  describe("Number tokenization", function()
    it("should tokenize integer", function()
      local stream = lexer_module.tokenize("42")
      local token = stream:advance()
      assert.are.equal("NUMBER", token.type)
      assert.are.equal("42", token.lexeme)
      assert.are.equal(42, token.literal)
    end)

    it("should tokenize float", function()
      local stream = lexer_module.tokenize("3.14")
      local token = stream:advance()
      assert.are.equal("NUMBER", token.type)
      assert.are.equal("3.14", token.lexeme)
      assert.are.equal(3.14, token.literal)
    end)

    it("should tokenize zero", function()
      local stream = lexer_module.tokenize("0")
      local token = stream:advance()
      assert.are.equal("NUMBER", token.type)
      assert.are.equal(0, token.literal)
    end)
  end)

  describe("String tokenization", function()
    it("should tokenize double-quoted string", function()
      local stream = lexer_module.tokenize('"hello"')
      local token = stream:advance()
      assert.are.equal("STRING", token.type)
      assert.are.equal('"hello"', token.lexeme)
      assert.are.equal("hello", token.literal)
    end)

    it("should tokenize single-quoted string", function()
      local stream = lexer_module.tokenize("'world'")
      local token = stream:advance()
      assert.are.equal("STRING", token.type)
      assert.are.equal("world", token.literal)
    end)

    it("should handle escape sequences", function()
      local stream = lexer_module.tokenize('"hello\\nworld"')
      local token = stream:advance()
      assert.are.equal("STRING", token.type)
      assert.are.equal("hello\nworld", token.literal)
    end)

    it("should handle escaped quotes", function()
      local stream = lexer_module.tokenize('"say \\"hi\\""')
      local token = stream:advance()
      assert.are.equal("STRING", token.type)
      assert.are.equal('say "hi"', token.literal)
    end)

    it("should report unterminated string", function()
      local stream = lexer_module.tokenize('"unterminated')
      local token = stream:advance()
      assert.are.equal("ERROR", token.type)
    end)
  end)

  describe("Variable tokenization", function()
    it("should tokenize variable reference", function()
      local stream = lexer_module.tokenize("$myVar")
      local token = stream:advance()
      assert.are.equal("VARIABLE", token.type)
      assert.are.equal("$myVar", token.lexeme)
      assert.are.equal("myVar", token.literal)
    end)

    it("should error on $ without identifier", function()
      local stream = lexer_module.tokenize("$ ")
      local token = stream:advance()
      assert.are.equal("ERROR", token.type)
    end)
  end)

  describe("Delimiter tokenization", function()
    it("should tokenize braces", function()
      local stream = lexer_module.tokenize("{}")
      assert.are.equal("LBRACE", stream:advance().type)
      assert.are.equal("RBRACE", stream:advance().type)
    end)

    it("should tokenize brackets", function()
      local stream = lexer_module.tokenize("[]")
      assert.are.equal("LBRACKET", stream:advance().type)
      assert.are.equal("RBRACKET", stream:advance().type)
    end)

    it("should tokenize parentheses", function()
      local stream = lexer_module.tokenize("()")
      assert.are.equal("LPAREN", stream:advance().type)
      assert.are.equal("RPAREN", stream:advance().type)
    end)

    it("should tokenize other delimiters", function()
      local stream = lexer_module.tokenize(",|.")
      assert.are.equal("COMMA", stream:advance().type)
      assert.are.equal("PIPE", stream:advance().type)
      assert.are.equal("DOT", stream:advance().type)
    end)
  end)

  describe("Newline tokenization", function()
    it("should tokenize newline", function()
      local stream = lexer_module.tokenize("a\nb")
      assert.are.equal("IDENTIFIER", stream:advance().type)  -- a
      assert.are.equal("NEWLINE", stream:advance().type)
      assert.are.equal("IDENTIFIER", stream:advance().type)  -- b
    end)

    it("should handle multiple newlines", function()
      local stream = lexer_module.tokenize("a\n\nb")
      stream:advance()  -- a
      assert.are.equal("NEWLINE", stream:advance().type)
      -- Blank lines between statements are handled by indentation tracking
      -- The second newline triggers blank line handling
      local next_token = stream:advance()
      -- Could be another NEWLINE or the identifier depending on blank line handling
      assert.truthy(next_token.type == "NEWLINE" or next_token.type == "IDENTIFIER")
    end)
  end)

  describe("Comment tokenization", function()
    it("should tokenize line comment", function()
      local stream = lexer_module.tokenize("// this is a comment")
      local token = stream:advance()
      assert.are.equal("COMMENT", token.type)
      assert.are.equal(" this is a comment", token.literal)
    end)

    it("should stop comment at newline", function()
      local stream = lexer_module.tokenize("// comment\nnext")
      assert.are.equal("COMMENT", stream:advance().type)
      assert.are.equal("NEWLINE", stream:advance().type)
      assert.are.equal("IDENTIFIER", stream:advance().type)
    end)
  end)

  describe("Whitespace handling", function()
    it("should skip spaces between tokens", function()
      local stream = lexer_module.tokenize("a   b   c")
      assert.are.equal("a", stream:advance().lexeme)
      assert.are.equal("b", stream:advance().lexeme)
      assert.are.equal("c", stream:advance().lexeme)
    end)

    it("should skip tabs between tokens", function()
      local stream = lexer_module.tokenize("a\tb\tc")
      assert.are.equal("a", stream:advance().lexeme)
      assert.are.equal("b", stream:advance().lexeme)
      assert.are.equal("c", stream:advance().lexeme)
    end)
  end)

  describe("Indentation tracking", function()
    it("should emit INDENT on increased indentation", function()
      local stream = lexer_module.tokenize("a\n  b")
      stream:advance()  -- a
      stream:advance()  -- NEWLINE
      assert.are.equal("INDENT", stream:advance().type)
      assert.are.equal("b", stream:advance().lexeme)
    end)

    it("should emit DEDENT on decreased indentation", function()
      local stream = lexer_module.tokenize("a\n  b\nc")
      stream:advance()  -- a
      stream:advance()  -- NEWLINE
      stream:advance()  -- INDENT
      stream:advance()  -- b
      stream:advance()  -- NEWLINE
      assert.are.equal("DEDENT", stream:advance().type)
    end)

    it("should emit multiple DEDENTs for multi-level decrease", function()
      local stream = lexer_module.tokenize("a\n  b\n    c\nd")
      stream:advance()  -- a
      stream:advance()  -- NEWLINE
      stream:advance()  -- INDENT
      stream:advance()  -- b
      stream:advance()  -- NEWLINE
      stream:advance()  -- INDENT
      stream:advance()  -- c
      stream:advance()  -- NEWLINE
      assert.are.equal("DEDENT", stream:advance().type)
      assert.are.equal("DEDENT", stream:advance().type)
      assert.are.equal("d", stream:advance().lexeme)
    end)

    it("should emit remaining DEDENTs at EOF", function()
      local stream = lexer_module.tokenize("a\n  b")
      stream:advance()  -- a
      stream:advance()  -- NEWLINE
      stream:advance()  -- INDENT
      stream:advance()  -- b
      assert.are.equal("DEDENT", stream:advance().type)
      assert.are.equal("EOF", stream:advance().type)
    end)
  end)

  describe("Position tracking", function()
    it("should track line number", function()
      local stream = lexer_module.tokenize("a\nb\nc")
      assert.are.equal(1, stream:advance().pos.line)  -- a
      stream:advance()  -- NEWLINE
      assert.are.equal(2, stream:advance().pos.line)  -- b
    end)

    it("should track column number", function()
      local stream = lexer_module.tokenize("abc def")
      local first = stream:advance()
      local second = stream:advance()
      assert.are.equal(1, first.pos.column)
      assert.are.equal(5, second.pos.column)
    end)
  end)

  describe("Error handling", function()
    it("should create ERROR token for unknown character", function()
      local stream = lexer_module.tokenize("@")
      local token = stream:advance()
      assert.are.equal("ERROR", token.type)
    end)

    it("should continue after error", function()
      local stream = lexer_module.tokenize("@ hello")
      assert.are.equal("ERROR", stream:advance().type)  -- @
      assert.are.equal("IDENTIFIER", stream:advance().type)  -- hello
    end)

    it("should accumulate errors", function()
      -- Note: # is now a valid comment character, so use different test
      local lexer = lexer_module.Lexer.new("@ ^ @")
      lexer:tokenize()
      local errors = lexer:get_errors()
      assert.is_true(#errors >= 2)
    end)
  end)

  describe("reset()", function()
    it("should reset lexer state", function()
      local lexer = lexer_module.Lexer.new("hello world")
      lexer:tokenize()

      lexer:reset()
      local stream = lexer:tokenize()

      assert.are.equal("IDENTIFIER", stream:advance().type)
    end)
  end)
end)

describe("TokenStream", function()
  local lexer_module

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    lexer_module = require("whisker.script.lexer")
  end)

  describe("peek()", function()
    it("should return current token", function()
      local stream = lexer_module.tokenize("a b c")
      assert.are.equal("a", stream:peek().lexeme)
    end)

    it("should support lookahead", function()
      local stream = lexer_module.tokenize("a b c")
      assert.are.equal("a", stream:peek(0).lexeme)
      assert.are.equal("b", stream:peek(1).lexeme)
      assert.are.equal("c", stream:peek(2).lexeme)
    end)

    it("should return EOF for out of bounds", function()
      local stream = lexer_module.tokenize("a")
      assert.are.equal("EOF", stream:peek(10).type)
    end)
  end)

  describe("advance()", function()
    it("should return current and move to next", function()
      local stream = lexer_module.tokenize("a b")
      assert.are.equal("a", stream:advance().lexeme)
      assert.are.equal("b", stream:advance().lexeme)
    end)
  end)

  describe("match()", function()
    it("should match and advance on correct type", function()
      local stream = lexer_module.tokenize("hello")
      local token = stream:match("IDENTIFIER")
      assert.is_table(token)
      assert.are.equal("hello", token.lexeme)
    end)

    it("should return nil on wrong type", function()
      local stream = lexer_module.tokenize("42")
      local token = stream:match("IDENTIFIER")
      assert.is_nil(token)
    end)

    it("should not advance on no match", function()
      local stream = lexer_module.tokenize("42")
      stream:match("IDENTIFIER")
      assert.are.equal("NUMBER", stream:peek().type)
    end)
  end)

  describe("expect()", function()
    it("should return token on match", function()
      local stream = lexer_module.tokenize("hello")
      local token, err = stream:expect("IDENTIFIER", "Expected identifier")
      assert.is_table(token)
      assert.is_nil(err)
    end)

    it("should return error info on no match", function()
      local stream = lexer_module.tokenize("42")
      local token, err = stream:expect("IDENTIFIER", "Expected identifier")
      assert.is_nil(token)
      assert.is_table(err)
      assert.are.equal("IDENTIFIER", err.expected)
      assert.are.equal("NUMBER", err.found)
    end)
  end)

  describe("check()", function()
    it("should return true on match", function()
      local stream = lexer_module.tokenize("hello")
      assert.is_true(stream:check("IDENTIFIER"))
    end)

    it("should return false on no match", function()
      local stream = lexer_module.tokenize("42")
      assert.is_false(stream:check("IDENTIFIER"))
    end)

    it("should not advance", function()
      local stream = lexer_module.tokenize("hello")
      stream:check("IDENTIFIER")
      assert.are.equal("hello", stream:peek().lexeme)
    end)
  end)

  describe("at_end()", function()
    it("should return false when not at EOF", function()
      local stream = lexer_module.tokenize("hello")
      assert.is_false(stream:at_end())
    end)

    it("should return true at EOF", function()
      local stream = lexer_module.tokenize("")
      assert.is_true(stream:at_end())
    end)
  end)
end)

describe("Module exports", function()
  local lexer_module

  before_each(function()
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    lexer_module = require("whisker.script.lexer")
  end)

  it("should export Lexer class", function()
    assert.is_table(lexer_module.Lexer)
    assert.is_function(lexer_module.Lexer.new)
  end)

  it("should export TokenStream class", function()
    assert.is_table(lexer_module.TokenStream)
    assert.is_function(lexer_module.TokenStream.new)
  end)

  it("should export TokenType enum", function()
    assert.is_table(lexer_module.TokenType)
    assert.are.equal("IDENTIFIER", lexer_module.TokenType.IDENTIFIER)
  end)

  it("should export convenience functions", function()
    assert.is_function(lexer_module.tokenize)
    assert.is_function(lexer_module.new)
  end)

  it("should have _whisker metadata", function()
    assert.is_table(lexer_module._whisker)
    assert.are.equal("script.lexer", lexer_module._whisker.name)
  end)
end)
