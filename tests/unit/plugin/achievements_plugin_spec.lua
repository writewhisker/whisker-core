--- Achievements Plugin Tests
-- @module tests.unit.plugin.achievements_plugin_spec

describe("Achievements Plugin", function()
  local Tracker
  local achievements_plugin
  local mock_ctx
  local tracker

  before_each(function()
    package.loaded["plugins.builtin.achievements.tracker"] = nil
    package.loaded["plugins.builtin.achievements.init"] = nil

    Tracker = require("plugins.builtin.achievements.tracker")

    -- Create mock context
    mock_ctx = {
      name = "achievements",
      version = "1.0.0",
      log = {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
      },
      state = {
        _data = {},
        get = function(key) return mock_ctx.state._data[key] end,
        set = function(key, value) mock_ctx.state._data[key] = value end,
      },
    }

    tracker = Tracker.new(mock_ctx)
    tracker:initialize()
  end)

  describe("Tracker", function()
    describe("define_achievement()", function()
      it("defines an achievement", function()
        local success, err = tracker:define_achievement({
          id = "first_step",
          name = "First Step",
          criteria = {type = "passage_visited", passage = "intro"},
        })

        assert.is_true(success)
        assert.is_nil(err)
        assert.is_not_nil(tracker:get_achievement("first_step"))
      end)

      it("requires id field", function()
        local success, err = tracker:define_achievement({
          name = "No ID",
          criteria = {type = "passage_visited", passage = "test"},
        })

        assert.is_false(success)
        assert.is_true(err:match("id") ~= nil)
      end)

      it("requires name field", function()
        local success, err = tracker:define_achievement({
          id = "no_name",
          criteria = {type = "passage_visited", passage = "test"},
        })

        assert.is_false(success)
        assert.is_true(err:match("name") ~= nil)
      end)

      it("requires criteria field", function()
        local success, err = tracker:define_achievement({
          id = "no_criteria",
          name = "No Criteria",
        })

        assert.is_false(success)
        assert.is_true(err:match("criteria") ~= nil)
      end)

      it("sets default values", function()
        tracker:define_achievement({
          id = "test",
          name = "Test",
          criteria = {type = "passage_visited", passage = "test"},
        })

        local achievement = tracker:get_achievement("test")
        assert.equal("", achievement.description)
        assert.equal(0, achievement.points)
        assert.is_false(achievement.secret)
      end)

      it("accepts custom points", function()
        tracker:define_achievement({
          id = "test",
          name = "Test",
          criteria = {type = "passage_visited", passage = "test"},
          points = 100,
        })

        local achievement = tracker:get_achievement("test")
        assert.equal(100, achievement.points)
      end)

      it("accepts secret flag", function()
        tracker:define_achievement({
          id = "secret",
          name = "Secret Achievement",
          criteria = {type = "passage_visited", passage = "secret_room"},
          secret = true,
        })

        local achievement = tracker:get_achievement("secret")
        assert.is_true(achievement.secret)
      end)
    end)

    describe("passage_visited criteria", function()
      before_each(function()
        tracker:define_achievement({
          id = "explorer",
          name = "Explorer",
          criteria = {type = "passage_visited", passage = "hidden_cave"},
        })
      end)

      it("unlocks when passage is visited", function()
        assert.is_false(tracker:is_unlocked("explorer"))

        tracker:track_passage_visit("hidden_cave")
        tracker:check_achievements()

        assert.is_true(tracker:is_unlocked("explorer"))
      end)

      it("does not unlock for different passage", function()
        tracker:track_passage_visit("other_place")
        tracker:check_achievements()

        assert.is_false(tracker:is_unlocked("explorer"))
      end)

      it("reports progress correctly", function()
        assert.equal(0, tracker:get_progress("explorer"))

        tracker:track_passage_visit("hidden_cave")
        tracker:check_achievements()

        assert.equal(1, tracker:get_progress("explorer"))
      end)
    end)

    describe("passage_count criteria", function()
      before_each(function()
        tracker:define_achievement({
          id = "wanderer",
          name = "Wanderer",
          criteria = {type = "passage_count", count = 5},
        })
      end)

      it("unlocks when passage count is reached", function()
        for i = 1, 5 do
          tracker:track_passage_visit("passage_" .. i)
        end
        tracker:check_achievements()

        assert.is_true(tracker:is_unlocked("wanderer"))
      end)

      it("tracks progress", function()
        tracker:track_passage_visit("passage_1")
        tracker:track_passage_visit("passage_2")
        tracker:check_achievements()

        assert.equal(0.4, tracker:get_progress("wanderer"))
      end)

      it("does not count same passage twice", function()
        tracker:track_passage_visit("passage_1")
        tracker:track_passage_visit("passage_1")
        tracker:track_passage_visit("passage_1")
        tracker:check_achievements()

        assert.equal(0.2, tracker:get_progress("wanderer"))
      end)
    end)

    describe("choice_count criteria", function()
      before_each(function()
        tracker:define_achievement({
          id = "decisive",
          name = "Decisive",
          criteria = {type = "choice_count", count = 10},
        })
      end)

      it("unlocks when choice count is reached", function()
        for i = 1, 10 do
          tracker:track_choice_select({id = "choice_" .. i})
        end
        tracker:check_achievements()

        assert.is_true(tracker:is_unlocked("decisive"))
      end)

      it("tracks progress", function()
        for i = 1, 5 do
          tracker:track_choice_select({id = "choice_" .. i})
        end
        tracker:check_achievements()

        assert.equal(0.5, tracker:get_progress("decisive"))
      end)
    end)

    describe("variable_threshold criteria", function()
      before_each(function()
        tracker:define_achievement({
          id = "wealthy",
          name = "Wealthy",
          criteria = {type = "variable_threshold", variable = "gold", threshold = 1000},
        })
      end)

      it("unlocks when threshold is reached", function()
        mock_ctx.state._data["gold"] = 1000
        tracker:check_achievements()

        assert.is_true(tracker:is_unlocked("wealthy"))
      end)

      it("unlocks when threshold is exceeded", function()
        mock_ctx.state._data["gold"] = 1500
        tracker:check_achievements()

        assert.is_true(tracker:is_unlocked("wealthy"))
      end)

      it("does not unlock below threshold", function()
        mock_ctx.state._data["gold"] = 500
        tracker:check_achievements()

        assert.is_false(tracker:is_unlocked("wealthy"))
      end)

      it("tracks progress", function()
        mock_ctx.state._data["gold"] = 250
        tracker:check_achievements()

        assert.equal(0.25, tracker:get_progress("wealthy"))
      end)
    end)

    describe("variable_equals criteria", function()
      before_each(function()
        tracker:define_achievement({
          id = "knight",
          name = "Knight",
          criteria = {type = "variable_equals", variable = "class", value = "knight"},
        })
      end)

      it("unlocks when variable equals value", function()
        mock_ctx.state._data["class"] = "knight"
        tracker:check_achievements()

        assert.is_true(tracker:is_unlocked("knight"))
      end)

      it("does not unlock for different value", function()
        mock_ctx.state._data["class"] = "mage"
        tracker:check_achievements()

        assert.is_false(tracker:is_unlocked("knight"))
      end)
    end)

    describe("custom criteria", function()
      it("supports custom check function", function()
        tracker:define_achievement({
          id = "custom",
          name = "Custom Achievement",
          criteria = {
            type = "custom",
            check = function(ctx, tracking_data)
              return tracking_data.passage_count >= 3
            end,
          },
        })

        tracker:track_passage_visit("p1")
        tracker:track_passage_visit("p2")
        tracker:check_achievements()
        assert.is_false(tracker:is_unlocked("custom"))

        tracker:track_passage_visit("p3")
        tracker:check_achievements()
        assert.is_true(tracker:is_unlocked("custom"))
      end)

      it("handles progress from custom function", function()
        tracker:define_achievement({
          id = "progress",
          name = "Progress Achievement",
          criteria = {
            type = "custom",
            check = function(ctx, tracking_data)
              return tracking_data.choices_made / 10
            end,
          },
        })

        for i = 1, 5 do
          tracker:track_choice_select({id = "c" .. i})
        end
        tracker:check_achievements()

        assert.equal(0.5, tracker:get_progress("progress"))
      end)

      it("handles errors in custom function", function()
        tracker:define_achievement({
          id = "error",
          name = "Error Achievement",
          criteria = {
            type = "custom",
            check = function()
              error("Test error")
            end,
          },
        })

        tracker:check_achievements()
        assert.is_false(tracker:is_unlocked("error"))
      end)
    end)

    describe("get_all_achievements()", function()
      before_each(function()
        tracker:define_achievement({
          id = "a1",
          name = "Achievement 1",
          points = 10,
          criteria = {type = "passage_visited", passage = "p1"},
        })
        tracker:define_achievement({
          id = "a2",
          name = "Achievement 2",
          points = 20,
          criteria = {type = "passage_visited", passage = "p2"},
        })
      end)

      it("returns all achievements", function()
        local all = tracker:get_all_achievements()
        assert.equal(2, #all)
      end)

      it("sorts unlocked first", function()
        tracker:track_passage_visit("p2")
        tracker:check_achievements()

        local all = tracker:get_all_achievements()
        assert.is_true(all[1].unlocked)
        assert.is_false(all[2].unlocked)
      end)

      it("hides secret achievements until unlocked", function()
        tracker:define_achievement({
          id = "secret",
          name = "Secret Achievement",
          secret = true,
          criteria = {type = "passage_visited", passage = "hidden"},
        })

        local all = tracker:get_all_achievements()
        local secret = nil
        for _, a in ipairs(all) do
          if a.id == "secret" then
            secret = a
            break
          end
        end

        assert.equal("???", secret.name)
        assert.equal("Secret achievement", secret.description)
      end)

      it("reveals secret achievements when unlocked", function()
        tracker:define_achievement({
          id = "secret",
          name = "Secret Achievement",
          description = "The real description",
          secret = true,
          criteria = {type = "passage_visited", passage = "hidden"},
        })

        tracker:track_passage_visit("hidden")
        tracker:check_achievements()

        local all = tracker:get_all_achievements()
        local secret = nil
        for _, a in ipairs(all) do
          if a.id == "secret" then
            secret = a
            break
          end
        end

        assert.equal("Secret Achievement", secret.name)
        assert.equal("The real description", secret.description)
      end)
    end)

    describe("get_unlocked_achievements()", function()
      before_each(function()
        tracker:define_achievement({
          id = "a1",
          name = "Achievement 1",
          criteria = {type = "passage_visited", passage = "p1"},
        })
        tracker:define_achievement({
          id = "a2",
          name = "Achievement 2",
          criteria = {type = "passage_visited", passage = "p2"},
        })
      end)

      it("returns only unlocked achievements", function()
        tracker:track_passage_visit("p1")
        tracker:check_achievements()

        local unlocked = tracker:get_unlocked_achievements()
        assert.equal(1, #unlocked)
        assert.equal("a1", unlocked[1].id)
      end)

      it("returns empty for no unlocks", function()
        local unlocked = tracker:get_unlocked_achievements()
        assert.equal(0, #unlocked)
      end)
    end)

    describe("get_statistics()", function()
      before_each(function()
        tracker:define_achievement({
          id = "a1",
          name = "Achievement 1",
          points = 10,
          criteria = {type = "passage_visited", passage = "p1"},
        })
        tracker:define_achievement({
          id = "a2",
          name = "Achievement 2",
          points = 20,
          criteria = {type = "passage_visited", passage = "p2"},
        })
        tracker:define_achievement({
          id = "a3",
          name = "Achievement 3",
          points = 30,
          criteria = {type = "passage_visited", passage = "p3"},
        })
      end)

      it("returns correct totals", function()
        local stats = tracker:get_statistics()

        assert.equal(3, stats.total)
        assert.equal(0, stats.unlocked)
        assert.equal(3, stats.locked)
        assert.equal(60, stats.total_points)
        assert.equal(0, stats.points)
        assert.equal(0, stats.completion)
      end)

      it("updates after unlocks", function()
        tracker:track_passage_visit("p1")
        tracker:track_passage_visit("p2")
        tracker:check_achievements()

        local stats = tracker:get_statistics()

        assert.equal(3, stats.total)
        assert.equal(2, stats.unlocked)
        assert.equal(1, stats.locked)
        assert.equal(60, stats.total_points)
        assert.equal(30, stats.points)
        assert.is_true(math.abs(stats.completion - 0.666666) < 0.001)
      end)
    end)

    describe("force_unlock()", function()
      before_each(function()
        tracker:define_achievement({
          id = "test",
          name = "Test",
          criteria = {type = "passage_visited", passage = "unreachable"},
        })
      end)

      it("unlocks achievement", function()
        local success = tracker:force_unlock("test")

        assert.is_true(success)
        assert.is_true(tracker:is_unlocked("test"))
      end)

      it("returns false for unknown achievement", function()
        local success = tracker:force_unlock("nonexistent")

        assert.is_false(success)
      end)
    end)

    describe("clear()", function()
      it("clears all achievements and state", function()
        tracker:define_achievement({
          id = "test",
          name = "Test",
          criteria = {type = "passage_visited", passage = "p1"},
        })
        tracker:track_passage_visit("p1")
        tracker:check_achievements()

        tracker:clear()

        assert.equal(0, #tracker:get_all_achievements())
        assert.equal(0, tracker.tracking_data.passage_count)
      end)
    end)

    describe("serialization", function()
      it("serializes tracking data", function()
        tracker:define_achievement({
          id = "test",
          name = "Test",
          criteria = {type = "passage_visited", passage = "p1"},
        })
        tracker:track_passage_visit("p1")
        tracker:track_passage_visit("p2")
        tracker:check_achievements()

        local data = tracker:get_tracking_data()

        assert.is_not_nil(data.passages_visited)
        assert.equal(2, data.passage_count)
      end)

      it("deserializes tracking data", function()
        local data = {
          passages_visited = {p1 = true, p2 = true},
          passage_count = 2,
          choices_made = 5,
          start_time = 12345,
        }

        tracker:set_tracking_data(data)

        assert.equal(2, tracker.tracking_data.passage_count)
        assert.equal(5, tracker.tracking_data.choices_made)
      end)
    end)
  end)

  describe("Plugin Definition", function()
    local plugin

    before_each(function()
      plugin = require("plugins.builtin.achievements.init")
    end)

    it("has required metadata", function()
      assert.equal("achievements", plugin.name)
      assert.equal("1.0.0", plugin.version)
      assert.is_true(plugin._trusted)
    end)

    it("declares core dependency", function()
      assert.is_not_nil(plugin.dependencies.core)
    end)

    it("has lifecycle hooks", function()
      assert.is_function(plugin.on_init)
      assert.is_function(plugin.on_enable)
      assert.is_function(plugin.on_disable)
      assert.is_function(plugin.on_destroy)
    end)

    it("has story event hooks", function()
      assert.is_not_nil(plugin.hooks)
      assert.is_function(plugin.hooks.on_story_start)
      assert.is_function(plugin.hooks.on_story_reset)
      assert.is_function(plugin.hooks.on_passage_enter)
      assert.is_function(plugin.hooks.on_choice_select)
      assert.is_function(plugin.hooks.on_state_change)
      assert.is_function(plugin.hooks.on_save)
      assert.is_function(plugin.hooks.on_load)
    end)

    it("exposes public API", function()
      assert.is_not_nil(plugin.api)
      assert.is_function(plugin.api.define_achievement)
      assert.is_function(plugin.api.is_unlocked)
      assert.is_function(plugin.api.get_progress)
      assert.is_function(plugin.api.get_achievement)
      assert.is_function(plugin.api.get_all_achievements)
      assert.is_function(plugin.api.get_unlocked_achievements)
      assert.is_function(plugin.api.get_statistics)
      assert.is_function(plugin.api.check_achievements)
      assert.is_function(plugin.api.force_unlock)
      assert.is_function(plugin.api.clear)
    end)
  end)
end)
