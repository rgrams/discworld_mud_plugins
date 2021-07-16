io.stdout:setvbuf("no")

local ansi = require "ansi"
local paletteGenerator = require "palette-generator"
local invertShader = love.graphics.newShader("invert-shader.glsl")

local function openFile(localFilepath, forWrite)
	local dir = love.filesystem.getWorkingDirectory()
	local file, err = io.open(dir .. "/"..localFilepath, forWrite and "w" or "r")
	if not file then
		print(err)
		return
	end
	return file
end

local function makeCanvas(width, height)
	return love.graphics.newCanvas(width, height)
end

local function getCanvasDataString(canvas) -- For saving the canvas ImageData to a file.
	local imageFormat = "png"
	love.graphics.setCanvas() -- Have to disable to get ImageData.
	local fileData = canvas:newImageData():encode(imageFormat)
	return fileData:getString()
end

local function saveCanvasToFile(canvas, localFilepath)
	local outFile = openFile(localFilepath, true)
	if outFile then
		outFile:write(getCanvasDataString(canvas))
		outFile:close()
	end
end

local function drawImageToCanvas(image, canvas, shader)
	love.graphics.setCanvas(canvas)
	love.graphics.setShader(shader)
	love.graphics.draw(image)
	love.graphics.setCanvas()
	love.graphics.setShader()
end

local colorMap = require "color-map"

local function equal(a, b)
	return a > b-0.02 and a < b+0.02
end

local function remapColors(x, y, r, g, b, a)
	for i,v in ipairs(colorMap) do
		if equal(r, v[1]) and equal(g, v[2]) and equal(b, v[3]) then
			r, g, b = v[4], v[5], v[6]
		end
	end

	return r, g, b, a
end

local myImg

local function getFilePath(folder, filename)
	if folder ~= "" and folder ~= "." then
		return folder .. "/" .. filename
	else
		return filename
	end
end

local function convertImage(filename, inputFolder, outputFolder)
	local inputPath = getFilePath(inputFolder, filename)
	local outputPath = getFilePath(outputFolder, filename)

	local image = love.graphics.newImage(inputPath)
	local iw, ih = image:getDimensions()
	print("Converting image: ", inputPath, iw, ih, outputPath)
	local canvas = makeCanvas(iw, ih)
	drawImageToCanvas(image, canvas, invertShader)

	local imageData = canvas:newImageData()
	imageData:mapPixel(remapColors, 0, 0, iw, ih)
	local remappedImage = love.graphics.newImage(imageData)
	drawImageToCanvas(remappedImage, canvas)

	myImg = canvas

	saveCanvasToFile(canvas, outputPath)
end

local function getPaletteConversion(filename, masterFolder, pupilFolder)
	local masterPath = getFilePath(masterFolder, filename)
	local pupilPath = getFilePath(pupilFolder, filename)

	local image = love.graphics.newImage(pupilPath)
	local iw, ih = image:getDimensions()
	myImg = image
	print("Generating palette conversion map: ", masterPath, iw, ih, pupilPath)

	paletteGenerator.setImageDataToCompare(love.image.newImageData(masterPath))

	local pupilImageData = love.image.newImageData(pupilPath)

	pupilImageData:mapPixel(paletteGenerator.pixelMapFn, 0, 0, iw, ih)

	paletteGenerator.printPalette()
end

local inputFileNames = require "map-filenames-list"

function love.load(arg)
	local t = love.timer.getTime()

	love.graphics.setDefaultFilter("nearest", "nearest")
	for i,filename in ipairs(inputFileNames) do
		-- convertImage(filename, "backup_maps", "output")
	end
	-- getPaletteConversion("am_docks.png", "", "output")

	-- convertImage("am.png", ".", "output")

	t = love.timer.getTime() - t
	print("ELAPSED TIME: "..t.." seconds")
end

local drawX, drawY = 0, 0

function love.draw()
	if myImg then  love.graphics.draw(myImg, drawX, drawY)  end
end

local isPanning = false

function love.mousemoved(x, y, dx, dy)
	if isPanning then  drawX, drawY = drawX + dx, drawY + dy  end
end

function love.mousepressed(x, y, button, isTouch)
	if button == 3 then  isPanning = true  end
end

function love.mousereleased(x, y, button, isTouch)
	if button == 3 then  isPanning = false  end
end
