--- Inventory Storage Module
-- Manages inventory state and item operations
-- @module plugins.builtin.inventory.storage
-- @author whisker-core
-- @license MIT

local Storage = {}
Storage.__index = Storage

--- Create new storage instance
-- @param ctx PluginContext Plugin context
-- @return Storage
function Storage.new(ctx)
  local self = setmetatable({}, Storage)

  self.ctx = ctx
  self.items = {}       -- item_id -> item data
  self.capacity = 100   -- Default capacity

  return self
end

--- Initialize empty inventory
function Storage:initialize()
  self.items = {}
  self:save_to_storage()
  if self.ctx and self.ctx.log then
    self.ctx.log.debug("Inventory initialized")
  end
end

--- Add item to inventory
-- @param item table Item definition {id, name, description, tags, quantity, metadata}
-- @return boolean success
-- @return string|nil error
function Storage:add_item(item)
  -- Validate item
  if not item then
    return false, "Item is nil"
  end

  if not item.id then
    return false, "Item must have 'id' field"
  end

  if not item.name then
    return false, "Item must have 'name' field"
  end

  -- Check capacity for new items
  if not self:has_item(item.id) then
    local item_count = 0
    for _ in pairs(self.items) do
      item_count = item_count + 1
    end

    if item_count >= self.capacity then
      return false, "Inventory full"
    end
  end

  -- Add or stack item
  local quantity = item.quantity or 1

  if self.items[item.id] then
    -- Stack existing item
    self.items[item.id].quantity = self.items[item.id].quantity + quantity
  else
    -- Add new item
    self.items[item.id] = {
      id = item.id,
      name = item.name,
      description = item.description or "",
      tags = item.tags or {},
      quantity = quantity,
      metadata = item.metadata or {},
    }
  end

  self:save_to_storage()

  if self.ctx and self.ctx.log then
    self.ctx.log.debug(string.format(
      "Added item: %s (qty: %d)",
      item.name,
      quantity
    ))
  end

  return true
end

--- Remove item from inventory
-- @param item_id string Item identifier
-- @param quantity number|nil Amount to remove (default 1)
-- @return boolean success
-- @return string|nil error
function Storage:remove_item(item_id, quantity)
  quantity = quantity or 1

  if not self.items[item_id] then
    return false, "Item not in inventory: " .. tostring(item_id)
  end

  local item = self.items[item_id]

  if item.quantity < quantity then
    return false, string.format(
      "Not enough items: have %d, need %d",
      item.quantity,
      quantity
    )
  end

  item.quantity = item.quantity - quantity

  -- Remove if quantity reaches zero
  if item.quantity <= 0 then
    self.items[item_id] = nil
  end

  self:save_to_storage()

  if self.ctx and self.ctx.log then
    self.ctx.log.debug(string.format(
      "Removed item: %s (qty: %d)",
      item_id,
      quantity
    ))
  end

  return true
end

--- Check if inventory contains item
-- @param item_id string Item identifier
-- @param quantity number|nil Required quantity (default 1)
-- @return boolean
function Storage:has_item(item_id, quantity)
  quantity = quantity or 1

  if not self.items[item_id] then
    return false
  end

  return self.items[item_id].quantity >= quantity
end

--- Get item details
-- @param item_id string Item identifier
-- @return table|nil Item data
function Storage:get_item(item_id)
  return self.items[item_id]
end

--- Get all items
-- @return table[] Array of items sorted by name
function Storage:get_all_items()
  local items = {}
  for _, item in pairs(self.items) do
    table.insert(items, item)
  end

  -- Sort by name for consistent ordering
  table.sort(items, function(a, b)
    return a.name < b.name
  end)

  return items
end

--- Get items matching a tag
-- @param tag string Tag to filter by
-- @return table[] Array of matching items
function Storage:get_items_by_tag(tag)
  local items = {}

  for _, item in pairs(self.items) do
    for _, item_tag in ipairs(item.tags) do
      if item_tag == tag then
        table.insert(items, item)
        break
      end
    end
  end

  return items
end

--- Clear all items from inventory
function Storage:clear()
  self.items = {}
  self:save_to_storage()

  if self.ctx and self.ctx.log then
    self.ctx.log.debug("Inventory cleared")
  end
end

--- Get total number of unique items
-- @return number
function Storage:get_item_count()
  local count = 0
  for _ in pairs(self.items) do
    count = count + 1
  end
  return count
end

--- Get total quantity of all items
-- @return number
function Storage:get_total_quantity()
  local total = 0
  for _, item in pairs(self.items) do
    total = total + item.quantity
  end
  return total
end

--- Set inventory capacity
-- @param capacity number Maximum unique items
function Storage:set_capacity(capacity)
  self.capacity = capacity
end

--- Get inventory capacity
-- @return number
function Storage:get_capacity()
  return self.capacity
end

--- Serialize inventory for saving
-- @return table Serialized state
function Storage:serialize()
  return {
    items = self.items,
    capacity = self.capacity,
  }
end

--- Deserialize inventory from save
-- @param state table Saved state
function Storage:deserialize(state)
  self.items = state.items or {}
  self.capacity = state.capacity or 100

  if self.ctx and self.ctx.log then
    self.ctx.log.debug(string.format(
      "Inventory restored: %d items",
      self:get_item_count()
    ))
  end
end

--- Save inventory to plugin storage
function Storage:save_to_storage()
  if self.ctx and self.ctx.storage then
    self.ctx.storage.set("inventory_data", {
      items = self.items,
      capacity = self.capacity,
    })
  end
end

--- Load inventory from plugin storage
function Storage:load_from_storage()
  if self.ctx and self.ctx.storage then
    local data = self.ctx.storage.get("inventory_data")
    if data then
      self.items = data.items or {}
      self.capacity = data.capacity or 100
    end
  end
end

--- Update item metadata
-- @param item_id string Item identifier
-- @param metadata table Metadata to merge
-- @return boolean success
function Storage:update_item_metadata(item_id, metadata)
  if not self.items[item_id] then
    return false
  end

  for k, v in pairs(metadata) do
    self.items[item_id].metadata[k] = v
  end

  self:save_to_storage()
  return true
end

--- Update item quantity directly
-- @param item_id string Item identifier
-- @param quantity number New quantity
-- @return boolean success
function Storage:set_item_quantity(item_id, quantity)
  if not self.items[item_id] then
    return false
  end

  if quantity <= 0 then
    self.items[item_id] = nil
  else
    self.items[item_id].quantity = quantity
  end

  self:save_to_storage()
  return true
end

return Storage
