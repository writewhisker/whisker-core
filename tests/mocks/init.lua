--- Test Mocks
-- Central export for all mock modules
-- @module tests.mocks
-- @author Whisker Core Team

return {
  MockBase = require("tests.mocks.mock_base"),
  MockState = require("tests.mocks.mock_state"),
  MockEngine = require("tests.mocks.mock_engine"),
  MockPlugin = require("tests.mocks.mock_plugin"),
  MockFactory = require("tests.mocks.mock_factory"),
  Spy = require("tests.mocks.spy"),
}
