--- VCS Tools Integration Tests
-- Tests for diff and merge operations on complete stories
-- @module tests.integration.vcs_spec

describe("VCS Tools Integration", function()
  local diff_module
  local merge_module

  setup(function()
    package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"
    diff_module = require("whisker.vcs.diff")
    merge_module = require("whisker.vcs.merge")
  end)

  -- Helper to create a complete test story
  local function create_complete_story()
    return {
      metadata = {
        title = "The Adventure",
        author = "Test Author",
        version = "1.0.0",
        created = "2024-01-01T00:00:00Z",
        modified = "2024-01-01T00:00:00Z",
        description = "An exciting adventure story",
        tags = { "adventure", "fantasy" },
        ifid = "12345678-1234-1234-1234-123456789ABC",
      },
      startPassage = "start",
      passages = {
        start = {
          id = "start",
          title = "The Beginning",
          content = "You stand at the entrance of a dark cave.\n\nWhat do you do?",
          position = { x = 100, y = 100 },
          choices = {
            { id = "c1", text = "Enter the cave", target = "cave" },
            { id = "c2", text = "Walk away", target = "forest" },
          },
          tags = { "start" },
        },
        cave = {
          id = "cave",
          title = "The Cave",
          content = "The cave is dark and mysterious.\n\nYou hear strange sounds.",
          position = { x = 200, y = 100 },
          choices = {
            { id = "c3", text = "Light a torch", target = "cave_lit", condition = "hasTorch" },
            { id = "c4", text = "Go deeper", target = "deep_cave" },
            { id = "c5", text = "Go back", target = "start" },
          },
          onEnterScript = "visited_cave = true",
        },
        forest = {
          id = "forest",
          title = "The Forest",
          content = "The forest is peaceful and calm.",
          position = { x = 100, y = 200 },
          choices = {
            { id = "c6", text = "Return to cave", target = "start" },
          },
        },
        deep_cave = {
          id = "deep_cave",
          title = "Deep in the Cave",
          content = "You find a treasure chest!",
          position = { x = 300, y = 100 },
          choices = {
            { id = "c7", text = "Open it", target = "treasure" },
            { id = "c8", text = "Leave it", target = "cave" },
          },
        },
        treasure = {
          id = "treasure",
          title = "Treasure Found!",
          content = "You found 100 gold coins!",
          position = { x = 400, y = 100 },
          choices = {},
          onEnterScript = "gold = gold + 100",
        },
      },
      variables = {
        gold = { name = "gold", type = "number", initial = 0 },
        hasTorch = { name = "hasTorch", type = "boolean", initial = false },
        visited_cave = { name = "visited_cave", type = "boolean", initial = false },
      },
      settings = {
        theme = "dark",
        autoSave = true,
      },
    }
  end

  -- Deep copy helper
  local function deep_copy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
      copy[deep_copy(k)] = deep_copy(v)
    end
    return copy
  end

  describe("Story Diff", function()
    it("should detect no changes for identical stories", function()
      local story = create_complete_story()
      local result = diff_module.diff_stories(story, story)

      assert.is_false(result.has_changes)
      assert.equals(0, result.summary.passages_added)
      assert.equals(0, result.summary.passages_removed)
      assert.equals(0, result.summary.passages_modified)
    end)

    it("should detect added passages", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.new_passage = {
        id = "new_passage",
        title = "New Passage",
        content = "New content",
        position = { x = 500, y = 100 },
        choices = {},
      }

      local result = diff_module.diff_stories(base, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.passages_added)
    end)

    it("should detect removed passages", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.forest = nil

      local result = diff_module.diff_stories(base, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.passages_removed)
    end)

    it("should detect modified content", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.start.content = "Modified content here."

      local result = diff_module.diff_stories(base, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.passages_modified)
    end)

    it("should detect added choices", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      table.insert(modified.passages.start.choices, {
        id = "c_new",
        text = "New choice",
        target = "new_target",
      })

      local result = diff_module.diff_stories(base, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.choices_added)
    end)

    it("should detect variable changes", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.variables.gems = { name = "gems", type = "number", initial = 0 }

      local result = diff_module.diff_stories(base, modified)

      assert.is_true(result.has_changes)
      assert.equals(1, result.summary.variables_added)
    end)

    it("should ignore positions by default", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.start.position = { x = 999, y = 999 }

      local result = diff_module.diff_stories(base, modified)

      assert.is_false(result.has_changes)
    end)

    it("should detect positions when not ignored", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.start.position = { x = 999, y = 999 }

      local result = diff_module.diff_stories(base, modified, { ignore_positions = false })

      assert.is_true(result.has_changes)
    end)
  end)

  describe("Format Diff", function()
    it("should produce readable output", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.start.content = "Modified content"

      local result = diff_module.diff_stories(base, modified)
      local output = diff_module.format_diff(result)

      assert.is_string(output)
      assert.truthy(output:find("Story Diff Summary"))
      assert.truthy(output:find("Passages"))
    end)

    it("should show no changes message for identical stories", function()
      local story = create_complete_story()
      local result = diff_module.diff_stories(story, story)
      local output = diff_module.format_diff(result)

      assert.truthy(output:find("No changes detected"))
    end)
  end)

  describe("Get Summary", function()
    it("should return no changes for identical stories", function()
      local story = create_complete_story()
      local result = diff_module.diff_stories(story, story)
      local summary = diff_module.get_summary(result)

      assert.equals("No changes", summary)
    end)

    it("should summarize passage additions", function()
      local base = create_complete_story()
      local modified = deep_copy(base)
      modified.passages.new1 = { id = "new1", title = "New 1", content = "", position = { x = 0, y = 0 }, choices = {} }
      modified.passages.new2 = { id = "new2", title = "New 2", content = "", position = { x = 0, y = 0 }, choices = {} }

      local result = diff_module.diff_stories(base, modified)
      local summary = diff_module.get_summary(result)

      assert.truthy(summary:find("added 2 passages"))
    end)
  end)

  describe("Story Merge", function()
    it("should merge identical stories without conflicts", function()
      local base = create_complete_story()
      local result = merge_module.merge_stories(base, base, base)

      assert.is_true(result.success)
      assert.equals(0, #result.conflicts)
    end)

    it("should merge when only local has changes", function()
      local base = create_complete_story()
      local local_version = deep_copy(base)
      local_version.passages.cave.content = "Local changes"

      local result = merge_module.merge_stories(base, local_version, base)

      assert.is_true(result.success)
      assert.equals("Local changes", result.merged.passages.cave.content)
    end)

    it("should merge when only remote has changes", function()
      local base = create_complete_story()
      local remote = deep_copy(base)
      remote.passages.cave.content = "Remote changes"

      local result = merge_module.merge_stories(base, base, remote)

      assert.is_true(result.success)
      assert.equals("Remote changes", result.merged.passages.cave.content)
    end)

    it("should merge non-conflicting changes from both sides", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.cave.content = "Local cave changes"

      local remote = deep_copy(base)
      remote.passages.forest.content = "Remote forest changes"

      local result = merge_module.merge_stories(base, local_version, remote)

      assert.is_true(result.success)
      assert.equals("Local cave changes", result.merged.passages.cave.content)
      assert.equals("Remote forest changes", result.merged.passages.forest.content)
    end)

    it("should detect content conflicts", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local content"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote content"

      local result = merge_module.merge_stories(base, local_version, remote)

      assert.is_false(result.success)
      assert.is_true(#result.conflicts > 0)
    end)

    it("should handle passage additions from both sides", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.local_new = {
        id = "local_new",
        title = "Local New",
        content = "Added by local",
        position = { x = 500, y = 100 },
        choices = {},
      }

      local remote = deep_copy(base)
      remote.passages.remote_new = {
        id = "remote_new",
        title = "Remote New",
        content = "Added by remote",
        position = { x = 600, y = 100 },
        choices = {},
      }

      local result = merge_module.merge_stories(base, local_version, remote)

      assert.is_true(result.success)
      assert.is_not_nil(result.merged.passages.local_new)
      assert.is_not_nil(result.merged.passages.remote_new)
    end)

    it("should handle passage deletions", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.forest = nil

      local result = merge_module.merge_stories(base, local_version, base)

      assert.is_true(result.success)
      assert.is_nil(result.merged.passages.forest)
    end)

    it("should merge variable additions", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.variables.health = { name = "health", type = "number", initial = 100 }

      local remote = deep_copy(base)
      remote.variables.mana = { name = "mana", type = "number", initial = 50 }

      local result = merge_module.merge_stories(base, local_version, remote)

      assert.is_true(result.success)
      assert.is_not_nil(result.merged.variables.health)
      assert.is_not_nil(result.merged.variables.mana)
    end)

    it("should resolve conflicts with local strategy", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote"

      local result = merge_module.merge_stories(base, local_version, remote, {
        strategy = merge_module.STRATEGIES.LOCAL,
      })

      assert.equals("Local", result.merged.passages.start.content)
      assert.is_true(result.auto_resolved > 0)
    end)

    it("should resolve conflicts with remote strategy", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote"

      local result = merge_module.merge_stories(base, local_version, remote, {
        strategy = merge_module.STRATEGIES.REMOTE,
      })

      assert.equals("Remote", result.merged.passages.start.content)
    end)
  end)

  describe("Manual Conflict Resolution", function()
    it("should allow resolving conflicts manually", function()
      local base = create_complete_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote"

      local merge_result = merge_module.merge_stories(base, local_version, remote)

      -- Create resolutions map
      local resolutions = {}
      for _, conflict in ipairs(merge_result.conflicts) do
        resolutions[conflict.path] = merge_module.STRATEGIES.REMOTE
      end

      local resolved = merge_module.resolve_conflicts(merge_result, resolutions)

      assert.equals("Remote", resolved.passages.start.content)
    end)
  end)

  describe("Round-trip Consistency", function()
    it("should maintain story integrity through diff and merge", function()
      local original = create_complete_story()

      -- No changes should produce no diff
      local no_diff = diff_module.diff_stories(original, original)
      assert.is_false(no_diff.has_changes)

      -- Merge with no changes should return equivalent structure
      local no_change_result = merge_module.merge_stories(original, original, original)
      assert.is_true(no_change_result.success)
      assert.equals(original.metadata.title, no_change_result.merged.metadata.title)
    end)
  end)
end)
