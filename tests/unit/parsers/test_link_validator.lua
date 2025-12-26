-- Unit Tests for Link Validator
local link_validator = require("whisker.format.parsers.link_validator")

describe("Link Validator", function()
  describe("extract_harlowe_links", function()
    it("should extract arrow links", function()
      local content = "[[Go north->North]]\n[[Go south->South]]"
      local links = link_validator.extract_harlowe_links(content)

      assert.equals(2, #links)
      assert.equals("Go north", links[1].text)
      assert.equals("North", links[1].target)
      assert.equals("arrow", links[1].type)
    end)

    it("should extract simple links", function()
      local content = "[[Continue]]"
      local links = link_validator.extract_harlowe_links(content)

      assert.equals(1, #links)
      assert.equals("Continue", links[1].target)
      assert.equals("simple", links[1].type)
    end)

    it("should extract goto macros", function()
      local content = '(goto: "Secret Room")'
      local links = link_validator.extract_harlowe_links(content)

      assert.equals(1, #links)
      assert.equals("Secret Room", links[1].target)
      assert.equals("macro", links[1].type)
    end)

    it("should extract display macros", function()
      local content = '(display: "Header")'
      local links = link_validator.extract_harlowe_links(content)

      assert.equals(1, #links)
      assert.equals("Header", links[1].target)
    end)

    it("should extract multiple links", function()
      local content = "[[A]] and [[B->C]] and (goto: \"D\")"
      local links = link_validator.extract_harlowe_links(content)

      assert.equals(3, #links)
    end)
  end)

  describe("extract_sugarcube_links", function()
    it("should extract pipe links", function()
      local content = "[[Go north|North]]\n[[Go south|South]]"
      local links = link_validator.extract_sugarcube_links(content)

      assert.equals(2, #links)
      assert.equals("Go north", links[1].text)
      assert.equals("North", links[1].target)
      assert.equals("pipe", links[1].type)
    end)

    it("should extract simple links", function()
      local content = "[[Continue]]"
      local links = link_validator.extract_sugarcube_links(content)

      assert.equals(1, #links)
      assert.equals("Continue", links[1].target)
    end)

    it("should extract goto macros", function()
      local content = '<<goto "Next Room">>'
      local links = link_validator.extract_sugarcube_links(content)

      assert.equals(1, #links)
      assert.equals("Next Room", links[1].target)
    end)

    it("should extract goto with single quotes", function()
      local content = "<<goto 'Next Room'>>"
      local links = link_validator.extract_sugarcube_links(content)

      assert.equals(1, #links)
      assert.equals("Next Room", links[1].target)
    end)
  end)

  describe("extract_chapbook_links", function()
    it("should extract arrow links", function()
      local content = "[[Go->Destination]]"
      local links = link_validator.extract_chapbook_links(content)

      assert.equals(1, #links)
      assert.equals("Go", links[1].text)
      assert.equals("Destination", links[1].target)
    end)

    it("should extract simple links", function()
      local content = "[[Next]]"
      local links = link_validator.extract_chapbook_links(content)

      assert.equals(1, #links)
      assert.equals("Next", links[1].target)
    end)

    it("should extract link inserts", function()
      local content = "{link to: 'Secret'}"
      local links = link_validator.extract_chapbook_links(content)

      assert.equals(1, #links)
      assert.equals("Secret", links[1].target)
    end)
  end)

  describe("extract_snowman_links", function()
    it("should extract markdown links", function()
      local content = "[Go north](North)"
      local links = link_validator.extract_snowman_links(content)

      assert.equals(1, #links)
      assert.equals("Go north", links[1].text)
      assert.equals("North", links[1].target)
    end)

    it("should include external URLs for categorization", function()
      local content = "[Link](https://example.com)"
      local links = link_validator.extract_snowman_links(content)

      assert.equals(1, #links)
      assert.equals("https://example.com", links[1].target)
    end)

    it("should extract bracket links", function()
      local content = "[[Next]]"
      local links = link_validator.extract_snowman_links(content)

      assert.equals(1, #links)
      assert.equals("Next", links[1].target)
    end)
  end)

  describe("validate_links", function()
    it("should identify valid links", function()
      local links = {{target = "Next"}}
      local passages = {Next = true, End = true}

      local results = link_validator.validate_links(links, passages, "Start")
      assert.equals(1, #results.valid)
      assert.equals(0, #results.broken)
    end)

    it("should identify broken links", function()
      local links = {{target = "NonExistent"}}
      local passages = {Start = true, End = true}

      local results = link_validator.validate_links(links, passages, "Start")
      assert.equals(0, #results.valid)
      assert.equals(1, #results.broken)
    end)

    it("should identify external links", function()
      local links = {{target = "https://example.com"}}
      local passages = {Start = true}

      local results = link_validator.validate_links(links, passages, "Start")
      assert.equals(1, #results.external)
      assert.equals(0, #results.broken)
    end)

    it("should identify mailto links as external", function()
      local links = {{target = "mailto:test@example.com"}}
      local passages = {Start = true}

      local results = link_validator.validate_links(links, passages, "Start")
      assert.equals(1, #results.external)
    end)

    it("should do case-insensitive matching", function()
      local links = {{target = "next"}}
      local passages = {Next = true}

      local results = link_validator.validate_links(links, passages, "Start")
      assert.equals(1, #results.valid)
      assert.equals("Next", results.valid[1].suggestion)
    end)

    it("should record from_passage for broken links", function()
      local links = {{target = "Missing"}}
      local passages = {Start = true}

      local results = link_validator.validate_links(links, passages, "Start")
      assert.equals("Start", results.broken[1].from_passage)
    end)
  end)

  describe("validate_story", function()
    it("should validate all links in story", function()
      local story = {
        passages = {
          {name = "Start", content = "[[Next]]\n[[End]]"},
          {name = "Next", content = "[[End]]"},
          {name = "End", content = "The end."}
        }
      }

      local results = link_validator.validate_story(story, "harlowe")
      assert.equals(3, results.total_links)
      assert.equals(3, results.valid_count)
      assert.equals(0, results.broken_count)
    end)

    it("should find broken links", function()
      local story = {
        passages = {
          {name = "Start", content = "[[Missing]]"},
        }
      }

      local results = link_validator.validate_story(story, "harlowe")
      assert.equals(1, results.broken_count)
      assert.equals("Missing", results.broken_links[1].target)
    end)

    it("should use correct format extractor", function()
      local story = {
        passages = {
          {name = "Start", content = "[[Go|Next]]"},
          {name = "Next", content = "Done"}
        }
      }

      local results = link_validator.validate_story(story, "sugarcube")
      assert.equals(1, results.valid_count)
    end)

    it("should track results by passage", function()
      local story = {
        passages = {
          {name = "Start", content = "[[A->B]]"},
          {name = "B", content = "[[C]]"},
          {name = "C", content = "End"}
        }
      }

      local results = link_validator.validate_story(story, "harlowe")
      assert.is_table(results.by_passage.Start)
      assert.is_table(results.by_passage.B)
    end)

    it("should count external links", function()
      local story = {
        passages = {
          {name = "Start", content = "[Google](https://google.com)"}
        }
      }

      local results = link_validator.validate_story(story, "snowman")
      assert.equals(1, results.external_count)
    end)
  end)
end)
