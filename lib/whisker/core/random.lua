-- lib/whisker/core/random.lua
-- Seeded random number generator for reproducibility
-- Implements GAP-017: Random Seed

local Random = {}
Random.__index = Random

--- Create a new seeded random number generator
---@param seed number|string|nil Initial seed
---@return Random
function Random.new(seed)
    local self = setmetatable({}, Random)
    self:set_seed(seed or os.time())
    return self
end

--- Set the random seed
---@param seed number|string
function Random:set_seed(seed)
    if type(seed) == "string" then
        -- Hash string to number
        seed = self:hash_string(seed)
    end

    -- Ensure seed is a positive integer
    seed = math.floor(math.abs(seed))
    if seed == 0 then
        seed = 1
    end

    self.seed = seed
    self.state = seed

    -- Also seed Lua's math.random for compatibility
    math.randomseed(seed)
end

--- Hash a string to a number (djb2 hash algorithm)
---@param str string
---@return number
function Random:hash_string(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end
    -- Ensure non-zero result
    if hash == 0 then
        hash = 1
    end
    return hash
end

--- Generate next random number using linear congruential generator
--- Uses MINSTD parameters for cross-platform consistency
---@return number between 0 and 1
function Random:next()
    -- LCG parameters (MINSTD)
    local a = 48271
    local m = 2147483647  -- 2^31 - 1

    self.state = (self.state * a) % m
    return self.state / m
end

--- Generate random integer in range [min, max]
---@param min number
---@param max number
---@return number
function Random:int(min, max)
    min = min or 1
    max = max or 100

    if min > max then
        min, max = max, min
    end

    return math.floor(self:next() * (max - min + 1)) + min
end

--- Generate random float in range [min, max)
---@param min number
---@param max number
---@return number
function Random:float(min, max)
    min = min or 0
    max = max or 1

    return min + self:next() * (max - min)
end

--- Pick random element from array
---@param array table
---@return any
function Random:pick(array)
    if not array or #array == 0 then
        return nil
    end
    local index = self:int(1, #array)
    return array[index]
end

--- Shuffle array in place using Fisher-Yates algorithm
---@param array table
---@return table same array, shuffled
function Random:shuffle(array)
    for i = #array, 2, -1 do
        local j = self:int(1, i)
        array[i], array[j] = array[j], array[i]
    end
    return array
end

--- Generate a random boolean with given probability of true
---@param probability number Probability of true (0-1), default 0.5
---@return boolean
function Random:bool(probability)
    probability = probability or 0.5
    return self:next() < probability
end

--- Roll dice (e.g., 2d6 = roll 2 six-sided dice)
---@param count number Number of dice
---@param sides number Number of sides per die
---@return number Total of all dice
function Random:dice(count, sides)
    count = count or 1
    sides = sides or 6
    local total = 0
    for i = 1, count do
        total = total + self:int(1, sides)
    end
    return total
end

--- Get current state for serialization
---@return table
function Random:get_state()
    return {
        seed = self.seed,
        state = self.state
    }
end

--- Restore state from serialization
---@param data table
function Random:set_state(data)
    if data then
        self.seed = data.seed
        self.state = data.state
    end
end

--- Clone this random generator with the same current state
---@return Random
function Random:clone()
    local new_rng = Random.new()
    new_rng.seed = self.seed
    new_rng.state = self.state
    return new_rng
end

--- Reset to initial seed
function Random:reset()
    self.state = self.seed
end

return Random
