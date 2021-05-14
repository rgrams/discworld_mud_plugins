
local prefix = 'room.writtenmap "'
local suffix = '.\\n"'

local customReplacers = {
   {"(%w+) and white", "%1-and-white"},
   {"\\u001b%[%dz", ""},
   {"MXP<.-MXP>", ""},
}

local THING_COUNT = "(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen)"
local MOVE_COUNT = "(one|two|three|four|five|six|seven)"
local DIRECTION = "(northeast|northwest|southeast|southwest|north|south|east|west)"
local moveRegex = rex.new("(?:"..MOVE_COUNT.." )?"..DIRECTION, CASE_INSENSITIVE) -- Match a space ONLY if there's a number, but don't capture it.

local numStrToNum = { [false] = 1, one = 1, two = 2, three = 3, four = 4, five = 5, six = 6, seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11, twelve = 12, thirteen = 13, fourteen = 14 }
local longDirToShort = { northeast = "ne", northwest = "nw", southeast = "se", southwest = "sw", north = "n", south = "s", east = "e", west = "w" }

local MV = "<\\d \\w{1,2}>" -- Ex: "<1 nw>" -- NOTE: No captures.
local moveSequenceRegex = rex.new("((?:(?:"..MV.."), )*)("..MV.." and )?("..MV..")")

local splitMoveSeqRegex = rex.new("(\\d) ([nsew]{1,2})(?=, |$)")

local EXIT, EXIT_DIRS, EXIT_POS, VISION, VISION_POS, THING, THING_POS = 1, 2, 3, 4, 5, 6, 7 -- Chunk capture indices.
local CHUNK = [[(?:(?:a |an )?(exit|door)s? <(.+?)> of <(.+?)>|(?:and )?the limit of your (vision) is <(.+?)> from here|(\w[\w \-,]+) (?:is|are) <(.+?)>)]]
local chunkRegex = rex.new(CHUNK, CASE_INSENSITIVE)

local function regexReplace(str, regex, matchFn)
   local overloadLimit = 1000
   local startI = 1
   local lastCharI = #str
   local i = 0
   while startI <= lastCharI do
      i = i + 1
      if i >= overloadLimit then  break  end
      startCharI, endCharI, captures = regex:match(str, startI)
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
      startI = (endCharI or lastCharI) + 1
   end
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

-- Replace words with abbreviations, inside < >.
local function moveReplacer(match, captures)
   local num = numStrToNum[captures[1]] or 1
   local dir = longDirToShort[captures[2]]
   return "<"..num.." "..dir..">"
end

-- Replace
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

local _debugLevel -- Set for each call to parse().

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

local function addEntities(match, captures)
   local num = numStrToNum[captures[1]]
   local entStr = captures[2]
   if num > 1 then  entStr = num .. " " .. entStr  end
   _entities = _entities or {}
   table.insert(_entities, entStr)
end

local entityRegex = rex.new("(?:a |an |)"..THING_COUNT.."? ?(.+?)(?:, |$)")

local function parseChunk(chunk, captures)
   local chunkType = (captures[EXIT] or captures[VISION] or "thing")
   if captures[EXIT] then  chunkType = chunkType:lower()  end -- "Exit"/"Door", etc. can be the first word in the whole packet.

   -- chunkType can be: "exit", "door", "vision", or "thing".
   if chunkType == "thing" then
      -- chunkType = "<"..chunkType.."> "
      -- print(chunkType..chunk)
      -- print("  ", things, ",", pos, ",", dx, ",", dy)
      local thingStr = captures[THING]
      local posStr = captures[THING_POS]

      getMoveSequenceFromString(posStr)

      thingStr = thingStr:gsub(" and ", ", ")
      _entities = nil -- Clear data from last use.
      entityRegex:gmatch(thingStr, addEntities)

      if _debugLevel then
         local str = string.format("%s:  %s", table.concat(_moves, ", "), table.concat(_entities, ", "))
         print(str)
      end

      if _entities and #_entities > 0 then
         local roomData = { entities = _entities, moves = _moves, dx = _dx, dy = _dy }
         table.insert(_rooms, roomData)
      end
   end
end

local function parse(str, debugLevel)
	_debugLevel = debugLevel -- any-truthy-value --> print each room, 2 --> print whole text and each room.

   str = str:gsub(prefix, "")
   str = str:gsub(suffix, "")
   str = str:gsub('"', "")

   for i,v in ipairs(customReplacers) do
      str = str:gsub(v[1], v[2])
   end

   if _debugLevel == 2 then  print(str)  end

   _rooms = {} -- List of room entries: { entities, moves, dx, dy }
   -- (Store at higher scope so parseChunk() can access it.)

   -- First replace directional stuff with sequences that are easy to deal with.
   str = regexReplace(str, moveRegex, moveReplacer) -- "two northwest" --> "<2 nw>"
   str = regexReplace(str, moveSequenceRegex, moveSequenceReplacer)
   -- Now we can detect the different chunks very specifically without extra junk in the way.
   chunkRegex:gmatch(str, parseChunk)

   return _rooms
end

return parse
