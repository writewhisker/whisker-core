#!/usr/bin/env lua
--- Complete Workflow Example
-- Demonstrates the full Phase 1 implementation:
-- - Storage system (SQLite and Filesystem backends)
-- - Import framework with Twine adapter
-- - Export template engine
--
-- This example shows how all components work together

-- Add lib to path
package.path = package.path .. ";lib/?.lua;lib/?/init.lua"

local Storage = require("whisker.storage")
local Parser = require("whisker.import.parser_framework")
local TwineAdapter = require("whisker.import.twine_adapter")
local Templates = require("whisker.export.templates.engine")

print("=== Whisker Core - Complete Workflow Example ===\n")

-- Step 1: Set up storage with SQLite backend
print("1. Setting up storage system...")
local storage = Storage.new({
  backend = "sqlite",
  path = ":memory:",  -- Use in-memory database for example
  cache_size = 10
})

local success, err = storage:initialize()
if not success then
  print("  ✗ Failed to initialize storage:", err)
  os.exit(1)
end
print("  ✓ Storage initialized (SQLite backend)")

-- Add event listeners
storage:on(Storage.Events.STORY_SAVED, function(data)
  print(string.format("  → Event: Story '%s' saved (%s)", 
    data.id, data.is_new and "new" or "updated"))
end)

storage:on(Storage.Events.STORY_LOADED, function(data)
  print(string.format("  → Event: Story '%s' loaded (from cache: %s)", 
    data.id, data.from_cache and "yes" or "no"))
end)

-- Step 2: Register Twine adapter with parser framework
print("\n2. Registering import adapters...")
Parser.register("twine", TwineAdapter)
print("  ✓ Registered parsers:", table.concat(Parser.list_parsers(), ", "))

-- Step 3: Create a sample Twine story (simulated)
print("\n3. Creating sample Twine story...")
local sample_twine = '<tw-storydata name="The Adventure" startnode="1" creator="Whisker" ifid="12345-67890">' ..
'<tw-passagedata pid="1" name="Start" tags="" position="100,100">' ..
'You wake up in a mysterious forest. What do you do? [[Look around]] [[Call for help]]' ..
'</tw-passagedata>' ..
'<tw-passagedata pid="2" name="Look around" tags="" position="300,100">' ..
'You scan your surroundings. [[Follow the path->Deep Forest]] [[Head toward the water]]' ..
'</tw-passagedata>' ..
'<tw-passagedata pid="3" name="Call for help" tags="" position="100,300">' ..
'You shout and hear a response! [[Follow the voice]]' ..
'</tw-passagedata>' ..
'<tw-passagedata pid="4" name="Deep Forest" tags="dark scary" position="500,100">' ..
'The forest grows darker. [[Turn back->Look around]] [[Continue onward]]' ..
'</tw-passagedata>' ..
'<tw-passagedata pid="5" name="Head toward the water" tags="" position="300,300">' ..
'You discover a beautiful stream. The end.' ..
'</tw-passagedata>' ..
'<tw-passagedata pid="6" name="Follow the voice" tags="" position="100,500">' ..
'You find another traveler! Together you escape. The end.' ..
'</tw-passagedata>' ..
'<tw-passagedata pid="7" name="Continue onward" tags="ending" position="700,100">' ..
'You find a hidden village! The end.' ..
'</tw-passagedata>' ..
'</tw-storydata>'

print("  ✓ Sample Twine story created (7 passages)")

-- Step 4: Parse the Twine story
print("\n4. Parsing Twine story...")
local parse_result, parse_err = Parser.parse(sample_twine, {
  parser = "twine",
  validate = true,
  on_progress = function(stage, percent)
    print(string.format("  → %s: %d%%", stage, percent))
  end
})

if not parse_result then
  print("  ✗ Parse failed:", parse_err)
  os.exit(1)
end

if not parse_result.success then
  print("  ✗ Validation failed:")
  for _, error in ipairs(parse_result.errors) do
    print("    -", error)
  end
  os.exit(1)
end

print(string.format("  ✓ Story parsed successfully (%s format)", parse_result.parser))
print(string.format("  ✓ Found %d passages", #parse_result.story.passages))

-- Step 5: Save the imported story
print("\n5. Saving story to storage...")
local story = parse_result.story

success, err = storage:save_story(story.id, story, {
  metadata = {
    tags = {"imported", "twine", "example"}
  }
})

if not success then
  print("  ✗ Save failed:", err)
  os.exit(1)
end

-- Step 6: Load the story back (should hit cache)
print("\n6. Loading story from storage...")
local loaded_story, load_err = storage:load_story(story.id)

if not loaded_story then
  print("  ✗ Load failed:", load_err)
  os.exit(1)
end

-- Try loading again (should be cached)
print("  (Loading again to test cache...)")
loaded_story = storage:load_story(story.id)

-- Step 7: List all stories
print("\n7. Listing all stories...")
local stories = storage:list_stories()
print(string.format("  ✓ Found %d story(ies) in storage:", #stories))
for _, meta in ipairs(stories) do
  print(string.format("    - %s (tags: %s)", 
    meta.title,
    table.concat(meta.tags or {}, ", ")))
end

-- Step 8: Export to different formats
print("\n8. Exporting story to various formats...")

-- Export to HTML
print("  → Exporting to HTML...")
local html, html_err = Templates.render(loaded_story, "html/default")
if html then
  print(string.format("  ✓ HTML generated (%d characters)", #html))
  -- Optionally save to file
  local html_file = io.open("example_export.html", "w")
  if html_file then
    html_file:write(html)
    html_file:close()
    print("  ✓ Saved to example_export.html")
  end
else
  print("  ✗ HTML export failed:", html_err)
end

-- Export to Markdown
print("  → Exporting to Markdown...")
local markdown, md_err = Templates.render(loaded_story, "markdown/default")
if markdown then
  print(string.format("  ✓ Markdown generated (%d characters)", #markdown))
  local md_file = io.open("example_export.md", "w")
  if md_file then
    md_file:write(markdown)
    md_file:close()
    print("  ✓ Saved to example_export.md")
  end
else
  print("  ✗ Markdown export failed:", md_err)
end

-- Export to plain text
print("  → Exporting to plain text...")
local text = Templates.render(loaded_story, "text/default")
if text then
  print(string.format("  ✓ Text generated (%d characters)", #text))
end

-- Step 9: Display statistics
print("\n9. Storage statistics:")
local stats = storage:get_statistics()
print(string.format("  - Total saves: %d", stats.saves))
print(string.format("  - Total loads: %d", stats.loads))
print(string.format("  - Cache hits: %d", stats.cache_hits))
print(string.format("  - Cache misses: %d", stats.cache_misses))
print(string.format("  - Cache hit rate: %.1f%%", stats.cache_hit_rate * 100))
print(string.format("  - Storage usage: %d bytes", stats.total_size_bytes))

-- Step 10: Demonstrate filtering
print("\n10. Filtering stories by tag...")
local filtered = storage:list_stories({ tags = {"imported"} })
print(string.format("  ✓ Found %d story(ies) with 'imported' tag", #filtered))

-- Step 11: Clean up
print("\n11. Cleanup...")
storage:delete_story(story.id)
print("  ✓ Deleted test story")

local final_stats = storage:get_statistics()
print(string.format("  ✓ Total deletes: %d", final_stats.deletes))

-- Summary
print("\n" .. string.rep("=", 50))
print("✓ Complete workflow executed successfully!")
print(string.rep("=", 50))

print("\nWhat was demonstrated:")
print("  ✓ Storage system (SQLite backend)")
print("  ✓ Event system (save/load events)")
print("  ✓ Import framework (Twine adapter)")
print("  ✓ Parser with validation")
print("  ✓ Export templates (HTML, Markdown, Text)")
print("  ✓ Caching system")
print("  ✓ Filtering and querying")
print("  ✓ Statistics tracking")

print("\nPhase 1 Core Features: COMPLETE ✓")
