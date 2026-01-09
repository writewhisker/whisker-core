--- Pure Lua PNG Encoder
-- Minimal PNG encoder for generating simple icons
-- @module whisker.vendor.codecs.png_encoder
-- @author Whisker Core Team
-- @license MIT
--
-- Creates valid PNG files using uncompressed deflate blocks.
-- Suitable for generating simple colored icons with text.

local PNGEncoder = {}

-- PNG signature
local PNG_SIGNATURE = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)

--- CRC32 lookup table
local crc_table = {}
do
  for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
      if c % 2 == 1 then
        c = bit32 and bit32.bxor(0xEDB88320, math.floor(c / 2)) or
            (0xEDB88320 ~ math.floor(c / 2))
      else
        c = math.floor(c / 2)
      end
    end
    crc_table[i] = c
  end
end

--- Calculate CRC32 checksum
-- @param data string Data to checksum
-- @return number CRC32 value
local function crc32(data)
  local crc = 0xFFFFFFFF
  for i = 1, #data do
    local byte = data:byte(i)
    local index = (crc ~ byte) % 256
    crc = (crc_table[index] ~ math.floor(crc / 256)) % 0x100000000
  end
  return (crc ~ 0xFFFFFFFF) % 0x100000000
end

--- Calculate Adler-32 checksum for zlib
-- @param data string Data to checksum
-- @return number Adler-32 value
local function adler32(data)
  local a = 1
  local b = 0
  for i = 1, #data do
    a = (a + data:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return b * 65536 + a
end

--- Write 32-bit big-endian integer
-- @param n number Value to encode
-- @return string 4 bytes
local function write_uint32_be(n)
  return string.char(
    math.floor(n / 16777216) % 256,
    math.floor(n / 65536) % 256,
    math.floor(n / 256) % 256,
    n % 256
  )
end

--- Create PNG chunk
-- @param chunk_type string 4-character chunk type
-- @param data string Chunk data
-- @return string Complete chunk with length and CRC
local function make_chunk(chunk_type, data)
  local length = write_uint32_be(#data)
  local crc = write_uint32_be(crc32(chunk_type .. data))
  return length .. chunk_type .. data .. crc
end

--- Create IHDR (image header) chunk
-- @param width number Image width
-- @param height number Image height
-- @param bit_depth number Bits per channel (8)
-- @param color_type number Color type (2=RGB, 6=RGBA)
-- @return string IHDR chunk
local function make_ihdr(width, height, bit_depth, color_type)
  local data = write_uint32_be(width) ..
               write_uint32_be(height) ..
               string.char(bit_depth) ..      -- bit depth
               string.char(color_type) ..     -- color type
               string.char(0) ..              -- compression method (deflate)
               string.char(0) ..              -- filter method
               string.char(0)                 -- interlace method (none)
  return make_chunk("IHDR", data)
end

--- Create uncompressed deflate stream
-- @param data string Raw data to wrap
-- @return string Deflate stream with zlib wrapper
local function make_deflate_uncompressed(data)
  local result = {}

  -- Zlib header: CMF=0x78 (deflate, 32K window), FLG=0x01 (no dict, level 0)
  table.insert(result, string.char(0x78, 0x01))

  -- Split data into blocks of max 65535 bytes
  local pos = 1
  local remaining = #data

  while remaining > 0 do
    local block_size = math.min(remaining, 65535)
    local is_final = remaining <= 65535

    -- Block header: BFINAL (1 bit), BTYPE=00 (2 bits) = uncompressed
    local header = is_final and 0x01 or 0x00
    table.insert(result, string.char(header))

    -- LEN (2 bytes, little-endian)
    table.insert(result, string.char(block_size % 256, math.floor(block_size / 256)))

    -- NLEN (one's complement of LEN)
    local nlen = 65535 - block_size
    table.insert(result, string.char(nlen % 256, math.floor(nlen / 256)))

    -- Literal data
    table.insert(result, data:sub(pos, pos + block_size - 1))

    pos = pos + block_size
    remaining = remaining - block_size
  end

  -- Adler-32 checksum (big-endian)
  local checksum = adler32(data)
  table.insert(result, write_uint32_be(checksum))

  return table.concat(result)
end

--- Create IDAT (image data) chunk
-- @param pixels table 2D array of {r, g, b} or {r, g, b, a} values
-- @param width number Image width
-- @param height number Image height
-- @param has_alpha boolean Include alpha channel
-- @return string IDAT chunk
local function make_idat(pixels, width, height, has_alpha)
  local raw_data = {}

  for y = 1, height do
    -- Filter byte (0 = None)
    table.insert(raw_data, string.char(0))

    -- Pixel data
    local row = pixels[y] or {}
    for x = 1, width do
      local pixel = row[x] or {0, 0, 0, 255}
      table.insert(raw_data, string.char(
        pixel[1] or 0,
        pixel[2] or 0,
        pixel[3] or 0
      ))
      if has_alpha then
        table.insert(raw_data, string.char(pixel[4] or 255))
      end
    end
  end

  local raw_string = table.concat(raw_data)
  local compressed = make_deflate_uncompressed(raw_string)

  return make_chunk("IDAT", compressed)
end

--- Create IEND chunk
-- @return string IEND chunk
local function make_iend()
  return make_chunk("IEND", "")
end

--- Encode pixel data as PNG
-- @param pixels table 2D array of {r, g, b} or {r, g, b, a} values (0-255)
-- @param width number Image width
-- @param height number Image height
-- @param options table Options (has_alpha: boolean)
-- @return string PNG file data
function PNGEncoder.encode(pixels, width, height, options)
  options = options or {}
  local has_alpha = options.has_alpha or false
  local color_type = has_alpha and 6 or 2  -- 6=RGBA, 2=RGB

  local parts = {
    PNG_SIGNATURE,
    make_ihdr(width, height, 8, color_type),
    make_idat(pixels, width, height, has_alpha),
    make_iend()
  }

  return table.concat(parts)
end

--- Create a solid color image
-- @param width number Image width
-- @param height number Image height
-- @param color table {r, g, b} or {r, g, b, a} (0-255)
-- @return string PNG file data
function PNGEncoder.solid_color(width, height, color)
  local pixels = {}
  for y = 1, height do
    pixels[y] = {}
    for x = 1, width do
      pixels[y][x] = color
    end
  end
  return PNGEncoder.encode(pixels, width, height, { has_alpha = #color == 4 })
end

--- Draw a simple letter onto pixels
-- Renders a capital letter using a simple bitmap font
-- @param pixels table 2D pixel array to modify
-- @param letter string Single character to draw
-- @param size number Image size
-- @param color table {r, g, b} text color
local function draw_letter(pixels, letter, size, color)
  -- Simple 5x7 bitmap font for uppercase letters
  local font = {
    A = {"01110", "10001", "10001", "11111", "10001", "10001", "10001"},
    B = {"11110", "10001", "10001", "11110", "10001", "10001", "11110"},
    C = {"01110", "10001", "10000", "10000", "10000", "10001", "01110"},
    D = {"11110", "10001", "10001", "10001", "10001", "10001", "11110"},
    E = {"11111", "10000", "10000", "11110", "10000", "10000", "11111"},
    F = {"11111", "10000", "10000", "11110", "10000", "10000", "10000"},
    G = {"01110", "10001", "10000", "10111", "10001", "10001", "01110"},
    H = {"10001", "10001", "10001", "11111", "10001", "10001", "10001"},
    I = {"11111", "00100", "00100", "00100", "00100", "00100", "11111"},
    J = {"00111", "00010", "00010", "00010", "00010", "10010", "01100"},
    K = {"10001", "10010", "10100", "11000", "10100", "10010", "10001"},
    L = {"10000", "10000", "10000", "10000", "10000", "10000", "11111"},
    M = {"10001", "11011", "10101", "10101", "10001", "10001", "10001"},
    N = {"10001", "11001", "10101", "10011", "10001", "10001", "10001"},
    O = {"01110", "10001", "10001", "10001", "10001", "10001", "01110"},
    P = {"11110", "10001", "10001", "11110", "10000", "10000", "10000"},
    Q = {"01110", "10001", "10001", "10001", "10101", "10010", "01101"},
    R = {"11110", "10001", "10001", "11110", "10100", "10010", "10001"},
    S = {"01111", "10000", "10000", "01110", "00001", "00001", "11110"},
    T = {"11111", "00100", "00100", "00100", "00100", "00100", "00100"},
    U = {"10001", "10001", "10001", "10001", "10001", "10001", "01110"},
    V = {"10001", "10001", "10001", "10001", "10001", "01010", "00100"},
    W = {"10001", "10001", "10001", "10101", "10101", "10101", "01010"},
    X = {"10001", "10001", "01010", "00100", "01010", "10001", "10001"},
    Y = {"10001", "10001", "01010", "00100", "00100", "00100", "00100"},
    Z = {"11111", "00001", "00010", "00100", "01000", "10000", "11111"},
    ["0"] = {"01110", "10001", "10011", "10101", "11001", "10001", "01110"},
    ["1"] = {"00100", "01100", "00100", "00100", "00100", "00100", "01110"},
    ["2"] = {"01110", "10001", "00001", "00110", "01000", "10000", "11111"},
    ["3"] = {"11111", "00010", "00100", "00010", "00001", "10001", "01110"},
    ["4"] = {"00010", "00110", "01010", "10010", "11111", "00010", "00010"},
    ["5"] = {"11111", "10000", "11110", "00001", "00001", "10001", "01110"},
    ["6"] = {"00110", "01000", "10000", "11110", "10001", "10001", "01110"},
    ["7"] = {"11111", "00001", "00010", "00100", "01000", "01000", "01000"},
    ["8"] = {"01110", "10001", "10001", "01110", "10001", "10001", "01110"},
    ["9"] = {"01110", "10001", "10001", "01111", "00001", "00010", "01100"},
  }

  local glyph = font[letter:upper()]
  if not glyph then
    glyph = font["W"]  -- Default fallback
  end

  -- Scale to fill ~60% of icon
  local glyph_height = #glyph
  local glyph_width = #glyph[1]
  local scale = math.floor(size * 0.6 / glyph_height)

  -- Center the letter
  local total_width = glyph_width * scale
  local total_height = glyph_height * scale
  local start_x = math.floor((size - total_width) / 2)
  local start_y = math.floor((size - total_height) / 2)

  -- Draw scaled glyph
  for gy = 1, glyph_height do
    local row = glyph[gy]
    for gx = 1, glyph_width do
      if row:sub(gx, gx) == "1" then
        -- Fill scaled pixel block
        for sy = 0, scale - 1 do
          for sx = 0, scale - 1 do
            local px = start_x + (gx - 1) * scale + sx
            local py = start_y + (gy - 1) * scale + sy
            if px >= 1 and px <= size and py >= 1 and py <= size then
              pixels[py][px] = color
            end
          end
        end
      end
    end
  end
end

--- Create an icon with a letter on colored background
-- @param size number Icon size (e.g., 192, 512)
-- @param options table Options:
--   - bg_color: {r, g, b} background color (default: blue)
--   - text_color: {r, g, b} text color (default: white)
--   - text: string letter to display (default: "W")
-- @return string PNG file data
function PNGEncoder.create_icon(size, options)
  options = options or {}
  local bg_color = options.bg_color or {66, 133, 244}  -- Material blue
  local text_color = options.text_color or {255, 255, 255}  -- White
  local text = options.text or "W"

  -- Create background
  local pixels = {}
  for y = 1, size do
    pixels[y] = {}
    for x = 1, size do
      pixels[y][x] = {bg_color[1], bg_color[2], bg_color[3]}
    end
  end

  -- Draw the letter
  if #text > 0 then
    draw_letter(pixels, text:sub(1, 1), size, text_color)
  end

  return PNGEncoder.encode(pixels, size, size)
end

--- Parse hex color to RGB
-- @param hex string Hex color like "#3498db" or "3498db"
-- @return table {r, g, b} values 0-255
function PNGEncoder.hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  if #hex == 3 then
    hex = hex:sub(1,1):rep(2) .. hex:sub(2,2):rep(2) .. hex:sub(3,3):rep(2)
  end
  return {
    tonumber(hex:sub(1, 2), 16) or 66,
    tonumber(hex:sub(3, 4), 16) or 133,
    tonumber(hex:sub(5, 6), 16) or 244
  }
end

return PNGEncoder
