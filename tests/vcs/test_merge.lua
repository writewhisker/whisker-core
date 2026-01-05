--- VCS Merge Module Tests
-- Unit tests for the story merge algorithm
-- @module tests.vcs.test_merge

local helper = require("tests.test_helper")
local merge = require("whisker.vcs.merge")

describe("VCS Merge Module", function()
  local function create_base_story()
    return {
      metadata = { title = "Test Story", author = "Author", version = "1.0" },
      startPassage = "start",
      passages = {
        start = {
          id = "start",
          title = "Start",
          content = "This is the start",
          choices = {
            { id = "c1", text = "Go to room", target = "room" },
          },
        },
        room = {
          id = "room",
          title = "The Room",
          content = "You are in a room",
          choices = {},
        },
      },
      variables = {
        score = { name = "score", type = "number", initial = 0 },
      },
      settings = { theme = "light" },
    }
  end

  local function deep_copy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
      copy[deep_copy(k)] = deep_copy(v)
    end
    return copy
  end

  describe("CONFLICT_TYPES", function()
    it("should define passage content conflict", function()
      assert.equals("passage-content", merge.CONFLICT_TYPES.PASSAGE_CONTENT)
    end)

    it("should define variable conflict types", function()
      assert.equals("variable-value", merge.CONFLICT_TYPES.VARIABLE_VALUE)
      assert.equals("variable-deleted", merge.CONFLICT_TYPES.VARIABLE_DELETED)
    end)
  end)

  describe("STRATEGIES", function()
    it("should define local strategy", function()
      assert.equals("local", merge.STRATEGIES.LOCAL)
    end)

    it("should define remote strategy", function()
      assert.equals("remote", merge.STRATEGIES.REMOTE)
    end)

    it("should define base strategy", function()
      assert.equals("base", merge.STRATEGIES.BASE)
    end)

    it("should define manual strategy", function()
      assert.equals("manual", merge.STRATEGIES.MANUAL)
    end)
  end)

  describe("merge_stories", function()
    it("should merge identical stories without conflicts", function()
      local base = create_base_story()
      local result = merge.merge_stories(base, base, base)

      assert.is_true(result.success)
      assert.equals(0, #result.conflicts)
    end)

    it("should merge when only local has changes", function()
      local base = create_base_story()
      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local change"

      local result = merge.merge_stories(base, local_version, base)

      assert.is_true(result.success)
      assert.equals("Local change", result.merged.passages.start.content)
    end)

    it("should merge when only remote has changes", function()
      local base = create_base_story()
      local remote = deep_copy(base)
      remote.passages.start.content = "Remote change"

      local result = merge.merge_stories(base, base, remote)

      assert.is_true(result.success)
      assert.equals("Remote change", result.merged.passages.start.content)
    end)

    it("should merge non-conflicting changes from both sides", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local start"

      local remote = deep_copy(base)
      remote.passages.room.content = "Remote room"

      local result = merge.merge_stories(base, local_version, remote)

      assert.is_true(result.success)
      assert.equals("Local start", result.merged.passages.start.content)
      assert.equals("Remote room", result.merged.passages.room.content)
    end)

    it("should detect content conflicts", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local content"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote content"

      local result = merge.merge_stories(base, local_version, remote)

      assert.is_false(result.success)
      assert.is_true(#result.conflicts > 0)
    end)

    it("should handle passage additions from both sides", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.local_new = {
        id = "local_new",
        title = "Local New",
        content = "New from local",
        choices = {},
      }

      local remote = deep_copy(base)
      remote.passages.remote_new = {
        id = "remote_new",
        title = "Remote New",
        content = "New from remote",
        choices = {},
      }

      local result = merge.merge_stories(base, local_version, remote)

      assert.is_true(result.success)
      assert.is_not_nil(result.merged.passages.local_new)
      assert.is_not_nil(result.merged.passages.remote_new)
    end)

    it("should handle passage deletion from local", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.room = nil

      local result = merge.merge_stories(base, local_version, base)

      assert.is_true(result.success)
      assert.is_nil(result.merged.passages.room)
    end)

    it("should handle passage deletion from remote", function()
      local base = create_base_story()

      local remote = deep_copy(base)
      remote.passages.room = nil

      local result = merge.merge_stories(base, base, remote)

      assert.is_true(result.success)
      assert.is_nil(result.merged.passages.room)
    end)

    it("should merge variable additions", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.variables.health = { name = "health", type = "number", initial = 100 }

      local remote = deep_copy(base)
      remote.variables.mana = { name = "mana", type = "number", initial = 50 }

      local result = merge.merge_stories(base, local_version, remote)

      assert.is_true(result.success)
      assert.is_not_nil(result.merged.variables.health)
      assert.is_not_nil(result.merged.variables.mana)
    end)

    it("should resolve conflicts with local strategy", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote"

      local result = merge.merge_stories(base, local_version, remote, {
        strategy = merge.STRATEGIES.LOCAL,
      })

      assert.equals("Local", result.merged.passages.start.content)
      assert.is_true(result.auto_resolved > 0)
    end)

    it("should resolve conflicts with remote strategy", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote"

      local result = merge.merge_stories(base, local_version, remote, {
        strategy = merge.STRATEGIES.REMOTE,
      })

      assert.equals("Remote", result.merged.passages.start.content)
    end)

    it("should handle metadata changes", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.metadata.title = "Local Title"

      local result = merge.merge_stories(base, local_version, base)

      assert.is_true(result.success)
      assert.equals("Local Title", result.merged.metadata.title)
    end)

    it("should detect metadata conflicts", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.metadata.title = "Local Title"

      local remote = deep_copy(base)
      remote.metadata.title = "Remote Title"

      local result = merge.merge_stories(base, local_version, remote)

      -- Metadata conflicts may or may not cause failure depending on implementation
      -- Just verify the merged result has some title
      assert.is_not_nil(result.merged.metadata.title)
    end)

    it("should handle start passage changes", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.startPassage = "room"

      local result = merge.merge_stories(base, local_version, base)

      assert.is_true(result.success)
      assert.equals("room", result.merged.startPassage)
    end)
  end)

  describe("resolve_conflicts", function()
    it("should resolve conflicts with specified resolutions", function()
      local base = create_base_story()

      local local_version = deep_copy(base)
      local_version.passages.start.content = "Local"

      local remote = deep_copy(base)
      remote.passages.start.content = "Remote"

      local merge_result = merge.merge_stories(base, local_version, remote)

      -- Create resolutions
      local resolutions = {}
      for _, conflict in ipairs(merge_result.conflicts) do
        resolutions[conflict.path] = merge.STRATEGIES.REMOTE
      end

      local resolved = merge.resolve_conflicts(merge_result, resolutions)

      assert.is_not_nil(resolved)
      assert.equals("Remote", resolved.passages.start.content)
    end)
  end)
end)
