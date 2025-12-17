-- spec/formats/ink/tunnel_converter_spec.lua
-- Tests for tunnel and thread conversion

describe("TunnelTransformer", function()
  local TunnelTransformer

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.transformers%.tunnel") then
        package.loaded[k] = nil
      end
    end

    TunnelTransformer = require("whisker.formats.ink.transformers.tunnel")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(TunnelTransformer._whisker)
      assert.are.equal("TunnelTransformer", TunnelTransformer._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.transformers.tunnel", TunnelTransformer._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = TunnelTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("_is_tunnel", function()
    local transformer

    before_each(function()
      transformer = TunnelTransformer.new()
    end)

    it("should return true for tunnel: true", function()
      local divert = { tunnel = true, ["->"] = "target" }
      assert.is_true(transformer:_is_tunnel(divert))
    end)

    it("should return true for ->t-> syntax", function()
      local divert = { ["->t->"] = "target" }
      assert.is_true(transformer:_is_tunnel(divert))
    end)

    it("should return false for regular divert", function()
      local divert = { ["->"] = "target" }
      assert.is_false(transformer:_is_tunnel(divert))
    end)

    it("should return false for nil", function()
      assert.is_false(transformer:_is_tunnel(nil))
    end)
  end)

  describe("_extract_target", function()
    local transformer

    before_each(function()
      transformer = TunnelTransformer.new()
    end)

    it("should extract from -> field", function()
      local divert = { ["->"] = "my_target" }
      assert.are.equal("my_target", transformer:_extract_target(divert))
    end)

    it("should extract from ->t-> field", function()
      local divert = { ["->t->"] = "tunnel_target" }
      assert.are.equal("tunnel_target", transformer:_extract_target(divert))
    end)

    it("should extract from target field", function()
      local divert = { target = "other_target" }
      assert.are.equal("other_target", transformer:_extract_target(divert))
    end)

    it("should return nil for empty table", function()
      assert.is_nil(transformer:_extract_target({}))
    end)
  end)

  describe("transform", function()
    local transformer

    before_each(function()
      transformer = TunnelTransformer.new()
    end)

    it("should transform regular divert", function()
      local divert = { ["->"] = "my_knot" }
      local result = transformer:transform(divert, "source", {})

      assert.are.equal("my_knot", result.target)
      assert.is_false(result.is_tunnel)
      assert.is_nil(result.return_point)
      assert.are.equal("divert", result.metadata.type)
    end)

    it("should transform tunnel divert", function()
      local divert = { ["->t->"] = "tunnel_knot" }
      local result = transformer:transform(divert, "source", {})

      assert.are.equal("tunnel_knot", result.target)
      assert.is_true(result.is_tunnel)
      assert.are.equal("source", result.return_point)
      assert.are.equal("tunnel", result.metadata.type)
    end)
  end)

  describe("find_tunnels", function()
    local transformer

    before_each(function()
      transformer = TunnelTransformer.new()
    end)

    it("should find tunnels in container", function()
      local container = {
        "^Some text",
        { ["->t->"] = "tunnel1" },
        "^More text",
        { ["->t->"] = "tunnel2" }
      }

      local tunnels = transformer:find_tunnels(container)

      assert.are.equal(2, #tunnels)
    end)

    it("should find nested tunnels", function()
      local container = {
        {
          { ["->t->"] = "nested_tunnel" }
        }
      }

      local tunnels = transformer:find_tunnels(container)

      assert.are.equal(1, #tunnels)
    end)

    it("should return empty for no tunnels", function()
      local container = { "^Just text", { ["->"] = "regular" } }

      local tunnels = transformer:find_tunnels(container)

      assert.are.same({}, tunnels)
    end)
  end)

  describe("is_tunnel_target", function()
    local transformer

    before_each(function()
      transformer = TunnelTransformer.new()
    end)

    it("should return true when has return marker", function()
      local passage = {
        "^Tunnel content",
        { ["->->"] = true }
      }

      assert.is_true(transformer:is_tunnel_target(passage))
    end)

    it("should return false without return marker", function()
      local passage = { "^Regular content" }

      assert.is_false(transformer:is_tunnel_target(passage))
    end)
  end)

  describe("create_passage_metadata", function()
    local transformer

    before_each(function()
      transformer = TunnelTransformer.new()
    end)

    it("should create tunnel target metadata", function()
      local meta = transformer:create_passage_metadata(true, { "caller1", "caller2" })

      assert.is_true(meta.is_tunnel_target)
      assert.are.same({ "caller1", "caller2" }, meta.return_points)
      assert.are.equal("tunnel", meta.call_type)
    end)

    it("should create normal passage metadata", function()
      local meta = transformer:create_passage_metadata(false, {})

      assert.is_false(meta.is_tunnel_target)
      assert.are.equal("normal", meta.call_type)
    end)
  end)
end)

describe("ThreadTransformer", function()
  local ThreadTransformer

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink%.transformers%.thread") then
        package.loaded[k] = nil
      end
    end

    ThreadTransformer = require("whisker.formats.ink.transformers.thread")
  end)

  describe("module metadata", function()
    it("should have _whisker metadata", function()
      assert.is_table(ThreadTransformer._whisker)
      assert.are.equal("ThreadTransformer", ThreadTransformer._whisker.name)
    end)

    it("should have capability", function()
      assert.are.equal("formats.ink.transformers.thread", ThreadTransformer._whisker.capability)
    end)
  end)

  describe("new", function()
    it("should create a new instance", function()
      local transformer = ThreadTransformer.new()
      assert.is_table(transformer)
    end)
  end)

  describe("is_thread_start", function()
    local transformer

    before_each(function()
      transformer = ThreadTransformer.new()
    end)

    it("should return true for <- syntax", function()
      local item = { ["<-"] = "thread_target" }
      assert.is_true(transformer:is_thread_start(item))
    end)

    it("should return true for thread field", function()
      local item = { thread = "thread_target" }
      assert.is_true(transformer:is_thread_start(item))
    end)

    it("should return false for non-thread", function()
      local item = { ["->"] = "regular_target" }
      assert.is_false(transformer:is_thread_start(item))
    end)
  end)

  describe("transform", function()
    local transformer

    before_each(function()
      transformer = ThreadTransformer.new()
    end)

    it("should transform thread", function()
      local thread_data = { ["<-"] = "thread_knot" }
      local result = transformer:transform(thread_data, "parent", {})

      assert.are.equal("thread_knot", result.target)
      assert.is_true(result.is_thread)
      assert.are.equal("parent", result.parent)
      assert.are.equal("thread", result.metadata.type)
    end)
  end)

  describe("find_threads", function()
    local transformer

    before_each(function()
      transformer = ThreadTransformer.new()
    end)

    it("should find threads in container", function()
      local container = {
        "^Text",
        { ["<-"] = "thread1" },
        { ["<-"] = "thread2" }
      }

      local threads = transformer:find_threads(container)

      assert.are.equal(2, #threads)
    end)

    it("should return empty for no threads", function()
      local container = { "^Just text" }

      local threads = transformer:find_threads(container)

      assert.are.same({}, threads)
    end)
  end)

  describe("create_passage_metadata", function()
    local transformer

    before_each(function()
      transformer = ThreadTransformer.new()
    end)

    it("should create threaded metadata", function()
      local meta = transformer:create_passage_metadata(true, { "t1", "t2" })

      assert.is_true(meta.is_threaded)
      assert.are.same({ "t1", "t2" }, meta.thread_targets)
      assert.are.equal("parallel", meta.execution_mode)
    end)

    it("should create sequential metadata", function()
      local meta = transformer:create_passage_metadata(false, {})

      assert.is_false(meta.is_threaded)
      assert.are.equal("sequential", meta.execution_mode)
    end)
  end)
end)

describe("Converter tunnel/thread integration", function()
  local transformers

  before_each(function()
    -- Clear cached modules
    for k in pairs(package.loaded) do
      if k:match("^whisker%.formats%.ink") then
        package.loaded[k] = nil
      end
    end

    transformers = require("whisker.formats.ink.transformers")
  end)

  describe("transformers registry", function()
    it("should include tunnel transformer", function()
      local list = transformers.list()
      local has_tunnel = false
      for _, name in ipairs(list) do
        if name == "tunnel" then
          has_tunnel = true
          break
        end
      end
      assert.is_true(has_tunnel)
    end)

    it("should include thread transformer", function()
      local list = transformers.list()
      local has_thread = false
      for _, name in ipairs(list) do
        if name == "thread" then
          has_thread = true
          break
        end
      end
      assert.is_true(has_thread)
    end)

    it("should create tunnel transformer", function()
      local tunnel = transformers.create("tunnel")
      assert.is_table(tunnel)
      assert.is_function(tunnel.transform)
    end)

    it("should create thread transformer", function()
      local thread = transformers.create("thread")
      assert.is_table(thread)
      assert.is_function(thread.transform)
    end)
  end)
end)
