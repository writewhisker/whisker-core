-- tests/wls/test_choices.lua
-- WLS 1.0 Choice System Tests
-- Tests once-only choices, sticky choices, special targets, and choice actions

describe("WLS 1.0 Choices", function()
    local Choice = require("whisker.core.choice")
    local GameState = require("whisker.core.game_state")
    local Passage = require("whisker.core.passage")
    local Story = require("whisker.core.story")
    local Engine = require("whisker.core.engine")
    local LuaInterpreter = require("whisker.core.lua_interpreter")

    describe("Choice Types", function()
        it("should default to once-only type", function()
            local choice = Choice.new({ text = "Test", target = "Target" })
            assert.equals(Choice.TYPE_ONCE, choice:get_type())
            assert.is_true(choice:is_once_only())
            assert.is_false(choice:is_sticky())
        end)

        it("should support sticky type", function()
            local choice = Choice.new({
                text = "Test",
                target = "Target",
                choice_type = Choice.TYPE_STICKY
            })
            assert.equals(Choice.TYPE_STICKY, choice:get_type())
            assert.is_false(choice:is_once_only())
            assert.is_true(choice:is_sticky())
        end)

        it("should allow setting type", function()
            local choice = Choice.new({ text = "Test", target = "Target" })
            choice:set_type(Choice.TYPE_STICKY)
            assert.is_true(choice:is_sticky())
        end)

        it("should serialize choice type", function()
            local choice = Choice.new({
                text = "Test",
                target = "Target",
                choice_type = Choice.TYPE_STICKY
            })
            local data = choice:serialize()
            assert.equals(Choice.TYPE_STICKY, data.choice_type)
        end)

        it("should deserialize choice type", function()
            local choice = Choice.new({ text = "Temp", target = "Temp" })
            choice:deserialize({
                text = "Test",
                target_passage = "Target",
                choice_type = Choice.TYPE_STICKY
            })
            assert.is_true(choice:is_sticky())
        end)
    end)

    describe("GameState Choice Tracking", function()
        local game_state

        before_each(function()
            game_state = GameState.new()
        end)

        it("should track selected choices", function()
            game_state:mark_choice_selected("ch_123")
            assert.is_true(game_state:is_choice_selected("ch_123"))
            assert.is_false(game_state:is_choice_selected("ch_456"))
        end)

        it("should clear selected choice", function()
            game_state:mark_choice_selected("ch_123")
            game_state:clear_choice_selected("ch_123")
            assert.is_false(game_state:is_choice_selected("ch_123"))
        end)

        it("should get all selected choices", function()
            game_state:mark_choice_selected("ch_1")
            game_state:mark_choice_selected("ch_2")
            game_state:mark_choice_selected("ch_3")

            local selected = game_state:get_all_selected_choices()
            assert.equals(3, #selected)
        end)

        it("should clear all selected choices", function()
            game_state:mark_choice_selected("ch_1")
            game_state:mark_choice_selected("ch_2")
            game_state:clear_all_selected_choices()

            assert.is_false(game_state:is_choice_selected("ch_1"))
            assert.is_false(game_state:is_choice_selected("ch_2"))
        end)

        it("should persist selected choices in serialize", function()
            game_state:mark_choice_selected("ch_1")
            game_state:mark_choice_selected("ch_2")

            local data = game_state:serialize()
            assert.is_not_nil(data.selected_choices)
            assert.is_true(data.selected_choices["ch_1"])
            assert.is_true(data.selected_choices["ch_2"])
        end)

        it("should restore selected choices in deserialize", function()
            local data = {
                version = "1.0.0",
                selected_choices = { ch_1 = true, ch_2 = true }
            }
            game_state:deserialize(data)

            assert.is_true(game_state:is_choice_selected("ch_1"))
            assert.is_true(game_state:is_choice_selected("ch_2"))
        end)

        it("should clear selected choices on reset", function()
            game_state:mark_choice_selected("ch_1")
            game_state:reset()
            assert.is_false(game_state:is_choice_selected("ch_1"))
        end)

        it("should clear selected choices on initialize", function()
            game_state:mark_choice_selected("ch_1")
            game_state:initialize({ metadata = {}, variables = {} })
            assert.is_false(game_state:is_choice_selected("ch_1"))
        end)
    end)

    describe("Engine Once-Only Choice Filtering", function()
        local engine, story

        before_each(function()
            local interpreter = LuaInterpreter.new()
            local game_state = GameState.new()
            engine = Engine.new({
                interpreter = interpreter,
                game_state = game_state
            })

            -- Create a simple story with choices
            story = Story.new()
            story.metadata = { ifid = "test-story" }

            local start = Passage.new({ id = "Start", name = "Start", content = "Welcome!" })

            -- Add choices with known IDs
            local choice1 = Choice.new({
                id = "once_choice_1",
                text = "Once-only option",
                target = "Target",
                choice_type = Choice.TYPE_ONCE
            })
            local choice2 = Choice.new({
                id = "sticky_choice_1",
                text = "Sticky option",
                target = "Target",
                choice_type = Choice.TYPE_STICKY
            })
            local choice3 = Choice.new({
                id = "once_choice_2",
                text = "Another once-only",
                target = "Target",
                choice_type = Choice.TYPE_ONCE
            })

            start:add_choice(choice1)
            start:add_choice(choice2)
            start:add_choice(choice3)

            story:add_passage(start)

            local target = Passage.new({ id = "Target", name = "Target", content = "You arrived!" })
            story:add_passage(target)

            story:set_start_passage("Start")
        end)

        it("should show all choices initially", function()
            engine:load_story(story)
            engine:start_story()
            local content = engine:get_current_content()

            assert.equals(3, #content.choices)
        end)

        it("should hide once-only choice after selection", function()
            engine:load_story(story)
            engine:start_story()

            -- Select the first once-only choice
            engine:make_choice(1)

            -- Navigate back to Start
            engine:navigate_to_passage("Start")
            local content = engine:get_current_content()

            -- Should have 2 choices now (sticky + remaining once-only)
            assert.equals(2, #content.choices)
        end)

        it("should keep sticky choices after selection", function()
            engine:load_story(story)
            engine:start_story()

            -- Select the sticky choice (index 2)
            engine:make_choice(2)

            -- Navigate back to Start
            engine:navigate_to_passage("Start")
            local content = engine:get_current_content()

            -- Should still have 3 choices (sticky always shows)
            assert.equals(3, #content.choices)
        end)

        it("should hide multiple once-only choices after selection", function()
            engine:load_story(story)
            engine:start_story()

            -- Select first once-only
            engine:make_choice(1)
            engine:navigate_to_passage("Start")

            -- Select the remaining once-only (now at index 2, after sticky at 1)
            engine:make_choice(2)
            engine:navigate_to_passage("Start")

            local content = engine:get_current_content()

            -- Should only have sticky choice left
            assert.equals(1, #content.choices)
            assert.equals("Sticky option", content.choices[1]:get_text())
        end)
    end)

    describe("Special Targets", function()
        local engine, story

        before_each(function()
            local interpreter = LuaInterpreter.new()
            local game_state = GameState.new()
            engine = Engine.new({
                interpreter = interpreter,
                game_state = game_state
            })

            story = Story.new()
            story.metadata = { ifid = "test-story" }

            local start = Passage.new({ id = "Start", name = "Start", content = "Start passage" })
            start:add_choice(Choice.new({ text = "End game", target = "END" }))
            start:add_choice(Choice.new({ text = "Restart", target = "RESTART" }))
            start:add_choice(Choice.new({ text = "Go to middle", target = "Middle" }))
            story:add_passage(start)

            local middle = Passage.new({ id = "Middle", name = "Middle", content = "Middle passage" })
            middle:add_choice(Choice.new({ text = "Go back", target = "BACK" }))
            middle:add_choice(Choice.new({ text = "Return to start", target = "Start" }))
            story:add_passage(middle)

            story:set_start_passage("Start")
        end)

        it("should handle END target", function()
            engine:load_story(story)
            engine:start_story()

            -- Select "End game" choice
            local result = engine:make_choice(1)

            assert.is_true(result.ended)
            assert.equals(0, #result.choices)
        end)

        it("should handle RESTART target", function()
            engine:load_story(story)
            engine:start_story()

            -- Set some state
            engine.game_state:set("testVar", 123)

            -- Go to Middle
            engine:make_choice(3)

            -- Select "Restart" - need to navigate back to Start first
            engine:navigate_to_passage("Start")
            engine:make_choice(2)

            -- Should be back at Start and state should be reset
            assert.equals("Start", engine.game_state:get_current_passage())
            assert.equals(nil, engine.game_state:get("testVar"))
        end)

        it("should handle BACK target", function()
            engine:load_story(story)
            engine:start_story()

            -- Go to Middle
            engine:make_choice(3)
            assert.equals("Middle", engine.game_state:get_current_passage())

            -- Select "Go back" - should return to Start
            engine:make_choice(1)

            assert.equals("Start", engine.game_state:get_current_passage())
        end)
    end)

    describe("Choice Actions", function()
        local engine, story

        before_each(function()
            local interpreter = LuaInterpreter.new()
            local game_state = GameState.new()
            engine = Engine.new({
                interpreter = interpreter,
                game_state = game_state
            })

            story = Story.new()
            story.metadata = { ifid = "test-story" }

            local shop = Passage.new({ id = "Shop", name = "Shop", content = "Welcome to the shop!" })
            shop:add_choice(Choice.new({
                text = "Buy sword",
                target = "Inventory",
                action = "whisker.state.set('gold', (whisker.state.get('gold') or 0) - 50)"
            }))
            shop:add_choice(Choice.new({
                text = "Buy potion",
                target = "Inventory",
                action = "whisker.state.set('potions', (whisker.state.get('potions') or 0) + 1)"
            }))
            story:add_passage(shop)

            local inventory = Passage.new({ id = "Inventory", name = "Inventory", content = "Your inventory" })
            story:add_passage(inventory)

            story:set_start_passage("Shop")
        end)

        it("should execute action on choice selection", function()
            engine:load_story(story)
            engine:start_story()
            engine.game_state:set("gold", 100)

            -- Buy sword
            engine:make_choice(1)

            assert.equals(50, engine.game_state:get("gold"))
        end)

        it("should execute action before navigation", function()
            engine:load_story(story)
            engine:start_story()

            -- Buy potion
            engine:make_choice(2)

            -- Potions should be set before we left Shop
            assert.equals(1, engine.game_state:get("potions"))
        end)
    end)

    describe("Conditional Choices", function()
        local engine, story

        before_each(function()
            local interpreter = LuaInterpreter.new()
            local game_state = GameState.new()
            engine = Engine.new({
                interpreter = interpreter,
                game_state = game_state
            })

            story = Story.new()
            story.metadata = { ifid = "test-story" }

            local shop = Passage.new({ id = "Shop", name = "Shop", content = "The shop" })
            shop:add_choice(Choice.new({
                text = "Buy expensive item",
                target = "Buy",
                condition = "gold >= 100"
            }))
            shop:add_choice(Choice.new({
                text = "Buy cheap item",
                target = "Buy",
                condition = "gold >= 10"
            }))
            shop:add_choice(Choice.new({
                text = "Leave",
                target = "Exit"
            }))
            story:add_passage(shop)

            local buy = Passage.new({ id = "Buy", name = "Buy", content = "Purchased!" })
            story:add_passage(buy)

            local exit = Passage.new({ id = "Exit", name = "Exit", content = "Goodbye!" })
            story:add_passage(exit)

            story:set_start_passage("Shop")
        end)

        it("should hide choices when condition is false", function()
            engine:load_story(story)
            engine:start_story()
            engine.game_state:set("gold", 5)  -- Not enough for anything

            -- Re-render to apply new state
            engine:navigate_to_passage("Shop")
            local content = engine:get_current_content()

            -- Only "Leave" should be visible
            assert.equals(1, #content.choices)
            assert.equals("Leave", content.choices[1]:get_text())
        end)

        it("should show choices when condition is true", function()
            engine:load_story(story)
            engine:start_story()
            engine.game_state:set("gold", 50)  -- Enough for cheap item

            -- Re-render to apply new state
            engine:navigate_to_passage("Shop")
            local content = engine:get_current_content()

            -- "Buy cheap item" and "Leave" should be visible
            assert.equals(2, #content.choices)
        end)

        it("should show all choices when all conditions are met", function()
            engine:load_story(story)
            engine:start_story()
            engine.game_state:set("gold", 200)  -- Enough for everything

            -- Re-render to apply new state
            engine:navigate_to_passage("Shop")
            local content = engine:get_current_content()

            assert.equals(3, #content.choices)
        end)
    end)

    describe("Combined Once-Only and Conditional", function()
        local engine, story

        before_each(function()
            local interpreter = LuaInterpreter.new()
            local game_state = GameState.new()
            engine = Engine.new({
                interpreter = interpreter,
                game_state = game_state
            })

            story = Story.new()
            story.metadata = { ifid = "test-story" }

            local room = Passage.new({ id = "Room", name = "Room", content = "A room with items" })
            room:add_choice(Choice.new({
                id = "take_key",
                text = "Take the key",
                target = "Room",
                choice_type = Choice.TYPE_ONCE,
                action = "whisker.state.set('hasKey', true)"
            }))
            room:add_choice(Choice.new({
                id = "open_door",
                text = "Open the locked door",
                target = "NextRoom",
                condition = "hasKey == true"
            }))
            room:add_choice(Choice.new({
                id = "examine",
                text = "Look around",
                target = "Room",
                choice_type = Choice.TYPE_STICKY
            }))
            story:add_passage(room)

            local next = Passage.new({ id = "NextRoom", name = "NextRoom", content = "You went through!" })
            story:add_passage(next)

            story:set_start_passage("Room")
        end)

        it("should handle combined once-only and conditional", function()
            engine:load_story(story)
            engine:start_story()
            local content = engine:get_current_content()

            -- Initially: Take key + Look around (door hidden, no key)
            assert.equals(2, #content.choices)

            -- Take the key (navigates back to Room)
            engine:make_choice(1)
            content = engine:get_current_content()

            -- Now: Open door + Look around (key taken, door visible)
            assert.equals(2, #content.choices)
            assert.equals("Open the locked door", content.choices[1]:get_text())
        end)
    end)
end)
