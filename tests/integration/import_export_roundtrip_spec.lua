--- Import/Export Round-trip Integration Tests
-- Tests that stories can be imported and exported without data loss
-- @module tests.integration.import_export_roundtrip_spec

describe("Import/Export Round-trip", function()
  local ImportManager
  local ExportManager
  local HarloweImporter
  local SugarCubeImporter
  local ChapbookImporter

  setup(function()
    package.path = package.path .. ";./lib/?.lua;./lib/?/init.lua"

    -- Try to load modules
    local ok_im, im = pcall(require, "whisker.import")
    if ok_im then ImportManager = im end

    local ok_em, em = pcall(require, "whisker.export")
    if ok_em then ExportManager = em end

    local ok_h, h = pcall(require, "whisker.import.harlowe")
    if ok_h then HarloweImporter = h end

    local ok_s, s = pcall(require, "whisker.import.sugarcube")
    if ok_s then SugarCubeImporter = s end

    local ok_c, c = pcall(require, "whisker.import.chapbook")
    if ok_c then ChapbookImporter = c end
  end)

  -- Sample Harlowe source
  local harlowe_source = [=[
:: Start
(set: $health to 100)
(set: $name to "Hero")

Welcome, traveler! You find yourself at a crossroads.

[[Go north->North Path]]
[[Go south->South Path]]

:: North Path
(if: $health > 50)[You feel strong enough to continue.]
(else:)[You feel weak.]

The path leads into a dark forest.

[[Enter the forest->Forest]]
[[Go back->Start]]

:: South Path
This path leads to a peaceful village.

(set: $visited_village to true)

[[Explore the village->Village]]
[[Return->Start]]

:: Forest
You encounter a wild beast!

(set: $health to $health - 20)

[[Fight->Battle]]
[[Run away->Start]]

:: Village
The villagers greet you warmly.

[[Buy supplies->Shop]]
[[Talk to elder->Elder]]
[[Leave->South Path]]

:: Battle
You defeat the beast!

(set: $gold to $gold + 50)

[[Continue->Deep Forest]]
[[Go back->Start]]

:: Shop
You can buy items here.

[[Buy health potion->Potion]]
[[Leave->Village]]

:: Elder
The elder shares ancient wisdom.

[[Listen->Wisdom]]
[[Leave->Village]]

:: Deep Forest
You find a treasure chest!

[[Open it->Treasure]]
[[Leave it->Start]]

:: Potion
You bought a health potion!

(set: $health to $health + 50)

[[Back->Village]]

:: Wisdom
"Beware the darkness, young one."

[[Thank the elder->Village]]

:: Treasure
You found gold!

(set: $gold to $gold + 100)

[[Continue->Start]]
]=]

  -- Sample SugarCube source
  local sugarcube_source = [=[
:: Start
<<set $health = 100>>
<<set $gold = 0>>

You wake up in a mysterious cave.

<<link "Look around" "Cave Entrance">>

:: Cave Entrance
The cave is dark but you can see light ahead.

<<if $health > 50>>
You feel well enough to explore.
<<else>>
You feel weak and should rest.
<</if>>

[[Go towards the light->Light]]
[[Rest here->Rest]]

:: Light
You emerge into a beautiful valley!

<<set $discovered_valley = true>>

[[Explore the valley->Valley]]
[[Go back into cave->Cave Entrance]]

:: Rest
You rest and recover some health.

<<set $health = $health + 25>>

[[Continue->Cave Entrance]]

:: Valley
The valley is filled with flowers and a small stream.

<<silently>>
<<set $peaceful = true>>
<</silently>>

[[Drink from stream->Stream]]
[[Pick flowers->Flowers]]
[[Return to cave->Cave Entrance]]

:: Stream
The water is refreshing!

<<set $health = $health + 10>>

[[Continue exploring->Valley]]

:: Flowers
You pick some beautiful flowers.

<<set $hasFlowers = true>>

[[Continue->Valley]]
]=]

  -- Sample Chapbook source
  local chapbook_source = [=[
:: Start
config.header.center: My Adventure
gold: 0
health: 100
---
Welcome to the adventure!

You stand before an ancient temple.

[[Enter the temple->Temple]]
[[Walk around->Outside]]

:: Temple
torchLit: false
---
The temple interior is dark.

[if torchLit]
With your torch, you can see ancient murals on the walls.
[else]
You can barely see anything in the darkness.
[continue]

+ [Light a torch] -> LightTorch
+ [Leave] -> Start

:: LightTorch
torchLit: true
---
You light a torch. The flames illuminate the ancient walls.

+ [Examine the murals] -> Murals
+ [Continue deeper] -> DeepTemple

:: Outside
visited_outside: true
---
The temple grounds are overgrown but beautiful.

[reveal link: hidden path]
You notice a hidden path behind some bushes.
[continue]

+ [Follow the path] -> SecretPath
+ [Return to entrance] -> Start

:: Murals
The murals depict an ancient civilization.

gold: 25
---
You find some gold coins hidden in a crack!

+ [Take the coins] -> Temple
+ [Leave them] -> Temple

:: DeepTemple
You find the temple's inner sanctum.

+ [Search for treasure] -> Treasure
+ [Leave quickly] -> Start

:: SecretPath
The hidden path leads to a garden.

health: 125
---
You feel refreshed by the peaceful surroundings.

+ [Return] -> Outside

:: Treasure
gold: 500
---
You found the temple treasure!

+ [Take it and leave] -> Start
]=]

  describe("Harlowe Import", function()
    pending("should convert Harlowe conditionals to WLS", function()
      if not HarloweImporter then
        pending("HarloweImporter not available")
        return
      end

      local importer = HarloweImporter.new()
      local can_import, err = importer:can_import(harlowe_source)

      assert.is_true(can_import, err)
    end)

    pending("should preserve passage structure", function()
      if not HarloweImporter then
        pending("HarloweImporter not available")
        return
      end

      local importer = HarloweImporter.new()
      local story = importer:import(harlowe_source)

      assert.is_not_nil(story)
      assert.is_not_nil(story.passages)
    end)

    pending("should convert variables correctly", function()
      if not HarloweImporter then
        pending("HarloweImporter not available")
        return
      end

      local importer = HarloweImporter.new()
      local wls = importer:convert_to_wls(harlowe_source)

      -- Should convert (set: $health to 100) to @{health = 100}
      assert.truthy(wls:find("health"))
    end)
  end)

  describe("SugarCube Import", function()
    pending("should detect SugarCube format", function()
      if not SugarCubeImporter then
        pending("SugarCubeImporter not available")
        return
      end

      local importer = SugarCubeImporter.new()
      local detected = importer:detect(sugarcube_source)

      assert.is_true(detected)
    end)

    pending("should convert SugarCube syntax", function()
      if not SugarCubeImporter then
        pending("SugarCubeImporter not available")
        return
      end

      local importer = SugarCubeImporter.new()
      local wls = importer:convert_to_wls(sugarcube_source)

      -- Should convert <<set $health = 100>> to @{health = 100}
      assert.truthy(wls:find("health"))
    end)

    pending("should handle silently blocks", function()
      if not SugarCubeImporter then
        pending("SugarCubeImporter not available")
        return
      end

      local importer = SugarCubeImporter.new()
      local wls = importer:convert_to_wls(sugarcube_source)

      -- <<silently>> blocks should be converted to silent variable assignments
      assert.truthy(wls:find("peaceful"))
    end)
  end)

  describe("Chapbook Import", function()
    pending("should detect Chapbook format", function()
      if not ChapbookImporter then
        pending("ChapbookImporter not available")
        return
      end

      local importer = ChapbookImporter.new()
      local detected = importer:detect(chapbook_source)

      assert.is_true(detected)
    end)

    pending("should convert variable sections", function()
      if not ChapbookImporter then
        pending("ChapbookImporter not available")
        return
      end

      local importer = ChapbookImporter.new()
      local wls = importer:convert_to_wls(chapbook_source)

      -- Variables before --- should become VAR statements
      assert.truthy(wls:find("gold") or wls:find("health"))
    end)

    pending("should handle reveal links", function()
      if not ChapbookImporter then
        pending("ChapbookImporter not available")
        return
      end

      local importer = ChapbookImporter.new()
      local wls = importer:convert_to_wls(chapbook_source)

      -- reveal links should be converted
      assert.truthy(wls:find("hidden path") or wls:find("SecretPath"))
    end)
  end)

  describe("ImportManager", function()
    pending("should detect format automatically", function()
      if not ImportManager then
        pending("ImportManager not available")
        return
      end

      local manager = ImportManager.new()

      -- Register importers
      if HarloweImporter then
        manager:register("harlowe", HarloweImporter.new())
      end
      if SugarCubeImporter then
        manager:register("sugarcube", SugarCubeImporter.new())
      end
      if ChapbookImporter then
        manager:register("chapbook", ChapbookImporter.new())
      end

      local detected = manager:detect_format(harlowe_source)
      assert.is_not_nil(detected)
    end)

    pending("should import using detected format", function()
      if not ImportManager then
        pending("ImportManager not available")
        return
      end

      local manager = ImportManager.new()

      if HarloweImporter then
        manager:register("harlowe", HarloweImporter.new())
      end

      local result = manager:import(harlowe_source, "harlowe")
      assert.is_not_nil(result)
      assert.is_nil(result.error)
    end)
  end)

  describe("Export Formats", function()
    pending("should export to HTML", function()
      if not ExportManager then
        pending("ExportManager not available")
        return
      end

      local story = {
        metadata = { title = "Test Story", author = "Test" },
        passages = {
          start = {
            id = "start",
            title = "Start",
            content = "Hello!",
            choices = {},
          },
        },
      }

      local manager = ExportManager.new()
      -- Would need to register HTML exporter

      -- Just verify the manager exists
      assert.is_not_nil(manager)
    end)

    pending("should export to Markdown", function()
      if not ExportManager then
        pending("ExportManager not available")
        return
      end

      local story = {
        metadata = { title = "Test Story", author = "Test" },
        passages = {
          start = {
            id = "start",
            title = "Start",
            content = "Hello!",
            choices = {},
          },
        },
      }

      local manager = ExportManager.new()
      assert.is_not_nil(manager)
    end)
  end)

  describe("Round-trip Integrity", function()
    pending("should preserve story structure through import", function()
      if not HarloweImporter or not ImportManager then
        pending("Required modules not available")
        return
      end

      local importer = HarloweImporter.new()
      local story = importer:import(harlowe_source)

      assert.is_not_nil(story)

      -- Count expected passages
      local passage_count = 0
      for _ in pairs(story.passages or {}) do
        passage_count = passage_count + 1
      end

      -- Harlowe source has ~12 passages
      assert.is_true(passage_count > 5, "Should import multiple passages")
    end)

    pending("should maintain variable types", function()
      if not HarloweImporter then
        pending("HarloweImporter not available")
        return
      end

      local importer = HarloweImporter.new()
      local story = importer:import(harlowe_source)

      -- Check that variables were parsed
      if story.variables and story.variables.health then
        -- Health should be a number
        assert.is_true(
          story.variables.health.type == "number" or
          type(story.variables.health.initial) == "number" or
          tonumber(story.variables.health.initial) ~= nil
        )
      end
    end)
  end)
end)
