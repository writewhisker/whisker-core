-- Unit Tests for SHA-256
local SHA256 = require("whisker.security.sha256")

describe("SHA-256", function()
  describe("hash", function()
    it("should return 32 bytes", function()
      local hash = SHA256.hash("test")
      assert.equals(32, #hash)
    end)

    it("should be deterministic", function()
      local hash1 = SHA256.hash("hello")
      local hash2 = SHA256.hash("hello")
      assert.equals(hash1, hash2)
    end)

    it("should produce different hashes for different inputs", function()
      local hash1 = SHA256.hash("hello")
      local hash2 = SHA256.hash("world")
      assert.is_not.equals(hash1, hash2)
    end)

    it("should handle empty string", function()
      local hash = SHA256.hash("")
      assert.equals(32, #hash)
    end)
  end)

  describe("hex", function()
    it("should return 64 character hex string", function()
      local hex = SHA256.hex("test")
      assert.equals(64, #hex)
      assert.matches("^[0-9a-f]+$", hex)
    end)

    -- Test vectors from NIST
    it("should hash empty string correctly", function()
      local hex = SHA256.hex("")
      assert.equals("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", hex)
    end)

    it("should hash 'abc' correctly", function()
      local hex = SHA256.hex("abc")
      assert.equals("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", hex)
    end)

    it("should hash 'hello' correctly", function()
      local hex = SHA256.hex("hello")
      assert.equals("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824", hex)
    end)

    it("should hash 'The quick brown fox jumps over the lazy dog' correctly", function()
      local hex = SHA256.hex("The quick brown fox jumps over the lazy dog")
      assert.equals("d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592", hex)
    end)

    it("should hash longer text correctly", function()
      -- 56 bytes - exactly fits one block boundary
      local hex = SHA256.hex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
      assert.equals("248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", hex)
    end)
  end)

  describe("base64", function()
    it("should return base64 encoded hash", function()
      local b64 = SHA256.base64("test")
      assert.matches("^[A-Za-z0-9+/]+=*$", b64)
    end)

    it("should be 44 characters (32 bytes in base64 with padding)", function()
      local b64 = SHA256.base64("test")
      assert.equals(44, #b64)
    end)

    it("should hash 'hello' to expected base64", function()
      local b64 = SHA256.base64("hello")
      -- SHA256("hello") in base64 is LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=
      assert.equals("LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=", b64)
    end)

    it("should hash empty string to expected base64", function()
      local b64 = SHA256.base64("")
      -- SHA256("") in base64 is 47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=
      assert.equals("47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=", b64)
    end)
  end)

  describe("edge cases", function()
    it("should handle single character", function()
      local hex = SHA256.hex("a")
      assert.equals("ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb", hex)
    end)

    it("should handle binary data", function()
      local binary = string.char(0, 1, 2, 3, 4, 5)
      local hex = SHA256.hex(binary)
      assert.equals(64, #hex)
    end)

    it("should handle unicode", function()
      local hex = SHA256.hex("hello\xC3\xA9")  -- "helloé" in UTF-8
      assert.equals(64, #hex)
    end)

    it("should handle newlines", function()
      local hex1 = SHA256.hex("hello\n")
      local hex2 = SHA256.hex("hello")
      assert.is_not.equals(hex1, hex2)
    end)
  end)
end)
