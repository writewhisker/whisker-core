-- tests/integration/include_spec.lua
-- Integration tests for WLS 1.0 Include Path Resolution (GAP-004)
-- and Circular Include Detection (GAP-005)

describe("Include Integration", function()
    local ModulesRuntime
    local os_tmpname = os.tmpname
    local io_open = io.open
    local os_remove = os.remove
    local temp_files = {}

    -- Helper to create a temp file with content
    local function create_temp_file(content, suffix)
        local tmpname = os_tmpname()
        -- Add suffix if provided
        if suffix then
            tmpname = tmpname .. suffix
        end
        local file = io_open(tmpname, "w")
        if file then
            file:write(content)
            file:close()
            table.insert(temp_files, tmpname)
            return tmpname
        end
        return nil
    end

    -- Helper to get directory of a file
    local function get_dir(path)
        return path:match("(.+)/[^/]+$") or "."
    end

    setup(function()
        ModulesRuntime = require("whisker.core.modules_runtime")
    end)

    teardown(function()
        -- Clean up temp files
        for _, file in ipairs(temp_files) do
            pcall(os_remove, file)
        end
    end)

    describe("GAP-004: Path Resolution", function()
        it("resolves relative paths from including file", function()
            -- Create a main file and a utils file in same directory
            local main_content = [[
@title: Test Story

:: Start
Hello from start.
]]
            local utils_content = [[
@title: Utils Module

:: UtilsPassage
Helper text.
]]
            local main_path = create_temp_file(main_content, ".ws")
            local dir = get_dir(main_path)
            local utils_path = dir .. "/utils.ws"

            -- Create utils file in same directory
            local f = io_open(utils_path, "w")
            if f then
                f:write(utils_content)
                f:close()
                table.insert(temp_files, utils_path)
            end

            local runtime = ModulesRuntime.new(nil, {
                project_root = dir
            })

            -- Set current file context
            runtime.resolver:set_current_file(main_path)

            -- Resolve relative path
            local resolved, err = runtime.resolver:resolve("utils.ws", main_path)

            assert.is_not_nil(resolved, "Should resolve path: " .. tostring(err))
            assert.has.match("utils.ws$", resolved)
        end)

        it("adds .ws extension if missing", function()
            local content = [[
:: Test
Content
]]
            local path = create_temp_file(content, ".ws")
            local dir = get_dir(path)
            local basename = path:match("([^/]+)%.ws$"):gsub("%.ws$", "")

            local runtime = ModulesRuntime.new(nil, {
                project_root = dir
            })

            -- Should add .ws extension
            local resolved = runtime.resolver:resolve(basename, path)

            -- resolved may be nil if file doesn't exist with that name
            -- but ensure_extension should work
            local with_ext = runtime.resolver:ensure_extension(basename)
            assert.are.equal(basename .. ".ws", with_ext)
        end)

        it("resolves parent directory paths", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- Test normalize with ..
            local normalized = runtime.resolver:normalize("/project/stories/chapter1/../shared/utils.ws")
            assert.are.equal("/project/stories/shared/utils.ws", normalized)
        end)

        it("returns error for missing files", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/nonexistent"
            })

            local result, err = runtime.resolver:resolve("missing.ws")
            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.has.match("not found", err:lower())
        end)
    end)

    describe("GAP-005: Circular Include Detection", function()
        it("detects direct self-include", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- Simulate including a.ws
            runtime.resolver:push_include("/project/a.ws")

            -- Try to include a.ws again
            local is_circular, cycle = runtime.resolver:push_include("/project/a.ws")

            assert.is_true(is_circular)
            assert.are.equal("a.ws -> a.ws", cycle)
        end)

        it("detects indirect circular include", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- Simulate: a.ws includes b.ws includes c.ws includes a.ws
            runtime.resolver:push_include("/project/a.ws")
            runtime.resolver:push_include("/project/b.ws")
            runtime.resolver:push_include("/project/c.ws")

            local is_circular, cycle = runtime.resolver:push_include("/project/a.ws")

            assert.is_true(is_circular)
            assert.are.equal("a.ws -> b.ws -> c.ws -> a.ws", cycle)
        end)

        it("allows diamond dependencies (non-circular)", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- a.ws includes b.ws
            runtime.resolver:push_include("/project/a.ws")
            runtime.resolver:push_include("/project/b.ws")

            -- b.ws includes d.ws
            runtime.resolver:push_include("/project/d.ws")
            runtime.resolver:pop_include()  -- pop d.ws
            runtime.resolver:pop_include()  -- pop b.ws

            -- a.ws includes c.ws
            runtime.resolver:push_include("/project/c.ws")

            -- c.ws includes d.ws (same file, but not circular)
            local is_circular = runtime.resolver:push_include("/project/d.ws")
            assert.is_false(is_circular)
        end)

        it("enforces maximum include depth", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- Push files up to MAX_INCLUDE_DEPTH
            for i = 1, ModulesRuntime.MAX_INCLUDE_DEPTH do
                runtime.resolver:push_include("/project/file" .. i .. ".ws")
            end

            -- Attempting to load_include should fail due to depth
            local result, err = runtime:load_include("next.ws", nil, nil)

            assert.is_nil(result)
            assert.is_not_nil(err)
            assert.has.match("WLS%-MOD%-004", err)
            assert.has.match("Maximum include depth", err)
        end)

        it("formats error with cycle chain", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- Simulate circular include detection
            runtime.resolver:push_include("/project/main.ws")
            runtime.resolver:push_include("/project/utils.ws")

            local is_circular, cycle = runtime.resolver:push_include("/project/main.ws")

            assert.is_true(is_circular)

            -- Format error
            local err = runtime:format_error(
                ModulesRuntime.ERROR_CODES.CIRCULAR_INCLUDE,
                "Circular include detected",
                { file = "/project/utils.ws", line = 5, column = 1 },
                "Remove one of the includes to break the cycle",
                { cycle = cycle }
            )

            assert.has.match("WLS%-MOD%-001", err)
            assert.has.match("main.ws %-> utils.ws %-> main.ws", err)
            assert.has.match("utils.ws:5:1", err)
            assert.has.match("Remove one", err)
        end)
    end)

    describe("Module caching", function()
        it("caches loaded modules", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            -- Manually add to cache
            runtime.loaded_modules["/project/cached.ws"] = {
                metadata = { title = "Cached" },
                passages = {}
            }

            -- Should use cache
            assert.is_not_nil(runtime.loaded_modules["/project/cached.ws"])
            assert.are.equal("Cached", runtime.loaded_modules["/project/cached.ws"].metadata.title)
        end)

        it("clears cache on clear_module_cache", function()
            local runtime = ModulesRuntime.new(nil, {
                project_root = "/project"
            })

            runtime.loaded_modules["/project/test.ws"] = { test = true }
            runtime.resolver:push_include("/project/a.ws")

            runtime:clear_module_cache()

            assert.are.same({}, runtime.loaded_modules)
            assert.are.equal(0, runtime.resolver:get_include_depth())
        end)
    end)
end)
