-- Minimal story fixture for testing
-- A single-passage story with no choices

return {
  title = "Minimal Story",
  author = "Test Author",
  start_passage = "start",
  passages = {
    {
      name = "start",
      text = "This is a minimal test story with just one passage and no choices.",
      choices = {},
    }
  }
}
