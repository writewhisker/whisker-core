-- spec/script/source_spec.lua
-- Unit tests for source position and span tracking

describe("Source Position Tracking", function()
  local source

  before_each(function()
    package.loaded["whisker.script.source"] = nil
    source = require("whisker.script.source")
  end)

  describe("SourcePosition", function()
    it("should create with default values", function()
      local pos = source.SourcePosition.new()
      assert.are.equal(1, pos.line)
      assert.are.equal(1, pos.column)
      assert.are.equal(0, pos.offset)
    end)

    it("should create with specified values", function()
      local pos = source.SourcePosition.new(5, 10, 100)
      assert.are.equal(5, pos.line)
      assert.are.equal(10, pos.column)
      assert.are.equal(100, pos.offset)
    end)

    it("should clone correctly", function()
      local pos = source.SourcePosition.new(3, 7, 50)
      local clone = pos:clone()

      assert.are.equal(pos.line, clone.line)
      assert.are.equal(pos.column, clone.column)
      assert.are.equal(pos.offset, clone.offset)

      -- Ensure it's a separate object
      clone.line = 99
      assert.are.equal(3, pos.line)
    end)

    it("should advance column for regular character", function()
      local pos = source.SourcePosition.new(1, 1, 0)
      local new = pos:advance('a')

      assert.are.equal(1, new.line)
      assert.are.equal(2, new.column)
      assert.are.equal(1, new.offset)
    end)

    it("should advance line for newline", function()
      local pos = source.SourcePosition.new(1, 5, 4)
      local new = pos:advance('\n')

      assert.are.equal(2, new.line)
      assert.are.equal(1, new.column)
      assert.are.equal(5, new.offset)
    end)

    it("should handle tab advancement", function()
      local pos = source.SourcePosition.new(1, 1, 0)
      local new = pos:advance('\t')

      assert.are.equal(1, new.line)
      -- Tab should advance to column 9 (next 8-column boundary from 1)
      assert.are.equal(9, new.column)
      assert.are.equal(1, new.offset)
    end)

    it("should handle tab at various positions", function()
      -- Column 3 -> should go to column 9
      local pos1 = source.SourcePosition.new(1, 3, 2)
      local new1 = pos1:advance('\t')
      assert.are.equal(9, new1.column)

      -- Column 8 -> should go to column 9
      local pos2 = source.SourcePosition.new(1, 8, 7)
      local new2 = pos2:advance('\t')
      assert.are.equal(9, new2.column)

      -- Column 9 -> should go to column 17
      local pos3 = source.SourcePosition.new(1, 9, 8)
      local new3 = pos3:advance('\t')
      assert.are.equal(17, new3.column)
    end)

    it("should not mutate original when advancing", function()
      local pos = source.SourcePosition.new(1, 1, 0)
      local _ = pos:advance('x')

      assert.are.equal(1, pos.line)
      assert.are.equal(1, pos.column)
      assert.are.equal(0, pos.offset)
    end)

    it("should support advance_line convenience method", function()
      local pos = source.SourcePosition.new(3, 10, 50)
      local new = pos:advance_line()

      assert.are.equal(4, new.line)
      assert.are.equal(1, new.column)
    end)

    it("should have string representation", function()
      local pos = source.SourcePosition.new(5, 12, 100)
      assert.are.equal("5:12", tostring(pos))
    end)

    it("should support equality comparison", function()
      local pos1 = source.SourcePosition.new(1, 5, 4)
      local pos2 = source.SourcePosition.new(1, 5, 4)
      local pos3 = source.SourcePosition.new(1, 6, 4)

      assert.is_true(pos1 == pos2)
      assert.is_false(pos1 == pos3)
    end)
  end)

  describe("SourceSpan", function()
    it("should create from start and end positions", function()
      local start_pos = source.SourcePosition.new(1, 1, 0)
      local end_pos = source.SourcePosition.new(1, 10, 9)
      local span = source.SourceSpan.new(start_pos, end_pos)

      assert.are.equal(1, span.start.line)
      assert.are.equal(10, span.end_pos.column)
    end)

    it("should create from_positions convenience", function()
      local start_pos = source.SourcePosition.new(1, 1, 0)
      local end_pos = source.SourcePosition.new(1, 5, 4)
      local span = source.SourceSpan.from_positions(start_pos, end_pos)

      assert.are.equal(start_pos.line, span.start.line)
      assert.are.equal(end_pos.column, span.end_pos.column)
    end)

    it("should default end_pos to start_pos clone", function()
      local start_pos = source.SourcePosition.new(1, 5, 4)
      local span = source.SourceSpan.new(start_pos)

      assert.are.equal(span.start.line, span.end_pos.line)
      assert.are.equal(span.start.column, span.end_pos.column)
    end)

    it("should merge two spans", function()
      local span1 = source.SourceSpan.new(
        source.SourcePosition.new(1, 1, 0),
        source.SourcePosition.new(1, 5, 4)
      )
      local span2 = source.SourceSpan.new(
        source.SourcePosition.new(1, 10, 9),
        source.SourcePosition.new(1, 15, 14)
      )

      local merged = span1:merge(span2)

      assert.are.equal(0, merged.start.offset)
      assert.are.equal(14, merged.end_pos.offset)
    end)

    it("should merge spans with overlapping start", function()
      local span1 = source.SourceSpan.new(
        source.SourcePosition.new(1, 5, 4),
        source.SourcePosition.new(1, 10, 9)
      )
      local span2 = source.SourceSpan.new(
        source.SourcePosition.new(1, 1, 0),
        source.SourcePosition.new(1, 7, 6)
      )

      local merged = span1:merge(span2)

      assert.are.equal(0, merged.start.offset)
      assert.are.equal(9, merged.end_pos.offset)
    end)

    it("should check if contains position", function()
      local span = source.SourceSpan.new(
        source.SourcePosition.new(1, 1, 0),
        source.SourcePosition.new(1, 10, 9)
      )

      local inside = source.SourcePosition.new(1, 5, 4)
      local outside = source.SourcePosition.new(1, 15, 14)
      local at_start = source.SourcePosition.new(1, 1, 0)
      local at_end = source.SourcePosition.new(1, 10, 9)

      assert.is_true(span:contains(inside))
      assert.is_false(span:contains(outside))
      assert.is_true(span:contains(at_start))
      assert.is_true(span:contains(at_end))
    end)

    it("should calculate length", function()
      local span = source.SourceSpan.new(
        source.SourcePosition.new(1, 1, 0),
        source.SourcePosition.new(1, 10, 9)
      )

      assert.are.equal(9, span:length())
    end)

    it("should have string representation", function()
      local span = source.SourceSpan.new(
        source.SourcePosition.new(1, 1, 0),
        source.SourcePosition.new(1, 10, 9)
      )

      assert.are.equal("1:1-1:10", tostring(span))
    end)
  end)

  describe("SourceLocation", function()
    it("should create with path and span", function()
      local span = source.SourceSpan.new(
        source.SourcePosition.new(5, 10, 50)
      )
      local loc = source.SourceLocation.new("test.wsk", span)

      assert.are.equal("test.wsk", loc.path)
      assert.are.equal(5, loc.span.start.line)
    end)

    it("should default path to <unknown>", function()
      local span = source.SourceSpan.new(source.SourcePosition.new())
      local loc = source.SourceLocation.new(nil, span)

      assert.are.equal("<unknown>", loc.path)
    end)

    it("should have string representation", function()
      local span = source.SourceSpan.new(
        source.SourcePosition.new(5, 10, 50)
      )
      local loc = source.SourceLocation.new("story.wsk", span)

      assert.are.equal("story.wsk:5:10", tostring(loc))
    end)
  end)

  describe("SourceFile", function()
    it("should create with path and content", function()
      local sf = source.SourceFile.new("test.wsk", "hello\nworld")
      assert.are.equal("test.wsk", sf.path)
      assert.are.equal("hello\nworld", sf.content)
    end)

    it("should default path to <unknown>", function()
      local sf = source.SourceFile.new(nil, "content")
      assert.are.equal("<unknown>", sf.path)
    end)

    it("should get single line", function()
      local sf = source.SourceFile.new("test.wsk", "line one\nline two\nline three")
      assert.are.equal("line one", sf:get_line(1))
      assert.are.equal("line two", sf:get_line(2))
      assert.are.equal("line three", sf:get_line(3))
    end)

    it("should return nil for out of range lines", function()
      local sf = source.SourceFile.new("test.wsk", "one\ntwo")
      assert.is_nil(sf:get_line(0))
      assert.is_nil(sf:get_line(4))
    end)

    it("should handle empty content", function()
      local sf = source.SourceFile.new("test.wsk", "")
      assert.is_nil(sf:get_line(1))
      assert.are.equal(0, sf:line_count())
    end)

    it("should handle single line without newline", function()
      local sf = source.SourceFile.new("test.wsk", "single line")
      assert.are.equal("single line", sf:get_line(1))
      assert.are.equal(1, sf:line_count())
    end)

    it("should handle trailing newline", function()
      local sf = source.SourceFile.new("test.wsk", "line\n")
      assert.are.equal("line", sf:get_line(1))
      assert.are.equal("", sf:get_line(2))
      assert.are.equal(2, sf:line_count())
    end)

    it("should handle empty lines", function()
      local sf = source.SourceFile.new("test.wsk", "a\n\nb")
      assert.are.equal("a", sf:get_line(1))
      assert.are.equal("", sf:get_line(2))
      assert.are.equal("b", sf:get_line(3))
    end)

    it("should get context around position", function()
      local content = "line 1\nline 2\nline 3\nline 4\nline 5"
      local sf = source.SourceFile.new("test.wsk", content)
      local pos = source.SourcePosition.new(3, 1, 14)

      local ctx = sf:get_context(pos, 1)
      assert.are.equal(3, #ctx)
      assert.are.equal(2, ctx[1].line_number)
      assert.are.equal("line 2", ctx[1].content)
      assert.are.equal(3, ctx[2].line_number)
      assert.are.equal("line 3", ctx[2].content)
      assert.are.equal(4, ctx[3].line_number)
      assert.are.equal("line 4", ctx[3].content)
    end)

    it("should clamp context at file boundaries", function()
      local sf = source.SourceFile.new("test.wsk", "one\ntwo\nthree")
      local pos = source.SourcePosition.new(1, 1, 0)

      local ctx = sf:get_context(pos, 5)
      assert.are.equal(3, #ctx)
      assert.are.equal(1, ctx[1].line_number)
    end)

    it("should report line count", function()
      local sf = source.SourceFile.new("test.wsk", "a\nb\nc\nd")
      assert.are.equal(4, sf:line_count())
    end)
  end)

  describe("format_source_snippet()", function()
    it("should format simple snippet", function()
      local sf = source.SourceFile.new("story.wsk", ":: Start\nHello, World!")
      local span = source.SourceSpan.new(
        source.SourcePosition.new(1, 4, 3),
        source.SourcePosition.new(1, 9, 8)
      )

      local snippet = source.format_source_snippet(sf, span, "passage name here")

      assert.truthy(snippet:match("story.wsk:1:4"))
      assert.truthy(snippet:match(":: Start"))
      assert.truthy(snippet:match("%^+"))
      assert.truthy(snippet:match("passage name here"))
    end)

    it("should format snippet without message", function()
      local sf = source.SourceFile.new("test.wsk", "content")
      local span = source.SourceSpan.new(
        source.SourcePosition.new(1, 1, 0),
        source.SourcePosition.new(1, 4, 3)
      )

      local snippet = source.format_source_snippet(sf, span, nil)
      assert.truthy(snippet:match("%^%^%^"))
    end)

    it("should handle unavailable line gracefully", function()
      local sf = source.SourceFile.new("test.wsk", "")
      local span = source.SourceSpan.new(
        source.SourcePosition.new(5, 1, 100)
      )

      local snippet = source.format_source_snippet(sf, span, "error")
      assert.truthy(snippet:match("line not available"))
    end)

    it("should underline single character", function()
      local sf = source.SourceFile.new("test.wsk", "abc")
      local span = source.SourceSpan.new(
        source.SourcePosition.new(1, 2, 1),
        source.SourcePosition.new(1, 2, 1)
      )

      local snippet = source.format_source_snippet(sf, span, "here")
      -- Should have at least one caret
      assert.truthy(snippet:match("%^"))
    end)
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(source._whisker)
      assert.are.equal("script.source", source._whisker.name)
      assert.is_string(source._whisker.version)
    end)
  end)
end)
