-- spec/wls2/list_state_machine_spec.lua
-- Tests for WLS 2.0 LIST State Machine

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("ListStateMachine", function()
    local ListStateMachine

    before_each(function()
        ListStateMachine = require("whisker.wls2.list_state_machine")
    end)

    describe("ListValue", function()
        local ListValue

        before_each(function()
            ListValue = ListStateMachine.ListValue
        end)

        it("creates a new list value", function()
            local list = ListValue.new("doorState", {"closed", "open", "locked"})
            assert.equals("doorState", list:getName())
        end)

        it("creates with initial active values", function()
            local list = ListValue.new("doorState", {"closed", "open"}, {"closed"})
            assert.is_true(list:contains("closed"))
            assert.is_false(list:contains("open"))
        end)

        it("gets possible values", function()
            local list = ListValue.new("doorState", {"closed", "open", "locked"})
            local possible = list:getPossibleValues()
            assert.equals(3, #possible)
        end)

        it("gets active values", function()
            local list = ListValue.new("state", {"a", "b", "c"}, {"a", "c"})
            local active = list:getActiveValues()
            assert.equals(2, #active)
        end)

        describe("add (+=)", function()
            it("adds a state", function()
                local list = ListValue.new("state", {"a", "b"})
                list:add("a")
                assert.is_true(list:contains("a"))
            end)

            it("adds multiple states", function()
                local list = ListValue.new("state", {"a", "b", "c"})
                list:add({"a", "c"})
                assert.is_true(list:contains("a"))
                assert.is_true(list:contains("c"))
            end)

            it("throws for invalid value", function()
                local list = ListValue.new("state", {"a", "b"})
                assert.has_error(function()
                    list:add("invalid")
                end)
            end)
        end)

        describe("remove (-=)", function()
            it("removes a state", function()
                local list = ListValue.new("state", {"a", "b"}, {"a", "b"})
                list:remove("a")
                assert.is_false(list:contains("a"))
                assert.is_true(list:contains("b"))
            end)

            it("removes multiple states", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a", "b", "c"})
                list:remove({"a", "c"})
                assert.is_false(list:contains("a"))
                assert.is_true(list:contains("b"))
                assert.is_false(list:contains("c"))
            end)
        end)

        describe("toggle", function()
            it("toggles state on", function()
                local list = ListValue.new("state", {"a"})
                list:toggle("a")
                assert.is_true(list:contains("a"))
            end)

            it("toggles state off", function()
                local list = ListValue.new("state", {"a"}, {"a"})
                list:toggle("a")
                assert.is_false(list:contains("a"))
            end)
        end)

        describe("contains (?)", function()
            it("returns true for active state", function()
                local list = ListValue.new("state", {"a", "b"}, {"a"})
                assert.is_true(list:contains("a"))
            end)

            it("returns false for inactive state", function()
                local list = ListValue.new("state", {"a", "b"}, {"a"})
                assert.is_false(list:contains("b"))
            end)
        end)

        describe("includes (superset, >=)", function()
            it("returns true when superset", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a", "b", "c"})
                assert.is_true(list:includes({"a", "b"}))
            end)

            it("returns false when not superset", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a"})
                assert.is_false(list:includes({"a", "b"}))
            end)

            it("compares with another ListValue", function()
                local list1 = ListValue.new("state1", {"a", "b", "c"}, {"a", "b", "c"})
                local list2 = ListValue.new("state2", {"a", "b"}, {"a", "b"})
                assert.is_true(list1:includes(list2))
            end)
        end)

        describe("isSubsetOf (<=)", function()
            it("returns true when subset", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a"})
                assert.is_true(list:isSubsetOf({"a", "b"}))
            end)

            it("returns false when not subset", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a", "c"})
                assert.is_false(list:isSubsetOf({"a", "b"}))
            end)
        end)

        describe("equals (==)", function()
            it("returns true for equal sets", function()
                local list1 = ListValue.new("state1", {"a", "b"}, {"a", "b"})
                local list2 = ListValue.new("state2", {"a", "b"}, {"a", "b"})
                assert.is_true(list1:equals(list2))
            end)

            it("returns false for different sets", function()
                local list1 = ListValue.new("state1", {"a", "b"}, {"a"})
                local list2 = ListValue.new("state2", {"a", "b"}, {"a", "b"})
                assert.is_false(list1:equals(list2))
            end)
        end)

        describe("count", function()
            it("returns count of active values", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a", "c"})
                assert.equals(2, list:count())
            end)

            it("returns 0 for empty list", function()
                local list = ListValue.new("state", {"a", "b"})
                assert.equals(0, list:count())
            end)
        end)

        describe("isEmpty", function()
            it("returns true when no active values", function()
                local list = ListValue.new("state", {"a", "b"})
                assert.is_true(list:isEmpty())
            end)

            it("returns false when has active values", function()
                local list = ListValue.new("state", {"a", "b"}, {"a"})
                assert.is_false(list:isEmpty())
            end)
        end)

        describe("clear", function()
            it("removes all active values", function()
                local list = ListValue.new("state", {"a", "b"}, {"a", "b"})
                list:clear()
                assert.is_true(list:isEmpty())
            end)
        end)

        describe("set", function()
            it("replaces active values", function()
                local list = ListValue.new("state", {"a", "b", "c"}, {"a"})
                list:set({"b", "c"})
                assert.is_false(list:contains("a"))
                assert.is_true(list:contains("b"))
                assert.is_true(list:contains("c"))
            end)
        end)

        describe("copy", function()
            it("creates an independent copy", function()
                local list = ListValue.new("state", {"a", "b"}, {"a"})
                local copy = list:copy()

                copy:add("b")
                assert.is_true(copy:contains("b"))
                assert.is_false(list:contains("b"))  -- Original unchanged
            end)
        end)

        describe("toString", function()
            it("converts to string representation", function()
                local list = ListValue.new("state", {"a", "b"}, {"a", "b"})
                local str = list:toString()
                assert.matches("state", str)
                assert.matches("a", str)
                assert.matches("b", str)
            end)

            it("shows empty for no active values", function()
                local list = ListValue.new("state", {"a", "b"})
                assert.equals("state()", list:toString())
            end)
        end)
    end)

    describe("ListRegistry", function()
        local ListRegistry, registry

        before_each(function()
            ListRegistry = ListStateMachine.ListRegistry
            registry = ListRegistry.new()
        end)

        it("creates a new registry", function()
            assert.is_not_nil(registry)
        end)

        it("defines a new list", function()
            local list = registry:define("doorState", {"closed", "open"})
            assert.is_not_nil(list)
            assert.is_true(registry:has("doorState"))
        end)

        it("throws for duplicate definition", function()
            registry:define("state", {"a", "b"})
            assert.has_error(function()
                registry:define("state", {"c", "d"})
            end)
        end)

        it("gets defined list", function()
            registry:define("state", {"a", "b"}, {"a"})
            local list = registry:get("state")
            assert.is_not_nil(list)
            assert.is_true(list:contains("a"))
        end)

        it("returns nil for undefined list", function()
            assert.is_nil(registry:get("undefined"))
        end)

        it("gets all list names", function()
            registry:define("state1", {"a"})
            registry:define("state2", {"b"})
            registry:define("state3", {"c"})

            local names = registry:getNames()
            assert.equals(3, #names)
        end)

        it("clears all lists", function()
            registry:define("state", {"a", "b"})
            registry:clear()
            assert.is_false(registry:has("state"))
        end)
    end)

    describe("manager", function()
        local manager

        before_each(function()
            manager = ListStateMachine.new()
        end)

        it("creates a new manager", function()
            assert.is_not_nil(manager)
            assert.is_not_nil(manager.registry)
        end)

        it("delegates to registry", function()
            manager:define("state", {"a", "b"})
            assert.is_true(manager:has("state"))

            local list = manager:get("state")
            assert.is_not_nil(list)

            local names = manager:getNames()
            assert.equals(1, #names)

            manager:clear()
            assert.is_false(manager:has("state"))
        end)
    end)
end)
