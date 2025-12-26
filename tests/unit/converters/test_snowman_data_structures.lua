-- Unit Tests for Snowman Data Structure Conversions
local HarloweConverter = require("whisker.format.converters.harlowe")

describe("Snowman Data Structures", function()

  describe("Array Conversion", function()
    it("should convert (a: 1, 2, 3) to [1, 2, 3]", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(set: $nums to (a: 1, 2, 3))", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("%[1, 2, 3%]", result)
    end)

    it("should convert array of strings", function()
      local parsed = {
        passages = {
          {name = "Start", content = '(set: $names to (a: "Alice", "Bob", "Carol"))', tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches('%["Alice", "Bob", "Carol"%]', result)
    end)

    it("should convert array access $arr's 1st to s.arr[0]", function()
      local parsed = {
        passages = {
          {name = "Start", content = "The first item is $items's 1st", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("s%.items%[0%]", result)
    end)

    it("should convert array access $arr's 2nd to s.arr[1]", function()
      local parsed = {
        passages = {
          {name = "Start", content = "The second item is $items's 2nd", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("s%.items%[1%]", result)
    end)

    it("should convert array access $arr's 3rd to s.arr[2]", function()
      local parsed = {
        passages = {
          {name = "Start", content = "The third item is $items's 3rd", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("s%.items%[2%]", result)
    end)

    it("should convert $arr's length to s.arr.length", function()
      local parsed = {
        passages = {
          {name = "Start", content = "There are $items's length items", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("s%.items%.length", result)
    end)

    it("should convert ($arr contains X) to s.arr.includes(X)", function()
      local parsed = {
        passages = {
          {name = "Start", content = '(if: ($items contains "apple"))[Found!]', tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches('s%.items%.includes%("apple"%)', result)
    end)
  end)

  describe("Datamap Conversion", function()
    it("should convert (dm: \"key\", value) to {key: value}", function()
      local parsed = {
        passages = {
          {name = "Start", content = '(set: $person to (dm: "name", "Alice", "age", 30))', tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("{name: \"Alice\", age: 30}", result)
    end)

    it("should convert $map's key to s.map.key", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello, $person's name!", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("s%.person%.name", result)
    end)

    it("should convert (datanames: $map) to Object.keys(s.map)", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Keys: (datanames: $person)", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("Object%.keys%(s%.person%)", result)
    end)

    it("should convert (datavalues: $map) to Object.values(s.map)", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Values: (datavalues: $person)", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("Object%.values%(s%.person%)", result)
    end)
  end)

  describe("Combined Data Structures", function()
    it("should handle arrays and datamaps in same passage", function()
      local parsed = {
        passages = {
          {name = "Start", content = [[
(set: $items to (a: 1, 2, 3))
(set: $config to (dm: "enabled", true))
First: $items's 1st
Enabled: $config's enabled
]], tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("%[1, 2, 3%]", result)
      assert.matches("{enabled: true}", result)
      assert.matches("s%.items%[0%]", result)
      assert.matches("s%.config%.enabled", result)
    end)

    it("should preserve JavaScript validity", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(set: $x to (a: 1, 2))", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      -- Should produce valid JavaScript assignment
      assert.matches("<%%.*s%.x = %[1, 2%]", result)
    end)
  end)

  describe("Edge Cases", function()
    it("should handle empty array", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(set: $empty to (a:))", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("%[%]", result)
    end)

    it("should handle single element array", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(set: $single to (a: 42))", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("%[42%]", result)
    end)

    it("should handle datamap with single pair", function()
      local parsed = {
        passages = {
          {name = "Start", content = '(set: $single to (dm: "key", "value"))', tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("{key: \"value\"}", result)
    end)

    it("should handle high ordinal access (10th, 15th)", function()
      local parsed = {
        passages = {
          {name = "Start", content = "$list's 10th item and $list's 15th item", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("s%.list%[9%]", result)
      assert.matches("s%.list%[14%]", result)
    end)
  end)

end)
