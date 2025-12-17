-- tests/contracts/script/compiler_contract.lua
-- Contract tests for IScriptCompiler interface

describe("IScriptCompiler Contract", function()
  local Compiler

  before_each(function()
    package.loaded["whisker.script"] = nil
    Compiler = require("whisker.script")
  end)

  describe("compile()", function()
    pending("should accept source string and options", function()
      -- Will be implemented when compiler is ready
      local result = Compiler:compile(":: Start\nHello, World!")
      assert.is_table(result)
      assert.is_table(result.story)
      assert.is_table(result.diagnostics)
    end)

    pending("should return diagnostics array", function()
      local result = Compiler:compile("invalid {{{{")
      assert.is_table(result.diagnostics)
    end)

    pending("should optionally include sourcemap", function()
      local result = Compiler:compile(":: Start\nHello!", { sourcemap = true })
      assert.is_table(result.sourcemap)
    end)
  end)

  describe("parse_only()", function()
    pending("should return AST without code generation", function()
      local ast = Compiler:parse_only(":: Start\nHello!")
      assert.is_table(ast)
      assert.is_string(ast.type)
    end)
  end)

  describe("validate()", function()
    pending("should return diagnostics without generating code", function()
      local diagnostics = Compiler:validate(":: Start\n-> Missing")
      assert.is_table(diagnostics)
    end)
  end)

  describe("get_tokens()", function()
    pending("should return token stream", function()
      local tokens = Compiler:get_tokens(":: Start\n+ [Choice]")
      assert.is_table(tokens)
    end)
  end)
end)

describe("Module structure", function()
  it("should load without error", function()
    local ok, mod = pcall(require, "whisker.script")
    assert.is_true(ok, "Failed to load whisker.script")
    assert.is_table(mod)
  end)

  it("should have _whisker metadata", function()
    local mod = require("whisker.script")
    assert.is_table(mod._whisker)
    assert.are.equal("whisker.script", mod._whisker.name)
    assert.is_string(mod._whisker.version)
  end)

  it("should have init function for container registration", function()
    local mod = require("whisker.script")
    assert.is_function(mod.init)
  end)

  it("should load interfaces module", function()
    local mod = require("whisker.script")
    local interfaces = mod.interfaces()
    assert.is_table(interfaces)
    assert.is_table(interfaces.IScriptCompiler)
    assert.is_table(interfaces.ILexer)
    assert.is_table(interfaces.IParser)
  end)
end)
