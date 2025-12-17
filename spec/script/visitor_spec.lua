-- spec/script/visitor_spec.lua
-- Tests for AST visitor pattern

describe("AST Visitor", function()
  local visitor_module
  local ast_module
  local Node
  local NodeType

  before_each(function()
    -- Clear module cache
    for k in pairs(package.loaded) do
      if k:match("^whisker%.script") then
        package.loaded[k] = nil
      end
    end
    visitor_module = require("whisker.script.visitor")
    ast_module = require("whisker.script.parser.ast")
    Node = ast_module.Node
    NodeType = ast_module.NodeType
  end)

  -- Helper to create a simple AST for testing
  local function create_test_ast()
    local lit1 = Node.literal(1, "number")
    local lit2 = Node.literal(2, "number")
    local expr = Node.binary_expr("+", lit1, lit2)
    local text = Node.text({ "Result: ", Node.inline_expr(Node.variable_ref("x")) })
    local assign = Node.assignment(Node.variable_ref("x"), "=", expr)
    local passage = Node.passage("Start", {}, { text, assign })
    return Node.script({}, {}, { passage })
  end

  describe("get_children", function()
    it("should return children of Script node", function()
      local script = Node.script(
        { Node.metadata("author", "Test") },
        { Node.include("other.wsk") },
        { Node.passage("Start", {}, {}) }
      )
      local children = visitor_module.get_children(script)
      assert.are.equal(3, #children)
    end)

    it("should return children of Passage node", function()
      local text = Node.text({ "Hello" })
      local passage = Node.passage("Start", { Node.tag("important") }, { text })
      local children = visitor_module.get_children(passage)
      assert.are.equal(2, #children)  -- 1 tag + 1 body statement
    end)

    it("should return children of BinaryExpr node", function()
      local left = Node.literal(1)
      local right = Node.literal(2)
      local expr = Node.binary_expr("+", left, right)
      local children = visitor_module.get_children(expr)
      assert.are.equal(2, #children)
    end)

    it("should return empty for leaf nodes", function()
      local lit = Node.literal(42)
      local children = visitor_module.get_children(lit)
      assert.are.equal(0, #children)
    end)

    it("should handle nil node", function()
      local children = visitor_module.get_children(nil)
      assert.are.equal(0, #children)
    end)
  end)

  describe("Visitor base class", function()
    it("should dispatch to type-specific methods", function()
      local visitor = visitor_module.Visitor.new()
      local visited_types = {}

      function visitor:visit_Literal(node)
        table.insert(visited_types, node.type)
      end

      local lit = Node.literal(42)
      visitor:visit(lit)
      assert.are.equal(1, #visited_types)
      assert.are.equal("Literal", visited_types[1])
    end)

    it("should call visit_default for unhandled types", function()
      local visitor = visitor_module.Visitor.new()
      local default_called = false

      function visitor:visit_default(node)
        default_called = true
      end

      local lit = Node.literal(42)
      visitor:visit(lit)
      assert.is_true(default_called)
    end)

    it("should traverse children in visit_default", function()
      local visitor = visitor_module.Visitor.new()
      local visited = {}

      function visitor:visit_Literal(node)
        table.insert(visited, node.value)
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:visit(expr)
      assert.are.equal(2, #visited)
    end)

    it("should handle nil node", function()
      local visitor = visitor_module.Visitor.new()
      assert.has_no_error(function()
        visitor:visit(nil)
      end)
    end)
  end)

  describe("traverse_depth_first", function()
    it("should visit nodes in pre-order", function()
      local visitor = visitor_module.Visitor.new()
      local order = {}

      function visitor:visit_BinaryExpr(node)
        table.insert(order, "binary")
        self:visit_children(node)
      end

      function visitor:visit_Literal(node)
        table.insert(order, "literal:" .. node.value)
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor_module.traverse_depth_first(expr, visitor)

      assert.are.equal("binary", order[1])
      assert.are.equal("literal:1", order[2])
      assert.are.equal("literal:2", order[3])
    end)
  end)

  describe("traverse_post_order", function()
    it("should visit children before parent", function()
      local visitor = visitor_module.Visitor.new()
      local order = {}

      function visitor:visit_BinaryExpr(node)
        table.insert(order, "binary")
      end

      function visitor:visit_Literal(node)
        table.insert(order, "literal:" .. node.value)
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor_module.traverse_post_order(expr, visitor)

      assert.are.equal("literal:1", order[1])
      assert.are.equal("literal:2", order[2])
      assert.are.equal("binary", order[3])
    end)
  end)

  describe("traverse_with_parent", function()
    it("should provide parent context", function()
      local visitor = visitor_module.Visitor.new()
      local parent_types = {}

      function visitor:visit_with_parent(node, parent)
        if parent then
          table.insert(parent_types, parent.type)
        else
          table.insert(parent_types, "nil")
        end
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor_module.traverse_with_parent(expr, visitor)

      assert.are.equal("nil", parent_types[1])  -- Root has no parent
      assert.are.equal("BinaryExpr", parent_types[2])  -- Left literal's parent
      assert.are.equal("BinaryExpr", parent_types[3])  -- Right literal's parent
    end)
  end)

  describe("TraversingVisitor", function()
    it("should call enter hooks before children", function()
      local visitor = visitor_module.TraversingVisitor.new()
      local order = {}

      function visitor:enter_BinaryExpr(node)
        table.insert(order, "enter:binary")
      end

      function visitor:visit_Literal(node)
        table.insert(order, "visit:literal")
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:visit(expr)

      assert.are.equal("enter:binary", order[1])
    end)

    it("should call leave hooks after children", function()
      local visitor = visitor_module.TraversingVisitor.new()
      local order = {}

      function visitor:leave_BinaryExpr(node)
        table.insert(order, "leave:binary")
      end

      function visitor:visit_Literal(node)
        table.insert(order, "visit:literal")
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:visit(expr)

      assert.are.equal("leave:binary", order[#order])
    end)

    it("should call both enter and leave in correct order", function()
      local visitor = visitor_module.TraversingVisitor.new()
      local order = {}

      function visitor:enter_BinaryExpr(node)
        table.insert(order, "enter")
      end

      function visitor:leave_BinaryExpr(node)
        table.insert(order, "leave")
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:visit(expr)

      assert.are.equal("enter", order[1])
      assert.are.equal("leave", order[2])
    end)
  end)

  describe("TransformVisitor", function()
    it("should transform nodes", function()
      local visitor = visitor_module.TransformVisitor.new()

      function visitor:transform_Literal(node)
        -- Double all literal values
        return Node.literal(node.value * 2, node.literal_type)
      end

      local lit = Node.literal(5)
      local result = visitor:transform(lit)
      assert.are.equal(10, result.value)
    end)

    it("should transform children first", function()
      local visitor = visitor_module.TransformVisitor.new()
      local transform_order = {}

      function visitor:transform_BinaryExpr(node)
        table.insert(transform_order, "binary")
        return node
      end

      function visitor:transform_Literal(node)
        table.insert(transform_order, "literal")
        return node
      end

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:transform(expr)

      -- Children should be transformed before parent
      assert.are.equal("literal", transform_order[1])
      assert.are.equal("literal", transform_order[2])
      assert.are.equal("binary", transform_order[3])
    end)
  end)

  describe("CollectingVisitor", function()
    it("should collect all nodes by default", function()
      local visitor = visitor_module.CollectingVisitor.new()
      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:visit(expr)
      local collected = visitor:get_collected()
      assert.are.equal(3, #collected)  -- BinaryExpr + 2 Literals
    end)

    it("should collect nodes matching predicate", function()
      local visitor = visitor_module.CollectingVisitor.new(function(node)
        return node.type == "Literal"
      end)

      local expr = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      visitor:visit(expr)
      local collected = visitor:get_collected()
      assert.are.equal(2, #collected)
    end)

    it("should clear collected nodes", function()
      local visitor = visitor_module.CollectingVisitor.new()
      visitor:visit(Node.literal(1))
      assert.are.equal(1, #visitor:get_collected())
      visitor:clear()
      assert.are.equal(0, #visitor:get_collected())
    end)
  end)

  describe("find_by_type", function()
    it("should find all nodes of specific type", function()
      local ast = create_test_ast()
      local literals = visitor_module.find_by_type(ast, "Literal")
      assert.are.equal(2, #literals)  -- 1 and 2 from binary expr
    end)

    it("should find passages", function()
      local ast = create_test_ast()
      local passages = visitor_module.find_by_type(ast, "Passage")
      assert.are.equal(1, #passages)
      assert.are.equal("Start", passages[1].name)
    end)

    it("should return empty array for non-existent type", function()
      local ast = Node.literal(42)
      local passages = visitor_module.find_by_type(ast, "Passage")
      assert.are.equal(0, #passages)
    end)
  end)

  describe("find_all", function()
    it("should find nodes matching predicate", function()
      local ast = create_test_ast()
      local vars = visitor_module.find_all(ast, function(node)
        return node.type == "VariableRef"
      end)
      assert.are.equal(2, #vars)  -- $x in text and assignment
    end)

    it("should find nodes by value", function()
      local ast = create_test_ast()
      local ones = visitor_module.find_all(ast, function(node)
        return node.type == "Literal" and node.value == 1
      end)
      assert.are.equal(1, #ones)
    end)
  end)

  describe("count_by_type", function()
    it("should count nodes of specific type", function()
      local ast = create_test_ast()
      assert.are.equal(2, visitor_module.count_by_type(ast, "Literal"))
      assert.are.equal(1, visitor_module.count_by_type(ast, "Passage"))
      assert.are.equal(1, visitor_module.count_by_type(ast, "Script"))
    end)
  end)

  describe("Complex AST traversal", function()
    it("should traverse nested conditionals", function()
      local cond = Node.conditional(
        Node.variable_ref("a"),
        { Node.text({ "A is true" }) },
        { Node.elif_clause(Node.variable_ref("b"), { Node.text({ "B is true" }) }) },
        { Node.text({ "Neither" }) }
      )

      local texts = visitor_module.find_by_type(cond, "Text")
      assert.are.equal(3, #texts)
    end)

    it("should traverse choices with nested content", function()
      local choice = Node.choice(
        Node.text({ "Choose this" }),
        Node.variable_ref("can_choose"),
        Node.divert("Target"),
        { Node.text({ "Nested content" }) }
      )

      local all = visitor_module.find_all(choice, function() return true end)
      -- Choice itself + text + condition + divert + nested text
      assert.is_true(#all >= 4)
    end)

    it("should handle deep expression nesting", function()
      -- Build: ((1 + 2) * (3 - 4))
      local add = Node.binary_expr("+", Node.literal(1), Node.literal(2))
      local sub = Node.binary_expr("-", Node.literal(3), Node.literal(4))
      local mul = Node.binary_expr("*", add, sub)

      local literals = visitor_module.find_by_type(mul, "Literal")
      assert.are.equal(4, #literals)

      local binaries = visitor_module.find_by_type(mul, "BinaryExpr")
      assert.are.equal(3, #binaries)
    end)
  end)

  describe("Custom visitor subclass", function()
    it("should allow creating custom visitors", function()
      local MyVisitor = setmetatable({}, { __index = visitor_module.Visitor })
      MyVisitor.__index = MyVisitor

      function MyVisitor.new()
        local self = setmetatable({
          sum = 0
        }, MyVisitor)
        return self
      end

      function MyVisitor:visit_Literal(node)
        if type(node.value) == "number" then
          self.sum = self.sum + node.value
        end
      end

      local visitor = MyVisitor.new()
      local expr = Node.binary_expr("+", Node.literal(10), Node.literal(20))
      visitor:visit(expr)
      assert.are.equal(30, visitor.sum)
    end)
  end)
end)
