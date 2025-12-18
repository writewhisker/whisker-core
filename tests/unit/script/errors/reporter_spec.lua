-- tests/unit/script/errors/reporter_spec.lua
-- Tests for error reporter

describe("ErrorReporter", function()
  local ErrorReporter
  local codes
  local source_module

  before_each(function()
    -- Clear cached modules
    package.loaded["whisker.script.errors"] = nil
    package.loaded["whisker.script.errors.reporter"] = nil
    package.loaded["whisker.script.errors.codes"] = nil
    package.loaded["whisker.script.source"] = nil

    local errors = require("whisker.script.errors")
    ErrorReporter = errors.ErrorReporter
    codes = errors
    source_module = require("whisker.script.source")
  end)

  local function make_pos(line, col)
    return source_module.SourcePosition.new(line, col, (line - 1) * 80 + col)
  end

  describe("new()", function()
    it("should create a new reporter", function()
      local reporter = ErrorReporter.new()
      assert.is_not_nil(reporter)
    end)

    it("should accept options", function()
      local reporter = ErrorReporter.new({ format = "json", color = false })
      assert.is_not_nil(reporter)
    end)
  end)

  describe("set_source()", function()
    it("should set source for context", function()
      local reporter = ErrorReporter.new()
      reporter:set_source(":: Start\nHello world", "test.wsk")
      -- Should not error
      assert.is_not_nil(reporter._source_file)
    end)
  end)

  describe("set_format()", function()
    it("should accept text format", function()
      local reporter = ErrorReporter.new()
      reporter:set_format("text")
      assert.are.equal("text", reporter._format)
    end)

    it("should accept json format", function()
      local reporter = ErrorReporter.new()
      reporter:set_format("json")
      assert.are.equal("json", reporter._format)
    end)

    it("should accept annotated format", function()
      local reporter = ErrorReporter.new()
      reporter:set_format("annotated")
      assert.are.equal("annotated", reporter._format)
    end)

    it("should reject invalid format", function()
      local reporter = ErrorReporter.new()
      assert.has_error(function()
        reporter:set_format("invalid")
      end)
    end)
  end)

  describe("format() - text", function()
    it("should format basic error", function()
      local reporter = ErrorReporter.new({ color = false })
      local diag = {
        code = "WSK0001",
        message = "Unexpected character 'X'",
        severity = codes.Severity.ERROR,
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find("error"))
      assert.is_truthy(result:find("WSK0001"))
      assert.is_truthy(result:find("Unexpected character"))
    end)

    it("should format warning", function()
      local reporter = ErrorReporter.new({ color = false })
      local diag = {
        code = "WSK0250",
        message = "Passage 'Test' is never referenced",
        severity = codes.Severity.WARNING,
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find("warning"))
    end)

    it("should include position", function()
      local reporter = ErrorReporter.new({ color = false })
      local diag = {
        code = "WSK0001",
        message = "Test error",
        severity = codes.Severity.ERROR,
        position = make_pos(5, 10),
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find("5:10"))
    end)

    it("should include source snippet", function()
      local reporter = ErrorReporter.new({ color = false })
      reporter:set_source(":: Start\nHello world\nGoodbye", "test.wsk")

      local diag = {
        code = "WSK0001",
        message = "Test error",
        severity = codes.Severity.ERROR,
        position = make_pos(2, 7),
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find("Hello world"))
      assert.is_truthy(result:find("test.wsk"))
    end)

    it("should include suggestion", function()
      local reporter = ErrorReporter.new({ color = false })
      local diag = {
        code = "WSK0001",
        message = "Test error",
        severity = codes.Severity.ERROR,
        suggestion = "Try doing this instead",
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find("help:"))
      assert.is_truthy(result:find("Try doing this instead"))
    end)
  end)

  describe("format() - json", function()
    it("should format as JSON", function()
      local reporter = ErrorReporter.new({ format = "json" })
      local diag = {
        code = "WSK0001",
        message = "Test error",
        severity = codes.Severity.ERROR,
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find('"code":"WSK0001"'))
      assert.is_truthy(result:find('"message":"Test error"'))
      assert.is_truthy(result:find('"severity":"error"'))
    end)

    it("should include location in JSON", function()
      local reporter = ErrorReporter.new({ format = "json" })
      local diag = {
        code = "WSK0001",
        message = "Test error",
        severity = codes.Severity.ERROR,
        position = make_pos(5, 10),
        file_path = "test.wsk",
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find('"location"'))
      assert.is_truthy(result:find('"line":5'))
      assert.is_truthy(result:find('"column":10'))
    end)

    it("should escape strings in JSON", function()
      local reporter = ErrorReporter.new({ format = "json" })
      local diag = {
        code = "WSK0001",
        message = 'Error with "quotes" and\nnewline',
        severity = codes.Severity.ERROR,
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find('\\"quotes\\"'))
      assert.is_truthy(result:find('\\n'))
    end)
  end)

  describe("format() - annotated", function()
    it("should format with source annotation", function()
      local reporter = ErrorReporter.new({ format = "annotated", color = false })
      reporter:set_source(":: Start\nHello world\nGoodbye", "test.wsk")

      local diag = {
        code = "WSK0001",
        message = "Test error",
        severity = codes.Severity.ERROR,
        position = make_pos(2, 7),
        length = 5,
      }

      local result = reporter:format(diag)
      assert.is_truthy(result:find("Hello world"))
      assert.is_truthy(result:find("%^%^%^%^%^")) -- 5 carets
    end)
  end)

  describe("format_all()", function()
    it("should format multiple diagnostics", function()
      local reporter = ErrorReporter.new({ color = false })
      local diags = {
        { code = "WSK0001", message = "Error 1", severity = codes.Severity.ERROR },
        { code = "WSK0002", message = "Error 2", severity = codes.Severity.ERROR },
      }

      local result = reporter:format_all(diags)
      assert.is_truthy(result:find("Error 1"))
      assert.is_truthy(result:find("Error 2"))
    end)

    it("should format as JSON array", function()
      local reporter = ErrorReporter.new({ format = "json" })
      local diags = {
        { code = "WSK0001", message = "Error 1", severity = codes.Severity.ERROR },
        { code = "WSK0002", message = "Error 2", severity = codes.Severity.ERROR },
      }

      local result = reporter:format_all(diags)
      assert.is_truthy(result:match("^%["))  -- Starts with [
      assert.is_truthy(result:match("%]$"))  -- Ends with ]
    end)
  end)

  describe("module structure", function()
    it("should have _whisker metadata", function()
      local reporter_mod = require("whisker.script.errors.reporter")
      assert.is_table(reporter_mod._whisker)
      assert.are.equal("script.errors.reporter", reporter_mod._whisker.name)
    end)

    it("should have new() factory", function()
      local reporter_mod = require("whisker.script.errors.reporter")
      assert.is_function(reporter_mod.new)
    end)
  end)
end)

describe("errors module", function()
  before_each(function()
    package.loaded["whisker.script.errors"] = nil
  end)

  it("should export error codes", function()
    local errors = require("whisker.script.errors")
    assert.is_table(errors.Lexer)
    assert.is_table(errors.Parser)
    assert.is_table(errors.Semantic)
  end)

  it("should export Severity", function()
    local errors = require("whisker.script.errors")
    assert.are.equal("error", errors.Severity.ERROR)
    assert.are.equal("warning", errors.Severity.WARNING)
    assert.are.equal("hint", errors.Severity.HINT)
  end)

  it("should export format_message()", function()
    local errors = require("whisker.script.errors")
    assert.is_function(errors.format_message)

    local msg = errors.format_message(errors.Lexer.UNEXPECTED_CHARACTER, "@")
    assert.is_truthy(msg:find("@"))
  end)

  it("should export ErrorReporter", function()
    local errors = require("whisker.script.errors")
    assert.is_table(errors.ErrorReporter)
  end)

  it("should have new() factory", function()
    local errors = require("whisker.script.errors")
    assert.is_function(errors.new)

    local reporter = errors.new()
    assert.is_not_nil(reporter)
  end)
end)
