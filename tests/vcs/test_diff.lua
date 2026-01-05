--- VCS Diff Module Tests
-- Unit tests for the story diff algorithm
-- @module tests.vcs.test_diff

local helper = require("tests.test_helper")
local diff = require("whisker.vcs.diff")

describe("VCS Diff Module", function()
  describe("_count_words", function()
    it("should count words in simple text", function()
      assert.equals(4, diff._count_words("Hello world foo bar"))
    end)

    it("should handle empty string", function()
      assert.equals(0, diff._count_words(""))
    end)

    it("should handle nil", function()
      assert.equals(0, diff._count_words(nil))
    end)

    it("should handle multiple spaces", function()
      assert.equals(3, diff._count_words("one   two    three"))
    end)

    it("should handle newlines", function()
      assert.equals(4, diff._count_words("one\ntwo\nthree four"))
    end)
  end)

  describe("_calculate_stats", function()
    it("should calculate stats for empty story", function()
      local stats = diff._calculate_stats({})
      assert.equals(0, stats.passage_count)
      assert.equals(0, stats.variable_count)
      assert.equals(0, stats.total_words)
      assert.equals(0, stats.total_choices)
    end)

    it("should count passages", function()
      local story = {
        passages = {
          p1 = { content = "Hello world", choices = {} },
          p2 = { content = "Goodbye", choices = {} },
        },
      }
      local stats = diff._calculate_stats(story)
      assert.equals(2, stats.passage_count)
    end)

    it("should count words", function()
      local story = {
        passages = {
          p1 = { content = "Hello world foo bar", choices = {} },
          p2 = { content = "One two three", choices = {} },
        },
      }
      local stats = diff._calculate_stats(story)
      assert.equals(7, stats.total_words)
    end)

    it("should count choices", function()
      local story = {
        passages = {
          p1 = {
            content = "Text",
            choices = {
              { id = "c1", text = "Choice 1" },
              { id = "c2", text = "Choice 2" },
            },
          },
        },
      }
      local stats = diff._calculate_stats(story)
      assert.equals(2, stats.total_choices)
    end)

    it("should count variables", function()
      local story = {
        passages = {},
        variables = {
          gold = { type = "number", initial = 0 },
          name = { type = "string", initial = "" },
        },
      }
      local stats = diff._calculate_stats(story)
      assert.equals(2, stats.variable_count)
    end)
  end)

  describe("_normalize_whitespace", function()
    it("should normalize multiple spaces", function()
      assert.equals("a b c", diff._normalize_whitespace("a   b    c"))
    end)

    it("should trim leading and trailing whitespace", function()
      assert.equals("hello", diff._normalize_whitespace("  hello  "))
    end)

    it("should handle nil", function()
      assert.equals("", diff._normalize_whitespace(nil))
    end)
  end)

  describe("_diff_metadata", function()
    it("should detect title changes", function()
      local base = { title = "Old Title" }
      local modified = { title = "New Title" }
      local changes = diff._diff_metadata(base, modified)

      assert.equals(1, #changes)
      assert.equals("title", changes[1].field)
      assert.equals("Old Title", changes[1].old_value)
      assert.equals("New Title", changes[1].new_value)
    end)

    it("should detect author changes", function()
      local base = { author = "Author A" }
      local modified = { author = "Author B" }
      local changes = diff._diff_metadata(base, modified)

      assert.equals(1, #changes)
      assert.equals("author", changes[1].field)
    end)

    it("should detect tag changes", function()
      local base = { tags = { "fantasy" } }
      local modified = { tags = { "fantasy", "adventure" } }
      local changes = diff._diff_metadata(base, modified)

      assert.equals(1, #changes)
      assert.equals("tags", changes[1].field)
    end)

    it("should return empty for identical metadata", function()
      local meta = { title = "Story", author = "Author" }
      local changes = diff._diff_metadata(meta, meta)
      assert.equals(0, #changes)
    end)
  end)

  describe("_diff_choice_fields", function()
    it("should detect text changes", function()
      local base = { text = "Go left", target = "left" }
      local modified = { text = "Turn left", target = "left" }
      local changes = diff._diff_choice_fields(base, modified)

      assert.equals(1, #changes)
      assert.equals("text", changes[1].field)
    end)

    it("should detect target changes", function()
      local base = { text = "Go", target = "room1" }
      local modified = { text = "Go", target = "room2" }
      local changes = diff._diff_choice_fields(base, modified)

      assert.equals(1, #changes)
      assert.equals("target", changes[1].field)
    end)

    it("should detect condition changes", function()
      local base = { text = "Go", target = "t", condition = "hasKey" }
      local modified = { text = "Go", target = "t", condition = "hasKey and hasTorch" }
      local changes = diff._diff_choice_fields(base, modified)

      assert.equals(1, #changes)
      assert.equals("condition", changes[1].field)
    end)
  end)

  describe("diff_stories", function()
    local base_story

    before_each(function()
      base_story = {
        metadata = { title = "Test Story", author = "Author" },
        passages = {
          start = {
            id = "start",
            title = "Start",
            content = "Beginning of story",
            choices = { { id = "c1", text = "Continue", target = "end" } },
          },
        },
        variables = {
          score = { type = "number", initial = 0 },
        },
        settings = { theme = "dark" },
      }
    end)

    it("should return no changes for identical stories", function()
      local result = diff.diff_stories(base_story, base_story)

      assert.is_false(result.has_changes)
      assert.equals(0, result.summary.passages_added)
      assert.equals(0, result.summary.passages_removed)
      assert.equals(0, result.summary.passages_modified)
    end)

    it("should detect added passages", function()
      local modified = {
        metadata = base_story.metadata,
        passages = {
          start = base_story.passages.start,
          new_passage = { id = "new", title = "New", content = "New content", choices = {} },
        },
        variables = base_story.variables,
        settings = base_story.settings,
      }

      local result = diff.diff_stories(base_story, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.passages_added)
    end)

    it("should detect removed passages", function()
      local modified = {
        metadata = base_story.metadata,
        passages = {},
        variables = base_story.variables,
        settings = base_story.settings,
      }

      local result = diff.diff_stories(base_story, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.passages_removed)
    end)

    it("should detect modified passages", function()
      local modified = {
        metadata = base_story.metadata,
        passages = {
          start = {
            id = "start",
            title = "Start",
            content = "Modified content",
            choices = base_story.passages.start.choices,
          },
        },
        variables = base_story.variables,
        settings = base_story.settings,
      }

      local result = diff.diff_stories(base_story, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.passages_modified)
    end)

    it("should include statistics", function()
      local result = diff.diff_stories(base_story, base_story)

      assert.equals(1, result.base_stats.passage_count)
      assert.equals(1, result.base_stats.variable_count)
      assert.is_true(result.base_stats.total_words > 0)
      assert.equals(1, result.base_stats.total_choices)
    end)

    it("should ignore positions by default", function()
      local modified = {
        metadata = base_story.metadata,
        passages = {
          start = {
            id = "start",
            title = "Start",
            content = "Beginning of story",
            choices = base_story.passages.start.choices,
            position = { x = 999, y = 999 },
          },
        },
        variables = base_story.variables,
        settings = base_story.settings,
      }

      local result = diff.diff_stories(base_story, modified)

      assert.is_false(result.has_changes)
    end)

    it("should detect positions when ignore_positions is false", function()
      base_story.passages.start.position = { x = 0, y = 0 }
      local modified = {
        metadata = base_story.metadata,
        passages = {
          start = {
            id = "start",
            title = "Start",
            content = "Beginning of story",
            choices = base_story.passages.start.choices,
            position = { x = 999, y = 999 },
          },
        },
        variables = base_story.variables,
        settings = base_story.settings,
      }

      local result = diff.diff_stories(base_story, modified, { ignore_positions = false })

      assert.is_true(result.has_changes)
    end)
  end)

  describe("format_diff", function()
    it("should produce no changes message for identical stories", function()
      local result = diff.diff_stories({}, {})
      local output = diff.format_diff(result)

      assert.is_string(output)
      assert.truthy(output:find("No changes detected"))
    end)

    it("should produce summary output", function()
      local result = {
        has_changes = true,
        summary = {
          passages_added = 2,
          passages_removed = 1,
          passages_modified = 3,
          variables_added = 1,
          variables_removed = 0,
          variables_modified = 0,
          choices_added = 2,
          choices_removed = 0,
          choices_modified = 1,
        },
        metadata_changes = {},
        passage_changes = {},
        variable_changes = {},
        settings_changes = {},
      }
      local output = diff.format_diff(result)

      assert.truthy(output:find("Story Diff Summary"))
      assert.truthy(output:find("Passages"))
    end)
  end)

  describe("get_summary", function()
    it("should return 'No changes' for no changes", function()
      local result = {
        summary = {
          passages_added = 0,
          passages_removed = 0,
          passages_modified = 0,
          variables_added = 0,
          variables_removed = 0,
          variables_modified = 0,
        },
      }
      assert.equals("No changes", diff.get_summary(result))
    end)

    it("should describe passage additions", function()
      local result = {
        summary = {
          passages_added = 3,
          passages_removed = 0,
          passages_modified = 0,
          variables_added = 0,
          variables_removed = 0,
          variables_modified = 0,
        },
      }
      assert.truthy(diff.get_summary(result):find("added 3 passages"))
    end)

    it("should describe passage removals", function()
      local result = {
        summary = {
          passages_added = 0,
          passages_removed = 2,
          passages_modified = 0,
          variables_added = 0,
          variables_removed = 0,
          variables_modified = 0,
        },
      }
      assert.truthy(diff.get_summary(result):find("removed 2 passages"))
    end)

    it("should combine multiple changes", function()
      local result = {
        summary = {
          passages_added = 1,
          passages_removed = 1,
          passages_modified = 1,
          variables_added = 1,
          variables_removed = 0,
          variables_modified = 0,
        },
      }
      local summary = diff.get_summary(result)
      assert.truthy(summary:find("added 1 passage"))
      assert.truthy(summary:find("removed 1 passage"))
      assert.truthy(summary:find("modified 1 passage"))
      assert.truthy(summary:find("variable change"))
    end)
  end)
end)
