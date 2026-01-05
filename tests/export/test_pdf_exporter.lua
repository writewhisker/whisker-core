--- PDF Exporter Tests
-- Tests for the PDF export functionality
-- @module tests.export.test_pdf_exporter

local PDFExporter = require("whisker.export.pdf.pdf_exporter")
local PDFGenerator = require("whisker.export.pdf.pdf_generator")

describe("PDF Generator", function()
  describe("initialization", function()
    it("should create a new PDF generator with default settings", function()
      local pdf = PDFGenerator.new()
      assert.is_not_nil(pdf)
      local width, height = pdf:get_page_size()
      assert.is_true(width > 0)
      assert.is_true(height > 0)
    end)

    it("should create PDF with A4 format", function()
      local pdf = PDFGenerator.new({ format = "a4" })
      local width, height = pdf:get_page_size()
      assert.are.near(595.28, width, 0.1)
      assert.are.near(841.89, height, 0.1)
    end)

    it("should create PDF with letter format", function()
      local pdf = PDFGenerator.new({ format = "letter" })
      local width, height = pdf:get_page_size()
      assert.equals(612, width)
      assert.equals(792, height)
    end)

    it("should create PDF with landscape orientation", function()
      local pdf = PDFGenerator.new({ format = "a4", orientation = "landscape" })
      local width, height = pdf:get_page_size()
      assert.are.near(841.89, width, 0.1)
      assert.are.near(595.28, height, 0.1)
    end)
  end)

  describe("page management", function()
    it("should add a new page", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      assert.is_not_nil(pdf.current_page)
    end)

    it("should track multiple pages", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      pdf:add_page()
      pdf:add_page()
      assert.equals(3, #pdf.pages)
    end)
  end)

  describe("text operations", function()
    it("should set font", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      pdf:set_font("helvetica-bold", 14)
      assert.equals("helvetica-bold", pdf.current_font)
      assert.equals(14, pdf.font_size)
    end)

    it("should split text to fit width", function()
      local pdf = PDFGenerator.new()
      pdf:set_font_size(12)
      local lines = pdf:split_text_to_size("This is a very long line of text that should be split into multiple lines", 100)
      assert.is_true(#lines > 1)
    end)

    it("should handle empty text", function()
      local pdf = PDFGenerator.new()
      local lines = pdf:split_text_to_size("", 100)
      assert.equals(0, #lines)
    end)

    it("should add text to page", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      pdf:text("Hello, World!", 100, 700)
      assert.is_true(#pdf.current_page.content > 0)
    end)
  end)

  describe("output generation", function()
    it("should generate valid PDF output", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      pdf:text("Test", 100, 700)
      local output = pdf:output()
      assert.is_string(output)
      assert.is_true(output:match("^%%PDF%-1%.4") ~= nil)
      assert.is_true(output:match("%%%%EOF") ~= nil)
    end)

    it("should include catalog object", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      local output = pdf:output()
      assert.is_true(output:match("/Type /Catalog") ~= nil)
    end)

    it("should include pages object", function()
      local pdf = PDFGenerator.new()
      pdf:add_page()
      local output = pdf:output()
      assert.is_true(output:match("/Type /Pages") ~= nil)
    end)
  end)
end)

describe("PDF Exporter", function()
  local function create_basic_story()
    return {
      name = "Test Story",
      title = "Test Story",
      author = "Test Author",
      start_passage = "Start",
      passages = {
        {
          name = "Start",
          text = "Welcome to the test story!\n\nThis is an adventure.",
          choices = {
            { text = "Begin", target = "Next" },
          },
        },
        {
          name = "Next",
          text = "This is the second passage.",
          choices = {
            { text = "Continue", target = "End" },
          },
        },
        {
          name = "End",
          text = "The End!",
          choices = {},
        },
      },
    }
  end

  local function create_complex_story()
    return {
      name = "Complex Story",
      author = "Tester",
      description = "A complex interactive story with multiple paths and choices.",
      start = "Start",
      created = os.time(),
      passages = {
        {
          name = "Start",
          text = "You are at a crossroads. Which way do you go?",
          choices = {
            { text = "Go left", target = "Left" },
            { text = "Go right", target = "Right" },
            { text = "Go straight", target = "Center" },
          },
        },
        {
          name = "Left",
          text = "You went left and found a treasure chest!",
          choices = {
            { text = "Open it", target = "Treasure" },
            { text = "Leave it", target = "End" },
          },
        },
        {
          name = "Right",
          text = "You went right and encountered a dragon!",
          choices = {
            { text = "Fight", target = "Fight" },
            { text = "Run", target = "Start" },
          },
        },
        {
          name = "Center",
          text = "You continued straight ahead.",
          choices = {},
        },
        {
          name = "Treasure",
          text = "You found gold coins!",
          choices = {},
        },
        {
          name = "Fight",
          text = "You bravely fought the dragon!",
          choices = {},
        },
        {
          name = "End",
          text = "The adventure ends here.",
          choices = {},
        },
      },
    }
  end

  describe("initialization", function()
    it("should create a new exporter", function()
      local exporter = PDFExporter.new()
      assert.is_not_nil(exporter)
    end)

    it("should provide metadata", function()
      local exporter = PDFExporter.new()
      local meta = exporter:metadata()
      assert.equals("pdf", meta.format)
      assert.equals(".pdf", meta.file_extension)
      assert.is_not_nil(meta.description)
    end)
  end)

  describe("can_export", function()
    it("should return true for valid story", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local can, err = exporter:can_export(story)
      assert.is_true(can)
      assert.is_nil(err)
    end)

    it("should return false for nil story", function()
      local exporter = PDFExporter.new()
      local can, err = exporter:can_export(nil)
      assert.is_false(can)
      assert.is_not_nil(err)
    end)

    it("should return false for story without passages", function()
      local exporter = PDFExporter.new()
      local can, err = exporter:can_export({ name = "Empty" })
      assert.is_false(can)
      assert.is_not_nil(err)
    end)

    it("should return false for story with empty passages", function()
      local exporter = PDFExporter.new()
      local can, err = exporter:can_export({ name = "Empty", passages = {} })
      assert.is_false(can)
      assert.is_not_nil(err)
    end)
  end)

  describe("export modes", function()
    it("should export in playable mode (default)", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.is_not_nil(result)
      assert.is_not_nil(result.content)
      assert.is_nil(result.error)
      assert.is_true(#result.content > 0)
    end)

    it("should export in manuscript mode", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { mode = "manuscript" })
      assert.is_not_nil(result)
      assert.is_not_nil(result.content)
      assert.equals("manuscript", result.manifest.mode)
    end)

    it("should export in outline mode", function()
      local exporter = PDFExporter.new()
      local story = create_complex_story()
      local result = exporter:export(story, { mode = "outline" })
      assert.is_not_nil(result)
      assert.is_not_nil(result.content)
      assert.equals("outline", result.manifest.mode)
    end)
  end)

  describe("export options", function()
    it("should respect page format option", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { format = "letter" })
      assert.is_not_nil(result)
      assert.equals("letter", result.manifest.page_format)
    end)

    it("should respect orientation option", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story, { orientation = "landscape" })
      assert.is_not_nil(result)
      assert.equals("landscape", result.manifest.orientation)
    end)

    it("should include TOC by default", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      -- TOC is included but we can verify content exists
      assert.is_true(#result.content > 1000) -- Basic story with TOC should be larger
    end)

    it("should skip TOC when disabled", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local with_toc = exporter:export(story, { include_toc = true })
      local without_toc = exporter:export(story, { include_toc = false })
      -- Without TOC should be smaller
      assert.is_true(#without_toc.content < #with_toc.content)
    end)
  end)

  describe("content generation", function()
    it("should generate valid PDF header", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.is_true(result.content:match("^%%PDF%-1%.4") ~= nil)
    end)

    it("should generate valid PDF trailer", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.is_true(result.content:match("%%%%EOF") ~= nil)
    end)

    it("should include story title in content", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      -- Title should appear in the PDF somewhere
      assert.is_true(result.content:match("Test Story") ~= nil)
    end)
  end)

  describe("manifest", function()
    it("should include format in manifest", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.equals("pdf", result.manifest.format)
    end)

    it("should include passage count in manifest", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.equals(3, result.manifest.passage_count)
    end)

    it("should include filename in manifest", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local result = exporter:export(story)
      assert.is_not_nil(result.manifest.filename)
      assert.is_true(result.manifest.filename:match("%.pdf$") ~= nil)
    end)
  end)

  describe("validation", function()
    it("should validate valid bundle", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local bundle = exporter:export(story)
      local validation = exporter:validate(bundle)
      assert.is_true(validation.valid)
      assert.equals(0, #validation.errors)
    end)

    it("should reject empty bundle", function()
      local exporter = PDFExporter.new()
      local validation = exporter:validate({ content = "" })
      assert.is_false(validation.valid)
      assert.is_true(#validation.errors > 0)
    end)

    it("should reject invalid PDF content", function()
      local exporter = PDFExporter.new()
      local validation = exporter:validate({ content = "not a pdf" })
      assert.is_false(validation.valid)
    end)
  end)

  describe("option validation", function()
    it("should accept valid options", function()
      local exporter = PDFExporter.new()
      local errors = exporter:validate_options({
        format = "a4",
        orientation = "portrait",
        mode = "playable",
        font_size = 11,
        line_height = 1.5,
        margin = 56,
      })
      assert.equals(0, #errors)
    end)

    it("should reject invalid format", function()
      local exporter = PDFExporter.new()
      local errors = exporter:validate_options({ format = "invalid" })
      assert.is_true(#errors > 0)
    end)

    it("should reject invalid mode", function()
      local exporter = PDFExporter.new()
      local errors = exporter:validate_options({ mode = "invalid" })
      assert.is_true(#errors > 0)
    end)

    it("should reject out-of-range font size", function()
      local exporter = PDFExporter.new()
      local errors = exporter:validate_options({ font_size = 100 })
      assert.is_true(#errors > 0)
    end)
  end)

  describe("size estimation", function()
    it("should estimate export size", function()
      local exporter = PDFExporter.new()
      local story = create_basic_story()
      local size = exporter:estimate_size(story)
      assert.is_true(size > 0)
    end)

    it("should estimate larger size for more passages", function()
      local exporter = PDFExporter.new()
      local small_story = create_basic_story()
      local large_story = create_complex_story()
      local small_size = exporter:estimate_size(small_story)
      local large_size = exporter:estimate_size(large_story)
      assert.is_true(large_size > small_size)
    end)
  end)

  describe("edge cases", function()
    it("should handle story with empty passage content", function()
      local exporter = PDFExporter.new()
      local story = {
        name = "Empty Content",
        passages = {
          { name = "Start", text = "", choices = {} },
        },
      }
      local result = exporter:export(story)
      assert.is_not_nil(result.content)
    end)

    it("should handle story with special characters", function()
      local exporter = PDFExporter.new()
      local story = {
        name = "Special <>&\"' Characters",
        author = "Test & Author",
        passages = {
          {
            name = "Start",
            text = "Special: <>&\"'\nMore: (parentheses) [brackets]",
            choices = {},
          },
        },
      }
      local result = exporter:export(story)
      assert.is_not_nil(result.content)
    end)

    it("should handle story with unicode content", function()
      local exporter = PDFExporter.new()
      local story = {
        name = "Unicode Test",
        passages = {
          { name = "Start", text = "Hello World", choices = {} },
        },
      }
      local result = exporter:export(story)
      assert.is_not_nil(result.content)
    end)

    it("should handle story with very long content", function()
      local exporter = PDFExporter.new()
      local long_text = string.rep("This is a long passage with lots of text. ", 100)
      local story = {
        name = "Long Content",
        passages = {
          { name = "Start", text = long_text, choices = {} },
        },
      }
      local result = exporter:export(story)
      assert.is_not_nil(result.content)
    end)

    it("should handle story with no start passage defined", function()
      local exporter = PDFExporter.new()
      local story = {
        name = "No Start",
        passages = {
          { name = "One", text = "First", choices = {} },
          { name = "Two", text = "Second", choices = {} },
        },
      }
      local result = exporter:export(story)
      assert.is_not_nil(result.content)
    end)
  end)
end)
