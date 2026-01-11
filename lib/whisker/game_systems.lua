--[[
  Game Systems Library
  
  Reusable game mechanics for interactive fiction.
  
  Systems included:
  - Inventory management
  - Combat system
  - Quest tracking
  - Stats & attributes
  
  Usage:
    local GameSystems = require("whisker.game_systems")
    local inventory = GameSystems.Inventory.new()
    local combat = GameSystems.Combat.new()
]]

local GameSystems = {}

-- ============================================================================
-- INVENTORY SYSTEM
-- ============================================================================

GameSystems.Inventory = {}
GameSystems.Inventory.__index = GameSystems.Inventory

function GameSystems.Inventory.new(options)
  options = options or {}
  
  local self = setmetatable({
    items = {},
    capacity = options.capacity or nil,  -- nil = unlimited
    weight_limit = options.weight_limit or nil
  }, GameSystems.Inventory)
  
  return self
end

function GameSystems.Inventory:add_item(item, quantity)
  quantity = quantity or 1
  
  -- Check capacity
  if self.capacity and self:get_item_count() + quantity > self.capacity then
    return false, "Inventory full"
  end
  
  -- Check weight
  if self.weight_limit and item.weight then
    local total_weight = self:get_total_weight() + (item.weight * quantity)
    if total_weight > self.weight_limit then
      return false, "Too heavy"
    end
  end
  
  -- Add item
  local item_id = item.id or item.name
  if not self.items[item_id] then
    self.items[item_id] = {
      item = item,
      quantity = 0
    }
  end
  
  self.items[item_id].quantity = self.items[item_id].quantity + quantity
  return true
end

function GameSystems.Inventory:remove_item(item_id, quantity)
  quantity = quantity or 1
  
  if not self.items[item_id] then
    return false, "Item not found"
  end
  
  if self.items[item_id].quantity < quantity then
    return false, "Not enough items"
  end
  
  self.items[item_id].quantity = self.items[item_id].quantity - quantity
  
  if self.items[item_id].quantity == 0 then
    self.items[item_id] = nil
  end
  
  return true
end

function GameSystems.Inventory:has_item(item_id, quantity)
  quantity = quantity or 1
  return self.items[item_id] and self.items[item_id].quantity >= quantity
end

function GameSystems.Inventory:get_item_count()
  local count = 0
  for _, entry in pairs(self.items) do
    count = count + entry.quantity
  end
  return count
end

function GameSystems.Inventory:get_total_weight()
  local weight = 0
  for _, entry in pairs(self.items) do
    if entry.item.weight then
      weight = weight + (entry.item.weight * entry.quantity)
    end
  end
  return weight
end

function GameSystems.Inventory:list_items()
  local items = {}
  for id, entry in pairs(self.items) do
    table.insert(items, {
      id = id,
      item = entry.item,
      quantity = entry.quantity
    })
  end
  return items
end

-- ============================================================================
-- COMBAT SYSTEM
-- ============================================================================

GameSystems.Combat = {}
GameSystems.Combat.__index = GameSystems.Combat

function GameSystems.Combat.new(options)
  options = options or {}
  
  local self = setmetatable({
    combatants = {},
    turn = 1,
    active_combatant = nil
  }, GameSystems.Combat)
  
  return self
end

function GameSystems.Combat:add_combatant(combatant)
  table.insert(self.combatants, {
    id = combatant.id or combatant.name,
    name = combatant.name,
    hp = combatant.hp or combatant.max_hp or 100,
    max_hp = combatant.max_hp or 100,
    attack = combatant.attack or 10,
    defense = combatant.defense or 5,
    speed = combatant.speed or 10,
    is_alive = true
  })
end

function GameSystems.Combat:get_combatant(id)
  for _, c in ipairs(self.combatants) do
    if c.id == id then
      return c
    end
  end
  return nil
end

function GameSystems.Combat:attack(attacker_id, target_id)
  local attacker = self:get_combatant(attacker_id)
  local target = self:get_combatant(target_id)
  
  if not attacker or not target then
    return nil, "Invalid combatant"
  end
  
  if not attacker.is_alive or not target.is_alive then
    return nil, "Combatant is dead"
  end
  
  -- Calculate damage
  local base_damage = attacker.attack
  local defense_reduction = target.defense * 0.5
  local damage = math.max(1, math.floor(base_damage - defense_reduction))
  
  -- Add randomness (80-120%)
  local random_factor = 0.8 + (math.random() * 0.4)
  damage = math.floor(damage * random_factor)
  
  -- Apply damage
  target.hp = target.hp - damage
  
  if target.hp <= 0 then
    target.hp = 0
    target.is_alive = false
  end
  
  return {
    attacker = attacker.name,
    target = target.name,
    damage = damage,
    target_hp = target.hp,
    target_alive = target.is_alive
  }
end

function GameSystems.Combat:is_combat_over()
  local alive_count = 0
  for _, c in ipairs(self.combatants) do
    if c.is_alive then
      alive_count = alive_count + 1
    end
  end
  return alive_count <= 1
end

function GameSystems.Combat:get_winners()
  local winners = {}
  for _, c in ipairs(self.combatants) do
    if c.is_alive then
      table.insert(winners, c)
    end
  end
  return winners
end

-- ============================================================================
-- QUEST SYSTEM
-- ============================================================================

GameSystems.Quest = {}
GameSystems.Quest.__index = GameSystems.Quest

function GameSystems.Quest.new(quest_data)
  local self = setmetatable({
    id = quest_data.id,
    title = quest_data.title,
    description = quest_data.description,
    objectives = quest_data.objectives or {},
    status = "active",  -- active, completed, failed
    rewards = quest_data.rewards or {}
  }, GameSystems.Quest)
  
  return self
end

function GameSystems.Quest:complete_objective(objective_id)
  for _, obj in ipairs(self.objectives) do
    if obj.id == objective_id then
      obj.completed = true
      return true
    end
  end
  return false
end

function GameSystems.Quest:is_completed()
  for _, obj in ipairs(self.objectives) do
    if not obj.completed then
      return false
    end
  end
  return true
end

function GameSystems.Quest:complete()
  self.status = "completed"
end

function GameSystems.Quest:fail()
  self.status = "failed"
end

-- ============================================================================
-- STATS SYSTEM
-- ============================================================================

GameSystems.Stats = {}
GameSystems.Stats.__index = GameSystems.Stats

function GameSystems.Stats.new(initial_stats)
  local self = setmetatable({
    stats = initial_stats or {},
    modifiers = {}
  }, GameSystems.Stats)
  
  return self
end

function GameSystems.Stats:set(stat_name, value)
  self.stats[stat_name] = value
end

function GameSystems.Stats:get(stat_name)
  local base = self.stats[stat_name] or 0
  local modifier = self.modifiers[stat_name] or 0
  return base + modifier
end

function GameSystems.Stats:add_modifier(stat_name, value, duration)
  if not self.modifiers[stat_name] then
    self.modifiers[stat_name] = 0
  end
  self.modifiers[stat_name] = self.modifiers[stat_name] + value
end

function GameSystems.Stats:remove_modifier(stat_name, value)
  if self.modifiers[stat_name] then
    self.modifiers[stat_name] = self.modifiers[stat_name] - value
  end
end

return GameSystems
