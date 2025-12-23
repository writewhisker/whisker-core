--- ISerializer Interface
-- Interface for data serialization services
-- @module whisker.interfaces.serializer
-- @author Whisker Core Team
-- @license MIT

local ISerializer = {}

--- Serialize data to a string format
-- @param data any The data to serialize
-- @param options table|nil Serialization options
-- @return string The serialized data
-- @return string|nil Error message if serialization failed
function ISerializer:serialize(data, options)
  error("ISerializer:serialize must be implemented")
end

--- Deserialize a string back to data
-- @param str string The string to deserialize
-- @param options table|nil Deserialization options
-- @return any The deserialized data
-- @return string|nil Error message if deserialization failed
function ISerializer:deserialize(str, options)
  error("ISerializer:deserialize must be implemented")
end

--- Get the serializer name
-- @return string The serializer name (e.g., "json", "lua", "msgpack")
function ISerializer:get_name()
  error("ISerializer:get_name must be implemented")
end

--- Check if this serializer can handle the given data type
-- @param data any The data to check
-- @return boolean True if this serializer can handle the data
function ISerializer:can_serialize(data)
  error("ISerializer:can_serialize must be implemented")
end

return ISerializer
