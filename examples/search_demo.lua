#!/usr/bin/env lua
--[[
  Full-Text Search Demo
  
  This example demonstrates whisker-core's powerful full-text search engine.
  
  Features demonstrated:
  - Story indexing
  - Multi-field search (title, author, tags, content)
  - Ranked results with relevance scoring
  - Match highlighting
  - Context excerpts
  - Search statistics
  
  Usage:
    lua examples/search_demo.lua
]]

-- Add lib directory to package path
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local SearchEngine = require("whisker.search.engine")
local Story = require("whisker.core.story")

--[[
  Create Sample Stories for Demonstration
]]
local function create_sample_stories()
  local stories = {}
  
  -- Story 1: Mystery
  table.insert(stories, {
    metadata = {
      id = "mystery_mansion",
      title = "The Mysterious Mansion",
      author = "Detective Writer",
      description = "A classic detective mystery set in an old mansion",
      tags = {"mystery", "detective", "mansion", "suspense"}
    },
    passages = {
      {
        id = "start",
        text = "You arrive at the old mansion on a dark and stormy night. The detective inside you knows something is wrong. The front door creaks open.",
        choices = {
          { text = "Enter the mansion", target = "entrance" },
          { text = "Investigate the grounds", target = "grounds" }
        }
      },
      {
        id = "entrance",
        text = "The entrance hall is dimly lit. A portrait of the old detective hangs on the wall, his eyes seeming to follow you. You notice a mysterious key on the table.",
        choices = {
          { text = "Take the key", target = "library" },
          { text = "Examine the portrait", target = "secret" }
        }
      },
      {
        id = "library",
        text = "The library contains countless ancient books about famous detectives and unsolved mysteries. A secret passage opens behind a bookshelf.",
        choices = {}
      }
    },
    start_passage = "start"
  })
  
  -- Story 2: Sci-Fi Adventure
  table.insert(stories, {
    metadata = {
      id = "space_explorer",
      title = "Space Explorer: The Quest for Earth",
      author = "Sci-Fi Master",
      description = "An epic journey through space to find a new home",
      tags = {"sci-fi", "space", "adventure", "exploration"}
    },
    passages = {
      {
        id = "start",
        text = "Your spaceship orbits a mysterious planet. Sensors detect unusual energy readings. As the ship's explorer, you must decide your next move.",
        choices = {
          { text = "Land on the planet", target = "surface" },
          { text = "Scan from orbit", target = "scan" }
        }
      },
      {
        id = "surface",
        text = "The planet's surface is covered in ancient ruins. Your explorer equipment detects technology far beyond Earth's capabilities. This could change everything.",
        choices = {
          { text = "Investigate the ruins", target = "ruins" },
          { text = "Return to ship", target = "ship" }
        }
      },
      {
        id = "ruins",
        text = "Inside the ruins, you discover a message from an ancient civilization. They were explorers too, searching for a new home among the stars.",
        choices = {}
      }
    },
    start_passage = "start"
  })
  
  -- Story 3: Fantasy Quest
  table.insert(stories, {
    metadata = {
      id = "dragon_quest",
      title = "The Dragon's Quest",
      author = "Fantasy Weaver",
      description = "A hero's journey to save the kingdom from darkness",
      tags = {"fantasy", "dragon", "quest", "magic"}
    },
    passages = {
      {
        id = "start",
        text = "The wise dragon speaks: 'Young hero, the kingdom needs you. A dark force threatens our land. Will you accept this quest?'",
        choices = {
          { text = "Accept the quest", target = "journey" },
          { text = "Ask for more information", target = "info" }
        }
      },
      {
        id = "journey",
        text = "Your quest begins in the enchanted forest. Magic swirls around you as the dragon's blessing guides your path. Ancient trees whisper secrets.",
        choices = {
          { text = "Follow the whispers", target = "temple" },
          { text = "Forge ahead", target = "battle" }
        }
      },
      {
        id = "temple",
        text = "You discover an ancient temple. The dragon's spirit appears, revealing the true nature of your quest and the power you possess.",
        choices = {}
      }
    },
    start_passage = "start"
  })
  
  -- Story 4: Romance
  table.insert(stories, {
    metadata = {
      id = "cafe_romance",
      title = "Coffee Shop Love Story",
      author = "Romance Author",
      description = "A heartwarming tale of unexpected love",
      tags = {"romance", "contemporary", "coffee", "love"}
    },
    passages = {
      {
        id = "start",
        text = "You walk into your favorite coffee shop and notice someone new behind the counter. They smile at you, and your heart skips a beat.",
        choices = {
          { text = "Order your usual", target = "order" },
          { text = "Try something new", target = "adventurous" }
        }
      },
      {
        id = "order",
        text = "They remember your order perfectly, even though it's your first time seeing them. 'I've been watching,' they say with a wink. Your heart races.",
        choices = {
          { text = "Start a conversation", target = "talk" },
          { text = "Just smile and leave", target = "shy" }
        }
      },
      {
        id = "talk",
        text = "The conversation flows naturally, like you've known each other forever. This coffee shop might just have become your favorite place for a new reason.",
        choices = {}
      }
    },
    start_passage = "start"
  })
  
  return stories
end

--[[
  Convert story data to Story objects
]]
local function create_story_objects(story_data_list)
  local stories = {}
  
  for _, data in ipairs(story_data_list) do
    local story = Story.from_table(data)
    table.insert(stories, story)
  end
  
  return stories
end

--[[
  Index all stories
]]
local function index_stories(search_engine, stories)
  print("📚 Indexing Stories...")
  print("")
  
  for i, story in ipairs(stories) do
    print(string.format("   %d. Indexing '%s' by %s", 
      i, 
      story.metadata.title, 
      story.metadata.author))
    
    search_engine:index_story(story)
  end
  
  print("")
  
  -- Display index stats
  local stats = search_engine:get_stats()
  print("✅ Indexing Complete!")
  print(string.format("   Indexed Words: %d", stats.indexed_words))
  print(string.format("   Indexed Stories: %d", stats.indexed_stories))
  print("")
end

--[[
  Display search results
]]
local function display_results(results, query)
  if #results == 0 then
    print("   No results found.")
    print("")
    return
  end
  
  for i, result in ipairs(results) do
    print(string.format("%d. %s (Score: %.2f)", 
      i, 
      result.story.metadata.title,
      result.score))
    
    print(string.format("   Author: %s", result.story.metadata.author))
    print(string.format("   Matched: %s", table.concat(result.matched_words, ", ")))
    
    -- Display highlights
    if #result.highlight > 0 then
      print("   Excerpts:")
      for j = 1, math.min(3, #result.highlight) do
        local excerpt = result.highlight[j]
        print(string.format("     - [%s] %s", excerpt.field, excerpt.text))
      end
    end
    
    print("")
  end
end

--[[
  Perform search demonstrations
]]
local function demo_searches(search_engine)
  print("=" .. string.rep("=", 70))
  print("  Search Demonstrations")
  print("=" .. string.rep("=", 70))
  print("")
  
  -- Demo 1: Genre search
  print("🔍 Search 1: Find mystery stories")
  print("   Query: 'mystery detective'")
  print("")
  
  local results = search_engine:search("mystery detective", { limit = 10 })
  display_results(results, "mystery detective")
  
  -- Demo 2: Theme search
  print("🔍 Search 2: Find stories about exploration")
  print("   Query: 'explorer space'")
  print("")
  
  results = search_engine:search("explorer space", { limit = 10 })
  display_results(results, "explorer space")
  
  -- Demo 3: Specific content
  print("🔍 Search 3: Find stories with dragons")
  print("   Query: 'dragon quest magic'")
  print("")
  
  results = search_engine:search("dragon quest magic", { limit = 10 })
  display_results(results, "dragon quest magic")
  
  -- Demo 4: Romance genre
  print("🔍 Search 4: Find romance stories")
  print("   Query: 'love heart romance'")
  print("")
  
  results = search_engine:search("love heart romance", { limit = 10 })
  display_results(results, "love heart romance")
  
  -- Demo 5: Minimum score filter
  print("🔍 Search 5: High-relevance detective stories only")
  print("   Query: 'detective' (min_score: 5.0)")
  print("")
  
  results = search_engine:search("detective", { 
    limit = 10,
    min_score = 5.0 
  })
  display_results(results, "detective")
  
  -- Demo 6: Broad search
  print("🔍 Search 6: Find any adventure")
  print("   Query: 'adventure journey'")
  print("")
  
  results = search_engine:search("adventure journey", { limit = 10 })
  display_results(results, "adventure journey")
end

--[[
  Interactive search mode
]]
local function interactive_search(search_engine)
  print("=" .. string.rep("=", 70))
  print("  Interactive Search Mode")
  print("=" .. string.rep("=", 70))
  print("")
  print("Enter search queries (or 'quit' to exit):")
  print("")
  
  while true do
    io.write("Search > ")
    io.flush()
    
    local query = io.read("*line")
    
    if not query or query:lower() == "quit" or query:lower() == "exit" then
      print("Exiting interactive mode.")
      break
    end
    
    repeat
      if query:match("^%s*$") then
        print("Please enter a search query.")
        print("")
        break
      end

      print("")
      local results = search_engine:search(query, { limit = 5 })
      display_results(results, query)
    until true
  end
  
  print("")
end

--[[
  Demonstrate search features
]]
local function demo_search_features(search_engine, stories)
  print("=" .. string.rep("=", 70))
  print("  Advanced Search Features")
  print("=" .. string.rep("=", 70))
  print("")
  
  -- Feature 1: Field weighting
  print("📊 Feature 1: Field Weighting")
  print("   - Title matches are weighted 10x")
  print("   - Author matches are weighted 5x")
  print("   - Tag matches are weighted 3x")
  print("   - Content matches are weighted 1x")
  print("")
  
  local results = search_engine:search("mansion", { limit = 3 })
  print("   Search: 'mansion'")
  for i, result in ipairs(results) do
    print(string.format("   %d. %s (Score: %.2f)", 
      i, result.story.metadata.title, result.score))
  end
  print("")
  
  -- Feature 2: Stop words
  print("📊 Feature 2: Stop Word Filtering")
  print("   Common words (the, a, and, etc.) are ignored")
  print("")
  
  results = search_engine:search("the mysterious and dark", { limit = 3 })
  print("   Search: 'the mysterious and dark'")
  print("   Processed: 'mysterious dark' (stop words removed)")
  for i, result in ipairs(results) do
    print(string.format("   %d. %s", i, result.story.metadata.title))
  end
  print("")
  
  -- Feature 3: Match highlighting
  print("📊 Feature 3: Match Highlighting")
  print("   Matched words are highlighted with **asterisks**")
  print("")
  
  results = search_engine:search("ancient", { limit = 1 })
  if #results > 0 then
    print("   Search: 'ancient'")
    print("   Highlights:")
    for _, highlight in ipairs(results[1].highlight) do
      if highlight.text:match("%*%*") then
        print("   - " .. highlight.text)
      end
    end
  end
  print("")
  
  -- Feature 4: Statistics
  print("📊 Feature 4: Search Statistics")
  local stats = search_engine:get_stats()
  print(string.format("   Indexed Words: %d unique words", stats.indexed_words))
  print(string.format("   Indexed Stories: %d stories", stats.indexed_stories))
  print("")
end

--[[
  Main function
]]
local function main()
  print("=" .. string.rep("=", 70))
  print("  Whisker-Core Full-Text Search Demo")
  print("=" .. string.rep("=", 70))
  print("")
  
  -- Initialize search engine
  print("🔧 Initializing Search Engine...")
  local search_engine = SearchEngine.new({
    case_sensitive = false,
    min_word_length = 2
  })
  print("✅ Search Engine Ready!")
  print("")
  
  -- Create sample stories
  print("📝 Creating Sample Stories...")
  local story_data = create_sample_stories()
  local stories = create_story_objects(story_data)
  print(string.format("✅ Created %d sample stories", #stories))
  print("")
  
  -- Index stories
  index_stories(search_engine, stories)
  
  -- Run demonstrations
  demo_search_features(search_engine, stories)
  demo_searches(search_engine)
  
  -- Interactive mode (optional)
  if os.getenv("INTERACTIVE") == "1" then
    interactive_search(search_engine)
  else
    print("ℹ️  Run with INTERACTIVE=1 for interactive search mode")
    print("")
  end
  
  print("=" .. string.rep("=", 70))
  print("  Demo Complete!")
  print("=" .. string.rep("=", 70))
  print("")
  print("Key Features Demonstrated:")
  print("  ✓ Multi-field search (title, author, tags, content)")
  print("  ✓ Relevance scoring and ranking")
  print("  ✓ Match highlighting")
  print("  ✓ Context excerpts")
  print("  ✓ Stop word filtering")
  print("  ✓ Configurable result limits")
  print("  ✓ Minimum score filtering")
  print("")
  print("Try it yourself:")
  print("  INTERACTIVE=1 lua examples/search_demo.lua")
  print("")
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("search_demo%.lua$") then
  main()
end

return {
  create_sample_stories = create_sample_stories,
  create_story_objects = create_story_objects,
  index_stories = index_stories,
  display_results = display_results
}
