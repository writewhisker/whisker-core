-- tests/format/gap048_json_assets_spec.lua
-- Tests for GAP-048: JSON Assets Support

describe("GAP-048: JSON Assets", function()
    local JsonParser
    local Assets

    setup(function()
        JsonParser = require("whisker.format.parsers.json")
        Assets = require("whisker.utils.assets")
    end)

    describe("Assets utility module", function()
        describe("get_mime_type", function()
            it("returns correct MIME type for images", function()
                assert.are.equal("image/png", Assets.get_mime_type("image.png"))
                assert.are.equal("image/jpeg", Assets.get_mime_type("photo.jpg"))
                assert.are.equal("image/jpeg", Assets.get_mime_type("photo.jpeg"))
                assert.are.equal("image/gif", Assets.get_mime_type("animation.gif"))
                assert.are.equal("image/svg+xml", Assets.get_mime_type("icon.svg"))
                assert.are.equal("image/webp", Assets.get_mime_type("modern.webp"))
            end)

            it("returns correct MIME type for audio", function()
                assert.are.equal("audio/mpeg", Assets.get_mime_type("song.mp3"))
                assert.are.equal("audio/ogg", Assets.get_mime_type("sound.ogg"))
                assert.are.equal("audio/wav", Assets.get_mime_type("effect.wav"))
            end)

            it("returns correct MIME type for video", function()
                assert.are.equal("video/mp4", Assets.get_mime_type("movie.mp4"))
                assert.are.equal("video/webm", Assets.get_mime_type("clip.webm"))
            end)

            it("returns correct MIME type for fonts", function()
                assert.are.equal("font/woff2", Assets.get_mime_type("font.woff2"))
                assert.are.equal("font/ttf", Assets.get_mime_type("font.ttf"))
            end)

            it("returns octet-stream for unknown types", function()
                assert.are.equal("application/octet-stream", Assets.get_mime_type("file.xyz"))
            end)

            it("handles case insensitivity", function()
                assert.are.equal("image/png", Assets.get_mime_type("IMAGE.PNG"))
            end)
        end)

        describe("get_asset_type", function()
            it("identifies image types", function()
                assert.are.equal("image", Assets.get_asset_type("image/png"))
                assert.are.equal("image", Assets.get_asset_type("image/jpeg"))
            end)

            it("identifies audio types", function()
                assert.are.equal("audio", Assets.get_asset_type("audio/mpeg"))
                assert.are.equal("audio", Assets.get_asset_type("audio/ogg"))
            end)

            it("identifies video types", function()
                assert.are.equal("video", Assets.get_asset_type("video/mp4"))
            end)

            it("identifies font types", function()
                assert.are.equal("font", Assets.get_asset_type("font/woff2"))
            end)

            it("identifies document types", function()
                assert.are.equal("document", Assets.get_asset_type("text/html"))
                assert.are.equal("document", Assets.get_asset_type("application/json"))
            end)

            it("returns other for truly unknown types", function()
                assert.are.equal("other", Assets.get_asset_type("some/random/mime"))
            end)
        end)

        describe("is_external_url", function()
            it("identifies http URLs", function()
                assert.is_true(Assets.is_external_url("http://example.com/image.png"))
            end)

            it("identifies https URLs", function()
                assert.is_true(Assets.is_external_url("https://example.com/image.png"))
            end)

            it("returns false for local paths", function()
                assert.is_false(Assets.is_external_url("assets/image.png"))
                assert.is_false(Assets.is_external_url("/absolute/path/image.png"))
                assert.is_false(Assets.is_external_url("./relative/image.png"))
            end)
        end)

        describe("generate_id", function()
            it("generates unique IDs", function()
                local id1 = Assets.generate_id("image.png", 1)
                local id2 = Assets.generate_id("image.png", 2)

                assert.is_string(id1)
                assert.is_string(id2)
                assert.are_not_equal(id1, id2)
            end)

            it("includes sanitized filename", function()
                local id = Assets.generate_id("my-image.png", 1)
                assert.matches("my%-image", id)
            end)

            it("handles paths with directories", function()
                local id = Assets.generate_id("assets/images/icon.png", 5)
                assert.matches("icon", id)
            end)
        end)

        describe("is_format_supported", function()
            it("recognizes supported image formats", function()
                assert.is_true(Assets.is_format_supported("image.png", "image"))
                assert.is_true(Assets.is_format_supported("image.jpg", "image"))
                assert.is_true(Assets.is_format_supported("image.gif", "image"))
            end)

            it("recognizes supported audio formats", function()
                assert.is_true(Assets.is_format_supported("sound.mp3", "audio"))
                assert.is_true(Assets.is_format_supported("sound.ogg", "audio"))
            end)

            it("returns false for unsupported formats", function()
                assert.is_false(Assets.is_format_supported("image.tiff", "image"))
                assert.is_false(Assets.is_format_supported("sound.wma", "audio"))
            end)
        end)

        describe("base64 encoding", function()
            it("encodes simple string", function()
                local encoded = Assets.base64_encode("Hello")
                assert.are.equal("SGVsbG8=", encoded)
            end)

            it("decodes back to original", function()
                local original = "Hello, World!"
                local encoded = Assets.base64_encode(original)
                local decoded = Assets.base64_decode(encoded)
                assert.are.equal(original, decoded)
            end)

            it("handles binary data", function()
                local binary = string.char(0, 1, 2, 255, 254, 253)
                local encoded = Assets.base64_encode(binary)
                local decoded = Assets.base64_decode(encoded)
                assert.are.equal(binary, decoded)
            end)
        end)
    end)

    describe("JsonParser asset collection", function()
        describe("collect_asset_references", function()
            it("finds @image directives", function()
                local content = [[
Some text
@image("assets/hero.png")
More text
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(1, #refs)
                assert.are.equal("image", refs[1].type)
                assert.are.equal("assets/hero.png", refs[1].path)
            end)

            it("finds @audio directives", function()
                local content = [[
@audio("sounds/bgm.mp3")
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(1, #refs)
                assert.are.equal("audio", refs[1].type)
                assert.are.equal("sounds/bgm.mp3", refs[1].path)
            end)

            it("finds @video directives", function()
                local content = [[
@video("videos/intro.mp4")
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(1, #refs)
                assert.are.equal("video", refs[1].type)
            end)

            it("finds @embed directives", function()
                local content = [[
@embed("https://youtube.com/embed/xyz")
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(1, #refs)
                assert.are.equal("embed", refs[1].type)
            end)

            it("finds markdown images", function()
                local content = [[
![Alt text](images/photo.jpg)
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(1, #refs)
                assert.are.equal("image", refs[1].type)
                assert.are.equal("images/photo.jpg", refs[1].path)
            end)

            it("deduplicates references", function()
                local content = [[
@image("same.png")
![Alt](same.png)
@image("same.png")
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(1, #refs)
            end)

            it("collects multiple different assets", function()
                local content = [[
@image("one.png")
@audio("two.mp3")
![Three](three.gif)
]]
                local refs = JsonParser.collect_asset_references(content)

                assert.are.equal(3, #refs)
            end)
        end)

        describe("collect_story_assets", function()
            it("collects assets from all passages", function()
                local story = {
                    passages = {
                        { name = "Start", content = "@image('a.png')" },
                        { name = "Middle", content = "@audio('b.mp3')" },
                        { name = "End", content = "![c](c.gif)" }
                    }
                }

                local refs = JsonParser.collect_story_assets(story)

                assert.are.equal(3, #refs)
            end)

            it("deduplicates across passages", function()
                local story = {
                    passages = {
                        { name = "Start", content = "@image('shared.png')" },
                        { name = "End", content = "@image('shared.png')" }
                    }
                }

                local refs = JsonParser.collect_story_assets(story)

                assert.are.equal(1, #refs)
            end)

            it("handles empty passages", function()
                local story = {
                    passages = {
                        { name = "Empty", content = "" },
                        { name = "Nil" }
                    }
                }

                local refs = JsonParser.collect_story_assets(story)

                assert.are.equal(0, #refs)
            end)
        end)

        describe("create_asset_manifest", function()
            it("creates manifest with basic info", function()
                local story = {
                    passages = {
                        { name = "Start", content = "@image('test.png')" }
                    }
                }

                local manifest = JsonParser.create_asset_manifest(story, "/base", {})

                assert.is_not_nil(manifest)
                assert.are.equal("1.0", manifest.version)
                assert.is_not_nil(manifest.generated)
                assert.is_table(manifest.assets)
            end)

            it("identifies external URLs", function()
                local story = {
                    passages = {
                        { name = "Start", content = "@image('https://example.com/img.png')" }
                    }
                }

                local manifest = JsonParser.create_asset_manifest(story, "/base", {})

                assert.are.equal(1, #manifest.assets)
                assert.is_true(manifest.assets[1].external)
            end)
        end)
    end)
end)
