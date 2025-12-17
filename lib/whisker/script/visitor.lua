-- lib/whisker/script/visitor.lua
-- AST visitor pattern for Whisker Script

local ast_module = require("whisker.script.parser.ast")
local NodeType = ast_module.NodeType
local Node = ast_module.Node

local M = {}

-- ============================================
-- Child node accessors for each node type
-- ============================================

local function get_children(node)
  if not node or not node.type then return {} end

  local children = {}

  local child_map = {
    [NodeType.Script] = function(n)
      for _, m in ipairs(n.metadata or {}) do table.insert(children, m) end
      for _, i in ipairs(n.includes or {}) do table.insert(children, i) end
      for _, p in ipairs(n.passages or {}) do table.insert(children, p) end
    end,

    [NodeType.Passage] = function(n)
      for _, t in ipairs(n.tags or {}) do table.insert(children, t) end
      for _, s in ipairs(n.body or {}) do table.insert(children, s) end
    end,

    [NodeType.Text] = function(n)
      for _, seg in ipairs(n.segments or {}) do
        if type(seg) == "table" and seg.type then
          table.insert(children, seg)
        end
      end
    end,

    [NodeType.Choice] = function(n)
      if n.text then table.insert(children, n.text) end
      if n.condition then table.insert(children, n.condition) end
      if n.target then table.insert(children, n.target) end
      for _, s in ipairs(n.body or {}) do table.insert(children, s) end
    end,

    [NodeType.Assignment] = function(n)
      if n.variable then table.insert(children, n.variable) end
      if n.value then table.insert(children, n.value) end
    end,

    [NodeType.Conditional] = function(n)
      if n.condition then table.insert(children, n.condition) end
      for _, s in ipairs(n.then_body or {}) do table.insert(children, s) end
      for _, elif in ipairs(n.elif_clauses or {}) do table.insert(children, elif) end
      for _, s in ipairs(n.else_body or {}) do table.insert(children, s) end
    end,

    [NodeType.ElifClause] = function(n)
      if n.condition then table.insert(children, n.condition) end
      for _, s in ipairs(n.body or {}) do table.insert(children, s) end
    end,

    [NodeType.ElseClause] = function(n)
      for _, s in ipairs(n.body or {}) do table.insert(children, s) end
    end,

    [NodeType.Divert] = function(n)
      for _, arg in ipairs(n.arguments or {}) do table.insert(children, arg) end
    end,

    [NodeType.TunnelCall] = function(n)
      for _, arg in ipairs(n.arguments or {}) do table.insert(children, arg) end
    end,

    [NodeType.BinaryExpr] = function(n)
      if n.left then table.insert(children, n.left) end
      if n.right then table.insert(children, n.right) end
    end,

    [NodeType.UnaryExpr] = function(n)
      if n.operand then table.insert(children, n.operand) end
    end,

    [NodeType.VariableRef] = function(n)
      if n.index then table.insert(children, n.index) end
    end,

    [NodeType.FunctionCall] = function(n)
      for _, arg in ipairs(n.arguments or {}) do table.insert(children, arg) end
    end,

    [NodeType.ListLiteral] = function(n)
      for _, elem in ipairs(n.elements or {}) do table.insert(children, elem) end
    end,

    [NodeType.InlineExpr] = function(n)
      if n.expression then table.insert(children, n.expression) end
    end,

    [NodeType.InlineConditional] = function(n)
      if n.condition then table.insert(children, n.condition) end
      if n.then_value then table.insert(children, n.then_value) end
      if n.else_value then table.insert(children, n.else_value) end
    end,
  }

  local accessor = child_map[node.type]
  if accessor then
    accessor(node)
  end

  return children
end

M.get_children = get_children

-- ============================================
-- Visitor Base Class
-- ============================================

local Visitor = {}
Visitor.__index = Visitor

--- Create a new visitor
-- @return Visitor
function Visitor.new()
  return setmetatable({}, Visitor)
end

--- Visit a node, dispatching to type-specific method
-- @param node table AST node to visit
-- @return any Result of visit
function Visitor:visit(node)
  if not node or not node.type then return nil end

  local method_name = "visit_" .. node.type
  local method = self[method_name]

  if method then
    return method(self, node)
  else
    return self:visit_default(node)
  end
end

--- Default visit method - traverses children
-- @param node table AST node
function Visitor:visit_default(node)
  self:visit_children(node)
end

--- Visit all children of a node
-- @param node table AST node
function Visitor:visit_children(node)
  local children = get_children(node)
  for _, child in ipairs(children) do
    self:visit(child)
  end
end

M.Visitor = Visitor

-- ============================================
-- Traversal Functions
-- ============================================

--- Traverse AST depth-first (pre-order)
-- @param node table Root node
-- @param visitor Visitor Visitor instance
function M.traverse_depth_first(node, visitor)
  if not node then return end
  visitor:visit(node)
end

--- Traverse AST with parent context
-- @param node table Current node
-- @param visitor Visitor Visitor instance
-- @param parent table Parent node (nil for root)
function M.traverse_with_parent(node, visitor, parent)
  if not node then return end

  -- Call visit_with_parent if available
  if visitor.visit_with_parent then
    visitor:visit_with_parent(node, parent)
  else
    visitor:visit(node)
  end

  -- Traverse children with current node as parent
  local children = get_children(node)
  for _, child in ipairs(children) do
    M.traverse_with_parent(child, visitor, node)
  end
end

--- Traverse AST post-order (children before node)
-- @param node table Root node
-- @param visitor Visitor Visitor instance
function M.traverse_post_order(node, visitor)
  if not node then return end

  -- Visit children first
  local children = get_children(node)
  for _, child in ipairs(children) do
    M.traverse_post_order(child, visitor)
  end

  -- Then visit this node
  visitor:visit(node)
end

-- ============================================
-- Traversing Visitor with enter/leave hooks
-- ============================================

local TraversingVisitor = setmetatable({}, { __index = Visitor })
TraversingVisitor.__index = TraversingVisitor

--- Create a new traversing visitor with enter/leave hooks
-- @return TraversingVisitor
function TraversingVisitor.new()
  return setmetatable({}, TraversingVisitor)
end

--- Traverse a node with enter/leave hooks
-- @param node table AST node
-- @return table Potentially modified node
function TraversingVisitor:traverse(node)
  if not node or not node.type then return node end

  -- Call enter hook
  local enter_method = self["enter_" .. node.type]
  if enter_method then
    local result = enter_method(self, node)
    if result ~= nil then node = result end
  end

  -- Traverse children
  self:visit_children(node)

  -- Call leave hook
  local leave_method = self["leave_" .. node.type]
  if leave_method then
    local result = leave_method(self, node)
    if result ~= nil then node = result end
  end

  return node
end

--- Override visit to use traverse
function TraversingVisitor:visit(node)
  return self:traverse(node)
end

M.TraversingVisitor = TraversingVisitor

-- ============================================
-- Transform Visitor (for AST modifications)
-- ============================================

local TransformVisitor = setmetatable({}, { __index = Visitor })
TransformVisitor.__index = TransformVisitor

--- Create a new transform visitor
-- @return TransformVisitor
function TransformVisitor.new()
  return setmetatable({}, TransformVisitor)
end

--- Transform a node and its children
-- @param node table AST node
-- @return table Transformed node
function TransformVisitor:transform(node)
  if not node or not node.type then return node end

  -- Transform children first (post-order for transformations)
  node = self:transform_children(node)

  -- Then transform this node
  local method_name = "transform_" .. node.type
  local method = self[method_name]

  if method then
    return method(self, node) or node
  end

  return node
end

--- Transform children and rebuild node
-- @param node table AST node
-- @return table Node with transformed children
function TransformVisitor:transform_children(node)
  -- This is a simplified version - full implementation would rebuild the node
  local children = get_children(node)
  for _, child in ipairs(children) do
    self:transform(child)
  end
  return node
end

M.TransformVisitor = TransformVisitor

-- ============================================
-- Collecting Visitor (finds nodes by predicate)
-- ============================================

local CollectingVisitor = setmetatable({}, { __index = Visitor })
CollectingVisitor.__index = CollectingVisitor

--- Create a new collecting visitor
-- @param predicate function Predicate function(node) -> boolean
-- @return CollectingVisitor
function CollectingVisitor.new(predicate)
  local self = setmetatable({
    predicate = predicate or function() return true end,
    collected = {}
  }, CollectingVisitor)
  return self
end

--- Visit a node and collect if predicate matches
-- @param node table AST node
function CollectingVisitor:visit_default(node)
  if self.predicate(node) then
    table.insert(self.collected, node)
  end
  self:visit_children(node)
end

--- Get collected nodes
-- @return table Array of matching nodes
function CollectingVisitor:get_collected()
  return self.collected
end

--- Clear collected nodes
function CollectingVisitor:clear()
  self.collected = {}
end

M.CollectingVisitor = CollectingVisitor

-- ============================================
-- Convenience Functions
-- ============================================

--- Find all nodes of a specific type
-- @param root table Root AST node
-- @param node_type string Node type to find
-- @return table Array of matching nodes
function M.find_by_type(root, node_type)
  local visitor = CollectingVisitor.new(function(node)
    return node.type == node_type
  end)
  visitor:visit(root)
  return visitor:get_collected()
end

--- Find all nodes matching a predicate
-- @param root table Root AST node
-- @param predicate function Predicate function
-- @return table Array of matching nodes
function M.find_all(root, predicate)
  local visitor = CollectingVisitor.new(predicate)
  visitor:visit(root)
  return visitor:get_collected()
end

--- Count nodes of a specific type
-- @param root table Root AST node
-- @param node_type string Node type to count
-- @return number Count of matching nodes
function M.count_by_type(root, node_type)
  return #M.find_by_type(root, node_type)
end

--- Module metadata
M._whisker = {
  name = "script.visitor",
  version = "0.1.0",
  description = "AST visitor pattern for Whisker Script",
  depends = { "script.parser.ast" },
  capability = "script.visitor"
}

return M
