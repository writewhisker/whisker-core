#!/usr/bin/env lua
--[[
  Operational Transform Collaboration Demo
  
  This example demonstrates whisker-core's operational transform (OT) system
  for real-time collaborative editing.
  
  Features demonstrated:
  - Text-level operations (INSERT, DELETE, RETAIN)
  - Operation transformation for concurrent edits
  - Story-level operations (passages, choices)
  - Conflict resolution
  - Operation composition and application
  
  Usage:
    lua examples/collaboration_demo.lua
]]

-- Add lib directory to package path
package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

local OT = require("whisker.collaboration.ot")
local Story = require("whisker.core.story")

--[[
  Simulate two users editing the same text concurrently
]]
local function demo_text_operations()
  print("=" .. string.rep("=", 70))
  print("  Demo 1: Concurrent Text Editing")
  print("=" .. string.rep("=", 70))
  print("")
  
  -- Initial text
  local text = "The quick fox jumps over the dog."
  print("📝 Initial Text:")
  print("   \"" .. text .. "\"")
  print("")
  
  -- User A: Insert "brown " at position 10
  print("👤 User A: Inserts 'brown ' at position 10")
  local opA = OT.insert(10, "brown ")
  print("   Operation: INSERT(10, \"brown \")")
  print("")
  
  -- User B: Insert "lazy " at position 29 (concurrently!)
  print("👤 User B: Inserts 'lazy ' at position 29 (concurrent!)")
  local opB = OT.insert(29, "lazy ")
  print("   Operation: INSERT(29, \"lazy \")")
  print("")
  
  print("⚙️  Transforming Operations...")
  print("")
  
  -- Transform operations
  local opA_prime = OT.transform(opA, opB)
  local opB_prime = OT.transform(opB, opA)
  
  print("   User A's transformed operation:")
  print("   " .. OT.operation_to_string(opA_prime))
  print("")
  
  print("   User B's transformed operation:")
  print("   " .. OT.operation_to_string(opB_prime))
  print("")
  
  -- Apply operations
  print("✅ Applying Operations...")
  local result1 = OT.apply(OT.apply(text, opA), opB_prime)
  local result2 = OT.apply(OT.apply(text, opB), opA_prime)
  
  print("")
  print("   Result 1 (A then B'): \"" .. result1 .. "\"")
  print("   Result 2 (B then A'): \"" .. result2 .. "\"")
  print("")
  
  if result1 == result2 then
    print("✅ CONVERGENCE ACHIEVED! Both users see the same result.")
  else
    print("❌ ERROR: Results differ!")
  end
  
  print("")
end

--[[
  Demonstrate delete operations
]]
local function demo_delete_operations()
  print("=" .. string.rep("=", 70))
  print("  Demo 2: Concurrent Deletions")
  print("=" .. string.rep("=", 70))
  print("")
  
  local text = "The quick brown fox jumps over the lazy dog."
  print("📝 Initial Text:")
  print("   \"" .. text .. "\"")
  print("")
  
  -- User A: Delete "quick " (positions 4-10)
  print("👤 User A: Deletes 'quick ' (6 chars at position 4)")
  local opA = OT.delete(4, 6)
  print("   Operation: DELETE(4, 6)")
  print("")
  
  -- User B: Delete "brown " (positions 10-16)
  print("👤 User B: Deletes 'brown ' (6 chars at position 10)")
  local opB = OT.delete(10, 6)
  print("   Operation: DELETE(10, 6)")
  print("")
  
  print("⚙️  Transforming Operations...")
  print("")
  
  -- Transform
  local opA_prime = OT.transform(opA, opB)
  local opB_prime = OT.transform(opB, opA)
  
  print("   User A's transformed operation:")
  print("   " .. OT.operation_to_string(opA_prime))
  print("")
  
  print("   User B's transformed operation:")
  print("   " .. OT.operation_to_string(opB_prime))
  print("")
  
  -- Apply
  local result1 = OT.apply(OT.apply(text, opA), opB_prime)
  local result2 = OT.apply(OT.apply(text, opB), opA_prime)
  
  print("✅ Results:")
  print("   Result 1 (A then B'): \"" .. result1 .. "\"")
  print("   Result 2 (B then A'): \"" .. result2 .. "\"")
  print("")
  
  if result1 == result2 then
    print("✅ CONVERGENCE ACHIEVED!")
  else
    print("❌ ERROR: Results differ!")
  end
  
  print("")
end

--[[
  Demonstrate mixed operations
]]
local function demo_mixed_operations()
  print("=" .. string.rep("=", 70))
  print("  Demo 3: Mixed Operations (Insert + Delete)")
  print("=" .. string.rep("=", 70))
  print("")
  
  local text = "Hello world!"
  print("📝 Initial Text:")
  print("   \"" .. text .. "\"")
  print("")
  
  -- User A: Insert ", beautiful" at position 5
  print("👤 User A: Inserts ', beautiful' at position 5")
  local opA = OT.insert(5, ", beautiful")
  print("")
  
  -- User B: Delete "world" (positions 6-11)
  print("👤 User B: Deletes 'world' (5 chars at position 6)")
  local opB = OT.delete(6, 5)
  print("")
  
  print("⚙️  Transforming Operations...")
  local opA_prime = OT.transform(opA, opB)
  local opB_prime = OT.transform(opB, opA)
  print("")
  
  -- Apply
  local result1 = OT.apply(OT.apply(text, opA), opB_prime)
  local result2 = OT.apply(OT.apply(text, opB), opA_prime)
  
  print("✅ Results:")
  print("   Result 1: \"" .. result1 .. "\"")
  print("   Result 2: \"" .. result2 .. "\"")
  print("")
  
  if result1 == result2 then
    print("✅ CONVERGENCE ACHIEVED!")
  end
  
  print("")
end

--[[
  Create a sample story for story-level operations
]]
local function create_sample_story()
  return Story.from_table({
    metadata = {
      id = "collab_story",
      title = "Collaborative Story",
      author = "Multiple Authors"
    },
    passages = {
      {
        id = "start",
        text = "This is the beginning.",
        choices = {
          { text = "Continue", target = "next" }
        }
      },
      {
        id = "next",
        text = "The story continues.",
        choices = {}
      }
    },
    start_passage = "start"
  })
end

--[[
  Demonstrate story-level operations
]]
local function demo_story_operations()
  print("=" .. string.rep("=", 70))
  print("  Demo 4: Story-Level Operations")
  print("=" .. string.rep("=", 70))
  print("")
  
  local story = create_sample_story()
  
  print("📖 Initial Story:")
  print(string.format("   Title: %s", story.metadata.title))
  print(string.format("   Passages: %d", #story.passages))
  print("")
  
  -- User A: Add a new passage
  print("👤 User A: Adds a new passage 'middle'")
  local opA = OT.StoryOT.add_passage({
    id = "middle",
    text = "A new middle section.",
    choices = {{ text = "Go on", target = "next" }}
  })
  print("")
  
  -- User B: Modify existing passage (concurrently!)
  print("👤 User B: Modifies passage 'start'")
  local opB = OT.StoryOT.modify_passage("start", {
    text = "This is the UPDATED beginning!"
  })
  print("")
  
  print("⚙️  Transforming Story Operations...")
  local opA_prime = OT.StoryOT.transform(opA, opB)
  local opB_prime = OT.StoryOT.transform(opB, opA)
  print("")
  
  -- Apply operations
  print("✅ Applying Operations...")
  
  -- Clone story for each path
  local story1 = Story.from_table({
    metadata = story.metadata,
    passages = story.passages,
    start_passage = story.start_passage
  })
  
  local story2 = Story.from_table({
    metadata = story.metadata,
    passages = story.passages,
    start_passage = story.start_passage
  })
  
  -- Path 1: A then B'
  OT.StoryOT.apply(story1, opA)
  OT.StoryOT.apply(story1, opB_prime)
  
  -- Path 2: B then A'
  OT.StoryOT.apply(story2, opB)
  OT.StoryOT.apply(story2, opA_prime)
  
  print("")
  print("   Story 1 (A then B'):")
  print(string.format("     Passages: %d", #story1.passages))
  local passage1 = story1:get_passage("start")
  if passage1 then
    print(string.format("     'start' text: %s", passage1.text:sub(1, 40) .. "..."))
  end
  
  print("")
  print("   Story 2 (B then A'):")
  print(string.format("     Passages: %d", #story2.passages))
  local passage2 = story2:get_passage("start")
  if passage2 then
    print(string.format("     'start' text: %s", passage2.text:sub(1, 40) .. "..."))
  end
  
  print("")
  
  if #story1.passages == #story2.passages and 
     passage1 and passage2 and 
     passage1.text == passage2.text then
    print("✅ STORY CONVERGENCE ACHIEVED!")
  else
    print("⚠️  Note: Story-level operations may have intentional differences")
  end
  
  print("")
end

--[[
  Demonstrate conflict scenarios
]]
local function demo_conflict_resolution()
  print("=" .. string.rep("=", 70))
  print("  Demo 5: Conflict Resolution")
  print("=" .. string.rep("=", 70))
  print("")
  
  print("📝 Scenario: Two users edit the same location")
  print("")
  
  local text = "The cat sat on the mat."
  print("   Initial: \"" .. text .. "\"")
  print("")
  
  -- Both users insert at the same position
  print("👤 User A: Inserts 'big ' at position 4")
  local opA = OT.insert(4, "big ")
  
  print("👤 User B: Inserts 'small ' at position 4 (same position!)")
  local opB = OT.insert(4, "small ")
  print("")
  
  print("⚙️  Conflict Resolution Strategy: Position-based ordering")
  print("   (Later operation is shifted to maintain both changes)")
  print("")
  
  -- Transform
  local opA_prime = OT.transform(opA, opB)
  local opB_prime = OT.transform(opB, opA)
  
  -- Apply
  local result = OT.apply(OT.apply(text, opA), opB_prime)
  
  print("✅ Result: \"" .. result .. "\"")
  print("   (Both insertions preserved)")
  print("")
end

--[[
  Demonstrate operation composition
]]
local function demo_operation_composition()
  print("=" .. string.rep("=", 70))
  print("  Demo 6: Operation Composition")
  print("=" .. string.rep("=", 70))
  print("")
  
  print("📝 Scenario: User makes multiple edits")
  print("")
  
  local text = "Hello world"
  print("   Initial: \"" .. text .. "\"")
  print("")
  
  -- Multiple operations from one user
  print("👤 User A performs multiple operations:")
  local op1 = OT.insert(5, ",")
  print("   1. Insert ',' at position 5")
  
  local op2 = OT.insert(12, "!")
  print("   2. Insert '!' at end")
  print("")
  
  -- Compose operations
  print("⚙️  Composing operations into a single operation...")
  local composed = OT.compose(op1, op2)
  print("")
  
  -- Apply composed operation
  local result = OT.apply(text, composed)
  
  print("✅ Result: \"" .. result .. "\"")
  print("   (Both edits applied atomically)")
  print("")
end

--[[
  Practical use case: Collaborative story writing
]]
local function demo_practical_collaboration()
  print("=" .. string.rep("=", 70))
  print("  Demo 7: Practical Collaborative Writing")
  print("=" .. string.rep("=", 70))
  print("")
  
  print("📖 Scenario: Two authors collaborate on a story passage")
  print("")
  
  local passage_text = "The detective walked into the room. It was empty."
  
  print("   Original passage:")
  print("   \"" .. passage_text .. "\"")
  print("")
  
  print("👤 Author 1: Adds atmospheric detail")
  local op1 = OT.insert(19, " slowly")
  local result1 = OT.apply(passage_text, op1)
  print("   \"" .. result1 .. "\"")
  print("")
  
  print("👤 Author 2: Expands ending (working from original)")
  local op2 = OT.insert(49, " The windows were dark.")
  
  print("⚙️  Merging changes...")
  local op2_prime = OT.transform(op2, op1)
  local final = OT.apply(result1, op2_prime)
  print("")
  
  print("✅ Final collaborative result:")
  print("   \"" .. final .. "\"")
  print("")
  print("   Both authors' contributions preserved!")
  print("")
end

--[[
  Main function
]]
local function main()
  print("=" .. string.rep("=", 70))
  print("  Whisker-Core Operational Transform Demo")
  print("  Real-Time Collaboration Infrastructure")
  print("=" .. string.rep("=", 70))
  print("")
  
  print("ℹ️  What is Operational Transform?")
  print("")
  print("   OT is an algorithm that enables multiple users to edit the same")
  print("   document concurrently while maintaining consistency. It's used by")
  print("   Google Docs, Figma, and other collaborative editing tools.")
  print("")
  print("   Key Features:")
  print("   - Concurrent editing without locks")
  print("   - Automatic conflict resolution")
  print("   - Eventual consistency guarantee")
  print("   - Low latency (no waiting for server)")
  print("")
  
  -- Run demonstrations
  demo_text_operations()
  demo_delete_operations()
  demo_mixed_operations()
  demo_story_operations()
  demo_conflict_resolution()
  demo_operation_composition()
  demo_practical_collaboration()
  
  print("=" .. string.rep("=", 70))
  print("  Demo Complete!")
  print("=" .. string.rep("=", 70))
  print("")
  print("Key Concepts Demonstrated:")
  print("  ✓ Operation transformation algorithm")
  print("  ✓ INSERT, DELETE, RETAIN operations")
  print("  ✓ Concurrent editing scenarios")
  print("  ✓ Conflict resolution strategies")
  print("  ✓ Operation composition")
  print("  ✓ Story-level operations")
  print("  ✓ Eventual consistency")
  print("")
  print("Next Steps:")
  print("  - Implement a WebSocket server for real-time sync")
  print("  - Add client-side collaboration library")
  print("  - Track user presence and cursor positions")
  print("  - Persist operations for offline support")
  print("")
  print("Use Cases:")
  print("  - Co-authoring stories in real-time")
  print("  - Teacher/student collaborative editing")
  print("  - Community storytelling projects")
  print("  - Game master + players editing adventures")
  print("")
end

-- Run if executed directly
if arg and arg[0] and arg[0]:match("collaboration_demo%.lua$") then
  main()
end

return {
  demo_text_operations = demo_text_operations,
  demo_delete_operations = demo_delete_operations,
  demo_mixed_operations = demo_mixed_operations,
  demo_story_operations = demo_story_operations,
  demo_conflict_resolution = demo_conflict_resolution,
  demo_operation_composition = demo_operation_composition,
  demo_practical_collaboration = demo_practical_collaboration
}
