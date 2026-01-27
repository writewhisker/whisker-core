-- lib/whisker/validation/presentation_errors.lua
-- WLS 1.0 Presentation Error Handling
-- Implements GAP-051: Presentation Errors

local PresentationErrors = {}
PresentationErrors.__index = PresentationErrors

--- Error codes for presentation-level errors
--- These errors are shown to end users in a friendly way
PresentationErrors.CODES = {
    -- Story errors
    STORY_NOT_FOUND = "WHISKER-001",
    PASSAGE_NOT_FOUND = "WHISKER-002",
    CHOICE_INVALID = "WHISKER-003",

    -- Media errors
    IMAGE_NOT_FOUND = "WHISKER-010",
    AUDIO_NOT_FOUND = "WHISKER-011",
    VIDEO_NOT_FOUND = "WHISKER-012",
    MEDIA_LOAD_FAILED = "WHISKER-013",

    -- Save/Load errors
    SAVE_FAILED = "WHISKER-020",
    LOAD_FAILED = "WHISKER-021",
    SAVE_CORRUPT = "WHISKER-022",
    SAVE_VERSION_MISMATCH = "WHISKER-023",

    -- Network errors (for online features)
    NETWORK_ERROR = "WHISKER-030",
    SYNC_FAILED = "WHISKER-031",

    -- General errors
    UNKNOWN_ERROR = "WHISKER-099"
}

--- Default user-friendly messages for each error code
PresentationErrors.DEFAULT_MESSAGES = {
    [PresentationErrors.CODES.STORY_NOT_FOUND] = "We couldn't find the story. Please try refreshing the page.",
    [PresentationErrors.CODES.PASSAGE_NOT_FOUND] = "This part of the story couldn't be loaded. Please try again.",
    [PresentationErrors.CODES.CHOICE_INVALID] = "That choice isn't available right now.",

    [PresentationErrors.CODES.IMAGE_NOT_FOUND] = "An image couldn't be loaded.",
    [PresentationErrors.CODES.AUDIO_NOT_FOUND] = "Audio content couldn't be loaded.",
    [PresentationErrors.CODES.VIDEO_NOT_FOUND] = "Video content couldn't be loaded.",
    [PresentationErrors.CODES.MEDIA_LOAD_FAILED] = "Some media content couldn't be loaded.",

    [PresentationErrors.CODES.SAVE_FAILED] = "We couldn't save your progress. Please try again.",
    [PresentationErrors.CODES.LOAD_FAILED] = "We couldn't load your saved progress.",
    [PresentationErrors.CODES.SAVE_CORRUPT] = "Your save file appears to be damaged.",
    [PresentationErrors.CODES.SAVE_VERSION_MISMATCH] = "This save file is from a different version of the story.",

    [PresentationErrors.CODES.NETWORK_ERROR] = "There was a network problem. Please check your connection.",
    [PresentationErrors.CODES.SYNC_FAILED] = "Syncing failed. Your progress is saved locally.",

    [PresentationErrors.CODES.UNKNOWN_ERROR] = "Something went wrong. Please try again."
}

--- Create a new presentation errors manager
---@param config table|nil Configuration options
---@return PresentationErrors
function PresentationErrors.new(config)
    config = config or {}
    local self = setmetatable({}, PresentationErrors)

    self.config = {
        -- Custom message overrides
        messages = config.messages or {},
        -- Callback when error occurs
        on_error = config.on_error or nil,
        -- Whether to log technical details
        log_technical = config.log_technical or false,
        -- Maximum errors to keep in history
        max_history = config.max_history or 100
    }

    self.error_history = {}

    return self
end

--- Create a presentation error
---@param code string Error code
---@param technical_details string|nil Technical details (for debugging)
---@param context table|nil Additional context
---@return table Presentation error object
function PresentationErrors:create(code, technical_details, context)
    -- Get user-friendly message
    local message = self.config.messages[code]
                    or PresentationErrors.DEFAULT_MESSAGES[code]
                    or PresentationErrors.DEFAULT_MESSAGES[PresentationErrors.CODES.UNKNOWN_ERROR]

    local error_obj = {
        code = code,
        message = message,
        timestamp = os.time(),
        context = context or {}
    }

    -- Store technical details separately (not shown to user)
    if technical_details then
        error_obj._technical = technical_details
    end

    return error_obj
end

--- Report an error (creates and stores it)
---@param code string Error code
---@param technical_details string|nil Technical details
---@param context table|nil Additional context
---@return table The error object
function PresentationErrors:report(code, technical_details, context)
    local error_obj = self:create(code, technical_details, context)

    -- Add to history
    table.insert(self.error_history, error_obj)

    -- Trim history if needed
    while #self.error_history > self.config.max_history do
        table.remove(self.error_history, 1)
    end

    -- Log technical details if enabled
    if self.config.log_technical and technical_details then
        io.stderr:write(string.format(
            "[%s] %s: %s\n",
            os.date("%Y-%m-%d %H:%M:%S"),
            code,
            technical_details
        ))
    end

    -- Call error callback if set
    if self.config.on_error then
        self.config.on_error(error_obj)
    end

    return error_obj
end

--- Get user-friendly message for an error
---@param error_obj table Error object or error code
---@return string User-friendly message
function PresentationErrors:get_message(error_obj)
    if type(error_obj) == "string" then
        return self.config.messages[error_obj]
               or PresentationErrors.DEFAULT_MESSAGES[error_obj]
               or PresentationErrors.DEFAULT_MESSAGES[PresentationErrors.CODES.UNKNOWN_ERROR]
    end
    return error_obj.message
end

--- Check if an error is recoverable
---@param code string Error code
---@return boolean
function PresentationErrors:is_recoverable(code)
    local non_recoverable = {
        [PresentationErrors.CODES.SAVE_CORRUPT] = true,
        [PresentationErrors.CODES.SAVE_VERSION_MISMATCH] = true
    }

    return not non_recoverable[code]
end

--- Get recovery suggestions for an error
---@param code string Error code
---@return table List of suggested actions
function PresentationErrors:get_recovery_suggestions(code)
    local suggestions = {
        [PresentationErrors.CODES.STORY_NOT_FOUND] = {
            "Refresh the page",
            "Check your internet connection",
            "Clear your browser cache"
        },
        [PresentationErrors.CODES.PASSAGE_NOT_FOUND] = {
            "Click 'Restart' to begin again",
            "Check if there are any story updates"
        },
        [PresentationErrors.CODES.SAVE_FAILED] = {
            "Check if you have storage space available",
            "Try enabling cookies/local storage",
            "Export your progress manually"
        },
        [PresentationErrors.CODES.LOAD_FAILED] = {
            "Try again",
            "Start a new game",
            "Contact support if the problem persists"
        },
        [PresentationErrors.CODES.NETWORK_ERROR] = {
            "Check your internet connection",
            "Try again in a few moments",
            "Your progress is saved locally"
        }
    }

    return suggestions[code] or {
        "Try again",
        "Refresh the page"
    }
end

--- Clear error history
function PresentationErrors:clear_history()
    self.error_history = {}
end

--- Get recent errors
---@param count number|nil Number of errors to return (default: all)
---@return table List of recent errors
function PresentationErrors:get_recent(count)
    if not count then
        return self.error_history
    end

    local result = {}
    local start = math.max(1, #self.error_history - count + 1)
    for i = start, #self.error_history do
        table.insert(result, self.error_history[i])
    end
    return result
end

--- Format error for display
---@param error_obj table The error object
---@param options table|nil Format options (show_code, show_suggestions)
---@return table Formatted error for UI rendering
function PresentationErrors:format_for_display(error_obj, options)
    options = options or {}

    local display = {
        message = error_obj.message,
        recoverable = self:is_recoverable(error_obj.code),
        suggestions = options.show_suggestions ~= false
                      and self:get_recovery_suggestions(error_obj.code)
                      or nil
    }

    if options.show_code then
        display.code = error_obj.code
    end

    return display
end

--- Convert internal error to presentation error
--- This maps technical/developer errors to user-friendly presentation errors
---@param internal_error table|string Internal error object or message
---@param error_type string|nil Type hint ("story", "media", "save", etc.)
---@return table Presentation error
function PresentationErrors:from_internal(internal_error, error_type)
    local technical = type(internal_error) == "string"
                      and internal_error
                      or (internal_error.message or tostring(internal_error))

    -- Map based on error type hint
    local code_map = {
        story = PresentationErrors.CODES.STORY_NOT_FOUND,
        passage = PresentationErrors.CODES.PASSAGE_NOT_FOUND,
        choice = PresentationErrors.CODES.CHOICE_INVALID,
        image = PresentationErrors.CODES.IMAGE_NOT_FOUND,
        audio = PresentationErrors.CODES.AUDIO_NOT_FOUND,
        video = PresentationErrors.CODES.VIDEO_NOT_FOUND,
        media = PresentationErrors.CODES.MEDIA_LOAD_FAILED,
        save = PresentationErrors.CODES.SAVE_FAILED,
        load = PresentationErrors.CODES.LOAD_FAILED,
        network = PresentationErrors.CODES.NETWORK_ERROR
    }

    local code = code_map[error_type] or PresentationErrors.CODES.UNKNOWN_ERROR

    return self:report(code, technical, {
        original_type = error_type
    })
end

--- Set custom message for an error code
---@param code string Error code
---@param message string Custom message
function PresentationErrors:set_message(code, message)
    self.config.messages[code] = message
end

--- Set error callback
---@param callback function Callback function (error_obj) -> void
function PresentationErrors:set_error_callback(callback)
    self.config.on_error = callback
end

return PresentationErrors
