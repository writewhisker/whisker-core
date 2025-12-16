-- whisker/interfaces/serializer.lua
-- ISerializer interface definition
-- Data serializers must implement this interface

local ISerializer = {
  _name = "ISerializer",
  _description = "Data serialization for save/load operations",
  _required = {"serialize", "deserialize"},
  _optional = {"name", "content_type"},

  -- Serialize data to string
  -- @param data table - Data to serialize
  -- @return string - Serialized string representation
  serialize = "function(self, data) -> string",

  -- Deserialize string to data
  -- @param str string - String to deserialize
  -- @return table - Deserialized data
  deserialize = "function(self, str) -> table",
}

return ISerializer
