# Getting Started with Advanced Features

**Whisker-Core 2.0 - Advanced Features Tutorial**

Learn how to use AI integration, full-text search, and real-time collaboration in your projects.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [AI-Powered Story Generation](#ai-powered-story-generation)
3. [Full-Text Search](#full-text-search)
4. [Real-Time Collaboration](#real-time-collaboration)
5. [Testing Your Stories](#testing-your-stories)
6. [Next Steps](#next-steps)

---

## Prerequisites

### Installation

```bash
cd whisker-core

# Install dependencies (if not already installed)
luarocks install lua-cjson
luarocks install luafilesystem
```

### Setup

Add whisker-core to your Lua path:

```lua
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"
```

---

## AI-Powered Story Generation

### Step 1: Initialize AI Client

```lua
local AIClient = require("whisker.ai.client")
local AITools = require("whisker.ai.tools")

-- Start with mock provider (no API key needed)
local ai = AIClient.new({
  provider = "mock",
  temperature = 0.8
})

local tools = AITools.new({ ai_client = ai })
```

### Step 2: Generate Story Outline

```lua
local outline = tools:generate_outline({
  genre = "mystery",
  themes = {"detective", "small town", "secrets"},
  passages = 10
})

print("Title:", outline.title)
print("Summary:", outline.summary)

for i, passage_desc in ipairs(outline.passages) do
  print(i, passage_desc)
end
```

**Output:**
```
Title: The Mysterious Case of Millbrook
Summary: A detective arrives in a small town...
1. Detective arrives in Millbrook...
2. Meet the suspicious mayor...
3. Discover hidden clues...
...
```

### Step 3: Generate Passage Content

```lua
local passage_text = tools:generate_passage({
  context = outline.passages[1],
  mood = "mysterious",
  length = "medium"
})

print(passage_text)
```

**Output:**
```
You arrive in Millbrook on a gray afternoon. The town square is eerily quiet,
and you notice the locals watching you from behind curtained windows. Something
here doesn't feel right...
```

### Step 4: Generate Choices

```lua
local choices = tools:generate_choices({
  passage_text = passage_text,
  num_choices = 3,
  type = "action"
})

for _, choice in ipairs(choices) do
  print("- " .. choice.text)
end
```

**Output:**
```
- Investigate the town hall
- Talk to the locals in the cafe
- Check into the hotel and rest
```

### Step 5: Use Real AI Providers

For production use, switch to real AI providers:

```lua
-- OpenAI
local ai_openai = AIClient.new({
  provider = "openai",
  api_key = os.getenv("OPENAI_API_KEY"),
  model = "gpt-4",
  temperature = 0.7
})

-- Anthropic (Claude)
local ai_claude = AIClient.new({
  provider = "anthropic",
  api_key = os.getenv("ANTHROPIC_API_KEY"),
  model = "claude-3-opus-20240229"
})

-- Ollama (Local)
local ai_local = AIClient.new({
  provider = "ollama",
  model = "llama2"
})
```

### Complete Example

```lua
-- examples/my_ai_story.lua
local AIClient = require("whisker.ai.client")
local AITools = require("whisker.ai.tools")
local Story = require("whisker.core.story")

local ai = AIClient.new({ provider = "mock" })
local tools = AITools.new({ ai_client = ai })

-- Generate outline
local outline = tools:generate_outline({
  genre = "sci-fi",
  themes = {"space", "exploration"},
  passages = 5
})

-- Create story
local story_data = {
  metadata = {
    title = outline.title,
    author = "AI Assistant",
    description = outline.summary
  },
  passages = {},
  start_passage = "start"
}

-- Generate passages
for i, desc in ipairs(outline.passages) do
  local passage_id = i == 1 and "start" or ("passage_" .. i)
  
  local text = tools:generate_passage({
    context = desc,
    mood = "adventurous"
  })
  
  local choices = {}
  if i < #outline.passages then
    choices = tools:generate_choices({
      passage_text = text,
      num_choices = 2
    })
  end
  
  table.insert(story_data.passages, {
    id = passage_id,
    text = text,
    choices = choices
  })
end

-- Save story
local json = require("cjson")
local file = io.open("generated_story.json", "w")
file:write(json.encode(story_data))
file:close()

print("Story generated and saved!")
```

---

## Full-Text Search

### Step 1: Create Search Engine

```lua
local SearchEngine = require("whisker.search.engine")
local Story = require("whisker.core.story")

local search = SearchEngine.new({
  case_sensitive = false,
  min_word_length = 2
})
```

### Step 2: Index Stories

```lua
-- Load or create stories
local story1 = Story.from_table({
  metadata = {
    id = "mystery1",
    title = "The Detective's Case",
    author = "Mystery Writer",
    tags = {"mystery", "detective"}
  },
  passages = {
    {
      id = "start",
      text = "The detective examines the crime scene carefully...",
      choices = {}
    }
  },
  start_passage = "start"
})

-- Index the story
search:index_story(story1)

-- Index multiple stories
local stories = {story1, story2, story3}
for _, story in ipairs(stories) do
  search:index_story(story)
end
```

### Step 3: Perform Searches

```lua
-- Simple search
local results = search:search("detective mystery", {
  limit = 10
})

print(string.format("Found %d results:", #results))
for _, result in ipairs(results) do
  print(string.format("  %s (Score: %.2f)", 
    result.story.metadata.title,
    result.score))
end
```

**Output:**
```
Found 3 results:
  The Detective's Case (Score: 15.50)
  Mystery Mansion (Score: 8.20)
  Crime Scene Investigation (Score: 5.10)
```

### Step 4: Use Search Results

```lua
-- Get detailed results with highlights
for _, result in ipairs(results) do
  print("\n" .. result.story.metadata.title)
  print("Matched words:", table.concat(result.matched_words, ", "))
  
  -- Show excerpts with highlights
  for _, highlight in ipairs(result.highlight) do
    print(string.format("  [%s] %s", highlight.field, highlight.text))
  end
end
```

**Output:**
```
The Detective's Case
Matched words: detective, mystery
  [title] The **Detective**'s Case
  [tags] **mystery**, **detective**
  [passage] The **detective** examines the **mystery**...
```

### Step 5: Filter and Manage Index

```lua
-- Filter by minimum score
local high_quality = search:search("detective", {
  limit = 5,
  min_score = 10.0
})

-- Get statistics
local stats = search:get_stats()
print(string.format("Indexed: %d stories, %d unique words",
  stats.indexed_stories,
  stats.indexed_words))

-- Remove a story
search:remove_story("mystery1")

-- Clear entire index
search:clear()
```

### Complete Search Application

```lua
-- examples/my_search_app.lua
local SearchEngine = require("whisker.search.engine")
local Story = require("whisker.core.story")

-- Initialize
local search = SearchEngine.new()

-- Load and index stories from files
local story_files = {"story1.json", "story2.json", "story3.json"}

for _, filename in ipairs(story_files) do
  local file = io.open(filename, "r")
  if file then
    local content = file:read("*all")
    file:close()
    
    local json = require("cjson")
    local data = json.decode(content)
    local story = Story.from_table(data)
    
    search:index_story(story)
    print("Indexed:", story.metadata.title)
  end
end

-- Interactive search
while true do
  io.write("\nSearch query (or 'quit'): ")
  local query = io.read()
  
  if query == "quit" then break end
  
  local results = search:search(query, { limit = 5 })
  
  if #results == 0 then
    print("No results found.")
  else
    for i, result in ipairs(results) do
      print(string.format("%d. %s (%.2f)", 
        i, result.story.metadata.title, result.score))
    end
  end
end
```

---

## Real-Time Collaboration

### Step 1: Understanding OT

Operational Transform allows multiple users to edit the same document concurrently without conflicts.

```lua
local OT = require("whisker.collaboration.ot")

-- User A inserts text
local opA = OT.insert(5, "hello")

-- User B inserts text (concurrent!)
local opB = OT.insert(10, "world")

-- Transform operations
local opA_transformed = OT.transform(opA, opB)
local opB_transformed = OT.transform(opB, opA)

-- Apply in any order - same result!
local text = "01234567890123456789"
local result1 = OT.apply(OT.apply(text, opA), opB_transformed)
local result2 = OT.apply(OT.apply(text, opB), opA_transformed)

assert(result1 == result2)  -- Always true!
```

### Step 2: Text Operations

```lua
local OT = require("whisker.collaboration.ot")

-- INSERT: Add text at position
local op1 = OT.insert(5, "new text")

-- DELETE: Remove characters
local op2 = OT.delete(10, 5)  -- Delete 5 chars at position 10

-- RETAIN: Keep unchanged
local op3 = OT.retain(10)  -- Keep first 10 characters
```

### Step 3: Transform and Apply

```lua
local text = "Hello world!"

-- User 1: Add comma
local op1 = OT.insert(5, ",")

-- User 2: Add exclamation (concurrent!)
local op2 = OT.insert(11, "!")

-- Transform op1 to apply after op2
local op1_prime = OT.transform(op1, op2)

-- Apply
local result = OT.apply(text, op2)
result = OT.apply(result, op1_prime)

print(result)  -- "Hello, world!!"
```

### Step 4: Story-Level Operations

```lua
local OT = require("whisker.collaboration.ot")
local Story = require("whisker.core.story")

-- Create story
local story = Story.from_table({
  metadata = { title = "Collaborative Story" },
  passages = {
    { id = "start", text = "Beginning...", choices = {} }
  },
  start_passage = "start"
})

-- User A: Add new passage
local opA = OT.StoryOT.add_passage({
  id = "middle",
  text = "Middle section...",
  choices = {}
})

-- User B: Modify existing passage (concurrent!)
local opB = OT.StoryOT.modify_passage("start", {
  text = "Updated beginning..."
})

-- Transform and apply
local opA_transformed = OT.StoryOT.transform(opA, opB)

OT.StoryOT.apply(story, opB)
OT.StoryOT.apply(story, opA_transformed)

-- Story now has both changes
```

### Complete Collaboration Example

```lua
-- Simulate two authors editing concurrently
local OT = require("whisker.collaboration.ot")

-- Initial passage text
local passage_text = "The hero enters the dark cave."

-- Author 1: Adds atmosphere
local edit1 = OT.insert(4, " brave")

-- Author 2: Adds detail (concurrent!)
local edit2 = OT.insert(24, " ancient")

-- Transform Author 1's edit
local edit1_transformed = OT.transform(edit1, edit2)

-- Apply both edits
local result = OT.apply(passage_text, edit2)
result = OT.apply(result, edit1_transformed)

print(result)
-- "The brave hero enters the dark ancient cave."

-- Both authors' contributions preserved!
```

---

## Testing Your Stories

### Step 1: Use Test Helpers

```lua
local helpers = require("whisker.testing.helpers")

-- Build a test story
local story = helpers.story_builder()
  :title("Test Adventure")
  :author("Test Author")
  :add_passage("start", "You begin your journey...")
  :add_passage("forest", "You enter a dark forest...")
  :connect("start", "forest", "Enter the forest")
  :build()

-- Verify structure
helpers.assert_story_valid(story)
helpers.assert_passage_exists(story, "start")
```

### Step 2: Use Custom Matchers

```lua
local matchers = require("whisker.testing.matchers")

-- Register with Busted
for name, matcher in pairs(matchers) do
  assert:register("assertion", name, matcher)
end

-- Use in tests
describe("My Story", function()
  it("should have valid structure", function()
    assert.has_passage(story, "start")
    assert.has_passage(story, "forest")
    assert.has_no_dead_ends(story)
  end)
end)
```

### Step 3: Generate Mock Data

```lua
local mocks = require("whisker.testing.mocks")

-- Generate random story for testing
local test_story = mocks.mock_story({
  passages = 20,
  seed = 12345,  -- Reproducible
  template = "branching"
})

-- Use in performance tests
for i = 1, 100 do
  local story = mocks.mock_story({ passages = 10, seed = i })
  search:index_story(story)
end
```

---

## Next Steps

### Learn More

1. **Try the Examples**
   ```bash
   lua examples/ai_story_generator.lua
   lua examples/search_demo.lua
   lua examples/collaboration_demo.lua
   ```

2. **Read API Documentation**
   - `docs/ADVANCED_FEATURES_API.md`
   - `docs/API_REFERENCE.md`

3. **Explore Source Code**
   - `lib/whisker/ai/` - AI integration
   - `lib/whisker/search/` - Search engine
   - `lib/whisker/collaboration/` - OT system

### Build Your Own

1. **AI Story Assistant**
   - Combine AI generation with manual editing
   - Create writing prompts and suggestions
   - Analyze story quality

2. **Story Library**
   - Index your story collection
   - Search by theme, genre, content
   - Organize and categorize

3. **Collaborative Editor**
   - Real-time multi-author editing
   - Track contributions
   - Merge story branches

### Get Help

- **Examples:** See `examples/` directory
- **Documentation:** Check `docs/` folder
- **Tests:** Review `tests/` for usage patterns

---

## Troubleshooting

### AI Integration

**Q: Mock provider returns generic text**  
A: Mock provider is for testing. Use real providers (OpenAI, Anthropic) for quality content.

**Q: How do I set API keys?**  
A: Set environment variables:
```bash
export OPENAI_API_KEY="sk-..."
export ANTHROPIC_API_KEY="sk-ant-..."
```

### Search Engine

**Q: Search is slow with many stories**  
A: This is expected. Search performance:
- 10 stories: < 5ms
- 100 stories: < 50ms  
- 1000 stories: < 200ms

**Q: Why are some words not searchable?**  
A: Stop words (the, a, and, etc.) are filtered. Adjust `min_word_length` if needed.

### Operational Transform

**Q: When do I need OT?**  
A: Only for real-time collaboration with concurrent edits. Single-user editing doesn't need OT.

**Q: Can I use OT for offline editing?**  
A: Yes, but you need to store and replay operations when users reconnect.

---

**Happy story creation! 🎭✨**

For questions and support, refer to the main documentation or explore the example applications.
