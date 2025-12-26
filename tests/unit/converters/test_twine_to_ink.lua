-- Unit Tests for Twine to Ink Conversion
local HarloweConverter = require("whisker.format.converters.harlowe")
local SugarCubeConverter = require("whisker.format.converters.sugarcube")
local ChapbookConverter = require("whisker.format.converters.chapbook")
local SnowmanConverter = require("whisker.format.converters.snowman")

describe("Twine to Ink Conversion", function()

  describe("Harlowe to Ink", function()
    it("should convert passages to knots", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello!", tags = {}},
          {name = "End", content = "Goodbye!", tags = {}}
        }
      }

      local result = HarloweConverter.to_ink(parsed)

      assert.matches("=== Start ===", result)
      assert.matches("=== End ===", result)
      assert.matches("Hello!", result)
      assert.matches("Goodbye!", result)
    end)

    it("should convert set macro to VAR and assignment", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(set: $score to 0)\nHello!", tags = {}}
        }
      }

      local result = HarloweConverter.to_ink(parsed)

      assert.matches("VAR score = 0", result)
      assert.matches("~ score = 0", result)
    end)

    it("should convert links to choices", function()
      local parsed = {
        passages = {
          {name = "Start", content = "[[Go north->North]]", tags = {}}
        }
      }

      local result = HarloweConverter.to_ink(parsed)

      assert.matches("%* %[Go north%] %-> North", result)
    end)

    it("should convert if macro to conditional", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(if: $x > 5)[Big!]", tags = {}}
        }
      }

      local result = HarloweConverter.to_ink(parsed)

      assert.matches("{x > 5: Big!}", result)
    end)

    it("should convert variable interpolation", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello $name!", tags = {}}
        }
      }

      local result = HarloweConverter.to_ink(parsed)

      assert.matches("{name}", result)
    end)

    it("should generate report with to_ink_with_report", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(set: $x to 5)\n[[Link->Target]]", tags = {}}
        }
      }

      local result, report = HarloweConverter.to_ink_with_report(parsed)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("harlowe", report.source_format)
      assert.equals("ink", report.target_format)
    end)
  end)

  describe("SugarCube to Ink", function()
    it("should convert passages to knots", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello!", tags = {}}
        }
      }

      local result = SugarCubeConverter.to_ink(parsed)

      assert.matches("=== Start ===", result)
      assert.matches("Hello!", result)
    end)

    it("should convert set macro to VAR and assignment", function()
      local parsed = {
        passages = {
          {name = "Start", content = "<<set $score to 0>>\nHello!", tags = {}}
        }
      }

      local result = SugarCubeConverter.to_ink(parsed)

      assert.matches("VAR score = 0", result)
      assert.matches("~ score = 0", result)
    end)

    it("should convert links to choices", function()
      local parsed = {
        passages = {
          {name = "Start", content = "[[Go north|North]]", tags = {}}
        }
      }

      local result = SugarCubeConverter.to_ink(parsed)

      assert.matches("%* %[Go north%] %-> North", result)
    end)

    it("should convert variable interpolation", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello $name!", tags = {}}
        }
      }

      local result = SugarCubeConverter.to_ink(parsed)

      assert.matches("{name}", result)
    end)

    it("should generate report with to_ink_with_report", function()
      local parsed = {
        passages = {
          {name = "Start", content = "<<set $x to 5>>", tags = {}}
        }
      }

      local result, report = SugarCubeConverter.to_ink_with_report(parsed)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("sugarcube", report.source_format)
      assert.equals("ink", report.target_format)
    end)
  end)

  describe("Chapbook to Ink", function()
    it("should convert passages to knots", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello!", tags = {}}
        }
      }

      local result = ChapbookConverter.to_ink(parsed)

      assert.matches("=== Start ===", result)
      assert.matches("Hello!", result)
    end)

    it("should convert vars section to VAR", function()
      local parsed = {
        passages = {
          {name = "Start", content = "score: 0\n--\nHello!", tags = {}}
        }
      }

      local result = ChapbookConverter.to_ink(parsed)

      assert.matches("VAR score = 0", result)
    end)

    it("should convert links to choices", function()
      local parsed = {
        passages = {
          {name = "Start", content = "[[Go north->North]]", tags = {}}
        }
      }

      local result = ChapbookConverter.to_ink(parsed)

      assert.matches("%* %[Go north%] %-> North", result)
    end)

    it("should generate report with to_ink_with_report", function()
      local parsed = {
        passages = {
          {name = "Start", content = "[[Link->Target]]", tags = {}}
        }
      }

      local result, report = ChapbookConverter.to_ink_with_report(parsed)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("chapbook", report.source_format)
      assert.equals("ink", report.target_format)
    end)
  end)

  describe("Snowman to Ink", function()
    it("should convert passages to knots", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello!", tags = {}}
        }
      }

      local result = SnowmanConverter.to_ink(parsed)

      assert.matches("=== Start ===", result)
      assert.matches("Hello!", result)
    end)

    it("should convert variable assignments to VAR", function()
      local parsed = {
        passages = {
          {name = "Start", content = "<% s.score = 0; %>\nHello!", tags = {}}
        }
      }

      local result = SnowmanConverter.to_ink(parsed)

      assert.matches("VAR score = 0", result)
    end)

    it("should convert variable interpolation", function()
      local parsed = {
        passages = {
          {name = "Start", content = "Hello <%= s.name %>!", tags = {}}
        }
      }

      local result = SnowmanConverter.to_ink(parsed)

      assert.matches("{name}", result)
    end)

    it("should convert links to choices", function()
      local parsed = {
        passages = {
          {name = "Start", content = "[Go north](North)", tags = {}}
        }
      }

      local result = SnowmanConverter.to_ink(parsed)

      assert.matches("%* %[Go north%] %-> North", result)
    end)

    it("should generate report with to_ink_with_report", function()
      local parsed = {
        passages = {
          {name = "Start", content = "<% s.x = 5; %>", tags = {}}
        }
      }

      local result, report = SnowmanConverter.to_ink_with_report(parsed)

      assert.is_not_nil(result)
      assert.is_not_nil(report)
      assert.equals("snowman", report.source_format)
      assert.equals("ink", report.target_format)
    end)
  end)

end)
