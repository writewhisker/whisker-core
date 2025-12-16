-- whisker/interfaces/format.lua
-- IFormat interface definition
-- Story format handlers must implement this interface

local IFormat = {
  _name = "IFormat",
  _description = "Story format handler for import/export operations",
  _required = {"can_import", "import", "can_export", "export"},
  _optional = {"name", "version", "extensions"},

  -- Check if this format can import the given source
  -- @param source string|table - Source data to check
  -- @return boolean - True if format can handle this source
  can_import = "function(self, source) -> boolean",

  -- Import source data into a Story object
  -- @param source string|table - Source data to import
  -- @return Story - Parsed story object
  import = "function(self, source) -> Story",

  -- Check if this format can export the given story
  -- @param story Story - Story to check
  -- @return boolean - True if format can export this story
  can_export = "function(self, story) -> boolean",

  -- Export story to this format
  -- @param story Story - Story to export
  -- @return string - Exported data
  export = "function(self, story) -> string",
}

return IFormat
