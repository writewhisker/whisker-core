--- Inventory Plugin Tests
-- @module tests.unit.plugin.inventory_plugin_spec

describe("Inventory Plugin", function()
  local Storage
  local inventory_plugin
  local mock_ctx
  local storage

  before_each(function()
    package.loaded["plugins.builtin.inventory.storage"] = nil
    package.loaded["plugins.builtin.inventory.init"] = nil

    Storage = require("plugins.builtin.inventory.storage")

    -- Create mock context
    mock_ctx = {
      name = "inventory",
      version = "1.0.0",
      log = {
        debug = function() end,
        info = function() end,
        warn = function() end,
        error = function() end,
      },
      storage = {
        _data = {},
        get = function(key) return mock_ctx.storage._data[key] end,
        set = function(key, value) mock_ctx.storage._data[key] = value end,
      },
    }

    storage = Storage.new(mock_ctx)
    storage:initialize()
  end)

  describe("Storage", function()
    describe("add_item()", function()
      it("adds item to inventory", function()
        local success, err = storage:add_item({
          id = "sword",
          name = "Iron Sword",
        })

        assert.is_true(success)
        assert.is_nil(err)
        assert.is_true(storage:has_item("sword"))
      end)

      it("requires id field", function()
        local success, err = storage:add_item({name = "Nameless"})

        assert.is_false(success)
        assert.is_true(err:match("id") ~= nil)
      end)

      it("requires name field", function()
        local success, err = storage:add_item({id = "unnamed"})

        assert.is_false(success)
        assert.is_true(err:match("name") ~= nil)
      end)

      it("uses default quantity of 1", function()
        storage:add_item({id = "sword", name = "Sword"})

        local item = storage:get_item("sword")
        assert.equal(1, item.quantity)
      end)

      it("accepts custom quantity", function()
        storage:add_item({id = "potion", name = "Potion", quantity = 5})

        local item = storage:get_item("potion")
        assert.equal(5, item.quantity)
      end)

      it("stacks items with same id", function()
        storage:add_item({id = "coin", name = "Gold Coin", quantity = 10})
        storage:add_item({id = "coin", name = "Gold Coin", quantity = 5})

        local item = storage:get_item("coin")
        assert.equal(15, item.quantity)
      end)

      it("stores description", function()
        storage:add_item({
          id = "key",
          name = "Rusty Key",
          description = "An old key",
        })

        local item = storage:get_item("key")
        assert.equal("An old key", item.description)
      end)

      it("stores tags", function()
        storage:add_item({
          id = "sword",
          name = "Iron Sword",
          tags = {"weapon", "melee"},
        })

        local item = storage:get_item("sword")
        assert.equal(2, #item.tags)
      end)

      it("stores metadata", function()
        storage:add_item({
          id = "sword",
          name = "Iron Sword",
          metadata = {damage = 10, durability = 100},
        })

        local item = storage:get_item("sword")
        assert.equal(10, item.metadata.damage)
        assert.equal(100, item.metadata.durability)
      end)

      it("respects capacity limit", function()
        storage:set_capacity(2)

        storage:add_item({id = "item1", name = "Item 1"})
        storage:add_item({id = "item2", name = "Item 2"})
        local success, err = storage:add_item({id = "item3", name = "Item 3"})

        assert.is_false(success)
        assert.is_true(err:match("full") ~= nil)
      end)

      it("allows stacking even at capacity", function()
        storage:set_capacity(1)

        storage:add_item({id = "item1", name = "Item 1"})
        local success = storage:add_item({id = "item1", name = "Item 1"})

        assert.is_true(success)
        assert.equal(2, storage:get_item("item1").quantity)
      end)
    end)

    describe("remove_item()", function()
      before_each(function()
        storage:add_item({id = "potion", name = "Potion", quantity = 5})
      end)

      it("removes item quantity", function()
        local success = storage:remove_item("potion", 2)

        assert.is_true(success)
        assert.equal(3, storage:get_item("potion").quantity)
      end)

      it("defaults to removing 1", function()
        storage:remove_item("potion")

        assert.equal(4, storage:get_item("potion").quantity)
      end)

      it("removes item when quantity reaches 0", function()
        storage:remove_item("potion", 5)

        assert.is_false(storage:has_item("potion"))
      end)

      it("fails for non-existent item", function()
        local success, err = storage:remove_item("nonexistent")

        assert.is_false(success)
        assert.is_not_nil(err)
      end)

      it("fails when not enough quantity", function()
        local success, err = storage:remove_item("potion", 10)

        assert.is_false(success)
        assert.is_true(err:match("Not enough") ~= nil)
      end)
    end)

    describe("has_item()", function()
      before_each(function()
        storage:add_item({id = "sword", name = "Sword", quantity = 3})
      end)

      it("returns true for existing item", function()
        assert.is_true(storage:has_item("sword"))
      end)

      it("returns false for missing item", function()
        assert.is_false(storage:has_item("shield"))
      end)

      it("checks quantity requirement", function()
        assert.is_true(storage:has_item("sword", 3))
        assert.is_false(storage:has_item("sword", 5))
      end)
    end)

    describe("get_all_items()", function()
      it("returns empty array for empty inventory", function()
        local items = storage:get_all_items()
        assert.equal(0, #items)
      end)

      it("returns all items", function()
        storage:add_item({id = "a", name = "Item A"})
        storage:add_item({id = "b", name = "Item B"})
        storage:add_item({id = "c", name = "Item C"})

        local items = storage:get_all_items()
        assert.equal(3, #items)
      end)

      it("returns items sorted by name", function()
        storage:add_item({id = "c", name = "Zebra"})
        storage:add_item({id = "a", name = "Apple"})
        storage:add_item({id = "b", name = "Ball"})

        local items = storage:get_all_items()
        assert.equal("Apple", items[1].name)
        assert.equal("Ball", items[2].name)
        assert.equal("Zebra", items[3].name)
      end)
    end)

    describe("get_items_by_tag()", function()
      before_each(function()
        storage:add_item({id = "sword", name = "Sword", tags = {"weapon", "melee"}})
        storage:add_item({id = "bow", name = "Bow", tags = {"weapon", "ranged"}})
        storage:add_item({id = "potion", name = "Potion", tags = {"consumable"}})
      end)

      it("finds items with matching tag", function()
        local weapons = storage:get_items_by_tag("weapon")
        assert.equal(2, #weapons)
      end)

      it("returns empty for no matches", function()
        local armor = storage:get_items_by_tag("armor")
        assert.equal(0, #armor)
      end)

      it("finds items with specific tag", function()
        local melee = storage:get_items_by_tag("melee")
        assert.equal(1, #melee)
        assert.equal("Sword", melee[1].name)
      end)
    end)

    describe("clear()", function()
      it("removes all items", function()
        storage:add_item({id = "a", name = "A"})
        storage:add_item({id = "b", name = "B"})

        storage:clear()

        assert.equal(0, storage:get_item_count())
      end)
    end)

    describe("serialization", function()
      it("serializes inventory state", function()
        storage:add_item({id = "sword", name = "Sword"})
        storage:set_capacity(50)

        local state = storage:serialize()

        assert.is_not_nil(state.items)
        assert.is_not_nil(state.items.sword)
        assert.equal(50, state.capacity)
      end)

      it("deserializes inventory state", function()
        local state = {
          items = {
            sword = {id = "sword", name = "Sword", quantity = 1},
          },
          capacity = 25,
        }

        storage:deserialize(state)

        assert.is_true(storage:has_item("sword"))
        assert.equal(25, storage:get_capacity())
      end)
    end)

    describe("update_item_metadata()", function()
      before_each(function()
        storage:add_item({
          id = "sword",
          name = "Sword",
          metadata = {durability = 100},
        })
      end)

      it("updates metadata", function()
        storage:update_item_metadata("sword", {durability = 80})

        local item = storage:get_item("sword")
        assert.equal(80, item.metadata.durability)
      end)

      it("adds new metadata keys", function()
        storage:update_item_metadata("sword", {enchanted = true})

        local item = storage:get_item("sword")
        assert.is_true(item.metadata.enchanted)
        assert.equal(100, item.metadata.durability)  -- Original preserved
      end)

      it("returns false for missing item", function()
        local success = storage:update_item_metadata("nonexistent", {})
        assert.is_false(success)
      end)
    end)

    describe("set_item_quantity()", function()
      before_each(function()
        storage:add_item({id = "potion", name = "Potion", quantity = 5})
      end)

      it("sets quantity", function()
        storage:set_item_quantity("potion", 10)

        local item = storage:get_item("potion")
        assert.equal(10, item.quantity)
      end)

      it("removes item when quantity is 0", function()
        storage:set_item_quantity("potion", 0)

        assert.is_false(storage:has_item("potion"))
      end)

      it("returns false for missing item", function()
        local success = storage:set_item_quantity("nonexistent", 5)
        assert.is_false(success)
      end)
    end)
  end)

  describe("Plugin Definition", function()
    local plugin

    before_each(function()
      plugin = require("plugins.builtin.inventory.init")
    end)

    it("has required metadata", function()
      assert.equal("inventory", plugin.name)
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
    end)

    it("has story event hooks", function()
      assert.is_not_nil(plugin.hooks)
      assert.is_function(plugin.hooks.on_story_start)
      assert.is_function(plugin.hooks.on_save)
      assert.is_function(plugin.hooks.on_load)
    end)

    it("exposes public API", function()
      assert.is_not_nil(plugin.api)
      assert.is_function(plugin.api.add_item)
      assert.is_function(plugin.api.remove_item)
      assert.is_function(plugin.api.has_item)
      assert.is_function(plugin.api.get_item)
      assert.is_function(plugin.api.get_all_items)
      assert.is_function(plugin.api.get_items_by_tag)
      assert.is_function(plugin.api.clear)
    end)
  end)
end)
