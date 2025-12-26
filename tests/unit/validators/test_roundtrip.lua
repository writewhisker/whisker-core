-- Unit Tests for Round-trip Validator
local RoundtripValidator = require("whisker.format.validators.roundtrip")

describe("Round-trip Validator", function()
  local validator

  before_each(function()
    validator = RoundtripValidator.new()
  end)

  describe("normalize", function()
    it("should remove extra whitespace", function()
      local result = validator:normalize("hello   world")
      assert.equals("hello world", result)
    end)

    it("should trim leading and trailing whitespace", function()
      local result = validator:normalize("  hello world  ")
      assert.equals("hello world", result)
    end)

    it("should handle nil", function()
      local result = validator:normalize(nil)
      assert.equals("", result)
    end)
  end)

  describe("compare_stories", function()
    it("should find identical stories identical", function()
      local story1 = {
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "End", content = "Goodbye", tags = {}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "End", content = "Goodbye", tags = {}}
        }
      }

      local result = validator:compare_stories(story1, story2)

      assert.is_true(result.identical)
      assert.is_true(result.passage_count_match)
      assert.equals(0, #result.differences)
    end)

    it("should detect missing passages", function()
      local story1 = {
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "Extra", content = "New", tags = {}}
        }
      }

      local result = validator:compare_stories(story1, story2)

      assert.is_false(result.identical)
      assert.is_false(result.passage_count_match)
      assert.is_true(#result.differences >= 1)
    end)

    it("should detect content differences", function()
      local story1 = {
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "Goodbye", tags = {}}
        }
      }

      local result = validator:compare_stories(story1, story2)

      assert.is_false(result.identical)
      assert.equals(1, #result.differences)
      assert.equals("content_mismatch", result.differences[1].type)
    end)

    it("should normalize whitespace when comparing", function()
      local story1 = {
        passages = {
          {name = "Start", content = "Hello  world", tags = {}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "Hello world", tags = {}}
        }
      }

      local result = validator:compare_stories(story1, story2)

      assert.is_true(result.identical)
    end)

    it("should detect tag differences", function()
      local story1 = {
        passages = {
          {name = "Start", content = "Hello", tags = {"important"}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local result = validator:compare_stories(story1, story2)

      assert.is_false(result.identical)
      local found_tag_diff = false
      for _, diff in ipairs(result.differences) do
        if diff.type == "tags_mismatch" then
          found_tag_diff = true
          break
        end
      end
      assert.is_true(found_tag_diff)
    end)
  end)

  describe("extract_links", function()
    it("should extract Harlowe-style links [[Text->Target]]", function()
      local content = "[[Go north->North]]"

      local links = validator:extract_links(content)

      assert.equals(1, #links)
      assert.equals("Go north", links[1].text)
      assert.equals("North", links[1].target)
    end)

    it("should extract SugarCube-style links [[Text|Target]]", function()
      local content = "[[Go north|North]]"

      local links = validator:extract_links(content)

      assert.equals(1, #links)
      assert.equals("Go north", links[1].text)
      assert.equals("North", links[1].target)
    end)

    it("should extract simple links [[Target]]", function()
      local content = "[[North]]"

      local links = validator:extract_links(content)

      assert.equals(1, #links)
      assert.equals("North", links[1].text)
      assert.equals("North", links[1].target)
    end)

    it("should extract Snowman-style links [Text](Target)", function()
      local content = "[Go north](North)"

      local links = validator:extract_links(content)

      assert.equals(1, #links)
      assert.equals("Go north", links[1].text)
      assert.equals("North", links[1].target)
    end)

    it("should extract multiple links", function()
      local content = "[[Go north->North]] or [[Go south->South]]"

      local links = validator:extract_links(content)

      assert.equals(2, #links)
    end)
  end)

  describe("compare_links", function()
    it("should find identical links preserved", function()
      local links1 = {{text = "Go", target = "North"}}
      local links2 = {{text = "Go", target = "North"}}

      local result = validator:compare_links(links1, links2)

      assert.is_true(result.preserved)
      assert.is_true(result.count_match)
    end)

    it("should detect missing links", function()
      local links1 = {{text = "Go", target = "North"}, {text = "Back", target = "South"}}
      local links2 = {{text = "Go", target = "North"}}

      local result = validator:compare_links(links1, links2)

      assert.is_false(result.preserved)
      assert.equals(1, #result.missing_from_2)
    end)

    it("should detect added links", function()
      local links1 = {{text = "Go", target = "North"}}
      local links2 = {{text = "Go", target = "North"}, {text = "New", target = "Extra"}}

      local result = validator:compare_links(links1, links2)

      assert.is_false(result.preserved)
      assert.equals(1, #result.missing_from_1)
    end)
  end)

  describe("extract_variables", function()
    it("should extract Harlowe variables", function()
      local content = "(set: $score to 100)(set: $name to 'Alice')"

      local vars = validator:extract_variables(content, "harlowe")

      assert.equals("100", vars.score)
      assert.equals("'Alice'", vars.name)
    end)

    it("should extract SugarCube variables", function()
      local content = "<<set $score to 100>><<set $name to 'Bob'>>"

      local vars = validator:extract_variables(content, "sugarcube")

      assert.equals("100", vars.score)
      assert.equals("'Bob'", vars.name)
    end)

    it("should extract Snowman variables", function()
      local content = "s.score = 100; s.name = 'Carol';"

      local vars = validator:extract_variables(content, "snowman")

      assert.equals("100", vars.score)
      assert.equals("'Carol'", vars.name)
    end)
  end)

  describe("compare_variables", function()
    it("should find identical variables preserved", function()
      local vars1 = {score = "100", name = "Alice"}
      local vars2 = {score = "100", name = "Alice"}

      local result = validator:compare_variables(vars1, vars2)

      assert.is_true(result.preserved)
      assert.equals(0, #result.differences)
    end)

    it("should detect missing variables", function()
      local vars1 = {score = "100", name = "Alice"}
      local vars2 = {score = "100"}

      local result = validator:compare_variables(vars1, vars2)

      assert.is_false(result.preserved)
      assert.is_true(#result.differences >= 1)
    end)

    it("should detect changed values", function()
      local vars1 = {score = "100"}
      local vars2 = {score = "200"}

      local result = validator:compare_variables(vars1, vars2)

      assert.is_false(result.preserved)
    end)
  end)

  describe("compare_semantics", function()
    it("should pass for semantically identical stories", function()
      local story1 = {
        passages = {
          {name = "Start", content = "(set: $x to 5)[[Next->End]]", tags = {}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "(set: $x to 5)[[Next->End]]", tags = {}}
        }
      }

      local result = validator:compare_semantics(story1, "harlowe", story2, "harlowe")

      assert.is_true(result.links_preserved)
      assert.is_true(result.variables_preserved)
    end)

    it("should detect semantic link differences", function()
      local story1 = {
        passages = {
          {name = "Start", content = "[[Go->End]]", tags = {}}
        }
      }
      local story2 = {
        passages = {
          {name = "Start", content = "[[Stay->Home]]", tags = {}}
        }
      }

      local result = validator:compare_semantics(story1, "harlowe", story2, "harlowe")

      assert.is_false(result.links_preserved)
    end)
  end)

  describe("validate_structure", function()
    it("should validate good story structure", function()
      local story = {
        name = "Test Story",
        passages = {
          {name = "Start", content = "Hello [[End]]", tags = {}},
          {name = "End", content = "Goodbye", tags = {}}
        }
      }

      local result = validator:validate_structure(story)

      assert.is_true(result.valid)
      assert.equals(0, #result.errors)
    end)

    it("should detect missing story name", function()
      local story = {
        passages = {
          {name = "Start", content = "Hello", tags = {}}
        }
      }

      local result = validator:validate_structure(story)

      assert.is_true(result.valid) -- Warning, not error
      assert.is_true(#result.warnings >= 1)
    end)

    it("should error on no passages", function()
      local story = {
        name = "Empty",
        passages = {}
      }

      local result = validator:validate_structure(story)

      assert.is_false(result.valid)
      assert.is_true(#result.errors >= 1)
    end)

    it("should error on duplicate passage names", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "Hello", tags = {}},
          {name = "Start", content = "Duplicate", tags = {}}
        }
      }

      local result = validator:validate_structure(story)

      assert.is_false(result.valid)
    end)

    it("should warn on empty passages", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "", tags = {}}
        }
      }

      local result = validator:validate_structure(story)

      assert.is_true(result.valid)
      assert.is_true(#result.warnings >= 1)
    end)

    it("should warn on broken links", function()
      local story = {
        name = "Test",
        passages = {
          {name = "Start", content = "[[Go->NonExistent]]", tags = {}}
        }
      }

      local result = validator:validate_structure(story)

      assert.is_true(result.valid)
      local found_broken = false
      for _, warn in ipairs(result.warnings) do
        if warn.type == "broken_link" then
          found_broken = true
          break
        end
      end
      assert.is_true(found_broken)
    end)
  end)

  describe("get_summary", function()
    it("should summarize identical stories", function()
      local comparison = {
        identical = true,
        passage_count_1 = 2,
        passage_count_2 = 2,
        differences = {}
      }

      local summary = validator:get_summary(comparison)

      assert.matches("identical", summary)
    end)

    it("should summarize different stories", function()
      local comparison = {
        identical = false,
        passage_count_1 = 2,
        passage_count_2 = 3,
        differences = {
          {description = "Content differs in passage 'Start'"}
        }
      }

      local summary = validator:get_summary(comparison)

      assert.matches("differ", summary)
      assert.matches("2 vs 3", summary)
    end)
  end)

end)
