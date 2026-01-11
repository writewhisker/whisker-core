#!/usr/bin/env lua
--- Example: Using the Storage Backend Interface
-- Demonstrates how to create a custom backend and use it

-- Add lib to path
package.path = package.path .. ";lib/?.lua;lib/?/init.lua"

local Backend = require("whisker.storage.interfaces.backend")

print("=== Storage Backend Interface Example ===\n")

-- Example 1: Creating a simple in-memory backend
print("1. Creating an in-memory backend...")

local MemoryBackend = {}
MemoryBackend.__index = MemoryBackend

function MemoryBackend.new()
  local self = setmetatable({}, MemoryBackend)
  self.storage = {}
  self.metadata = {}
  return self
end

function MemoryBackend:initialize()
  print("  Initializing memory backend...")
  return true
end

function MemoryBackend:save(key, data, metadata)
  self.storage[key] = data
  self.metadata[key] = {
    id = key,
    title = data.title or "Untitled",
    created_at = os.time(),
    updated_at = os.time(),
    tags = metadata.tags or {}
  }
  return true
end

function MemoryBackend:load(key)
  if self.storage[key] then
    return self.storage[key], nil
  else
    return nil, "Story not found"
  end
end

function MemoryBackend:delete(key)
  if self.storage[key] then
    self.storage[key] = nil
    self.metadata[key] = nil
    return true
  else
    return false, "Story not found"
  end
end

function MemoryBackend:list(filter)
  local results = {}
  for key, meta in pairs(self.metadata) do
    table.insert(results, meta)
  end
  return results
end

function MemoryBackend:exists(key)
  return self.storage[key] ~= nil
end

function MemoryBackend:get_metadata(key)
  return self.metadata[key]
end

function MemoryBackend:update_metadata(key, metadata)
  if self.metadata[key] then
    for k, v in pairs(metadata) do
      self.metadata[key][k] = v
    end
    self.metadata[key].updated_at = os.time()
    return true
  else
    return false, "Story not found"
  end
end

function MemoryBackend:export(key)
  local data = self.storage[key]
  if data then
    -- Simple JSON-like export
    return string.format('{"id":"%s","title":"%s"}', key, data.title or "")
  else
    return nil, "Story not found"
  end
end

function MemoryBackend:import_data(data)
  -- Simple import (in real implementation, parse JSON)
  local key = "imported-" .. os.time()
  self:save(key, {title = "Imported Story"}, {})
  return key
end

function MemoryBackend:get_storage_usage()
  local total = 0
  for _, data in pairs(self.storage) do
    -- Rough estimate
    total = total + 1000
  end
  return total
end

function MemoryBackend:clear()
  self.storage = {}
  self.metadata = {}
  return true
end

-- Create and validate backend
local mem_impl = MemoryBackend.new()
local backend = Backend.new(mem_impl)

print("  ✓ Backend created and validated\n")

-- Example 2: Basic operations
print("2. Performing basic operations...")

-- Initialize
backend:initialize()

-- Save a story
local story_data = {
  title = "The Adventure Begins",
  passages = {
    {id = "start", content = "You wake up in a mysterious forest..."}
  }
}

local success, err = backend:save("story-1", story_data, {
  tags = {"adventure", "fantasy"}
})

if success then
  print("  ✓ Story saved: story-1")
else
  print("  ✗ Failed to save:", err)
end

-- Check if exists
if backend:exists("story-1") then
  print("  ✓ Story exists")
end

-- Load the story
local loaded, err = backend:load("story-1")
if loaded then
  print("  ✓ Story loaded:", loaded.title)
end

-- Get metadata
local meta = backend:get_metadata("story-1")
if meta then
  print("  ✓ Metadata retrieved:")
  print("    - Title:", meta.title)
  print("    - Tags:", table.concat(meta.tags or {}, ", "))
end

-- Update metadata
backend:update_metadata("story-1", {title = "The Great Adventure"})
print("  ✓ Metadata updated")

-- List all stories
local stories = backend:list()
print("  ✓ Found", #stories, "story(ies)")

-- Get storage usage
local bytes = backend:get_storage_usage()
print("  ✓ Storage usage:", bytes, "bytes\n")

-- Example 3: Error handling
print("3. Testing error handling...")

-- Try to load non-existent story
local data, err = backend:load("non-existent")
if not data then
  print("  ✓ Correctly handled missing story:", err)
end

-- Try to delete non-existent story
local success, err = backend:delete("non-existent")
if not success then
  print("  ✓ Correctly handled delete error:", err)
end

-- Example 4: Optional methods
print("\n4. Testing optional methods...")

if not backend:has_method("save_preference") then
  print("  ✓ Backend does not support preferences (expected)")
end

local success, err = backend:save_preference("theme", {value = "dark"})
if not success then
  print("  ✓ Optional method returns error:", err)
end

-- Example 5: Cleanup
print("\n5. Cleanup...")

backend:clear()
print("  ✓ Storage cleared")

local stories = backend:list()
print("  ✓ Stories remaining:", #stories, "(should be 0)")

print("\n=== Example Complete ===")
