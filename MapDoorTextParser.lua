
local prefix = 'room.writtenmap "'
local suffix = '\\n"'

local customReplacers = {
	{"(%w+) and white", "%1-and-white"},
	{"(%w+) and yellow", "%1-and-yellow"},
}

-- Up-scoped values for regex replacer and other functions to grab.
local _debugLevel -- Set for each call to parse().
local _playerPrefix
local _colorOption

local function hexToAnsi(hex)
	local rgb = ColourNameToRGB(hex)
	-- How to split a single-int-rgb value into its components if you have absolutely no clue what you're doing.
	local r = rgb % 256
	local g = (rgb - r) % 65536 / 256
	local b = bit.shr(rgb, 16)

	return ANSI(38, 2, r, g, b) -- 38;2 is the 24-bit foreground color ANSI sequence.
end

local CASE_INSENSITIVE = rex.flags().CASELESS

-- MXP color can be a hex color: "C #d7d7d7" or a named color: "White".
local playerColorRegex = rex.new([[\\u001b\[4zMXP<(?:C )?(#[0-9a-f]{6}|[A-Z]\w+)MXP>]])

local THING_COUNT = "(?:(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen) )"
local MOVE_COUNT = "(one|two|three|four|five|six|seven)"
local DIRECTION = "(northeast|northwest|southeast|southwest|north|south|east|west|here)\\b"
local moveRegex = rex.new("(?:"..MOVE_COUNT.." )?"..DIRECTION, CASE_INSENSITIVE) -- Match a space ONLY if there's a number, but don't capture it.

local numStrToNum = { [false] = 1, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11, twelve = 12, thirteen = 13, fourteen = 14 }
local longDirToShort = { here = "here", northeast = "ne", northwest = "nw", southeast = "se", southwest = "sw", north = "n", south = "s", east = "e", west = "w" }

local MOVE = "<\\d \\w{1,2}>" -- Ex: "<1 nw>" -- NOTE: No captures.
local moveSequenceRegex = rex.new("((?:(?:"..MOVE.."), )*)("..MOVE.." and )?("..MOVE..")")
local splitMoveSeqRegex = rex.new("(\\d) ([nsew]{1,2})(?=, |$)")

local BOUNDARY_JUNK = [[(?: and |, |.)]] -- Chunks will end with an [[ and ]], [[, ]], or [[.]] that we don't need but don't want to leave behind.
local EXIT_CHUNK = [[(?:a |an )?(exit|door)s? <(.+?)> of <(.+?)>]] .. BOUNDARY_JUNK
local VISION_CHUNK = [[the limit of your vision is (?:<(.+?)> from )?<0 n>]] .. BOUNDARY_JUNK -- Must match: "The limit of your vision is here."
local ENTITY_CHUNK = [[(.+?) (?:is|are) <(.+?)>]] .. BOUNDARY_JUNK -- Once other chunks are filtered out, this can be very broad.
local exitChunkRegex = rex.new(EXIT_CHUNK, CASE_INSENSITIVE)
local visionChunkRegex = rex.new(VISION_CHUNK, CASE_INSENSITIVE)
local entityChunkRegex = rex.new(ENTITY_CHUNK, CASE_INSENSITIVE)

local splitEntitySeqRegex = rex.new("(?:a |an |)"..THING_COUNT.."?(.+?)(?:, |$)", CASE_INSENSITIVE)

-- Chunk capture indices:
local THING, THING_POS = 1, 2 -- For entity chunks.

local function regexReplace(str, regex, matchFn)
	local overloadLimit = 1000
	local startI = 1
	local lastCharI = #str
	local iter = 0
	repeat
		iter = iter + 1
		if iter >= overloadLimit then  print("regexReplace - HIT OVERLOAD LIMIT")  break  end
		local startCharI, endCharI, captures = regex:match(str, startI)
		if startCharI then
			local fullMatch = str:sub(startCharI, endCharI)
			local repl = matchFn(fullMatch, captures)
			if repl then
				local pre = str:sub(1, startCharI - 1)
				local post = str:sub(endCharI + 1, -1)
				str = pre .. repl .. post
				endCharI = startCharI + #repl
				lastCharI = #str
			end
		end
		startI = (endCharI or lastCharI)
	until startI >= lastCharI
	return str
end

local function dirStrToVec(dir)
	if dir == "n" then  return 0, 1
	elseif dir == "s" then  return 0, -1
	elseif dir == "e" then  return 1, 0
	elseif dir == "w" then  return -1, 0
	elseif dir == "ne" then  return 1, 1
	elseif dir == "nw" then  return -1, 1
	elseif dir == "se" then  return 1, -1
	elseif dir == "sw" then  return -1, -1
	end
end

-- Replacer for MXP hex colors before player names.
local function playerColorReplacer(match, captures)
	local replacement = ""
	if _playerPrefix then
		replacement = _playerPrefix
	end
	if _colorOption == "ansi" then
		local hexColor = captures[1]
		local ansiColor = hexToAnsi(hexColor)
		replacement = ansiColor .. replacement
	elseif _colorOption == "unmodified" then
		replacement = match .. replacement
	end
	return replacement
end

-- Replace words with abbreviations, inside < >. Example: "two northwest" --> "<2 nw>"
local function moveReplacer(match, captures)
	local num = numStrToNum[captures[1]] or 1
	local dir = longDirToShort[captures[2]]
	if dir == "here" then
		num, dir = 0, "n"
	end
	return "<"..num.." "..dir..">"
end

-- Merge a sequence of moves into a single list inside < >.
-- Example <1 n>, <2 nw>, <1 n> and <1 w> --> <1 n, 2 nw, 1 n, 1 w>
local function moveSequenceReplacer(match, captures)
	local list, moveAnd, last = captures[1], captures[2], captures[3]
	list = list or ""
	moveAnd = moveAnd and moveAnd:gsub(" and", ",") or ""
	local all = list..moveAnd..last
	all = all:gsub("[<>]", "")
	return "<"..all..">"
end

-- Temporary variables so regex match functions can be static.
local _rooms
local _entities
local _moves
local _dx, _dy

local function sumMove(match, captures) -- Full match is the abbreviation: "1 nw", etc.
	local dist, dir = tonumber(captures[1]), captures[2]
	local dx, dy = dirStrToVec(dir)
	_dx, _dy = _dx + dx*dist, _dy + dy*dist
	table.insert(_moves, match)
end

local function getMoveSequenceFromString(moveSeqStr)
	_dx, _dy = 0, 0
	_moves = {}
	splitMoveSeqRegex:gmatch(moveSeqStr, sumMove)
	return _moves, _dx, _dy
end

local function replaceExitChunk(match, captures)
	return ""
end

local function replaceVisionChunk(match, captures)
	return ""
end

local function addEntities(match, captures)
	if captures[1] then  captures[1] = string.lower(captures[1])  end
	local num = numStrToNum[captures[1]]
	if type(num) ~= "number" then
		print("WARNING: MDT-Parser.addEntities - Number capture seems to have failed. Invalid number: '"..tostring(num).."' for match: '"..match.."'")
		num = 1
	end
	local entStr = captures[2]
	if num > 1 then  entStr = num .. " " .. entStr  end
	_entities = _entities or {}
	table.insert(_entities, entStr)
end

local function parseEntityChunk(match, captures)
	local thingStr = captures[THING]
	local posStr = captures[THING_POS]

	getMoveSequenceFromString(posStr)

	thingStr = thingStr:gsub(" and ", ", ")
	_entities = nil -- Clear data from last use.
	splitEntitySeqRegex:gmatch(thingStr, addEntities)

	if _debugLevel then
		local str = string.format("%s:  %s", table.concat(_moves, ", "), table.concat(_entities, ", "))
		print(str)
	end

	if _entities and #_entities > 0 then
		local roomData = { entities = _entities, moves = _moves, dx = _dx, dy = _dy }
		table.insert(_rooms, roomData)
	end
end

local isValidColorOption = { strip = false, ansi = true, unmodified = true }

local function parse(str, debugLevel, playerPrefix, colorOption)
	_debugLevel = debugLevel -- any-truthy-value --> print each room, 2 --> print whole text and each room.
	if playerPrefix == "" then  playerPrefix = nil  end
	_playerPrefix = playerPrefix
	colorOption = isValidColorOption[colorOption] and colorOption or nil
	_colorOption = colorOption

	str = str:gsub(prefix, "")
	str = str:gsub(suffix, "")
	str = str:gsub('"', "")

	-- Handle player colors and prefix.
	if not playerPrefix and not colorOption then -- Default: just strip out player colors.
		str = str:gsub("\\u001b%[%dz", "") -- NOTE: \u001b == Unicode Escape Sequence.
		str = str:gsub("MXP<.-MXP>", "")
	else
		str = regexReplace(str, playerColorRegex, playerColorReplacer)
		if colorOption == "ansi" then
			-- If converting color codes to ANSI, make sure it's reset first or it looks like we messed up if a color is already set (like the standard Note blue).
			str = ANSI(0) .. str
			str = str:gsub("\\u001b%[3z", ANSI(0))
		elseif not colorOption then
			str = str:gsub("\\u001b%[3z", "")
		end
	end

	for i,v in ipairs(customReplacers) do
		str = str:gsub(v[1], v[2])
	end

	if _debugLevel and _debugLevel >= 2 then  AnsiNote(str)  end

	_rooms = {} -- List of room entries: { entities, moves, dx, dy }
	-- (Store at higher scope so parseChunk() can access it.)

	-- First replace directional stuff with sequences that are easy to deal with.
	str = regexReplace(str, moveRegex, moveReplacer) -- "two northwest" --> "<2 nw>"
	str = regexReplace(str, moveSequenceRegex, moveSequenceReplacer) -- "<2 nw>, <1 n> and <1 w>" --> "<2 nw, 1 n, 1 w>"

	if _debugLevel == 3 then  AnsiNote("\n"..str)  end
	-- Now we can detect the different chunks more specifically without extra junk in the way.

	str = regexReplace(str, exitChunkRegex, replaceExitChunk) -- Replace door/exit chunks.
	str = regexReplace(str, visionChunkRegex, replaceVisionChunk) -- Replace vision limit chunks.
	entityChunkRegex:gmatch(str, parseEntityChunk) -- Parse what's left: entity chunks.

	return _rooms
end

return parse
