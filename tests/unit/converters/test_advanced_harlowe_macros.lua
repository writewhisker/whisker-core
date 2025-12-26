-- Unit Tests for Advanced Harlowe Macro Conversions
local HarloweConverter = require("whisker.format.converters.harlowe")

describe("Advanced Harlowe Macros", function()

  describe("live macro to SugarCube", function()
    it("should convert (live: Xs)[body] to <<repeat>>", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(live: 2s)[Time: $time]", tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches("<<repeat 2s>>Time:", result)
      assert.matches("<</repeat>>", result)
    end)

    it("should preserve timing value", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(live: 5s)[Updating]", tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches("<<repeat 5s>>", result)
    end)
  end)

  describe("live macro to Chapbook", function()
    it("should convert (live:) to note with JS hint", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(live: 3s)[Content]", tags = {}}
        }
      }

      local result = HarloweConverter.to_chapbook(parsed)

      assert.matches("%[note%]Live update every 3s %(requires JS%)", result)
      assert.matches("Content", result)
    end)
  end)

  describe("live macro to Snowman", function()
    it("should convert (live:) to setInterval", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(live: 2s)[Update]", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("setInterval", result)
      assert.matches("2000", result)  -- 2 seconds = 2000ms
      assert.matches("Update", result)
    end)
  end)

  describe("click macro to SugarCube", function()
    it("should convert (click: ?hook)[action] to <<link>>", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(click: ?button)[do something]", tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches("<<link", result)
      assert.matches("click button", result)
    end)
  end)

  describe("click macro to Chapbook", function()
    it("should convert (click:) to {reveal link}", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(click: ?target)[revealed text]", tags = {}}
        }
      }

      local result = HarloweConverter.to_chapbook(parsed)

      assert.matches("{reveal link:", result)
      assert.matches("revealed text", result)
    end)
  end)

  describe("click macro to Snowman", function()
    it("should convert (click:) to onclick handler", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(click: ?btn)[action]", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches('onclick="', result)
      assert.matches("click btn", result)
    end)
  end)

  describe("mouseover macro to SugarCube", function()
    it("should convert (mouseover:) to comment", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(mouseover: ?tooltip)[Show tooltip]", tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches("/%* mouseover on tooltip not supported", result)
      assert.matches("Show tooltip", result)
    end)
  end)

  describe("mouseover macro to Chapbook", function()
    it("should convert (mouseover:) to note", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(mouseover: ?item)[Hover text]", tags = {}}
        }
      }

      local result = HarloweConverter.to_chapbook(parsed)

      assert.matches("%[note%]Mouseover on item not supported", result)
      assert.matches("Hover text", result)
    end)
  end)

  describe("mouseover macro to Snowman", function()
    it("should convert (mouseover:) to comment", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(mouseover: ?elem)[Tooltip]", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("<!%-%- mouseover on elem not supported %-%->", result)
      assert.matches("Tooltip", result)
    end)
  end)

  describe("mouseout macro", function()
    it("should convert (mouseout:) to comment in SugarCube", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(mouseout: ?box)[Hide content]", tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches("/%* mouseout on box not supported", result)
    end)

    it("should convert (mouseout:) to note in Chapbook", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(mouseout: ?area)[Hide]", tags = {}}
        }
      }

      local result = HarloweConverter.to_chapbook(parsed)

      assert.matches("%[note%]Mouseout on area not supported", result)
    end)
  end)

  describe("enchant macro to SugarCube", function()
    it("should convert CSS enchant to <<addclass>>", function()
      local parsed = {
        passages = {
          {name = "Start", content = '(enchant: "button", (css: "color", "red"))', tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches('<<addclass "button" "enchant%-color">>', result)
    end)

    it("should remove complex enchant with comment", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(enchant: ?hook, (text-style: 'bold'))", tags = {}}
        }
      }

      local result = HarloweConverter.to_sugarcube(parsed)

      assert.matches("/%* enchant removed:", result)
    end)
  end)

  describe("enchant macro to Chapbook", function()
    it("should convert (enchant:) to note", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(enchant: ?target, (css: 'background', 'blue'))", tags = {}}
        }
      }

      local result = HarloweConverter.to_chapbook(parsed)

      assert.matches("%[note%]Enchant removed:", result)
    end)
  end)

  describe("enchant macro to Snowman", function()
    it("should convert (enchant:) to comment", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(enchant: ?elem, (css: 'font-size', '20px'))", tags = {}}
        }
      }

      local result = HarloweConverter.to_snowman(parsed)

      assert.matches("<!%-%- enchant removed:", result)
    end)
  end)

  describe("report tracking", function()
    it("should track live as approximation in SugarCube", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(live: 2s)[Update]", tags = {}}
        }
      }

      local _, report = HarloweConverter.to_sugarcube_with_report(parsed)

      local approximated = report:get_details("approximated")
      assert.is_true(#approximated > 0)
      local found = false
      for _, approx in ipairs(approximated) do
        if approx.feature == "live" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("should track click as approximation in Chapbook", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(click: ?btn)[action]", tags = {}}
        }
      }

      local _, report = HarloweConverter.to_chapbook_with_report(parsed)

      local approximated = report:get_details("approximated")
      local found = false
      for _, approx in ipairs(approximated) do
        if approx.feature == "click" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("should track mouseover as approximation in Snowman", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(mouseover: ?tip)[text]", tags = {}}
        }
      }

      local _, report = HarloweConverter.to_snowman_with_report(parsed)

      local approximated = report:get_details("approximated")
      local found = false
      for _, approx in ipairs(approximated) do
        if approx.feature == "mouseover" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("should track enchant as approximation in SugarCube", function()
      local parsed = {
        passages = {
          {name = "Start", content = "(enchant: ?x, (css: 'a', 'b'))", tags = {}}
        }
      }

      local _, report = HarloweConverter.to_sugarcube_with_report(parsed)

      local approximated = report:get_details("approximated")
      local found = false
      for _, approx in ipairs(approximated) do
        if approx.feature == "enchant" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

end)
