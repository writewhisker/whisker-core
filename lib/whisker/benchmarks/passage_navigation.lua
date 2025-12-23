--- Passage Navigation Benchmarks
-- Benchmarks for story passage operations
-- @module whisker.benchmarks.passage_navigation
-- @author Whisker Core Team
-- @license MIT

local BenchmarkSuite = require("whisker.benchmarks.suite")

local suite = BenchmarkSuite.new("Passage Navigation")

-- Test data: stories of various sizes
local small_story, medium_story, large_story

--- Setup: Create test stories
local function setup_stories()
  -- Small story (10 passages)
  small_story = { passages = {}, passage_map = {} }
  for i = 1, 10 do
    local passage = {
      name = "passage_" .. i,
      text = "Test passage " .. i .. " with some content.",
      choices = {
        { text = "Go to next", target = "passage_" .. ((i % 10) + 1) },
      },
    }
    table.insert(small_story.passages, passage)
    small_story.passage_map[passage.name] = passage
  end

  -- Medium story (100 passages)
  medium_story = { passages = {}, passage_map = {} }
  for i = 1, 100 do
    local passage = {
      name = "passage_" .. i,
      text = string.rep("Lorem ipsum dolor sit amet. ", 5),
      choices = {},
    }
    -- Add 3 choices
    for j = 1, 3 do
      local target_idx = ((i + j - 1) % 100) + 1
      table.insert(passage.choices, {
        text = "Choice " .. j,
        target = "passage_" .. target_idx,
      })
    end
    table.insert(medium_story.passages, passage)
    medium_story.passage_map[passage.name] = passage
  end

  -- Large story (1000 passages)
  large_story = { passages = {}, passage_map = {} }
  for i = 1, 1000 do
    local passage = {
      name = "passage_" .. i,
      text = string.rep("Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", 3),
      tags = { "tag1", "tag2" },
      choices = {},
    }
    -- Add 5 choices
    for j = 1, 5 do
      local target_idx = ((i + j * 100 - 1) % 1000) + 1
      table.insert(passage.choices, {
        text = "Choice " .. j,
        target = "passage_" .. target_idx,
        condition = (j % 2 == 0) and "has_item" or nil,
      })
    end
    table.insert(large_story.passages, passage)
    large_story.passage_map[passage.name] = passage
  end
end

setup_stories()

-- Benchmark: Linear passage lookup (small story)
suite:register("linear_lookup_10", function()
  local target = "passage_5"
  for _, p in ipairs(small_story.passages) do
    if p.name == target then
      return p
    end
  end
end, {
  iterations = 10000,
  description = "Linear search through 10 passages",
})

-- Benchmark: Hash table lookup (small story)
suite:register("hash_lookup_10", function()
  return small_story.passage_map["passage_5"]
end, {
  iterations = 10000,
  description = "Hash table lookup in 10-passage story",
})

-- Benchmark: Linear passage lookup (medium story)
suite:register("linear_lookup_100", function()
  local target = "passage_50"
  for _, p in ipairs(medium_story.passages) do
    if p.name == target then
      return p
    end
  end
end, {
  iterations = 5000,
  description = "Linear search through 100 passages",
})

-- Benchmark: Hash table lookup (medium story)
suite:register("hash_lookup_100", function()
  return medium_story.passage_map["passage_50"]
end, {
  iterations = 10000,
  description = "Hash table lookup in 100-passage story",
})

-- Benchmark: Linear passage lookup (large story)
suite:register("linear_lookup_1000", function()
  local target = "passage_500"
  for _, p in ipairs(large_story.passages) do
    if p.name == target then
      return p
    end
  end
end, {
  iterations = 1000,
  description = "Linear search through 1000 passages",
})

-- Benchmark: Hash table lookup (large story)
suite:register("hash_lookup_1000", function()
  return large_story.passage_map["passage_500"]
end, {
  iterations = 10000,
  description = "Hash table lookup in 1000-passage story",
})

-- Benchmark: Choice iteration (few choices)
suite:register("choice_iteration_3", function()
  local passage = medium_story.passages[1]
  local count = 0
  for _, choice in ipairs(passage.choices) do
    count = count + 1
  end
  return count
end, {
  iterations = 10000,
  description = "Iterate 3 choices",
})

-- Benchmark: Choice iteration (many choices)
suite:register("choice_iteration_5", function()
  local passage = large_story.passages[1]
  local count = 0
  for _, choice in ipairs(passage.choices) do
    count = count + 1
  end
  return count
end, {
  iterations = 10000,
  description = "Iterate 5 choices",
})

-- Benchmark: Story traversal (10 passages)
suite:register("traversal_10", function()
  local visited = {}
  local current = small_story.passage_map["passage_1"]

  for i = 1, 10 do
    visited[current.name] = true
    if current.choices and #current.choices > 0 then
      current = small_story.passage_map[current.choices[1].target]
    end
  end

  return visited
end, {
  iterations = 1000,
  description = "Navigate through 10 passages",
})

-- Benchmark: Story traversal (50 passages)
suite:register("traversal_50", function()
  local visited = {}
  local current = medium_story.passage_map["passage_1"]

  for i = 1, 50 do
    visited[current.name] = true
    if current.choices and #current.choices > 0 then
      local next_name = current.choices[1].target
      current = medium_story.passage_map[next_name]
      if not current then break end
    end
  end

  return visited
end, {
  iterations = 500,
  description = "Navigate through 50 passages",
})

-- Benchmark: Find passage by tag
suite:register("find_by_tag", function()
  local results = {}
  for _, passage in ipairs(large_story.passages) do
    if passage.tags then
      for _, tag in ipairs(passage.tags) do
        if tag == "tag1" then
          table.insert(results, passage)
          break
        end
      end
    end
  end
  return results
end, {
  iterations = 100,
  description = "Find all passages with a specific tag",
})

return suite
