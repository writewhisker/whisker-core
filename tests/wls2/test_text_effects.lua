-- spec/wls2/text_effects_spec.lua
-- Tests for WLS 2.0 Text Effects

package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

describe("TextEffects", function()
    local TextEffects

    before_each(function()
        TextEffects = require("whisker.wls2.text_effects")
    end)

    describe("parseTimeString", function()
        it("parses milliseconds", function()
            assert.equals(500, TextEffects.parseTimeString("500ms"))
        end)

        it("parses seconds", function()
            assert.equals(2000, TextEffects.parseTimeString("2s"))
        end)

        it("parses minutes", function()
            assert.equals(60000, TextEffects.parseTimeString("1m"))
        end)

        it("parses hours", function()
            assert.equals(3600000, TextEffects.parseTimeString("1h"))
        end)

        it("parses plain number as ms", function()
            assert.equals(100, TextEffects.parseTimeString("100"))
        end)

        it("returns nil for invalid string", function()
            assert.is_nil(TextEffects.parseTimeString("invalid"))
        end)
    end)

    describe("parseEffectDeclaration", function()
        it("parses simple effect name", function()
            local decl = TextEffects.parseEffectDeclaration("typewriter")
            assert.equals("typewriter", decl.name)
            assert.same({}, decl.options)
        end)

        it("parses effect with duration", function()
            local decl = TextEffects.parseEffectDeclaration("fade-in 1s")
            assert.equals("fade-in", decl.name)
            assert.equals(1000, decl.options.duration)
        end)

        it("parses effect with key:value options", function()
            local decl = TextEffects.parseEffectDeclaration("typewriter speed:100")
            assert.equals("typewriter", decl.name)
            assert.equals(100, decl.options.speed)
        end)

        it("parses multiple options", function()
            local decl = TextEffects.parseEffectDeclaration("slide-left delay:500 easing:ease-in-out")
            assert.equals("slide-left", decl.name)
            assert.equals(500, decl.options.delay)
            assert.equals("ease-in-out", decl.options.easing)
        end)

        it("throws for empty declaration", function()
            assert.has_error(function()
                TextEffects.parseEffectDeclaration("")
            end)
        end)
    end)

    describe("manager", function()
        local manager

        before_each(function()
            manager = TextEffects.new()
        end)

        it("creates a new manager", function()
            assert.is_not_nil(manager)
        end)

        it("has builtin effects", function()
            assert.is_true(manager:hasEffect("typewriter"))
            assert.is_true(manager:hasEffect("shake"))
            assert.is_true(manager:hasEffect("pulse"))
            assert.is_true(manager:hasEffect("glitch"))
            assert.is_true(manager:hasEffect("fade-in"))
            assert.is_true(manager:hasEffect("fade-out"))
            assert.is_true(manager:hasEffect("slide-left"))
            assert.is_true(manager:hasEffect("slide-right"))
            assert.is_true(manager:hasEffect("slide-up"))
            assert.is_true(manager:hasEffect("slide-down"))
        end)

        it("registers custom effect", function()
            manager:registerEffect("custom", {
                type = "animation",
                defaultOptions = { duration = 1000 }
            })
            assert.is_true(manager:hasEffect("custom"))
        end)

        it("throws for unknown effect", function()
            assert.has_error(function()
                manager:applyEffect("nonexistent", "text", {}, function() end, function() end)
            end)
        end)

        it("applies typewriter effect", function()
            local frames = {}
            local completed = false

            local controller = manager:applyEffect(
                "typewriter",
                "Hello",
                { speed = 10 },
                function(frame)
                    table.insert(frames, frame)
                end,
                function()
                    completed = true
                end
            )

            assert.is_not_nil(controller)

            -- Initial frame
            assert.equals(1, #frames)
            assert.equals("", frames[1].visibleText)
            assert.equals(0, frames[1].progress)

            -- Tick to reveal first character
            controller:tick(10)
            assert.equals(2, #frames)
            assert.equals("H", frames[2].visibleText)

            -- Tick to reveal all characters
            controller:tick(50)
            assert.is_true(#frames > 2)
            assert.is_true(completed)
        end)

        it("applies timed effect", function()
            local frames = {}
            local completed = false

            local controller = manager:applyEffect(
                "fade-in",
                "Hello",
                { duration = 100 },
                function(frame)
                    table.insert(frames, frame)
                end,
                function()
                    completed = true
                end
            )

            -- Initial frame
            assert.equals(1, #frames)
            assert.equals(0, frames[1].progress)

            -- Tick halfway
            controller:tick(50)
            assert.equals(2, #frames)
            assert.equals(0.5, frames[2].progress)

            -- Tick to completion
            controller:tick(50)
            assert.equals(3, #frames)
            assert.equals(1.0, frames[3].progress)
            assert.is_true(completed)
        end)

        it("controller can pause and resume", function()
            local frames = {}

            local controller = manager:applyEffect(
                "fade-in",
                "Hello",
                { duration = 100 },
                function(frame)
                    table.insert(frames, frame)
                end,
                function() end
            )

            controller:tick(25)
            local countBeforePause = #frames

            controller:pause()
            assert.is_true(controller:isPaused())

            controller:tick(25)
            assert.equals(countBeforePause, #frames)  -- No new frames while paused

            controller:resume()
            assert.is_false(controller:isPaused())

            controller:tick(25)
            assert.is_true(#frames > countBeforePause)  -- Frames resume
        end)

        it("controller can skip", function()
            local frames = {}
            local completed = false

            local controller = manager:applyEffect(
                "typewriter",
                "Hello, World!",
                { speed = 100 },
                function(frame)
                    table.insert(frames, frame)
                end,
                function()
                    completed = true
                end
            )

            -- Skip before any ticks
            controller:skip()

            -- Should have jumped to end
            local lastFrame = frames[#frames]
            assert.equals("Hello, World!", lastFrame.visibleText)
            assert.equals(1.0, lastFrame.progress)
            assert.is_true(completed)
        end)

        it("returns available effects", function()
            local effects = manager:getAvailableEffects()
            assert.is_true(#effects >= 10)  -- At least the built-in ones
        end)

        it("cancels all active effects", function()
            manager:applyEffect("fade-in", "A", {}, function() end, function() end)
            manager:applyEffect("fade-in", "B", {}, function() end, function() end)

            local controllers = manager:getActiveControllers()
            local count = 0
            for _ in pairs(controllers) do count = count + 1 end
            assert.equals(2, count)

            manager:cancelAll()
            controllers = manager:getActiveControllers()
            count = 0
            for _ in pairs(controllers) do count = count + 1 end
            assert.equals(0, count)
        end)
    end)

    describe("EFFECT_CSS", function()
        it("contains CSS keyframes", function()
            local css = TextEffects.EFFECT_CSS
            assert.is_not_nil(css)
            assert.matches("@keyframes", css)
            assert.matches("wls%-shake", css)
            assert.matches("wls%-pulse", css)
            assert.matches("wls%-glitch", css)
            assert.matches("wls%-fade%-in", css)
        end)
    end)
end)
