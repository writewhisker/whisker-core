-- tests/contracts/script/lexer_contract.lua
-- Contract tests for ILexer interface

describe("ILexer Contract", function()
  local Lexer

  before_each(function()
    package.loaded["whisker.script.lexer"] = nil
    Lexer = require("whisker.script.lexer")
  end)

  describe("tokenize()", function()
    pending("should accept source string", function()
      local lexer = Lexer.new()
      local tokens = lexer:tokenize(":: Start")
      assert.is_table(tokens)
    end)

    pending("should return TokenStream with tokens", function()
      local lexer = Lexer.new()
      local tokens = lexer:tokenize(":: Start\n+ [Choice]")
      assert.is_function(tokens.peek)
      assert.is_function(tokens.advance)
    end)

    pending("should produce error tokens for invalid input", function()
      local lexer = Lexer.new()
      local tokens = lexer:tokenize("{{{{")
      -- Should not throw, should produce error token
      assert.is_table(tokens)
    end)
  end)

  describe("reset()", function()
    pending("should reset internal state for reuse", function()
      local lexer = Lexer.new()
      lexer:tokenize(":: First")
      lexer:reset()
      local tokens = lexer:tokenize(":: Second")
      assert.is_table(tokens)
    end)
  end)
end)

describe("Lexer module structure", function()
  it("should load without error", function()
    local ok, mod = pcall(require, "whisker.script.lexer")
    assert.is_true(ok, "Failed to load whisker.script.lexer")
    assert.is_table(mod)
  end)

  it("should have _whisker metadata", function()
    local mod = require("whisker.script.lexer")
    assert.is_table(mod._whisker)
    assert.are.equal("script.lexer", mod._whisker.name)
  end)

  it("should have new() factory function", function()
    local mod = require("whisker.script.lexer")
    assert.is_function(mod.new)
  end)
end)
