--- Large Story Integration Tests
-- Tests for handling stories with many passages
-- @module tests.integration.large_story_spec

describe("Large Story Handling", function()
  local LargeStoryGenerator

  before_each(function()
    LargeStoryGenerator = require("tools.generate_large_story")
  end)

  describe("story generation", function()
    it("generates stories with correct passage count", function()
      local story = LargeStoryGenerator.generate(100, { seed = 1234 })
      assert.equals(100, #story.passages)
    end)

    it("generates passage map for O(1) lookup", function()
      local story = LargeStoryGenerator.generate(50, { seed = 1234 })
      assert.is_table(story.passage_map)
      assert.equals(50, #story.passages)

      -- Verify map entries
      for _, passage in ipairs(story.passages) do
        assert.equals(passage, story.passage_map[passage.name])
      end
    end)

    it("generates choices that reference valid passages", function()
      local story = LargeStoryGenerator.generate(100, { seed = 1234 })

      for _, passage in ipairs(story.passages) do
        for _, choice in ipairs(passage.choices) do
          assert.is_not_nil(story.passage_map[choice.target],
            "Invalid target: " .. choice.target)
        end
      end
    end)
  end)

  describe("100 passage story", function()
    local story

    before_each(function()
      story = LargeStoryGenerator.generate(100, { seed = 1234 })
    end)

    it("loads within time limit", function()
      local start = os.clock()

      -- Simulate loading by building passage map
      local map = {}
      for _, passage in ipairs(story.passages) do
        map[passage.name] = passage
      end

      local elapsed = os.clock() - start
      assert.truthy(elapsed < 0.1, "Loading took " .. elapsed .. "s")
    end)

    it("finds passages quickly via hash table", function()
      local start = os.clock()

      for i = 1, 1000 do
        local name = "passage_" .. ((i % 100) + 1)
        local passage = story.passage_map[name]
        assert.is_not_nil(passage)
      end

      local elapsed = os.clock() - start
      assert.truthy(elapsed < 0.01, "1000 lookups took " .. elapsed .. "s")
    end)
  end)

  describe("500 passage story", function()
    local story

    before_each(function()
      story = LargeStoryGenerator.generate(500, { seed = 1234 })
    end)

    it("handles medium-sized story", function()
      assert.equals(500, #story.passages)
      assert.is_not_nil(story.passage_map["passage_1"])
      assert.is_not_nil(story.passage_map["passage_250"])
      assert.is_not_nil(story.passage_map["passage_500"])
    end)

    it("traverses story efficiently", function()
      local start = os.clock()
      local visited = {}
      local current = story.passage_map["passage_1"]

      for i = 1, 100 do
        visited[current.name] = true
        if current.choices and #current.choices > 0 then
          local next_name = current.choices[1].target
          current = story.passage_map[next_name]
        end
      end

      local elapsed = os.clock() - start
      assert.truthy(elapsed < 0.01, "100 traversals took " .. elapsed .. "s")
    end)
  end)

  describe("1000 passage story", function()
    local story

    before_each(function()
      story = LargeStoryGenerator.generate(1000, {
        seed = 1234,
        add_tags = true,
      })
    end)

    it("handles large story", function()
      assert.equals(1000, #story.passages)
    end)

    it("lookup remains O(1)", function()
      -- Measure lookup time for first, middle, last passage
      local lookups = {"passage_1", "passage_500", "passage_1000"}
      local times = {}

      for _, name in ipairs(lookups) do
        local start = os.clock()
        for i = 1, 10000 do
          local _ = story.passage_map[name]
        end
        times[name] = os.clock() - start
      end

      -- All lookup times should be similar (O(1) characteristic)
      local max_ratio = times["passage_1000"] / times["passage_1"]
      assert.truthy(max_ratio < 2, "Lookup time varies too much: " .. max_ratio)
    end)

    it("exports to text format", function()
      local TextExporter = require("whisker.export.text.text_exporter")
      local exporter = TextExporter.new()

      local start = os.clock()
      local bundle = exporter:export(story, {})
      local elapsed = os.clock() - start

      assert.is_not_nil(bundle.content)
      assert.truthy(#bundle.content > 0)
      assert.truthy(elapsed < 2, "Export took " .. elapsed .. "s")
    end)

    it("exports to HTML format", function()
      local HTMLExporter = require("whisker.export.html.html_exporter")
      local exporter = HTMLExporter.new()

      local start = os.clock()
      local bundle = exporter:export(story, {})
      local elapsed = os.clock() - start

      -- Validate the bundle
      local validation = exporter:validate(bundle)
      assert.is_true(validation.valid)
      assert.truthy(elapsed < 5, "Export took " .. elapsed .. "s")
    end)
  end)

  describe("5000 passage story", function()
    it("handles extreme size", function()
      local story = LargeStoryGenerator.generate(5000, { seed = 1234 })

      assert.equals(5000, #story.passages)
      assert.is_not_nil(story.passage_map["passage_1"])
      assert.is_not_nil(story.passage_map["passage_2500"])
      assert.is_not_nil(story.passage_map["passage_5000"])
    end)

    it("memory usage is reasonable", function()
      collectgarbage("collect")
      local before = collectgarbage("count")

      local story = LargeStoryGenerator.generate(5000, { seed = 1234 })

      collectgarbage("collect")
      local after = collectgarbage("count")

      local memory_used_mb = (after - before) / 1024
      assert.truthy(memory_used_mb < 50,
        "Memory usage too high: " .. memory_used_mb .. " MB")

      -- Keep reference to prevent GC
      assert.equals(5000, #story.passages)
    end)
  end)

  describe("story statistics", function()
    it("calculates correct stats", function()
      local story = LargeStoryGenerator.generate(100, {
        seed = 1234,
        text_length = "medium",
      })

      local stats = LargeStoryGenerator.stats(story)

      assert.equals(100, stats.passage_count)
      assert.truthy(stats.total_text_bytes > 0)
      assert.truthy(stats.avg_text_bytes > 0)
      assert.truthy(stats.total_choices > 0)
      assert.truthy(stats.avg_choices > 0)
    end)
  end)
end)
