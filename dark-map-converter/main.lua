io.stdout:setvbuf("no")

local ansi = require "ansi"
local paletteGenerator = require "palette-generator"
local invertShader = love.graphics.newShader("invert-shader.glsl")

local function makeLocalFolder(folder)
	os.execute("mkdir "..folder)
end

local function splitFilePath(path)
	return string.match(path, "(.*)[\\/]([^\\/%.]+)%.?(.*)$") -- returns folder, filename, extension
end

local function getImageFromAbsolutePath(path)
	local file, error = io.open(path, "rb")
	if error then
		print("Error opening file from absolute path:\n   "..tostring(error))
		return
	end
	local folder, name, extension = splitFilePath(path)
	local filename = name .. "." .. extension
	local fileData, error = love.filesystem.newFileData(file:read("*a"), filename)
	file:close()
	if not error then
		local isSuccess, result = pcall(love.graphics.newImage, fileData)
		if not isSuccess then
			print("Error decoding image from file:\n   "..result)
		else
			return result
		end
	else
		print("Error reading file:\n   "..error)
	end
end

local function openFile(localFilepath, forWrite)
	local dir = love.filesystem.getWorkingDirectory()
	local file, err = io.open(dir .. "/" .. localFilepath, forWrite and "wb" or "r") -- Need 'b'---binary mode for windows.
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

local function convertImage(filename, inputFolder, outputFolder, isAbsolutePath)
	local inputPath = getFilePath(inputFolder, filename)
	local outputPath = getFilePath(outputFolder, filename)

	local image

	if isAbsolutePath then
		image = getImageFromAbsolutePath(inputPath)
		if not image then  return  end
	else
		local isSuccess, result = pcall(love.graphics.newImage, inputPath)
		if not isSuccess then
			print("Error loading image for conversion from relative path, '"..tostring(inputPath).."':\n   "..tostring(result))
			return
		end
		image = result
	end

	local iw, ih = image:getDimensions()
	local pixelFormat = image:getFormat()
	print("Converting image:   "..filename.." ("..iw.." x "..ih..") ("..pixelFormat..")\n   FROM: "..inputPath.."\n   TO:   "..outputPath)
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

function love.load(arg)
	print("Dark Map Converter - working directory: "..love.filesystem.getWorkingDirectory())
	love.graphics.setDefaultFilter("nearest", "nearest")
end

local DEFAULT_OUTPUT_FOLDER = "output"
local MOUNT_FOLDER = "droppedFolder"

function love.filedropped(file)
	local path = file:getFilename()
	print("File dropped: "..path)
	local folder, filename, extension = splitFilePath(path)
	makeLocalFolder(DEFAULT_OUTPUT_FOLDER)
	convertImage(filename.."."..extension, folder, DEFAULT_OUTPUT_FOLDER, true)
end

function love.directorydropped(path)
	print("Directory dropped: "..path)
	love.filesystem.mount(path, MOUNT_FOLDER)
	makeLocalFolder(DEFAULT_OUTPUT_FOLDER)
	for i,filename in ipairs(love.filesystem.getDirectoryItems(MOUNT_FOLDER)) do
		convertImage(filename, MOUNT_FOLDER, DEFAULT_OUTPUT_FOLDER)
	end
	love.filesystem.unmount(path)
end

local drawX, drawY = 0, 0

function love.draw()
	if myImg then
		love.graphics.draw(myImg, drawX, drawY)
	else
		local fnt = love.graphics.getFont()
		local str = "Drag-and-drop map images or folders onto this window to convert."
		local textW = fnt:getWidth(str)
		local w, h = love.graphics.getDimensions()
		love.graphics.print(str, w/2 - textW/2, h/2-8)
	end
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
