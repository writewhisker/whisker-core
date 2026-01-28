-- Test suite for Save State Migrator
-- WLS 1.0 GAP-068: Save state versioning tests

local SaveMigrator = require("lib.whisker.core.save_migrator")

describe("SaveMigrator", function()
  local migrator

  before_each(function()
    migrator = SaveMigrator.new()
  end)

  describe("version comparison", function()
    it("should compare versions correctly - less than", function()
      assert.equals(-1, migrator:compare_versions("0.9.0", "1.0.0"))
      assert.equals(-1, migrator:compare_versions("1.0.0", "1.1.0"))
      assert.equals(-1, migrator:compare_versions("1.0.0", "1.0.1"))
    end)

    it("should compare versions correctly - equal", function()
      assert.equals(0, migrator:compare_versions("1.0.0", "1.0.0"))
      assert.equals(0, migrator:compare_versions("0.9.0", "0.9.0"))
    end)

    it("should compare versions correctly - greater than", function()
      assert.equals(1, migrator:compare_versions("1.0.0", "0.9.0"))
      assert.equals(1, migrator:compare_versions("1.1.0", "1.0.0"))
      assert.equals(1, migrator:compare_versions("1.0.1", "1.0.0"))
    end)

    it("should handle missing patch version", function()
      assert.equals(0, migrator:compare_versions("1.0", "1.0.0"))
    end)
  end)

  describe("needs_migration", function()
    it("should return true for older versions", function()
      local data = { version = "0.9.0" }
      assert.is_true(migrator:needs_migration(data))
    end)

    it("should return false for current version", function()
      local data = { version = SaveMigrator.CURRENT_VERSION }
      assert.is_false(migrator:needs_migration(data))
    end)

    it("should return true for missing version", function()
      local data = {}
      assert.is_true(migrator:needs_migration(data))
    end)
  end)

  describe("migration", function()
    it("should migrate old saves to current version", function()
      local old_data = {
        version = "0.9.0",
        visited = { Start = 1 },
        current_passage = "Start",
        variables = {}
      }

      local migrated, err = migrator:migrate(old_data)

      assert.is_nil(err)
      assert.is_not_nil(migrated)
      assert.equals(SaveMigrator.CURRENT_VERSION, migrated.version)
      assert.is_not_nil(migrated.visited_passages)
      assert.is_nil(migrated.visited)  -- Old field should be removed
    end)

    it("should add tunnel_stack if missing", function()
      local old_data = {
        version = "0.9.0",
        visited = {},
        current_passage = "Start",
        variables = {}
      }

      local migrated, err = migrator:migrate(old_data)

      assert.is_nil(err)
      assert.is_table(migrated.tunnel_stack)
    end)

    it("should reject newer versions", function()
      local future_data = {
        version = "99.0.0",
        current_passage = "Start",
        variables = {}
      }

      local migrated, err = migrator:migrate(future_data)

      assert.is_nil(migrated)
      assert.has.match("newer than supported", err)
    end)

    it("should pass through current version unchanged", function()
      local current_data = {
        version = SaveMigrator.CURRENT_VERSION,
        current_passage = "Start",
        variables = { hp = 100 }
      }

      local migrated, err = migrator:migrate(current_data)

      assert.is_nil(err)
      assert.equals(100, migrated.variables.hp)
    end)
  end)

  describe("validation", function()
    it("should validate required fields - version", function()
      local valid, errors = migrator:validate({})

      assert.is_false(valid)
      assert.is_true(#errors > 0)
      local found_version = false
      for _, e in ipairs(errors) do
        if e:match("version") then found_version = true end
      end
      assert.is_true(found_version)
    end)

    it("should validate required fields - current_passage", function()
      local valid, errors = migrator:validate({
        version = "1.0.0",
        variables = {}
      })

      assert.is_false(valid)
      local found_passage = false
      for _, e in ipairs(errors) do
        if e:match("current_passage") then found_passage = true end
      end
      assert.is_true(found_passage)
    end)

    it("should validate variables field type", function()
      local valid, errors = migrator:validate({
        version = "1.0.0",
        current_passage = "Start",
        variables = "invalid"
      })

      assert.is_false(valid)
      local found_vars = false
      for _, e in ipairs(errors) do
        if e:match("variables") then found_vars = true end
      end
      assert.is_true(found_vars)
    end)

    it("should accept valid save data", function()
      local valid, errors = migrator:validate({
        version = "1.0.0",
        current_passage = "Start",
        variables = {}
      })

      assert.is_true(valid)
      assert.equals(0, #(errors or {}))
    end)

    it("should validate version format", function()
      local valid, errors = migrator:validate({
        version = "invalid",
        current_passage = "Start",
        variables = {}
      })

      assert.is_false(valid)
    end)
  end)

  describe("is_compatible", function()
    it("should return true for same major.minor", function()
      -- Current version is 1.0.0
      assert.is_true(migrator:is_compatible("1.0.1"))
      assert.is_true(migrator:is_compatible("1.0.0"))
    end)

    it("should return false for different minor", function()
      assert.is_false(migrator:is_compatible("1.1.0"))
      assert.is_false(migrator:is_compatible("0.9.0"))
    end)
  end)

  describe("migration chain", function()
    it("should migrate through multiple versions", function()
      local old_data = {
        version = "0.8.0",
        passage_history = { "Start", "Combat", "Start" },
        current_passage = "Combat",
        variables = {}
      }

      local migrated, err = migrator:migrate(old_data)

      assert.is_nil(err)
      assert.equals(SaveMigrator.CURRENT_VERSION, migrated.version)
      -- Should have migrated passage_history -> visited -> visited_passages
      assert.is_table(migrated.visited_passages)
    end)
  end)

  describe("get_migration_path", function()
    it("should return empty path for same version", function()
      local path, err = migrator:get_migration_path("1.0.0", "1.0.0")
      assert.is_nil(err)
      assert.equals(0, #path)
    end)

    it("should return error for downgrade", function()
      local path, err = migrator:get_migration_path("2.0.0", "1.0.0")
      assert.is_nil(path)
      assert.has.match("Downgrade", err)
    end)
  end)

  describe("deep_copy", function()
    it("should create independent copy", function()
      local original = {
        a = { b = { c = 1 } },
        d = "test"
      }

      local copy = migrator:deep_copy(original)

      -- Modify original
      original.a.b.c = 2
      original.d = "changed"

      -- Copy should be unchanged
      assert.equals(1, copy.a.b.c)
      assert.equals("test", copy.d)
    end)
  end)
end)
