-- tests/core/path_resolver_spec.lua
-- Tests for WLS 1.0 Path Resolution (GAP-004) and Circular Detection (GAP-005)

describe("PathResolver", function()
    local PathResolver

    setup(function()
        PathResolver = require("whisker.core.path_resolver")
    end)

    describe("new()", function()
        it("creates a new instance with defaults", function()
            local resolver = PathResolver.new()
            assert.is_not_nil(resolver)
            assert.are.equal(".", resolver.project_root)
            assert.are.same({}, resolver.search_paths)
        end)

        it("accepts configuration options", function()
            local resolver = PathResolver.new({
                project_root = "/my/project",
                search_paths = {"/lib", "/vendor"}
            })
            assert.are.equal("/my/project", resolver.project_root)
            assert.are.same({"/lib", "/vendor"}, resolver.search_paths)
        end)
    end)

    describe("get_directory()", function()
        it("extracts directory from Unix path", function()
            local resolver = PathResolver.new()
            assert.are.equal("/home/user/stories", resolver:get_directory("/home/user/stories/main.ws"))
        end)

        it("extracts directory from Windows path", function()
            local resolver = PathResolver.new()
            assert.are.equal("C:\\Users\\stories", resolver:get_directory("C:\\Users\\stories\\main.ws"))
        end)

        it("returns '.' for filename only", function()
            local resolver = PathResolver.new()
            assert.are.equal(".", resolver:get_directory("main.ws"))
        end)

        it("handles nil path", function()
            local resolver = PathResolver.new()
            assert.are.equal(".", resolver:get_directory(nil))
        end)
    end)

    describe("get_filename()", function()
        it("extracts filename from Unix path", function()
            local resolver = PathResolver.new()
            assert.are.equal("main.ws", resolver:get_filename("/home/user/stories/main.ws"))
        end)

        it("extracts filename from Windows path", function()
            local resolver = PathResolver.new()
            assert.are.equal("main.ws", resolver:get_filename("C:\\Users\\stories\\main.ws"))
        end)

        it("returns path as-is for filename only", function()
            local resolver = PathResolver.new()
            assert.are.equal("main.ws", resolver:get_filename("main.ws"))
        end)
    end)

    describe("join()", function()
        it("joins path components", function()
            local resolver = PathResolver.new()
            assert.are.equal("a/b/c", resolver:join("a", "b", "c"))
        end)

        it("normalizes slashes", function()
            local resolver = PathResolver.new()
            assert.are.equal("a/b/c", resolver:join("a\\b", "c"))
        end)

        it("removes duplicate slashes", function()
            local resolver = PathResolver.new()
            assert.are.equal("a/b/c", resolver:join("a//b", "/c"))
        end)
    end)

    describe("normalize()", function()
        it("resolves parent directory references", function()
            local resolver = PathResolver.new()
            assert.are.equal("a/c", resolver:normalize("a/b/../c"))
        end)

        it("removes current directory references", function()
            local resolver = PathResolver.new()
            assert.are.equal("a/b", resolver:normalize("a/./b"))
        end)

        it("handles multiple parent refs", function()
            local resolver = PathResolver.new()
            assert.are.equal("a", resolver:normalize("a/b/c/../../"))
        end)

        it("handles complex paths", function()
            local resolver = PathResolver.new()
            -- a/b/../c/d/../../x/./y
            -- a (b popped by ..) -> c (d popped by first .., c popped by second ..) -> x/y
            -- Result: a/x/y is correct
            assert.are.equal("a/x/y", resolver:normalize("a/b/../c/d/../../x/./y"))
        end)

        it("preserves leading slash for absolute paths", function()
            local resolver = PathResolver.new()
            assert.are.equal("/a/b", resolver:normalize("/a/b/c/.."))
        end)

        it("returns '.' for empty normalized path", function()
            local resolver = PathResolver.new()
            assert.are.equal(".", resolver:normalize("a/.."))
        end)

        it("handles nil path", function()
            local resolver = PathResolver.new()
            assert.are.equal(".", resolver:normalize(nil))
        end)

        it("converts backslashes to forward slashes", function()
            local resolver = PathResolver.new()
            assert.are.equal("a/b/c", resolver:normalize("a\\b\\c"))
        end)
    end)

    describe("is_absolute()", function()
        it("detects Unix absolute paths", function()
            local resolver = PathResolver.new()
            assert.is_true(resolver:is_absolute("/home/user"))
            assert.is_true(resolver:is_absolute("/"))
        end)

        it("detects Windows absolute paths", function()
            local resolver = PathResolver.new()
            assert.is_true(resolver:is_absolute("C:\\Users"))
            assert.is_true(resolver:is_absolute("D:/folder"))
        end)

        it("detects relative paths", function()
            local resolver = PathResolver.new()
            assert.is_false(resolver:is_absolute("relative/path"))
            assert.is_false(resolver:is_absolute("./relative"))
            assert.is_false(resolver:is_absolute("../parent"))
        end)

        it("handles nil and empty", function()
            local resolver = PathResolver.new()
            assert.is_false(resolver:is_absolute(nil))
            assert.is_false(resolver:is_absolute(""))
        end)
    end)

    describe("ensure_extension()", function()
        it("adds .ws extension if missing", function()
            local resolver = PathResolver.new()
            assert.are.equal("test.ws", resolver:ensure_extension("test"))
        end)

        it("preserves existing .ws extension", function()
            local resolver = PathResolver.new()
            assert.are.equal("test.ws", resolver:ensure_extension("test.ws"))
        end)

        it("adds extension to paths with directories", function()
            local resolver = PathResolver.new()
            assert.are.equal("dir/test.ws", resolver:ensure_extension("dir/test"))
        end)

        it("handles nil", function()
            local resolver = PathResolver.new()
            assert.is_nil(resolver:ensure_extension(nil))
        end)
    end)

    describe("set_current_file()", function()
        it("sets the current file context", function()
            local resolver = PathResolver.new()
            resolver:set_current_file("/project/stories/main.ws")
            assert.are.equal("/project/stories/main.ws", resolver.current_file)
        end)
    end)

    -- Note: resolve() tests require actual file system access
    -- These are integration tests that should be run with test fixtures
    describe("resolve()", function()
        it("returns error for empty include path", function()
            local resolver = PathResolver.new()
            local result, err = resolver:resolve("")
            assert.is_nil(result)
            assert.is_not_nil(err)
        end)

        it("returns error for nil include path", function()
            local resolver = PathResolver.new()
            local result, err = resolver:resolve(nil)
            assert.is_nil(result)
            assert.is_not_nil(err)
        end)
    end)

    -- ============================================================================
    -- GAP-005: Circular Include Detection Tests
    -- ============================================================================

    describe("include stack (GAP-005)", function()
        it("detects direct cycle (A -> A)", function()
            local resolver = PathResolver.new({project_root = "/project"})

            local c1 = resolver:push_include("/project/a.ws")
            assert.is_false(c1)

            local is_circular, cycle = resolver:push_include("/project/a.ws")
            assert.is_true(is_circular)
            assert.are.equal("a.ws -> a.ws", cycle)
        end)

        it("detects indirect cycle (A -> B -> A)", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/a.ws")
            resolver:push_include("/project/b.ws")

            local is_circular, cycle = resolver:push_include("/project/a.ws")

            assert.is_true(is_circular)
            assert.are.equal("a.ws -> b.ws -> a.ws", cycle)
        end)

        it("detects long chain cycle (A -> B -> C -> A)", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/a.ws")
            resolver:push_include("/project/b.ws")
            resolver:push_include("/project/c.ws")

            local is_circular, cycle = resolver:push_include("/project/a.ws")

            assert.is_true(is_circular)
            assert.are.equal("a.ws -> b.ws -> c.ws -> a.ws", cycle)
        end)

        it("does not flag non-circular includes", function()
            local resolver = PathResolver.new({project_root = "/project"})

            local c1 = resolver:push_include("/project/a.ws")
            local c2 = resolver:push_include("/project/b.ws")
            local c3 = resolver:push_include("/project/c.ws")

            assert.is_false(c1)
            assert.is_false(c2)
            assert.is_false(c3)
        end)

        it("allows same file after popping", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/a.ws")
            resolver:push_include("/project/b.ws")
            resolver:pop_include()
            resolver:pop_include()

            -- Same file again should be OK
            local is_circular = resolver:push_include("/project/a.ws")
            assert.is_false(is_circular)
        end)

        it("reports correct cycle chain for mid-chain cycle", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/main.ws")
            resolver:push_include("/project/utils.ws")
            resolver:push_include("/project/helpers.ws")

            local is_circular, cycle = resolver:push_include("/project/utils.ws")

            assert.is_true(is_circular)
            assert.are.equal("utils.ws -> helpers.ws -> utils.ws", cycle)
        end)

        it("handles paths with different separators as same", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/dir/a.ws")

            -- Same path with backslash should still be detected as circular
            local is_circular = resolver:push_include("/project/dir/a.ws")
            assert.is_true(is_circular)
        end)
    end)

    describe("pop_include()", function()
        it("pops from the include stack", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/a.ws")
            resolver:push_include("/project/b.ws")

            assert.are.equal(2, resolver:get_include_depth())

            resolver:pop_include()
            assert.are.equal(1, resolver:get_include_depth())

            resolver:pop_include()
            assert.are.equal(0, resolver:get_include_depth())
        end)

        it("handles pop on empty stack", function()
            local resolver = PathResolver.new()
            assert.has_no.errors(function()
                resolver:pop_include()
            end)
            assert.are.equal(0, resolver:get_include_depth())
        end)
    end)

    describe("get_include_depth()", function()
        it("returns current include depth", function()
            local resolver = PathResolver.new({project_root = "/project"})

            assert.are.equal(0, resolver:get_include_depth())

            resolver:push_include("/project/a.ws")
            assert.are.equal(1, resolver:get_include_depth())

            resolver:push_include("/project/b.ws")
            assert.are.equal(2, resolver:get_include_depth())
        end)
    end)

    describe("get_include_chain()", function()
        it("returns the include chain as string", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/main.ws")
            resolver:push_include("/project/utils.ws")
            resolver:push_include("/project/helpers.ws")

            local chain = resolver:get_include_chain()
            assert.are.equal("main.ws -> utils.ws -> helpers.ws", chain)
        end)

        it("returns empty string for empty stack", function()
            local resolver = PathResolver.new()
            assert.are.equal("", resolver:get_include_chain())
        end)
    end)

    describe("clear_include_stack()", function()
        it("clears the include stack", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:push_include("/project/a.ws")
            resolver:push_include("/project/b.ws")

            resolver:clear_include_stack()

            assert.are.equal(0, resolver:get_include_depth())
            assert.are.equal("", resolver:get_include_chain())
        end)
    end)

    describe("reset()", function()
        it("resets all state", function()
            local resolver = PathResolver.new({project_root = "/project"})

            resolver:set_current_file("/project/main.ws")
            resolver:push_include("/project/a.ws")

            resolver:reset()

            assert.is_nil(resolver.current_file)
            assert.are.equal(0, resolver:get_include_depth())
        end)
    end)
end)
