#!/usr/bin/env lua
--[[
  Search Engine Benchmarks
  
  Performance tests for the full-text search engine.
  
  Targets:
  - Index 100 stories: < 1000ms
  - Search across 100 stories: < 50ms
  - Index single story: < 10ms
  
  Usage:
    lua tests/benchmarks/search_benchmark.lua
]]

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local Benchmark = require("tests.benchmarks.benchmark_runner")
local SearchEngine = require("whisker.search.engine")
local Story = require("whisker.core.story")

-- Helper: Create test story
local function create_test_story(id, num_passages)
  local passages = {}
  
  for i = 1, num_passages do
    table.insert(passages, {
      id = "passage_" .. i,
      text = string.format(
        "This is passage %d with some detective mystery content about solving crimes in the mansion. " ..
        "The detective investigates clues and discovers secrets hidden in the ancient library.",
        i
      ),
      choices = i < num_passages and {
        { text = "Continue", target = "passage_" .. (i + 1) }
      } or {}
    })
  end
  
  return Story.from_table({
    metadata = {
      id = id or ("story_" .. math.random(10000)),
      title = "Test Story " .. (id or ""),
      author = "Benchmark Author",
      description = "A mystery detective story for benchmarking search performance",
      tags = {"mystery", "detective", "benchmark", "test"}
    },
    passages = passages,
    start_passage = "passage_1"
  })
end

-- Helper: Create multiple stories
local function create_stories(count, passages_per_story)
  local stories = {}
  for i = 1, count do
    table.insert(stories, create_test_story("bench_" .. i, passages_per_story))
  end
  return stories
end

--[[
  Run search benchmarks
]]
local function run_benchmarks()
  print("\n" .. string.rep("=", 70))
  print("  SEARCH ENGINE BENCHMARKS")
  print(string.rep("=", 70))
  print("")
  
  -- Prepare test data
  local small_stories = create_stories(10, 10)   -- 10 stories, 10 passages each
  local medium_stories = create_stories(50, 20)  -- 50 stories, 20 passages each
  local large_stories = create_stories(100, 50)  -- 100 stories, 50 passages each
  local single_story = create_test_story("single", 100)
  
  -- Define benchmarks
  local benchmarks = {
    -- Indexing benchmarks
    {
      name = "Index single story (100 passages)",
      iterations = 10,
      target = 10,  -- Target: < 10ms
      fn = function()
        local search = SearchEngine.new()
        search:index_story(single_story)
      end
    },
    
    {
      name = "Index 10 small stories (100 passages total)",
      iterations = 10,
      target = 100,  -- Target: < 100ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(small_stories) do
          search:index_story(story)
        end
      end
    },
    
    {
      name = "Index 50 medium stories (1000 passages total)",
      iterations = 5,
      target = 500,  -- Target: < 500ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(medium_stories) do
          search:index_story(story)
        end
      end
    },
    
    {
      name = "Index 100 large stories (5000 passages total)",
      iterations = 2,
      target = 2000,  -- Target: < 2s
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(large_stories) do
          search:index_story(story)
        end
      end
    },
    
    -- Search benchmarks (with pre-indexed data)
    {
      name = "Search in 10 stories (single term)",
      iterations = 100,
      target = 5,  -- Target: < 5ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(small_stories) do
          search:index_story(story)
        end
        search:search("detective", { limit = 10 })
      end
    },
    
    {
      name = "Search in 50 stories (single term)",
      iterations = 50,
      target = 20,  -- Target: < 20ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(medium_stories) do
          search:index_story(story)
        end
        search:search("mystery", { limit = 10 })
      end
    },
    
    {
      name = "Search in 100 stories (single term)",
      iterations = 20,
      target = 50,  -- Target: < 50ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(large_stories) do
          search:index_story(story)
        end
        search:search("detective", { limit = 10 })
      end
    },
    
    {
      name = "Search in 100 stories (multiple terms)",
      iterations = 20,
      target = 75,  -- Target: < 75ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(large_stories) do
          search:index_story(story)
        end
        search:search("detective mystery mansion", { limit = 10 })
      end
    },
    
    {
      name = "Search with highlighting (100 stories)",
      iterations = 20,
      target = 100,  -- Target: < 100ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(large_stories) do
          search:index_story(story)
        end
        local results = search:search("detective", { limit = 10 })
        -- Highlighting is automatic
      end
    },
    
    -- Index management benchmarks
    {
      name = "Remove story from index (100 stories)",
      iterations = 50,
      target = 5,  -- Target: < 5ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(large_stories) do
          search:index_story(story)
        end
        search:remove_story(large_stories[1].metadata.id)
      end
    },
    
    {
      name = "Clear entire index (100 stories)",
      iterations = 10,
      target = 1,  -- Target: < 1ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(large_stories) do
          search:index_story(story)
        end
        search:clear()
      end
    },
    
    {
      name = "Get index statistics (100 stories)",
      iterations = 1000,
      target = 0.1,  -- Target: < 0.1ms
      fn = function()
        local search = SearchEngine.new()
        for _, story in ipairs(small_stories) do
          search:index_story(story)
        end
        search:get_stats()
      end
    }
  }
  
  -- Run benchmarks
  local results = Benchmark.run_suite("Search Engine", benchmarks)
  
  -- Display results
  Benchmark.display_results(results)
  
  -- Save results
  Benchmark.save_results(results, "tests/benchmarks/results/search_results.json")
  
  -- Compare with baseline if exists
  Benchmark.compare_with_baseline(results, "tests/benchmarks/baseline/search_baseline.json")
  
  -- Performance summary
  print("\nPERFORMANCE SUMMARY")
  print(string.rep("=", 70))
  
  local passed = 0
  local failed = 0
  local targets = {}
  
  for i, result in ipairs(results) do
    local bench = benchmarks[i]
    if bench.target then
      if result.avg_time_ms <= bench.target then
        passed = passed + 1
        table.insert(targets, {
          name = result.name,
          status = "PASS",
          time = result.avg_time_ms,
          target = bench.target
        })
      else
        failed = failed + 1
        table.insert(targets, {
          name = result.name,
          status = "FAIL",
          time = result.avg_time_ms,
          target = bench.target
        })
      end
    end
  end
  
  for _, t in ipairs(targets) do
    local status_icon = t.status == "PASS" and "✓" or "✗"
    print(string.format("%s %-50s %7.2f ms / %7.2f ms",
      status_icon, t.name, t.time, t.target))
  end
  
  print(string.rep("=", 70))
  print(string.format("\nResults: %d passed, %d failed out of %d targets\n",
    passed, failed, passed + failed))
  
  return passed == (passed + failed)
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("search_benchmark%.lua$") then
  local success = run_benchmarks()
  os.exit(success and 0 or 1)
end

return {
  run_benchmarks = run_benchmarks,
  create_test_story = create_test_story,
  create_stories = create_stories
}
