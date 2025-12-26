-- Unit Tests for Error Reporter
local error_reporter = require("whisker.format.parsers.error_reporter")

describe("Error Reporter", function()
  describe("new", function()
    it("should create a new reporter", function()
      local reporter = error_reporter.new("test content")
      assert.is_not_nil(reporter)
    end)

    it("should split content into lines", function()
      local content = "line 1\nline 2\nline 3"
      local reporter = error_reporter.new(content)
      assert.equals(3, #reporter._lines)
    end)
  end)

  describe("get_line_number", function()
    it("should return correct line for position", function()
      local content = "line 1\nline 2\nline 3"
      local reporter = error_reporter.new(content)

      assert.equals(1, reporter:get_line_number(1))
      assert.equals(2, reporter:get_line_number(8))
      assert.equals(3, reporter:get_line_number(15))
    end)
  end)

  describe("get_column", function()
    it("should return correct column for position", function()
      local content = "line 1\nline 2"
      local reporter = error_reporter.new(content)

      assert.equals(1, reporter:get_column(1))
      assert.equals(5, reporter:get_column(5))
      assert.equals(1, reporter:get_column(8))  -- Start of line 2
    end)
  end)

  describe("add_error", function()
    it("should add an error", function()
      local reporter = error_reporter.new("test")
      reporter:add_error("Test error", 1)

      local results = reporter:get_results()
      assert.is_true(results.has_errors)
      assert.equals(1, #results.errors)
      assert.equals("Test error", results.errors[1].message)
    end)

    it("should include line and column", function()
      local content = "line 1\nline 2"
      local reporter = error_reporter.new(content)
      reporter:add_error("Error", 8)

      local results = reporter:get_results()
      assert.equals(2, results.errors[1].line)
      assert.equals(1, results.errors[1].column)
    end)
  end)

  describe("add_warning", function()
    it("should add a warning", function()
      local reporter = error_reporter.new("test")
      reporter:add_warning("Test warning", 1)

      local results = reporter:get_results()
      assert.is_true(results.has_warnings)
      assert.equals(1, #results.warnings)
    end)
  end)

  describe("check_common_errors", function()
    it("should detect unclosed parentheses", function()
      local content = "(set: $x to 1"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_true(results.has_errors)
      assert.matches("Unclosed", results.errors[1].message)
    end)

    it("should detect unexpected closing parenthesis", function()
      local content = "text)more"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_true(results.has_errors)
      assert.matches("Unexpected closing", results.errors[1].message)
    end)

    it("should detect unclosed brackets", function()
      local content = "[hook content"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_true(results.has_errors)
      assert.matches("Unclosed bracket", results.errors[1].message)
    end)

    it("should detect unclosed strings", function()
      local content = '(set: $x to "hello)'
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_true(results.has_errors)
    end)

    it("should detect unclosed SugarCube macro", function()
      local content = "<<if $x"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_true(results.has_errors)
      assert.matches("SugarCube", results.errors[1].message)
    end)

    it("should warn about empty macros", function()
      local content = "() empty macro"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_true(results.has_warnings)
    end)

    it("should provide line numbers", function()
      local content = "line 1\nline 2\n(broken"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.equals(3, results.errors[1].line)
    end)

    it("should pass valid content", function()
      local content = "(set: $x to 1)(print: $x)"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()
      local results = reporter:get_results()

      assert.is_false(results.has_errors)
    end)
  end)

  describe("format_error", function()
    it("should format errors nicely", function()
      local content = "(set: $x to 1"
      local reporter = error_reporter.new(content)
      reporter:check_common_errors()

      local formatted = reporter:format_all()
      assert.matches("error:", formatted)
      assert.matches("%^", formatted)  -- Caret pointing to error
    end)

    it("should include line number in format", function()
      local reporter = error_reporter.new("test")
      reporter:add_error("Test error", 1)

      local formatted = reporter:format_all()
      assert.matches(":1:", formatted)
    end)
  end)

  describe("get_results", function()
    it("should return results structure", function()
      local reporter = error_reporter.new("test")
      local results = reporter:get_results()

      assert.is_table(results.errors)
      assert.is_table(results.warnings)
      assert.is_boolean(results.has_errors)
      assert.is_boolean(results.has_warnings)
    end)
  end)
end)
