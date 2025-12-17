-- tests/contracts/script/parser_contract.lua
-- Contract tests for IParser interface

describe("IParser Contract", function()
  local Parser

  before_each(function()
    package.loaded["whisker.script.parser"] = nil
    Parser = require("whisker.script.parser")
  end)

  describe("parse()", function()
    pending("should accept TokenStream", function()
      local parser = Parser.new()
      -- Requires token stream from lexer
      -- local ast = parser:parse(tokens)
      -- assert.is_table(ast)
    end)

    pending("should return AST with type field", function()
      local parser = Parser.new()
      -- local ast = parser:parse(tokens)
      -- assert.is_string(ast.type)
    end)

    pending("should preserve source positions in AST nodes", function()
      local parser = Parser.new()
      -- local ast = parser:parse(tokens)
      -- assert.is_table(ast.pos)
    end)
  end)

  describe("set_error_handler()", function()
    pending("should accept error handler function", function()
      local parser = Parser.new()
      local errors = {}
      parser:set_error_handler(function(err)
        table.insert(errors, err)
      end)
      -- Parse invalid input and check errors captured
    end)
  end)
end)

describe("Parser module structure", function()
  it("should load without error", function()
    local ok, mod = pcall(require, "whisker.script.parser")
    assert.is_true(ok, "Failed to load whisker.script.parser")
    assert.is_table(mod)
  end)

  it("should have _whisker metadata", function()
    local mod = require("whisker.script.parser")
    assert.is_table(mod._whisker)
    assert.are.equal("script.parser", mod._whisker.name)
  end)

  it("should have new() factory function", function()
    local mod = require("whisker.script.parser")
    assert.is_function(mod.new)
  end)
end)
