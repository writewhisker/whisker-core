--- Operational Transform (OT) System
-- Real-time collaborative editing with conflict resolution
--
-- @module whisker.collaboration.ot
-- @author Whisker Team
-- @license MIT
-- @usage
-- local OT = require("whisker.collaboration.ot")
-- local op1_prime = OT.transform(op1, op2)

local OT = {}

--- Operation types
OT.Type = {
  INSERT = "insert",
  DELETE = "delete",
  RETAIN = "retain"
}

--- Create INSERT operation
-- @param position number Insert position
-- @param text string Text to insert
-- @return table operation INSERT operation
function OT.insert(position, text)
  return {
    type = OT.Type.INSERT,
    position = position,
    text = text
  }
end

--- Create DELETE operation
-- @param position number Delete position
-- @param length number Length to delete
-- @return table operation DELETE operation
function OT.delete(position, length)
  return {
    type = OT.Type.DELETE,
    position = position,
    length = length
  }
end

--- Create RETAIN operation
-- @param length number Length to retain
-- @return table operation RETAIN operation
function OT.retain(length)
  return {
    type = OT.Type.RETAIN,
    length = length
  }
end

--- Transform operation A against operation B
-- When two operations happen concurrently, they must be transformed
-- against each other to maintain consistency
-- @param op_a table Operation A
-- @param op_b table Operation B
-- @return table op_a_prime Transformed operation A
function OT.transform(op_a, op_b)
  -- INSERT vs INSERT
  if op_a.type == OT.Type.INSERT and op_b.type == OT.Type.INSERT then
    if op_a.position < op_b.position then
      return op_a  -- A happens before B, no change
    elseif op_a.position > op_b.position then
      -- B inserted before A, adjust A's position
      return OT.insert(op_a.position + #op_b.text, op_a.text)
    else
      -- Same position, B wins (arbitrary tie-breaker)
      return OT.insert(op_a.position + #op_b.text, op_a.text)
    end
  end
  
  -- INSERT vs DELETE
  if op_a.type == OT.Type.INSERT and op_b.type == OT.Type.DELETE then
    if op_a.position <= op_b.position then
      return op_a  -- A before B's deletion
    elseif op_a.position >= op_b.position + op_b.length then
      -- A after B's deletion, adjust position
      return OT.insert(op_a.position - op_b.length, op_a.text)
    else
      -- A is within B's deletion range, insert at deletion point
      return OT.insert(op_b.position, op_a.text)
    end
  end
  
  -- DELETE vs INSERT
  if op_a.type == OT.Type.DELETE and op_b.type == OT.Type.INSERT then
    if op_a.position < op_b.position then
      return op_a  -- A before B
    elseif op_a.position >= op_b.position then
      -- B inserted before A, adjust A's position
      return OT.delete(op_a.position + #op_b.text, op_a.length)
    end
  end
  
  -- DELETE vs DELETE
  if op_a.type == OT.Type.DELETE and op_b.type == OT.Type.DELETE then
    if op_a.position + op_a.length <= op_b.position then
      return op_a  -- A completely before B
    elseif op_a.position >= op_b.position + op_b.length then
      -- A completely after B
      return OT.delete(op_a.position - op_b.length, op_a.length)
    else
      -- Overlapping deletions
      local new_pos = math.max(op_a.position, op_b.position)
      local new_len = math.min(op_a.position + op_a.length, op_b.position + op_b.length) - new_pos
      new_len = math.max(0, new_len)
      
      if op_a.position < op_b.position then
        new_pos = op_a.position
        new_len = op_b.position - op_a.position
      else
        new_pos = op_b.position
        new_len = 0
      end
      
      return OT.delete(new_pos, new_len)
    end
  end
  
  -- Default: return unchanged
  return op_a
end

--- Apply operation to text
-- @param text string Original text
-- @param operation table Operation to apply
-- @return string text Resulting text
function OT.apply(text, operation)
  if operation.type == OT.Type.INSERT then
    local before = text:sub(1, operation.position)
    local after = text:sub(operation.position + 1)
    return before .. operation.text .. after
    
  elseif operation.type == OT.Type.DELETE then
    local before = text:sub(1, operation.position)
    local after = text:sub(operation.position + operation.length + 1)
    return before .. after
    
  elseif operation.type == OT.Type.RETAIN then
    return text  -- No change
  end
  
  return text
end

--- Compose two operations
-- Combine consecutive operations into a single operation
-- @param op1 table First operation
-- @param op2 table Second operation
-- @return table operation Composed operation
function OT.compose(op1, op2)
  -- Simplified composition for common cases
  
  -- Two inserts at same position
  if op1.type == OT.Type.INSERT and op2.type == OT.Type.INSERT then
    if op1.position == op2.position then
      return OT.insert(op1.position, op1.text .. op2.text)
    end
  end
  
  -- Insert then delete at same position (cancel out)
  if op1.type == OT.Type.INSERT and op2.type == OT.Type.DELETE then
    if op1.position == op2.position and #op1.text == op2.length then
      return OT.retain(0)  -- Noop
    end
  end
  
  -- Cannot compose, return array of operations
  return {op1, op2}
end

--- Story-level Operational Transform
-- Operations on story structure (passages, choices, etc.)
-- @type StoryOT
local StoryOT = {}
OT.StoryOT = StoryOT

--- Create ADD_PASSAGE operation
-- @param passage table Passage data
-- @return table operation ADD_PASSAGE operation
function StoryOT.add_passage(passage)
  return {
    type = "add_passage",
    passage = passage
  }
end

--- Create DELETE_PASSAGE operation
-- @param passage_id string Passage ID
-- @return table operation DELETE_PASSAGE operation
function StoryOT.delete_passage(passage_id)
  return {
    type = "delete_passage",
    passage_id = passage_id
  }
end

--- Create MODIFY_PASSAGE operation
-- @param passage_id string Passage ID
-- @param changes table Changes to apply
-- @return table operation MODIFY_PASSAGE operation
function StoryOT.modify_passage(passage_id, changes)
  return {
    type = "modify_passage",
    passage_id = passage_id,
    changes = changes
  }
end

--- Create ADD_CHOICE operation
-- @param passage_id string Passage ID
-- @param choice table Choice data
-- @return table operation ADD_CHOICE operation
function StoryOT.add_choice(passage_id, choice)
  return {
    type = "add_choice",
    passage_id = passage_id,
    choice = choice
  }
end

--- Transform story-level operations
-- @param op_a table Operation A
-- @param op_b table Operation B
-- @return table op_a_prime Transformed operation A
function StoryOT.transform(op_a, op_b)
  -- ADD_PASSAGE vs ADD_PASSAGE
  if op_a.type == "add_passage" and op_b.type == "add_passage" then
    if op_a.passage.id == op_b.passage.id then
      -- Same passage ID, B wins
      return nil  -- Noop
    end
    return op_a  -- Different passages, both can be added
  end
  
  -- MODIFY_PASSAGE vs DELETE_PASSAGE
  if op_a.type == "modify_passage" and op_b.type == "delete_passage" then
    if op_a.passage_id == op_b.passage_id then
      return nil  -- B deleted the passage, A's modification is invalid
    end
    return op_a
  end
  
  -- DELETE_PASSAGE vs MODIFY_PASSAGE
  if op_a.type == "delete_passage" and op_b.type == "modify_passage" then
    if op_a.passage_id == op_b.passage_id then
      -- A is deleting, keep the deletion
      return op_a
    end
    return op_a
  end
  
  -- MODIFY_PASSAGE vs MODIFY_PASSAGE
  if op_a.type == "modify_passage" and op_b.type == "modify_passage" then
    if op_a.passage_id == op_b.passage_id then
      -- Same passage, merge changes
      -- B's changes win for conflicts (last-write-wins)
      local merged_changes = {}
      for k, v in pairs(op_a.changes) do
        merged_changes[k] = v
      end
      for k, v in pairs(op_b.changes) do
        merged_changes[k] = v  -- Overwrite
      end
      return StoryOT.modify_passage(op_a.passage_id, merged_changes)
    end
    return op_a
  end
  
  -- Default: operations don't conflict
  return op_a
end

--- Apply story operation to story
-- @param story table Story data
-- @param operation table Operation to apply
-- @return table story Modified story
function StoryOT.apply(story, operation)
  if operation.type == "add_passage" then
    table.insert(story.passages, operation.passage)
    
  elseif operation.type == "delete_passage" then
    for i, passage in ipairs(story.passages) do
      if passage.id == operation.passage_id then
        table.remove(story.passages, i)
        break
      end
    end
    
  elseif operation.type == "modify_passage" then
    for _, passage in ipairs(story.passages) do
      if passage.id == operation.passage_id then
        for key, value in pairs(operation.changes) do
          passage[key] = value
        end
        break
      end
    end
    
  elseif operation.type == "add_choice" then
    for _, passage in ipairs(story.passages) do
      if passage.id == operation.passage_id then
        passage.links = passage.links or {}
        table.insert(passage.links, operation.choice)
        break
      end
    end
  end
  
  return story
end

return OT
