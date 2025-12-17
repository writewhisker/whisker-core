-- spec/vendor/tinta_smoke_spec.lua
-- Smoke tests for vendored tinta library

describe("Vendored tinta", function()
  local tinta

  before_each(function()
    -- Clear cached modules for clean test
    for k in pairs(package.loaded) do
      if k:match("^whisker%.vendor%.tinta") then
        package.loaded[k] = nil
      end
    end
    -- Clear globals that tinta sets
    rawset(_G, "import", nil)
    rawset(_G, "compat", nil)
    rawset(_G, "dump", nil)
    rawset(_G, "classic", nil)

    tinta = require("whisker.vendor.tinta")
  end)

  describe("module loading", function()
    it("should load without error", function()
      assert.is_table(tinta)
    end)

    it("should have _whisker metadata", function()
      assert.is_table(tinta._whisker)
      assert.are.equal("tinta", tinta._whisker.name)
      assert.is_string(tinta._whisker.version)
      assert.is_string(tinta._whisker.source)
      assert.is_string(tinta._whisker.commit)
    end)

    it("should have Story function", function()
      assert.is_function(tinta.Story)
    end)

    it("should have create_story function", function()
      assert.is_function(tinta.create_story)
    end)

    it("should have cleanup function", function()
      assert.is_function(tinta.cleanup)
    end)
  end)

  describe("Story loading", function()
    it("should return Story constructor", function()
      local Story = tinta.Story()
      assert.is_table(Story)
    end)

    it("should set up global import function", function()
      tinta.Story()
      assert.is_function(rawget(_G, "import"))
    end)

    it("should set up global compat", function()
      tinta.Story()
      assert.is_table(rawget(_G, "compat"))
    end)
  end)
end)
