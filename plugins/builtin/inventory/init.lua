--- Inventory Plugin
-- Item management for interactive fiction stories
-- @module plugins.builtin.inventory
-- @author whisker-core
-- @license MIT

-- Local reference to storage module
local Storage = require("plugins.builtin.inventory.storage")

-- Plugin internal state
local inventory_plugin = {
  _storage = nil,
  _ctx = nil,
}

-- Plugin definition
return {
  name = "inventory",
  version = "1.0.0",
  _trusted = true,

  author = "whisker-core",
  description = "Item inventory management for stories",
  license = "MIT",

  dependencies = {
    core = "^1.0.0",
  },

  capabilities = {
    "state:read",
    "state:write",
    "persistence:read",
    "persistence:write",
  },

  -- Lifecycle hooks
  on_init = function(ctx)
    inventory_plugin._ctx = ctx
    inventory_plugin._storage = Storage.new(ctx)
    ctx.log.debug("Inventory plugin initialized")
  end,

  on_enable = function(ctx)
    ctx.log.debug("Inventory plugin enabled")
  end,

  on_disable = function(ctx)
    ctx.log.debug("Inventory plugin disabled")
  end,

  on_destroy = function(ctx)
    inventory_plugin._storage = nil
    inventory_plugin._ctx = nil
  end,

  -- Story event hooks (registered with hook manager)
  hooks = {
    on_story_start = function(ctx)
      if inventory_plugin._storage then
        inventory_plugin._storage:initialize()
      end
    end,

    on_story_reset = function(ctx)
      if inventory_plugin._storage then
        inventory_plugin._storage:initialize()
      end
    end,

    on_save = function(save_data, ctx)
      if inventory_plugin._storage then
        save_data.inventory = inventory_plugin._storage:serialize()
      end
      return save_data
    end,

    on_load = function(save_data, ctx)
      if save_data.inventory and inventory_plugin._storage then
        inventory_plugin._storage:deserialize(save_data.inventory)
      end
      return save_data
    end,
  },

  -- Public API exposed to story scripts
  api = {
    --- Add item to inventory
    -- @param item table Item definition {id, name, description, tags, quantity, metadata}
    -- @return boolean success
    -- @return string|nil error
    add_item = function(item)
      if not inventory_plugin._storage then
        return false, "Inventory not initialized"
      end
      return inventory_plugin._storage:add_item(item)
    end,

    --- Remove item from inventory
    -- @param item_id string Item identifier
    -- @param quantity number|nil Amount to remove (default 1)
    -- @return boolean success
    -- @return string|nil error
    remove_item = function(item_id, quantity)
      if not inventory_plugin._storage then
        return false, "Inventory not initialized"
      end
      return inventory_plugin._storage:remove_item(item_id, quantity)
    end,

    --- Check if inventory contains item
    -- @param item_id string Item identifier
    -- @param quantity number|nil Required quantity (default 1)
    -- @return boolean
    has_item = function(item_id, quantity)
      if not inventory_plugin._storage then
        return false
      end
      return inventory_plugin._storage:has_item(item_id, quantity)
    end,

    --- Get item details
    -- @param item_id string Item identifier
    -- @return table|nil Item data
    get_item = function(item_id)
      if not inventory_plugin._storage then
        return nil
      end
      return inventory_plugin._storage:get_item(item_id)
    end,

    --- Get all items
    -- @return table[] Array of items
    get_all_items = function()
      if not inventory_plugin._storage then
        return {}
      end
      return inventory_plugin._storage:get_all_items()
    end,

    --- Get items matching a tag
    -- @param tag string Tag to filter by
    -- @return table[] Array of matching items
    get_items_by_tag = function(tag)
      if not inventory_plugin._storage then
        return {}
      end
      return inventory_plugin._storage:get_items_by_tag(tag)
    end,

    --- Get number of unique items
    -- @return number
    get_item_count = function()
      if not inventory_plugin._storage then
        return 0
      end
      return inventory_plugin._storage:get_item_count()
    end,

    --- Get total quantity of all items
    -- @return number
    get_total_quantity = function()
      if not inventory_plugin._storage then
        return 0
      end
      return inventory_plugin._storage:get_total_quantity()
    end,

    --- Clear all items from inventory
    clear = function()
      if not inventory_plugin._storage then
        return
      end
      inventory_plugin._storage:clear()
    end,

    --- Set inventory capacity
    -- @param capacity number Maximum unique items
    set_capacity = function(capacity)
      if not inventory_plugin._storage then
        return
      end
      inventory_plugin._storage:set_capacity(capacity)
    end,

    --- Get inventory capacity
    -- @return number
    get_capacity = function()
      if not inventory_plugin._storage then
        return 0
      end
      return inventory_plugin._storage:get_capacity()
    end,

    --- Update item metadata
    -- @param item_id string Item identifier
    -- @param metadata table Metadata to merge
    -- @return boolean success
    update_item_metadata = function(item_id, metadata)
      if not inventory_plugin._storage then
        return false
      end
      return inventory_plugin._storage:update_item_metadata(item_id, metadata)
    end,

    --- Set item quantity directly
    -- @param item_id string Item identifier
    -- @param quantity number New quantity
    -- @return boolean success
    set_item_quantity = function(item_id, quantity)
      if not inventory_plugin._storage then
        return false
      end
      return inventory_plugin._storage:set_item_quantity(item_id, quantity)
    end,
  },
}
