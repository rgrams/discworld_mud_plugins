
local M = {}

local ansi = require "ansi"

local function equal(a, b)  return a > b-0.02 and a < b+0.02  end

local colors = {}
local imageDataToCompare

function M.setImageDataToCompare(imageData)
	imageDataToCompare = imageData
end

function M.pixelMapFn(x, y, r, g, b, a)
	local colorExists = false
	for i=1,#colors do
		local color = colors[i]
		if equal(r, color[1]) and equal(g, color[2]) and equal(b, color[3]) then
			colorExists = true
			break
		end
	end
	if not colorExists then
		local _r, _g, _b = imageDataToCompare:getPixel(x, y)
		table.insert(colors, { r, g, b, _r, _g, _b })
	end
	return r, g, b, a
end

function M.printPalette()
	print("COLOR COUNT: "..#colors)
	local numColor = ansi(1)
	local punctColor = ansi(2)

	for i,color in ipairs(colors) do
		local r, g, b = color[1], color[2], color[3]
		_r, _g, _b = color[4], color[5], color[6]
		local col = ansi("48;2;"..r*255 .. ";"..g*255 .. ";"..b*255)
		local col2 = ansi("48;2;".._r*255 .. ";".._g*255 .. ";".._b*255)
		print(string.format("%s%d%s]: %s(%.2f, %.2f, %.2f) %s     %s     %s",numColor, i, punctColor, ansi.RESET, r, g, b, col, col2, ansi.RESET))
		print(string.format("\t{ %.2f, %.2f, %.2f, %.2f, %.2f, %.2f },", r, g, b, _r, _g, _b))
	end
end

return M
