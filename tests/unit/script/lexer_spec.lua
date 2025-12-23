-- Tests for Whisker Script Lexer
-- tests/unit/script/lexer_spec.lua

describe("Whisker Script Lexer", function()
  local lexer_module

  setup(function()
    package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"
    lexer_module = require("whisker.script.lexer")
  end)

  describe("Token", function()
    local Token

    before_each(function()
      Token = lexer_module.Token
    end)

    it("creates token with all fields", function()
      local t = Token.new("IDENTIFIER", "foo", 1, 5, "foo")
      assert.equals("IDENTIFIER", t.type)
      assert.equals("foo", t.value)
      assert.equals(1, t.line)
      assert.equals(5, t.column)
      assert.equals(3, t.length)
      assert.equals("foo", t.raw)
    end)

    it("converts to string", function()
      local t = Token.new("NUMBER", 42, 2, 10, "42")
      local s = tostring(t)
      assert.is_string(s)
      assert.truthy(s:match("NUMBER"))
      assert.truthy(s:match("42"))
      assert.truthy(s:match("2:10"))
    end)

    it("handles nil value", function()
      local t = Token.new("NEWLINE", nil, 1, 1, "\n")
      assert.is_nil(t.value)
      local s = tostring(t)
      assert.is_string(s)
    end)
  end)

  describe("Lexer", function()
    local Lexer

    before_each(function()
      Lexer = lexer_module.Lexer
    end)

    describe("initialization", function()
      it("creates lexer with source", function()
        local l = Lexer.new("hello")
        assert.equals("hello", l.source)
        assert.equals(1, l.pos)
        assert.equals(1, l.line)
        assert.equals(1, l.column)
      end)

      it("stores filename", function()
        local l = Lexer.new("test", "test.ws")
        assert.equals("test.ws", l.filename)
      end)

      it("uses default filename", function()
        local l = Lexer.new("test")
        assert.equals("<input>", l.filename)
      end)

      it("normalizes CRLF to LF", function()
        local l = Lexer.new("a\r\nb")
        assert.equals("a\nb", l.source)
      end)

      it("normalizes CR to LF", function()
        local l = Lexer.new("a\rb")
        assert.equals("a\nb", l.source)
      end)
    end)

    describe("peek and advance", function()
      it("peek returns current char without consuming", function()
        local l = Lexer.new("abc")
        assert.equals("a", l:peek())
        assert.equals("a", l:peek())  -- Still 'a'
        assert.equals(1, l.pos)
      end)

      it("peek with offset", function()
        local l = Lexer.new("abc")
        assert.equals("a", l:peek(0))
        assert.equals("b", l:peek(1))
        assert.equals("c", l:peek(2))
        assert.is_nil(l:peek(3))
      end)

      it("advance consumes char", function()
        local l = Lexer.new("abc")
        assert.equals("a", l:advance())
        assert.equals("b", l:peek())
        assert.equals(2, l.pos)
      end)

      it("advance updates column", function()
        local l = Lexer.new("abc")
        l:advance()
        assert.equals(2, l.column)
        l:advance()
        assert.equals(3, l.column)
      end)

      it("advance updates line on newline", function()
        local l = Lexer.new("a\nb")
        l:advance()  -- 'a'
        assert.equals(1, l.line)
        assert.equals(2, l.column)

        l:advance()  -- '\n'
        assert.equals(2, l.line)
        assert.equals(1, l.column)
      end)

      it("advance returns nil at end", function()
        local l = Lexer.new("a")
        l:advance()
        assert.is_nil(l:advance())
      end)
    end)

    describe("match", function()
      it("matches and consumes expected char", function()
        local l = Lexer.new("abc")
        assert.is_true(l:match("a"))
        assert.equals(2, l.pos)
      end)

      it("does not match unexpected char", function()
        local l = Lexer.new("abc")
        assert.is_false(l:match("b"))
        assert.equals(1, l.pos)  -- Not consumed
      end)

      it("returns false at end", function()
        local l = Lexer.new("")
        assert.is_false(l:match("a"))
      end)
    end)

    describe("match_string", function()
      it("matches multi-char string", function()
        local l = Lexer.new("::Start")
        assert.is_true(l:match_string("::"))
        assert.equals(3, l.pos)
      end)

      it("does not match partial", function()
        local l = Lexer.new(":Start")
        assert.is_false(l:match_string("::"))
        assert.equals(1, l.pos)
      end)
    end)

    describe("consume_while", function()
      it("consumes while predicate is true", function()
        local l = Lexer.new("123abc")
        local result = l:consume_while(lexer_module.is_digit)
        assert.equals("123", result)
        assert.equals("a", l:peek())
      end)

      it("returns empty if predicate false immediately", function()
        local l = Lexer.new("abc")
        local result = l:consume_while(lexer_module.is_digit)
        assert.equals("", result)
        assert.equals("a", l:peek())
      end)
    end)
  end)

  describe("tokenize", function()
    local Lexer

    before_each(function()
      Lexer = lexer_module.Lexer
    end)

    it("produces EOF token for empty input", function()
      local l = Lexer.new("")
      local tokens = l:tokenize()
      assert.equals(1, #tokens)
      assert.equals("EOF", tokens[1].type)
    end)

    it("emits newline token", function()
      local l = Lexer.new("\n")
      local tokens = l:tokenize()
      assert.equals(2, #tokens)  -- NEWLINE + EOF
      assert.equals("NEWLINE", tokens[1].type)
    end)

    it("skips whitespace", function()
      local l = Lexer.new("   \t  ")
      local tokens = l:tokenize()
      assert.equals(1, #tokens)  -- Just EOF
    end)

    it("tokenizes passage marker", function()
      local l = Lexer.new("::")
      local tokens = l:tokenize()
      assert.equals(2, #tokens)
      assert.equals("PASSAGE_MARKER", tokens[1].type)
    end)

    it("tokenizes identifier", function()
      local l = Lexer.new("Start")
      local tokens = l:tokenize()
      assert.equals(2, #tokens)
      assert.equals("IDENTIFIER", tokens[1].type)
      assert.equals("Start", tokens[1].value)
    end)

    it("tokenizes identifier with underscore", function()
      local l = Lexer.new("my_passage_name")
      local tokens = l:tokenize()
      assert.equals("IDENTIFIER", tokens[1].type)
      assert.equals("my_passage_name", tokens[1].value)
    end)

    it("tokenizes number", function()
      local l = Lexer.new("42")
      local tokens = l:tokenize()
      assert.equals("NUMBER", tokens[1].type)
      assert.equals(42, tokens[1].value)
    end)

    it("tokenizes decimal number", function()
      local l = Lexer.new("3.14")
      local tokens = l:tokenize()
      assert.equals("NUMBER", tokens[1].type)
      assert.equals(3.14, tokens[1].value)
    end)

    it("tokenizes string", function()
      local l = Lexer.new('"hello"')
      local tokens = l:tokenize()
      assert.equals("STRING", tokens[1].type)
      assert.equals("hello", tokens[1].value)
    end)

    it("tokenizes string with escapes", function()
      local l = Lexer.new('"hello\\nworld"')
      local tokens = l:tokenize()
      assert.equals("STRING", tokens[1].type)
      assert.equals("hello\nworld", tokens[1].value)
    end)

    it("tokenizes string with escaped quote", function()
      local l = Lexer.new('"say \\"hi\\""')
      local tokens = l:tokenize()
      assert.equals("STRING", tokens[1].type)
      assert.equals('say "hi"', tokens[1].value)
    end)

    it("tokenizes true keyword", function()
      local l = Lexer.new("true")
      local tokens = l:tokenize()
      assert.equals("TRUE", tokens[1].type)
      assert.equals(true, tokens[1].value)
    end)

    it("tokenizes false keyword", function()
      local l = Lexer.new("false")
      local tokens = l:tokenize()
      assert.equals("FALSE", tokens[1].type)
      assert.equals(false, tokens[1].value)
    end)

    it("tokenizes arrow", function()
      local l = Lexer.new("->")
      local tokens = l:tokenize()
      assert.equals("ARROW", tokens[1].type)
    end)

    it("tokenizes dollar", function()
      local l = Lexer.new("$")
      local tokens = l:tokenize()
      assert.equals("DOLLAR", tokens[1].type)
    end)

    it("tokenizes braces", function()
      local l = Lexer.new("{ }")
      local tokens = l:tokenize()
      assert.equals("LBRACE", tokens[1].type)
      assert.equals("RBRACE", tokens[2].type)
    end)

    it("tokenizes brackets", function()
      local l = Lexer.new("[ ]")
      local tokens = l:tokenize()
      assert.equals("LBRACKET", tokens[1].type)
      assert.equals("RBRACKET", tokens[2].type)
    end)

    it("tokenizes parens", function()
      local l = Lexer.new("( )")
      local tokens = l:tokenize()
      assert.equals("LPAREN", tokens[1].type)
      assert.equals("RPAREN", tokens[2].type)
    end)

    it("tokenizes comparison operators", function()
      local l = Lexer.new("== != < > <= >=")
      local tokens = l:tokenize()
      assert.equals("EQ", tokens[1].type)
      assert.equals("NEQ", tokens[2].type)
      assert.equals("LT", tokens[3].type)
      assert.equals("GT", tokens[4].type)
      assert.equals("LTE", tokens[5].type)
      assert.equals("GTE", tokens[6].type)
    end)

    it("tokenizes logical operators", function()
      local l = Lexer.new("&& || !")
      local tokens = l:tokenize()
      assert.equals("AND", tokens[1].type)
      assert.equals("OR", tokens[2].type)
      assert.equals("NOT", tokens[3].type)
    end)

    it("tokenizes assignment operators", function()
      local l = Lexer.new("= += -=")
      local tokens = l:tokenize()
      assert.equals("ASSIGN", tokens[1].type)
      assert.equals("PLUS_ASSIGN", tokens[2].type)
      assert.equals("MINUS_ASSIGN", tokens[3].type)
    end)

    it("tokenizes plus and slash", function()
      local l = Lexer.new("+ /")
      local tokens = l:tokenize()
      assert.equals("PLUS", tokens[1].type)
      assert.equals("SLASH", tokens[2].type)
    end)

    it("skips line comments", function()
      local l = Lexer.new("// comment\ntext")
      local tokens = l:tokenize()
      assert.equals("NEWLINE", tokens[1].type)
      assert.equals("TEXT", tokens[2].type)
    end)

    it("skips block comments", function()
      local l = Lexer.new("/* comment */text")
      local tokens = l:tokenize()
      assert.equals("TEXT", tokens[1].type)
      assert.equals("text", tokens[1].value)
    end)

    it("skips multiline block comments", function()
      local l = Lexer.new("/* multi\nline */x")
      local tokens = l:tokenize()
      assert.equals("IDENTIFIER", tokens[1].type)
    end)

    it("tokenizes lua block", function()
      local l = Lexer.new("{{ code }}")
      local tokens = l:tokenize()
      assert.equals("LUA_BLOCK", tokens[1].type)
      assert.equals(" code ", tokens[1].value)
    end)

    it("tokenizes complex lua block", function()
      local l = Lexer.new("{{ math.random(1, 10) }}")
      local tokens = l:tokenize()
      assert.equals("LUA_BLOCK", tokens[1].type)
      assert.equals(" math.random(1, 10) ", tokens[1].value)
    end)

    it("tokenizes text content", function()
      local l = Lexer.new("Hello world!")
      local tokens = l:tokenize()
      assert.equals("TEXT", tokens[1].type)
      assert.equals("Hello world!", tokens[1].value)
    end)
  end)

  describe("complex inputs", function()
    local Lexer

    before_each(function()
      Lexer = lexer_module.Lexer
    end)

    it("tokenizes passage header", function()
      local l = Lexer.new(":: Start\n")
      local tokens = l:tokenize()
      assert.equals("PASSAGE_MARKER", tokens[1].type)
      assert.equals("IDENTIFIER", tokens[2].type)
      assert.equals("Start", tokens[2].value)
      assert.equals("NEWLINE", tokens[3].type)
    end)

    it("tokenizes choice", function()
      local l = Lexer.new("+ [Go north] -> North\n")
      local tokens = l:tokenize()
      assert.equals("PLUS", tokens[1].type)
      assert.equals("LBRACKET", tokens[2].type)
      -- Text inside brackets
      assert.equals("TEXT", tokens[3].type)
      assert.equals("Go north", tokens[3].value)
      assert.equals("RBRACKET", tokens[4].type)
      assert.equals("ARROW", tokens[5].type)
      assert.equals("IDENTIFIER", tokens[6].type)
      assert.equals("North", tokens[6].value)
    end)

    it("tokenizes variable assignment", function()
      local l = Lexer.new("$gold = 100\n")
      local tokens = l:tokenize()
      assert.equals("DOLLAR", tokens[1].type)
      assert.equals("IDENTIFIER", tokens[2].type)
      assert.equals("gold", tokens[2].value)
      assert.equals("ASSIGN", tokens[3].type)
      assert.equals("NUMBER", tokens[4].type)
      assert.equals(100, tokens[4].value)
    end)

    it("tokenizes conditional", function()
      local l = Lexer.new("{ $gold > 50 }\n")
      local tokens = l:tokenize()
      assert.equals("LBRACE", tokens[1].type)
      assert.equals("DOLLAR", tokens[2].type)
      assert.equals("IDENTIFIER", tokens[3].type)
      assert.equals("GT", tokens[4].type)
      assert.equals("NUMBER", tokens[5].type)
      assert.equals("RBRACE", tokens[6].type)
    end)

    it("tokenizes conditional close", function()
      local l = Lexer.new("{ / }\n")
      local tokens = l:tokenize()
      assert.equals("LBRACE", tokens[1].type)
      assert.equals("SLASH", tokens[2].type)
      assert.equals("RBRACE", tokens[3].type)
    end)

    it("tokenizes complex expression", function()
      local l = Lexer.new("{ $gold >= 50 && $level > 3 }")
      local tokens = l:tokenize()
      local types = {}
      for _, t in ipairs(tokens) do
        table.insert(types, t.type)
      end
      assert.same({
        "LBRACE", "DOLLAR", "IDENTIFIER", "GTE", "NUMBER",
        "AND", "DOLLAR", "IDENTIFIER", "GT", "NUMBER", "RBRACE", "EOF"
      }, types)
    end)

    it("tracks line numbers correctly", function()
      local l = Lexer.new(":: Start\ncontent\n:: Second")
      local tokens = l:tokenize()
      assert.equals(1, tokens[1].line)  -- ::
      assert.equals(1, tokens[2].line)  -- Start
      assert.equals(1, tokens[3].line)  -- newline
      assert.equals(2, tokens[4].line)  -- content
      assert.equals(2, tokens[5].line)  -- newline
      assert.equals(3, tokens[6].line)  -- ::
    end)
  end)

  describe("error handling", function()
    local Lexer

    before_each(function()
      Lexer = lexer_module.Lexer
    end)

    it("reports unterminated string", function()
      local l = Lexer.new('"hello')
      local tokens = l:tokenize()
      local has_error = false
      for _, t in ipairs(tokens) do
        if t.type == "ERROR" then
          has_error = true
          assert.truthy(t.value:match("unterminated string"))
        end
      end
      assert.is_true(has_error)
    end)

    it("reports unterminated block comment", function()
      local l = Lexer.new("/* comment")
      local tokens = l:tokenize()
      local has_error = false
      for _, t in ipairs(tokens) do
        if t.type == "ERROR" then
          has_error = true
          assert.truthy(t.value:match("unterminated"))
        end
      end
      assert.is_true(has_error)
    end)

    it("reports unterminated lua block", function()
      local l = Lexer.new("{{ code")
      local tokens = l:tokenize()
      local has_error = false
      for _, t in ipairs(tokens) do
        if t.type == "ERROR" then
          has_error = true
        end
      end
      assert.is_true(has_error)
    end)

    it("collects errors list", function()
      local l = Lexer.new('"unterminated')
      l:tokenize()
      assert.equals(1, #l.errors)
      assert.truthy(l.errors[1].message:match("unterminated"))
      assert.equals(1, l.errors[1].line)
    end)
  end)

  describe("character classification", function()
    it("is_alpha identifies letters and underscore", function()
      assert.is_true(lexer_module.is_alpha("a"))
      assert.is_true(lexer_module.is_alpha("Z"))
      assert.is_true(lexer_module.is_alpha("_"))
      assert.is_false(lexer_module.is_alpha("1"))
      assert.is_false(lexer_module.is_alpha(" "))
      assert.is_false(lexer_module.is_alpha(nil))
    end)

    it("is_digit identifies digits", function()
      assert.is_true(lexer_module.is_digit("0"))
      assert.is_true(lexer_module.is_digit("9"))
      assert.is_false(lexer_module.is_digit("a"))
      assert.is_false(lexer_module.is_digit(nil))
    end)

    it("is_alphanumeric identifies both", function()
      assert.is_true(lexer_module.is_alphanumeric("a"))
      assert.is_true(lexer_module.is_alphanumeric("9"))
      assert.is_true(lexer_module.is_alphanumeric("_"))
      assert.is_false(lexer_module.is_alphanumeric(" "))
    end)

    it("is_whitespace identifies spaces and tabs", function()
      assert.is_true(lexer_module.is_whitespace(" "))
      assert.is_true(lexer_module.is_whitespace("\t"))
      assert.is_true(lexer_module.is_whitespace("\r"))
      assert.is_false(lexer_module.is_whitespace("\n"))
      assert.is_false(lexer_module.is_whitespace("a"))
    end)
  end)
end)
