-- spec/script/lexer/tokens_spec.lua
-- Unit tests for token type definitions

describe("Token Types", function()
  local tokens

  before_each(function()
    package.loaded["whisker.script.lexer.tokens"] = nil
    tokens = require("whisker.script.lexer.tokens")
  end)

  describe("TokenType enum", function()
    it("should define structural token types", function()
      local TT = tokens.TokenType
      assert.are.equal("PASSAGE_DECL", TT.PASSAGE_DECL)
      assert.are.equal("CHOICE", TT.CHOICE)
      assert.are.equal("DIVERT", TT.DIVERT)
      assert.are.equal("TUNNEL", TT.TUNNEL)
      assert.are.equal("THREAD", TT.THREAD)
      assert.are.equal("ASSIGN", TT.ASSIGN)
      assert.are.equal("METADATA", TT.METADATA)
      assert.are.equal("INCLUDE", TT.INCLUDE)
    end)

    it("should define delimiter token types", function()
      local TT = tokens.TokenType
      assert.are.equal("LBRACE", TT.LBRACE)
      assert.are.equal("RBRACE", TT.RBRACE)
      assert.are.equal("LBRACKET", TT.LBRACKET)
      assert.are.equal("RBRACKET", TT.RBRACKET)
      assert.are.equal("LPAREN", TT.LPAREN)
      assert.are.equal("RPAREN", TT.RPAREN)
      assert.are.equal("COLON", TT.COLON)
      assert.are.equal("PIPE", TT.PIPE)
      assert.are.equal("COMMA", TT.COMMA)
      assert.are.equal("DASH", TT.DASH)
      assert.are.equal("DOT", TT.DOT)
    end)

    it("should define assignment operator types", function()
      local TT = tokens.TokenType
      assert.are.equal("EQ", TT.EQ)
      assert.are.equal("PLUS_EQ", TT.PLUS_EQ)
      assert.are.equal("MINUS_EQ", TT.MINUS_EQ)
      assert.are.equal("STAR_EQ", TT.STAR_EQ)
      assert.are.equal("SLASH_EQ", TT.SLASH_EQ)
    end)

    it("should define comparison operator types", function()
      local TT = tokens.TokenType
      assert.are.equal("EQ_EQ", TT.EQ_EQ)
      assert.are.equal("BANG_EQ", TT.BANG_EQ)
      assert.are.equal("LT", TT.LT)
      assert.are.equal("GT", TT.GT)
      assert.are.equal("LT_EQ", TT.LT_EQ)
      assert.are.equal("GT_EQ", TT.GT_EQ)
    end)

    it("should define arithmetic operator types", function()
      local TT = tokens.TokenType
      assert.are.equal("PLUS", TT.PLUS)
      assert.are.equal("MINUS", TT.MINUS)
      assert.are.equal("STAR", TT.STAR)
      assert.are.equal("SLASH", TT.SLASH)
      assert.are.equal("PERCENT", TT.PERCENT)
    end)

    it("should define logical operator types", function()
      local TT = tokens.TokenType
      assert.are.equal("AND", TT.AND)
      assert.are.equal("OR", TT.OR)
      assert.are.equal("NOT", TT.NOT)
    end)

    it("should define literal token types", function()
      local TT = tokens.TokenType
      assert.are.equal("TRUE", TT.TRUE)
      assert.are.equal("FALSE", TT.FALSE)
      assert.are.equal("NULL", TT.NULL)
      assert.are.equal("NUMBER", TT.NUMBER)
      assert.are.equal("STRING", TT.STRING)
    end)

    it("should define identifier and variable types", function()
      local TT = tokens.TokenType
      assert.are.equal("IDENTIFIER", TT.IDENTIFIER)
      assert.are.equal("VARIABLE", TT.VARIABLE)
      assert.are.equal("TEXT", TT.TEXT)
    end)

    it("should define keyword types", function()
      local TT = tokens.TokenType
      assert.are.equal("ELSE", TT.ELSE)
      assert.are.equal("INCLUDE_KW", TT.INCLUDE_KW)
      assert.are.equal("IMPORT_KW", TT.IMPORT_KW)
      assert.are.equal("AS", TT.AS)
      assert.are.equal("IF", TT.IF)
      assert.are.equal("ELIF", TT.ELIF)
    end)

    it("should define synthetic token types", function()
      local TT = tokens.TokenType
      assert.are.equal("NEWLINE", TT.NEWLINE)
      assert.are.equal("INDENT", TT.INDENT)
      assert.are.equal("DEDENT", TT.DEDENT)
      assert.are.equal("COMMENT", TT.COMMENT)
      assert.are.equal("EOF", TT.EOF)
      assert.are.equal("ERROR", TT.ERROR)
    end)

    it("should error on unknown token type access", function()
      local TT = tokens.TokenType
      assert.has_error(function()
        local _ = TT.UNKNOWN_TYPE
      end, "Unknown token type: UNKNOWN_TYPE")
    end)

    it("should error on token type modification", function()
      local TT = tokens.TokenType
      assert.has_error(function()
        TT.NEW_TYPE = "NEW_TYPE"
      end, "Cannot modify TokenType enum")
    end)

    it("should have at least 45 token types", function()
      local count = 0
      -- We can't iterate directly due to metatable, so check known types
      local types = {
        "PASSAGE_DECL", "CHOICE", "DIVERT", "TUNNEL", "THREAD", "ASSIGN", "METADATA", "INCLUDE",
        "LBRACE", "RBRACE", "LBRACKET", "RBRACKET", "LPAREN", "RPAREN", "COLON", "PIPE", "COMMA", "DASH", "DOT",
        "EQ", "PLUS_EQ", "MINUS_EQ", "STAR_EQ", "SLASH_EQ",
        "EQ_EQ", "BANG_EQ", "LT", "GT", "LT_EQ", "GT_EQ",
        "PLUS", "MINUS", "STAR", "SLASH", "PERCENT",
        "AND", "OR", "NOT",
        "TRUE", "FALSE", "NULL", "NUMBER", "STRING",
        "IDENTIFIER", "VARIABLE", "TEXT",
        "ELSE", "INCLUDE_KW", "IMPORT_KW", "AS", "IF", "ELIF",
        "NEWLINE", "INDENT", "DEDENT", "COMMENT", "EOF", "ERROR"
      }
      for _, t in ipairs(types) do
        local TT = tokens.TokenType
        assert.is_string(TT[t])
        count = count + 1
      end
      assert.is_true(count >= 45, "Expected at least 45 token types, got " .. count)
    end)
  end)

  describe("Token factory", function()
    it("should create token with all fields", function()
      local TT = tokens.TokenType
      local token = tokens.Token.new("PASSAGE_DECL", "::", nil, { line = 1, column = 1, offset = 0 })

      assert.are.equal("PASSAGE_DECL", token.type)
      assert.are.equal("::", token.lexeme)
      assert.is_nil(token.literal)
      assert.are.equal(1, token.pos.line)
      assert.are.equal(1, token.pos.column)
      assert.are.equal(0, token.pos.offset)
    end)

    it("should create token with literal value", function()
      local token = tokens.Token.new("NUMBER", "42", 42, { line = 5, column = 10, offset = 50 })

      assert.are.equal("NUMBER", token.type)
      assert.are.equal("42", token.lexeme)
      assert.are.equal(42, token.literal)
    end)

    it("should create token with string literal", function()
      local token = tokens.Token.new("STRING", '"hello"', "hello", { line = 1, column = 1, offset = 0 })

      assert.are.equal("STRING", token.type)
      assert.are.equal('"hello"', token.lexeme)
      assert.are.equal("hello", token.literal)
    end)

    it("should create token with default position", function()
      local token = tokens.Token.new("IDENTIFIER", "myPassage", nil, nil)

      assert.are.equal("IDENTIFIER", token.type)
      assert.is_table(token.pos)
      assert.are.equal(1, token.pos.line)
      assert.are.equal(1, token.pos.column)
    end)

    it("should create token with empty lexeme", function()
      local token = tokens.Token.new("EOF", "", nil, { line = 10, column = 1, offset = 100 })

      assert.are.equal("EOF", token.type)
      assert.are.equal("", token.lexeme)
    end)

    it("should error on invalid token type", function()
      assert.has_error(function()
        tokens.Token.new("INVALID_TYPE", "test", nil, nil)
      end)
    end)

    it("should have string representation", function()
      local token = tokens.Token.new("CHOICE", "+", nil, { line = 3, column = 5, offset = 20 })

      local str = tostring(token)
      assert.truthy(str:match("Token"))
      assert.truthy(str:match("CHOICE"))
      assert.truthy(str:match("%+"))
      assert.truthy(str:match("3:5"))
    end)

    it("should support is() method", function()
      local token = tokens.Token.new("DIVERT", "->", nil, { line = 1, column = 1, offset = 0 })

      assert.is_true(token:is("DIVERT"))
      assert.is_false(token:is("TUNNEL"))
    end)
  end)

  describe("is_keyword()", function()
    it("should recognize 'and' as keyword", function()
      assert.are.equal("AND", tokens.is_keyword("and"))
    end)

    it("should recognize 'or' as keyword", function()
      assert.are.equal("OR", tokens.is_keyword("or"))
    end)

    it("should recognize 'not' as keyword", function()
      assert.are.equal("NOT", tokens.is_keyword("not"))
    end)

    it("should recognize 'true' as keyword", function()
      assert.are.equal("TRUE", tokens.is_keyword("true"))
    end)

    it("should recognize 'false' as keyword", function()
      assert.are.equal("FALSE", tokens.is_keyword("false"))
    end)

    it("should recognize 'null' as keyword", function()
      assert.are.equal("NULL", tokens.is_keyword("null"))
    end)

    it("should recognize 'else' as keyword", function()
      assert.are.equal("ELSE", tokens.is_keyword("else"))
    end)

    it("should recognize 'if' as keyword", function()
      assert.are.equal("IF", tokens.is_keyword("if"))
    end)

    it("should recognize 'elif' as keyword", function()
      assert.are.equal("ELIF", tokens.is_keyword("elif"))
    end)

    it("should recognize 'include' as keyword", function()
      assert.are.equal("INCLUDE_KW", tokens.is_keyword("include"))
    end)

    it("should recognize 'import' as keyword", function()
      assert.are.equal("IMPORT_KW", tokens.is_keyword("import"))
    end)

    it("should recognize 'as' as keyword", function()
      assert.are.equal("AS", tokens.is_keyword("as"))
    end)

    it("should return nil for non-keywords", function()
      assert.is_nil(tokens.is_keyword("hello"))
      assert.is_nil(tokens.is_keyword("passage"))
      assert.is_nil(tokens.is_keyword("start"))
      assert.is_nil(tokens.is_keyword("AND"))  -- case sensitive
    end)
  end)

  describe("is_operator()", function()
    it("should identify assignment operators", function()
      assert.is_true(tokens.is_operator("EQ"))
      assert.is_true(tokens.is_operator("PLUS_EQ"))
      assert.is_true(tokens.is_operator("MINUS_EQ"))
      assert.is_true(tokens.is_operator("STAR_EQ"))
      assert.is_true(tokens.is_operator("SLASH_EQ"))
    end)

    it("should identify comparison operators", function()
      assert.is_true(tokens.is_operator("EQ_EQ"))
      assert.is_true(tokens.is_operator("BANG_EQ"))
      assert.is_true(tokens.is_operator("LT"))
      assert.is_true(tokens.is_operator("GT"))
      assert.is_true(tokens.is_operator("LT_EQ"))
      assert.is_true(tokens.is_operator("GT_EQ"))
    end)

    it("should identify arithmetic operators", function()
      assert.is_true(tokens.is_operator("PLUS"))
      assert.is_true(tokens.is_operator("MINUS"))
      assert.is_true(tokens.is_operator("STAR"))
      assert.is_true(tokens.is_operator("SLASH"))
      assert.is_true(tokens.is_operator("PERCENT"))
    end)

    it("should identify logical operators", function()
      assert.is_true(tokens.is_operator("AND"))
      assert.is_true(tokens.is_operator("OR"))
      assert.is_true(tokens.is_operator("NOT"))
    end)

    it("should return false for non-operators", function()
      assert.is_false(tokens.is_operator("IDENTIFIER"))
      assert.is_false(tokens.is_operator("NUMBER"))
      assert.is_false(tokens.is_operator("PASSAGE_DECL"))
      assert.is_false(tokens.is_operator("EOF"))
    end)
  end)

  describe("is_literal()", function()
    it("should identify boolean literals", function()
      assert.is_true(tokens.is_literal("TRUE"))
      assert.is_true(tokens.is_literal("FALSE"))
    end)

    it("should identify null literal", function()
      assert.is_true(tokens.is_literal("NULL"))
    end)

    it("should identify number literal", function()
      assert.is_true(tokens.is_literal("NUMBER"))
    end)

    it("should identify string literal", function()
      assert.is_true(tokens.is_literal("STRING"))
    end)

    it("should return false for non-literals", function()
      assert.is_false(tokens.is_literal("IDENTIFIER"))
      assert.is_false(tokens.is_literal("VARIABLE"))
      assert.is_false(tokens.is_literal("PLUS"))
      assert.is_false(tokens.is_literal("EOF"))
    end)
  end)

  describe("is_structural()", function()
    it("should identify structural tokens", function()
      assert.is_true(tokens.is_structural("PASSAGE_DECL"))
      assert.is_true(tokens.is_structural("CHOICE"))
      assert.is_true(tokens.is_structural("DIVERT"))
      assert.is_true(tokens.is_structural("TUNNEL"))
      assert.is_true(tokens.is_structural("THREAD"))
      assert.is_true(tokens.is_structural("ASSIGN"))
      assert.is_true(tokens.is_structural("METADATA"))
      assert.is_true(tokens.is_structural("INCLUDE"))
    end)

    it("should return false for non-structural tokens", function()
      assert.is_false(tokens.is_structural("IDENTIFIER"))
      assert.is_false(tokens.is_structural("NUMBER"))
      assert.is_false(tokens.is_structural("PLUS"))
      assert.is_false(tokens.is_structural("EOF"))
    end)
  end)

  describe("get_keywords()", function()
    it("should return a copy of keywords table", function()
      local kw = tokens.get_keywords()
      assert.is_table(kw)
      assert.are.equal("AND", kw["and"])
      assert.are.equal("OR", kw["or"])
      assert.are.equal("TRUE", kw["true"])
    end)

    it("should not allow modification of original", function()
      local kw = tokens.get_keywords()
      kw["test"] = "TEST"

      local kw2 = tokens.get_keywords()
      assert.is_nil(kw2["test"])
    end)
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(tokens._whisker)
      assert.are.equal("script.lexer.tokens", tokens._whisker.name)
      assert.is_string(tokens._whisker.version)
    end)
  end)
end)
