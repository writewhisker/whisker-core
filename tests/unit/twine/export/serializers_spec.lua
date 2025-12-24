--- Serializer unit tests
-- Tests format-specific AST to text serializers
--
-- tests/unit/twine/export/serializers_spec.lua

describe("Serializers", function()
  local HarloweSerializer
  local SugarCubeSerializer
  local ChapbookSerializer
  local SnowmanSerializer
  local FormatTemplateProvider

  before_each(function()
    package.loaded['whisker.twine.export.serializers.harlowe_serializer'] = nil
    package.loaded['whisker.twine.export.serializers.sugarcube_serializer'] = nil
    package.loaded['whisker.twine.export.serializers.chapbook_serializer'] = nil
    package.loaded['whisker.twine.export.serializers.snowman_serializer'] = nil
    package.loaded['whisker.twine.export.format_template_provider'] = nil

    HarloweSerializer = require('whisker.twine.export.serializers.harlowe_serializer')
    SugarCubeSerializer = require('whisker.twine.export.serializers.sugarcube_serializer')
    ChapbookSerializer = require('whisker.twine.export.serializers.chapbook_serializer')
    SnowmanSerializer = require('whisker.twine.export.serializers.snowman_serializer')
    FormatTemplateProvider = require('whisker.twine.export.format_template_provider')
  end)

  describe("HarloweSerializer", function()
    it("serializes text nodes", function()
      local ast = {
        { type = "text", value = "Hello, world!" }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.equals("Hello, world!", text)
    end)

    it("serializes assignment", function()
      local ast = {
        {
          type = "assignment",
          variable = "gold",
          value = { type = "literal", value_type = "number", value = 100 }
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.equals("(set: $gold to 100)", text)
    end)

    it("serializes string assignment", function()
      local ast = {
        {
          type = "assignment",
          variable = "name",
          value = { type = "literal", value_type = "string", value = "Hero" }
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.equals('(set: $name to "Hero")', text)
    end)

    it("serializes simple conditional", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = {
            { type = "text", value = "Rich!" }
          }
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.is_true(text:find("%(if:") ~= nil)
      assert.is_true(text:find("%$gold > 50") ~= nil)
      assert.is_true(text:find("Rich!") ~= nil)
    end)

    it("serializes conditional with else", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = { { type = "text", value = "Rich!" } },
          else_body = { { type = "text", value = "Poor!" } }
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.is_true(text:find("%(else:%)") ~= nil)
      assert.is_true(text:find("Poor!") ~= nil)
    end)

    it("serializes simple link", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "Go north"
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.equals("[[Go north]]", text)
    end)

    it("serializes link-goto", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "North Room"
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.equals('(link-goto: "Go north", "North Room")', text)
    end)

    it("serializes goto", function()
      local ast = {
        { type = "goto", destination = "End" }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.equals('(goto: "End")', text)
    end)

    it("converts == to is", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = "==",
            left = { type = "variable_ref", name = "state" },
            right = { type = "literal", value_type = "string", value = "ready" }
          },
          body = { { type = "text", value = "Go!" } }
        }
      }

      local text = HarloweSerializer.serialize(ast)
      assert.is_true(text:find(" is ") ~= nil)
    end)

    it("handles empty AST", function()
      local text = HarloweSerializer.serialize({})
      assert.equals("", text)
    end)

    it("handles nil AST", function()
      local text = HarloweSerializer.serialize(nil)
      assert.equals("", text)
    end)
  end)

  describe("SugarCubeSerializer", function()
    it("serializes text nodes", function()
      local ast = {
        { type = "text", value = "Hello, world!" }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.equals("Hello, world!", text)
    end)

    it("serializes assignment", function()
      local ast = {
        {
          type = "assignment",
          variable = "gold",
          value = { type = "literal", value_type = "number", value = 100 }
        }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.equals("<<set $gold to 100>>", text)
    end)

    it("serializes if/endif", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = {
            { type = "text", value = "Rich!" }
          }
        }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.is_true(text:find("<<if %$gold > 50>>") ~= nil)
      assert.is_true(text:find("Rich!") ~= nil)
      assert.is_true(text:find("<</if>>") ~= nil)
    end)

    it("serializes if/else/endif", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = { { type = "text", value = "Rich!" } },
          else_body = { { type = "text", value = "Poor!" } }
        }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.is_true(text:find("<<else>>") ~= nil)
      assert.is_true(text:find("Poor!") ~= nil)
    end)

    it("serializes simple wiki link", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "Go north"
        }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.equals("[[Go north]]", text)
    end)

    it("serializes arrow link", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "North Room"
        }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.equals("[[Go north->North Room]]", text)
    end)

    it("serializes goto", function()
      local ast = {
        { type = "goto", destination = "End" }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.equals('<<goto "End">>', text)
    end)

    it("serializes print", function()
      local ast = {
        {
          type = "print",
          expression = { type = "variable_ref", name = "score" }
        }
      }

      local text = SugarCubeSerializer.serialize(ast)
      assert.equals("<<print $score>>", text)
    end)
  end)

  describe("ChapbookSerializer", function()
    it("serializes text nodes", function()
      local ast = {
        { type = "text", value = "Hello, world!" }
      }

      local text = ChapbookSerializer.serialize(ast)
      assert.equals("Hello, world!", text)
    end)

    it("serializes assignment (no $ prefix)", function()
      local ast = {
        {
          type = "assignment",
          variable = "gold",
          value = { type = "literal", value_type = "number", value = 100 }
        }
      }

      local text = ChapbookSerializer.serialize(ast)
      assert.equals("gold: 100", text)
    end)

    it("serializes string assignment with single quotes", function()
      local ast = {
        {
          type = "assignment",
          variable = "name",
          value = { type = "literal", value_type = "string", value = "Hero" }
        }
      }

      local text = ChapbookSerializer.serialize(ast)
      assert.equals("name: 'Hero'", text)
    end)

    it("serializes conditional with [if]", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = {
            { type = "text", value = "Rich!" }
          }
        }
      }

      local text = ChapbookSerializer.serialize(ast)
      assert.is_true(text:find("%[if gold > 50%]") ~= nil)
      assert.is_true(text:find("Rich!") ~= nil)
    end)

    it("serializes simple link", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "Go north"
        }
      }

      local text = ChapbookSerializer.serialize(ast)
      assert.equals("[[Go north]]", text)
    end)

    it("serializes arrow link", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "North Room"
        }
      }

      local text = ChapbookSerializer.serialize(ast)
      assert.equals("[[Go north->North Room]]", text)
    end)
  end)

  describe("SnowmanSerializer", function()
    it("serializes text nodes", function()
      local ast = {
        { type = "text", value = "Hello, world!" }
      }

      local text = SnowmanSerializer.serialize(ast)
      assert.equals("Hello, world!", text)
    end)

    it("serializes assignment with s. prefix", function()
      local ast = {
        {
          type = "assignment",
          variable = "gold",
          value = { type = "literal", value_type = "number", value = 100 }
        }
      }

      local text = SnowmanSerializer.serialize(ast)
      assert.is_true(text:find("s%.gold = 100") ~= nil)
      assert.is_true(text:find("<%%") ~= nil)
      assert.is_true(text:find("%%>") ~= nil)
    end)

    it("serializes conditional", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = {
            { type = "text", value = "Rich!" }
          }
        }
      }

      local text = SnowmanSerializer.serialize(ast)
      assert.is_true(text:find("if %(s%.gold > 50%)") ~= nil)
      assert.is_true(text:find("Rich!") ~= nil)
      assert.is_true(text:find("} %%>") ~= nil)
    end)

    it("serializes data-passage link", function()
      local ast = {
        {
          type = "choice",
          text = "Go north",
          destination = "North Room"
        }
      }

      local text = SnowmanSerializer.serialize(ast)
      assert.is_true(text:find('data%-passage="North Room"') ~= nil)
      assert.is_true(text:find(">Go north</a>") ~= nil)
    end)

    it("serializes print expression", function()
      local ast = {
        {
          type = "print",
          expression = { type = "variable_ref", name = "score" }
        }
      }

      local text = SnowmanSerializer.serialize(ast)
      assert.is_true(text:find("<%%=") ~= nil)
      assert.is_true(text:find("s%.score") ~= nil)
    end)

    it("converts ~= to !=", function()
      local ast = {
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = "~=",
            left = { type = "variable_ref", name = "state" },
            right = { type = "literal", value_type = "string", value = "error" }
          },
          body = { { type = "text", value = "OK" } }
        }
      }

      local text = SnowmanSerializer.serialize(ast)
      assert.is_true(text:find("!=") ~= nil)
    end)
  end)

  describe("FormatTemplateProvider", function()
    it("provides engine code for supported formats", function()
      local harlowe = FormatTemplateProvider.get_engine_code("harlowe")
      local sugarcube = FormatTemplateProvider.get_engine_code("sugarcube")
      local chapbook = FormatTemplateProvider.get_engine_code("chapbook")
      local snowman = FormatTemplateProvider.get_engine_code("snowman")

      assert.is_true(#harlowe > 0)
      assert.is_true(#sugarcube > 0)
      assert.is_true(#chapbook > 0)
      assert.is_true(#snowman > 0)

      assert.is_true(harlowe:find("Harlowe") ~= nil)
      assert.is_true(sugarcube:find("SugarCube") ~= nil)
      assert.is_true(chapbook:find("Chapbook") ~= nil)
      assert.is_true(snowman:find("Snowman") ~= nil)
    end)

    it("returns empty for unknown format", function()
      local unknown = FormatTemplateProvider.get_engine_code("unknown")
      assert.equals("", unknown)
    end)

    it("checks format support", function()
      assert.is_true(FormatTemplateProvider.is_supported("harlowe"))
      assert.is_true(FormatTemplateProvider.is_supported("Harlowe"))
      assert.is_true(FormatTemplateProvider.is_supported("SUGARCUBE"))
      assert.is_false(FormatTemplateProvider.is_supported("unknown"))
    end)

    it("lists supported formats", function()
      local formats = FormatTemplateProvider.get_supported_formats()
      assert.equals(4, #formats)
    end)
  end)

  describe("round-trip consistency", function()
    -- These tests verify that serializers produce output
    -- that could be re-parsed (conceptual round-trip)

    it("serializes complex mixed content", function()
      local ast = {
        { type = "text", value = "Welcome to the game.\n" },
        {
          type = "assignment",
          variable = "gold",
          value = { type = "literal", value_type = "number", value = 100 }
        },
        {
          type = "conditional",
          condition = {
            type = "binary_op",
            operator = ">",
            left = { type = "variable_ref", name = "gold" },
            right = { type = "literal", value_type = "number", value = 50 }
          },
          body = {
            { type = "text", value = "You have plenty of gold." }
          }
        },
        {
          type = "choice",
          text = "Continue",
          destination = "Next Room"
        }
      }

      local harlowe = HarloweSerializer.serialize(ast)
      local sugarcube = SugarCubeSerializer.serialize(ast)
      local chapbook = ChapbookSerializer.serialize(ast)
      local snowman = SnowmanSerializer.serialize(ast)

      -- All should produce non-empty output
      assert.is_true(#harlowe > 0)
      assert.is_true(#sugarcube > 0)
      assert.is_true(#chapbook > 0)
      assert.is_true(#snowman > 0)

      -- All should contain the text
      assert.is_true(harlowe:find("Welcome") ~= nil)
      assert.is_true(sugarcube:find("Welcome") ~= nil)
      assert.is_true(chapbook:find("Welcome") ~= nil)
      assert.is_true(snowman:find("Welcome") ~= nil)
    end)
  end)
end)
