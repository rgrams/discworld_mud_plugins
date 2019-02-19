
local max = math.max
local min = math.min

local function clamp(a, minVal, maxVal)
	return min(maxVal, max(minVal, a))
end

-- Convert three 0-255 RGB values to an Integer.
-- 	Inputs are clamped to 0-255.
-- 	Can use a single input to get a grey color of that value.
-- 	Will return black if called with no inputs.
local function RGBToInt(_, r, g, b)
	r = r and clamp(r, 0, 255) or 0
	g = g and clamp(g, 0, 255) or r
	b = b and clamp(b, 0, 255) or r
	return r + g * 256 + b * 65536
end

local mt = { __call = RGBToInt }

return setmetatable({}, mt)
