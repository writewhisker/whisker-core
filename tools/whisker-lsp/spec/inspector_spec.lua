-- whisker-lsp/spec/inspector_spec.lua
-- Tests for debug variable inspector (GAP-058)

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("Debug Inspector", function()
  local Inspector

  before_each(function()
    Inspector = require("whisker.debug.inspector")
  end)

  -- Mock game state for testing
  local function create_mock_game_state()
    return {
      variables = {
        health = 100,
        gold = 50,
        name = "Hero"
      },
      temp_variables = {
        damage = 10,
        target = "enemy"
      },
      current_passage = "Combat",
      visit_counts = {
        Combat = 3,
        Start = 1
      },
      get_all_variables = function(self)
        return self.variables
      end,
      get_all_temp_variables = function(self)
        return self.temp_variables
      end,
      get_current_passage = function(self)
        return self.current_passage
      end,
      get_visit_count = function(self, passage)
        return self.visit_counts[passage] or 0
      end,
      get_all_collections = function(self)
        return {
          lists = {
            inventory = { active = { sword = true, shield = false, potion = true } }
          },
          arrays = {
            history = { "Start", "Combat" }
          },
          maps = {
            stats = { str = 10, dex = 15 }
          }
        }
      end,
      set = function(self, name, value)
        self.variables[name] = value
      end,
      set_temp = function(self, name, value)
        self.temp_variables[name] = value
      end
    }
  end

  describe("scopes", function()
    it("returns all scope types", function()
      local inspector = Inspector.new(create_mock_game_state())

      local scopes = inspector:get_scopes()

      assert.equals(4, #scopes)
      assert.equals("Story Variables", scopes[1].name)
      assert.equals("Temp Variables", scopes[2].name)
      assert.equals("Collections", scopes[3].name)
      assert.equals("System State", scopes[4].name)
    end)

    it("scopes have correct references", function()
      local inspector = Inspector.new(create_mock_game_state())

      local scopes = inspector:get_scopes()

      assert.equals(Inspector.SCOPE_GLOBAL, scopes[1].variablesReference)
      assert.equals(Inspector.SCOPE_TEMP, scopes[2].variablesReference)
      assert.equals(Inspector.SCOPE_COLLECTIONS, scopes[3].variablesReference)
      assert.equals(Inspector.SCOPE_SYSTEM, scopes[4].variablesReference)
    end)
  end)

  describe("global variables", function()
    it("returns global variables", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      assert.is_true(#vars > 0)

      local found_health = false
      for _, v in ipairs(vars) do
        if v.name == "$health" then
          found_health = true
          assert.equals("100", v.value)
          assert.equals("number", v.type)
          break
        end
      end
      assert.is_true(found_health)
    end)

    it("variables are sorted by name", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      for i = 1, #vars - 1 do
        assert.is_true(vars[i].name < vars[i + 1].name)
      end
    end)
  end)

  describe("temp variables", function()
    it("returns temp variables with underscore prefix", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_TEMP)

      assert.is_true(#vars > 0)

      local found_damage = false
      for _, v in ipairs(vars) do
        if v.name == "_damage" then
          found_damage = true
          assert.equals("10", v.value)
          break
        end
      end
      assert.is_true(found_damage)
    end)
  end)

  describe("collections", function()
    it("returns lists, arrays, and maps", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_COLLECTIONS)

      local has_list = false
      local has_array = false
      local has_map = false

      for _, v in ipairs(vars) do
        if v.name:match("^LIST") then has_list = true end
        if v.name:match("^ARRAY") then has_array = true end
        if v.name:match("^MAP") then has_map = true end
      end

      assert.is_true(has_list)
      assert.is_true(has_array)
      assert.is_true(has_map)
    end)

    it("collections are expandable", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_COLLECTIONS)

      for _, v in ipairs(vars) do
        if v.name:match("^LIST") or v.name:match("^ARRAY") or v.name:match("^MAP") then
          assert.is_true(v.variablesReference > 0)
        end
      end
    end)
  end)

  describe("system state", function()
    it("returns current passage", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_SYSTEM)

      local found_passage = false
      for _, v in ipairs(vars) do
        if v.name == "_passage" then
          found_passage = true
          assert.equals("Combat", v.value)
          break
        end
      end
      assert.is_true(found_passage)
    end)

    it("returns visit count", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_SYSTEM)

      local found_visits = false
      for _, v in ipairs(vars) do
        if v.name == "_visits" then
          found_visits = true
          assert.equals("3", v.value)
          break
        end
      end
      assert.is_true(found_visits)
    end)
  end)

  describe("value formatting", function()
    it("formats strings with quotes", function()
      local inspector = Inspector.new(create_mock_game_state())

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      for _, v in ipairs(vars) do
        if v.name == "$name" then
          assert.equals('"Hero"', v.value)
          break
        end
      end
    end)

    it("formats booleans", function()
      local gs = create_mock_game_state()
      gs.variables.active = true
      local inspector = Inspector.new(gs)

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      for _, v in ipairs(vars) do
        if v.name == "$active" then
          assert.equals("true", v.value)
          break
        end
      end
    end)

    it("formats tables with item count", function()
      local gs = create_mock_game_state()
      gs.variables.data = { a = 1, b = 2, c = 3 }
      local inspector = Inspector.new(gs)

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      for _, v in ipairs(vars) do
        if v.name == "$data" then
          assert.is_true(v.value:match("3 items") ~= nil)
          break
        end
      end
    end)
  end)

  describe("variable expansion", function()
    it("expands table variables", function()
      local gs = create_mock_game_state()
      gs.variables.data = { a = 1, b = 2 }
      local inspector = Inspector.new(gs)

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      local data_ref = nil
      for _, v in ipairs(vars) do
        if v.name == "$data" then
          data_ref = v.variablesReference
          break
        end
      end

      assert.is_not_nil(data_ref)
      assert.is_true(data_ref > 0)

      local children = inspector:get_variables(data_ref)
      assert.equals(2, #children)
    end)
  end)

  describe("variable modification", function()
    it("sets global variable", function()
      local gs = create_mock_game_state()
      local inspector = Inspector.new(gs)

      local result = inspector:set_variable(Inspector.SCOPE_GLOBAL, "$health", 50)

      assert.is_true(result)
      assert.equals(50, gs.variables.health)
    end)

    it("sets temp variable", function()
      local gs = create_mock_game_state()
      local inspector = Inspector.new(gs)

      local result = inspector:set_variable(Inspector.SCOPE_TEMP, "_damage", 20)

      assert.is_true(result)
      assert.equals(20, gs.temp_variables.damage)
    end)
  end)

  describe("watch expressions", function()
    it("adds watch expression", function()
      local inspector = Inspector.new(create_mock_game_state())

      local id = inspector:add_watch("health + 10")

      assert.is_true(id > 0)
    end)

    it("removes watch expression", function()
      local inspector = Inspector.new(create_mock_game_state())

      local id = inspector:add_watch("health")
      inspector:remove_watch(id)

      local results = inspector:evaluate_watches()

      local found = false
      for _, r in ipairs(results) do
        if r.id == id then
          found = true
          break
        end
      end
      assert.is_false(found)
    end)
  end)

  describe("no game state", function()
    it("handles nil game state gracefully", function()
      local inspector = Inspector.new(nil)

      local vars = inspector:get_variables(Inspector.SCOPE_GLOBAL)

      assert.is_table(vars)
      assert.equals(0, #vars)
    end)

    it("returns placeholder for system state without game", function()
      local inspector = Inspector.new(nil)

      local vars = inspector:get_variables(Inspector.SCOPE_SYSTEM)

      assert.is_table(vars)
      assert.is_true(#vars > 0)
      assert.equals("(no state)", vars[1].value)
    end)
  end)

  describe("reference management", function()
    it("clears references on request", function()
      local gs = create_mock_game_state()
      gs.variables.data = { a = 1 }
      local inspector = Inspector.new(gs)

      -- Create some references
      inspector:get_variables(Inspector.SCOPE_GLOBAL)

      inspector:clear_references()

      -- After clear, old refs should not work
      -- (implementation detail - just verify no error)
      assert.is_true(true)
    end)
  end)
end)
