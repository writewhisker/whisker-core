local helper = require("tests.test_helper")
local harlowe_parser = require("whisker.format.parsers.harlowe")
local sugarcube_parser = require("whisker.format.parsers.sugarcube")
local chapbook_parser = require("whisker.format.parsers.chapbook")
local snowman_parser = require("whisker.format.parsers.snowman")

describe("Converter Roundtrip Tests", function()

  describe("Harlowe Roundtrips", function()
    it("should roundtrip Harlowe -> SugarCube -> Harlowe", function()
      local original = [=[
:: Start
(set: $name to "Hero")
Welcome, $name!
[[Next]]
]=]

      local parsed = harlowe_parser.parse(original)
      local converter_h2s = require("whisker.format.converters.harlowe")
      local sugarcube = converter_h2s.to_sugarcube(parsed)

      local parsed_sc = sugarcube_parser.parse(sugarcube)
      local converter_s2h = require("whisker.format.converters.sugarcube")
      local back_to_harlowe = converter_s2h.to_harlowe(parsed_sc)

      assert.is_not_nil(back_to_harlowe)
      assert.matches("%(set:", back_to_harlowe)
      assert.matches("%$name", back_to_harlowe)
    end)

    it("should roundtrip Harlowe -> Chapbook -> Harlowe", function()
      local original = [[
:: Start
(set: $gold to 100)
Gold: $gold
]]

      local parsed = harlowe_parser.parse(original)
      local converter_h2c = require("whisker.format.converters.harlowe")
      local chapbook = converter_h2c.to_chapbook(parsed)

      local parsed_cb = chapbook_parser.parse(chapbook)
      local converter_c2h = require("whisker.format.converters.chapbook")
      local back_to_harlowe = converter_c2h.to_harlowe(parsed_cb)

      assert.is_not_nil(back_to_harlowe)
      assert.matches("%(set:", back_to_harlowe)
    end)
  end)

  describe("SugarCube Roundtrips", function()
    it("should roundtrip SugarCube -> Harlowe -> SugarCube", function()
      local original = [[
:: Start
<<set $name to "Hero">>
Welcome, $name!
]]

      local parsed = sugarcube_parser.parse(original)
      local converter_s2h = require("whisker.format.converters.sugarcube")
      local harlowe = converter_s2h.to_harlowe(parsed)

      local parsed_h = harlowe_parser.parse(harlowe)
      local converter_h2s = require("whisker.format.converters.harlowe")
      local back_to_sugarcube = converter_h2s.to_sugarcube(parsed_h)

      assert.is_not_nil(back_to_sugarcube)
      assert.matches("<<set", back_to_sugarcube)
    end)
  end)

  describe("Chapbook Roundtrips", function()
    it("should roundtrip Chapbook -> SugarCube -> Chapbook", function()
      local original = [[
:: Start
gold: 100
--
Gold: {gold}
]]

      local parsed = chapbook_parser.parse(original)
      local converter_c2s = require("whisker.format.converters.chapbook")
      local sugarcube = converter_c2s.to_sugarcube(parsed)

      local parsed_sc = sugarcube_parser.parse(sugarcube)
      local converter_s2c = require("whisker.format.converters.sugarcube")
      local back_to_chapbook = converter_s2c.to_chapbook(parsed_sc)

      assert.is_not_nil(back_to_chapbook)
      assert.matches("gold:", back_to_chapbook)
      assert.matches("%-%-", back_to_chapbook)
    end)
  end)

  describe("Data Preservation", function()
    it("should preserve passage count", function()
      local original = [[
:: Start
Content

:: Second
More content

:: Third
Even more
]]

      local parsed = harlowe_parser.parse(original)
      local original_count = #parsed.passages

      local converter = require("whisker.format.converters.harlowe")
      local sugarcube = converter.to_sugarcube(parsed)
      local parsed_sc = sugarcube_parser.parse(sugarcube)

      assert.equals(original_count, #parsed_sc.passages)
    end)

    it("should preserve passage names", function()
      local original = [[
:: Start
:: CustomName
:: Another_Passage
]]

      local parsed = harlowe_parser.parse(original)
      local converter = require("whisker.format.converters.harlowe")
      local chapbook = converter.to_chapbook(parsed)

      assert.matches(":: Start", chapbook)
      assert.matches(":: CustomName", chapbook)
      assert.matches(":: Another_Passage", chapbook)
    end)

    it("should preserve links", function()
      local original = [=[
:: Start
[[Link One]]
[[Text->Target]]
[[Another Link]]
]=]

      local parsed = harlowe_parser.parse(original)
      local converter = require("whisker.format.converters.harlowe")
      local sugarcube = converter.to_sugarcube(parsed)

      -- Links should be preserved in some form
      assert.matches("%[%[", sugarcube)
    end)
  end)

  describe("Conversion Loss Detection", function()
    it("should warn about incompatible features when converting Harlowe to Chapbook", function()
      local harlowe_with_link_repeat = [=[
:: Start
(link-repeat: "Click")[Text changes]
]=]

      local parsed = harlowe_parser.parse(harlowe_with_link_repeat)
      local converter = require("whisker.format.converters.harlowe")

      local result, warnings = converter.to_chapbook_with_warnings(parsed)

      assert.is_not_nil(result)
      assert.is_table(warnings)
      assert.is_true(#warnings > 0, "Expected warnings for incompatible feature")
      assert.equals("link-repeat", warnings[1].feature)
      assert.equals("Start", warnings[1].passage)
    end)

    it("should warn about multiple incompatible features", function()
      local harlowe_complex = [=[
:: Start
(link-repeat: "Click")[Changes]
(live: 2s)[Updates every 2 seconds]
(enchant: "button", (click: ?button)[(alert: "clicked")])
]=]

      local parsed = harlowe_parser.parse(harlowe_complex)
      local converter = require("whisker.format.converters.harlowe")

      local result, warnings = converter.to_chapbook_with_warnings(parsed)

      assert.is_not_nil(result)
      assert.is_true(#warnings >= 3, "Expected at least 3 warnings")

      -- Check that different features are detected
      local features = {}
      for _, w in ipairs(warnings) do
        features[w.feature] = true
      end
      assert.is_true(features["link-repeat"])
      assert.is_true(features["live"])
      assert.is_true(features["enchant"])
    end)

    it("should return empty warnings for compatible Harlowe content", function()
      local harlowe_compatible = [=[
:: Start
(set: $name to "Player")
(if: $name is "Player")[Welcome, Player!]
[[Continue->Next]]
]=]

      local parsed = harlowe_parser.parse(harlowe_compatible)
      local converter = require("whisker.format.converters.harlowe")

      local result, warnings = converter.to_chapbook_with_warnings(parsed)

      assert.is_not_nil(result)
      assert.equals(0, #warnings)
    end)

    it("should detect when exact conversion to Harlowe isn't possible", function()
      local chapbook_with_timing = [=[
:: Start
[after 5s]
Delayed text appears here
[continue]
]=]

      local parsed = chapbook_parser.parse(chapbook_with_timing)
      local converter = require("whisker.format.converters.chapbook")

      local result, info = converter.to_harlowe_with_info(parsed)

      assert.is_not_nil(result)
      assert.is_table(info)
      assert.is_false(info.exact_conversion)
      assert.is_true(#info.approximations_used > 0)
      assert.equals("after modifier", info.approximations_used[1].feature)
    end)

    it("should report exact conversion for simple Chapbook content", function()
      local chapbook_simple = [=[
:: Start
name: Player
--
Hello, {name}!

[[Continue->Next]]
]=]

      local parsed = chapbook_parser.parse(chapbook_simple)
      local converter = require("whisker.format.converters.chapbook")

      local result, info = converter.to_harlowe_with_info(parsed)

      assert.is_not_nil(result)
      assert.is_true(info.exact_conversion)
      assert.equals(0, #info.approximations_used)
    end)

    it("should list all approximations used for complex Chapbook content", function()
      local chapbook_complex = [=[
:: Start
[after 3s]
This appears after 3 seconds
[continue]

[align center]
Centered text
[continue]

{embed passage: 'Other'}
]=]

      local parsed = chapbook_parser.parse(chapbook_complex)
      local converter = require("whisker.format.converters.chapbook")

      local result, info = converter.to_harlowe_with_info(parsed)

      assert.is_not_nil(result)
      assert.is_false(info.exact_conversion)
      assert.is_true(#info.approximations_used >= 2)

      -- Check that different approximations are reported
      local features = {}
      for _, a in ipairs(info.approximations_used) do
        features[a.feature] = true
      end
      assert.is_true(features["after modifier"] or features["align modifier"] or features["embed insert"])
    end)
  end)
end)
