--- SHA-256 Implementation
-- Pure Lua implementation of SHA-256 hash algorithm
-- Compatible with Lua 5.1, 5.2, 5.3, 5.4, 5.5, and LuaJIT
-- @module whisker.security.sha256
-- @author Whisker Core Team
-- @license MIT

local SHA256 = {}

-- ============================================================================
-- Bit operations compatibility layer
-- ============================================================================

local band, bor, bxor, bnot, rshift, lshift

-- Try Lua 5.3+ native operators first
if _VERSION >= "Lua 5.3" then
  -- Use load to avoid parse errors in older Lua
  band = load("return function(a, b) return a & b end")()
  bor = load("return function(a, b) return a | b end")()
  bxor = load("return function(a, b) return a ~ b end")()
  bnot = load("return function(a) return ~a end")()
  rshift = load("return function(a, n) return a >> n end")()
  lshift = load("return function(a, n) return a << n end")()
elseif bit32 then
  -- Lua 5.2 bit32 library
  band = bit32.band
  bor = bit32.bor
  bxor = bit32.bxor
  bnot = bit32.bnot
  rshift = bit32.rshift
  lshift = bit32.lshift
elseif bit then
  -- LuaJIT bit library
  band = bit.band
  bor = bit.bor
  bxor = bit.bxor
  bnot = bit.bnot
  rshift = bit.rshift
  lshift = bit.lshift
else
  -- Pure Lua fallback for Lua 5.1 without bit library
  local function normalize(n)
    return n % 0x100000000
  end

  band = function(a, b)
    local result = 0
    local bit_val = 1
    for _ = 1, 32 do
      if a % 2 == 1 and b % 2 == 1 then
        result = result + bit_val
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit_val = bit_val * 2
    end
    return result
  end

  bor = function(a, b)
    local result = 0
    local bit_val = 1
    for _ = 1, 32 do
      if a % 2 == 1 or b % 2 == 1 then
        result = result + bit_val
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit_val = bit_val * 2
    end
    return result
  end

  bxor = function(a, b)
    local result = 0
    local bit_val = 1
    for _ = 1, 32 do
      if (a % 2 == 1) ~= (b % 2 == 1) then
        result = result + bit_val
      end
      a = math.floor(a / 2)
      b = math.floor(b / 2)
      bit_val = bit_val * 2
    end
    return result
  end

  bnot = function(a)
    return normalize(0xFFFFFFFF - normalize(a))
  end

  rshift = function(a, n)
    return math.floor(normalize(a) / (2 ^ n))
  end

  lshift = function(a, n)
    return normalize(a * (2 ^ n))
  end
end

-- Mask to 32 bits
local function mask32(x)
  return band(x, 0xFFFFFFFF)
end

-- ============================================================================
-- SHA-256 Constants and Functions
-- ============================================================================

-- SHA-256 constants (first 32 bits of the fractional parts of the cube roots of the first 64 primes)
local K = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

-- Initial hash values (first 32 bits of the fractional parts of the square roots of the first 8 primes)
local H0 = {
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
}

--- Right rotate (circular right shift)
-- @param x number Value to rotate
-- @param n number Number of bits to rotate
-- @return number Rotated value
local function rotr(x, n)
  return bor(rshift(x, n), mask32(lshift(x, 32 - n)))
end

--- SHA-256 Ch function
local function ch(x, y, z)
  return bxor(band(x, y), band(bnot(x), z))
end

--- SHA-256 Maj function
local function maj(x, y, z)
  return bxor(bxor(band(x, y), band(x, z)), band(y, z))
end

--- SHA-256 Sigma0 function
local function sigma0(x)
  return bxor(bxor(rotr(x, 2), rotr(x, 13)), rotr(x, 22))
end

--- SHA-256 Sigma1 function
local function sigma1(x)
  return bxor(bxor(rotr(x, 6), rotr(x, 11)), rotr(x, 25))
end

--- SHA-256 sigma0 (lowercase) function for message schedule
local function lsigma0(x)
  return bxor(bxor(rotr(x, 7), rotr(x, 18)), rshift(x, 3))
end

--- SHA-256 sigma1 (lowercase) function for message schedule
local function lsigma1(x)
  return bxor(bxor(rotr(x, 17), rotr(x, 19)), rshift(x, 10))
end

--- Convert string to byte array
-- @param str string Input string
-- @return table Array of byte values
local function string_to_bytes(str)
  local bytes = {}
  for i = 1, #str do
    bytes[i] = string.byte(str, i)
  end
  return bytes
end

--- Pad message to multiple of 512 bits
-- @param msg table Byte array
-- @return table Padded byte array
local function pad_message(msg)
  local len = #msg
  local bit_len = len * 8

  -- Clone message
  local padded = {}
  for i, b in ipairs(msg) do
    padded[i] = b
  end

  -- Append bit '1' (0x80)
  padded[#padded + 1] = 0x80

  -- Append zeros until length ≡ 448 (mod 512)
  while (#padded % 64) ~= 56 do
    padded[#padded + 1] = 0
  end

  -- Append 64-bit length in big-endian
  -- Note: We only support messages up to 2^32 bits (536MB)
  for _ = 1, 4 do
    padded[#padded + 1] = 0
  end
  padded[#padded + 1] = band(rshift(bit_len, 24), 0xFF)
  padded[#padded + 1] = band(rshift(bit_len, 16), 0xFF)
  padded[#padded + 1] = band(rshift(bit_len, 8), 0xFF)
  padded[#padded + 1] = band(bit_len, 0xFF)

  return padded
end

--- Process a 512-bit block
-- @param H table Current hash state (8 words)
-- @param block table 64 bytes
local function process_block(H, block)
  -- Create message schedule W
  local W = {}

  -- Copy block into first 16 words
  for i = 0, 15 do
    W[i] = bor(bor(bor(
      lshift(block[i * 4 + 1], 24),
      lshift(block[i * 4 + 2], 16)),
      lshift(block[i * 4 + 3], 8)),
      block[i * 4 + 4])
  end

  -- Extend to 64 words
  for i = 16, 63 do
    W[i] = mask32(lsigma1(W[i - 2]) + W[i - 7] + lsigma0(W[i - 15]) + W[i - 16])
  end

  -- Initialize working variables
  local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]

  -- Main loop
  for i = 0, 63 do
    local T1 = mask32(h + sigma1(e) + ch(e, f, g) + K[i + 1] + W[i])
    local T2 = mask32(sigma0(a) + maj(a, b, c))

    h = g
    g = f
    f = e
    e = mask32(d + T1)
    d = c
    c = b
    b = a
    a = mask32(T1 + T2)
  end

  -- Add to hash state
  H[1] = mask32(H[1] + a)
  H[2] = mask32(H[2] + b)
  H[3] = mask32(H[3] + c)
  H[4] = mask32(H[4] + d)
  H[5] = mask32(H[5] + e)
  H[6] = mask32(H[6] + f)
  H[7] = mask32(H[7] + g)
  H[8] = mask32(H[8] + h)
end

--- Compute SHA-256 hash
-- @param message string Input message
-- @return string 32-byte hash as binary string
function SHA256.hash(message)
  -- Convert to bytes and pad
  local bytes = string_to_bytes(message)
  local padded = pad_message(bytes)

  -- Initialize hash state
  local H = {}
  for i, v in ipairs(H0) do
    H[i] = v
  end

  -- Process each 512-bit block
  for i = 1, #padded, 64 do
    local block = {}
    for j = 0, 63 do
      block[j + 1] = padded[i + j]
    end
    process_block(H, block)
  end

  -- Convert hash to binary string
  local result = {}
  for i = 1, 8 do
    result[#result + 1] = string.char(band(rshift(H[i], 24), 0xFF))
    result[#result + 1] = string.char(band(rshift(H[i], 16), 0xFF))
    result[#result + 1] = string.char(band(rshift(H[i], 8), 0xFF))
    result[#result + 1] = string.char(band(H[i], 0xFF))
  end

  return table.concat(result)
end

--- Compute SHA-256 hash and return as hex string
-- @param message string Input message
-- @return string 64-character hex string
function SHA256.hex(message)
  local hash = SHA256.hash(message)
  local hex = {}
  for i = 1, #hash do
    hex[i] = string.format("%02x", string.byte(hash, i))
  end
  return table.concat(hex)
end

--- Compute SHA-256 hash and return as base64 string
-- @param message string Input message
-- @return string Base64-encoded hash
function SHA256.base64(message)
  local hash = SHA256.hash(message)

  local b64_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local result = {}

  -- Convert bytes to base64
  for i = 1, #hash, 3 do
    local b1 = string.byte(hash, i)
    local b2 = string.byte(hash, i + 1) or 0
    local b3 = string.byte(hash, i + 2) or 0

    local n = b1 * 65536 + b2 * 256 + b3

    result[#result + 1] = b64_chars:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
    result[#result + 1] = b64_chars:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
    result[#result + 1] = b64_chars:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1)
    result[#result + 1] = b64_chars:sub(n % 64 + 1, n % 64 + 1)
  end

  -- SHA-256 hash is 32 bytes, which is evenly divisible by 3... no wait, 32 % 3 = 2
  -- So we need 1 padding character
  result[#result] = "="

  return table.concat(result)
end

return SHA256
